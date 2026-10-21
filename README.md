# Zaba

> **Ez egy demó, éles használatra nem alkalmas. A hiányzó elemek listája lent.**

A Zaba egy magyar ételrendelő és házhozszállító alkalmazás (Flutter mobil + web, Supabase backend).
Ez a repó a **0. fázis**: egy bemutatható demó, amelyen a megrendelő a saját telefonján végigmehet egy
teljes vásárlási úton. Az architektúra úgy épül, hogy az MVP-be **bővítéssel**, nem újraírással lehessen eljutni.

## Állapot

| Lépés | Tartalom | Állapot |
|---|---|---|
| a | Projektváz, CI, témázás | kész |
| a2 | Étlap, termék lap, kosár, címválasztó (memóriabeli adatokkal) | kész |
| a3 | Pénztár, szimulált kártyás fizetés, rendeléskövetés, rendeléslista (memóriabeli adatokkal) | kész |
| b | Adatmodell, lokális backend (Supabase), seed adatok, termékfotók | kész |
| b+ | Saját szerveres (staging) környezet: telepítő, Caddy, Cloudflare Tunnel, runbook | kész és helyben tesztelt; a Proxmoxon és a tunnelen még nem futott |
| c | Belépés és regisztráció (Supabase Auth), demó fiók, védett útvonalak | kész |
| d | Étlap a Supabase-ből (kategóriák, termékek, árak), betöltési és hibaállapotok | kész |
| e | Kosár a szerver árazásával, kiszállítási zónák és idősávok a Supabase-ből, mentett kosár | kész |
| f | Rendelés leadása és fake fizetés a szerveren (Edge Function-ök, aláírt webhook), élő rendelés-követés | kész |
| g | Mini admin (Flutter web: belépés, élő rendeléslista, állapotváltás, audit napló), szimulált értesítések a vásárlónál | kész |
| h | Demó környezet: Cloudflare (app, admin, APK letöltés) és Supabase Free, szigorú fejlécek, aláírt Android APK, napi életben tartás | kész és helyben tesztelt (emulátoron az APK is); a felhős fiókokon még nem futott |
| i | Eszközellenőrzés: telefonos ellenőrző lista, helyi hálózati előnézet, kis kijelzős tesztek, iPhone biztonságos terület | kész a részem; a listát te futtatod a telefonokon (iPhone Safari, Android Chrome, APK): jóváhagyásra vár |
| j | Átadási csomag | nincs |
| k | Végleges logó | nincs |

## Helyi indítás

Követelmény: Flutter **3.47.0** (Dart 3.13).

```sh
cd app
flutter pub get
flutter test
flutter run -d web-server --web-port 8080   # vagy: -d chrome / Android eszköz
```

Release web build: `flutter build web --release` (kimenet: `app/build/web`).

### Backend (Supabase, lokális Docker)

Követelmény: Docker és Node.js. A Supabase CLI verziója a `package.json`-ban rögzített.

```sh
npm ci
echo "FAKE_PAYMENT_WEBHOOK_SECRET=$(openssl rand -hex 32)" > supabase/.env   # a fizetési függvények titka, egyszer
npx supabase start -x studio,imgproxy,vector,logflare,mailpit   # első indításkor sok képet tölt le
npx supabase db reset                                           # migrációk + seed adatok
npx supabase test db                                            # 149 pgTAP-állítás
python3 supabase/tests/api_smoke.py --from-local                # 20 HTTP-ellenőrzés
pip install websockets && python3 supabase/tests/realtime_smoke.py --from-local   # élő rendelésfrissítés
python3 supabase/tests/payment_smoke.py --from-local            # 28 ellenőrzés a fizetési úton (valódi Edge Function-ök)
npm run test:functions                                          # a fizetési kód Node-tesztjei (aláírás, munkamenet, webhook)
python3 tool/create_demo_user.py --from-local                   # a demó vásárló (db reset után újra kell)
python3 tool/create_staff_user.py --from-local --role operator  # konyhai munkatárs: konyha@zaba.example (db reset után újra)
python3 tool/create_staff_user.py --from-local --role admin     # admin: admin@zaba.example
npx supabase stop
```

Az app a lokális Supabase-zel (a `config/dev.example.json` mintájára készített, gitignore-olt `config/dev.json`-nal):

