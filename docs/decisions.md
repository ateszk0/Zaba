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
szolgáltatói azonosítókat). **A tulajdonos 2026-10-21-én a fejlesztői beszélgetésben írásban megerősítette, hogy a „Falatozó" saját munkája.** Az átadási csomagba ezt a megrendelő felé is érdemes rögzíteni (jogi szöveg: ügyvéddel egyeztetendő).

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
| Tesztek | 136 pgTAP-állítás (`supabase test db`) + 20 HTTP-ellenőrzés (`supabase/tests/api_smoke.py`) | A jogosultságokat valódi szerepkörökkel és valódi HTTP-hívásokkal is próbáljuk |

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

## Belépés (c lépés)

| Téma | Döntés | Miért |
|---|---|---|
| Ki mit lát | Az étlap és a kosár vendégként is használható; a pénztár, a fizetés és a rendelés-követés belépést kér (a vendég a belépés után oda kerül vissza, ahová tartott, a kosara megmarad). A Rendeléseim fül vendégnek belépési felhívást mutat | A bemutatón ne legyen fal a böngészés előtt, a rendelés viszont fiókhoz kötött (RLS) |
| Mód | E-mail + jelszó, e-mail-megerősítés **kikapcsolva** (lokálisan `config.toml`, self-hostnál `ENABLE_EMAIL_AUTOCONFIRM`) | A beépített levélküldés erősen korlátozott; a demón kitalált adatok vannak. Az MVP-ben megerősítés kell, az app már kezeli a „nincs session" esetet (`emailNotConfirmed`) |
| Demó fiók | A belépő képernyő „Belépés demó fiókkal" gombja a `DEMO_EMAIL` / `DEMO_PASSWORD` build-értékekből lép be; a fiókot a `tool/create_demo_user.py` hozza létre (csak a nyilvános regisztrációs végpontot használja, titok nélkül) | A jelszó az appba van fordítva, ezért eldobható fiók, kitalált adatokkal; nem titok. Az adatbázis `db reset` után a fiók elvész, a szkript újrafuttatható |
| Vendég-belépés (anonim) | Elvetve | Minden megnyitás új, üres felhasználót csinálna, és nem lenne előre kitöltött demó adat |
| Offline mód | `SUPABASE_URL` nélkül az app a memóriabeli adatokon fut, egy beépített demó fiókkal | `flutter run` backend nélkül is megy, a CI build nem kér titkot. A banner továbbra is jelzi, hogy demó |
| Réteg | `AuthRepository` interfész, kétféle megvalósítás (memóriabeli és Supabase); a hibák egyetlen típusba (`AuthFailure`) fordulnak, a szerver szövege sosem jut a felhasználóig | A hibaüzenetek magyarok és egy helyen vannak; a szerver üzenete nem szivárog ki |
| Hibák felismerése | A GoTrue hibakódja (`invalid_credentials`, `user_already_exists`, …), nem a szövege | A szöveg változhat, a kód stabil |
| Munkamenet | A Supabase kliens kezeli és frissíti; weben a böngésző `localStorage`-ában él (újratöltés után bent marad, böngészőben ellenőrizve). `detectSessionInUri` kikapcsolva | A webes URL töredéke a routeré (`#/…`), az app nem használ e-mail linket |
| Átirányítás | A router a vendéget a belépésre küldi (`/login?from=…`), a `from` csak alkalmazáson belüli útvonal lehet. Belépés után a képernyő maga lép tovább | A `redirect` egy ráfordított (pushed) oldalnál csak az alatta lévő oldalt látja, ezt egy teszt találta meg |
| Függőség | `supabase_flutter` 2.18.3 (a hivatalos Supabase SDK; a pub.dev ellenőrzött kiadója `supabase.io`, licenc MIT, 2026-10-21-én nincs visszavonási vagy biztonsági figyelmeztetés), a verzió a `pubspec.lock`-ban rögzített | A terv eleve ezt tartalmazza; a licenc bekerül az átadási licenclistába |
| Regisztráció | Név (nem kötelező), e-mail, jelszó (min. 8 karakter, a `config.toml`-lal egyezően); a név a `profiles`-ba kerül egy adatbázis-trigger által | A jelszószabályt a szerver érvényesíti, a kliens csak időt spórol |

