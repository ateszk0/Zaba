#!/usr/bin/env python3
"""End-to-end smoke test of the HTTP API (PostgREST + Auth), the way the app
and the admin page will use it: an anonymous visitor, a customer who signs up,
and the payment provider (service role).

    python3 supabase/tests/api_smoke.py --from-local

`--from-local` reads URL and keys from `npx supabase status`. For another
environment set SUPABASE_URL, SUPABASE_PUBLISHABLE_KEY and SUPABASE_SECRET_KEY.
Keys are never printed. Do not run this against a production project: it
creates a user and an order.
"""

import json
import os
import subprocess
import sys
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
        return data["API_URL"], data["PUBLISHABLE_KEY"], data["SECRET_KEY"]
    try:
        return os.environ["SUPABASE_URL"], os.environ["SUPABASE_PUBLISHABLE_KEY"], os.environ["SUPABASE_SECRET_KEY"]
    except KeyError as missing:
        sys.exit(f"Missing environment variable {missing}, or pass --from-local")


API, PUBLISHABLE, SECRET = load_config()


def call(method, path, key, token=None, body=None):
    headers = {"apikey": key, "Content-Type": "application/json"}
    # The new-style secret/publishable keys are not JWTs: they go in `apikey`
    # only. A signed-in user's JWT goes in Authorization.
    if token:
        headers["Authorization"] = f"Bearer {token}"
    data = json.dumps(body).encode() if body is not None else None
    request = urllib.request.Request(f"{API}{path}", data=data, method=method, headers=headers)
    try:
        with urllib.request.urlopen(request) as response:
            text = response.read().decode()
            return response.status, (json.loads(text) if text else None)
    except urllib.error.HTTPError as error:
        text = error.read().decode()
        try:
            return error.code, json.loads(text)
        except ValueError:
            return error.code, text


def rpc(name, key, token=None, **args):
    return call("POST", f"/rest/v1/rpc/{name}", key, token, args)


# --- an anonymous visitor ----------------------------------------------------
status, products = call("GET", "/rest/v1/catalog_products?select=id,price_huf&order=id", PUBLISHABLE)
check("anon can list the menu", status == 200 and len(products) == 45, status)

status, quote = rpc("quote_cart", PUBLISHABLE, p_lines=[{"product_id": "carbonara", "quantity": 2}], p_postal_code="1051")
check("anon can get a quote", status == 200 and quote["total_huf"] == 6570, quote)

status, _ = call("GET", "/rest/v1/orders?select=id", PUBLISHABLE)
check("anon cannot read orders", status in (401, 403), status)

status, _ = rpc("place_order", PUBLISHABLE, p_idempotency_key="k", p_lines=[], p_postal_code="1051", p_street="x", p_slot_id=str(uuid.uuid4()))
check("anon cannot place an order", status in (401, 403), status)

status, _ = rpc("apply_payment_event", PUBLISHABLE, p_provider="fake", p_event_id="x", p_order_id=str(uuid.uuid4()), p_type="succeeded")
check("anon cannot report payment events", status in (401, 403), status)

# --- a customer signs up ------------------------------------------------------
email = f"smoke-{uuid.uuid4().hex[:10]}@example.test"
status, session = call("POST", "/auth/v1/signup", PUBLISHABLE, body={"email": email, "password": "Sm0ke-test-pass"})
check("a customer can sign up (no email confirmation locally)", status == 200 and "access_token" in (session or {}), status)
token = session["access_token"]

status, profile = call("GET", "/rest/v1/profiles?select=id", PUBLISHABLE, token)
check("the new account has its profile", status == 200 and len(profile) == 1, profile)

status, slots = rpc("get_delivery_slots", PUBLISHABLE, token)
check("the customer can list delivery slots", status == 200 and len(slots) > 0, slots)
slot_id = slots[0]["slot_id"]

key = f"smoke-{uuid.uuid4()}"
args = dict(
    p_idempotency_key=key,
    p_lines=[{"product_id": "carbonara", "quantity": 2}],
    p_postal_code="1051",
    p_street="Váci utca 12.",
    p_slot_id=slot_id,
    p_note="smoke test",
)
status, placed = rpc("place_order", PUBLISHABLE, token, **args)
check("the customer can place an order", status == 200 and placed["number"].startswith("ZB-"), placed)
order_id = placed["id"]

status, again = rpc("place_order", PUBLISHABLE, token, **args)
check("the same key gives the same order", status == 200 and again["id"] == order_id and again["replayed"], again)

status, orders = call("GET", f"/rest/v1/orders?id=eq.{order_id}&select=status,payment_status,total_huf,order_items(name,quantity)", PUBLISHABLE, token)
check(
    "the customer sees the order, waiting for payment, with its lines",
    status == 200 and orders[0]["status"] == "pending_payment" and orders[0]["total_huf"] == 6570
    and orders[0]["order_items"][0]["quantity"] == 2,
    orders,
)

status, body = call("PATCH", f"/rest/v1/orders?id=eq.{order_id}", PUBLISHABLE, token, {"status": "delivered"})
check("the customer cannot edit the order by hand", status in (401, 403), (status, body))

status, payment = rpc("start_payment", PUBLISHABLE, token, p_order_id=order_id)
check("the customer can start a payment", status == 200 and payment["amount_huf"] == 6570, payment)

status, _ = rpc("apply_payment_event", PUBLISHABLE, token, p_provider="fake", p_event_id="x", p_order_id=order_id, p_type="succeeded")
check("the customer cannot report their own payment", status in (401, 403), status)

# --- the payment provider ------------------------------------------------------
event = dict(p_provider="fake", p_event_id=f"evt-{uuid.uuid4()}", p_order_id=order_id, p_type="succeeded")
status, result = rpc("apply_payment_event", SECRET, **event)
check("the service role can report a payment", status == 200 and result == {"applied": True}, result)

status, result = rpc("apply_payment_event", SECRET, **event)
check("the same event again is a duplicate", status == 200 and result == {"applied": False, "reason": "duplicate"}, result)

status, orders = call("GET", f"/rest/v1/orders?id=eq.{order_id}&select=status,payment_status", PUBLISHABLE, token)
check("the order is now received and paid", status == 200 and orders[0] == {"status": "received", "payment_status": "succeeded"}, orders)

status, history = call("GET", f"/rest/v1/order_status_history?order_id=eq.{order_id}&select=to_status&order=id", PUBLISHABLE, token)
check("the customer sees the status history", status == 200 and [h["to_status"] for h in history] == ["pending_payment", "received"], history)

status, _ = rpc("cancel_order", PUBLISHABLE, token, p_order_id=order_id)
check("the customer can cancel until the kitchen starts", status in (200, 204), status)

status, orders = call("GET", f"/rest/v1/orders?id=eq.{order_id}&select=status,payment_status", PUBLISHABLE, token)
check("the cancelled order is refunded", status == 200 and orders[0] == {"status": "cancelled", "payment_status": "refunded"}, orders)

print()
if failures:
    sys.exit(f"{len(failures)} check(s) failed")
print("All API checks passed.")
