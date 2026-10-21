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
                    └───► api-staging.<domain>    csak az API-útvonalak ─► Supabase gateway ─► Auth, REST, Realtime, Functions
                                                  minden más útvonal 404 (a Studio NEM érhető el kívülről)
```

## Mi van kipróbálva és mi nem

| Kipróbálva (a fejlesztői gépen, **friss** telepítésből) | Még NEM kipróbálva |
|---|---|
| Az `install.sh` végig (hivatalos stack, titokgenerálás, migrációk, seed, fizetési függvények, ütemezett feladatok): 1:56, többször futtatva is | Futtatás a **Proxmox VM**-en (a te gépeden) |
| pgTAP mind a 12 fájl (187 állítás), a három HTTP-füstteszt (API, fizetés valódi Edge Function-ökkel és aláírt webhookkal, Realtime élő frissítés) | A **Cloudflare Tunnel** (a tokened nélkül nem lehet) és a WebSocket a Cloudflare-en át |
| Az app 45 integrációs tesztje a self-hosted stack ellen, a régi JWT-s anon kulccsal, mint a stagingen | Az app és az admin böngészős kipróbálása a **self-hosted** stacken (a CLI stacken megtörtént) |
| `verify.sh`, `backup.sh` (titkosítva), `restore.sh`: **katasztrófa-helyreállítás ~130 s** alatt, a titkokkal együtt | Az admin oldal telepítése (`deploy-web.sh ... admin`, `rsync`/`ssh`) a szerveren |
| Összeomlás (`kill -9` a Postgres folyamatain a fizetési füstteszt közben): nincs adatvesztés, a PostgREST újracsatlakozik | A telepítés `git clone`-ja a privát repóból a szerveren |
| Terhelés: ~1 600-1 800 kérés/mp hiba nélkül (a 12 magos fejlesztői gépen) | A célhardver teljesítménye, hetes üzem, sok egyidejű Realtime-kapcsolat |
| A lejárati job (`pg_cron`): a régi fizetetlen rendelést lemondja, a naplóba ír | Valódi SMTP, valódi fizetési szolgáltató, iPhone Safari |
| Mi érhető el kívülről és mi nem (Studio, meta API, Storage: 404), a fejlécek, a webes build kiszolgálása | |
| A Caddyfile, a shell scriptek (`shellcheck`), a compose profil szintaxisa (CI-ban is) | |

Az éles üzemhez szükséges teendők és a mért adatok: [`docs/real-life-plan.md`](../../docs/real-life-plan.md). A kód átnézésének eredménye: [`docs/code-review.md`](../../docs/code-review.md).

## 1. A virtuális gép a Proxmoxon

- **VM, nem LXC** (a Docker VM-ben a legegyszerűbb és legbiztonságosabb). Operációs rendszer: Debian 12/13 vagy Ubuntu 24.04 LTS.
- Ajánlott méret: **4 vCPU** (CPU típus: `host`), **8 GB RAM**, **60 GB** lemez, QEMU guest agent, "Start at boot" bekapcsolva.
  A hivatalos minimum 4 GB RAM / 2 mag / 40 GB. Mérés (lokális teszt, 12 konténer üresjáratban): **kb. 1,2 GB RAM**, a Docker-képek
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
stacket, lefuttatja a migrációkat, betölti a demó adatokat és beállítja az ütemezett feladatokat (a fizetetlen rendelések lejárata). **Többször is futtatható**: a titkokat nem generálja újra, az új
migrációkat alkalmazza, a már betöltött menüt nem írja felül.

A végén kiírja a `config/staging.json`-be való értékeket. Az **anon kulcs publikus** (az app tartalmazza, az RLS védi az adatot). Szándékosan a régi, JWT-s anon kulcsot használjuk, nem az új `sb_publishable_…` kulcsot: ez a self-hosting kiadás a Realtime WebSocketen csak a JWT-s kulcsot fogadja el (REST-hez mindkettő jó).

## 4. Ellenőrzés

Az első és legfontosabb: a **`verify.sh`** (semmit sem változtat, soronként `ok`, `WARN` vagy `FAILED`; `FAILED` esetén 1-gyel lép ki):

```sh
deploy/selfhost/verify.sh
```

Ellenőrzi, hogy minden konténer fut és egészséges; hogy az internet felé csak a Caddy érhető el (a gateway a helyi gépre kötött); hogy a Caddy kiszolgálja, amit kell, és rejti, amit kell (Studio, meta API, Storage); a biztonsági fejléceket; hogy egyetlen titok sem a hivatalos helyőrző értékű; hogy megvan az összes migráció; hogy a lejárati job be van állítva; hogy a mentés friss; hogy a lemez és a naplók korlátosak. Telepítés után, minden módosítás után és időnként (cronból, a kimenetét levélben elküldve) futtasd.

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

A **munkatársi fiókok** (az admin oldalhoz) a titkos kulccsal hozhatók létre, ami a szerver `.env`-jében van (`sh run.sh secrets`), ezért a parancsot
úgy futtasd, hogy a kulcs ne kerüljön a chatbe vagy a repóba (a szerveren vagy a fejlesztői gépen a környezetben, a parancs idejére):

```sh
SUPABASE_URL=https://api-staging.<domain> SUPABASE_PUBLISHABLE_KEY=<anon kulcs> SUPABASE_SECRET_KEY=<titkos kulcs> \
  STAFF_EMAIL=<e-mail> STAFF_PASSWORD=<jelszó> python3 tool/create_staff_user.py --role operator   # vagy: --role admin
