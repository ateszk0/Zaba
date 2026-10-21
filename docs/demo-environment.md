# A demó környezet (Cloudflare + Supabase Free)

Ez a leírás vezet végig azon, hogyan kerül fel a demó a megrendelőnek adható, stabil címekre. Három statikus oldal fut a Cloudflare-en
(vásárlói app, admin oldal, Android letöltő oldal), a backend egy ingyenes Supabase projekt. A saját szerveres staging (Proxmox,
Cloudflare Tunnel) ettől független, a fejlesztésé: [`deploy/selfhost/README.md`](../deploy/selfhost/README.md).

| Rész | Hol fut | Honnan épül | Cím |
|---|---|---|---|
| Vásárlói app | Cloudflare (Worker, csak statikus fájlok) | `deploy/demo/build-web.sh app` | `https://zaba-app.<fiók>.workers.dev` |
| Admin oldal | ugyanott, külön oldal | `deploy/demo/build-web.sh admin` | `https://zaba-admin.<fiók>.workers.dev` |
| Android APK | ugyanott, külön oldal | `deploy/demo/build-apk.sh` | `https://zaba-apk.<fiók>.workers.dev` |
| Backend | Supabase Free (felhő) | `supabase/` mappa (`setup-supabase.sh`) | `https://<projekt>.supabase.co` |

A saját domainedre is rá lehet tenni mindhármat (Cloudflare dashboard, Workers & Pages, az oldal Settings, Domains & Routes): ez a
`workers.dev` címek helyett szebb linket ad, és ugyanúgy ingyenes.

## Miért nem Pages

A tervben Cloudflare Pages szerepelt. A Cloudflare dokumentációja szerint a Pages tovább működik, de az **új projektekhez a Workers
Static Assets az ajánlott** út, és az újdonságok oda érkeznek. Ugyanaz az ingyenes statikus kiszolgálás (a statikus fájlok kérései
ingyenesek és korlátlanok, 20 000 fájl és 25 MiB fájlonként a korlát; a build 93 fájl, a legnagyobb 7,3 MB), ugyanaz a `_headers`
fájl. Ezért az oldalak Workers Static Assets-ként mennek, egy kis `wrangler.*.jsonc` fájllal (`deploy/demo/`).

## Amit neked kell megcsinálnod (egyszer)

Titkot nem kérek tőled a chatben: a tokeneket és jelszavakat csak a saját gépeden, a parancsok idejére add meg.

### 1. Cloudflare

1. A fiókodban (a domainedhez használt) a **Workers & Pages** menüben a `workers.dev` aldomain regisztrálása, ha még nincs (egyszer, a
   dashboard kéri).
2. Belépés a gépeden: `npx wrangler login` (böngészőben jóváhagyod), **vagy** API token: dashboard, My Profile, API Tokens, Create Token,
   sablon *Edit Cloudflare Workers*. A token és az *Account ID* (a Workers & Pages áttekintőn) kell a GitHub workflow-hoz is.

### 2. Supabase

1. Új projekt: <https://supabase.com/dashboard>, New project, **Free** csomag, régió **Frankfurt** (EU). A megadott **adatbázis-jelszót** mentsd el
   (jelszókezelőbe), a projekt nevét hívhatod `zaba-demo`-nak.
2. Kellenek: a **projekt azonosítója** (Project Settings, General, Reference ID), a **publishable key** (Project Settings, API Keys), a **secret
   key** (ugyanott; csak a gépeden, a staff fiók létrehozásához és a teszthez kell), és egy **account token** (Account, Access Tokens).
3. Egy egyszeri beállítás a dashboardon (Authentication): *Email* szolgáltatónál a **Confirm email kapcsoló legyen KI** (a demó nem küld
   levelet), a regisztráció legyen engedélyezve, és a *URL Configuration* Site URL-je legyen a vásárlói app címe. Ha ez kimarad, a
   `create_demo_user.py` hibát ad ("The project wants the email confirmed first").

### 3. GitHub (a napi életben tartáshoz és a kézi telepítéshez)

Repository, Settings, Secrets and variables, Actions:

