# Saját szerveres (staging) környezet

A Zaba fejlesztés közbeni, telefonról is elérhető környezete az otthoni Proxmox szerveren: a **hivatalos Supabase self-hosting
csomag** (rögzített kiadás), előtte **Caddy**, kifelé pedig egy **Cloudflare Tunnel**. A szerveren nincs kinyitott bejövő port.

```
telefon / böngésző
      │  https
      ▼
Cloudflare (TLS, a saját domainedhez)
      │  titkosított alagút, a szerver csak KIFELÉ kapcsolódik
      ▼
cloudflared ──► Caddy ──► app-staging.<domain>    Flutter web build (statikus fájlok)
                    ├───► admin-staging.<domain>  admin oldal (később)
                    └───► api-staging.<domain>    csak az API-útvonalak ─► Supabase gateway ─► Auth, REST, Realtime, Storage, Functions
                                                  minden más útvonal 404 (a Studio NEM érhető el kívülről)
```

## Mi van kipróbálva és mi nem

| Kipróbálva (a fejlesztői gépen, tiszta telepítésből) | Még NEM kipróbálva |
|---|---|
| Az `install.sh` végig (hivatalos stack, titokgenerálás, migrációk, seed, fizetési függvények), többször futtatva is | Futtatás a **Proxmox VM**-en (a te gépeden) |
| A 20 API-ellenőrzés, a 28 fizetési ellenőrzés (valódi Edge Function-ökkel, aláírt webhookkal) és a Realtime élő frissítés | A **Cloudflare Tunnel** (a tokened nélkül nem lehet) és a WebSocket a Cloudflare-en át |
| Az app integrációs tesztjei (35) a self-hosted stack ellen, a régi JWT-s anon kulccsal, mint a stagingen | Az app böngészős kipróbálása a **self-hosted** stacken (a CLI stacken megtörtént) |
| Mi érhető el kívülről és mi nem (Studio, meta API: 404), CORS, a webes build kiszolgálása | A `deploy-web.sh` `rsync`/`ssh` része |
| A Caddyfile, a shell scriptek, a compose profil szintaxisa (CI-ban is) | A telepítés `git clone`-ja a privát repóból a szerveren |

## 1. A virtuális gép a Proxmoxon

- **VM, nem LXC** (a Docker VM-ben a legegyszerűbb és legbiztonságosabb). Operációs rendszer: Debian 12/13 vagy Ubuntu 24.04 LTS.
- Ajánlott méret: **4 vCPU** (CPU típus: `host`), **8 GB RAM**, **60 GB** lemez, QEMU guest agent, "Start at boot" bekapcsolva.
  A hivatalos minimum 4 GB RAM / 2 mag / 40 GB. Mérés (lokális teszt, 12 konténer üresjáratban a smoke tesztek után): **kb. 1,3 GB RAM**, a Docker-képek
  együtt kb. 9-10 GB lemezen; a 16 GB-os gépeden a 8 GB RAM és a 60 GB lemez bőven elég, a Proxmoxon ráadásul módosítható.