```

## 5. A webes app és az admin oldal feltöltése

A fejlesztői gépről (a `config/staging.json` a telepítő kimenete alapján készül, a `.gitignore` kizárja a repóból):

```sh
deploy/selfhost/deploy-web.sh user@a-szerver            # a vásárlói app (app-staging.<domain>)
deploy/selfhost/deploy-web.sh user@a-szerver admin      # az admin oldal (admin-staging.<domain>)
```

Az admin build ugyanazt a `config/staging.json`-t használja. Az `ADMIN_DEMO_EMAIL` / `ADMIN_DEMO_PASSWORD` a "Belépés demó munkatársként" gombot kapcsolja be: a
jelszó az oldalba van fordítva, tehát bárki, aki az admin címét megnyitja, kezelheti a rendeléseket. A vásárlónak adott linkhez ezért hagyd ki a két értékből, és a
munkatárs gépelje be a jelszót (a vásárlói buildből a fa-nyesés kiveszi, az admin buildből nem).
Ez lebuildeli a `flutter build web --release`-t a staging beállításokkal, és `rsync`-kel feltölti. Utána az `https://app-staging.<domain>` a telefonodról is megnyitható.

## 6. Üzemeltetés

| Mit | Hogyan |
|---|---|
| Állapot, naplók | `cd ~/zaba-stack && sh run.sh status` / `sh run.sh logs api-gw` |
| Új migráció vagy új kód | `cd ~/zaba && git pull && cd deploy/selfhost && ./install.sh` |
| Csak a migrációk | `./migrate.sh` |
| Ütemezett feladatok (a fizetetlen rendelések lejárata) | `./schedule.sh` (az `install.sh` is hívja; a `ZABA_UNPAID_MINUTES` alapból 30 perc, legalább 5) |
| Állapotellenőrzés | `./verify.sh` |
| Mentés | `./backup.sh` (lásd lent) |
| Visszaállítás | `./restore.sh data <mentés>`, új gépen előbb `./restore.sh env <mentés>` |
| Leállítás, indítás | `sh run.sh stop` / `sh run.sh start` (a `~/zaba-stack` mappában) |
| Studio (irányítópult) | A gateway csak a szerver loopbackjén figyel: `ssh -L 8000:127.0.0.1:8000 user@szerver`, majd `http://localhost:8000`. A belépés: `DASHBOARD_USERNAME` és a jelszó a `sh run.sh secrets` kimenetéből |
| Titkok megtekintése | `cd ~/zaba-stack && sh run.sh secrets` |
| Supabase frissítése | A `SUPABASE_SELFHOST_REF` átírása a `zaba-selfhost.env`-ben, **előtte a kiadás CHANGELOG-jának elolvasása**, majd `./install.sh` |

### Mentés és helyreállítás

A `backup.sh` az **adatbázist és a stack titkait** (`.env`) menti egy fájlba. **Mindkettő kell**: a titkok (a JWT-titok és a kulcsok) nélkül a visszaállított adat a már kiadott appok kulcsát és minden munkamenetet érvénytelenítene.

```sh
ZABA_BACKUP_DIR=/var/backups/zaba ZABA_BACKUP_PASSPHRASE_FILE=~/.zaba-backup-passphrase deploy/selfhost/backup.sh
```

