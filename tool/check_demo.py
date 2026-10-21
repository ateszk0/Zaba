#!/usr/bin/env python3
"""Checks a deployed demo environment from the outside, without changing anything
(it only reads): the pages answer with their security headers, the menu is served
from the backend, the payment functions are deployed and have their secret.

    python3 tool/check_demo.py --app https://zaba-app.example.workers.dev \\
        --admin https://zaba-admin.example.workers.dev \\
        --supabase-url https://REF.supabase.co --key sb_publishable_...

--admin is optional. The key is the public key the app ships with. Nothing is
printed that is secret. Exits with 1 if a check fails.
"""

import argparse
import json
import sys
import urllib.error
import urllib.request
from urllib.parse import urlparse

parser = argparse.ArgumentParser()
parser.add_argument("--app", required=True)
parser.add_argument("--admin")
parser.add_argument("--supabase-url", required=True)
parser.add_argument("--key", required=True)
args = parser.parse_args()

failures = []


def check(name, condition, detail=""):
    print(("ok      " if condition else "FAILED  ") + name + (f"  [{detail}]" if detail and not condition else ""))
    if not condition:
        failures.append(name)


def fetch(url, method="GET", headers=None, body=None):
    request = urllib.request.Request(url, method=method, headers=headers or {}, data=body)
    try:
        with urllib.request.urlopen(request, timeout=30) as response:
            return response.status, dict((k.lower(), v) for k, v in response.headers.items()), response.read()
    except urllib.error.HTTPError as error:
        return error.code, dict((k.lower(), v) for k, v in error.headers.items()), error.read()


backend_host = urlparse(args.supabase_url).netloc

for label, url in [("app", args.app), ("admin", args.admin)]:
    if not url:
        continue
    status, headers, body = fetch(url.rstrip("/") + "/")
    check(f"the {label} page answers", status == 200 and b"flutter_bootstrap.js" in body, status)
    csp = headers.get("content-security-policy", "")
    check(f"the {label} page has a content security policy that names the backend", backend_host in csp and "default-src 'self'" in csp, csp[:80])
    check(f"the {label} page cannot be framed or sniffed",
          headers.get("x-content-type-options") == "nosniff" and "frame-ancestors 'none'" in csp)
    check(f"the {label} page is kept out of search engines", "noindex" in headers.get("x-robots-tag", ""))
    check(f"the {label} start files are never cached", "no-cache" in headers.get("cache-control", ""))
    status, headers, _ = fetch(url.rstrip("/") + "/canvaskit/canvaskit.wasm")
    check(f"the {label} serves its own rendering engine (nothing from a third-party CDN)", status == 200, status)

status, _, body = fetch(f"{args.supabase_url.rstrip('/')}/rest/v1/catalog_products?select=id&limit=3",
                        headers={"apikey": args.key})
rows = json.loads(body) if status == 200 else []
check("the backend serves the menu to a guest", status == 200 and len(rows) == 3, status)

# An unsigned event must be refused by the function itself (400). 500 would mean the
# payment secret is not set; 404, that the functions are not deployed.
status, _, body = fetch(f"{args.supabase_url.rstrip('/')}/functions/v1/payments-webhook", method="POST",
                        headers={"Content-Type": "application/json"}, body=b"{}")
check("the payment webhook is deployed and refuses an unsigned event", status == 400 and b"invalid_webhook" in body,
      f"{status} {body[:80]!r} (500 = FAKE_PAYMENT_WEBHOOK_SECRET missing, 404 = functions not deployed)")

status, _, body = fetch(f"{args.supabase_url.rstrip('/')}/functions/v1/payments-create", method="POST",
                        headers={"Content-Type": "application/json", "apikey": args.key}, body=b'{"order_id":"x"}')
check("starting a payment needs a signed-in customer", status == 401, status)

status, _, _ = fetch(f"{args.supabase_url.rstrip('/')}/rest/v1/orders?select=id", headers={"apikey": args.key})
check("a guest cannot read orders", status in (401, 403), status)

print()
if failures:
    sys.exit(f"{len(failures)} check(s) failed")
print("The demo environment looks right.")
