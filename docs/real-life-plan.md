# Éles üzem terve (a saját szerveren)

> **Állapot: terv, nem teljesített feladatlista.** A Zaba ma egy bemutatható demó. Ez a lap azt írja le, mi kell ahhoz, hogy a **saját szerveren** (`deploy/selfhost/`) valódi vásárlók valódi pénzzel rendelhessenek, és mit mértünk meg
> hozzá. Ami nincs kipróbálva, azt **„nem tesztelt"** jelzi. A jogi, adózási és szerződéses kérdésekben nem döntök és nem állítok semmit: azokat a [`known-gaps.md`](known-gaps.md) 3. fejezete gyűjti ügyvédnek és könyvelőnek.
> A kód- és biztonsági átnézés eredménye a [`code-review.md`](code-review.md)-ben van; a részletes leírás a [`development.md`](development.md)-ben.

## 1. Összefoglaló: mi áll közte és az éles üzem között

A saját szerveres környezetet végig kipróbáltuk (friss telepítés, mentés és katasztrófa-helyreállítás, összeomlás-teszt, terhelés, ellenőrző szkript). A **háttér működik és helyreállítható**. Az éles üzemhez három dolog **kötelező**, és még nincs kész:

| # | Mi hiányzik | Miért kötelező | Hol van leírva |
|---|---|---|---|
| 1 | **Valódi fizetési szolgáltató**, a hamis kikapcsolva (`FAKE_PAYMENTS_ENABLED=false`) | A hamis kártyalépésnél az app maga jelenti, hogy a kártyát elfogadták: egy valódi boltban bárki kifizetettnek jelölhetné a rendelését. A kapcsoló ezért alapból zárva van | 5. fejezet |
| 2 | **A belépés védelme a kitalálgatás ellen** (Cloudflare szabály és/vagy Turnstile, az admin oldal elé Cloudflare Access) | A saját szerveres Supabase auth **nem korlátozza** a jelszópróbálkozásokat: mértük, **másodpercenként ~100 rossz jelszót** elfogadott, korlátozás nélkül | 4.3 |
| 3 | **E-mail (SMTP)**, megerősítés és jelszó-visszaállítás | A telepítő a demóban „megerősítettnek" veszi az új fiókot, mert nincs kimenő levelezés; éleshez ez nem maradhat | 6. fejezet |

Mellettük a jogi és üzleti teendők (ÁSZF, adatkezelés, számlázás, ÁFA-kulcsok) és a rendszeres üzemeltetés (mentés másik helyre, figyelés, frissítés) következnek. A teljes lista a **go-live ellenőrzőlista** (10. fejezet).

## 2. Amit megmértünk (a saját szerveres tesztben)

A teszt a fejlesztői gépen futott, ugyanazzal a kóddal és Docker-képekkel, amelyek a szerveren is futnának. **A gép nem a célhardver**: 12 mag, 15 GB memória, a terhelésgenerátor is ugyanott futott (ezért a számok alsó becslések). A célhardveren a méréseket meg kell ismételni.

| Mit mértünk | Eredmény |
|---|---|
| **Friss telepítés** (`install.sh`, a képek már letöltve) | 1 perc 56 másodperc; 14 migráció, kezdőadat. Első alkalommal a képek letöltése néhány GB |
| **Konténerek** | 12 (11 hivatalos Supabase + Caddy), a `cloudflared` a 13. a tunnel profillal |
| **Memória, üresjáratban** | ~1,2 GB összesen (legnagyobb: Realtime ~250 MB, Pooler ~240 MB, Studio ~220 MB, Meta ~110 MB, Postgres ~110 MB) |
| **Lemez** | A Docker-képek néhány GB; a naplók korlátosak (konténerenként 5 x 10 MB); az adatbázis 14 MB, a mentése (`pg_dump`) 849 KB |
| **Katalógus-lekérés** (`GET catalog_products`, 45 termék) | ~1 800 kérés/mp 8-64 párhuzamos kapcsolatnál; p50 4,5 ms (8 kapcsolat), p95 28 ms (32 kapcsolat), hiba nélkül |
| **Kosár-árazás** (`quote_cart`, az adatbázisban számol) | ~1 600 kérés/mp; p50 5 ms (8), p95 31 ms (32), hiba nélkül |
| **Mi telik meg először terhelés alatt** | az API-átjáró (Envoy) és a PostgREST fejenként egy-másfél magot használt, a Postgres egyet; több mag nem fogyott el |
| **Jelszópróbálkozás korlát nélkül** | 977 rossz jelszó 10 másodperc alatt (16 párhuzamos kapcsolat), egy sem lett elutasítva korlát miatt |
| **Összeomlás-teszt** (a Postgres folyamatainak `kill -9`-e a fizetési füstteszt ciklusa közben) | A PostgREST újracsatlakozott, az adatbázis helyreállt; **nem veszett el megerősített rendelés, nem maradt félig kifizetett állapot**. Az összeomlás alatti kérések átmenetileg `PGRST001/002` hibát adtak, majd magától rendbe jött |
| **Katasztrófa-helyreállítás** (a teljes stack és az adatbázis törlése, majd `restore.sh env` + `install.sh` + `restore.sh data`) | **~130 másodperc** a teljes újjáépítésig, kis adatbázison; a titkok megmaradtak, így az appok kulcsa és a munkamenetek érvényesek maradtak |
| **Fizetési folyamat** (valódi Edge Function-ökkel, aláírt eseménnyel) | Mind a 20+ ellenőrzés zöld: siker, elutasítás, megszakítás, ismételt esemény (idempotencia), hamis, elavult és módosított esemény, idegen vásárló, lejárt munkamenet |
| **Élő követés** (Realtime WebSocket) | A kifizetett rendelés egyetlen, konzisztens frissítésben megérkezik a vásárlóhoz |
| **A lejárati futás** (`expire_unpaid_orders` pg_cron-ból) | Egy 2 órája fizetetlen rendelést a következő futás lemondott, a hely felszabadult, a napló bejegyezte |
| **Tesztek a friss telepítésen** | pgTAP mind a 12 fájl, 187 állítás; három HTTP-füstteszt; 45 Dart integrációs teszt; `verify.sh` |

