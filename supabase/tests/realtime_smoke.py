#!/usr/bin/env python3
"""Checks that live order updates (Supabase Realtime over WebSocket) arrive.

A customer signs up, places an order and subscribes to changes of `orders`;
then the payment provider (service role) reports a successful payment, and the
customer must receive the update live. Run it against a local stack, or against
the staging environment to prove the WebSocket survives the whole path (Caddy,
the Cloudflare Tunnel):

    pip install websockets
    python3 supabase/tests/realtime_smoke.py --from-local
    # or: SUPABASE_URL=... SUPABASE_PUBLISHABLE_KEY=... SUPABASE_SECRET_KEY=... SUPABASE_ANON_KEY=... python3 supabase/tests/realtime_smoke.py

It creates a user and an order, so it is for local and staging only.
"""

import asyncio
import json
import os
import subprocess
import sys
import urllib.error
import urllib.request
import uuid

try:
    import websockets
except ImportError:
    sys.exit("This test needs the websockets package: pip install websockets")


def load_config():
    if "--from-local" in sys.argv:
        out = subprocess.run(["npx", "supabase", "status", "-o", "json"], capture_output=True, text=True, check=True).stdout
        data = json.loads(out[out.index("{"):])
        return data["API_URL"], data["PUBLISHABLE_KEY"], data["SECRET_KEY"], data["ANON_KEY"]
    try:
        return (
            os.environ["SUPABASE_URL"], os.environ["SUPABASE_PUBLISHABLE_KEY"], os.environ["SUPABASE_SECRET_KEY"],
            # The self-hosted Realtime server accepts only the legacy anon JWT on the
            # WebSocket (the new publishable key works for REST, not for Realtime).
            os.environ.get("SUPABASE_ANON_KEY") or os.environ["SUPABASE_PUBLISHABLE_KEY"],
        )
    except KeyError as missing:
        sys.exit(f"Missing environment variable {missing}, or pass --from-local")


API, PUBLISHABLE, SECRET, WEBSOCKET_KEY = load_config()


def call(method, path, key, token=None, body=None):
    headers = {"apikey": key, "Content-Type": "application/json"}
    if token:
        headers["Authorization"] = f"Bearer {token}"
    data = json.dumps(body).encode() if body is not None else None
    request = urllib.request.Request(f"{API}{path}", data=data, method=method, headers=headers)
    try:
        with urllib.request.urlopen(request) as response:
            text = response.read().decode()
            return response.status, (json.loads(text) if text else None)
    except urllib.error.HTTPError as error:
        sys.exit(f"{method} {path} failed with {error.code}: {error.read().decode()[:300]}")


def rpc(name, key, token=None, **args):
    return call("POST", f"/rest/v1/rpc/{name}", key, token, args)[1]


async def receive_until(socket, predicate, seconds):
    async def loop():
        async for raw in socket:
            message = json.loads(raw)
            if predicate(message):
                return message

    return await asyncio.wait_for(loop(), timeout=seconds)


async def main():
    email = f"realtime-{uuid.uuid4().hex[:10]}@example.test"
    _, session = call("POST", "/auth/v1/signup", PUBLISHABLE, body={"email": email, "password": "Sm0ke-test-pass"})
    token = session["access_token"]

    slot = rpc("get_delivery_slots", PUBLISHABLE, token)[0]["slot_id"]
    placed = rpc(
        "place_order", PUBLISHABLE, token,
        p_idempotency_key=f"rt-{uuid.uuid4()}", p_lines=[{"product_id": "carbonara", "quantity": 2}],
        p_postal_code="1051", p_street="Váci utca 12.", p_slot_id=slot, p_note="",
    )
    order_id = placed["id"]
    rpc("start_payment", PUBLISHABLE, token, p_order_id=order_id)

    ws_url = API.replace("https://", "wss://").replace("http://", "ws://")
    async with websockets.connect(f"{ws_url}/realtime/v1/websocket?apikey={WEBSOCKET_KEY}&vsn=1.0.0") as socket:
        await socket.send(json.dumps({
            "topic": "realtime:orders", "event": "phx_join", "ref": "1",
            "payload": {
                "config": {
                    "broadcast": {"ack": False, "self": False},
                    "presence": {"key": ""},
                    "postgres_changes": [{"event": "*", "schema": "public", "table": "orders"}],
                    "private": False,
                },
                "access_token": token,
            },
        }))
        # Realtime answers the join first, and only a moment later (on a fresh
        # server up to several seconds: it sets up its replication slot on
        # demand) announces that the database changes are being followed. Paying
        # before that would miss the update, so wait for both.
        joined = followed = False

        def subscription_ready(message):
            nonlocal joined, followed
            if message["event"] == "phx_reply":
                if message["payload"]["status"] != "ok":
                    sys.exit(f"FAILED  could not subscribe: {message['payload']}")
                joined = True
            elif message["event"] == "system" and message["payload"].get("extension") == "postgres_changes":
                if message["payload"].get("status") != "ok":
                    sys.exit(f"FAILED  could not follow the database changes: {message['payload']}")
                followed = True
            return joined and followed

        try:
            await receive_until(socket, subscription_ready, 30)
        except asyncio.TimeoutError:
            sys.exit("FAILED  the subscription did not become active within 30 seconds")
        print("ok      subscribed to live order changes over the WebSocket")

        rpc("apply_payment_event", SECRET, p_provider="fake", p_event_id=f"evt-{uuid.uuid4()}",
            p_order_id=order_id, p_type="succeeded")

        # Realtime may still deliver the changes made before we subscribed (the
        # order being created); those show the order waiting for payment, and are
        # skipped. The first update after that must be the finished one.
        waiting = ("pending_payment", "pending")

        def paid_update(message):
            if message["event"] != "postgres_changes":
                return False
            record = message["payload"]["data"].get("record", {})
            return record.get("id") == order_id and (record["status"], record["payment_status"]) != waiting

        try:
            event = await receive_until(socket, paid_update, 15)
        except asyncio.TimeoutError:
            sys.exit("FAILED  the paid order did not arrive live within 15 seconds")

    # A payment changes the status and the payment status in one step: nobody
    # following the order sees a half-done state such as "paid, but waiting".
    record = event["payload"]["data"]["record"]
    if (record["status"], record["payment_status"]) != ("received", "succeeded"):
        sys.exit(f"FAILED  the first live update after payment was a half-done state: {record['status']}, {record['payment_status']}")
    print("ok      the customer received the paid order live, in one consistent update (received, succeeded)")
    print("\nRealtime works end to end.")


asyncio.run(main())
