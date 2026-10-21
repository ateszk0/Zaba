#!/usr/bin/env python3
"""End-to-end test of the payment path through the real Edge Functions: the
customer starts a payment, reports the (fake) card outcome, the fake provider
signs an event and delivers it to the webhook, and the order changes. It also
attacks the webhook and the session the way a hostile client would.

    python3 supabase/tests/payment_smoke.py --from-local

`--from-local` reads URL and keys from `npx supabase status`, and the provider's
signing secret from supabase/.env (the file the local stack was started with).
For another environment set SUPABASE_URL, SUPABASE_PUBLISHABLE_KEY,
SUPABASE_ANON_KEY and FAKE_PAYMENT_WEBHOOK_SECRET. Keys and secrets are never
printed. Do not run this against a production project: it creates users and
orders.
"""

import base64
import hashlib
import hmac
import json
import os
import pathlib
import subprocess
import sys
import time
import urllib.error
import urllib.request
import uuid

failures = []


def check(name, condition, detail=""):
    print(("ok      " if condition else "FAILED  ") + name + (f"  [{detail}]" if detail and not condition else ""))
    if not condition:
        failures.append(name)


def load_config():
    if "--from-local" in sys.argv:
        out = subprocess.run(["npx", "supabase", "status", "-o", "json"], capture_output=True, text=True, check=True).stdout
        data = json.loads(out[out.index("{"):])
        secret = os.environ.get("FAKE_PAYMENT_WEBHOOK_SECRET")
        env_file = pathlib.Path(__file__).resolve().parents[1] / ".env"
        if not secret and env_file.exists():
            for line in env_file.read_text().splitlines():
                if line.startswith("FAKE_PAYMENT_WEBHOOK_SECRET="):
                    secret = line.split("=", 1)[1].strip()
        if not secret:
            sys.exit("No FAKE_PAYMENT_WEBHOOK_SECRET: put it in supabase/.env and restart the stack (see supabase/.env.example)")
        return data["API_URL"], data["PUBLISHABLE_KEY"], data["ANON_KEY"], secret
    try:
        return (os.environ["SUPABASE_URL"], os.environ["SUPABASE_PUBLISHABLE_KEY"],
                os.environ["SUPABASE_ANON_KEY"], os.environ["FAKE_PAYMENT_WEBHOOK_SECRET"])
    except KeyError as missing:
        sys.exit(f"Missing environment variable {missing}, or pass --from-local")


API, PUBLISHABLE, ANON, SECRET = load_config()


def call(method, path, key, token=None, body=None, raw=None, headers=None):
    all_headers = {**({"apikey": key} if key else {}), "Content-Type": "application/json", **(headers or {})}
    if token:
        all_headers["Authorization"] = f"Bearer {token}"
    data = raw.encode() if raw is not None else (json.dumps(body).encode() if body is not None else None)
    request = urllib.request.Request(f"{API}{path}", data=data, method=method, headers=all_headers)
    try:
        with urllib.request.urlopen(request) as response:
            text = response.read().decode()
            return response.status, (json.loads(text) if text else None)
    except urllib.error.HTTPError as error:
        text = error.read().decode()
        try:
            return error.code, json.loads(text)
        except ValueError:
            return error.code, {"raw": text[:200]}


def rpc(name, key, token=None, **params):
    return call("POST", f"/rest/v1/rpc/{name}", key, token, params)


def sign_up():
    email = f"pay-{uuid.uuid4().hex[:10]}@example.test"
    status, session = call("POST", "/auth/v1/signup", PUBLISHABLE, body={"email": email, "password": "Sm0ke-test-pass"})
    assert status == 200, status
    return session["access_token"]


def place_order(token, slot):
    # One checkout attempt, one idempotency id (kept apart from the call so the
    # secret scanner does not mistake the random id for a key).
    attempt_id = f"pay-{uuid.uuid4()}"
    order = dict(p_lines=[{"product_id": "carbonara", "quantity": 2}], p_postal_code="1051",
                 p_street="Váci utca 12.", p_slot_id=slot, p_note="")
    status, placed = rpc("place_order", PUBLISHABLE, token, p_idempotency_key=attempt_id, **order)
    assert status == 200, placed
    return placed["id"]