**Nem mértük / nem tesztelt:** valódi Cloudflare Tunnel és valódi domain (nem volt fiók hozzá), a Realtime WebSocket átmenete az alagúton, TLS a Cloudflare-nél, iPhone Safari, valódi fizetési szolgáltató, valódi SMTP, a célhardver teljesítménye, hosszú távú (hetes) üzem, több száz egyidejű Realtime-kapcsolat.

## 3. Méretezés

### 3.1 Mekkora forgalmat bír

A mért ~1 600-1 800 kérés/mp egy 12 magos gépen azt jelenti, hogy a háttér **nem a szűk keresztmetszet** egy étterem méretű forgalomnál. Egy becslés (az adatok a **feltételezésből** jönnek, nem mérésből, az éles forgalom mást mutathat):

- 500 rendelés naponta, a csúcsórában a nap rendeléseinek ~20%-a: 100 rendelés/óra.
- Egy rendelés ~50 kérés (étlap, árazás minden kosárváltozásnál, idősáv, leadás, fizetés, élő követés).
- Ez csúcsban ~1,5 kérés/mp: a mért kapacitás ezerszerese alatt.

Ami **valóban korlátoz**: a memória (1,2 GB üresjáratban), a lemez (képek, naplók, mentések), és egy-egy Realtime-kapcsolat minden nyitva tartott appnál (a Realtime korlátját a célhardveren kell megmérni, **nem mértük**). Az egyetlen szerver egyben **egyetlen hibapont** (lásd 11. fejezet).

### 3.2 Ajánlott gép

| | Minimum (a hivatalos) | Ajánlott |
|---|---|---|
| Memória | 4 GB | 8 GB |
| Mag | 2 | 4 |
| Lemez | 40 GB SSD | 80 GB SSD (a mentés külön lemezen vagy gépen) |
| Rendszer | Linux, Docker, compose 2.24 vagy újabb | Debian vagy Ubuntu LTS, automatikus biztonsági frissítéssel |

A költségkategóriák (a szerver, a domain, az SMTP, a fizetési szolgáltató díja, a mentési tárhely) összegét **nem ellenőriztem**; a megrendelőnek az ajánlatok alapján kell megállapítania.

## 4. Az üzemi felépítés

### 4.1 Hol fusson a szerver

| Lehetőség | Előny | Hátrány |
|---|---|---|
| **Otthoni szerver** (a mostani terv: Proxmox virtuális gép) | Nincs havi bérleti díj, teljes kontroll | Az áram és az internet kimaradása a **szolgáltatás kimaradása**; nincs szolgáltatói garancia; dinamikus IP (a Cloudflare Tunnel ezt megoldja, mert kimenő kapcsolat) |
| **Bérelt virtuális szerver (VPS) vagy kihelyezett (colocation) gép** | Szolgáltatói hálózat és áram, stabil IP | Havi díj |

