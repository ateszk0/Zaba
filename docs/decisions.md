# Döntések, mérések, nyitott ellenőrzések

## Eredet (provenance)

A Zaba kódja önállóan készült. **Nem tartalmaz, és nem használ forrásként harmadik fél védett kódját**
(például más cégek alkalmazásaiból dekompilált vagy átírt kódot, nem publikus API-szerződéseket).
Az ilyen referenciaanyagot a repón kívül kell tartani; a `.gitignore` a `kinyert_funkciok/` mappát
kizárja, hogy véletlenül se kerüljön commitba vagy az átadási csomagba.

**A felület elrendezésének forrása.** A képernyők szerkezete és a vásárlási folyamat (címsor és keresés, kategóriachipek,
termékkártyák, tétellap allergénekkel, kosár, fizetés, rendeléskövetés) a tulajdonos által átadott „Falatozó" nevű
Flutter demóalkalmazás alapján készült. A tulajdonos ezt saját munkájaként adta át; az alkalmazás a Zaba
architektúrájához igazítva, újraírva került át (Riverpod, szerveroldali árazás szerződése, saját téma és szövegek).
Kupon, borravaló, elsőbbségi kiszállítás, kedvencek, több étterem és emoji-illusztrációk nem kerültek át. Az átadott
alkalmazás eredetét külső forrásból nem tudtam ellenőrizni (a README szerint saját, és nem tartalmaz ismert
szolgáltatói azonosítókat); **az átadás előtt a tulajdonosnak írásban meg kell erősítenie, hogy az saját munkája.**

## Technológiai döntések

| Terület | Döntés | Miért |
|---|---|---|
| Kliens | Flutter 3.47.0 / Dart 3.13, Riverpod, go_router, `flutter gen-l10n` (hu) | A megrendelő Flutter vagy React Native alapot kért; kevés függőség |
| Backend | Supabase (Postgres + Auth + RLS + Realtime + Edge Functions) | Valódi Postgres az MVP-modellhez; RLS; Realtime az élő állapotkövetéshez |
| Hosting | Fejlesztés: saját szerver + Cloudflare Tunnel; demó: Cloudflare Pages + Supabase Free | Ingyenes fejlesztés, utána ingyenes felhős szint; minden hordozható |
| Betűtípus | Baloo 2 (címsor) + Inter (törzs), statikus, Latin/Latin-Extended részhalmaz, az app csomagjában | Kis méret (7 fájl, ~340 KB a ~1,5 MB helyett), nincs külső fetch; az ő/ű/Ő/Ű glifek ellenőrzöttek (`tool/fonts/subset_fonts.py`) |
| Pénz | `Money` típus, egész forint, bruttó; az authentikus végösszeg szerveroldali | Sosem float |
| Paletta | Levélzöld márka + paradicsompiros akcent meleg krém alapon | A kontraszt tesztelt (`test/core/theme/app_colors_test.dart`, WCAG AA/AAA) |

## Mérések (a) lépés után, `flutter build web --release`

| Fájl | Nyers | gzip -9 |
|---|---|---|
| `main.dart.js` | 2,9 MB | 0,83 MB |
| `canvaskit/canvaskit.wasm` (Safari, Firefox, minden iOS böngésző) | 7,1 MB | 2,8 MB |
| `canvaskit/chromium/canvaskit.wasm` (Chrome, Edge) | 5,3 MB | 2,0 MB |

Első betöltés iPhone-on durván 3,9 MB (gzip), a Cloudflare brotlival ennél kevesebb. A build mappa 41 MB, mert
minden renderer-változatot tartalmaz, de a böngésző csak egyet tölt le. **A funkciók készültével újramérendő.**

## Adatbázis és backend (b lépés)

Részletek: [`data-model.md`](data-model.md). A fontos döntések:

| Téma | Döntés | Miért |
|---|---|---|
| Futtatás | Supabase CLI (a `package.json`-ban rögzített verzió), lokális Docker stack | Ugyanaz a séma fut lokálisan, a saját szerveren és a felhőben; nincs kézi Studio-kattintgatás |
| Írás | Állapotot csak függvények változtatnak; a táblákhoz a kliensnek nincs írási joga | Egy hibás vagy hiányzó policy sem nyithat írási utat |
| Alapértelmezett jogok | Új tábla és függvény alapból zárt (`alter default privileges`), minden megnyitás kifejezett | Fordítva (alapból nyitott) a hiba csendes lenne |
| Rendelés leadása | `place_order` újraárazza a kosarat, ellenőrzi a zónát, a minimumot és az idősávot; idempotencia-kulcs véd a dupla leadás ellen | A kliens számai soha nem hitelesek; dupla kattintás nem hoz létre két rendelést |
| Fizetés | Csak az `apply_payment_event` (service role) teheti fizetetté a rendelést; az esemény azonosítója egyedi, így kétszer érkező esemény egyszer hat | A brief szerint a szolgáltató eseménye az egyetlen igazságforrás |
| Állapotgép | Az `order_status_transitions` tábla, amit a `private.transition_order` kényszerít ki | Új állapot felvétele egy helyen történik |
| Idősávok | A szerver rakja ki a bolt időzónájában; "foglalható" egyetlen szabály szerint dől el, a listázás és a rendelés ugyanazt használja | A nyitvatartás módosítása után a régi sorok nem maradnak foglalhatók (ezt egy teszt találta meg) |
| Seed | A katalógus SQL-je a Dart demóadatokból generálódik (`app/tool/seed_sql.dart`), egy teszt őrzi az egyezést | Egy forrás, nincs eltérés az app és az adatbázis között |
| Tesztek | 131 pgTAP-állítás (`supabase test db`) + 20 HTTP-ellenőrzés (`supabase/tests/api_smoke.py`) | A jogosultságokat valódi szerepkörökkel és valódi HTTP-hívásokkal is próbáljuk |

