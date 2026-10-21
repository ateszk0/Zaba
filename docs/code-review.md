# Kódellenőrzés: a teljes kódbázis, elsőként a saját szerveres környezet

> **Hatókör.** A teljes tároló átnézése (SQL-migrációk, Edge Function-ök, Flutter-app, tesztek, shell- és Python-eszközök, munkafolyamatok, telepítési fájlok), **és** a saját szerveres környezet (`deploy/selfhost/`) végigpróbálása egy friss telepítésen. A találatok mellett
> az állapotuk: **Javítva** (a javítás a kódban van, teszttel), **Nyitva** (nincs kész, kinek a dolga), **Elfogadott** (tudatos korlát).
> A formátum az `engineering:code-review` szerinti: összefoglaló, kritikus problémák, javaslatok, ami jó, ítélet. A találatokat a **hely** (fájl és függvény) és a **súlyosság** azonosítja; a sorszámok a javítások miatt elmozdulnak, ezért nincsenek megadva.
> Az éles üzem tervét a [`real-life-plan.md`](real-life-plan.md), a kód részletes leírását a [`development.md`](development.md) adja.

## 1. Összefoglaló

A kód egészében **rendezett és ellenőrzött**: egyértelmű rétegek, szerveroldali ár- és állapotkezelés, idempotens rendelésfelvétel, aláírt és időbélyeges fizetési esemény, zárt jogosultsági lista tesztelve. A saját szerveres környezet **működik és helyreállítható** (friss telepítés
2 perc alatt, katasztrófa-helyreállítás ~130 másodperc, összeomlás után nincs adatvesztés).

Az átnézés **két valódi biztonsági hiányt** talált, amelyek éles üzemben számítanának: a hamis fizetési út alapból nyitott volt, és bárki foglalhatta le az összes szállítási idősáv helyét kifizetetlen rendelésekkel. Mindkettő javítva. **Három blokkoló teendő marad az éles üzemhez**
(a belépés védelme a kitalálgatás ellen, valódi fizetés összegellenőrzéssel, e-mail), ezek nem kódhibák, hanem hiányzó, a megrendelővel egyeztetendő funkciók és beállítások.

**Őszinte megjegyzés a saját munkámról:** két hibát **én vezettem be** az átnézés közben, és a próbák fogták meg őket, mielőtt commitba kerültek volna: (1) a `fake-provider-confirm` függvény egy duplán deklarált változó miatt el sem indult (a `node --check` ezt a TypeScript-modulnál nem látja, ezért most
minden belépési pontot betöltő teszt van); (2) az új, vásárlónkénti 5 fizetetlen rendelés korlát két régi pgTAP-fájlt (050, 060) elbuktatott, amit a **friss telepítésen futtatott teljes pgTAP-sor** mutatott ki. Mindkettő javítva.

### Amit lefuttattunk, és eredménye

| Ellenőrzés | Eredmény |
|---|---|
| `dart format`, `flutter analyze` | tiszta |
| Dart egység- és widgetteszt | **273 zöld** (45 integrációs teszt kihagyva egy háttér nélküli futásnál) |
| Dart integrációs teszt a **friss saját szerveren** | **45 zöld** |
| pgTAP (friss adatbázison, mind a 12 fájl) | **187 állítás zöld** |
| HTTP-füsttesztek a saját szerveren (API, fizetés, Realtime) | mind zöld |
| Edge Function Node-tesztek | **31 zöld** |
| `shellcheck -S warning` (minden shell-szkript), `py_compile`, Caddyfile-érvényesség | tiszta |
| `tool/dev_inventory.py --check` (a `development.md` lefedettsége) | zöld |
| `verify.sh` a friss szerveren | minden `ok` (két várt `WARN`: hamis fizetés be van kapcsolva a demóban; még nincs mentés) |

### A saját szerveres környezet próbái