**Amit a tesztelés megtalált:**

- Egy túl hosszú név (a `profiles.full_name` 200 karakternél korlátoz) az **egész regisztrációt** megbuktatta volna (adatbázishiba a triggerben). A `20261021100000_signup_robustness.sql` levágja a nevet; az app is korlátozza a mezőt, és a `070_signup.test.sql` őrzi.
- A valódi Supabase-kliens PKCE-tárolót kér, amit az alkalmazás a `shared_preferences`-ből kap; a Dart-tesztben memóriabeli tároló áll a helyén.
- Vendégként a `profiles` táblához nincs jog (`permission denied`), nem üres lista: ez a zárt alapértelmezés következménye, és így jó.

**Ismert korlátok (demó, az MVP-ben kezelendő):**

- A „már van fiók ezzel a címmel" üzenet elárulja, hogy egy cím regisztrált-e (felhasználó-felderítés). Megerősítéssel az MVP-ben ez elkerülhető.
- A rendelések még a memóriabeli tárból jönnek, nem felhasználónként: kijelentkezés után egy másik fiók ugyanazon az eszközön látná őket. A következő lépések (pénztár és rendelés a szerveren, RLS) ezt megszüntetik.
- Profilszerkesztés (név, telefon, allergén-figyelmeztetések, mentett címek) nincs; az adatbázis előkészített hozzá.
- Elfelejtett jelszó nincs (e-mail küldés nélkül nem működik).

**Mérés a c lépés után** (`flutter build web --release`, `supabase_flutter`-rel és az a2–a3 funkcióival): `main.dart.js` 3,47 MB nyers, 1,00 MB gzip -9 (az (a) lépés után 2,9 / 0,83 MB; a növekedés nem csak a Supabase-klienstől van).

## Katalógus (d lépés)

| Téma | Döntés | Miért |
|---|---|---|
| Olvasás | `SupabaseCatalogRepository`: a `categories` tábla és a `catalog_products` nézet (az aktuális árral), vendégként is; az inaktív sorokat az RLS rejti el | Az ár és az étlap forrása a szerver, a kliens nem számol árat |
| Keresés | **Marad a kliensben** (ékezetfüggetlen, `foldText`), nem szerveroldali `unaccent`, ellentétben az eredeti tervvel | Az egész étlap (45 termék) egyszer letöltődik, így a találat azonnali, nincs kérés minden betűnél. Ha az étlap több száz tételre nő (MVP), akkor `unaccent` + `pg_trgm` a szerveren |
| Ismeretlen allergénkód | A betöltés hibával áll meg, nem hagyja ki csendben | Az allergén-információ biztonsági adat; egy elavult app ne mutasson hiányos allergénlistát |
| Hiba | Ha a termékek vagy a kategóriák betöltése bukik, az étlap hibanézetet mutat, az „Újra" mindkettőt újratölti | Valódi hálózaton előfordul; korábban a kategóriahiba csendben elmaradt |
| Képek | Változatlanul az app csomagjában (azonos eredet), az `image_path` csak a fájlnév | Nincs CORS, nem terheli a Supabase egress-ét |

**Amit a tesztelés megtalált:**

- A `postgrest-dart` `order()` alapból **csökkenő**: a kategóriák fordított sorrendben jöttek (Italok elöl). Egy integrációs teszt találta meg, ami a szerverről visszaolvasott étlapot mezőről mezőre összeveti a Dart demóadatokkal (a seed ebből generálódik). Az irányok most kifejezettek.
- Egy kategória-betöltési hiba csendben elmaradt (üres chip-sor, az étlap rendben) – most a teljes étlapot hibára állítja.

**Nem része:** szerkeszthető étlap, készletkezelés (az `inventory` tábla előkészített), képfeltöltés – MVP.

## Kosár és kiszállítás (e lépés)

