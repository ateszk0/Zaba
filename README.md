# Zaba

> **Ez egy demó, éles használatra nem alkalmas. A hiányzó elemek listája lent.**

A Zaba egy magyar ételrendelő és házhozszállító alkalmazás (Flutter mobil + web, Supabase backend).
Ez a repó a **0. fázis**: egy bemutatható demó, amelyen a megrendelő a saját telefonján végigmehet egy
teljes vásárlási úton. Az architektúra úgy épül, hogy az MVP-be **bővítéssel**, nem újraírással lehessen eljutni.

## Állapot

| Lépés | Tartalom | Állapot |
|---|---|---|
| a | Projektváz, CI, témázás | kész, jóváhagyásra vár |
| a2 | Étlap, termék lap, kosár, címválasztó (memóriabeli adatokkal) | kész, jóváhagyásra vár |
| a3 | Pénztár, szimulált kártyás fizetés, rendeléskövetés, rendeléslista (memóriabeli adatokkal) | kész, jóváhagyásra vár |
| b | Adatmodell, lokális backend (Supabase), seed adatok, termékfotók | kész, jóváhagyásra vár |
| b+ | Saját szerveres (staging) környezet: telepítő, Caddy, Cloudflare Tunnel, runbook | kész és helyben tesztelt; a Proxmoxon és a tunnelen még nem futott |
| c–g | Auth, katalógus, kosár, checkout + fake fizetés, rendelésállapot + mini admin | nincs |
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
npx supabase start -x studio,imgproxy,vector,logflare,mailpit   # első indításkor sok képet tölt le
npx supabase db reset                                           # migrációk + seed adatok
npx supabase test db                                            # 131 pgTAP-állítás
python3 supabase/tests/api_smoke.py --from-local                # 20 HTTP-ellenőrzés
pip install websockets && python3 supabase/tests/realtime_smoke.py --from-local   # élő rendelésfrissítés
npx supabase stop
```

A kliens `SUPABASE_URL`-jét és publikus kulcsát a `config/<env>.json` adja, a titkos kulcs sosem kerül az appba.
A saját szerveres (Proxmox, Cloudflare Tunnel) telepítés leírása: [`deploy/selfhost/README.md`](deploy/selfhost/README.md).
Az adatmodell: [`docs/data-model.md`](docs/data-model.md).

## Felépítés

```
app/        Flutter kliens (mobil + web); lib/core = közös alap, lib/features = funkciók
supabase/   adatbázis: migrációk, seed adatok, tesztek (pgTAP, HTTP)
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
- [`docs/image-credits.md`](docs/image-credits.md): a termékfotók forrása és licence
- [`deploy/selfhost/README.md`](deploy/selfhost/README.md): a saját szerveres staging telepítése és üzemeltetése
