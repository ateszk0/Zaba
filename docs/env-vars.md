# Környezeti változók és titkok

Minden érték, amit a Zaba bármelyik része beállításként olvas, egy helyen. A lista a kódból és a scriptekből készült (nem emlékezetből), a
sablonfájlok: [`.env.example`](../.env.example), [`config/*.example.json`](../config), [`supabase/.env.example`](../supabase/.env.example),
[`deploy/selfhost/zaba-selfhost.env.example`](../deploy/selfhost/zaba-selfhost.env.example).

**Az alapszabály:** a kliensbe (web build, APK) csak **publikus** érték kerülhet, mert ami a buildben van, azt bárki kiolvashatja. A titkok csak a
szerveren (Edge Function környezet, a szerver `.env`-je), a fejlesztő gépén (környezeti változó, git-ignorált fájl) vagy a GitHub titkai között élnek.
A repóban titok nincs; ezt a CI minden futásnál a teljes történeten ellenőrzi (gitleaks), és a `.gitleaks.toml` csak a **szándékosan publikus, helyi
fejlesztői** értékeket engedi át (a helyi demó fiókok jelszavai).

Jelölés: **P** = publikus (a buildbe kerülhet), **T** = titkos (soha nem kerülhet az appba, a webes buildbe vagy a gitbe).

## 1. Az app (build időben, `--dart-define-from-file=config/<env>.json`)

A valódi `config/*.json` fájlok git-ignoráltak; csak a `*.example.json` sablon van a repóban.