| Próba | Mit bizonyít | Eredmény |
|---|---|---|
| Friss telepítés `install.sh`-val | Az egész stack egy parancsból, titkok generálva, migrációk, kezdőadat | 1:56, 14 migráció |
| Újrafuttatás | A telepítő idempotens, nem cseréli a titkokat | megfelelt |
| `verify.sh` | Konténerek, kitett portok, a Caddy rejti a Studio-t, a meta API-t és a Storage-t, fejlécek, titkok, migrációk, mentés, lemez | minden `ok` |
| Terhelés | Kapacitás | ~1 600-1 800 kérés/mp, hiba nélkül (lásd `real-life-plan.md`) |
| Összeomlás (`kill -9` a Postgres folyamatain a fizetési füstteszt közben) | Nincs félig kifizetett állapot, nincs adatvesztés | megfelelt |
| Mentés és **katasztrófa-helyreállítás** (a teljes stack törlése, `restore.sh env`, `install.sh`, `restore.sh data`) | A helyreállítás a titkokkal együtt működik, az appok kulcsa érvényes marad | ~130 s |
| Helyreállítás hibás állapotban | A `data` egy tranzakció, hiba esetén az adatbázis változatlan marad | megfelelt (egy korábbi, `--clean`-es megoldás bukott, ezért lett adat-visszatöltés) |
| Belépés kitalálgatása | Van-e szerveroldali korlát | **nincs** (~100 próba/mp elfogadva): **Nyitva, kötelező** |
| Lejárati job (`pg_cron`) | A kifizetetlen rendelés lemondódik, a hely felszabadul, naplózás | megfelelt |

**Nem tesztelt** (nem volt hozzá fiók vagy eszköz): valódi Cloudflare Tunnel és domain, a Realtime WebSocket az alagúton át, iPhone Safari, valódi fizetési szolgáltató, valódi SMTP, a célhardver teljesítménye, hetes üzem.

## 2. Kritikus és magas súlyú problémák

| # | Hely | Probléma | Súlyosság | Állapot |
|---|---|---|---|---|
| 1 | `supabase/functions/payments-create`, `fake-provider-confirm` | A hamis fizetési út **alapból nyitott volt**: a kártyalépés kimenetét az app maga jelenti, így egy éles boltban bárki kifizetettnek jelölhette volna a saját rendelését | 🔴 Magas (éleshez) | **Javítva.** `FAKE_PAYMENTS_ENABLED` kapcsoló (`_shared/flags.ts`): a függvények csak akkor dolgoznak, ha értéke pontosan `true`; alapból zárt. A `verify.sh` figyelmeztet, amíg be van kapcsolva; `flags.test.ts`, `entrypoints.test.ts`, a füstteszt előzetes ellenőrzése |
| 2 | `public.place_order` (migráció `20261021130000`) | A fizetetlen rendelés **örökre lefoglalta** az idősáv helyét: bárki, akinek van fiókja (a regisztráció nyitott és a demóban azonnal megerősített), lefoglalhatta az összes sáv összes helyét, és a valódi vásárlók nem találtak volna helyet | 🔴 Magas | **Javítva.** Legfeljebb 5 fizetésre váró rendelés vásárlónként (`too_many_unpaid_orders`) és `expire_unpaid_orders()`, amely a régieket lemondja és a helyet visszaadja. **Az ütemezést a `deploy/selfhost/schedule.sh` végzi** (pg_cron, bizonyítva). pgTAP `100` |
| 3 | `deploy/selfhost` (GoTrue) | **Nincs szerveroldali korlát a jelszópróbálkozásokra**: ~100 próba/mp elfogadva. A munkatársi és vásárlói fiókok kitalálhatók | 🔴 Magas (éleshez) | **Nyitva, kötelező.** Cloudflare sebességkorlát és Access az admin hoston, Turnstile (`real-life-plan.md` 4.3). Beállítási feladat, nem kódhiba |
| 4 | `supabase/functions/payments-webhook` → `apply_payment_event` | A webhook **nem hasonlítja össze** a szolgáltató által jelentett összeget a rendelés összegével (a hamis szolgáltató eseménye nem hordoz összeget) | 🔴 Magas (valódi szolgáltatóval) | **Nyitva.** Az éles adapter feladata (`real-life-plan.md` 5. fejezet 3. pont); amíg a hamis szolgáltató van, nem érvényesül |
| 5 | `supabase/functions/fake-provider-confirm/index.ts` | A függvény **el sem indult** (`Identifier 'body' has already been declared`): a fizetés nem lett volna befejezhető. Az átnézés közben bevezetett változtatás hibája volt; a saját szerveres próba fogta meg, **commitba nem került** | 🔴 Magas | **Javítva.** A változó átnevezve; `entrypoints.test.ts` minden belépési pontot betölt egy `Deno`-helyettessel (a `node --check` ezt a TS-modulnál nem észleli) |
| 6 | `supabase/migrations/20261021130000_unpaid_orders.sql` | Az új függvény **mindenkinek végrehajtható** volt (a PostgreSQL alapból `PUBLIC`-nak ad végrehajtási jogot, a séma-szintű alapértelmezett jogok ezt nem veszik vissza) | 🟠 Közepes-magas | **Javítva.** Kifejezett `revoke`, és a `110_function_privileges.test.sql` **zárt listaként** őrzi: egy lemondás nélkül felvett új függvényen a teszt elbukik |
| 7 | pgTAP `050`, `060` (a saját változtatásom miatt) | Az 5 fizetetlen rendelés korlát és a `payment` szereplő az állapotgépben két régi tesztfájlt elbuktatott; a CI (`supabase test db`) piros lett volna | 🟠 Közepes | **Javítva** (a teszt-adat beállítása és az elvárt állapotgép igazítva); a friss telepítésen mind a 12 fájl zöld |