| Téma | Döntés | Miért |
|---|---|---|
| Árazás | A kosarat a `quote_cart` függvény árazza a szerveren; a kosár sora a **szerver** egységárát és sorösszegét mutatja (`QuoteLine`), nem a menüben betöltött árat | Ha az ár a menü betöltése után változik, a sor és a végösszeg nem mondhat ellent egymásnak; a kliens sosem számol végösszeget |
| Zónák | A `delivery_zones` és a prefixek egyszer töltődnek le, az irányítószámot a kliens illeszti rájuk (`zoneServing`); a szerver az árazáskor és a rendeléskor újra ellenőrzi | A címdialógus azonnal válaszol; a döntés a szerveré marad. A zónák az app élettartamára gyorsítótárazottak: egy üzemeltetői módosítás újratöltésig nem látszik (az MVP admin felületével ez finomítandó) |
| Idősávok | A `get_delivery_slots` (csak belépett vevőnek) sávjai azonosítóval (`DeliverySlot.id`), mert a rendelés az azonosítót foglalja; a szerver a saját órájával és a bolt időzónájában dönt, a kliens a készülék időzónájában mutatja | Magyarországon a kettő azonos; külföldről nézve a megjelenített idő eltérhet (időzónacsomag nélkül nem oldható meg) |
| Mentett kosár | A `shared_preferences` (weben `localStorage`, kulcs: `zaba.cart.v1`) csak terméket és mennyiséget tárol, árat nem; betöltéskor csak az értelmes sorokat veszi át, a hibás vagy szerkesztett tartalmat eldobja | Újratöltés után a kosár megmarad (böngészőben ellenőrizve); egy módosított tárolt érték nem juttathat be érvénytelen sort |
| Mennyiség | Egy sor legfeljebb 99 db (a szerver is ennyit fogad el, `invalid_lines`) | Különben a +-gomb túl sok kattintása az egész kosarat árazhatatlanná tenné |
| Megszűnt termék | A szerver kihagyja az árazásból; az app ilyenkor a kosárból is kiveszi (`cartPruningProvider`) | A mentett kosárban lehet olyan termék, ami közben lekerült az étlapról; a tételszám és a sorok egyezzenek |
| Üres kosár | Nem megy rá kérés a szerverre | Fölösleges hívás lenne a Kosár fülön és az app indulásakor |
| Hiba | Az árazás hibájánál a kosár hibanézetet mutat, az „Újra" a menüt is újratölti; a kosár tartalma nem vész el, ha a szerver elérhetetlen | Valódi hálózaton előfordul |

**Ellenőrzés:** az integrációs teszt ugyanazokat a kérdéseket (belső és külső zóna, ingyenes szállítás küszöb alatt és fölött, több termék, cím nélküli becslés, üres kosár) a szerveren és a Dart szabályokon is felteszi, és azonos választ vár; ez tartja egyben az SQL-t és a Dart másolatát. A zónák és a nyitvatartás-alapú idősávok mezőről mezőre egyeznek a demóadatokkal. Eltérést nem talált.

**Ismert korlátok (demó):**

- Minden +/− érintés új árazási kérést indít, nincs késleltetett összevonás; a legutolsó válasz számít. Gyors kattintásnál a szám egy pillanatra elmaradhat.
- A rendelés még a memóriabeli tárba kerül, ezért az idősáv foglalása sem a szerveren történik; a következő lépés (rendelés és fizetés a szerveren) ezt megszünteti. A pénztár addig is a szerver árazását és idősávjait használja, ezért belépés kell hozzá.
- A cím nincs mentve (újratöltés után újra meg kell adni); a mentett címek az MVP-ben jönnek.

## Rendelés és fizetés (f lépés)

A teljes folyamat és a sorozatdiagram: [`payment-flow.md`](payment-flow.md).