**Javaslat:** egy próbaüzemhez (zárt kör, valódi rendelés kevés) az otthoni szerver elfogadható, **szünetmentes tápegységgel (UPS)** és az interneten kívül mobilnet tartalékkal; **nyilvános indításhoz** a bérelt szerver az ajánlott, mert egy vendéglátó szolgáltatásnál a kimaradás pénzbe kerül. A telepítő mindkettőn ugyanúgy működik. (A döntés a megrendelőé.)

### 4.2 Hálózat, tűzfal, VPN

- A szerver **semmilyen bejövő portot nem nyit** az internet felé: a Cloudflare Tunnel (`cloudflared`) kimenő kapcsolat. A tűzfal (pl. `ufw`) alapértelmezésben **tiltsa a bejövő forgalmat**; az egyetlen kivétel az SSH, és az is csak VPN-ről vagy megbízható címről.
- A **Supabase Studio** és a Postgres meta API **nincs kiajánlva** (a Caddy 404-et ad rájuk, a `verify.sh` ellenőrzi). Ha kell a Studio, az SSH-alagúton vagy VPN-en át érhető el (`127.0.0.1:8000`), sosem a nyilvános hoston.
- **VPN** (WireGuard vagy Tailscale) javasolt az üzemeltetői hozzáféréshez (SSH, Studio, a mentések másolása), hogy az SSH-portot se kelljen kitenni.
- SSH: csak kulccsal, jelszavas belépés letiltva, root belépés letiltva.
- A Docker-portok a géphez kötöttek (`127.0.0.1`): az `install.sh` és a compose-réteg így állítja be, a `verify.sh` ellenőrzi, hogy csak a helyi átjáró és a Caddy publikált.

### 4.3 A belépés védelme (kötelező, nincs kész)

**Mért tény:** a saját szerveres GoTrue nem korlátozza a jelszó-alapú belépés és regisztráció próbálkozásait (a mérés a 2. fejezetben: 977 rossz jelszó 10 másodperc alatt, egyet sem utasított el). A Cloudflare Tunnel mögött minden kérés ugyanonnan (`cloudflared`) érkezik, ezért **a valódi kliens-IP-re támaszkodó korlátozás ott sem működne magától** (nem tesztelt: a `CF-Connecting-IP` fejléc átadása a GoTrue-nak külön beállítás).

Teendők, **a Cloudflare oldalon** (nem a kódban):

1. **Sebességkorlátozási szabály (Rate limiting rule)** az `api` hostra: `/auth/v1/token` és `/auth/v1/signup` útvonalra, IP-nként néhány kérés percenként; a túllépőt blokkolni.
2. **Cloudflare Access** (Zero Trust) az **admin hosthoz**: a konyha oldalát így csak a meghívott munkatársak érik el (e-mail-kód vagy identitásszolgáltató), mielőtt a bejelentkező oldal egyáltalán megjelenik. Ez a legerősebb védelem a munkatársi fiókok kitalálgatása ellen, és kódváltoztatás nélkül megy.
3. **Turnstile** (CAPTCHA) a regisztrációra és a belépésre: a GoTrue támogatja (`GOTRUE_SECURITY_CAPTCHA_*`), de a hivatalos compose-fájl nem teszi elérhetővé: a `docker-compose.zaba.yml` `auth` szolgáltatásának környezetébe fel kell venni, és az **appnak is kezelnie kell a widgetet** (weben megoldható, a natív appban külön munka). **Nem tesztelt, fejlesztést igényel.**
4. A munkatársi fiókok jelszava hosszú és egyedi legyen; az admin oldalon a `ADMIN_DEMO_EMAIL`/`ADMIN_DEMO_PASSWORD` **nem szerepelhet** a buildben.

### 4.4 Domain és Cloudflare

- Három hostnév egy Cloudflare-ben lévő domainen: `app.`, `api.`, `admin.` (a `zaba-selfhost.env`-ben). Stabil (named) alagúthoz Cloudflare-fiók és egy a Cloudflare DNS-ében lévő domain kell (a Quick Tunnel véletlen címet ad, éleshez nem jó).
- Az `install.sh` a tokent a `CLOUDFLARE_TUNNEL_TOKEN`-ből veszi; a token titok (csak a szerver `.env`-jében).
- Az appba (APK) és a webes buildbe a **stabil `api.` cím** van beleépítve: egy későbbi címváltás az appok újraépítését és újratelepítését jelenti. **Éles domaint elég egyszer jól kiválasztani.**
- A kulcs (a nyilvános `ANON_KEY` JWT) és a `JWT_SECRET` összetartozik: **a `JWT_SECRET` cseréje érvényteleníti az összes kiadott appot és munkamenetet**. Ezért a `backup.sh` a titkokat is menti.

## 5. Valódi fizetés