| Név | Típus | Érték |
|---|---|---|
| `DEMO_SUPABASE_URL` | variable | `https://<projekt>.supabase.co` |
| `DEMO_SUPABASE_KEY` | secret | a publishable key (az app is ezt kapja, publikus) |
| `DEMO_EMAIL`, `DEMO_PASSWORD` | variable, secret | a demó vásárlói fiók (lásd lent; a jelszó az appba van fordítva) |
| `CLOUDFLARE_API_TOKEN`, `CLOUDFLARE_ACCOUNT_ID` | secret | csak a `Deploy the demo web apps` workflow-hoz |

A `keepalive` workflow addig nem csinál semmit, amíg a `DEMO_SUPABASE_URL` nincs beállítva.

## Telepítés, lépésről lépésre

A repó gyökeréből, `npm ci` után (a Supabase CLI és a Cloudflare `wrangler` rögzített verzióban a `package.json`-ban van).

### A. A backend

```sh
export SUPABASE_ACCESS_TOKEN=...      # account token
export SUPABASE_PROJECT_REF=...       # projekt azonosító
export SUPABASE_DB_PASSWORD=...       # az adatbázis jelszava
export FAKE_PAYMENT_WEBHOOK_SECRET="$(openssl rand -hex 32)"   # mentsd el: a fizetési függvények és a teszt is ezt kéri
deploy/demo/setup-supabase.sh first   # új, üres projektre: séma, demó étlap, függvények, titok
```

Később (új migráció, módosított függvény): ugyanez `update` móddal, a demó étlapot nem tölti be újra. A függvények
JWT-ellenőrzése függvényenként a `supabase/config.toml`-ban van (a webhook és a kártyalépés maga hitelesít, mert a fizetési szolgáltatónak
nincs Supabase tokenje, és az ellenőrzés az új publishable/secret kulcsokat nem ismeri).

### B. A demó fiókok

```sh
export SUPABASE_URL=https://<projekt>.supabase.co
export SUPABASE_PUBLISHABLE_KEY=<publishable key>
export DEMO_EMAIL=... DEMO_PASSWORD=...             # egy eldobható fiók, a jelszó az appban lesz
python3 tool/create_demo_user.py

export SUPABASE_SECRET_KEY=<secret key>             # csak erre a lépésre
STAFF_EMAIL=... STAFF_PASSWORD=... python3 tool/create_staff_user.py --role operator
unset SUPABASE_SECRET_KEY
```

### C. Az oldalak

```sh
cp config/demo.example.json config/demo.json        # kitöltöd: APP_ENV=demo, SUPABASE_URL, SUPABASE_ANON_KEY (a publishable key), DEMO_*
deploy/demo/deploy-web.sh app
deploy/demo/deploy-web.sh admin
```

A `config/demo.json` nincs a repóban (gitignore), és csak publikus értéket tartalmaz. **Az `ADMIN_DEMO_EMAIL` és az `ADMIN_DEMO_PASSWORD`
ne legyen benne** abban a buildben, amit a megrendelő megnyithat: a jelszó egy nyilvános oldalban ülne, és bárki kezelhetné az admint. Az
admin belépéséhez a munkatárs gépelje be a jelszót. Ugyanezt a két oldalt kézzel indítható GitHub workflow is telepíti
(`Actions, Deploy the demo web apps, Run workflow`), ugyanazzal a scripttel.

### D. Az Android app

```sh
tool/android/create_demo_keystore.sh   # egyszer: az aláíró kulcs a ~/.zaba-keys/ mappába kerül (a repón kívül), mentsd el
deploy/demo/deploy-web.sh apk          # megépíti, aláírja, ellenőrzi, és feltölti a letöltő oldalra
```

Az APK csak 64 bites ARM-re készül (gyakorlatilag minden Android telefon 2017 óta); a 32 bitessel együtt ~40 MB lenne, a Cloudflare pedig
25 MiB-nál nagyobb fájlt nem szolgál ki. A telepítéshez a telefon rákérdez, hogy engedélyezed-e az ismeretlen forrásból való telepítést:
a letöltő oldalon ez le van írva. **Az `applicationId` (`hu.zaba.zaba`) helyőrző**: az átadáskor a végleges tulajdonos a sajátját választja,
és a saját kulcsával ír alá. Az aláíró kulcs elvesztése esetén egy már telepített APK-t nem lehet frissíteni (az új aláírás miatt a telefon
elutasítja), csak eltávolítani és újratelepíteni.