| Név | | Mire | Honnan |
|---|---|---|---|
| `APP_ENV` | P | `dev`, `staging` vagy `demo`; a `demo` elrejti a fejlesztői képernyőket | te adod meg |
| `SUPABASE_URL` | P | a Supabase projekt címe; **hiányában az app memóriabeli adatokkal fut**, backend nélkül | Supabase dashboard, vagy `supabase status`, vagy a saját szerver telepítője |
| `SUPABASE_ANON_KEY` | P | a publikus kulcs (`sb_publishable_…`, vagy a régi „anon" JWT). A neve történeti, az új kulcsot is ez viszi. **A saját szerveres Realtime a JWT-t kéri**, nem a `sb_publishable_` kulcsot | Supabase dashboard, API Keys; saját szerveren a telepítő írja ki |
| `DEMO_EMAIL`, `DEMO_PASSWORD` | P | a „Belépés demó fiókkal" gomb fiókja. **Szándékosan nyilvános**: az app tartalmazza, ezért eldobható fiók, kitalált adatokkal | `tool/create_demo_user.py` |
| `ADMIN_DEMO_EMAIL`, `ADMIN_DEMO_PASSWORD` | P, de **vigyázz** | az admin oldal „Belépés demó munkatársként" gombja. **Csak helyi fejlesztéshez**: a megrendelő által megnyitható buildből hagyd ki, mert a jelszó egy nyilvános oldalban ülne, és bárki kezelhetné az admint | `tool/create_staff_user.py` |

## 2. A tesztek (`flutter test`, `--dart-define`)

| Név | | Mire |
|---|---|---|
| `ZABA_TEST_SUPABASE_URL` | P | az integrációs tesztek célja (helyi stack, `http://127.0.0.1:54321`); nélküle az integrációs tesztek kimaradnak |
| `ZABA_TEST_SUPABASE_KEY` | P | a publikus kulcsa |
| `ZABA_TEST_SUPABASE_SECRET_KEY` | **T** | a titkos kulcs; csak az admin tesztekhez kell (munkatársi fiókot hoznak létre). **Csak helyi stackkel használd**, éles projekttel soha |

## 3. A szerveroldali függvények (Edge Functions: `payments-create`, `fake-provider-confirm`, `payments-webhook`)

| Név | | Mire | Hol áll be |
|---|---|---|---|
| `FAKE_PAYMENT_WEBHOOK_SECRET` | **T** | a szimulált fizetési szolgáltató aláíró titka (HMAC); **nélküle a függvények nem működnek**. Éles szolgáltatónál ennek helyére a szolgáltató webhook-titka kerül | helyben: `supabase/.env` (a `config.toml` `[edge_runtime.secrets]` adja át); felhőben: `supabase secrets set` (a `deploy/demo/setup-supabase.sh` végzi); saját szerveren a telepítő generálja |
| `SUPABASE_URL` | – | a függvény saját projektjének címe; **a platform adja** | automatikus |
| `SUPABASE_PUBLISHABLE_KEYS` | – | a platform JSON-szótára az új publikus kulcsokkal (`{"default": "sb_publishable_…"}`); a `payments-create` használja | automatikus (felhő) |
| `SUPABASE_SECRET_KEYS` | – | ugyanez a titkos kulcsokkal; a `payments-webhook` használja | automatikus (felhő) |
| `SUPABASE_ANON_KEY`, `SUPABASE_SERVICE_ROLE_KEY` | – | a **régi** kulcsok; tartalék, ha a szótár nincs. A Supabase 2026 végéig kivezeti őket | automatikus |

A függvény az új kulcsot részesíti előnyben, és a régire esik vissza (`supabase/functions/_shared/keys.ts`, Node-tesztekkel). A JWT-ellenőrzés függvényenként a
`supabase/config.toml`-ban van: a `payments-create` ellenőriz, a webhook és a kártyalépés nem (maguk hitelesítenek, mert a szolgáltatónak nincs Supabase tokenje).

## 4. Segédscriptek és tesztek (`tool/`, `supabase/tests/`)

A legtöbbjük `--from-local` kapcsolóval a helyi stackből (`npx supabase status`) olvassa a címet és a kulcsokat; máshol ezek a változók kellenek.
A `tool/check_demo.py` **nem** környezeti változót olvas, hanem parancssori kapcsolókat (`--app`, `--admin`, `--supabase-url`, `--key`).

| Név | | Ki használja |
|---|---|---|
| `SUPABASE_URL` | P | minden script és smoke teszt |
| `SUPABASE_PUBLISHABLE_KEY` | P | `create_demo_user.py`, `create_staff_user.py`, a három smoke teszt (`api_smoke.py`, `realtime_smoke.py`, `payment_smoke.py`) |
| `SUPABASE_ANON_KEY` | P | `realtime_smoke.py`, `payment_smoke.py` (a régi JWT-kulcs; a saját szerveres Realtime ezt kéri) |
| `SUPABASE_SECRET_KEY` | **T** | `create_staff_user.py` (munkatársi fiók és jogosultság), `api_smoke.py`, `realtime_smoke.py`; **csak arra a pár percre add meg, és utána `unset`** |
| `DEMO_EMAIL`, `DEMO_PASSWORD` | P | `create_demo_user.py` (helyben alapértelmezett: `demo@zaba.example` / `Demo-jelszo-1`) |
| `STAFF_EMAIL`, `STAFF_PASSWORD` | **T** | `create_staff_user.py` (helyben alapértelmezett: `konyha@zaba.example`, `admin@zaba.example`; éles fiókhoz erős, egyedi jelszó) |
| `FAKE_PAYMENT_WEBHOOK_SECRET` | **T** | `payment_smoke.py` (ugyanaz az érték, mint a függvényeké) |

## 5. Telepítés (a fejlesztő gépéről)

| Név | | Ki használja | Honnan |
|---|---|---|---|
| `SUPABASE_ACCESS_TOKEN` | **T** | `deploy/demo/setup-supabase.sh` (a Supabase CLI) | dashboard, Account, Access Tokens |
| `SUPABASE_PROJECT_REF` | P | ugyanaz | a projekt azonosítója (a `.supabase.co` előtti rész) |
| `SUPABASE_DB_PASSWORD` | **T** | ugyanaz | a projekt létrehozásakor megadott adatbázis-jelszó |
| `FAKE_PAYMENT_WEBHOOK_SECRET` | **T** | ugyanaz; `openssl rand -hex 32`, legalább 32 karakter | te generálod, **mentsd el** |
| `CLOUDFLARE_API_TOKEN`, `CLOUDFLARE_ACCOUNT_ID` | **T** (a token); az azonosító nem titok, de ne tedd közzé | `deploy/demo/deploy-web.sh` (Wrangler); helyette lehet `npx wrangler login` | Cloudflare dashboard |
| `ZABA_BUILD_OUT` | – | csak a `tool/lan_preview.sh` állítja, hogy a telefonos próba ne írja felül a telepítendő buildet | belső |

## 6. Android aláírás

| Név | | Mire |
|---|---|---|
| `ZABA_KEY_PASSWORD` | **T** | csak a `tool/android/create_demo_keystore.sh` olvassa (a kulcstár jelszava, `keytool -storepass:env`); a script generálja |
| `ZABA_KEYS_DIR` | – | hova kerül a kulcstár (alapértelmezés: `~/.zaba-keys`, **a repón kívül**) |
| `app/android/key.properties` | **T** (git-ignorált fájl) | `storeFile`, `storePassword`, `keyAlias`, `keyPassword`; a `build.gradle.kts` ebből ír alá. Ha nincs, a build a debug kulccsal ír alá, a `build-apk.sh` ezt visszautasítja |

A kulcstár elvesztése esetén egy már telepített APK nem frissíthető (az új aláírást a telefon elutasítja), csak eltávolítható és újratelepíthető.
Az `applicationId` (`hu.zaba.zaba`) **helyőrző**; az átadáskor a tulajdonos a sajátját és a saját kulcsát választja ([`handover.md`](handover.md)).

## 7. Saját szerveres staging (`deploy/selfhost/`)

A `zaba-selfhost.env` (git-ignorált, mintája a `zaba-selfhost.env.example`) a **nem titkos** beállításokat és a tunnel tokenjét tartalmazza:

| Név | | Mire |
|---|---|---|
| `ZABA_APP_HOST`, `ZABA_API_HOST`, `ZABA_ADMIN_HOST` | P | a három nyilvános név, egy domain alatt, mind ugyanazon a Cloudflare Tunnelen |
| `ZABA_PUBLIC_SCHEME` | P | `https` a tunnel mögött; csak egy saját gépen végzett próbához `http` |
| `ZABA_STACK_DIR` | – | hova települ a stack a szerveren |
| `CLOUDFLARE_TUNNEL_TOKEN` | **T** | a tunnel tokenje; üresen is indul a stack, a tunnel nélkül |
| `SUPABASE_SELFHOST_REF` | – | a hivatalos Supabase self-host kiadás, amelyhez a kit rögzítve van; a váltás frissítés, előbb a kiadás CHANGELOG-ját olvasd |
| `ZABA_HTTP_BIND`, `ZABA_HTTP_PORT` | – | közvetlen elérés a tunnel nélkül (pl. telefonról ugyanazon a Wi-Fi-n) |
| `ZABA_SELFHOST_ENV`, `ZABA_REMOTE_STACK_DIR` | – | a telepítő és a `deploy-web.sh` által használt útvonalak |

**A stack titkait** (adatbázis-jelszó, JWT-titok, API-kulcsok, a Studio jelszava, a webhook-titok) a telepítő **generálja a szerveren**, a stack saját `.env`
fájljába, és soha nem kerülnek a repóba vagy a beszélgetésbe. A telepítő a hivatalos `.env.example`-t másolja, és **rögtön kulcsot generál** (`generate-keys.sh`), mielőtt bármi elindulna: a helyőrző kulcsokkal a stack nem fut.

## 8. GitHub Actions

Repository, Settings, Secrets and variables, Actions. Egyik sem kell a CI-hoz (az titok nélkül fut); csak a telepítéshez és az életben tartáshoz.

| Név | Típus | Ki használja | Érték |
|---|---|---|---|
| `DEMO_SUPABASE_URL` | variable | `keepalive.yml`, `deploy-demo.yml` | a felhős projekt címe; **amíg nincs beállítva, a `keepalive` nem csinál semmit** |
| `DEMO_SUPABASE_KEY` | secret | ugyanazok | a publikus kulcs (az app is ezt kapja, tehát nem titok; a GitHub titokként kezeli, így a naplókban maszkolva van) |
| `DEMO_EMAIL` | variable | `deploy-demo.yml` | a demó fiók e-mail-címe |
| `DEMO_PASSWORD` | secret | `deploy-demo.yml` | a demó fiók jelszava (az appba van fordítva) |
| `CLOUDFLARE_API_TOKEN`, `CLOUDFLARE_ACCOUNT_ID` | secret | `deploy-demo.yml` | a Cloudflare-telepítéshez |

## 9. Átadáskor cserélendő titkok

Az átadási csomaghoz tartozó lista a [`handover.md`](handover.md)-ben van; röviden: a megrendelő **minden titkot újragenerál a saját fiókjaiban**, és semmit nem
vesz át a fejlesztő gépéről: a Supabase kulcsai és adatbázis-jelszava, a webhook-titok (az éles szolgáltatóé), a Cloudflare tokenek, az Android kulcstár,
a GitHub titkai.