- Docker Engine telepítése a hivatalos leírás szerint ([Debian](https://docs.docker.com/engine/install/debian/),
  [Ubuntu](https://docs.docker.com/engine/install/ubuntu/)), majd `sudo usermod -aG docker $USER` és új bejelentkezés.
  Kell még: `git`, `openssl`, `curl` (és a webes feltöltéshez a fejlesztői gépen `rsync`). A `docker compose version` legyen **2.24 vagy újabb**.

## 2. Cloudflare Tunnel (egyszer)

A domainednek **Cloudflare-en kell lennie** (a Cloudflare-ben "Add a site", és a domain névszervereit a regisztrátornál át kell
állítani). Ezután:

1. Cloudflare Zero Trust irányítópult, **Networking, Tunnels, Create a tunnel**, típus: *Cloudflared*, név pl. `zaba-staging`.
2. A megjelenő telepítési parancsból másold ki a **tokent** (a hosszú karaktersor). Ez titok, ne commitold és ne oszd meg.
3. A tunnelhez vegyél fel **három published application** (Routes) útvonalat, mindhárom szolgáltatása `http://caddy:80`:
   - `app-staging.<domainod>`
   - `api-staging.<domainod>`
   - `admin-staging.<domainod>`
4. A tokent a `zaba-selfhost.env`-be tedd (lásd lent), és futtasd újra az `install.sh`-t.

## 3. Telepítés a szerveren

```sh
git clone https://github.com/ateszk0/Zaba.git ~/zaba        # privát repó: `gh auth login` vagy egy csak olvasható deploy key kell
cd ~/zaba/deploy/selfhost
cp zaba-selfhost.env.example zaba-selfhost.env
nano zaba-selfhost.env                                      # a három host név és (ha már megvan) a tunnel token
./install.sh
```

Az `install.sh` lépései: ellenőrzi az eszközöket, letölti a hivatalos fájlokat a rögzített kiadásból, **egyszer** legyártja a titkokat
(`~/zaba-stack/.env`, 600-as jogosultsággal, a kulcsokat nem írja ki), beállítja az URL-eket, ráteszi a Caddy-t és a tunnelt, elindítja a
stacket, lefuttatja a migrációkat és betölti a demó adatokat. **Többször is futtatható**: a titkokat nem generálja újra, az új
migrációkat alkalmazza, a már betöltött menüt nem írja felül.

A végén kiírja a `config/staging.json`-be való értékeket. Az **anon kulcs publikus** (az app tartalmazza, az RLS védi az adatot). Szándékosan a régi, JWT-s anon kulcsot használjuk, nem az új `sb_publishable_…` kulcsot: ez a self-hosting kiadás a Realtime WebSocketen csak a JWT-s kulcsot fogadja el (REST-hez mindkettő jó).

## 4. Ellenőrzés

```sh
cd ~/zaba-stack && sh run.sh status                           # minden szolgáltatás (healthy)
curl -s https://api-staging.<domain>/rest/v1/catalog_products?select=id\&limit=2 -H "apikey: <anon kulcs>"
curl -s https://app-staging.<domain>/healthz                  # ok
curl -s -o /dev/null -w "%{http_code}\n" https://api-staging.<domain>/   # 404: a Studio nem érhető el
```

A teljes API-folyamat (regisztráció, rendelés, fizetési esemény, visszatérítés) egy paranccsal kipróbálható a fejlesztői gépről.
Figyelem: létrehoz egy teszt felhasználót és egy rendelést a staging adatbázisban, a titkos kulcsot csak a parancs idejére add meg:

```sh
SUPABASE_URL=https://api-staging.<domain> SUPABASE_PUBLISHABLE_KEY=<publishable> SUPABASE_SECRET_KEY=<secret> \
  python3 supabase/tests/api_smoke.py
# a kulcsok: ssh a szerverre, cd ~/zaba-stack && sh run.sh secrets (a publishable és a secret kulcs)

# a fizetési út a valódi Edge Function-ökön át (aláírt webhook, idempotencia, támadások)
SUPABASE_URL=https://api-staging.<domain> SUPABASE_PUBLISHABLE_KEY=<publishable> SUPABASE_ANON_KEY=<anon> FAKE_PAYMENT_WEBHOOK_SECRET=<a stack .env-jéből> \
  python3 supabase/tests/payment_smoke.py

# élő rendelésfrissítés a WebSocketen át (a Cloudflare-en keresztül is): pip install websockets
SUPABASE_URL=https://api-staging.<domain> SUPABASE_PUBLISHABLE_KEY=<publishable> SUPABASE_SECRET_KEY=<secret> SUPABASE_ANON_KEY=<anon> \
  python3 supabase/tests/realtime_smoke.py
```

A **demó fiók** (az app „Belépés demó fiókkal" gombja) a fejlesztői gépről hozható létre; csak a nyilvános regisztrációs végpontot használja, titkos kulcs
nélkül, és többször is futtatható. Az e-mail és a jelszó ugyanaz legyen, mint a `config/staging.json`-ban (`DEMO_EMAIL`, `DEMO_PASSWORD`; a jelszó az appba van
fordítva, ezért egy eldobható legyen):

```sh
SUPABASE_URL=https://api-staging.<domain> SUPABASE_PUBLISHABLE_KEY=<anon kulcs> DEMO_EMAIL=<e-mail> DEMO_PASSWORD=<jelszó> \
  python3 tool/create_demo_user.py
```

## 5. A webes app feltöltése

A fejlesztői gépről (a `config/staging.json` a telepítő kimenete alapján készül, a `.gitignore` kizárja a repóból):

```sh
deploy/selfhost/deploy-web.sh user@a-szerver
```

Ez lebuildeli a `flutter build web --release`-t a staging beállításokkal, és `rsync`-kel feltölti. Utána az `https://app-staging.<domain>` a telefonodról is megnyitható.

## 6. Üzemeltetés

| Mit | Hogyan |
|---|---|
| Állapot, naplók | `cd ~/zaba-stack && sh run.sh status` / `sh run.sh logs api-gw` |
| Új migráció vagy új kód | `cd ~/zaba && git pull && cd deploy/selfhost && ./install.sh` |
| Csak a migrációk | `./migrate.sh` |
| Leállítás, indítás | `sh run.sh stop` / `sh run.sh start` (a `~/zaba-stack` mappában) |
| Studio (irányítópult) | A gateway csak a szerver loopbackjén figyel: `ssh -L 8000:127.0.0.1:8000 user@szerver`, majd `http://localhost:8000`. A belépés: `DASHBOARD_USERNAME` és a jelszó a `sh run.sh secrets` kimenetéből |
| Titkok megtekintése | `cd ~/zaba-stack && sh run.sh secrets` |
| Adatbázis-mentés | `cd ~/zaba-stack && docker compose exec -T db pg_dump -U postgres -d postgres --clean --if-exists \| gzip > mentes-$(date +%F).sql.gz` |
| Supabase frissítése | A `SUPABASE_SELFHOST_REF` átírása a `zaba-selfhost.env`-ben, **előtte a kiadás CHANGELOG-jának elolvasása**, majd `./install.sh` |

A teljes gép mentéséhez használd a Proxmox **backup ütemezését** (vzdump): ez a titkokat és a feltöltött fájlokat is menti. Az adatbázis-dump csak a
`public` adatot tartalmazza.

## 7. Biztonság

- A szerveren **nincs nyitott bejövő port**: a tunnel kifelé kapcsolódik.
- A Docker által közzétett portok: a gateway és a Caddy alapból csak a `127.0.0.1`-en figyel (`ZABA_HTTP_BIND=0.0.0.0` csak szándékos LAN-teszthez; a Docker megkerüli az `ufw`-t, ezért ne bízz a tűzfalban).
- A Caddy csak az engedélyezett API-útvonalakat adja tovább (`/rest/v1`, `/auth/v1`, `/realtime/v1`, `/storage/v1`, `/functions/v1`); a Studio és a Postgres meta API kívülről 404.
- A titkok csak a szerver `.env` fájljában vannak (600-as jogosultság). A kliensbe (web, APK) csak a publishable kulcs kerül.
- A demón az e-mail megerősítés ki van kapcsolva (az `install.sh` `ENABLE_EMAIL_AUTOCONFIRM=true`-t állít; nincs kimenő levelezés), a regisztráció nyilvános. Az MVP-ben SMTP és megerősítés kell.

## 8. Hibaelhárítás

| Tünet | Teendő |
|---|---|
| A tunnel nem csatlakozik | `docker logs zaba-cloudflared`: hibás token? A Zero Trust irányítópulton a tunnel állapota legyen Healthy |
| 502 az api hoston | `sh run.sh status`: az `api-gw` és az `auth` legyen healthy; `sh run.sh logs api-gw` |
| Az app betölt, de nincs adat | A böngésző konzolja (CORS, kulcs): a `config/staging.json` URL-je és kulcsa egyezik-e a telepítő kimenetével? |
| `install.sh`: "too old" | Frissítsd a Docker Enginet (a Debian saját csomagja régi lehet) |
| Egy szolgáltatás `created`, nem `Up` | `sh tests/test-container-logs.sh` a `~/zaba-stack` mappában |

## Eltérések a felhős Supabase-től

- Az Auth beállításai környezeti változók (`.env`), nem a `config.toml` vagy a Dashboard.
- A migrációkat az `migrate.sh` alkalmazza (a Supabase CLI ugyanazt a nyilvántartó táblát használja).
- Az Edge Function-ök fájl-elhelyezéssel települnek (`volumes/functions`, az `install.sh` másolja a `supabase/functions` mappát), nem `supabase functions deploy`-jal. A titkot (`FAKE_PAYMENT_WEBHOOK_SECRET`) a telepítő egyszer generálja a stack `.env`-jébe, és a compose-kiegészítés adja át a függvények tárolójának. Az átjáró függvényenkénti JWT-ellenőrzést nem ismer (a `FUNCTIONS_VERIFY_JWT` az összesre vonatkozik, alapból kikapcsolt), ezért a függvények maguk hitelesítenek: a vásárló tokenje, a munkamenet aláírása, az esemény aláírása.
- A Realtime WebSocket kapcsolatnak át kell mennie a Cloudflare-en. Cloudflare minden csomagon támogatja a WebSocketet, de a tényleges működés az éles tunnelen **ellenőrzendő**; tartalék az 5 mp-es polling.