## 3. További találatok

| # | Hely | Probléma | Súlyosság | Állapot |
|---|---|---|---|---|
| 8 | `deploy/selfhost/Caddyfile` | A tartalombiztonsági szabály (CSP) port nélküli hoston blokkolta az API-t, ha az nem a 443-as porton ért el (helyi hálózati teszt) | 🟡 Közepes | **Javítva** (`host:*`) |
| 9 | `deploy/selfhost/Caddyfile` | Az ismeretlen hostnévre üres 200-as válasz ment (egy monitor működő oldalnak venné) | 🟢 Alacsony | **Javítva:** 404 |
| 10 | `deploy/selfhost/Caddyfile` | Az API-hoston a `/storage/v1/*` is átment, bár az app nem használja | 🟡 Közepes | **Javítva:** csak a négy használt útvonal megy át, minden más 404 |
| 11 | `deploy/selfhost/docker-compose.zaba.yml` | A Docker-naplók sosem forogtak: egy forgalmas szerver lassan megtölti a lemezt | 🟡 Közepes | **Javítva:** konténerenként 5 x 10 MB |
| 12 | `deploy/selfhost` | **Nem volt mentés és helyreállítás**, sem ellenőrző eszköz | 🔴 Magas | **Javítva:** `backup.sh` (titkosítható, visszaolvasás-ellenőrzéssel), `restore.sh` (atomikus), `verify.sh`; katasztrófa-helyreállítás kipróbálva |
| 13 | `deploy/selfhost/deploy-web.sh` | A webes build másolása közben a Caddy bind-mountja eltörhetett volna | 🟢 Alacsony | **Javítva:** `rsync --delay-updates` |
| 14 | `supabase/functions/_shared/http.ts` | A kéréstörzs korlátlan méretű lehetett | 🟡 Közepes | **Javítva:** `readTextLimited`/`readJsonBody`, 10 000 bájt; `http.test.ts` |
| 15 | `.github/workflows/*` | A harmadik féltől való Action-ök címkére voltak rögzítve (a címke átirányítható) | 🟡 Közepes (ellátási lánc) | **Javítva:** a teljes commit-azonosítóra (SHA) rögzítve, mellette az olvasható verzió |
| 16 | `deploy/demo/.wrangler/` | A `wrangler dev` helyi állapota (sqlite-fájlok) bekerült a tárolóba | 🟢 Alacsony | **Javítva:** kivéve a nyilvántartásból, `.gitignore`-ba téve (nincs bennük titok) |
| 17 | `tool/create_staff_user.py`, `create_demo_user.py` | Nem volt időkorlát; hiba esetén érthetetlen üzenet; a meglévő fiókot nem ismerte fel | 🟢 Alacsony | **Javítva:** előbb belép, érthető hibák, időkorlát |
| 18 | `deploy/selfhost` (GoTrue) | Az `sb_secret_` kulcsot az auth admin API 403-mal utasítja el: a munkatársi eszköz a régi `service_role` JWT-t kéri | 🟢 Alacsony | **Dokumentálva** (`create_staff_user.py`, `real-life-plan.md` 7.6) |
| 19 | `app/lib/features/checkout`, `payment`, `admin` | Csak `Exception`-t kaptak el: egy olvashatatlan szerverválasz (`TypeError`, ami `Error`) **örökre pörgő gombot** vagy lezárt kártyaűrlapot hagyott | 🟡 Közepes | **Javítva** (`catch (_)`, a gomb újra használható); tesztek mindhárom helyre |
| 20 | `app/lib/features/orders/presentation/order_tracking_screen.dart` | Ha a konyha közben elkezdte a rendelést, a **lemondás némán elbukott** (kezeletlen kivétel, semmilyen visszajelzés) | 🟡 Közepes | **Javítva:** üzenetsáv ("a konyha elkezdte készíteni" / "próbáld újra"); `cancel_failure_test.dart` |
| 21 | `app/lib/main.dart`, `main_admin.dart` | Ha a böngésző megtagadja a tárhelyet (letiltott webhelyadatok, egyes privát ablakok), az **app el sem indult** | 🟡 Közepes | **Javítva:** `openPreferences` → kosár és munkamenet nélkül, de működik; `preferences_test.dart`. (A Supabase-munkamenet-viselkedés tárhely nélkül: nem tesztelt böngészőben) |
| 22 | `supabase/migrations/20261021140000_inactive_categories.sql` | Egy kategória kikapcsolása után a termékei az étlapról eltűntek az appban, de a szerver tovább árazta és eladta őket | 🟡 Közepes | **Javítva:** a nézet és az árazás is csak aktív kategória termékét ismeri; pgTAP `120` |
| 23 | `app/.../product_image.dart` | A fotó nélküli termék ikonját a kategória **azonosítójából** vette (csak azért működött, mert a demóban az azonosító és az ikonkulcs egyezik) | 🟢 Alacsony | **Javítva:** a kategória `iconKey`-éből; teszt |
| 24 | `app/.../profile_screen.dart` | Név és e-mail nélküli fióknál a monogram (`characters.first`) kivételt dobott | 🟢 Alacsony | **Javítva** (`?`); teszt |
| 25 | `app/.../address_dialog.dart` | Ha a zónák nem töltődtek be (nincs hálózat), a mentés **némán nem csinált semmit** | 🟢 Alacsony | **Javítva:** hibaüzenet; teszt |
| 26 | `app/lib/core/realtime/live_query.dart` | Egy lezárás után érkező állapot-jelzés új időzítőt indíthatott, amelyet senki sem állít le | 🟢 Alacsony | **Javítva** |
| 27 | `app/lib/core/text/fold_text.dart` | Elavult megjegyzés ("a háttér ugyanezt `unaccent`-tel csinálja"): a keresés az appban van | ℹ️ Info | **Javítva** |
| 28 | `.github/workflows/ci.yml` | A `py_compile` nem fedte a `tool/fonts` és `tool/images` szkriptjeit; a Caddyfile-érvényesség a CSP új környezeti változói nélkül futott; a dokumentáció-lefedettségnek nem volt ellenőrzése | 🟢 Alacsony | **Javítva** |