### E. Ellenőrzés

```sh
python3 tool/check_demo.py --app https://zaba-app.<fiók>.workers.dev --admin https://zaba-admin.<fiók>.workers.dev \
  --supabase-url https://<projekt>.supabase.co --key <publishable key>
```

Csak olvas: a fejléceket, az étlapot és azt nézi, hogy a fizetési függvények telepítve vannak és megvan a titkuk. A teljes folyamatot
(regisztráció, rendelés, fizetés, támadások) a `supabase/tests/api_smoke.py` és a `payment_smoke.py` próbálja végig a felhős projekten is
(környezeti változókkal, lásd a fájlok tetejét), de **teszt felhasználókat és rendeléseket hoznak létre**: egyszer, átadás előtt futtasd, és
utána töröld őket (Dashboard, SQL editor; a tesztfiókok mind `@example.test` végűek):

```sql
delete from public.orders where user_id in (select id from auth.users where email like '%@example.test');
delete from auth.users where email like '%@example.test';
-- a lefoglalt helyek számlálója a megmaradt rendelésekhez igazodik
update public.delivery_slots s set booked =
  (select count(*) from public.orders o where o.slot_id = s.id and o.status <> 'cancelled');
```

## Mielőtt a megrendelőnek megmutatod

- Aktív-e a projekt (a Free csomag egy hét inaktivitás után szüneteltet; a napi `keepalive` ezt megakadályozza, de a bemutató előtti napon
  nézd meg a Supabase dashboardot, és futtasd le egyszer kézzel a workflow-t).
- Betölt-e az app a telefonodon, belép-e a demó fiókkal, le lehet-e adni és kifizetni egy rendelést, megjelenik-e az adminban, és a váltás
  megjelenik-e a telefonon. (A telefonos ellenőrző lista az i lépésben készül el.)
- A DEMÓ szalag látszik mindenhol.

## Ingyenes szint, limitek (2026. október, a gyártók dokumentációja alapján)

- **Supabase Free:** 2 projekt, 500 MB adatbázis (a demó néhány MB), 5 GB egress, 50 000 aktív felhasználó, 200 egyidejű Realtime kapcsolat. **Egy hét
  inaktivitás után a projekt szünetel**, a dashboardról visszaállítható (90 napig). Ha később szükséges, a *Pro* csomag a szüneteltetést megszünteti.
- **Cloudflare Workers Static Assets (Free):** korlátlan, ingyenes statikus kérés; 20 000 fájl és 25 MiB fájlonként; 100 Worker a fiókban.
- **GitHub Actions:** privát repóban a havi ingyenes perckeret bőven elég a napi pingre és a ritka kézi telepítésre.

## Ismert hiányok és mi nem volt kipróbálva

- A **felhős Supabase projekten és a Cloudflare-en még nem futott semmi** (ehhez a te fiókjaid kellenek). Helyben teszteltem: a lokális Supabase stacken
  és a Cloudflare ugyanazon `workerd` futtatókörnyezetével (`wrangler dev`) a ténylegesen kiadott fájlokat és fejléceket.
- iPhone Safari és Android Chrome böngészőben nem próbáltam; az Android app egy emulátoron futott (belépés, kosár, újraindítás), valódi telefonon nem.
- Az iOS biztonságos terület (notch, alsó sáv), a billentyűzet és a kezdőképernyős mód ellenőrzése a telefonos lista (i lépés) dolga.
- Az app saját rendszerfontja a bundle-ölt betűkön kívül nincs (a Content-Security-Policy a külső tartalék betöltést tiltja): a
  Baloo 2 és az Inter latin és latin-kiterjesztett készletén kívüli karakter (emoji, cirill, kínai) egy **doboz** (□) lesz. Az étlap és a felület ilyet
  nem használ, de a vásárló megjegyzésében előfordulhat.
