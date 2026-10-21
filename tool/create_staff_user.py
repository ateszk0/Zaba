#!/usr/bin/env python3
"""Creates a staff account for the admin page (a kitchen operator or an
administrator). Safe to run again: an existing account keeps its password, and
only its role is brought up to date.

    python3 tool/create_staff_user.py --from-local --role operator
    python3 tool/create_staff_user.py --from-local --role admin

`--from-local` reads URL and keys from `npx supabase status` and uses the demo
staff accounts below. For any other environment set SUPABASE_URL,
SUPABASE_PUBLISHABLE_KEY (the public key the app ships with), SUPABASE_SECRET_KEY
(the service-role / secret key: it is what may create staff, so keep it out of
the chat and the repository), STAFF_EMAIL and STAFF_PASSWORD.

The account is created through the public sign-up endpoint; the staff row is
written with the secret key. Passwords and keys are never printed.
"""

import argparse
import json
import os
import subprocess
import sys
import urllib.error
import urllib.request

LOCAL_STAFF = {
    "operator": ("konyha@zaba.example", "Konyha-jelszo-1"),
    "admin": ("admin@zaba.example", "Admin-jelszo-1"),
}

parser = argparse.ArgumentParser()
parser.add_argument("--role", choices=["operator", "admin"], required=True)
parser.add_argument("--from-local", action="store_true")
args = parser.parse_args()


def load_config():
    if args.from_local:
        out = subprocess.run(["npx", "supabase", "status", "-o", "json"], capture_output=True, text=True, check=True).stdout
        data = json.loads(out[out.index("{"):])
        email, password = LOCAL_STAFF[args.role]
        return (data["API_URL"], data["PUBLISHABLE_KEY"], data["SECRET_KEY"],
                os.environ.get("STAFF_EMAIL", email), os.environ.get("STAFF_PASSWORD", password))
    try:
        return (os.environ["SUPABASE_URL"], os.environ["SUPABASE_PUBLISHABLE_KEY"], os.environ["SUPABASE_SECRET_KEY"],
                os.environ["STAFF_EMAIL"], os.environ["STAFF_PASSWORD"])
    except KeyError as missing:
        sys.exit(f"Missing environment variable {missing}, or pass --from-local")


API, PUBLISHABLE, SECRET, EMAIL, PASSWORD = load_config()


def request(method, path, key, body=None, token=None, extra=None):
    headers = {"apikey": key, "Content-Type": "application/json", **(extra or {})}
    # The new-style keys are not JWTs: they go in `apikey` only.
    if token or key.startswith("eyJ"):
        headers["Authorization"] = f"Bearer {token or key}"
    data = json.dumps(body).encode() if body is not None else None
    req = urllib.request.Request(f"{API}{path}", data=data, method=method, headers=headers)
    try:
        with urllib.request.urlopen(req, timeout=30) as response:
            text = response.read().decode()
            return response.status, (json.loads(text) if text else None)
    except urllib.error.HTTPError as error:
        text = error.read().decode()
        try:
            return error.code, json.loads(text)
        except ValueError:
            return error.code, {"raw": text[:200]}


# An account that already exists is only promoted: signing in with its password proves the
# person running this knows it, and gives the id the staff row needs.
status, session = request("POST", "/auth/v1/token?grant_type=password", PUBLISHABLE, {"email": EMAIL, "password": PASSWORD})
if status == 200:
    print(f"the account {EMAIL} already exists, password matches")
else:
    status, session = request("POST", "/auth/v1/signup", PUBLISHABLE, {"email": EMAIL, "password": PASSWORD, "data": {"full_name": f"Munkatárs ({args.role})"}})
    if status == 200 and "access_token" in (session or {}):
        print(f"created the account {EMAIL}")
    elif (session or {}).get("error_code") in ("user_already_exists", "email_exists"):
        sys.exit(f"The account {EMAIL} exists, but with a different password.")
    elif status == 200:
        sys.exit(f"The project wants the e-mail address confirmed first, so the account {EMAIL} cannot sign in yet. "
                 "Confirm it (or create the user in the dashboard: Authentication, Users, Add user, with Auto Confirm), "
                 "then run this tool again to give it the role.")
    elif (session or {}).get("error_code") in ("signup_disabled", "email_provider_disabled"):
        sys.exit("Sign-up is switched off on this project. Create the user in the dashboard (Authentication, Users, "
                 f"Add user, with Auto Confirm) as {EMAIL}, then run this tool again to give it the role.")
    else:
        sys.exit(f"Could not create the account: HTTP {status} {(session or {}).get('error_code') or (session or {}).get('msg') or session}")

user_id = session["user"]["id"]
status, body = request(
    "POST", "/rest/v1/admin_users?on_conflict=user_id", SECRET, {"user_id": user_id, "role": args.role},
    extra={"Prefer": "resolution=merge-duplicates,return=minimal"},
)
if status not in (200, 201, 204):
    sys.exit(f"Could not set the staff role: HTTP {status} {body}")

# Check it the way the admin page will: as the staff member.
status, rows = request("GET", "/rest/v1/admin_users?select=role", PUBLISHABLE, token=session["access_token"])
if status != 200 or rows != [{"role": args.role}]:
    sys.exit(f"The role does not read back as {args.role}: HTTP {status} {rows}")
print(f"{EMAIL} is staff, role {args.role}")