A jelenlegi folyamat ([`payment-flow.md`](payment-flow.md)) a **szerkezetet** már úgy valósítja meg, ahogy éles szolgáltatóval is kellene: a fizetési függvény aláírt eseményt vár, azt ellenőrzi, idempotensen alkalmazza, és csak ez tehet kifizetetté egy rendelést. Éleshez:

1. **Szolgáltató kiválasztása** (Barion, Stripe, SimplePay, vagy más): az összehasonlítást a hivatalos dokumentációjuk alapján kell elvégezni; **nem döntöttem el**. Szempontok: bankkártya és Apple/Google Pay támogatás, díjak, kifizetési idő, magyar számlázási és visszatérítési folyamat, a webhook aláírási módja, tesztkörnyezet.
2. **Adapter** a `supabase/functions/_shared/payments/provider.ts` interfész mögé (a `fake_provider.ts` mintájára): munkamenet-nyitás, webhook-aláírás ellenőrzése. A kártyaadat **sosem érintheti a Zaba szervereit**: átirányításos vagy beágyazott (hosted) fizetőoldal kell, hogy a Zaba a kártyaadatokra vonatkozó szigorú szabályok hatókörén kívül maradjon (a pontos megfelelőségi követelményeket a szolgáltatóval és jogásszal kell tisztázni).
3. **Összeg- és pénznem-ellenőrzés a webhookban.** A jelenlegi `apply_payment_event` az eseményt a nyitott fizetési kísérlethez illeszti, de **nem hasonlítja össze a szolgáltató által jelentett összeget** a `payments.amount_huf`-fal (a hamis szolgáltató eseménye nem hordoz összeget). Éles adapterben ez kötelező, különben egy kisebb összegű sikeres fizetés kifizetettnek jelölhetne egy drágább rendelést. **Fejlesztői feladat, nincs kész.**
4. **Valódi visszatérítés**: a lemondáskor a rendszer ma azonnal `refunded`-ra állít; élesben a szolgáltatótól kell visszakérni, és a státusz csak a sikeres visszatérítés után válthat (`refunds` tábla, lásd `known-gaps.md`).
5. **Lemondás közben érkező sikeres fizetés**: ma a rendszer figyelmen kívül hagyja (`order_not_pending`); valódi pénznél ez visszatérítést igényel.
6. **A hamis fizetési út lezárása:** `FAKE_PAYMENTS_ENABLED=false` a szerver `.env`-jében (a telepítő csak friss stacken állítja `true`-ra, a meglévő beállításhoz nem nyúl), és a függvények újraindítása. A `verify.sh` figyelmeztet, amíg be van kapcsolva. A tesztkártyák súgóját mutató képernyő (`payment_screen.dart`) a valódi szolgáltatóval lecserélődik.
7. **Lejárat**: a fizetésre váró rendelés helye az idősávban foglalt. Az `expire_unpaid_orders` 30 perc után lemondja (lásd 7.4); a valódi szolgáltatónál a fizetési munkamenet lejáratát ehhez kell igazítani.

## 6. E-mail

A telepítő `ENABLE_EMAIL_AUTOCONFIRM=true` értéket állít (a demó nem küld levelet). Éleshez:

1. **SMTP-szolgáltató** választása (a megrendelő döntése), a hozzá tartozó `SMTP_*` beállítások a stack `.env`-jében (`SMTP_HOST`, `SMTP_PORT`, `SMTP_USER`, `SMTP_PASS`, `SMTP_ADMIN_EMAIL`, `SMTP_SENDER_NAME`). A jelszót csak a szerver `.env`-je tartalmazhatja.
2. A **küldő domain hitelesítése** (SPF, DKIM, DMARC), különben a levelek a levélszemétbe kerülnek. Nem tesztelt.
3. `ENABLE_EMAIL_AUTOCONFIRM=false`: az új fiók megerősítésre vár. Az app erre ma **nem** készült fel: a regisztráció `emailNotConfirmed` hibát ad, ha nincs munkamenet, és nincs „nézd meg a leveledet" képernyő. **Fejlesztői feladat.**
4. **Elfelejtett jelszó** képernyő és folyamat (nincs kész), a levélsablonok magyarul és az app arculatával.
5. A „már van fiók ezzel a címmel" üzenet felderítést tesz lehetővé; a megerősítés bekapcsolása megoldja (`known-gaps.md`).

## 7. Üzemeltetés

### 7.1 Mentés (kötelező, az eszköz kész)

A `deploy/selfhost/backup.sh` az adatbázist **és a titkokat** menti, titkosítva (`ZABA_BACKUP_PASSPHRASE_FILE`), ellenőrzi a visszaolvasást, és a régieket törli. **Ütemezni kell, és egy másolatot másik gépre/helyre kell vinni**: az ugyanazon a lemezen lévő mentés a lemezzel együtt veszik el.

