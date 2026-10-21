"""Small helper around the Wikimedia Commons API, used by the product photo tools.

Only photos whose license is CC0, public domain or CC BY (attribution only) are
accepted. Share-alike (SA), non-commercial (NC) and no-derivatives (ND) licences
are rejected: the photos are resized and cropped, and the app is handed over to
a customer.
"""

import json
import re
import time
import urllib.parse
import urllib.request

API = "https://commons.wikimedia.org/w/api.php"
# Wikimedia asks for a descriptive User-Agent with a way to contact us.
USER_AGENT = "ZabaDemo/0.1 (demo app product photos; atis.nagy04@gmail.com)"

ACCEPTED_LICENSES = re.compile(r"^(CC0|Public domain|PDM.*|CC BY (2\.0|2\.5|3\.0|4\.0))$", re.IGNORECASE)


def api(params):
    url = API + "?" + urllib.parse.urlencode({**params, "format": "json"})
    request = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
    with urllib.request.urlopen(request, timeout=40) as response:
        time.sleep(0.25)
        return json.load(response)


def fetch_bytes(url):
    request = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
    for attempt in range(4):
        try:
            with urllib.request.urlopen(request, timeout=60) as response:
                time.sleep(0.25)
                return response.read()
        except urllib.error.HTTPError as error:
            if error.code != 429 or attempt == 3:
                raise
            time.sleep(3 * (attempt + 1))


def _meta(info, key):
    return re.sub(r"<[^>]+>", "", info["extmetadata"].get(key, {}).get("value", "")).strip()


def describe(page):
    info = page["imageinfo"][0]
    return {
        "title": page["title"],
        "width": info["width"],
        "height": info["height"],
        "thumb_url": info.get("thumburl"),
        "url": info["url"],
        "page_url": info["descriptionurl"],
        "license": _meta(info, "LicenseShortName"),
        "license_url": _meta(info, "LicenseUrl"),
        "author": _meta(info, "Artist"),
    }


def search(query, limit=12, thumb_width=480):
    """Photos for `query`, best match first, with an accepted license."""
    data = api({
        "action": "query", "generator": "search", "gsrsearch": f"{query} filetype:bitmap",
        "gsrnamespace": 6, "gsrlimit": limit, "prop": "imageinfo",
        "iiprop": "url|extmetadata|size|mime", "iiurlwidth": thumb_width,
    })
    pages = sorted(data.get("query", {}).get("pages", {}).values(), key=lambda p: p.get("index", 0))
    found = []
    for page in pages:
        item = describe(page)
        if item["width"] >= 900 and ACCEPTED_LICENSES.match(item["license"]) and item["thumb_url"]:
            found.append(item)
    return found


def file_info(title, width=1000):
    data = api({
        "action": "query", "titles": title, "prop": "imageinfo",
        "iiprop": "url|extmetadata|size|mime", "iiurlwidth": width,
    })
    page = next(iter(data["query"]["pages"].values()))
    return describe(page)