| Téma | Döntés | Miért |
|---|---|---|
| Ki fizet | A rendelést csak a szolgáltató aláírt eseménye teheti kifizetetté (`payments-webhook` → `apply_payment_event`); az app nem ír rendelést | A brief szerint a szolgáltató eseménye az egyetlen igazságforrás |
| Szolgáltató | `PaymentProvider` interfész TypeScriptben, a demóban `FakePaymentProvider`; a `fake-provider-confirm` a szolgáltató "háttere" | Éles szolgáltatóra váltáskor egy új osztály kell, a rendelési logika nem változik |
| Függőségek | A függvények nem importálnak semmit távolról, a Supabase-et sima `fetch`-csel (PostgREST) hívják; a közös kód csak Web API-t használ | Hálózat nélkül is elindulnak, ugyanúgy futnak lokálisan, a saját szerveren és a felhőben, és Node alatt is tesztelhetők (nincs Deno a gépen) |
| Titok | `FAKE_PAYMENT_WEBHOOK_SECRET`: lokálisan `supabase/.env` (git-ignorált), a szerveren a telepítő generálja a stack `.env`-jébe, a felhőben `supabase secrets set`. Hiányában a függvények leállnak | Nincs alapértelmezett érték, amit valaki ismerhetne |
| Aláírás | `t=<unix>,v1=<HMAC-SHA256 hex>` az `<t>.<törzs>` szövegen, 5 perces tűréssel, időzítés-biztos összehasonlítással | Az időbélyeg az aláírt szövegben van, így egy régi esemény nem adható ki újnak |
| Idempotencia | Az esemény azonosítója egyedi az adatbázisban; ugyanaz kétszer egyszer hat | A szolgáltatók többször is kézbesíthetnek |
| Követés | A rendelés és a lista a Realtime-ra iratkozik fel; amíg az nem él, 5 mp-enként lekérdez, és percenként akkor is frissít; a kapcsolat felépülése után 2 mp-cel még egyszer lekérdez | A Realtime a feliratkozást kicsivel azelőtt jelzi késznek, hogy ténylegesen kézbesítene, az ott történt változás elveszne |
| Hibák | A hálózati hibát a pénztár és a fizetés képernyő kezeli ("nem sikerült", újra lehet próbálni); a rendelés idempotencia-kulcsa miatt az újrapróbálás nem hoz létre másodikat | Valódi hálózaton előfordul |
| Új függőségek | `shared_preferences` 2.x (flutter.dev, a mentett kosárhoz, e lépés) és `fake_async` 1.3.3 (dev; dart.dev ellenőrzött kiadó, Apache-2.0, nincs figyelmeztetés a pub.dev-en 2026-10-21-én; a Realtime-logika idővezérelt tesztjeihez). Mindkettő már közvetett függőség volt | A licenc bekerül az átadási licenclistába |
| Kiszolgáló gomb | A "rendelés léptetése (demó)" gomb csak a backend nélküli módban van meg; backenddel a konyha az admin oldal (g lépés) | A vásárlónak nincs joga rendelést léptetni |

**Amit a tesztelés megtalált:**

- **Valódi hiba az adatbázisban:** egy lezárt (elutasított) fizetési kísérlet késve érkező "sikeres" eseménye nem talált nyitott kísérletet, mégis kifizetettnek jelölte a rendelést. A `20261021110100_payment_event_matching.sql` az eseményt csak nyitott, egyező kísérletre engedi hatni (ha az esemény megnevezi a kísérletet, annak kell lennie).
- Egy vásárló a rendelése idősávjának idejét nem láthatta (a `delivery_slots` táblához nem volt olvasási jog). A `20261021110000_order_slot_visible.sql` megnyitja a saját rendelések idősávját (azonosító és idő, a kapacitás nem).
- A Realtime a feliratkozást a szerver tényleges készenléte előtt jelezte késznek: a frissítés a felépülés utáni másodpercekben elveszhet. Ezért a 2 mp-es utólagos lekérdezés.
- Az önállóan futtatott (self-hosted) átjáró a **frissen újraindított** függvény-tárolóra pár másodpercig 503-at ad, mert kétszer jó állapotellenőrzés kell neki. A telepítő megvárja, míg a függvények válaszolnak.

**Ismert korlátok:** lásd [`payment-flow.md`](payment-flow.md). Nem tesztelt: a felhős Supabase Edge Functions futása (a `demo` környezet, h lépés), a Proxmox VM és a Cloudflare Tunnel (a WebSocket a Cloudflare-en át).

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