Példa systemd időzítőre (óránként a mentés ritkítható; napi egy a minimum):

```ini
# /etc/systemd/system/zaba-backup.service
[Unit]
Description=Zaba backup
[Service]
Type=oneshot
User=zaba
Environment=ZABA_SELFHOST_ENV=/home/zaba/Zaba/deploy/selfhost/zaba-selfhost.env
Environment=ZABA_BACKUP_DIR=/var/backups/zaba
Environment=ZABA_BACKUP_PASSPHRASE_FILE=/home/zaba/.zaba-backup-passphrase
ExecStart=/home/zaba/Zaba/deploy/selfhost/backup.sh
ExecStartPost=/usr/bin/rsync -a --delete /var/backups/zaba/ backup@masik-gep:/zaba-backups/

# /etc/systemd/system/zaba-backup.timer
[Timer]
OnCalendar=*-*-* 03:30:00
Persistent=true
[Install]
WantedBy=timers.target
```

(Példa, **nem tesztelt** a megadott alakban; a `backup.sh` önmagában tesztelt.) Szabályok:

- A jelszófájl (a mentés titkosításához) **nem lehet csak a mentéssel egy helyen**; külön, biztonságos helyen is meg kell őrizni, különben a titkosított mentés használhatatlan.
- **Helyreállítási próba negyedévente** egy külön gépen: `restore.sh env`, `install.sh`, `restore.sh data`, aztán `verify.sh` és a füstteszt. A mért idő kis adatbázison ~130 másodperc; nagy adatbázison ez nő (**nem mértük**).
- A mentési gyakoriság a megengedhető adatvesztést (RPO) adja: napi mentésnél legfeljebb egy napnyi rendelés veszhet. Ha ez sok, a folyamatos archiválás (WAL) a következő lépés (nem készült el).

### 7.2 Figyelés

- A `deploy/selfhost/verify.sh` cronból (5-15 percenként), a kimenete levélben vagy üzenetben, ha a kilépési kód nem 0. Ellenőrzi a konténereket, a kitett portokat, a Caddy-t, a fejléceket, a titkokat, a migrációkat, a lejárati jobot, a mentés frissességét, a lemezt és a naplókat.
- **Kívülről is** figyelni kell (a szerver nem tudja jelezni, ha az internete vagy az áram megszűnt): egy külső üzemidő-figyelő (például egy ingyenes szolgáltatás) a `https://app.<domain>/healthz` és az API címre. A `/healthz` a Caddy saját válasza; az API állapotához a `/rest/v1/` kulccsal kérdezhető.
- A naplók konténerenként forognak (5 x 10 MB). Hosszabb megőrzéshez külső naplógyűjtő kell (**nincs**).
- **Riasztási küszöbök** (javaslat): lemez > 80%, a `verify.sh` hibája, a mentés 36 óránál régebbi, a rendelések között hosszú ideje fizetésre váró.

### 7.3 Frissítés

- A Supabase self-host kiadás **rögzített** (`SUPABASE_SELFHOST_REF=self-hosted/v0.8.3`). Frissítés: a kiadás **CHANGELOG-ját el kell olvasni**, előbb a stagingen próbálni, **mentés után**, a `SUPABASE_SELFHOST_REF` átírásával és az `install.sh` újrafuttatásával. A képek (Caddy, cloudflared) verziója a `docker-compose.zaba.yml`-ben rögzített.
- Az operációs rendszer biztonsági frissítései automatikusan, a Docker és a compose rendszeresen.
- Új migráció: `deploy/selfhost/migrate.sh` (az `install.sh` is hívja); minden migrációt a repóban kell tartani, kézi Studio-szerkesztés nélkül.
- **Minden új SQL-függvényre** ki kell adni a `revoke all ... from public, anon, authenticated` parancsot, különben mindenki hívhatja; a pgTAP `110` teszt ezt őrzi.

### 7.4 Ütemezett feladatok

A `deploy/selfhost/schedule.sh` (az `install.sh` hívja) két `pg_cron` feladatot állít be:

| Feladat | Mikor | Mit csinál |
|---|---|---|
| `zaba-expire-unpaid` | 10 percenként | A `ZABA_UNPAID_MINUTES` (alapból 30, legalább 5) percnél régebben fizetésre váró rendeléseket lemondja, a helyet felszabadítja, a naplóba ír |
| `zaba-cron-history` | naponta 03:17 | A pg_cron egy hétnél régebbi futási előzményeit törli |

Mért: a lejárati jobot egy visszadatált rendelésen kipróbáltuk, lemondta és naplózta. A `verify.sh` figyelmeztet, ha a job nincs beállítva.

