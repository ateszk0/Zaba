#!/usr/bin/env python3
"""Creates the demo customer behind the app's "sign in with the demo account"
button. Safe to run again: an existing account is left as it is, as long as its
password matches.

    python3 tool/create_demo_user.py --from-local

`--from-local` reads URL and key from `npx supabase status` and uses the demo
account of config/dev.example.json. For any other environment set
SUPABASE_URL, SUPABASE_PUBLISHABLE_KEY (the public key the app ships with: the
sb_publishable_ key or the anon JWT), DEMO_EMAIL and DEMO_PASSWORD, the same
values as in that environment's config/<env>.json.

It only uses the public sign-up endpoint, so no secret is involved. The
account is a throw-away with invented data; the password is shipped in the app.
The password is never printed.
"""

import json
import os
import subprocess
import sys
import urllib.error
import urllib.request

LOCAL_DEMO_EMAIL = "demo@zaba.example"
LOCAL_DEMO_PASSWORD = "Demo-jelszo-1"
FULL_NAME = "Demó Dóra"


def load_config():
    if "--from-local" in sys.argv:
        out = subprocess.run(["npx", "supabase", "status", "-o", "json"], capture_output=True, text=True, check=True).stdout
        data = json.loads(out[out.index("{"):])
        return (
            data["API_URL"],
            data["PUBLISHABLE_KEY"],
            os.environ.get("DEMO_EMAIL", LOCAL_DEMO_EMAIL),
            os.environ.get("DEMO_PASSWORD", LOCAL_DEMO_PASSWORD),
        )
    try:
        return (
            os.environ["SUPABASE_URL"],
            os.environ["SUPABASE_PUBLISHABLE_KEY"],
            os.environ["DEMO_EMAIL"],
            os.environ["DEMO_PASSWORD"],
        )
    except KeyError as missing:
        sys.exit(f"Missing environment variable {missing}, or pass --from-local")


API, KEY, EMAIL, PASSWORD = load_config()


def post(path, body):
    request = urllib.request.Request(
        f"{API}{path}",
        data=json.dumps(body).encode(),
        method="POST",
        headers={"apikey": KEY, "Content-Type": "application/json"},
    )
    try:
        with urllib.request.urlopen(request, timeout=30) as response:
            return response.status, json.loads(response.read().decode() or "null")
    except urllib.error.HTTPError as error:
        text = error.read().decode()
        try:
            return error.code, json.loads(text)
        except ValueError:
            return error.code, {"raw": text[:200]}


status, body = post("/auth/v1/signup", {"email": EMAIL, "password": PASSWORD, "data": {"full_name": FULL_NAME}})
if status == 200 and "access_token" in (body or {}):
    print(f"created the demo account {EMAIL}")
elif status == 200:
    sys.exit("The project wants the email confirmed first. Turn email confirmation off for the demo (see docs/decisions.md).")
elif (body or {}).get("error_code") in ("user_already_exists", "email_exists"):
    status, _ = post("/auth/v1/token?grant_type=password", {"email": EMAIL, "password": PASSWORD})
    if status == 200:
        print(f"the demo account {EMAIL} already exists, password matches")
    else:
        sys.exit(f"The account {EMAIL} exists, but with a different password. Fix it in Studio, or choose another DEMO_EMAIL.")
else:
    sys.exit(f"Could not create the demo account: HTTP {status} {(body or {}).get('error_code') or (body or {}).get('msg') or body}")