def create_payment(token, order_id):
    return call("POST", "/functions/v1/payments-create", PUBLISHABLE, token, {"order_id": order_id})


def confirm(token, session_token, outcome):
    # `token` None sends no Supabase credentials: the signed session is the credential.
    return call("POST", "/functions/v1/fake-provider-confirm", PUBLISHABLE if token else None, token,
                {"session_token": session_token, "outcome": outcome})


def order_state(token, order_id):
    status, rows = call("GET", f"/rest/v1/orders?id=eq.{order_id}&select=status,payment_status", PUBLISHABLE, token)
    assert status == 200, rows
    return rows[0]["status"], rows[0]["payment_status"]


def signed_event(order_id, payment_id, kind="succeeded", event_id=None, at=None):
    """What a provider's backend would send, signed with the shared secret."""
    body = json.dumps({"id": event_id or f"evt_{uuid.uuid4().hex}", "type": f"payment.{kind}",
                       "data": {"order_id": order_id, "payment_id": payment_id}})
    t = int(at if at is not None else time.time())
    signature = hmac.new(SECRET.encode(), f"{t}.{body}".encode(), hashlib.sha256).hexdigest()
    return body, f"t={t},v1={signature}"


def deliver(body, header, token=None, key=None):
    """Posts an event to the webhook. By default with no Supabase credentials at
    all, like a payment provider: the signature is the only credential."""
    headers = {"x-zaba-signature": header} if header else {}
    return call("POST", "/functions/v1/payments-webhook", key, token, raw=body, headers=headers)


token = sign_up()
other = sign_up()
status, slots = rpc("get_delivery_slots", PUBLISHABLE, token)
assert status == 200 and len(slots) >= 6, slots
slot_ids = [s["slot_id"] for s in slots]

# --- a successful payment --------------------------------------------------------
order = place_order(token, slot_ids[0])
status, payment = create_payment(token, order)
check("the customer gets a payment session", status == 200 and payment["amount_huf"] == 6570
      and payment["provider"] == "fake" and payment["currency"] == "HUF" and payment["session_token"], (status, payment))
session = payment["session_token"]

status, result = confirm(token, session, "approved")
check("the fake provider reports success", status == 200 and result == {"accepted": True}, (status, result))
check("the order is received and paid", order_state(token, order) == ("received", "succeeded"), order_state(token, order))

status, history = call("GET", f"/rest/v1/order_status_history?order_id=eq.{order}&select=to_status,actor&order=id", PUBLISHABLE, token)
check("the history names the payment as the actor", status == 200 and history[-1] == {"to_status": "received", "actor": "payment"}, history)

status, rows = call("GET", f"/rest/v1/payments?order_id=eq.{order}&select=status,provider", PUBLISHABLE, token)
check("the payment attempt succeeded", status == 200 and rows == [{"status": "succeeded", "provider": "fake"}], rows)

# --- the card step needs only its session --------------------------------------
order = place_order(token, slot_ids[5])
status, attempt = create_payment(token, order)
status, result = confirm(None, attempt["session_token"], "approved")
check("the card step works with the signed session alone", status == 200 and result == {"accepted": True}, (status, result))
check("and pays the order", order_state(token, order) == ("received", "succeeded"), order_state(token, order))

# --- a declined card, then a retry ---------------------------------------------
order = place_order(token, slot_ids[1])
status, first = create_payment(token, order)
confirm(token, first["session_token"], "declined")
check("a declined card leaves the order waiting, payment failed", order_state(token, order) == ("pending_payment", "failed"), order_state(token, order))

status, late = confirm(token, first["session_token"], "approved")
check("the closed attempt's session cannot pay the order afterwards", status == 200 and order_state(token, order) == ("pending_payment", "failed"),
      (status, order_state(token, order)))

status, second = create_payment(token, order)
check("a retry opens a new attempt", status == 200 and second["payment_id"] != first["payment_id"], (status, second))
confirm(token, second["session_token"], "approved")
check("and the retry can pay the order", order_state(token, order) == ("received", "succeeded"), order_state(token, order))