### 7.5 Titkok

- Minden titok (adatbázisjelszó, `JWT_SECRET`, `SERVICE_ROLE_KEY`, a webhook titka, a Cloudflare-token, az SMTP-jelszó) **csak a szerver `.env` fájljában** él (600-as módban), a mentésben (titkosítva), és a megrendelő jelszókezelőjében. Chatbe, e-mailbe, tárolóba **sosem** kerül.
- **Szivárgás esetén**: a `JWT_SECRET` és a kulcsok cseréje minden appot érvénytelenít (újra kell építeni és telepíteni); a webhook titkát és az adatbázisjelszót külön, a stack újraindításával lehet cserélni. A lépéseket a 9. fejezet futtatási kézikönyve adja.
- A `gitleaks` a CI-ban a teljes történetet átnézi.

### 7.6 Hozzáférések

- A `service_role` kulcs (a munkatársi eszköz és az ütemezés használja) **a legerősebb kulcs**: kiszivárogva bárki bármit olvashat és írhat. Csak a szerveren és az üzemeltető gépén lehet.
- Az admin oldalra csak Cloudflare Access mögül (4.3).
- Munkatársi fiókot a `tool/create_staff_user.py` hoz létre (saját szerveren a **régi, service_role JWT** kell hozzá: az új `sb_secret_` kulcsot az auth admin API ott 403-mal elutasítja).

## 8. Adatvédelem és jog (teendők, nem állítások)

Az alábbiakat **nem én döntöm el**, a lista a [`known-gaps.md`](known-gaps.md) 2-3. fejezetét egészíti ki az éles üzem szempontjából. A fejlesztési oldal már tud: adatot törölni nem (a fiókon az `orders.user_id` `restrict`), ezért **az érintett törlési kérelmére ma nincs eszköz**: anonimizáló függvény kell (a megőrzési kötelezettségekkel egyeztetve).

| Terület | Teendő | Ki |
|---|---|---|
| Adatkezelési tájékoztató, ÁSZF, impresszum, elállási jog | Elkészíteni és az appból (regisztrációnál, láblécben) linkelni | Jogász, megrendelő |
| Mit gyűjt az app, hol tárolódik, kik az adatfeldolgozók (a saját szerveren a szerver üzemeltetője, a Cloudflare, az SMTP- és a fizetési szolgáltató) | A tájékoztató alapja: a `known-gaps.md` tételes listája; adatfeldolgozói megállapodások | Jogász |
| Az érintett jogai (hozzáférés, törlés, export) | Folyamat és eszköz (anonimizálás, export) | Jogász, fejlesztő |
| Az allergén-tájékoztatás, az ÁFA-kulcsok | Az étlap adatait a megrendelő és a könyvelő hagyja jóvá; a demó adatai illusztratívak | Megrendelő, könyvelő |
| Számlázás (NAV Online Számla) | A működési forma szerint; számlázó adapter és `invoices` tábla | Könyvelő, fejlesztő |
| A szerver fizikai és hozzáférési védelme, incidenskezelés (adatvédelmi incidens bejelentése) | Folyamat és felelős kijelölése | Megrendelő, jogász |

## 9. Futtatási kézikönyv (események és teendők)

| Esemény | Teendő |
|---|---|
| **Az oldal nem érhető el** | `verify.sh`; a Cloudflare Tunnel él-e (`docker compose ps cloudflared`, a Cloudflare irányítópultja); a Caddy (`docker compose logs caddy`); az internet/áram a szerveren. Az alagút nélkül a szerver helyben (`127.0.0.1:8080`) működik |
| **Egy konténer nem egészséges** | `docker compose ps`, `sh run.sh logs <név>`; újraindítás: `docker compose restart <név>`; ha az adatbázis: lásd következő |
| **Az adatbázis leállt vagy összeomlott** | A Postgres és a PostgREST magától helyreáll összeomlás után (mértük); ha nem: `docker compose restart db`, majd `verify.sh`. Adatvesztés gyanújánál a mentésből: `restore.sh data` |
| **Elfogyott a lemez** | `df -h`, a legnagyobb könyvtárak; a mentések, a Docker-képek (`docker image prune`), a naplók; a `verify.sh` 80% fölött figyelmeztet |
| **Teljes gépvesztés** | Új gép: Docker, a repó; `restore.sh env <mentés>`, `install.sh`, `restore.sh data <mentés>`, `verify.sh`, a webes buildek újratelepítése (`deploy-web.sh`). Mért idő a számítástechnikai rész: ~130 s kis adatbázison |
| **Kiszivárgott kulcs vagy jelszó** | Azonnal a Cloudflare-token és az érintett jelszavak cseréje; a `SERVICE_ROLE_KEY`/`JWT_SECRET` esetén új kulcsok és az appok újraépítése és újratelepítése; a munkatársi jelszavak cseréje; az `audit_log` és a naplók átnézése |
| **Valaki kitalálgatja a belépést** | A Cloudflare sebességkorlát és az Access (4.3); a naplókban a `/auth/v1/token` hibás kérései; az érintett fiókok jelszavának cseréje |
| **Egy rendelés beragadt fizetésre várva** | A `zaba-expire-unpaid` 30 perc után lemondja; kézzel az admin oldalon vagy `select public.expire_unpaid_orders(interval '5 minutes')` a service role-lal |
| **Fizetés megtörtént, a rendelés mégis fizetésre vár** | A webhook naplója (`sh run.sh logs functions`) és a `payment_events` tábla; az eseményt a szolgáltató újra tudja küldeni (idempotens). **Éles szolgáltatónál kötelező a kézi egyeztetés eljárása** |
| **Az érintett törlést kér** | Ma nincs eszköz (8. fejezet); jogásszal egyeztetett kézi eljárás kell, amíg nincs |