## 4. Javaslatok (nyitott, nem blokkoló)

| # | Hely | Javaslat | Kategória | Ki |
|---|---|---|---|---|
| S1 | `app/.../supabase_admin_repository.dart`, `supabase_order_repository.dart` | A vásárló legutóbbi **50**, az admin legutóbbi **200** rendelését tölti be: nagy forgalomnál régi, aktív rendelés kieshet a listából. Szerveroldali szűrés (az aktív állapotokra) és lapozás kell | Méretezés | Fejlesztő |
| S2 | `public.order_status_history.actor_id` | A vásárló a saját rendelése előzményeiben látja a munkatárs felhasználó-azonosítóját (UUID; név nem, az app nem használja). Oszlopszintű jog vagy nézet megszüntetné; a Realtime miatt külön tesztelni kell | Adatvédelem | Fejlesztő |
| S3 | `app/.../auth` | Nincs fióktörlés/anonimizálás, jelszó-visszaállítás, e-mail-megerősítési képernyő (az `orders.user_id` `restrict`) | Funkció / jog | Fejlesztő, jogász |
| S4 | `app/lib/features/cart/data/shared_preferences_cart_store.dart` | A `save` nem várja meg a `setString` eredményét (a hibája kezeletlen aszinkron hiba lenne); a következő mentés rendbe hozza | Megbízhatóság | Fejlesztő |
| S5 | `app/.../admin_app_bar.dart`, `admin_gate.dart` | A kijelentkezés hibája nincs kezelve (a hálózat nélküli kijelentkezés kezeletlen kivételt adna) | Hibaág | Fejlesztő |
| S6 | `deploy/selfhost/install.sh` | A `ENABLE_EMAIL_AUTOCONFIRM=true` a demóhoz való; éleshez SMTP-vel `false` kell (`real-life-plan.md` 6. fejezet) | Konfiguráció | Üzemeltető |
| S7 | `deploy/selfhost` | A mentés ugyanazon a gépen marad, amíg a példa szerinti másolás nincs beállítva; folyamatos (WAL) archiválás nincs | Üzemeltetés | Üzemeltető |
| S8 | `app/lib/features/payment/presentation/payment_screen.dart` | A tesztkártya-súgó és a kártyaűrlap a hamis szolgáltatóé; éles szolgáltatóval a képernyő cserélődik | Funkció | Fejlesztő |
| S9 | `supabase/tests/database/010-090` | A számlálókat a kezdőadattal vetik össze, ezért **friss** adatbázist igényelnek (a `100`-`120` bármilyenen megy) | Tesztelhetőség | Fejlesztő |