**Termékfotók.** Az Unsplash/Pexels kulcs vagy kézi böngészés nélkül nem keresgélhető géppel, ezért a fotók a Wikimedia Commonsból
jönnek, ahol a licenc géppel olvasható és ellenőrizhető. Csak **CC0, közkincs és CC BY** (csak névjelzés) licencű kép fogadható el:
a share-alike (SA) képeket átméretezzük és vágjuk, a terméket pedig átadjuk, ezért ott a szerzői jogi helyzet nem egyértelmű.
A névjelzések listája: [`image-credits.md`](image-credits.md). Ezek ellenőrzött adatok, de nem jogi tanács.

## Saját szerveres környezet (b+ lépés)

Kivitelezés és runbook: [`deploy/selfhost/`](../deploy/selfhost/README.md).

| Téma | Döntés | Miért |
|---|---|---|
| Stack | A hivatalos Supabase self-hosting csomag, rögzített kiadás (`self-hosted/v0.8.3`), nem a CLI fejlesztői stackje | A CLI stackjének alapértelmezett JWT-titka és kulcsai nyilvánosan ismertek: egy kiajánlott szerveren bárki hamis `service_role` tokent gyárthatna |
| Elérés | Cloudflare Tunnel (csak kifelé kapcsolódik), előtte Caddy, három host (app, api, admin) | A szerveren nincs nyitott bejövő port; a stabil címhez van saját domained |
| API-felület | A Caddy csak a `/rest`, `/auth`, `/realtime`, `/storage`, `/functions` útvonalat adja tovább, minden más 404 | A Studio és a Postgres meta API ugyanazon a gateway mögött él, kívülről nem szabad elérhetőnek lennie |
| Portok | A gateway és a Caddy alapból csak a loopbacken; a pooler portjai nincsenek közzétéve | A Docker megkerüli az `ufw`-t, ezért nem a tűzfalra bízzuk |
| Titkok | A telepítő egyszer generálja a szerver `.env`-jébe (600), nem írja ki; újrafuttatás nem írja felül | Egy meglévő adatbázis jelszava nem változhat meg véletlenül |
| Migrációk | `migrate.sh`: fájlonként egyszer, tranzakcióban, a CLI-vel azonos nyilvántartó táblába írva | A hivatalos csomag nem ad eljárást a saját migrációkhoz |

**Amit a tesztelés megtalált:**

- A self-hosted Realtime a WebSocketen **csak a régi, JWT-s anon kulcsot** fogadja el, az új `sb_publishable_…` kulcsot nem (REST-hez mindkettő jó). Ezért a staging app konfigurációjába az anon JWT kerül. A felhős Supabase-en ez nem probléma, ott az átültetéskor visszaválthatunk a publishable kulcsra.
- Egy sikeres fizetés két külön sor-módosítást okozott, így az élő követő egy félkész állapotot is látott ("fizetve, de még fizetésre vár"). A `transition_order` most egyetlen módosítással állítja a státuszt és a fizetési státuszt, a `start_payment` pedig nem ír, ha nincs változás. Ezt a `realtime_smoke.py` őrzi.
- A kliens-oldali útvonalak (`/menu`) alkalmazás-visszaesése nem takarhatja el a hiányzó fájlokat: kiterjesztéssel rendelkező hiányzó fájl valódi 404.
- A gateway általános CORS-szabálya minden origint enged, így a külön app és api host működik.

## Nyitott ellenőrzések

- **(h) CanvasKit forrása.** Az alapértelmezett web build a CanvasKitet a Google CDN-jéről
  (`gstatic.com/flutter-canvaskit/<engine>/`) tölti, nem a saját tárhelyről, és hiányzó glifekhez a
  `fonts.gstatic.com`-ról tölthet tartalék betűt. Mérés alapján eldöntendő: `--no-web-resources-cdn` (saját
  tárhelyről) használata. Emojit ezért nem használunk a felületen.
- **(h) Renderer.** CanvasKit (dart2js) a döntés; a `--wasm` próba sikerült (dry run), de iPhone-on nem hoz
  előnyt. A flutter.dev hivatalos dokumentációja alapján újraellenőrzendő.
- **(h/i) iOS Safari.** Biztonságos terület (notch, alsó sáv) kezelése a Flutter webben, billentyűzet viselkedése a
  checkout űrlapon és a keresésen, kezdőképernyős (standalone) mód.
- **(b+) Realtime a Cloudflare Tunnelen.** A WebSocket átmegy-e, nem igazolt; tartalék az 5 mp-es polling.