## 10. Go-live ellenőrzőlista

Jelölés: [ ] = még nincs kész. (A **Kész** a kódban/eszközben már megvan.)

**Biztonság**
- [ ] Cloudflare sebességkorlátozás az `api` hoston a `/auth/v1/token` és `/auth/v1/signup` útvonalra
- [ ] Cloudflare Access az `admin` host előtt; a munkatársak meghívva
- [ ] (Ha lesz natív app tömegesen) Turnstile a regisztrációra és belépésre, az app módosításával
- [ ] SSH csak kulccsal, tűzfal (bejövő tiltva), VPN az üzemeltetéshez
- [ ] A `verify.sh` minden sora `ok` (a WARN-ok megértve)
- [ ] A `ADMIN_DEMO_*` és a demó fiók **nincs** az éles buildekben
- [ ] Kész: a Studio, a meta API és a Storage nem érhető el az internetről; a CSP és a biztonsági fejlécek be vannak állítva
- [ ] Kész: minden SQL-függvény zárt (110 teszt), az `expire_unpaid_orders` csak a service role-é

**Fizetés**
- [ ] Szolgáltató kiválasztva, szerződés, tesztkörnyezetben kipróbálva
- [ ] Adapter megírva és tesztelve, **összeg- és pénznem-ellenőrzéssel**
- [ ] `FAKE_PAYMENTS_ENABLED=false`, a tesztkártya-súgó eltávolítva a képernyőről
- [ ] Valódi visszatérítés és a lemondás közbeni sikeres fizetés kezelése
- [ ] Kész: aláírt, időbélyeges, idempotens webhook; csak az esemény tehet kifizetetté rendelést

**Fiók és e-mail**
- [ ] SMTP beállítva, SPF/DKIM/DMARC; `ENABLE_EMAIL_AUTOCONFIRM=false`
- [ ] Az app kezeli a megerősítést és az elfelejtett jelszót
- [ ] Fióktörlés/anonimizálás és adatexport eszköze (a jogi egyeztetés szerint)

**Üzemeltetés**
- [ ] Mentés ütemezve, titkosítva, **másik gépre másolva**; a jelszófájl külön is megőrizve
- [ ] Helyreállítási próba egy külön gépen elvégezve
- [ ] A `verify.sh` ütemezve (cron), a riasztás kézbesül; külső üzemidő-figyelő beállítva
- [ ] UPS (otthoni szervernél) vagy bérelt szerver; mobilnet tartalék
- [ ] A célhardveren a terhelésmérés és a Realtime-kapcsolatok mérése megismételve
- [ ] A frissítési folyamat kipróbálva a stagingen
- [ ] Kész: a lejárati job ütemezve (`schedule.sh`), a naplók forognak, a `healthz` él

**Jog és üzlet**
- [ ] ÁSZF, adatkezelési tájékoztató, impresszum, elállási tájékoztatás elkészítve és az appban linkelve
- [ ] Adatfeldolgozói megállapodások; az incidenskezelés felelőse kijelölve
- [ ] ÁFA-kulcsok és allergén-adatok a könyvelő és a megrendelő által jóváhagyva
- [ ] Számlázás megoldva a működési forma szerint
- [ ] Az étlap, az árak, a zónák, a nyitvatartás az éles adatokkal (a `seed` demóadat!), a demó "DEMÓ" feliratok és a kitalált adatok eltávolítva
- [ ] Az Android-app saját aláírókulccsal, saját azonosítóval (`hu.zaba.app` helyőrző), áruházi beadás szabályainak ellenőrzése (nem tesztelt)