## 5. Ami jó

- **Szerveroldali igazság.** Az árat, a szállítási díjat, a minimumot és az idősáv-szabadságot a szerver számolja; az app megjelenít. A pénz egész forint (`Money`, `integer`), az ÁFA-kerekítés egyetlen függvényben.
- **Az állapotgép egy táblában** (`order_status_transitions`): az app, az admin és a függvények mind ebből indulnak ki; a "fogadva" állapotba csak fizetési esemény vezet.
- **Idempotencia mindenütt**: a rendelésfelvétel kulccsal, a fizetési esemény azonosítóval; a dupla érintés és az ismételt kézbesítés ártalmatlan (tesztelve, valódi háttéren is).
- **A fizetés szerkezete éles-kész**: aláírt, időbélyeges webhook, a titok csak a függvény környezetében, az esemény csak nyitott, egyező kísérletre hat.
- **Zárt jogosultsági lista tesztelve**: minden új függvényre ki kell adni a `revoke`-ot, különben a teszt elbukik. A `service_role` jogai kifejezettek.
- **Hibakezelés a szerver hibakódjaira épül** (nem az üzenet szövegére); a felhasználó sosem lát technikai szöveget.
- **Rétegezés és cserélhetőség**: a Supabase-os és a memóriabeli megvalósítás ugyanazon interfész mögött; a tesztek a dublőrökkel hálózat nélkül futnak, ugyanaz az integrációs tesztsor pedig valódi háttéren.
- **Teszt-kultúra**: 273 + 45 Dart, 187 pgTAP, 31 Node, három HTTP-füstteszt, kis képernyős és nagy betűs végigjárás, kontraszt-teszt, a dokumentáció lefedettsége is ellenőrzött.
- **Üzemeltethetőség**: idempotens telepítő, titkosítható és ellenőrzött mentés, atomikus visszaállítás, kívülről ellenőrző `verify.sh`, naplókorlát, rögzített verziók.
- **Titokkezelés**: titok nincs a tárolóban (`gitleaks` a teljes történeten), a nyilvános kulcs az appban, a titkos csak a szerver `.env`-jében.

## 6. Ítélet

**Bemutatóra és stagingre: jóváhagyva.** Az éles üzemhez **változtatásokat kér** az átnézés, három blokkoló teendővel: (1) a belépés védelme a kitalálgatás ellen, (2) valódi fizetési szolgáltató összeg- és pénznem-ellenőrzéssel és a hamis út lezárásával, (3) e-mail (SMTP) a megerősítéshez és a jelszó-visszaállításhoz.
Mellettük a mentés másik helyre másolása, a külső figyelés, és a jogi-üzleti lista (`known-gaps.md`) szükséges; mindez a [`real-life-plan.md`](real-life-plan.md)-ben ellenőrzőlistával, becsléssel és futtatási kézikönyvvel szerepel.