- Jelszófájllal a mentés titkosított (`.tar.enc`, AES-256, PBKDF2); nélküle sima `.tar`, amely a titkokat is tartalmazza: csak titkosított lemezen szabad tartani.
- Visszaolvasással ellenőrzi a mentést, és a `ZABA_BACKUP_KEEP` (alapból 14) legújabbat őrzi.
- **Ütemezd** (cron vagy systemd időzítő, példa: `docs/real-life-plan.md` 7.1), és **másold másik gépre**: az ugyanazon a lemezen lévő mentés a lemezzel együtt elvész.
- A titkosító jelszót külön, biztonságos helyen is őrizd meg.
- Visszaállítás ugyanazon a gépen: `restore.sh data <mentés>`. Új gépen: `restore.sh env <mentés>`, `install.sh`, `restore.sh data <mentés>` (az `env` az `install.sh` előtt kell, különben az új titkok érvénytelenítenék az appok kulcsát). A `data` egy tranzakcióban cseréli az adatot: ha elbukik, az adatbázis változatlan marad. Mért idő kis adatbázison: **~130 s** a teljes újjáépítésig.
- **Próbáld ki negyedévente** egy külön gépen, nem csak akkor, amikor baj van.

A teljes gép mentéséhez a Proxmox **backup ütemezése** (vzdump) is jó kiegészítés, de nem helyettesíti a `backup.sh`-t (az a titkokat is és az adatbázist következetesen menti).

## 7. Biztonság

- A szerveren **nincs nyitott bejövő port**: a tunnel kifelé kapcsolódik.
- A Docker által közzétett portok: a gateway és a Caddy alapból csak a `127.0.0.1`-en figyel (`ZABA_HTTP_BIND=0.0.0.0` csak szándékos LAN-teszthez; a Docker megkerüli az `ufw`-t, ezért ne bízz a tűzfalban).
- A Caddy csak az engedélyezett API-útvonalakat adja tovább (`/rest/v1`, `/auth/v1`, `/realtime/v1`, `/functions/v1`); a Studio, a Postgres meta API és a Storage (az app még nem használja) kívülről 404, minden ismeretlen hostnév is 404.
- Az oldalak **tartalombiztonsági szabályt** (CSP) és biztonsági fejléceket kapnak: csak a saját fájljaikat tölthetik be, és csak az API hosthoz csatlakozhatnak.
- A konténerek naplói **forognak** (konténerenként 5 x 10 MB), így a lemez nem telik meg.
- **A belépésnek nincs szerveroldali korlátja** (a GoTrue a jelszópróbálkozásokat nem korlátozza; mértük: ~100 próba/mp elfogadva). Éles használat előtt a Cloudflare oldalán sebességkorlát és az admin hoston Cloudflare Access kell: `docs/real-life-plan.md` 4.3.
- A **fizetés hamis szolgáltatója** csak akkor működik, ha a stack `.env`-jében `FAKE_PAYMENTS_ENABLED=true` (az `install.sh` friss stacken ezt állítja be, a demóhoz). Valódi fizetésnél `false` kell; a `verify.sh` figyelmeztet, amíg be van kapcsolva.
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
| A fizetési függvények 503-at adnak | A `FAKE_PAYMENTS_ENABLED` értéke a stack `.env`-jében (a hamis út csak `true`-val működik), vagy a `FAKE_PAYMENT_WEBHOOK_SECRET` hiányzik; a `functions` konténer újraindítása kell a változás után |
| A munkatársi eszköz 403-at kap | Saját szerveren a régi `service_role` JWT kell titkos kulcsként; az új `sb_secret_` kulcsot az auth admin API ott elutasítja |

## Eltérések a felhős Supabase-től

- Az Auth beállításai környezeti változók (`.env`), nem a `config.toml` vagy a Dashboard.
- A migrációkat az `migrate.sh` alkalmazza (a Supabase CLI ugyanazt a nyilvántartó táblát használja).
- Az Edge Function-ök fájl-elhelyezéssel települnek (`volumes/functions`, az `install.sh` másolja a `supabase/functions` mappát), nem `supabase functions deploy`-jal. A titkot (`FAKE_PAYMENT_WEBHOOK_SECRET`) a telepítő egyszer generálja a stack `.env`-jébe, és a compose-kiegészítés adja át a függvények tárolójának. Az átjáró függvényenkénti JWT-ellenőrzést nem ismer (a `FUNCTIONS_VERIFY_JWT` az összesre vonatkozik, alapból kikapcsolt), ezért a függvények maguk hitelesítenek: a vásárló tokenje, a munkamenet aláírása, az esemény aláírása.
- A Realtime WebSocket kapcsolatnak át kell mennie a Cloudflare-en. Cloudflare minden csomagon támogatja a WebSocketet, de a tényleges működés az éles tunnelen **ellenőrzendő**; tartalék az 5 mp-es polling.