## 11. Kockázatok

| Kockázat | Valószínűség / hatás | Kezelés |
|---|---|---|
| **Egyetlen szerver, nincs tartalék** (hardver, áram, internet) | Közepes / a szolgáltatás kiesik | UPS, mobilnet, bérelt szerver, a mért ~130 s-os újjáépítés új gépen; magas rendelkezésre állás **nincs** |
| **A mentés ugyanazon a gépen marad** | Kicsi / a teljes adat elvész | Másik gépre másolás, helyreállítási próba |
| **Jelszó kitalálgatás** (nincs szerveroldali korlát) | Magas / fiókok átvétele | 4.3, kötelező az indulás előtt |
| **Hamis fizetés bekapcsolva marad** | Közepes / ingyen étel | `FAKE_PAYMENTS_ENABLED=false`, a `verify.sh` figyelmeztet; a függvény alapból zárt |
| **Összeghiba az éles webhookban** | Közepes / veszteség | 5. fejezet 3. pont, kötelező ellenőrzés és teszt |
| **Kiszivárgó titok** | Kicsi / nagy | 7.5, a `.env` csak a szerveren, a mentés titkosítva, `gitleaks` |
| **A Supabase self-host kiadás frissítése eltör valamit** | Közepes / üzemzavar | Rögzített kiadás, CHANGELOG, staging, mentés előtte |
| **Spam rendelések az idősávok lefoglalására** | Kicsi / a valódi vevők nem találnak helyet | Vásárlónként legfeljebb 5 fizetésre váró rendelés, 30 perc utáni lejárat (kész, mért) |
| **A kimaradás-érzékelés hiánya** | Közepes / észrevétlen leállás | Külső üzemidő-figyelő |
| **Jogi megfelelés hiánya** (adatkezelés, ÁSZF, számlázás) | Magas az indulásnál / bírság, leállítás | 8. fejezet, jogász bevonása indulás előtt |
| **Az adatok törlésének hiánya** | Közepes / jogi | Anonimizáló eszköz (8. fejezet) |
| **Az admin lista csak a legutóbbi 200, a vásárló csak a legutóbbi 50 rendelést tölti be** | Kicsi / nagy forgalomnál régi, aktív rendelés kieshet a listából | Szerveroldali szűrés és lapozás (lásd `known-gaps.md`) |

## 12. Lépések és becslés

A becslés **fókuszált fejlesztői óra**, nem naptári idő; a külső függőségek (szolgáltatói szerződés, jogász, domain, hardver) várakozása nincs benne.

| Fázis | Tartalom | Óra |
|---|---|---|
| **A. Biztonsági alapok** | Cloudflare szabályok és Access beállítása, tűzfal, VPN, SSH (nagyrészt beállítás, nem kód) | 4-8 |
| **B. E-mail és fiók** | SMTP, megerősítési és jelszó-visszaállítási képernyők, fióktörlés/anonimizálás, adatexport | 14-22 |
| **C. Fizetés** | Szolgáltatói adapter, összegellenőrzés, visszatérítés, lemondás közbeni fizetés, tesztek | 16-26 (a szolgáltatótól függ) |
| **D. Üzemeltetés** | Mentés ütemezése és másolása, figyelés, riasztás, frissítési folyamat, helyreállítási próba a célhardveren | 8-12 |
| **E. Pilot** | Zárt kör valódi rendelésekkel, mérések a célhardveren, hibajavítás | 12-20 |
| **F. Jog és üzlet** | ÁSZF, tájékoztató, számlázás: elsősorban jogász és könyvelő munkája; fejlesztői oldalon a linkek, az adatok éles feltöltése | 6-10 |
| **Összesen** | | **~60-100** |

## 13. Döntések a megrendelőnek

1. **Hol fusson a szerver** (otthon, bérelt, kihelyezett)? Mekkora kiesés fogadható el?
2. **Melyik fizetési szolgáltató?** (Díjak, kártyatípusok, kifizetési idő.)
3. **Melyik SMTP-szolgáltató?** Melyik küldő domain?
4. **Milyen domain** (az appokba beépül)?
5. **Ki az üzemeltető**, aki a mentést, a figyelést és a riasztást kezeli (és helyettese)?
6. **Mekkora adatvesztés elfogadható** (napi mentés elég-e, vagy folyamatos archiválás kell)?
7. **Kell-e natív app az indulásnál**, vagy elég a webes változat (a Turnstile és az áruházi beadás ettől függ)?
8. **Ki készíti a jogi dokumentumokat** és a számlázás megoldását?