# --- the customer cancels at the card step -----------------------------------
order = place_order(token, slot_ids[2])
status, attempt = create_payment(token, order)
confirm(token, attempt["session_token"], "cancelled")
check("cancelling the card step is recorded", order_state(token, order) == ("pending_payment", "cancelled"), order_state(token, order))

# --- the webhook: only a signed, fresh event counts -----------------------------
order = place_order(token, slot_ids[3])
status, attempt = create_payment(token, order)
pay_id = attempt["payment_id"]

body, header = signed_event(order, pay_id)
status, result = deliver(body, None)
check("an unsigned event is refused", status == 400 and result == {"error": "invalid_webhook"}, (status, result))
status, result = deliver(body, f"t={int(time.time())},v1={'0' * 64}")
check("a wrongly signed event is refused", status == 400, (status, result))
status, result = deliver(body.replace("succeeded", "failed"), header)
check("a changed body is refused", status == 400, (status, result))
old_body, old_header = signed_event(order, pay_id, at=time.time() - 3600)
status, result = deliver(old_body, old_header)
check("a stale event is refused", status == 400, (status, result))
status, result = call("GET", "/functions/v1/payments-webhook", None)
check("only POST is accepted", status == 405, (status, result))
check("none of those changed the order", order_state(token, order) == ("pending_payment", "pending"), order_state(token, order))

status, result = deliver(body, header)
check("a signed event is applied, with no Supabase credentials sent", status == 200 and result == {"applied": True}, (status, result))
check("the order is paid", order_state(token, order) == ("received", "succeeded"), order_state(token, order))
status, result = deliver(body, header)
check("the same request delivered again is a duplicate", status == 200 and result == {"applied": False, "reason": "duplicate"}, (status, result))

body, header = signed_event(str(uuid.uuid4()), str(uuid.uuid4()))
status, result = deliver(body, header)
check("an event for an unknown order is acknowledged and ignored", status == 200 and result == {"applied": False, "reason": "unknown_order"}, (status, result))

# --- who may start a payment, and the session token -----------------------------
order = place_order(token, slot_ids[4])
status, result = create_payment(other, order)
check("another customer cannot start a payment for the order", status == 404 and result == {"error": "order_not_found"}, (status, result))
status, result = call("POST", "/functions/v1/payments-create", PUBLISHABLE, ANON, {"order_id": order})
check("a guest cannot start a payment", status == 401, (status, result))
unsigned_body, _ = signed_event(order, str(uuid.uuid4()), kind="succeeded")
status, result = deliver(unsigned_body, None, key=ANON, token=token)
check("credentials of a customer do not replace the signature", status == 400 and result == {"error": "invalid_webhook"}, (status, result))
status, result = call("POST", "/functions/v1/payments-create", PUBLISHABLE, None, {"order_id": order})
check("a request without credentials is refused", status == 401, (status, result))
status, result = create_payment(token, "not-a-uuid")
check("an invalid order id is refused", status == 400 and result == {"error": "invalid_request"}, (status, result))

status, attempt = create_payment(token, order)
payload, signature = attempt["session_token"].split(".")
status, result = confirm(token, f"{payload}.{'0' * 64}", "approved")
check("a tampered session token is refused", status == 400 and result == {"error": "invalid_session"}, (status, result))

forged_payload = base64.urlsafe_b64encode(json.dumps({"v": 1, "p": attempt["payment_id"], "o": order, "a": 1, "e": int(time.time()) - 10, "n": "x"}).encode()).decode().rstrip("=")
forged_signature = hmac.new(SECRET.encode(), f"session:{forged_payload}".encode(), hashlib.sha256).hexdigest()
status, result = confirm(token, f"{forged_payload}.{forged_signature}", "approved")
check("an expired session token is refused", status == 400 and result == {"error": "invalid_session"}, (status, result))
status, result = confirm(token, attempt["session_token"], "succeeded")
check("the card page can only report approved, declined or cancelled", status == 400 and result == {"error": "invalid_request"}, (status, result))
check("none of that paid the order", order_state(token, order) == ("pending_payment", "pending"), order_state(token, order))

print()
if failures:
    sys.exit(f"{len(failures)} check(s) failed")
print("All payment checks passed.")