```sh
cd app
flutter run -d web-server --web-port 8080 --dart-define-from-file=../config/dev.json
# a belépés valódi Supabase-kliensét a futó stackkel is kipróbálja:
flutter test test/integration \
  --dart-define=ZABA_TEST_SUPABASE_URL=http://127.0.0.1:54321 \
  --dart-define=ZABA_TEST_SUPABASE_KEY=<a `supabase status` publikus (anon) kulcsa> \
  --dart-define=ZABA_TEST_SUPABASE_SECRET_KEY=<a `supabase status` titkos kulcsa: csak az admin tesztekhez, munkatársi fiókot hoz létre>
```

Konfiguráció (`SUPABASE_URL`) nélkül az app a memóriabeli adatokon, egy beépített demó fiókkal fut.

A kezelőfelület (admin) külön belépési pont, csak backenddel működik:

```sh
cd app
flutter run -d web-server --web-port 8081 -t lib/main_admin.dart --dart-define-from-file=../config/dev.json
flutter build web --release -t lib/main_admin.dart --dart-define-from-file=../config/dev.json   # kimenet: app/build/web
```

A belépés a fent létrehozott munkatársi fiókkal megy. A `config/dev.json` `ADMIN_DEMO_*` értékei egy „Belépés demó munkatársként" gombot adnak a helyi fejlesztéshez; a vásárlónak adott build ezeket ne tartalmazza.

A kliens `SUPABASE_URL`-jét és publikus kulcsát a `config/<env>.json` adja, a titkos kulcs sosem kerül az appba.
A saját szerveres (Proxmox, Cloudflare Tunnel) telepítés leírása: [`deploy/selfhost/README.md`](deploy/selfhost/README.md).
Az adatmodell: [`docs/data-model.md`](docs/data-model.md).

## Felépítés

```
app/        Flutter kliens (mobil + web); lib/core = közös alap, lib/features = funkciók
supabase/   adatbázis: migrációk, seed adatok, Edge Function-ök (fizetés), tesztek (pgTAP, HTTP)
deploy/     selfhost: a saját szerveres staging; demo: a megrendelőnek adható demó (Cloudflare, Supabase, APK)
config/     környezetenkénti dart-define sablonok (az éles fájlok nincsenek a repóban)
docs/       döntések és dokumentáció
tool/       segédscriptek (betűtípus-részhalmaz, termékfotók)
```

A titkok sosem kerülnek a repóba: lásd `.env.example`. A kliensbe (web build, APK) csak publikus érték kerülhet.

## Ismert hiányosságok (a demóban nincs, az MVP-ben pótolandó)

- Valódi fizetés (a demóban szimulált), számlázás (NAV Online Számla)
- Tartós adat: a felület jelenleg memóriabeli adatokkal fut, a rendelések az app újraindításakor elvesznek (a Supabase backend bekötéséig)
- Valódi push értesítés (a demóban csak appon belüli értesítés)
- Apple/Google belépés, fiók törlése az appból, adatexport, GDPR hozzájárulás-kezelés
- Áruházi beadás (App Store, Google Play), natív iOS build
- Készletfoglalás a checkout idejére
- Teljes biztonsági hardening (rate limiting, admin 2FA, szigorú CORS és fejlécek)
- Monitoring, hibakövetés, automatikus mentés és visszaállítási eljárás
- Jogi dokumentumok (ÁSZF, adatkezelési tájékoztató, impresszum): ügyvéddel egyeztetendők

## Dokumentáció

- [`docs/decisions.md`](docs/decisions.md): technológiai döntések, mérések, nyitott ellenőrzések
- [`docs/data-model.md`](docs/data-model.md): ER-diagram, a rendelés állapotgépe, ki mit írhat
- [`docs/payment-flow.md`](docs/payment-flow.md): a fizetés sorozatdiagramja, mi igazi és mi szimulált, éles szolgáltatóra váltás
- [`docs/demo-environment.md`](docs/demo-environment.md): a megrendelőnek adható demó telepítése (Cloudflare, Supabase Free, Android APK), amit te csinálsz meg
- [`docs/test-checklist.md`](docs/test-checklist.md): a telefonos ellenőrző lista (iPhone Safari, Android Chrome, Android-app), és az előnézet a saját gépről (`tool/lan_preview.sh`)
- [`docs/image-credits.md`](docs/image-credits.md): a termékfotók forrása és licence
- [`deploy/selfhost/README.md`](deploy/selfhost/README.md): a saját szerveres staging telepítése és üzemeltetése
