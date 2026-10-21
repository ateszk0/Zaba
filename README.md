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
| f | Rendelés leadása és fake fizetés a szerveren (Edge Function-ök, aláírt webhook), élő rendelés-követés | kész és tesztelt (lokális és self-hosted Supabase, böngészőben is); jóváhagyásra vár |
| g | Mini admin (Flutter web), szimulált értesítések | nincs |
| h–j | Web build + deploy + APK, eszközellenőrzés, átadási csomag | nincs |
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
python3 tool/create_demo_user.py --from-local                   # a demó fiók (db reset után újra kell)
npx supabase stop
```

Az app a lokális Supabase-zel (a `config/dev.example.json` mintájára készített, gitignore-olt `config/dev.json`-nal):

```sh
cd app
flutter run -d web-server --web-port 8080 --dart-define-from-file=../config/dev.json
# a belépés valódi Supabase-kliensét a futó stackkel is kipróbálja:
flutter test test/integration \
  --dart-define=ZABA_TEST_SUPABASE_URL=http://127.0.0.1:54321 \
  --dart-define=ZABA_TEST_SUPABASE_KEY=<a `supabase status` publikus kulcsa>
```

Konfiguráció (`SUPABASE_URL`) nélkül az app a memóriabeli adatokon, egy beépített demó fiókkal fut.

A kliens `SUPABASE_URL`-jét és publikus kulcsát a `config/<env>.json` adja, a titkos kulcs sosem kerül az appba.
A saját szerveres (Proxmox, Cloudflare Tunnel) telepítés leírása: [`deploy/selfhost/README.md`](deploy/selfhost/README.md).
Az adatmodell: [`docs/data-model.md`](docs/data-model.md).

## Felépítés

```
app/        Flutter kliens (mobil + web); lib/core = közös alap, lib/features = funkciók
supabase/   adatbázis: migrációk, seed adatok, Edge Function-ök (fizetés), tesztek (pgTAP, HTTP)
deploy/     saját szerveres (staging) telepítés: telepítő, Caddy, Cloudflare Tunnel
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
- [`docs/image-credits.md`](docs/image-credits.md): a termékfotók forrása és licence
- [`deploy/selfhost/README.md`](deploy/selfhost/README.md): a saját szerveres staging telepítése és üzemeltetése
