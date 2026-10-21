# Zaba fejlesztői útmutató

Ez a dokumentum **az egész kódbázist leírja**: minden fájlt, osztályt, szolgáltatót, mezőt, függvényt, adatbázis-objektumot és szkriptet, azzal a céllal, hogy aki először nyitja meg a tárolót (egy új fejlesztő, a megrendelő csapata), a
forráskód olvasása nélkül is értse, mi mit csinál és miért. Az áttekintő képet az [`architecture.md`](architecture.md), a döntések indoklását a [`decisions.md`](decisions.md), a kódellenőrzés eredményét a [`code-review.md`](code-review.md), az éles üzem tervét a [`real-life-plan.md`](real-life-plan.md) adja; ez a fájl a **részletes leltár**.

> **Ez a leírás ellenőrzött.** A `tool/dev_inventory.py --check` (a CI minden futásnál lefuttatja) kiolvassa a Dart-forrásokból az összes deklarált nevet, és megköveteli, hogy mindegyik szerepeljen a saját fájljának szakaszában. Egy új osztály, mező,
> függvény vagy fájl ezért nem kerülhet be a kódba dokumentáció nélkül, és egy törölt fájl szakasza sem maradhat itt. Az SQL, a TypeScript, a Python és a shell fájlokra a fájl-szintű lefedettséget ellenőrzi.

## 1. Áttekintés

### 1.1 Mi ez a projekt

A Zaba egy magyar ételrendelő bemutató (demó) és az abból bővítéssel készülő MVP alapja: a vásárló végigmehet a böngészéstől a kosáron, a pénztáron és a (hamis) kártyás fizetésen át a rendelés élő követéséig; közben a konyha egy külön admin oldalon
váltogatja a rendelés állapotát. Egy Flutter-projekt (telefon + web), egy Supabase-háttér (Postgres, Auth, Realtime, Edge Function), és a telepítést kiszolgáló szkriptek.

### 1.2 A fő folyamat egy ábrán

```
Vásárló (app)                          Háttér (Supabase)                        Munkatárs (admin oldal)
─────────────                          ─────────────────                        ───────────────────────
étlap letöltése ────────────────────►  catalog_products (csak aktív)
kosár (csak darabszámok) ─ quote_cart ► ár, szállítási díj, minimum (szerver számol)
cím + idősáv ─────────────────────────► get_delivery_slots
Rendelés leadása ─ place_order ───────► orders (pending_payment) + helyfoglalás az idősávban
Fizetés ─ payments-create ────────────► fizetési kísérlet + munkamenet
kártyalépés kimenete ─ fake-provider-confirm ─► aláírt esemény ─► payments-webhook
                                                  │  aláírás- és időellenőrzés, idempotencia
                                                  ▼
                                      apply_payment_event ─► orders: received      ◄── élő lista (Realtime)
élő követés (Realtime + lekérdezés) ◄─ orders / order_status_history                    admin_set_order_status
                                                                                        (szerepkör + állapotgép + napló)
```

Három szabály tartja egyben:

1. **A kliensben nincs hiteles szám.** Árat, díjat, minimumot, idősáv-szabadságot a szerver számol; az app megjelenít.
2. **Kifizetetté csak a szolgáltató aláírt eseménye tehet egy rendelést** (`apply_payment_event`). Az app a kártyalépés kimenetét közli, de sosem ír rendelést.
3. **Az állapotgép egy helyen van** (`order_status_transitions` tábla): az app, az admin oldal és a függvények mind ebből indulnak ki.

### 1.3 Környezetek

| Környezet | Hol fut | Mire való |
|---|---|---|
| `dev` | a fejlesztő gépén: `npx supabase start` + `flutter run` | napi fejlesztés, SQL- és integrációs tesztek |
| `staging` / saját szerver | otthoni vagy bérelt Linux gép: hivatalos Supabase self-host + Caddy + Cloudflare Tunnel | telefonról is megnézhető köztes állapot; az éles üzem alapja ([`real-life-plan.md`](real-life-plan.md)) |
| `demo` | Cloudflare (három Worker) + felhős Supabase (ingyenes szint) | a megrendelőnek adott link |

### 1.4 Konvenciók

- **Nyelv**: a kód, a megjegyzések és a commit-üzenetek angolul; a felhasználói szövegek és a dokumentumok magyarul.
- **Pénz**: egész forint (`Money` a Dartban, `integer`, `*_huf` az SQL-ben), bruttó; sosem lebegőpontos. Az ÁFA egyetlen helyen számolódik (`private.vat_from_gross`).
- **Idő**: az adatbázisban `timestamptz` (UTC); az app az eszköz időzónájában mutat; az idősávokat a szerver a bolt időzónájában (Europe/Budapest) rakja ki.
- **Hibák**: az SQL-függvények rövid kódot dobnak (`slot_unavailable`, `too_many_unpaid_orders` ...); az app ezeket képezi le magyar szövegre. Az app a szerver saját üzenetét sosem mutatja.
- **Rétegek az appban**: `domain` (tiszta Dart) → `data` (memóriabeli és Supabase-os megvalósítás) → `application` (Riverpod) → `presentation`. A `presentation` sosem éri el közvetlenül a Supabase-klienst.
- **Hibaág**: ahol egy képernyő hívást vár, ott a hibát (`Exception` és `Error` is) elkapja, megmondja a felhasználónak, és a gomb újra használható marad.
- **Titok**: soha nincs a tárolóban. A nyilvános kulcs (anon/publishable) az appban van, mert az adatot a sorszintű jogosultság védi; a titkos kulcs, az adatbázisjelszó, a webhook titka és a Cloudflare-token csak a szerver `.env` fájljában vagy a GitHub-titkokban él.
- **Idegen kód**: a `kinyert_funkciok/` mappa (idegen, kinyert kód) git-ben nincs, és a Zaba kódjának sosem forrása.

### 1.5 A tároló térképe

```
Zaba/
├─ README.md  package.json  .gitignore
├─ .github/workflows/      ci.yml  deploy-demo.yml  keepalive.yml                    (8. fejezet)
├─ config/                 *.example.json  (dart-define sablonok)                    (9. fejezet)
├─ deploy/
│  ├─ demo/                a felhős demó: build, APK, Cloudflare, Supabase beállítás  (7.1)
│  └─ selfhost/            a saját szerver: install, Caddy, mentés, ellenőrzés        (7.2)
├─ docs/                   átadási dokumentumok (ez is)
├─ supabase/
│  ├─ config.toml  .env.example
│  ├─ migrations/          a séma időrendben                                          (2. fejezet)
│  ├─ seed/                kezdőadat: étlap, szállítási feltételek                    (2.10)
│  ├─ functions/           Edge Function-ök (TypeScript, Deno)                        (3. fejezet)
│  └─ tests/               pgTAP és HTTP-füsttesztek                                  (2.11)
├─ tool/                   Python- és shell-eszközök                                  (6. fejezet)
└─ app/                    a Flutter-projekt                                          (4-5. fejezet)
   ├─ lib/main.dart  lib/main_admin.dart  lib/app.dart  lib/admin_app.dart
   ├─ lib/core/            közös alapok
   ├─ lib/features/        auth  catalog  cart  delivery  checkout  payment  orders  notifications  profile  admin
   ├─ lib/l10n/            szövegek
   ├─ assets/              betűk, termékfotók, logó
   ├─ web/  android/  ios/ platformok
   ├─ tool/seed_sql.dart   az étlap-kezdőadat generátora
   └─ test/                a tesztek
```

### 1.6 Tartalom

1. Áttekintés
2. Az adatbázis (`supabase/`): típusok, étlap, kiszállítás, fiókok, rendelések, árazás, függvények, jogosultságok, későbbi migrációk, kezdőadat, tesztek
3. Az Edge Function-ök (`supabase/functions/`)
4. A Flutter-app (`app/`): belépési pontok, közös alapok, belépés és fiók, kiszállítás, étlap, kosár, pénztár, rendelések, fizetés, értesítések, admin oldal, szövegek
5. A tesztek
6. Segédeszközök (`tool/`)
7. Telepítés (`deploy/`)
8. Automatizálás (`.github/workflows/`)
9. Beállítófájlok és a gyökér

## 2. Az adatbázis (`supabase/`)

A séma a `supabase/migrations/` mappában van, időrendben (a fájlnév előtagja a verzió). Mind egy tranzakcióban fut le, és a Supabase CLI és a
`deploy/selfhost/migrate.sh` ugyanabba a nyilvántartásba (`supabase_migrations.schema_migrations`) jegyzi fel, így a kettő felcserélhető.
**Alapelvek**, amelyek minden migrációra érvényesek:

- A pénz egész forint (`integer`, `*_huf` oszlop), bruttó; sosem lebegőpontos.
- Az idő `timestamptz` (UTC); helyi időt csak az idősávok kirakásakor használ a rendszer (a `delivery_settings.timezone` szerint).
- Minden rendelés- és fizetésváltoztatás **függvényen** át történik; a kliens táblába nem ír. Minden táblán RLS van, és az írási jog egyszerűen nincs megadva.
- A hibák rövid kódok az üzenetben (`out_of_delivery_area`, `slot_unavailable` ...); az app ezeket képezi le magyar szövegre.
- **Minden új függvényre ki kell adni a `revoke all ... from public, anon, authenticated` parancsot** (a PostgreSQL alapból mindenkinek adja a végrehajtást, és a séma-szintű alapértelmezett jogok ezt nem tudják visszavonni). A `110_function_privileges.test.sql` ezt őrzi.

### 2.1 Típusok és segédek: `supabase/migrations/20261021090000_types_and_helpers.sql`

| Név | Mi ez | Leírás |
|---|---|---|
| `private` (séma) | séma | Belső függvények helye. Az API nem teszi ki (`api.schemas`), így HTTP-n nem hívható. `anon`, `authenticated`, `service_role` használhatja (usage) |
| `public.order_status` | enum | A rendelés állapota: `pending_payment`, `received`, `preparing`, `out_for_delivery`, `delivered`, `cancelled` |
| `public.payment_status` | enum | A fizetés állapota: `pending`, `succeeded`, `failed`, `cancelled`, `refunded` |
| `public.admin_role` | enum | Munkatársi szerepkör: `admin` (mindent lát, az audit naplót is), `operator` (rendeléseket kezel) |
| `private.allergen_codes()` | függvény | Az EU 14 kötelező allergénje kóddal (`gluten`, `crustaceans`, `egg`, `fish`, `peanut`, `soy`, `milk`, `nuts`, `celery`, `mustard`, `sesame`, `sulphites`, `lupin`, `molluscs`). `immutable`; a CHECK kényszerek használják, hogy elírás ne kerülhessen az adatba |
| `private.vat_from_gross(p_gross, p_rate)` | függvény | A bruttó összegben foglalt ÁFA, **felfelé kerekítve .5-nél**, egész forintra. Az ÁFA-kerekítés szabályának egyetlen helye (példa: 1290 Ft 27%-on = 274 Ft) |
| `private.touch_updated_at()` | trigger-függvény | Az `updated_at` oszlopot `now()`-ra állítja módosításkor |

### 2.2 Étlap: `supabase/migrations/20261021090100_catalog.sql`

| Név | Mi ez | Leírás |
|---|---|---|
| `public.categories` | tábla | Étlap-kategóriák. `id` (szöveg, alapból UUID), `name`, `icon_key` (az app ebből választ ikont), `sort_order`, `is_active`, `created_at` |
| `public.products` | tábla | Termékek. `id`, `category_id` (FK, `restrict`), `name`, `description`, `vat_rate_percent` (0, 5, 18 vagy 27; a demóban mind 27), `allergens text[]` (CHECK: csak az `allergen_codes()` elemei), `vegetarian`, `popularity` (nagyobb = népszerűbb, ez adja az alapsorrendet), `image_path`, `is_active`, `created_at`, `updated_at` |
| `products_category_idx` | index | A kategória szerinti lekérdezéshez |
| `products_touch_updated_at` | trigger | `updated_at` karbantartása |
| `public.product_prices` | tábla | Ártörténet. `id`, `product_id` (FK, `cascade`), `amount_huf` (bruttó, >= 0), `valid_from`, `valid_to` (a jelenlegi ár sorában NULL) |
| `product_prices_one_current_idx` | egyedi index | Termékenként legfeljebb egy jelenlegi (`valid_to is null`) ár |
| `public.inventory` | tábla | Készlet. `product_id` (PK, FK), `quantity` (NULL = nincs követve, korlátlan), `updated_at`. A demó nem foglal készletet; az MVP erre építi a foglalást |
| `public.catalog_products` | nézet (`security_invoker`) | Amit az app listáz: az aktív termékek a jelenlegi áraikkal (`price_huf`). A hívó jogaival fut, ezért pontosan azt látja, amit a policy-k engednek |

### 2.3 Kiszállítás: `supabase/migrations/20261021090200_delivery.sql`

| Név | Mi ez | Leírás |
|---|---|---|
| `public.delivery_zones` | tábla | Szállítási zónák. `id`, `name`, `delivery_fee_huf`, `min_order_huf`, `free_delivery_from_huf` (NULL: soha nem ingyenes), `eta_min_minutes`, `eta_max_minutes`, `is_estimate_default` (az a zóna, amelyet a rendszer címmegadás előtti becsléshez feltételez), `sort_order` |
| `delivery_zones_one_default_idx` | egyedi index | Legfeljebb egy alapértelmezett zóna |
| `public.delivery_zone_prefixes` | tábla | Melyik háromjegyű irányítószám-előtag melyik zónához tartozik (`prefix` PK, `zone_id` FK): "1" + a kerület két számjegye, pl. `105` az V. kerület |
| `public.opening_hours` | tábla | Nyitvatartás ISO-hétköznaponként (`weekday` 1 = hétfő ... 7 = vasárnap), helyi idő (`opens_at`, `closes_at`). A sor nélküli nap zárva van |
| `public.delivery_settings` | tábla | Egyetlen sor (`id` csak `true` lehet): `timezone` (alapból `Europe/Budapest`), `lead_time_minutes` (az idősáv ennyivel a kezdete előtt már nem foglalható), `days_ahead` (hány napra előre, a mai nappal együtt), `slot_minutes`, `slot_capacity` (egy sáv hány rendelést bír) |
| `delivery_zone_prefixes_zone_idx` | index | A zóna szerinti előtag-kereséshez |
| `public.delivery_slots` | tábla | Foglalható időablakok, igény szerint hozza létre a `get_delivery_slots()`. `id`, `starts_at`, `ends_at`, `capacity`, `booked` (CHECK: nem lehet több a kapacitásnál, így a túlfoglalást az adatbázis tiltja), egyedi `(starts_at, ends_at)` |

### 2.4 Fiókok: `supabase/migrations/20261021090300_accounts.sql`

| Név | Mi ez | Leírás |
|---|---|---|
| `public.profiles` | tábla | A felhasználó profilja (`id` = `auth.users.id`, `cascade`): `full_name` (legfeljebb 200), `phone` (legfeljebb 40; az app nem használja), `avoid_allergens text[]` (az app nem használja), `created_at`, `updated_at` |
| `private.handle_new_user()` | trigger-függvény (`security definer`) | Minden új `auth.users` sorhoz profilt készít a regisztrációkor megadott névvel. A `20261021100000_signup_robustness.sql` a nevet 200 karakterre vágja, hogy egy túl hosszú név ne buktassa a regisztrációt |
| `on_auth_user_created` | trigger | Az `auth.users` beszúrása után hívja a fenti függvényt |
| `profiles_touch_updated_at` | trigger | A profil `updated_at` oszlopának karbantartása |
| `public.addresses` | tábla | Mentett címek (`user_id` FK `cascade`, `label`, `postal_code` 4 számjegy, `street`, `note`, `is_default`). **Az app nem használja**, az MVP-nek van előkészítve |
| `addresses_user_idx` | index | A felhasználó címeinek kereséséhez |
| `addresses_one_default_idx` | egyedi index | Felhasználónként legfeljebb egy alapértelmezett cím |
| `public.admin_users` | tábla | A konyha és az üzem munkatársai (`user_id` PK, `role`, `created_at`). Sort csak az `admin`/service role hoz létre (`tool/create_staff_user.py`), a felhasználó sosem |
| `public.audit_log` | tábla | Minden munkatársi művelet naplója: `id`, `actor_id` (FK, `set null`), `action`, `entity`, `entity_id`, `details jsonb`, `created_at`; az újak elöl (`audit_log_created_idx`). A lejárati futás is ide ír (`actor_id` NULL) |
| `private.admin_role()` | függvény (`security definer`, `stable`) | A bejelentkezett felhasználó szerepköre, vagy NULL ha nem munkatárs. A policy-k és az admin függvények használják; `authenticated` hívhatja |
| `private.is_staff()` | függvény (`security definer`, `stable`) | Igaz, ha a bejelentkezett felhasználó munkatárs |

### 2.5 Rendelések és fizetések: `supabase/migrations/20261021090400_orders.sql`

| Név | Mi ez | Leírás |
|---|---|---|
| `public.order_number_seq` | szekvencia | A rendelésszámok forrása, 1001-től |
| `public.orders` | tábla | A rendelés. `id`, `number` (`ZB-1001`, egyedi), `user_id` (FK **`restrict`**: a rendelésnek túl kell élnie a fiókot, a könyvelés miatt; a fiók törlése az MVP-ben anonimizálás), `status`, `payment_status` (a `payments`-ből átvéve, hogy az app join nélkül lássa), `zone_id`, `slot_id`, `delivery_postal_code`, `delivery_street`, `note` (legfeljebb 500), `subtotal_huf`, `delivery_fee_huf`, `total_huf` (számított: részösszeg + díj), `idempotency_key` (a kliens választja kísérletenként; ugyanaz a kulcs ugyanazt a rendelést adja, egyedi `(user_id, idempotency_key)`), `created_at`, `updated_at` |
| `orders_user_created_idx`, `orders_status_created_idx`, `orders_slot_idx` | indexek | A vásárló rendelései, az állapot szerinti lista és az idősáv szerinti keresés |
| `orders_touch_updated_at` | trigger | Az `updated_at` oszlop karbantartása módosításkor |
| `public.order_items` | tábla | Pillanatkép arról, mit rendeltek: `order_id` (FK `cascade`), `product_id`, `name`, `quantity` (1..99), `unit_price_huf`, `vat_rate_percent`, `line_total_huf` (számított). A későbbi árváltozás nem érinti |
| `order_items_order_idx` | index | A rendelés tételeinek kereséséhez |
| `public.order_status_history` | tábla | Minden állapotváltás: `order_id`, `from_status` (NULL az első), `to_status`, `actor` (`customer`, `operator` vagy `payment`), `actor_id`, `created_at` |
| `order_status_history_order_idx` | index | Egy rendelés előzményei időrendben |
| `public.order_status_transitions` | tábla | **Az állapotgép egyetlen helye**: melyik állapotból melyikbe, és ki léphet (`allowed_actors`). Kezdő tartalma: `pending_payment`→`received` (csak a fizetés), `pending_payment`→`cancelled` (vásárló, üzem; a `130000` migráció óta a fizetési oldal is, a lejárathoz), `received`→`preparing` (üzem), `received`→`cancelled` (vásárló, üzem), `preparing`→`out_for_delivery` (üzem), `preparing`→`cancelled` (csak üzem), `out_for_delivery`→`delivered` (üzem) |
| `public.deliveries` | tábla | A kiszállítás (`order_id` PK): `courier_name`, `dispatched_at`, `delivered_at`. Ma kézi, a felület nem mutat belőle semmit; külön táblában van, hogy az élő futárkövetés a rendelés logikájának érintése nélkül jöhessen |
| `public.payments` | tábla | Egy sor fizetési kísérletenként: `order_id`, `provider` (`fake`), `provider_reference`, `amount_huf`, `currency` (csak `HUF`), `status`, `created_at`, `updated_at` |
| `payments_order_idx` | index | Egy rendelés fizetési kísérletei, újak elöl |
| `payments_touch_updated_at` | trigger | A fizetés `updated_at` oszlopának karbantartása |
| `public.payment_events` | tábla | Amit a szolgáltató jelentett: `provider`, `provider_event_id`, `order_id` (**szándékosan FK nélkül**, hogy ismeretlen rendelésre érkező esemény is rögzíthető legyen), `event_type` (`succeeded`, `failed`, `cancelled`), `payload jsonb`, `received_at`. Az egyedi `(provider, provider_event_id)` teszi az feldolgozást idempotenssé |

### 2.6 Árazás és idősávok: `supabase/migrations/20261021090500_pricing_and_slots.sql`

| Név | Mi ez | Leírás |
|---|---|---|
| `private.compute_quote(p_lines, p_postal_code)` | függvény (`stable`, a hívó jogaival) | A kosár árazása. `p_lines`: JSON-tömb `{product_id, quantity 1..99}` elemekkel (legfeljebb 100). Postai irányítószám nélkül az alapértelmezett zónát veszi, és `estimated: true`-t ad. Az ismeretlen és inaktív termékeket kihagyja; ugyanaz a termék kétszer egy sor (az összeg nem lehet 99-nél több). Visszaad: `lines`, `subtotal_huf`, `delivery_fee_huf`, `total_huf`, `min_order_huf`, `free_delivery_from_huf`, `zone_id`, `estimated`. Hibák: `invalid_lines`, `out_of_delivery_area`, `delivery_not_configured` |
| `public.quote_cart(p_lines, p_postal_code)` | függvény | Az API-n hívható burkoló a fentihez; vendég is hívhatja |
| `private.generate_delivery_slots(p_now)` | függvény (`security definer`) | Létrehozza a foglalási ablak hiányzó sáv-sorait (a bolt időzónájában, így a nyári időszámítás UTC-ben is helyes), és visszaadja a foglalhatókat: a jelenlegi nyitvatartáson belül, a `lead_time_minutes`-nél nem közelebb, az ablakon belül, nem teltek. A `p_now` paraméter, hogy rögzített időpontban tesztelhető legyen |
| `public.get_delivery_slots()` | függvény (`security definer`) | A fentit hívja `now()`-val, `slot_id`, `starts_at`, `ends_at`, `remaining` oszlopokkal; csak bejelentkezett felhasználó hívhatja |

### 2.7 Rendelés- és fizetésfüggvények: `supabase/migrations/20261021090600_order_functions.sql`

| Név | Mi ez | Leírás |
|---|---|---|
| `private.require_user()` | függvény | A bejelentkezett felhasználó azonosítója, vagy `not_authenticated` hiba |
| `private.transition_order(p_order_id, p_to, p_actor, p_actor_id, p_payment_status)` | függvény (`security definer`) | **Az egyetlen hely, ahol a rendelés állapota változik.** Zárolja a sort, ellenőrzi az állapotgépet (`invalid_transition`), a rendelést **egyetlen** `update`-tel írja (állapot és fizetési állapot együtt, így az élő követő sosem lát félkész állapotot), naplóz, `out_for_delivery`-nél/`delivered`-nél vezeti a `deliveries`-t, lemondáskor visszaadja a helyet az idősávban, és a kifizetett rendelést `refunded`-re állítja |
| `public.place_order(p_idempotency_key, p_lines, p_postal_code, p_street, p_slot_id, p_note)` | függvény (`security definer`) | A bejelentkezett vásárló rendelést ad le: ellenőrzi a kérést (`invalid_request`), azonos kulcsra ugyanazt a rendelést adja (`replayed`), korlátozza a kifizetetlen rendeléseket (`too_many_unpaid_orders`, a `130000` migráció óta), **újraárazza a kosarat a szerveren**, ellenőrzi a területet, a minimális értéket (`below_minimum_order`) és az idősávot (`slot_unavailable`, zárolva, lefoglalja a helyet), majd létrehozza a rendelést, a tételeit és az első előzményt. A kettős koppintást tanácsadó zárral (advisory lock) kezeli |
| `public.cancel_order(p_order_id)` | függvény (`security definer`) | A vásárló lemondja a saját rendelését, amíg az állapotgép engedi. "Nem a tiéd" és "nincs ilyen" ugyanazt a választ adja (`order_not_found`) |
| `public.start_payment(p_order_id)` | függvény (`security definer`) | A fizetendő kísérletet adja vissza: a nyitottat, vagy újat egy sikertelen/elhagyott után. Csak a saját, fizetésre váró rendelésre (`order_not_found`, `order_not_payable`) |
| `public.apply_payment_event(p_provider, p_event_id, p_order_id, p_type, p_payload)` | függvény (`security definer`) | **Az egyetlen dolog, ami a rendelést kifizetetté teheti.** A webhook hívja (csak `service_role`). Az eseményt azonosító szerint egyszer rögzíti (idempotens: `duplicate`), csak fizetésre váró rendelésre hat (`order_not_pending`), és csak olyan fizetési kísérletre, amely még nyitott és egyezik a `payload.payment_id`-vel (`no_matching_payment`, a `110100` migráció javítása) |
| `public.admin_set_order_status(p_order_id, p_status)` | függvény (`security definer`) | Egy munkatárs (bármely szerepkör) léptet az állapotgépen (`forbidden`, ha nem munkatárs), és naplózza az `audit_log`-ba |

### 2.8 Jogosultságok és élő frissítés: `supabase/migrations/20261021090700_security_and_realtime.sql`

Ami nincs kifejezetten megadva, az nem elérhető. A fájl: (1) a `public` és `private` sémában a meglévő táblákról, szekvenciákról és függvényekről **visszavonja** az `anon`/`authenticated`/`public` jogait, és az alapértelmezett jogokat is szűkíti; (2) **minden táblán bekapcsolja az RLS-t**; (3) policy-kat és oszlop-szintű jogokat ad:

| Policy / jog | Kinek | Mit enged |
|---|---|---|
| `categories_read`, `products_read` (`is_active`), `product_prices_read` (`valid_to is null`) | `anon`, `authenticated` | az aktív étlap olvasása |
| `delivery_zones_read`, `delivery_zone_prefixes_read`, `opening_hours_read`, `delivery_settings_read` | `anon`, `authenticated` | a szállítási feltételek olvasása |
| `order_status_transitions_read` | `authenticated` | az állapotgép olvasása |
| `profiles_select_own`, `profiles_update_own` + `grant update (full_name, phone, avoid_allergens)` | `authenticated` | a saját profil olvasása, és **csak** ezen három oszlop módosítása |
| `addresses_own` (`for all`) | `authenticated` | a saját címek teljes kezelése; a `user_id` alapértéke `auth.uid()` |
| `orders_read` | `authenticated` | a saját rendelés, vagy munkatársként mindegyik |
| `order_items_read`, `order_status_history_read`, `deliveries_read`, `payments_read` | `authenticated` | akié a rendelés, azé (a feltétel a rendelés policy-jét használja) |
| `admin_users_read_own` | `authenticated` | annak kiderítése, hogy az ember munkatárs-e |
| `audit_log_read` | `authenticated` | csak az `admin` szerepkör |
| nincs policy (`inventory`, `delivery_slots`, `payment_events`) | senki az API-n | csak függvények és a service role érik el |
| függvény-jogok | | `quote_cart`: vendég és vásárló; `get_delivery_slots`, `place_order`, `cancel_order`, `start_payment`, `admin_set_order_status`: bejelentkezett; `apply_payment_event`: csak `service_role` |

Élő frissítés: az `orders` és az `order_status_history` bekerül a `supabase_realtime` publikációba. A Realtime a fenti policy-kat is érvényesíti, így mindenki csak azt kapja, amit olvashat.

### 2.9 Későbbi migrációk

| Fájl | Mit csinál |
|---|---|
| `supabase/migrations/20261021100000_signup_robustness.sql` | `private.handle_new_user()` újradefiniálása: a nevet 200 karakterre vágja, hogy a túl hosszú név ne buktassa a regisztrációt |
| `supabase/migrations/20261021110000_order_slot_visible.sql` | `delivery_slots_read_ordered` policy és `grant select (id, starts_at, ends_at)`: a vásárló látja a saját rendelései idősávjának idejét (a kapacitását nem) |
| `supabase/migrations/20261021110100_payment_event_matching.sql` | `apply_payment_event` javítása: az esemény csak nyitott, egyező fizetési kísérletre hat (korábban egy elutasítás utáni elavult "sikeres" esemény kifizetettnek jelölhette a rendelést) |
| `supabase/migrations/20261021120000_service_role_grants.sql` | `grant ... on public.admin_users to service_role`: a Supabase új projektekben már nem ad automatikus jogot, így a munkatársi eszköz működéséhez kifejezett jog kell |
| `supabase/migrations/20261021130000_unpaid_orders.sql` | A kifizetetlen rendelések korlátja (legfeljebb 5 / vásárló, `too_many_unpaid_orders`) és lejárata: `public.expire_unpaid_orders(p_older_than interval default '30 minutes')` (csak `service_role`; legalább 5 percet kér; a fizetésre váró, régebbi rendeléseket lemondja `payment` szereplővel, lezárja a nyitott fizetési kísérleteket, és naplóz). A `place_order` újradefiniálva a korláttal. A `pending_payment`→`cancelled` átmenetet a `payment` szereplő is használhatja |
| `supabase/migrations/20261021140000_inactive_categories.sql` | Az inaktív kategória termékei nincsenek az étlapon és nem rendelhetők: a `catalog_products` nézet csak olyan terméket listáz, amelynek a kategóriája is aktív, a `private.compute_quote` pedig kihagyja az ilyen termék sorát (a kategória újraaktiválása visszahozza a termékeit; semmi nem másolódik és nem kapcsolódik ki). Korábban a kategória eltűnt, a termékei viszont maradtak, és rendelhetők voltak |

### 2.10 Kiinduló adatok: `supabase/seed/`

| Fájl | Leírás |
|---|---|
| `supabase/seed/10_catalog.sql` | A demó étlap: 7 kategória, 45 termék és az áraik. **Generált**: az `app/tool/seed_sql.dart` állítja elő az `app/lib/features/catalog/data/demo_catalog.dart`-ból (egy forrás, így a memóriabeli demó és az adatbázis ugyanazt az étlapot mutatja). Ne szerkeszd kézzel |
| `supabase/seed/20_delivery.sql` | Szállítási feltételek: egy `delivery_settings` sor (Budapest, 45 perc előfutás, 3 nap, 60 perces sáv, 10 rendelés/sáv), nyitvatartás (hétfő-szombat 11-21, vasárnap 11-20), a két zóna (`inner`: 990 Ft díj, 3 500 Ft minimum, 15 000 Ft felett ingyenes, 35-50 perc; `outer`: 1 490 Ft, 5 000 Ft, 45-60 perc) és az irányítószám-előtagjaik (belső: I, II, V-IX, XI-XIII; külső: III, IV, X, XIV-XVI) |

### 2.11 Tesztek az adatbázishoz: `supabase/tests/`

| Fájl | Mit ellenőriz |
|---|---|
| `supabase/tests/database/010_security.test.sql` | Hogy melyik szerep mit tehet és mit nem: olvasás, írás, RLS, a jogok zártsága (20 állítás) |
| `supabase/tests/database/020_pricing.test.sql` | Az ÁFA-kerekítés, a kosár árazása, a szállítási díjak és a bemenet ellenőrzése (27 állítás) |
| `supabase/tests/database/030_slots.test.sql` | Az idősávok: nyitvatartás, előfutás, kapacitás, a nyári időszámítás váltása (13 állítás) |
| `supabase/tests/database/040_orders.test.sql` | Rendelés leadása és lemondása vásárlóként, idempotencia, a hibakódok |
| `supabase/tests/database/050_payments_and_admin.test.sql` | A fizetési események, az állapotgép egy munkatárs szemével, a visszatérítés és az audit napló |
| `supabase/tests/database/060_seed_and_state_machine.test.sql` | A kiinduló adatok és az állapotgép táblája (13 állítás) |
| `supabase/tests/database/070_signup.test.sql` | Amit egy új fiók kap: profil, bármit is küldött az app névként (5 állítás) |
| `supabase/tests/database/080_payment_matching_and_slot_visibility.test.sql` | Az esemény-illesztés a nyitott kísérlethez, és az idősáv láthatósága |
| `supabase/tests/database/090_service_role_grants.test.sql` | A service role-ra támaszkodó jogok kifejezettek, és senki más nem kapta meg őket (7 állítás) |
| `supabase/tests/database/100_unpaid_orders.test.sql` | A kifizetetlen rendelések korlátja és lejárata (adatbázis-állapottól független) |
| `supabase/tests/database/110_function_privileges.test.sql` | Hogy melyik szerep mely függvényeket hívhatja, **zárt listaként**: egy lemondás nélkül felvett új függvényen elbukik |
| `supabase/tests/database/120_inactive_categories.test.sql` | Hogy az inaktív kategória termékei kikerülnek az étlapról és az árazásból, a kategória visszakapcsolásával pedig visszajönnek (saját kategóriát és terméket készít, így bármilyen adatbázison megy) |
| `supabase/tests/api_smoke.py` | HTTP-ellenőrzések a futó stack ellen: étlap, árazás, regisztráció, rendelés, a jogosultságok |
| `supabase/tests/payment_smoke.py` | A teljes fizetési út valódi Edge Function-ökkel: siker, elutasítás, megszakítás, ismétlés (idempotencia), hamis és elavult események |
| `supabase/tests/realtime_smoke.py` | Hogy a vásárló az élő csatornán megkapja a kifizetett rendelést, egy konzisztens frissítésben |

A három füsttesztnek közös a felépítése (`failures` gyűjtő, `check`, `load_config`, `call`, `rpc`); mindhárom `--from-local` kapcsolóval a helyi stackből olvassa az URL-t és a kulcsokat, **kulcsot sosem ír ki**, és felhasználót és rendelést hoz létre, ezért éles projekt ellen nem futtatható.

| Fájl | Segédfüggvényei |
|---|---|
| `supabase/tests/api_smoke.py` | `check(name, condition, detail)` (egy ellenőrzés eredménye és a hibák gyűjtése), `load_config()` (a helyi stack vagy a környezeti változók), `call(method, path, key, token, body)` (HTTP-kérés a REST-végpontra), `rpc(name, key, token, **args)` (függvényhívás) |
| `supabase/tests/payment_smoke.py` | ugyanazok, kiegészítve: `sign_up()` (új vásárló), `place_order(token, slot)` (rendelés leadása), `create_payment(token, order_id)` (a `payments-create` hívása), `confirm(token, session_token, outcome)` (a `fake-provider-confirm` hívása), `order_state(token, order_id)` (a rendelés és a fizetés állapota), `signed_event(order_id, payment_id, kind, event_id, at)` (a szolgáltató aláírt eseménye, hibás esetekhez eltérő aláírással vagy idővel), `deliver(body, header, token, key)` (az esemény kézbesítése a webhooknak) |
| `supabase/tests/realtime_smoke.py` | `load_config()`, `call(...)`, `rpc(...)`, és az aszinkron WebSocket-rész: feliratkozás az `orders` változásaira, majd egy fizetési esemény után az élő frissítés kivárása |

(Az adatbázis-tesztek nagy része számlálókat vet össze a magozott adatokkal, ezért a `010`-`090` fájlokat **frissen magozott adatbázison** kell futtatni; a `100`, a `110` és a `120` bármilyenen megy.)

## 3. Az Edge Function-ök (`supabase/functions/`)

Három TypeScript-függvény (Deno futtatókörnyezet) viszi a fizetést. A közös kód a `_shared/` mappában van, **távoli import nélkül**, hogy a függvények hálózat nélkül is induljanak,
és ugyanúgy viselkedjenek helyben, a saját szerveren és a felhőben. A tisztán számoló részek Node alatt is futnak (`npm run test:functions`).
A függvények környezeti változóit az [`env-vars.md`](env-vars.md) sorolja fel.

A fizetés menete: `payments-create` (fizetési munkamenet) → a kártyalépés az appban → `fake-provider-confirm` (a szimulált szolgáltató háttere: aláírt eseményt küld) → `payments-webhook`
(aláírás-ellenőrzés, majd `apply_payment_event`). A sorozatdiagram a [`payment-flow.md`](payment-flow.md)-ben van.

#### supabase/functions/_shared/http.ts

A függvények közös kis segédei.

| Név | Mi ez | Leírás |
|---|---|---|
| `corsHeaders` | érték | A válaszok CORS-fejlécei: bármely eredet, `POST` és `OPTIONS`. Megengedhető, mert az app tokent küld, nem sütit |
| `json(body, status)` | függvény | JSON-választ ad a CORS-fejlécekkel |
| `preflight()` | függvény | A böngésző `OPTIONS` előzetes kérésére 204-gyel válaszol |
| `readEnv(functionName, names)` | függvény | Beolvassa a megadott környezeti változókat; ha egy hiányzik, naplózza a **nevét** (sosem az értékét), és `null`-t ad. A titok nélküli függvény megtagadja a munkát, nem esik vissza alapértékre |
| `apiKey(functionName, which)` | függvény | A projekt publikus (`publishable`) vagy titkos (`secret`) kulcsa: előbb a platform új, szótár-alakú változójából, különben a régi változóból; `null`, ha egyik sincs |
| `restHeaders(key, extra)` | függvény | A PostgREST-hívás fejlécei: `apikey`, és ha a kulcs JWT (`eyJ...`), `Authorization` is (az új `sb_` kulcs **nem** mehet oda) |
| `MAX_BODY_BYTES` | érték | A legnagyobb beolvasott kéréstörzs: 10 000 bájt (a törzsek pár száz bájtosak) |
| `readTextLimited(req, maxBytes)` | függvény | A törzs szövege, vagy `null`, ha nagyobb a korlátnál. Előbb a deklarált méretet nézi, aztán darabonként olvas, és abbahagyja, amint túllépi: a hatalmas vagy hazudó törzs sosem kerül egészben a memóriába |
| `readJsonBody(req, maxBytes)` | függvény | A törzs JSON-objektumként, vagy `null` (túl nagy, nem JSON, nem objektum) |
| `UUID` | érték | Reguláris kifejezés a kisbetűs, kötőjeles UUID-kra |

#### supabase/functions/_shared/keys.ts

| Név | Mi ez | Leírás |
|---|---|---|
| `keyFromDictionary(json, name)` | függvény | A platform JSON-szótárából (`{"default": "sb_..."}`) a megnevezett (alapból `default`) kulcs; üres vagy hibás esetben `undefined` |
| `pickKey(dictionaryJson, legacy)` | függvény | Az új kulcs, ha van, különben a régi (a Supabase 2026 végéig kivezeti a régit); az üres sztring sosem kulcs |

#### supabase/functions/_shared/flags.ts

| Név | Mi ez | Leírás |
|---|---|---|
| `fakePaymentsEnabled(value)` | függvény | A demó hamis fizetési folyamata csak akkor fut, ha a `FAKE_PAYMENTS_ENABLED` értéke pontosan `true`. A hamis kártyalépés az appnak engedi bejelenteni, hogy a kártyát elfogadták: demóhoz való, valódi boltban bárki kifizetettnek jelölhetné a saját rendelését. Ezért alapból zárva van |

#### supabase/functions/_shared/payments/signing.ts

HMAC-SHA256 aláírás a webhookokhoz, csak a Web Crypto API-ra írva, így ugyanaz a fájl fut a Deno-ban és a Node tesztekben.

| Név | Mi ez | Leírás |
|---|---|---|
| `encoder` | érték | Szövegből bájtokat csináló `TextEncoder` |
| `toHex(bytes)` | függvény | Bájtokból kisbetűs hexa szöveg |
| `hmacSha256Hex(secret, message)` | függvény | Az üzenet HMAC-SHA256 aláírása hexában; üres titokra hibát dob (nem ír alá semmivel) |
| `timingSafeEqual(a, b)` | függvény | Két szöveg összehasonlítása úgy, hogy nem áll meg az első eltérésnél (időzítési támadás ellen) |
| `signPayload(secret, body, timestampSec)` | függvény | Az aláírás-fejléc értéke: `t=<unix mp>,v1=<hexa>`; az aláírás a `<t>.<törzs>`-re vonatkozik, így az időbélyeg nem cserélhető ki egy régi esemény újként visszajátszásához |
| `SignatureCheck` | típus | Az ellenőrzés eredménye: `ok`, vagy a hiba oka (`missing`, `malformed`, `expired`, `mismatch`) |
| `checkSignature(secret, body, header, nowSec, toleranceSec)` | függvény | Ellenőrzi a fejlécet a törzzsel szemben. Az 5 percnél (alapból) régebbi vagy újabb eseményt elutasítja; több `v1` értéket is elfogad (kulcsforgatás), és mindet összeveti, hogy az idő ne árulja el, melyik egyezett |

#### supabase/functions/_shared/payments/provider.ts

A határ a Zaba és a fizetési szolgáltató között. A rendelés logikája csak olyan `ProviderEvent`-et lát, amelyet a `verifyWebhook` hitelesített, így a hamis szolgáltatót valódira (Barion, Stripe, SimplePay) cserélni egy új osztály megírása.

| Név | Mi ez | Leírás |
|---|---|---|
| `PaymentOutcome` | típus | A fizetés kimenete az adatbázis szavaival: `succeeded`, `failed`, `cancelled` |
| `ProviderEvent` | típus | Amit a szolgáltató jelent, **csak hitelesített webhookból** építve: `id` (esemény-azonosító, egyedi), `outcome`, `orderId`, `paymentId` |
| `PaymentSession` | típus | `token` (amit az app a szolgáltató fizetési oldalának ad) és `expiresAt` |
| `WebhookVerificationError` | osztály | A webhook elutasítását jelző hiba; a `reason` mező az okot hordozza (csak naplóba megy, nem a válaszba) |
| `PaymentProvider` | interfész | `name`; `createSession(...)` fizetési munkamenetet nyit egy kísérletre; `verifyWebhook(rawBody, signatureHeader)` hitelesíti a kérést (aláírás, frissesség) és visszaadja az eseményt, minden mást `WebhookVerificationError`-ral utasít el |

#### supabase/functions/_shared/payments/fake_provider.ts

A demó fizetési szolgáltatója. Mindkét oldalt játssza: fizetési munkamenetet ad ki, és (`signEvent`) aláírja azokat az eseményeket, amelyeket a valódi szolgáltató háttere küldene. A webhook-oldal (`verifyWebhook`) a valódi: aláírás, frissesség, szigorú értelmezés.

| Név | Mi ez | Leírás |
|---|---|---|
| `SESSION_TTL_SEC` | érték | A fizetési munkamenet élettartama: 30 perc |
| `UUID` | érték | UUID-minta az eseményben kapott azonosítók ellenőrzéséhez |
| `EVENT_TYPES` | érték | `Map`: a szolgáltatói eseménytípusból (`payment.succeeded` ...) a kimenet. **`Map`, nem objektum**: az objektumban a `constructor` vagy a `toString` is "találat" lenne |
| `InvalidSessionError` | osztály | A fizetési munkamenet-token elutasítása (`malformed`, `signature`, `expired`) |
| `SessionDetails` | típus | A munkamenetből kiolvasott adatok: `paymentId`, `orderId`, `amountHuf`, `expiresAt` |
| `base64UrlEncode(text)`, `base64UrlDecode(text)` | függvények | URL-barát Base64 a token adatrészéhez |
| `randomHex(bytes)` | függvény | Kriptográfiailag véletlen hexa szöveg (nonce, esemény-azonosító) |
| `FakePaymentProvider` | osztály | A `PaymentProvider` szimulált megvalósítása. `name` = `fake`; a konstruktor üres titokra hibát dob; privát `#secret` és `#now` (az idő, tesztben cserélhető) |
| `FakePaymentProvider.createSession` | metódus | Aláírt tokent ad: `base64url(JSON)` + `.` + HMAC (`session:` előtaggal, így nem téveszthető össze a webhook aláírásával); a JSON a fizetést, a rendelést, az összeget, a lejáratot és egy véletlen nonce-t tartalmaz |
| `FakePaymentProvider.readSession` | metódus | Ellenőrzi a tokent (alak, aláírás, lejárat), és visszaadja a részleteit; `InvalidSessionError` egyébként |
| `FakePaymentProvider.signEvent` | metódus | A szolgáltató háttere nevében aláírt webhook-kérést készít egy kimenetre (`evt_...` azonosítóval, `payment.<kimenet>` típussal) |
| `FakePaymentProvider.verifyWebhook` | metódus | A valódi hitelesítés: aláírás és frissesség, majd az esemény szigorú értelmezése (azonosító, ismert típus, UUID-k); bármi más `WebhookVerificationError` |

#### supabase/functions/payments-create/index.ts

A bejelentkezett vásárló rendeléséhez fizetést indít, és fizetési munkamenetet nyit. A valódi ellenőrzéseket az adatbázis-függvény végzi (bejelentkezett, a saját rendelése, még fizetésre vár); ez a függvény csak továbbadja a vásárló személyazonosságát, és hozzáadja a szolgáltatói munkamenetet.
Kapcsoló nélkül (`FAKE_PAYMENTS_ENABLED`) 503-at ad. Hibakódok: `not_authenticated` (401), `invalid_request` (400), `order_not_found` (404), `order_not_payable` (409), `payment_start_failed` (502), `not_configured` (500).
Fájlon belüli nevek: `Deno.serve` kezelő (a belépési pont), `env`, `publishableKey`, `authorization`, `orderId`, `response`, `payment`, `provider`, `session` (helyi értékek).

#### supabase/functions/fake-provider-confirm/index.ts

A **hamis** szolgáltató háttere. Élesben nem létezik: a valódi szolgáltató a saját oldalán veszi fel a kártyát, és a háttere hívja a webhookot. Itt az app jelenti a hamis kártyalépés kimenetét, ez a függvény pedig a szolgáltató hátterét játssza: ellenőrzi a kiadott munkamenetet, aláírt eseményt készít, és HTTP-n kézbesíti a webhooknak, így innentől minden a valódi út.
Nincs platform-hitelesítés (a szolgáltatónak nincs Supabase tokenje; az aláírás a hitelesítő). Kapcsoló nélkül 503. Hibakódok: `invalid_request` (400), `invalid_session` (400), `webhook_failed` (502).

| Név | Mi ez | Leírás |
|---|---|---|
| `OUTCOMES` | érték | `Map`: az app kimenetéből (`approved`, `declined`, `cancelled`) az adatbázis kimenete (`succeeded`, `failed`, `cancelled`) |

#### supabase/functions/payments-webhook/index.ts

A szolgáltató eseményeit fogadja. **Az egyetlen út, amelyen egy rendelés kifizetetté válik.** Először az aláírást ellenőrzi, és csak az igazolt esemény jut el az `apply_payment_event`-hez (amelyet csak ennek a függvénynek a titkos kulcsa hívhat). Idempotens: az adatbázis minden eseményt egyszer rögzít.
A törzs legfeljebb 10 000 bájt (`413`); az elutasítás oka csak a naplóba kerül (`400 invalid_webhook`), hogy ne segítsen hamisítani; az adatbázis-hiba `500`, hogy a valódi szolgáltató később újrakézbesítse.

#### Tesztek: `supabase/functions/_shared/`

| Fájl | Mit ellenőriz |
|---|---|
| `supabase/functions/_shared/keys.test.ts` | Az új kulcs előnye a régivel szemben, a régi használata, a kulcs nélküli eset |
| `supabase/functions/_shared/flags.test.ts` | A kapcsoló csak a pontos `true`-ra nyit |
| `supabase/functions/_shared/http.test.ts` | A törzsolvasók: kis törzs, üres törzs, a korlát (a deklarált méretre és a nem deklaráltra is), a korlát inkluzív volta, a JSON-objektum követelménye |
| `supabase/functions/_shared/payments/payments.test.ts` | Az aláírás (RFC 4231 tesztvektor, a módosított törzs és a rossz titok elutasítása, az időablak, a kulcsforgatás), a munkamenet, a webhook-hitelesítés, az események azonossága, a `constructor`/`toString` típusok elutasítása |
| `supabase/functions/_shared/entrypoints.test.ts` | Mindhárom függvény betöltése `Deno` csonkkal (szintaxis, importok), és a kérés-kezelők hívása valódi `Request`-ekkel: a kapcsoló, a hitelesítés, a hibás és a túl nagy törzsek, a hiányzó titok |

## 4. A Flutter-app (`app/`)

Egy Flutter-projekt, két build: a vásárlói app (`lib/main.dart`, mobil + web) és az admin oldal (`lib/main_admin.dart`, csak web). A kód **funkciók szerint** van tagolva
(`lib/features/<funkció>/`), és minden funkción belül ugyanaz a rétegzés:

- `domain/`: tiszta Dart. Modellek és a **repository-interfészek** (`abstract interface class`). Flutter- vagy Supabase-típus nem kerül ide.
- `data/`: az interfészek megvalósításai: egy **memóriabeli** (a demóadatból, tesztekhez és szerver nélküli futtatáshoz) és egy **Supabase**-alapú.
- `application/`: Riverpod-szolgáltatók (`Provider`, `FutureProvider`, `Notifier`), amelyek a képernyők és a repository-k közé állnak.
- `presentation/`: képernyők és widgetek. Csak a szolgáltatókat használják, sosem a Supabase-klienst.

A cserét a `main.dart` végzi: ha a build kapott `SUPABASE_URL`-t és `SUPABASE_ANON_KEY`-t, a szolgáltatókat felülírja a Supabase-os megvalósításokkal; ha nem, az app a memóriabeli
adatokkal teljesen önállóan fut. A tesztek ugyanezt a módszert használják (felülírt szolgáltatók, lásd a 5. fejezetet).

A felületi szövegek magyarul az `lib/l10n/app_hu.arb` fájlban vannak; a `flutter gen-l10n` ebből készíti az `lib/l10n/generated/` mappát (ez git-ben van, hogy a build ne függjön a generálástól).
Kifejezetten nem lokalizált: a fejlesztői galéria (`design_gallery_screen.dart`) és az admin `_MissingBackend` üzenete.

### 4.1 Belépési pontok

#### app/lib/main.dart

A vásárlói app indítása.

| Név | Mi ez | Leírás |
|---|---|---|
| `main()` | függvény | Megnyitja az eszköz tárhelyét (`openPreferences`), és ha elérhető, a kosarat abba menti (`SharedPreferencesCartStore`). Ha a build kapott Supabase-adatot (`AppConfig.hasBackend`), elindítja a klienst (`initSupabase`, a munkamenet csak működő tárhelyen marad meg), és a memóriabeli megvalósításokat a Supabase-osakkal helyettesíti (auth, étlap, árazás, zónák, idősávok, rendelések, fizetés). A `kitchenSimulationProvider`-t kikapcsolja: a konyhát az admin oldal játssza. Végül elindítja a `ZabaApp`-ot egy `ProviderScope`-ban |

#### app/lib/main_admin.dart

Az admin oldal indítása (`flutter build web -t lib/main_admin.dart`). Külön build, így a vásárlói appba nem kerül admin-kód.

| Név | Mi ez | Leírás |
|---|---|---|
| `main()` | függvény | Backend nélkül a `_MissingBackend` üzenetet mutatja (két külön app nem oszthat memóriabeli rendeléseket). Egyébként elindítja a klienst, felülírja az auth- és admin-repository-t, és elindítja az `AdminApp`-ot |
| `_MissingBackend` | `StatelessWidget` | Egy üzenet arról, hogy a kezelőfelülethez Supabase kell (`SUPABASE_URL`, `SUPABASE_ANON_KEY`). Szándékosan nem lokalizált |

#### app/lib/app.dart

| Név | Mi ez | Leírás |
|---|---|---|
| `ZabaApp` | `ConsumerWidget` | A vásárlói app gyökere: `MaterialApp.router` a `routerProvider`-rel, a világos témával, magyar nyelvvel. Két szolgáltatót figyel, hogy éljenek: a `cartPruningProvider`-t (a kosár megtisztítása az étlaphoz) és az `orderNotificationsProvider`-t (értesítések a rendelések változásaiból). Az `AppFrame` tetejére teszi az értesítéssávot (`NotificationBanner`) |

#### app/lib/admin_app.dart

| Név | Mi ez | Leírás |
|---|---|---|
| `AdminApp` | `ConsumerWidget` | Az admin oldal gyökere: ugyanaz a téma és nyelv, az `adminRouterProvider` útvonalaival |

### 4.2 Közös alapok (`lib/core/`)

#### app/lib/core/config/app_config.dart

Fordítási idejű beállítások (`--dart-define-from-file=config/<env>.json`). **Csak nyilvános érték kerülhet ide**, mert ami itt van, az benne van a webes buildben és az APK-ban.

| Név | Mi ez | Leírás |
|---|---|---|
| `AppConfig` | `abstract final class` | Csak statikus értékek, nem példányosítható |
| `AppConfig.env` | konstans | `APP_ENV`: `dev`, `staging` vagy `demo` (alapból `dev`) |
| `AppConfig.showDevTools` | konstans | `env != 'demo'`: a demó buildben nincs fejlesztői galéria |
| `AppConfig.supabaseUrl` | konstans | `SUPABASE_URL`, a projekt címe |
| `AppConfig.supabaseAnonKey` | konstans | `SUPABASE_ANON_KEY`, a nyilvános kulcs (`sb_publishable_...`, vagy a régi anon JWT; a saját szerver Realtime-ja a JWT-t kéri). Nem titok: az adatot a sorszintű jogosultság védi |
| `AppConfig.hasBackend` | konstans | Mindkét érték meg van adva. Nélküle az app memóriabeli adatokkal fut |
| `AppConfig.demoEmail`, `AppConfig.demoPassword` | konstansok | A "belépés demó fiókkal" gomb fiókja. Eldobható fiók kitalált adatokkal, nem titok; ha nincs megadva, a gomb rejtve van |
| `AppConfig.adminDemoEmail`, `AppConfig.adminDemoPassword` | konstansok | Az admin oldal "belépés demó munkatársként" gombjának fiókja. Vásárlók által elérhető buildben **üresen marad**: a jelszó egy nyilvános weboldalon ülne |

#### app/lib/core/clock/clock.dart

| Név | Mi ez | Leírás |
|---|---|---|
| `Clock` | típusnév | `DateTime Function()`: az aktuális idő forrása |
| `clockProvider` | szolgáltató | Alapból `DateTime.now`; a tesztek rögzítik, hogy az idősávok, értesítések és időbélyegek determinisztikusak legyenek |

#### app/lib/core/storage/preferences.dart

| Név | Mi ez | Leírás |
|---|---|---|
| `openPreferences()` | függvény | Az eszköz kulcs-érték tárhelye (`SharedPreferences`), vagy `null`, ha a böngésző megtagadja (letiltott webhelyadatok, egyes privát ablakok). Ilyenkor az app működik, csak a kosár és a munkamenet nem éli túl az újratöltést |

#### app/lib/core/supabase/supabase_bootstrap.dart

| Név | Mi ez | Leírás |
|---|---|---|
| `initSupabase({persistSession})` | függvény | Elindítja a `Supabase` klienst a build beállításaiból, és visszaadja. Az URL-töredékből nem olvas munkamenetet (`detectSessionInUri: false`: az app nem használ e-mail linket, a böngészőben pedig a töredék az útválasztóé). `persistSession: false` esetén a munkamenet csak az oldal újratöltéséig él |

#### app/lib/core/money/money.dart

| Név | Mi ez | Leírás |
|---|---|---|
| `Money` | `extension type` (`int forint`) | Egész forintban megadott összeg, nulla futásidejű többletköltséggel. **Pénz sosem `double`**: a forintnak nincs használható váltópénze, a szerver is egészként számol. Az app csak megjelenít és előnézetet számol; a mérvadó összeg a szervertől jön |
| `Money.zero` | konstans | `Money(0)` |
| `Money._nbsp`, `Money._minus` | konstansok | A tördelhetetlen szóköz (`U+00A0`) és a valódi mínuszjel (`U+2212`) a formázáshoz |
| `Money.sum(amounts)` | statikus metódus | Összegzi az összegeket |
| `+`, `-`, `*`, `<`, `<=`, `>`, `>=` | operátorok | Összeadás, kivonás, szorzás darabszámmal, összehasonlítás |
| `Money.format()` | metódus | `1 290 Ft`: ezres tagolás tördelhetetlen szóközzel (az összeg sosem törik két sorba), negatívnál valódi mínuszjellel |

#### app/lib/core/format/date_time_format.dart

| Név | Mi ez | Leírás |
|---|---|---|
| `_two` | privát függvény | Két számjegyre egészíti ki a számot (nullával) |
| `formatClock(time)` | függvény | `12:05` |
| `formatDate(date)` | függvény | `2026. 10. 21.` |
| `formatTimeRange(start, end)` | függvény | `12:00–13:00` (nagykötőjellel) |

#### app/lib/core/text/fold_text.dart

| Név | Mi ez | Leírás |
|---|---|---|
| `_folded` | privát térkép | A magyar ékezetes kisbetűk ékezet nélküli párja (`á`→`a`, `ő`→`o`, `ű`→`u` ...) |
| `foldText(input)` | függvény | Kisbetűsre alakít és elhagyja az ékezeteket, hogy a "rantott" megtalálja a "Rántott"-at. Az étlapot az app egyszer letölti és helyben keresi; ha több száz tételes lesz, a keresést a szerverre kell tenni (lásd `decisions.md`) |

#### app/lib/core/realtime/live_query.dart

Az élő frissítés magja. A képernyők, amelyek a rendelések változását követik, ezt használják.

| Név | Mi ez | Leírás |
|---|---|---|
| `ChangeFeed` | típusnév | Függvény, amely `onChange` (valami változhatott az adatbázisban) és `onStatus(live)` (él-e a kapcsolat) visszahívást kap, és a leiratkozó függvényt adja vissza |
| `_channelCounter` | privát számláló | Az egyedi Realtime-csatornanevekhez (`live-<tábla>-<n>`) |
| `realtimeChangeFeed(client, table:, filter:)` | függvény | Egy tábla `ChangeFeed`-je a Supabase Realtime-on. A Realtime alkalmazza a sorszintű jogosultságot, így a vevő csak a saját soraira kap értesítést. Leiratkozáskor eltávolítja a csatornát |
| `liveQuery<T>(feed:, fetch:, pollInterval:, safetyInterval:, settleDelay:)` | függvény | Egy érték, amely lépést tart az adatbázissal: egyszer lekéri, majd minden jelzett változásra újra. **Amíg az élő kapcsolat nincs fent, `pollInterval`-onként (5 mp) lekérdez**; élőben is lekér `safetyInterval`-onként (60 mp) arra az esetre, ha egy újracsatlakozás alatt esemény veszett el. A Realtime valamivel korábban jelzi késznek a feliratkozást, mint ahogy a szerver valóban kézbesít, ezért `settleDelay` (2 mp) múlva még egyszer lekér. Az első érték előtti hiba hibaként megy tovább; utána a hibát elnyeli, hogy a képernyő ne veszítse el, amit mutat. Lekérés közben jött újabb jelzés után még egyet lekér (`again`). Lezárás után (`closed`) nem indít időzítőt és nem lekér |

#### app/lib/core/router/app_router.dart

| Név | Mi ez | Leírás |
|---|---|---|
| `_needsSignIn(path)` | privát függvény | Igaz a `/checkout`, `/pay/...` és `/orders/...` útvonalra. Az étlap böngészése és a kosár vendégként is nyitva áll; a rendeléshez fiók kell (a rendelések fül maga mutat belépési felkérést) |
| `authRedirect({signedIn, location})` | függvény (tesztekhez látható) | A router belépési szabályai a routertől külön, hogy tesztelhetők legyenek: a belépett felhasználót a `/login` és `/register` helyett továbbviszi (`from` paraméter vagy `/profile`); a vendéget a védett útról `/login?from=<hová tartott>` címre küldi. A visszatérési cél a `safeReturnPath`-on megy át |
| `routerProvider` | szolgáltató | A `GoRouter`. Kezdőcím `/menu`; a munkamenet változására újra lefuttatja az átirányítást. Négy fül (`StatefulShellRoute.indexedStack`: `/menu`, `/cart`, `/orders` + `/orders/:id`, `/profile` + `/profile/credits`), mellettük teljes képernyős `/login`, `/register`, `/notifications`, `/checkout`, `/pay/:orderId`, és (a demó buildben nem) `/dev/gallery` |

#### app/lib/core/router/home_shell.dart

| Név | Mi ez | Leírás |
|---|---|---|
| `HomeShell` | `ConsumerWidget` | Az alsó navigációs sáv a négy fül körül (Étlap, Kosár, Rendeléseim, Profil). Minden fül külön navigációs veremmel és görgetési állapottal él (`StatefulNavigationShell`); a kosár ikonján a tételek száma látszik |
| `HomeShell.navigationShell` | mező | A go_router shell-je, amelyből a fülváltás megy |

#### app/lib/core/router/locations.dart

| Név | Mi ez | Leírás |
|---|---|---|
| `tabLocations` | konstans | A négy fül útvonala. Egy fülre `go`-val kell menni (az a veremet a fülig cseréli); `push` a teljes shellt még egyszer ráhalmozná |
| `isTabLocation(location)` | függvény | Igaz, ha a cím útvonala fül |

#### app/lib/core/theme/app_colors.dart

| Név | Mi ez | Leírás |
|---|---|---|
| `AppColors` | `abstract final class` | A "saláta" paletta: zöldek mint márkaszín, paradicsompiros mint kiemelés, meleg krém háttéren. A szövegpárok kontrasztját a `test/core/theme/app_colors_test.dart` őrzi |
| `green900`, `green700`, `green500`, `green100`, `green50` | konstansok | A zöld árnyalatai (sötéttől világosig). A `green700` az elsődleges szín |
| `tomato700`, `tomato600`, `tomato100` | konstansok | A paradicsompiros: szöveg/ikon (700), kiemelés és demó-szalag (600), halvány háttér (100) |
| `cream`, `surface` | konstansok | Az oldal krémszínű háttere és a kártyák fehérje |
| `outline`, `outlineStrong` | konstansok | A dekoratív vonalak (osztók, kártyaszél) és a jelentést hordozó szegélyek (beviteli mezők, 3:1 kontraszt) |
| `ink`, `inkMuted` | konstansok | A szöveg és a halványabb szöveg színe |
| `error` | konstans | A hibaszín |

#### app/lib/core/theme/app_spacing.dart

| Név | Mi ez | Leírás |
|---|---|---|
| `AppSpacing` | `abstract final class` | Térközök: `xs` 4, `sm` 8, `md` 16, `lg` 24, `xl` 32 |
| `AppRadius` | `abstract final class` | Lekerekítések: `control` 14 (gombok, mezők), `card` 20, `dialog` 24 |

#### app/lib/core/theme/app_typography.dart

| Név | Mi ez | Leírás |
|---|---|---|
| `AppFonts` | `abstract final class` | A betűcsaládok: `heading` (`Baloo2`), `body` (`Inter`), `fallback` (rendszerbetű). A betűk az appba vannak csomagolva (`assets/fonts`), sosem külső címről jönnek; emoji nem használható a szövegben, mert tartalék betű letöltését váltaná ki |
| `AppTypography` | `abstract final class` | A szöveg-témák |
| `AppTypography.priceFeatures` | konstans | Táblázatos számjegyek (`tabularFigures`): az árak egy oszlopban illeszkednek |
| `AppTypography.textTheme()` | metódus | A teljes `TextTheme` (cím: Baloo 2, törzs: Inter). A beviteli mezők szövege legalább 16 px, különben az iOS Safari ráközelít fókuszkor |

#### app/lib/core/theme/app_theme.dart

| Név | Mi ez | Leírás |
|---|---|---|
| `AppTheme` | `abstract final class` | |
| `AppTheme.light()` | metódus | A `ThemeData`: Material 3, a `ColorScheme` az `AppColors`-ból, és az összes komponens (gombok, mezők, chip, navigációs sáv, snackbar, dialógus, kereső, szegmentált gomb, alsó lap, jelvény) egységesen formázva |

#### app/lib/core/widgets/app_frame.dart

| Név | Mi ez | Leírás |
|---|---|---|
| `AppFrame` | `StatelessWidget` | Az app fölé teszi a `below` elemet (az értesítéssávot), alatta az app. Nincs állandó szalag |
| `AppFrame.child` | mező | Az app |
| `AppFrame.below` | mező | A fölé kerülő elem (értesítés); a sáv a státuszsor alatt ül |

#### app/lib/core/widgets/failure_box.dart

| Név | Mi ez | Leírás |
|---|---|---|
| `FailureBox` | `StatelessWidget` | Rövid hibaüzenet halvány piros dobozban; megjelenésekor a képernyőolvasó felolvassa (`liveRegion`) |
| `FailureBox.message` | mező | Az üzenet |

#### app/lib/core/widgets/quantity_stepper.dart

| Név | Mi ez | Leírás |
|---|---|---|
| `QuantityStepper` | `StatelessWidget` | Pirula: mínusz, darabszám, plusz |
| `QuantityStepper.quantity` | mező | A darabszám |
| `QuantityStepper.onIncrement` | mező | A plusz gomb |
| `QuantityStepper.onDecrement` | mező | A mínusz gomb; `null` esetén letiltva (a legkisebb engedett mennyiségnél) |
| `_StepButton` | privát widget | Egy 44 x 44 képpontos gomb a pirulában |
| `_StepButton.icon`, `_StepButton.tooltip`, `_StepButton.onPressed` | mezők | Az ikon, a súgószöveg (a képernyőolvasó is ezt mondja) és a művelet (`null`: halvány, letiltott) |

#### app/lib/core/widgets/state_views.dart

Minden képernyőnek a tartalmán kívül három állapota van: betöltés, hiba, üres. A képernyők ezeket használják, nem rögtönöznek sajátot.

| Név | Mi ez | Leírás |
|---|---|---|
| `LoadingView` | `StatelessWidget` | Forgó jelző és felirat; a képernyőolvasónak egyetlen élő üzenet |
| `LoadingView.message` | mező | A felirat (alapból "Betöltés...") |
| `ErrorView` | `StatelessWidget` | Hibaállapot felhő-ikonnal; `onRetry` esetén "Újra" gombbal |
| `ErrorView.title`, `ErrorView.body`, `ErrorView.onRetry` | mezők | A cím, a szöveg (alapból az általános hibaüzenet) és az újrapróbálás |
| `EmptyView` | `StatelessWidget` | Üres állapot (üres kosár, nincs találat) |
| `EmptyView.icon`, `EmptyView.title`, `EmptyView.body`, `EmptyView.action` | mezők | Az ikon, a cím, a magyarázó szöveg és egy akciógomb |
| `_StateLayout` | privát widget | A hiba és az üres állapot közös elrendezése: kör alakú ikon, cím, szöveg, gomb, legfeljebb 320 képpont szélesen, görgethetően |
| `_StateLayout.icon`, `iconColor`, `iconBackground`, `title`, `body`, `action` | mezők | A fentiek, szín nélkül is megadva |

#### app/lib/core/widgets/zaba_wordmark.dart

| Név | Mi ez | Leírás |
|---|---|---|
| `ZabaWordmark` | `StatelessWidget` | A logó (a Z a rolleres) a név mellett. A jel az `assets/brand/zaba-mark.svg`-ből a `tool/brand/make_icons.py` készítette képek (1x, 2x, 3x), így bármilyen méretben éles. A képnek nincs saját felolvasása: mellette ott a név |
| `ZabaWordmark.size` | mező | A jel magassága (alapból 32); a szöveg ennek 0,8-szorosa |

#### app/lib/core/dev/design_gallery_screen.dart

Fejlesztői galéria a témáról és a közös elemekről, a profilról érhető el (a demó buildben nem). A szövege szándékosan nem lokalizált: arra való, hogy valódi eszközön szemrevételezzük a betűket (főleg az ő/ű glifeket), a színeket és az állapotokat.

| Név | Mi ez | Leírás |
|---|---|---|
| `DesignGalleryScreen` | `StatelessWidget` | A hat szakasz egy görgethető listában |
| `DesignGalleryScreen._pangram` | konstans | "Árvíztűrő tükörfúrógép": minden magyar ékezetes betű benne van |
| `_Section` | privát widget | Címmel ellátott szakasz |
| `_Section.title`, `_Section.child` | mezők | A cím és a tartalom |
| `_Palette` | privát widget | A színminták nevükkel, 72 x 48 képpontos téglalapokon |
| `_Palette._swatches` | konstans | A mutatott 12 szín és neve (a zöldek, a paradicsomok, a krém, a két szövegszín és a halvány vonal) |
| `_Typography` | privát widget | Hat szövegstílus a pangrammal, normál és nagybetűs alakban, alatta az `ő ű Ő Ű`, idézőjel és nagykötőjel próbájával |
| `_Prices` | privát widget | A `Money.format()` hat összegen (0-tól 1 234 567-ig, és egy negatívon), táblázatos számjegyekkel |
| `_Buttons` | privát widget | A kitöltött (zöld és piros), a körvonalas és a szöveges gomb, és egy letiltott |
| `_Inputs` | privát widget | Két beviteli mező (az egyik hibaüzenettel) és három szűrő-chip |
| `_States` | privát widget | A `LoadingView`, az `ErrorView` és az `EmptyView` egy-egy kártyában |

### 4.3 Belépés és fiók (`lib/features/auth/`)

E-mail + jelszó. A munkamenetet (token, frissítés) a megvalósítás kezeli; az app csak azt tudja, ki van bejelentkezve (`AppUser?`). A hibák egyetlen típuson (`AuthFailure`) mennek át, szándékosan **nincs bennük a szerver saját üzenete**,
így semmi technikai nem jut a felhasználóhoz. Nincs jelszó-visszaállítás, fióktörlés és e-mail-megerősítés (lásd `known-gaps.md`).

#### app/lib/features/auth/domain/app_user.dart

| Név | Mi ez | Leírás |
|---|---|---|
| `AppUser` | `@immutable` osztály | A bejelentkezett vásárló, annyira, amennyire a felületnek kell. Érték-egyenlőség (`==`, `hashCode`) az `id`, `email`, `fullName` mezőkön, hogy a felhasználó változatlan ismétlődő eseményei (tokenfrissítés) ne frissítsék feleslegesen a képernyőket |
| `AppUser.id` | mező | A fiók azonosítója (`auth.users.id`) |
| `AppUser.email` | mező | Az e-mail-cím, kisbetűsítve |
| `AppUser.fullName` | mező | A regisztrációkor megadott név; `null`, ha nincs vagy üres |
| `AppUser.displayName` | getter | Amit a képernyő kiír: a név, ennek hiányában az e-mail-cím |

#### app/lib/features/auth/domain/auth_repository.dart

| Név | Mi ez | Leírás |
|---|---|---|
| `AuthFailureReason` | enum | A hiba oka: `invalidCredentials` (rossz e-mail vagy jelszó; szándékosan nem árulja el, melyik), `emailTaken` (már van fiók), `weakPassword`, `emailNotConfirmed` (a projekt megerősítést kér, amit a demó nem tud), `tooManyRequests`, `network`, `unknown` |
| `AuthFailure` | kivétel | Az egyetlen hiba, amit a belépő képernyőknek kezelniük kell |
| `AuthFailure.reason` | mező | A hiba oka |
| `AuthFailure.toString()` | metódus | `AuthFailure(<ok>)`, naplózáshoz |
| `AuthRepository` | interfész | E-mail + jelszavas fiókok |
| `AuthRepository.currentUser` | getter | A tárolt munkamenet felhasználója, ha van |
| `AuthRepository.userChanges` | getter | Folyam: ki- vagy belépéskor, illetve fiókadat-változáskor ad eseményt. Feliratkozáskor **nem** ismétli a jelenlegit: azt a `currentUser` adja |
| `AuthRepository.signIn(email, password)` | metódus | Belépés; `AuthFailure`-t dob |
| `AuthRepository.signUp(email, password, fullName)` | metódus | Fiókot hoz létre és be is léptet; `AuthFailure`-t dob |
| `AuthRepository.signOut()` | metódus | Kilépés |

#### app/lib/features/auth/domain/auth_rules.dart

| Név | Mi ez | Leírás |
|---|---|---|
| `minPasswordLength` | konstans | 8. A `supabase/config.toml` `minimum_password_length` értékét tükrözi; a döntést a szerver hozza, ez csak egy kérést spórol |
| `maxFullNameLength` | konstans | 100 (a profiltábla legfeljebb 200 karaktert fogad el) |
| `_plausibleEmail` | privát minta | `valami@valami.valami`: nincs szóköz, egy `@`, a végén pont-tagolt tartomány |
| `isPlausibleEmail(value)` | függvény | Olcsó épelméjűség-vizsgálat, nem ellenőrzés: az igazi próba, hogy a szerver elfogadja-e a címet |
| `safeReturnPath(value)` | függvény | Belépés után csak alkalmazáson belüli útra lehet visszatérni. Eldobja a más oldalra mutatót, a protokollmentes `//host`-ot, a visszaperjeles (`\`) címet és magukat a belépő oldalakat; `null`-t ad ilyenkor. **Ez védi a nyílt átirányítástól** a `/login?from=...` paramétert |

#### app/lib/features/auth/data/in_memory_auth_repository.dart

| Név | Mi ez | Leírás |
|---|---|---|
| `InMemoryAccount` | rekord-típus | `({email, password, fullName})`: egy fiók a memóriában |
| `offlineDemoAccount` | konstans | A szerver nélküli demó eldobható vásárlója (`demo@zaba.example` / `Demo-jelszo-1`, "Demó Dóra"); a tesztek is ezzel lépnek be |
| `InMemoryAuthRepository` | osztály | Memóriabeli fiókok a szerver nélküli demóhoz és a tesztekhez. A valódi szerver szabályait követi: az e-mail kis- és nagybetűtől függetlenül egyedi, a jelszó legalább `minPasswordLength` karakter. A konstruktor `signedInAs` paramétere már bejelentkezve indít |
| `_accounts` | mező | E-mail (kulcs) szerint a fiókok |
| `_changes` | mező | A `userChanges` folyam vezérlője (broadcast) |
| `_current` | mező | A bejelentkezett felhasználó |
| `_key(email)` | statikus metódus | A kulcs: levágott, kisbetűs e-mail |
| `_add(account)` | metódus | Új fiók felvétele (`user-<n>` azonosítóval) |
| `currentUser`, `userChanges` | getterek | Az interfész szerint |
| `_setCurrent(user)` | metódus | Beállítja a jelenlegi felhasználót és értesít |
| `signIn`, `signUp`, `signOut` | metódusok | Az interfész szerint; hibás belépésnél `invalidCredentials`, rövid jelszónál `weakPassword`, foglalt címnél `emailTaken` |
| `dispose()` | metódus | Lezárja a folyamot |
| `_Account` | privát osztály | Egy fiók: `user` és `password` |

#### app/lib/features/auth/data/supabase_auth_repository.dart

| Név | Mi ez | Leírás |
|---|---|---|
| `SupabaseAuthRepository` | osztály | A Supabase Auth (GoTrue) az interfész mögött. A munkamenetet a Supabase-kliens tárolja és frissíti; weben a böngésző helyi tárhelyén |
| `_auth` | mező | A `GoTrueClient` |
| `currentUser` | getter | A kliens jelenlegi felhasználója `AppUser`-ré alakítva |
| `userChanges` | getter | Az `onAuthStateChange` folyamból, `distinct()`-tel (a tokenfrissítés ugyanazt a felhasználót küldi újra) |
| `signIn` | metódus | `signInWithPassword`, a hibákat `authFailureFrom` alakítja |
| `signUp` | metódus | `signUp`; a nevet a `data.full_name` mezőben küldi, a profilt az adatbázis-trigger tölti ki. Ha nincs munkamenet a válaszban, a projekt e-mail-megerősítést kér: `emailNotConfirmed` |
| `signOut` | metódus | Kilépés |
| `_requireUser(user)` | metódus | A felhasználó, vagy `unknown` hiba, ha hiányzik |
| `_toUser(user)` | statikus metódus | `User` → `AppUser` (a név a `user_metadata.full_name`) |
| `authFailureFrom(error)` | függvény | Bármi, amit a kliens dob, az egyetlen ismert hibává. **A szerver stabil hibakódja** (`code`) alapján dönt, nem az üzenet szövegéből: `invalid_credentials`, `user_already_exists`/`email_exists`, `weak_password`, `email_not_confirmed`, `over_request_rate_limit`/`over_email_send_rate_limit` (és a 429-es állapot) → `tooManyRequests`. Aminek nem auth-szerver az eredete (socket, időtúllépés, böngésző `fetch` hiba), az `network` |

#### app/lib/features/auth/application/auth_providers.dart

| Név | Mi ez | Leírás |
|---|---|---|
| `authRepositoryProvider` | szolgáltató | Alapból a memóriabeli, az `offlineDemoAccount`-tal; a `main.dart` a Supabase-osra cseréli |
| `sessionProvider` | szolgáltató | Ki van most bejelentkezve (`null` = vendég). **A router és a képernyők ezt figyelik**, így semmi más nem ismeri az auth-folyamot |
| `SessionNotifier` | `Notifier<AppUser?>` | A `userChanges` folyamra iratkozik, és a `currentUser`-rel indul. A `build` a repository cseréjekor újraindul |
| `DemoCredentials` | osztály | A demó fiók adatai |
| `DemoCredentials.email`, `DemoCredentials.password` | mezők | A fiók belépési adatai |
| `demoCredentialsProvider` | szolgáltató | A "belépés demó fiókkal" gomb fiókja. Szerver nélkül az `offlineDemoAccount`; szerverrel az `AppConfig.demoEmail`/`demoPassword`, és `null` (a gomb rejtve), ha egyik sincs megadva |

#### app/lib/features/auth/presentation/auth_messages.dart

| Név | Mi ez | Leírás |
|---|---|---|
| `authFailureMessage(l10n, reason)` | függvény | A hiba okából a magyar felhasználói szöveg (az `authError...` szövegek) |

#### app/lib/features/auth/presentation/auth_screen.dart

| Név | Mi ez | Leírás |
|---|---|---|
| `AuthMode` | enum | `login` vagy `register`: a két módnak egy űrlapja van |
| `AuthScreen` | `ConsumerStatefulWidget` | Belépés és regisztráció. Siker után a `returnTo` címre lép (az átirányítás ezt nem tudná: egy másik oldal tetejére tett oldalnál csak az alatta lévőt nézi) |
| `AuthScreen.mode` | mező | A mód |
| `AuthScreen.returnTo` | mező | Ahová a felhasználó tartott, mielőtt belépést kértünk tőle (a `safeReturnPath`-on átment érték) |
| `_AuthScreenState` | állapot | Az űrlap állapota |
| `_formKey` | mező | Az űrlap kulcsa az egyben-ellenőrzéshez |
| `_name`, `_email`, `_password` | mezők | A beviteli mezők vezérlői |
| `_showPassword` | mező | Látszik-e a jelszó |
| `_busy` | mező | Folyamatban van a kérés: a mezők és gombok le vannak tiltva, a gomb helyén forgó jelző van (a dupla elküldést is ez gátolja) |
| `_checkWhileTyping` | mező | Az első elküldés után gépelés közben is ellenőriz |
| `_failure` | mező | A kérés hibájának oka, amit a `FailureBox` mutat |
| `_isLogin` | getter | A mód belépés-e |
| `dispose()` | metódus | A vezérlők felszabadítása |
| `_run(call)` | metódus | Lefuttat egy hívást: `_busy` be, hiba esetén `_failure`, siker esetén `_leave`; csak akkor nyúl az állapothoz, ha a képernyő még él |
| `_leave()` | metódus | A `returnTo` (vagy `/profile`) útra lép: fülre `go`-val (a mögötte lévő fülek a helyükön maradnak), máshová `pushReplacement`-tel |
| `_submit()` | metódus | Ellenőriz, aztán belép vagy regisztrál |
| `_signInWithDemoAccount(demo)` | metódus | A demó fiókkal lép be |
| `_switchMode()` | metódus | Belépés és regisztráció között vált, a `from` paramétert megtartva |

#### app/lib/features/profile/presentation/profile_screen.dart

| Név | Mi ez | Leírás |
|---|---|---|
| `ProfileScreen` | `ConsumerWidget` | A fiók és a demó-tájékoztató, amelynek itt mindig látszania kell. Tartalma: a demó-kártya, a fiókkártya, a "Képek forrásai" és (a demó buildben nem) a komponens-galéria belépője |
| `_AccountCard` | privát widget | Vendégnek a belépés/regisztráció gombjai; bejelentkezettnek a monogram (a név első betűje, név és e-mail nélküli fióknál `?`), a név, az e-mail és a kijelentkezés |
| `_AccountCard.user` | mező | A bejelentkezett felhasználó vagy `null` |
| `_AccountCard._signOut(context, ref)` | metódus | Kilépés; hiba esetén snackbar |

### 4.4 Kiszállítás (`lib/features/delivery/`)

A cím, a zóna (milyen díjjal és minimummal szállítunk) és az idősáv. A zónát az app csak azért ismeri, hogy **kérdezés előtt válaszolhasson**; a rendelés árazásakor és felvételekor a szerver újra dönt.

#### app/lib/features/delivery/domain/delivery_address.dart

| Név | Mi ez | Leírás |
|---|---|---|
| `DeliveryAddress` | osztály | A vásárló által megadott szállítási cím. Csak Budapest, ezért város nincs benne |
| `DeliveryAddress.postalCode` | mező | Négyjegyű irányítószám |
| `DeliveryAddress.street` | mező | Utca és házszám, ahogy beírták |

#### app/lib/features/delivery/domain/delivery_slot.dart

| Név | Mi ez | Leírás |
|---|---|---|
| `DeliverySlot` | osztály | Foglalható szállítási időablak. Érték-egyenlőség az `id`, `start`, `end` mezőkön |
| `DeliverySlot.id` | mező | Amit a rendelés lefoglal; szerveren a sáv sorának azonosítója |
| `DeliverySlot.start`, `DeliverySlot.end` | mezők | Az ablak kezdete és vége |
| `DeliveryDay` | osztály | Egy naptári nap foglalható sávjai |
| `DeliveryDay.date` | mező | A nap éjfélje |
| `DeliveryDay.slots` | mező | A nap sávjai, korai elöl |

#### app/lib/features/delivery/domain/delivery_slot_service.dart

| Név | Mi ez | Leírás |
|---|---|---|
| `DeliverySlotService` | interfész | Az idősávok forrása |
| `DeliverySlotService.availableDays({now})` | metódus | Azok a napok, amelyeken `now`-kor még van foglalható sáv, korai elöl |
| `DeliverySlotService.isAvailable(slot, {now})` | metódus | Foglalható-e még a sáv `now`-kor |

#### app/lib/features/delivery/domain/delivery_zone.dart

| Név | Mi ez | Leírás |
|---|---|---|
| `DeliveryZone` | osztály | Azonos feltételű budapesti kerületek csoportja. Az irányítószám első három karaktere ("1" + a kerület két számjegye) dönti el, melyik zónába tartozik a cím |
| `DeliveryZone.id`, `DeliveryZone.name` | mezők | Azonosító és megnevezés |
| `DeliveryZone.postalPrefixes` | mező | A zóna háromjegyű irányítószám-előtagjai |
| `DeliveryZone.deliveryFee` | mező | A szállítási díj |
| `DeliveryZone.minOrder` | mező | A legkisebb rendelési érték |
| `DeliveryZone.etaMinMinutes`, `DeliveryZone.etaMaxMinutes` | mezők | A becsült szállítási idő sávja percben |
| `DeliveryZone.freeDeliveryFrom` | mező | Ettől a rendelési értéktől ingyenes a szállítás; `null`, ha soha |
| `zoneServing(zones, postalCode)` | függvény | A zónák közül az, amelyik kiszolgálja az irányítószámot (az első három karakter alapján), vagy `null`, ha a cím a szállítási területen kívül van. Háromnál rövidebb irányítószámra `null` |

#### app/lib/features/delivery/domain/delivery_zone_repository.dart

| Név | Mi ez | Leírás |
|---|---|---|
| `DeliveryZoneRepository` | interfész | A zónák forrása |
| `DeliveryZoneRepository.zoneForPostalCode(postalCode)` | metódus | A kiszolgáló zóna, vagy `null` |
| `DeliveryZoneRepository.defaultZone()` | metódus | A zóna, amelyet a becslésekhez feltételezünk, amíg nincs cím |

#### app/lib/features/delivery/data/demo_zones.dart

Demóadat; az éles értékeket az üzemeltető állítja be.

| Név | Mi ez | Leírás |
|---|---|---|
| `innerZone` | konstans | Belső kerületek (I, II, V-IX, XI-XIII): 990 Ft díj, 3 500 Ft minimum, 15 000 Ft felett ingyenes, 35-50 perc |
| `outerZone` | konstans | Külső kerületek (III, IV, X, XIV-XVI): 1 490 Ft díj, 5 000 Ft minimum, soha nem ingyenes, 45-60 perc |
| `demoZones` | konstans | A kettő együtt. A `supabase/seed/20_delivery.sql` kézzel karbantartott megfelelője (az étlapnál ellenőrzi a `seed_sql_test.dart` a fájlt, a zónáknál nincs ilyen teszt: az értékek egyezését a `supabase/tests/api_smoke.py` és a pgTAP `060` tesztek a szerver oldalán őrzik) |

#### app/lib/features/delivery/data/in_memory_delivery_zone_repository.dart

| Név | Mi ez | Leírás |
|---|---|---|
| `InMemoryDeliveryZoneRepository` | osztály | A zónák memóriából |
| `zones` | mező | A zónák (alapból `demoZones`) |
| `fallbackZone` | mező | Az alapértelmezett zóna (alapból `innerZone`) |
| `zoneForPostalCode`, `defaultZone` | metódusok | Az interfész szerint |

#### app/lib/features/delivery/data/supabase_delivery_zone_repository.dart

| Név | Mi ez | Leírás |
|---|---|---|
| `SupabaseDeliveryZoneRepository` | osztály | A zónák a Supabase-ből. Csak néhány van, ezért egyszer betölti őket, és az irányítószámot itt illeszti; a szerver a rendelés árazásakor újra ellenőriz. A sikertelen betöltést nem jegyzi meg, a következő hívás újra próbálja |
| `_client` | mező | A `SupabaseClient` |
| `_loaded` | mező | A betöltés `Future`-je (megosztva a párhuzamos hívásokkal) |
| `_zones()` | metódus | A betöltött zónák; hibánál elfelejti a próbálkozást |
| `_fetch()` | metódus | Lekéri a `delivery_zones` táblát az előtagjaival együtt, `sort_order`, `id` szerint |
| `zoneForPostalCode`, `defaultZone` | metódusok | Az interfész szerint; ha nincs alapértelmezett zóna beállítva, `StateError` |
| `ZoneRow` | rekord-típus | `({zone, isEstimateDefault})` |
| `zoneRowFromJson(row)` | függvény | Egy adatbázissor `ZoneRow`-vá (előtagok, összegek `Money`-ként, a `null` ingyenes küszöb) |

#### app/lib/features/delivery/data/in_memory_delivery_slot_service.dart

| Név | Mi ez | Leírás |
|---|---|---|
| `InMemoryDeliverySlotService` | osztály | Óránkénti sávok a nyitvatartás alatt: hétfőtől szombatig 11-21, vasárnap 11-20. Az idő az eszköz helyi ideje; a valódi szolgáltatás a szerveren, Europe/Budapest szerint rak ki sávokat (az óraátállítással együtt) |
| `leadTime` | mező | Ennyivel a kezdete előtt már nem foglalható a sáv (alapból 45 perc) |
| `days` | mező | Hány naptári nap foglalható a mai nappal együtt (alapból 3) |
| `_openingHour` | konstans | 11 |
| `_closingHour(date)` | metódus | Zárás órája: vasárnap 20, egyébként 21 |
| `availableDays`, `isAvailable` | metódusok | Az interfész szerint |

#### app/lib/features/delivery/data/supabase_delivery_slot_service.dart

| Név | Mi ez | Leírás |
|---|---|---|
| `SupabaseDeliverySlotService` | osztály | A sávok a `get_delivery_slots` függvényből (csak bejelentkezett vásárlónak). A szerver rakja ki a sávokat a bolt időzónájában, és alkalmazza a nyitvatartást, az előfutást és a kapacitást a saját órájával: az interfész `now` paramétere itt nem számít. A napokat és az időket az eszköz időzónájában mutatja (Magyarországon ez a boltéval egyezik) |
| `_client` | mező | A `SupabaseClient` |
| `availableDays`, `isAvailable` | metódusok | Az `isAvailable` újra kérdez a szervertől, hogy a válasz a lehető legfrissebb legyen |
| `deliveryDaysFromRows(rows)` | függvény | A szerver sávjait naptári napokba csoportosítja, korai elöl |

#### app/lib/features/delivery/application/delivery_providers.dart

| Név | Mi ez | Leírás |
|---|---|---|
| `deliverySlotServiceProvider` | szolgáltató | Alapból a memóriabeli; a `main.dart` cseréli |
| `deliveryDaysProvider` | szolgáltató | A foglalható napok sávokkal (`clockProvider` ideje szerint) |
| `deliveryZoneRepositoryProvider` | szolgáltató | Alapból a memóriabeli; a `main.dart` cseréli |
| `DeliveryAddressNotifier` | `Notifier<DeliveryAddress?>` | A vásárló választott szállítási címe; amíg nincs, `null` |
| `DeliveryAddressNotifier.set(address)` | metódus | Beállítja a címet |
| `deliveryAddressProvider` | szolgáltató | A fenti notifier szolgáltatója |
| `deliveryZoneProvider` | szolgáltató | A választott cím zónája, vagy az alapértelmezett zóna, amíg nincs cím (vagy a cím kívül esik) |

#### app/lib/features/delivery/presentation/address_dialog.dart

| Név | Mi ez | Leírás |
|---|---|---|
| `formatAddress(l10n, address)` | függvény | "1051 Budapest, Váci utca 12." |
| `showAddressDialog(context)` | függvény | Megnyitja a cím megadása párbeszédablakot |
| `_AddressDialog` | `ConsumerStatefulWidget` | Irányítószám (csak számjegy, legfeljebb 4) és utca. Mentéskor ellenőrzi: négyjegyű-e, kiszolgálja-e zóna (ha a zónák nem tölthetők be, ezt mondja ki, és nyitva marad), nem üres-e az utca |
| `_AddressDialogState` | állapot | |
| `_postalCode`, `_street` | mezők | A mezők vezérlői (a jelenlegi címmel előtöltve) |
| `_postalCodeError`, `_streetError` | mezők | A mezők hibaszövege, gépeléskor törlődik |
| `_saving` | mező | Mentés közben letiltja a gombot |
| `_save()` | metódus | Ellenőriz, majd beállítja a `deliveryAddressProvider` címét és bezár |

### 4.5 Étlap (`lib/features/catalog/`)

Az étlapot az app **egyszer tölti le** (kategóriák és termékek), és helyben szűri, rendezi, keresi (`applyMenuFilter`). A szerver csak az aktív termékeket és kategóriákat adja ki (sorszintű jogosultság), és
a `catalog_products` nézet csak olyan terméket listáz, amelynek a kategóriája is aktív. Az allergén-adat biztonsági kérdés: ismeretlen kód esetén az étlap **nem tölt be** (nem hagyja el csendben).

#### app/lib/features/catalog/domain/allergen.dart

| Név | Mi ez | Leírás |
|---|---|---|
| `Allergen` | enum | Az EU 14 kötelezően jelölendő allergénje. Az értékek: `gluten`, `crustaceans`, `egg`, `fish`, `peanut`, `soy`, `milk`, `nuts`, `celery`, `mustard`, `sesame`, `sulphites`, `lupin`, `molluscs` |
| `Allergen.code` | mező | Az adatbázisban tárolt kód (`products.allergens`) |
| `Allergen.fromCode(code)` | statikus metódus | A kódhoz tartozó érték; ismeretlen kódra `FormatException` |

#### app/lib/features/catalog/domain/category.dart

| Név | Mi ez | Leírás |
|---|---|---|
| `Category` | osztály | Étlap-kategória |
| `Category.id` | mező | Azonosító (a szerveren szöveg) |
| `Category.name` | mező | Megnevezés |
| `Category.iconKey` | mező | Szöveges ikonkulcs, hogy a domain Flutter-típustól mentes maradjon; a megjelenítés az `iconForCategoryKey`-jel választ ikont |

#### app/lib/features/catalog/domain/product.dart

| Név | Mi ez | Leírás |
|---|---|---|
| `Product` | osztály | Egy étlap-tétel |
| `Product.id` | mező | Azonosító |
| `Product.categoryId` | mező | A kategória azonosítója |
| `Product.name`, `Product.description` | mezők | Név és leírás |
| `Product.price` | mező | Bruttó ár (az ÁFÁ-val) egész forintban |
| `Product.allergens` | mező | Az allergének halmaza |
| `Product.vegetarian` | mező | Vegetáriánus-e |
| `Product.popularity` | mező | Nagyobb = népszerűbb; ez adja az alapsorrendet |
| `Product.imagePath` | mező | A fotó fájlneve az `assets/images/products/` mappában, ha van |

#### app/lib/features/catalog/domain/catalog_repository.dart

| Név | Mi ez | Leírás |
|---|---|---|
| `CatalogRepository` | interfész | Az étlap forrása |
| `CatalogRepository.categories()` | metódus | A kategóriák megjelenítési sorrendben |
| `CatalogRepository.products()` | metódus | A termékek |

#### app/lib/features/catalog/data/demo_catalog.dart

| Név | Mi ez | Leírás |
|---|---|---|
| `demoCategories` | konstans | A hét kategória (tészták, saláták, levesek, magyaros főételek, szendvicsek és burgerek, desszertek, italok); az `id` és az `iconKey` egyezik |
| `demoProducts` | konstans | A 45 kitalált demó-termék (ár, allergén, népszerűség, fotó). Az allergén-halmazok és az árak csak szemléltetők. **Ebből készül** a `supabase/seed/10_catalog.sql` (`app/tool/seed_sql.dart`), a `seed_sql_test.dart` pedig elbukik, ha a két fájl eltér |

#### app/lib/features/catalog/data/image_credits.dart

Generált fájl (`tool/images/build_images.py`), kézzel nem szerkeszthető.

| Név | Mi ez | Leírás |
|---|---|---|
| `ImageCredit` | osztály | Egy fotó forrása és licence (a CC BY megköveteli a forrásmegjelölést, ezért az app megmutatja) |
| `ImageCredit.productId` | mező | Melyik termék fotója |
| `ImageCredit.title` | mező | A fájl neve a Wikimedia Commonson |
| `ImageCredit.author` | mező | A szerző |
| `ImageCredit.license` | mező | A licenc (`CC0`, `Public domain` vagy `CC BY x.y`) |
| `ImageCredit.pageUrl` | mező | A fotó oldala a Commonson |
| `imageCredits` | konstans | Minden fotó forrása (egy `ImageCredit` fotónként) |

#### app/lib/features/catalog/data/in_memory_catalog_repository.dart

| Név | Mi ez | Leírás |
|---|---|---|
| `InMemoryCatalogRepository` | osztály | A beépített demó-étlap (alapból), és tesztdupla |
| `categoryList` | mező | A kategóriák (alapból `demoCategories`) |
| `productList` | mező | A termékek (alapból `demoProducts`) |
| `categories()`, `products()` | metódusok | A listák |

#### app/lib/features/catalog/data/supabase_catalog_repository.dart

| Név | Mi ez | Leírás |
|---|---|---|
| `SupabaseCatalogRepository` | osztály | Az étlap a Supabase-ből. Mindkét olvasás vendégnek is nyitva áll; az inaktív sorok sosem érik el az appot |
| `_client` | mező | A `SupabaseClient` |
| `categories()` | metódus | A `categories` tábla `sort_order`, `id` szerint (a `order` alapból csökkenő, ezért az `ascending: true` kell) |
| `products()` | metódus | A `catalog_products` nézet (a termék a jelenlegi árával), népszerűség szerint csökkenően, majd `id` szerint |
| `categoryFromRow(row)` | függvény | Adatbázissor → `Category` |
| `productFromRow(row)` | függvény | Adatbázissor → `Product`; ismeretlen allergénkódra `FormatException` |

#### app/lib/features/catalog/application/menu_filter.dart

| Név | Mi ez | Leírás |
|---|---|---|
| `MenuSort` | enum | A rendezés: `popular` (népszerűség, alapból), `priceAscending`, `priceDescending` |
| `MenuFilter` | osztály | Az étlap szűrőinek állapota |
| `MenuFilter.query` | mező | A keresőszöveg |
| `MenuFilter.categoryId` | mező | A kiválasztott kategória; `null` = mind |
| `MenuFilter.vegetarianOnly` | mező | Csak vegetáriánus tételek |
| `MenuFilter.sort` | mező | A rendezés |
| `MenuFilter.isDefault` | getter | Nincs szűrő és a rendezés alapértelmezett: ilyenkor az üres lista azt jelenti, hogy nincs étlap, nem azt, hogy nincs találat |
| `MenuFilter.grouped` | getter | A lista kategória-szakaszokban csak akkor jelenik meg, ha sem a keresés, sem a rendezés nem rendezi át; egyébként egyetlen lapos lista |
| `applyMenuFilter(products, filter)` | függvény | Szűr és rendez. A keresés kis- és nagybetűre, valamint a magyar ékezetre érzéketlen (`foldText`), a nevet és a leírást nézi. Egyenlő népszerűségnél vagy árnál a név dönt |

#### app/lib/features/catalog/application/catalog_providers.dart

| Név | Mi ez | Leírás |
|---|---|---|
| `catalogRepositoryProvider` | szolgáltató | Alapból a beépített demó-étlap; a `main.dart` cseréli |
| `categoriesProvider` | szolgáltató | A kategóriák |
| `productsProvider` | szolgáltató | A termékek |
| `MenuFilterNotifier` | `Notifier<MenuFilter>` | A szűrők állapota |
| `MenuFilterNotifier.setQuery(query)` | metódus | A keresőszöveg beállítása |
| `MenuFilterNotifier.selectCategory(id)` | metódus | Kategória választása; a már kiválasztott újra választása törli a választást |
| `MenuFilterNotifier.toggleVegetarian()` | metódus | A vegetáriánus szűrő be/ki |
| `MenuFilterNotifier.setSort(sort)` | metódus | A rendezés beállítása |
| `MenuFilterNotifier.reset()` | metódus | Minden szűrő törlése |
| `menuFilterProvider` | szolgáltató | A fenti notifier szolgáltatója |
| `visibleProductsProvider` | szolgáltató | A szűrők utáni termékek. Az étlap a kategóriák nélkül nem használható, ezért a sikertelen kategória-betöltés ezt is hibássá teszi |
| `reloadMenu(ref)` | függvény | Hiba után újratölti a kategóriákat és a termékeket |

#### app/lib/features/catalog/presentation/category_icons.dart

| Név | Mi ez | Leírás |
|---|---|---|
| `iconForCategoryKey(key)` | függvény | A `Category.iconKey` Material-ikonná: `pasta`, `salad`, `soup`, `hungarian`, `sandwich`, `dessert`, `drink`; ismeretlen kulcsra az általános étterem-ikon |

#### app/lib/features/catalog/presentation/allergen_labels.dart

| Név | Mi ez | Leírás |
|---|---|---|
| `AllergenLabel` | kiterjesztés az `Allergen`-en | |
| `AllergenLabel.label(l10n)` | metódus | Az allergén magyar neve (`allergenGluten`, `allergenEgg` ... szövegek) |

#### app/lib/features/catalog/presentation/menu_screen.dart

| Név | Mi ez | Leírás |
|---|---|---|
| `_MenuRow` | lezárt (`sealed`) osztály | A lista egy sora: kategória-fejléc vagy termék |
| `_HeaderRow` | privát osztály | Kategória-fejléc; `title` a kategória neve |
| `_ProductRow` | privát osztály | Termék-sor; `product` a termék |
| `_buildRows(products, categories, filter)` | függvény | A sorok. Lapos listánál csak termékek; csoportosnál minden kategória fejléccel és termékeivel, a termékek nélküli kategória fejléc nélkül. (Olyan termék, amelynek kategóriája nincs a listában, itt nem jelenik meg: az adatbázis nézete ezért nem is ad ki ilyet) |
| `MenuScreen` | `ConsumerStatefulWidget` | Az Étlap fül: fent a szállítási cím (érintésre a cím párbeszédablak), a kereső, a zóna feltételei, a szűrő-chipek (vegetáriánus, kategóriák), a rendezés, majd a lista; alul a `CartBar` |
| `_MenuScreenState` | állapot | |
| `_search` | mező | A kereső vezérlője |
| `_resetFilters()` | metódus | Törli a keresőt és minden szűrőt |
| `dispose()` | metódus | A vezérlő felszabadítása |

#### app/lib/features/catalog/presentation/widgets/product_card.dart

| Név | Mi ez | Leírás |
|---|---|---|
| `ProductCard` | `ConsumerWidget` | A lista egy kártyája: kép, név, leírás (két sor), ár, vegetáriánus jel, és a kosárba gomb (0 darabnál) vagy a `QuantityStepper` (egyébként). Keskeny képernyőn vagy nagy betűmérettel a darabszám-választó külön sorba kerül (`Wrap`), nem vágódik le. Érintésre megnyílik a `ProductSheet` |
| `ProductCard.product` | mező | A termék |

#### app/lib/features/catalog/presentation/widgets/product_image.dart

| Név | Mi ez | Leírás |
|---|---|---|
| `ProductImage` | `ConsumerWidget` | A termék képe: a fotó (az appba csomagolt eszköz), vagy a fotó nélküli terméknél kategória-ikonos színes csempe. A csempe a fotó dekódolása közben is látszik. Az ikon a termék **kategóriájáé** (az `iconKey` alapján keresi ki a `categoriesProvider`-ből; amíg a kategóriák nincsenek betöltve, az általános ikon) |
| `ProductImage.product` | mező | A termék |
| `ProductImage.width`, `ProductImage.height` | mezők | A kép mérete (alapból 84 x 84) |
| `ProductImage.iconSize` | mező | A csempe ikonjának mérete (alapból 34) |
| `ProductImage.borderRadius` | mező | A lekerekítés (alapból 14) |
| `ProductImage.assetFolder` | konstans | `assets/images/products` |
| `_Tile` | privát widget | A színes csempe: a termék azonosítójának karakterösszege dönt, hogy zöld vagy paradicsom árnyalatú (termékenként állandó) |
| `_Tile.product` | mező | A termék (a szín miatt) |
| `_Tile.iconKey` | mező | A kategória ikonkulcsa (üres: általános ikon) |
| `_Tile.iconSize` | mező | Az ikon mérete |

#### app/lib/features/catalog/presentation/widgets/product_sheet.dart

| Név | Mi ez | Leírás |
|---|---|---|
| `showProductSheet(context, product)` | függvény | Megnyitja a részletlapot a gyökér navigátoron, hogy az alsó navigációs sávot is eltakarja |
| `ProductSheet` | `ConsumerStatefulWidget` | A termék részletei: kép, név, vegetáriánus jel, leírás, allergének (chipek, vagy "nincs allergén"), az allergén-megjegyzés, a mennyiség és a "Kosárba" gomb az árral |
| `ProductSheet.product` | mező | A termék |
| `_ProductSheetState` | állapot | |
| `_quantity` | mező | A kosárba teendő mennyiség (1-ről indul) |

#### app/lib/features/catalog/presentation/widgets/kitchen_info_strip.dart

| Név | Mi ez | Leírás |
|---|---|---|
| `KitchenInfoStrip` | `ConsumerWidget` | A jelenlegi zóna feltételei egy sorban: várakozási idő, szállítási díj, minimális rendelés. Amíg a zóna nem töltődött be, üres |
| `_Meta` | privát widget | Egy ikon és felirat |
| `_Meta.icon`, `_Meta.label` | mezők | Az ikon és a felirat |

#### app/lib/features/catalog/presentation/image_credits_screen.dart

| Név | Mi ez | Leírás |
|---|---|---|
| `ImageCreditsScreen` | `ConsumerWidget` | A "Képek forrásai" képernyő: a bevezető után minden fotó a termék nevével, a címmel, a szerzővel és a licenccel |

### 4.6 Kosár (`lib/features/cart/`)

A kosár a kliensen él (termékazonosító → darabszám), és minden változásnál elmentődik, így az újratöltést túléli. **Árat nem tartalmaz**: a darabszámokból a szerver (`quote_cart`) számolja ki az árakat, a szállítási díjat és a minimális
rendelést, az app csak megjeleníti őket. Ha egy mentett kosárban olyan termék van, amelyet már nem árulnak, a szerver kihagyja az ajánlatból, a `cartPruningProvider` pedig kiveszi a kosárból is.

#### app/lib/features/cart/domain/cart_limits.dart

| Név | Mi ez | Leírás |
|---|---|---|
| `maxLineQuantity` | konstans | 99: egy termékből legfeljebb ennyi lehet egy kosárban. A szerver a fölötte lévő sort elutasítja (`invalid_lines`), ezért az app el sem engedi |

#### app/lib/features/cart/domain/cart_quote.dart

| Név | Mi ez | Leírás |
|---|---|---|
| `QuoteLine` | osztály | Az árazott kosár egy sora. Az árak az ajánlatéi, nem a termékéi: az étlap az árváltozás előtt is betöltődhetett |
| `QuoteLine.product` | mező | A termék (a kép és az allergének miatt) |
| `QuoteLine.quantity` | mező | A darabszám |
| `QuoteLine.unitPrice` | mező | Az egységár |
| `QuoteLine.total` | mező | A sor összege |
| `CartQuote` | osztály | Az árazott kosár. A `QuoteService` állítja elő (éles háttérrel a szerver); a kliens csak megjeleníti, saját végösszeget sosem számol hitelesen |
| `CartQuote.lines` | mező | A sorok |
| `CartQuote.subtotal` | mező | A részösszeg |
| `CartQuote.deliveryFee` | mező | A szállítási díj |
| `CartQuote.minOrder` | mező | A legkisebb rendelési érték |
| `CartQuote.freeDeliveryFrom` | mező | Ettől ingyenes a szállítás; `null`, ha soha |
| `CartQuote.estimated` | mező | Igaz, amíg nincs cím: a feltételek az alapértelmezett zónáéi, és változhatnak |
| `CartQuote.total` | getter | Részösszeg + szállítási díj |
| `CartQuote.isEmpty` | getter | Nincs sor |
| `CartQuote.itemCount` | getter | A darabszámok összege |
| `CartQuote.minOrderShortfall` | getter | Mennyi hiányzik a minimumhoz (nulla, ha megvan) |
| `CartQuote.meetsMinOrder` | getter | Eléri-e a minimumot |
| `CartQuote.remainingForFreeDelivery` | getter | Mennyivel kell többet rendelni az ingyenes szállításhoz; `null`, ha már ingyenes vagy soha nem az |

#### app/lib/features/cart/domain/cart_store.dart

| Név | Mi ez | Leírás |
|---|---|---|
| `CartStore` | interfész | Hol őrződik a kosár a látogatások között |
| `CartStore.load()` | metódus | A mentett kosár (termékazonosító → darabszám); üres, ha nincs |
| `CartStore.save(lines)` | metódus | Elmenti a kosarat |
| `MemoryCartStore` | osztály | Semmit sem őriz meg az újraindításon át; tesztekhez és alapértelmezésként |
| `MemoryCartStore._lines` | mező | A memóriabeli kosár |

#### app/lib/features/cart/domain/quote_service.dart

| Név | Mi ez | Leírás |
|---|---|---|
| `OutOfDeliveryAreaException` | kivétel | A cím nincs a szállítási területen |
| `OutOfDeliveryAreaException.postalCode` | mező | A kiszolgálhatatlan irányítószám |
| `UnknownProductException` | kivétel | A szerver olyan terméket árazott, amelyet az app nem ismer (az eszközön lévő étlap régebbi, mint a szerveré). Az étlap újratöltése megoldja |
| `UnknownProductException.productId` | mező | A termék azonosítója |
| `QuoteService` | interfész | A kosár árazója |
| `QuoteService.quote(lines:, postalCode:)` | metódus | Árazza a sorokat. Irányítószám nélkül az alapértelmezett zónát feltételezi, és az ajánlatot becsültnek jelöli; ha az irányítószám nincs kiszolgálva, `OutOfDeliveryAreaException` |

#### app/lib/features/cart/data/in_memory_quote_service.dart

| Név | Mi ez | Leírás |
|---|---|---|
| `InMemoryQuoteService` | osztály | Azt teszi, amit a szerveroldali árazó függvény; tesztdupla és szerver nélküli futtatás. A hiányzó terméket kihagyja, az ingyenes szállítás küszöbét és a díjat a zóna szerint alkalmazza |
| `catalog` | mező | Az étlap-forrás |
| `zones` | mező | A zóna-forrás |
| `quote(lines:, postalCode:)` | metódus | Az interfész szerint |

#### app/lib/features/cart/data/shared_preferences_cart_store.dart

| Név | Mi ez | Leírás |
|---|---|---|
| `SharedPreferencesCartStore` | osztály | A kosár a böngésző helyi tárhelyén (web) vagy az app beállításaiban. Csak termékazonosítót és darabszámot őriz, árat soha. Betöltéskor csak azt veszi át, aminek értelme van (a tárhely tartalma régi, szerkesztett vagy hibás lehet): egész, legalább 1 darabszám, legfeljebb a `maxLineQuantity`; hibás JSON-ra üres kosár |
| `_preferences` | mező | A `SharedPreferences` |
| `key` | konstans | `zaba.cart.v1` |
| `load()`, `save(lines)` | metódusok | Az interfész szerint; üres kosárnál a kulcsot törli |

#### app/lib/features/cart/data/supabase_quote_service.dart

| Név | Mi ez | Leírás |
|---|---|---|
| `SupabaseQuoteService` | osztály | A kosarat a szerveren árazza (`quote_cart`): az árak, a szállítási díj és a minimum mind onnan jönnek |
| `_client` | mező | A `SupabaseClient` |
| `loadProducts` | mező | Az étlap betöltője, hogy az árazott sorok mellett fotó és allergén legyen |
| `quote(lines:, postalCode:)` | metódus | Meghívja a `quote_cart`-ot; az `out_of_delivery_area` hibakódot `OutOfDeliveryAreaException`-ná alakítja, mást továbbdob |
| `cartQuoteFromJson(json, products)` | függvény | A szerver válaszából `CartQuote`; ismeretlen termékre `UnknownProductException` |
| `_lineFromJson(line, products)` | privát függvény | Egy sor a válaszból |

#### app/lib/features/cart/application/cart_providers.dart

| Név | Mi ez | Leírás |
|---|---|---|
| `quoteServiceProvider` | szolgáltató | Alapból a memóriabeli árazó; a `main.dart` cseréli |
| `cartStoreProvider` | szolgáltató | Hol éli túl a kosár az újratöltést. Alapból sehol (`MemoryCartStore`); a `main.dart` a böngésző vagy az eszköz tárhelyét adja |
| `CartNotifier` | `Notifier<Map<String, int>>` | A kosár tartalma. Minden változás elmentődik |
| `CartNotifier._store` | getter | A `cartStoreProvider` tára |
| `CartNotifier._update(lines)` | metódus | Új állapot és mentés |
| `CartNotifier.add(productId, {quantity})` | metódus | Hozzáad (legfeljebb `maxLineQuantity`-ig); nem pozitív mennyiséget figyelmen kívül hagy |
| `CartNotifier.increment(productId)` | metódus | Eggyel többet |
| `CartNotifier.decrement(productId)` | metódus | Eggyel kevesebbet; nullánál törli a sort |
| `CartNotifier.remove(productId)` | metódus | Törli a sort |
| `CartNotifier.retainOnly(productIds)` | metódus | Eldobja azoknak a termékeknek a sorait, amelyek nincsenek a halmazban |
| `CartNotifier.clear()` | metódus | Kiüríti a kosarat |
| `cartProvider` | szolgáltató | A fenti notifier |
| `cartItemCountProvider` | szolgáltató | A darabszámok összege (a jelvényhez és az üres-kosár döntéshez) |
| `cartQuoteProvider` | szolgáltató | Az árazott kosár: a kosár és a választott cím irányítószáma alapján kérdezi a `QuoteService`-t |
| `reloadCartQuote(ref)` | függvény | Hiba után újratölti az étlapot és az árazást |
| `cartPruningProvider` | szolgáltató | Kiveszi a kosárból azokat a termékeket, amelyeket a szerver az ajánlatban kihagyott. A gyökérben figyeli az `app.dart`; üres kosárnál a szervertől semmit sem kérdez |

#### app/lib/features/cart/presentation/cart_screen.dart

| Név | Mi ez | Leírás |
|---|---|---|
| `CartScreen` | `ConsumerWidget` | A Kosár fül. Üres kosárnál üres állapot ("Az étlaphoz" gombbal); egyébként az árazott sorok, az ingyenes szállítás csíkja, az összesítő és a megjegyzések. **Az üres kosarat nem árazza** |
| `_CartLineTile` | privát widget | Egy sor: kép, név, sor-összeg és a darabszám-választó |
| `_CartLineTile.line` | mező | A `QuoteLine` |
| `_FreeDeliveryHint` | privát widget | "Még X Ft az ingyenes szállításig" és egy folyamatjelző |
| `_FreeDeliveryHint.quote`, `_FreeDeliveryHint.remaining` | mezők | Az ajánlat és a hiányzó összeg |
| `_CheckoutBar` | privát widget | Az alsó sáv: a minimumhoz hiányzó összeg (ha van) és a "Tovább a fizetéshez" gomb az összeggel; a minimum alatt letiltva |
| `_CheckoutBar.quote` | mező | Az ajánlat |

#### app/lib/features/cart/presentation/widgets/cart_bar.dart

| Név | Mi ez | Leírás |
|---|---|---|
| `CartBar` | `ConsumerWidget` | Az étlap alján a "Kosár megtekintése" sáv a darabszámmal és a részösszeggel; üres kosárnál rejtett |

#### app/lib/features/cart/presentation/widgets/price_summary.dart

| Név | Mi ez | Leírás |
|---|---|---|
| `PriceSummary` | `StatelessWidget` | Részösszeg, szállítási díj ("Ingyenes", ha nulla) és végösszeg. Minden ár bruttó (az ÁFÁ-val) |
| `PriceSummary.subtotal`, `PriceSummary.deliveryFee` | mezők | A két összeg |
| `_Row` | privát widget | Egy sor: felirat balra, érték jobbra, táblázatos számjegyekkel |
| `_Row.label`, `_Row.value`, `_Row.style` | mezők | A felirat, az érték és a stílus |

### 4.7 Pénztár (`lib/features/checkout/`)

#### app/lib/features/checkout/presentation/checkout_screen.dart

A rendelés leadása: cím, idősáv, megjegyzés, fizetési mód (csak kártya, demó), összegzés. Az **árat a szerver számolja újra** a rendelés felvételekor; a képernyő csak azt mutatja, amit az árazás adott.

| Név | Mi ez | Leírás |
|---|---|---|
| `CheckoutScreen` | `ConsumerStatefulWidget` | A pénztár képernyő. Üres vagy árazás nélküli kosárnál betöltés-, hiba- vagy üres nézet. A gomb csak akkor aktív, ha van cím, van idősáv, a kosár eléri a minimumot és nincs folyamatban küldés |
| `_CheckoutScreenState` | állapot | |
| `_note` | mező | A megjegyzés mező vezérlője |
| `_idempotencyKey` | mező | **Egy kulcs a képernyő egy látogatásához** (idő + 30 bites titkos véletlen szám). A "Leadás" kétszeri megérintése, vagy az elveszett válasz utáni újrapróbálás így sosem hoz létre két rendelést: ugyanarra a kulcsra a szerver ugyanazt a rendelést adja vissza |
| `_chosenDay`, `_chosenSlot` | mezők | A választott nap és idősáv; ha nincs (vagy már nem elérhető), az első foglalható |
| `_submitting` | mező | Folyamatban van a küldés |
| `_error` | mező | A legutóbbi leadás hibaüzenete |
| `dispose()` | metódus | A vezérlő felszabadítása |
| `_placeOrder(address, slot)` | metódus | Leadja a rendelést. Siker után a fizetés képernyő **cseréli** a pénztárat (hogy ne villanjon fel üres kosár), és kiüríti a kosarat. `OrderRejectedException` esetén az ok szerinti magyar üzenet (az idősáv-ütközésnél az idősávok újratöltésével, a túl sok kifizetetlen rendelésnél a lemondásra vagy fizetésre biztatással). **Bármilyen más hibára** (hálózat, szerver, olvashatatlan válasz) az általános üzenet, és a gomb újra használható: semmi sem jött létre, vagy ha a válasz veszett el, ugyanaz a kulcs a következő próbánál visszaadja a rendelést |
| `_Section` | privát widget | Címmel ellátott szakasz |
| `_Section.title`, `_Section.child` | mezők | A cím és a tartalom |
| `_SlotPicker` | privát widget | A napok és az idősávok választó-chipjei ("Ma", "Holnap", majd a hét napja és a dátum) |
| `_SlotPicker.days` | mező | A foglalható napok |
| `_SlotPicker.selectedDay`, `_SlotPicker.selectedSlot` | mezők | A kijelölt nap és sáv |
| `_SlotPicker.onDay`, `_SlotPicker.onSlot` | mezők | A választás visszahívásai |
| `_SlotPicker._dayLabel(l10n, date, now)` | metódus | A nap felirata |
| `_SummaryCard` | privát widget | A tételek (darab x név, sor-összeg), az összesítő és az ÁFA-megjegyzés |
| `_SummaryCard.quote` | mező | Az ajánlat |
| `_PlaceOrderBar` | privát widget | Az alsó sáv: a hibaüzenet (vagy a minimumhoz hiányzó összeg) és a "Rendelés leadása" gomb az összeggel; küldés közben forgó jelzővel |
| `_PlaceOrderBar.quote`, `error`, `submitting`, `onPressed` | mezők | Az ajánlat, az üzenet, a küldés állapota és a gomb művelete (`null`: letiltva) |

### 4.8 Rendelések (`lib/features/orders/`)

A rendelést a szerver hozza létre és változtatja (`place_order`, `cancel_order`, a fizetési webhook, az admin függvények); az app olvassa (a sorszintű jogosultság miatt a vásárló csak a sajátjait látja) és élőben követi (`liveQuery`).

#### app/lib/features/orders/domain/order_status.dart

| Név | Mi ez | Leírás |
|---|---|---|
| `OrderStatus` | enum | A rendelés állapota: `pendingPayment` (fizetésre vár; a konyha a fizetés után kezd), `received`, `preparing`, `outForDelivery`, `delivered`, `cancelled` |
| `OrderStatus.timeline` | konstans | A fizetés utáni "boldog út" sorrendben: fogadva, készül, úton, kiszállítva. Ez hajtja az idővonalat |
| `OrderStatus.next` | getter | A boldog út következő lépése; `null`, ha nincs |
| `OrderStatus.isActive` | getter | Még folyamatban van (nem szállították ki és nem mondták le) |
| `OrderStatus.customerCanCancel` | getter | A vásárló a konyha indulásáig mondhat le (`pendingPayment`, `received`). A szerver ugyanezt érvényesíti; ez csak a gomb felkínálásáról dönt |

#### app/lib/features/orders/domain/order.dart

| Név | Mi ez | Leírás |
|---|---|---|
| `PaymentStatus` | enum | A fizetés állapota: `pending`, `succeeded`, `failed`, `cancelled`, `refunded` |
| `OrderLine` | osztály | A rendelés egy sora: **pillanatkép**, az étlap későbbi változása nem módosítja |
| `OrderLine.productId`, `name`, `quantity`, `unitPrice` | mezők | A termék azonosítója, neve, a darabszám és az egységár a rendelés pillanatában |
| `OrderLine.total` | getter | Egységár x darabszám |
| `Order` | osztály | A rendelés |
| `Order.id` | mező | Azonosító |
| `Order.number` | mező | Az ember számára olvasható szám, pl. `ZB-1001` |
| `Order.placedAt` | mező | A leadás ideje |
| `Order.lines` | mező | A sorok |
| `Order.subtotal`, `Order.deliveryFee` | mezők | A részösszeg és a szállítási díj |
| `Order.address` | mező | A szállítási cím |
| `Order.slot` | mező | A lefoglalt szállítási idősáv |
| `Order.note` | mező | A vásárló megjegyzése |
| `Order.status`, `Order.paymentStatus` | mezők | A rendelés és a fizetés állapota |
| `Order.total` | getter | Részösszeg + szállítási díj |
| `Order.itemCount` | getter | A darabszámok összege |
| `Order.copyWith({status, paymentStatus})` | metódus | Másolat más állapottal |

#### app/lib/features/orders/domain/order_repository.dart

| Név | Mi ez | Leírás |
|---|---|---|
| `PlaceOrderRequest` | osztály | A rendelésfelvétel kérése |
| `PlaceOrderRequest.idempotencyKey` | mező | Egy kulcs egy pénztár-kísérlethez: ugyanaz a kérés újra elküldve (dupla érintés, elveszett válasz utáni újrapróba) ugyanazt a rendelést adja vissza |
| `PlaceOrderRequest.lines` | mező | Termékazonosító → darabszám |
| `PlaceOrderRequest.address`, `slot`, `note` | mezők | A cím, az idősáv és a megjegyzés |
| `maxUnpaidOrders` | konstans | 5: ennyi fizetésre váró rendelése lehet egy vásárlónak. Az idősáv helyét a rendelés felvételekor, a fizetés előtt foglaljuk le, ezért korlátozott (az adatbázis ugyanezt a határt érvényesíti, és a túl régen kifizetetlen rendeléseket lemondja) |
| `OrderRejection` | enum | Miért utasította el a szerver a rendelést: `emptyCart`, `outOfDeliveryArea`, `belowMinimumOrder`, `slotUnavailable`, `tooManyUnpaidOrders` |
| `OrderRejectedException` | kivétel | A rendelés elutasítva |
| `OrderRejectedException.reason` | mező | Az ok |
| `OrderNotCancellableException` | kivétel | A rendelés már nem mondható le (a konyha elkezdte) |
| `OrderNotCancellableException.status` | mező | Az állapot, amelyben a rendelés van |
| `InvalidOrderTransitionException` | kivétel | Az állapotgép nem engedi ezt a lépést |
| `InvalidOrderTransitionException.from`, `to` | mezők | Honnan, hová |
| `OrderRepository` | interfész | Amit a vásárlói app tehet a rendelésekkel |
| `OrderRepository.placeOrder(request)` | metódus | Újraárazza a kosarat, ellenőrzi a területet, a minimumot és az idősávot, és fizetésre váró rendelést hoz létre; `OrderRejectedException`-t dob |
| `OrderRepository.findOrder(id)` | metódus | Egy rendelés vagy `null` |
| `OrderRepository.watchOrders()` | metódus | A vásárló rendelései, újak elöl; minden változásra újra ad |
| `OrderRepository.watchOrder(id)` | metódus | Egy rendelés változásai |
| `OrderRepository.cancelOrder(id)` | metódus | Lemondás; a konyha indulása után `OrderNotCancellableException` |
| `OrderAdmin` | interfész | Amit az üzemeltető tehet; éles háttérrel ez az admin API |
| `OrderAdmin.setStatus(id, status)` | metódus | Állapotot vált; az állapotgép által nem engedett lépésre `InvalidOrderTransitionException`. Kézzel nem lehet "fogadva" állapotba tenni: azt csak fizetési esemény teheti |

#### app/lib/features/orders/data/order_status_codes.dart

| Név | Mi ez | Leírás |
|---|---|---|
| `_codes` | privát térkép | Az adatbázis szava minden állapothoz (`pending_payment`, `received`, `preparing`, `out_for_delivery`, `delivered`, `cancelled`). Az egyetlen hely, ahol ezeket ismerjük: a vásárló rendelései és az admin oldal is ezt használja |
| `orderStatusCode(status)` | függvény | Az állapot adatbázis-szava |
| `orderStatusFromCode(code)` | függvény | A szóhoz tartozó állapot; ismeretlen szóra `null` (a hívó dönti el, hogy ez hiba: egy kifizetett rendelés rossz állapotának mutatása rosszabb volna) |

#### app/lib/features/orders/data/in_memory_order_store.dart

| Név | Mi ez | Leírás |
|---|---|---|
| `_operatorTransitions` | privát térkép | Az üzemeltető által megtehető lépések; a szerver átmenet-táblájának tükre. A `received`-be vezető lépés szándékosan hiányzik: azt csak fizetési esemény teheti |
| `InMemoryOrderStore` | osztály | A demóban ez játssza a szervert: ellenőrzi és tárolja a rendeléseket, egyszer alkalmazza a fizetési eseményeket, érvényesíti az állapotgépet. Egyszerre `OrderRepository`, `OrderAdmin` és `PaymentEventSink`. Tesztdupla marad az éles háttér mellett is |
| `quoteService`, `slotService`, `clock` | mezők | Az árazó, az idősáv-szolgáltatás és az óra |
| `_orders` | mező | Azonosító szerinti rendelések |
| `_idByKey` | mező | Idempotencia-kulcs → rendelés azonosítója |
| `_seenEvents` | mező | A már alkalmazott fizetési események azonosítói |
| `_changes` | mező | Változásjelző (broadcast, szinkron) |
| `_counter` | mező | A rendelésszám számlálója (1000-ről indul, `ZB-1001` az első) |
| `_snapshot()` | metódus | A rendelések listája, újak elöl |
| `_put(order)` | metódus | Elmenti a rendelést és jelez |
| `placeOrder` | metódus | Az idempotens felvétel: ismert kulcsra a régi rendelést adja; a kifizetetlenek korlátján (`maxUnpaidOrders`) elutasít; árazás, terület, minimum, idősáv ellenőrzése; a versenyhelyzetet (a dupla érintés két hívása) a várakozás utáni újabb kulcs-ellenőrzés fogja meg |
| `findOrder`, `watchOrders`, `watchOrder` | metódusok | Olvasás és követés |
| `cancelOrder(id)` | metódus | Lemondás, ha az állapot engedi |
| `_cancel(order)` | metódus | Lemondott állapotba teszi; a kifizetett rendelést azonnal "visszatérítve" jelöli (demó) |
| `setStatus(id, status)` | metódus | Az üzemeltető lépése az átmenet-tábla szerint |
| `apply(event)` | metódus | Fizetési esemény: azonosító szerint egyszer. Csak a fizetésre váró rendelést érinti; a sikeres esemény "fogadva", a sikertelen és a megszakított csak a fizetés állapotát állítja |

#### app/lib/features/orders/data/supabase_order_repository.dart

| Név | Mi ez | Leírás |
|---|---|---|
| `SupabaseOrderRepository` | osztály | A vásárló rendelései a Supabase-en. Rendelést csak adatbázis-függvények (`place_order`, `cancel_order`) és a fizetési webhook hoz létre és változtat |
| `_client` | mező | A `SupabaseClient` |
| `placeOrder` | metódus | Meghívja a `place_order`-t; a szerver hibakódjait `OrderRejectedException`-né alakítja (`_rejections`), a többit továbbdobja. A létrejött rendelést utána beolvassa |
| `_rejections` | konstans | A szerver hibakód → `OrderRejection` megfeleltetés (`empty_cart`, `out_of_delivery_area`, `below_minimum_order`, `slot_unavailable`, `too_many_unpaid_orders`) |
| `findOrder(id)` | metódus | Egy rendelés a sorszintű jogosultsággal |
| `watchOrders()` | metódus | `liveQuery` az `orders` táblán, a legutóbbi 50 rendelés újak elöl |
| `watchOrder(id)` | metódus | `liveQuery` egy rendelésre, az `id`-re szűrt Realtime-feliratkozással |
| `cancelOrder(id)` | metódus | Meghívja a `cancel_order`-t; `invalid_transition` esetén beolvassa a rendelést, és `OrderNotCancellableException`-t dob az állapotával |
| `orderSelectColumns` | konstans | A rendelés oszlopai a sorokkal és az idősávval együtt (az admin oldal is ezt olvassa) |
| `_paymentStatuses` | konstans | A fizetés állapotának szava → `PaymentStatus` |
| `orderFromRow(row)` | függvény | Adatbázissor → `Order` (a sorok azonosító szerint). Ismeretlen állapotra vagy hiányzó idősávra `FormatException`: tévedés helyett hiba |

#### app/lib/features/orders/application/order_providers.dart

| Név | Mi ez | Leírás |
|---|---|---|
| `orderStoreProvider` | szolgáltató | A memóriabeli tár: a demóban egy példány játssza a szervert (vásárlói app, üzemeltetői lépések, fizetési események) |
| `orderRepositoryProvider` | szolgáltató | A `OrderRepository`; a `main.dart` a Supabase-osra cseréli |
| `orderAdminProvider` | szolgáltató | Az `OrderAdmin` (a memóriabeli tár) |
| `paymentEventSinkProvider` | szolgáltató | A fizetési események fogadója (a memóriabeli tár) |
| `kitchenSimulationProvider` | szolgáltató | Kínál-e a rendelés-képernyő "Következő állapot (demó)" gombot a konyha helyett. Csak a szerver nélküli demóban van; háttérrel a konyha az admin oldal |
| `ordersProvider` | szolgáltató | A vásárló rendelései, újak elöl. A bejelentkezettől függ: más felhasználó ugyanazon az eszközön nem látja az előzőét, a vendég pedig semmit sem kérdez a szervertől |
| `orderProvider` | családszolgáltató | Egy rendelés azonosító szerint, ugyanezekkel a szabályokkal |

#### app/lib/features/orders/presentation/order_labels.dart

| Név | Mi ez | Leírás |
|---|---|---|
| `OrderStatusPresentation` | kiterjesztés az `OrderStatus`-on | A megjelenítési részletek |
| `OrderStatusPresentation.title(l10n)` | metódus | Az állapot magyar neve |
| `OrderStatusPresentation.subtitle(l10n)` | metódus | Az állapot magyarázó szövege |
| `OrderStatusPresentation.icon` | getter | Az állapot ikonja |
| `OrderStatusPresentation.colors` | getter | A chip és a kártya háttér- és előtérszíne (a fizetésre váró piros, a lemondott szürke, a többi zöld) |
| `PaymentStatusLabel` | kiterjesztés a `PaymentStatus`-on | |
| `PaymentStatusLabel.label(l10n)` | metódus | A fizetési állapot magyar neve |

#### app/lib/features/orders/presentation/widgets/order_status_chip.dart

| Név | Mi ez | Leírás |
|---|---|---|
| `OrderStatusChip` | `StatelessWidget` | Kerek címke az állapot ikonjával és nevével |
| `OrderStatusChip.status` | mező | Az állapot |

#### app/lib/features/orders/presentation/orders_screen.dart

| Név | Mi ez | Leírás |
|---|---|---|
| `OrdersScreen` | `ConsumerWidget` | A Rendeléseim fül. Vendégnek belépési felkérés; bejelentkezettnek a lista (üres állapottal), az értesítések csengőjével és az olvasatlanok jelvényével |
| `_OrderCard` | privát widget | Egy rendelés kártyája: szám, dátum, idő, darabszám, állapot-chip és végösszeg; érintésre a rendelés oldala |
| `_OrderCard.order` | mező | A rendelés |

#### app/lib/features/orders/presentation/order_tracking_screen.dart

| Név | Mi ez | Leírás |
|---|---|---|
| `OrderTrackingScreen` | `ConsumerWidget` | Egy rendelés oldala élő állapottal: állapotkártya, fizetésre váró rendelésnél a "Fizetés" kártya, a fizetett rendelés idővonala, a kiszállítási ablak, a demó-"következő állapot" gomb, a lemondás és az összegzés |
| `OrderTrackingScreen.orderId` | mező | A rendelés azonosítója |
| `OrderTrackingScreen._confirmCancel(context, ref, order)` | metódus | Megerősítés után lemond. Ha a konyha közben elkezdte (`OrderNotCancellableException`), ezt közli egy üzenetsávban; bármi más hibára azt, hogy próbálja újra: a lemondás sosem marad némán sikertelen |
| `_StatusCard` | privát widget | Az állapot színes kártyája folyamatjelzővel |
| `_StatusCard.order` | mező | A rendelés |
| `_PayCard` | privát widget | "A rendelés még nem fizetett" és a fizetés gombja |
| `_PayCard.order` | mező | A rendelés |
| `_DeliveryWindow` | privát widget | "Kiszállítás: dátum időablak" |
| `_DeliveryWindow.order` | mező | A rendelés |
| `_TimelineRow` | privát widget | Az idővonal egy lépése |
| `_TimelineRow.status` | mező | A lépés állapota |
| `_TimelineRow.reached` | mező | Elérte-e már a rendelés |
| `_TimelineRow.current` | mező | Ez a jelenlegi lépés (félkövér) |
| `_TimelineRow.last` | mező | Az utolsó lépés (utána nincs összekötő vonal) |
| `_SummaryCard` | privát widget | A tételek, az összesítő, a cím, az idősáv, a fizetés és a megjegyzés |
| `_SummaryCard.order` | mező | A rendelés |

### 4.9 Fizetés (`lib/features/payment/`)

A fizetés a demóban **hamis szolgáltatóval** történik, de a szabály ugyanaz, mint éles szolgáltatóval lenne: **az app sosem jelölhet kifizetettnek rendelést**. Az app csak a kártyalépés kimenetét közli; a rendelést kizárólag a szolgáltató aláírt eseménye
(webhook) változtatja. A kártyaadat a képernyő űrlapján marad, a háttérhez sosem jut el. A teljes folyamatot a [`payment-flow.md`](payment-flow.md) rajzolja le.

#### app/lib/features/payment/domain/card_outcome.dart

| Név | Mi ez | Leírás |
|---|---|---|
| `CardOutcome` | enum | Hogyan ért véget a (hamis) kártyalépés: `approved`, `declined`, `cancelled`. Csak ez megy a háttérnek, a kártyaadat nem |

#### app/lib/features/payment/domain/card_validation.dart

| Név | Mi ez | Leírás |
|---|---|---|
| `declinedTestCard` | konstans | `4000000000000002`: az az egy tesztkártya, amelyet a hamis szolgáltató elutasít |
| `isValidCardNumber(digits)` | függvény | Luhn-ellenőrzés 13-19 számjegyre |
| `isValidExpiry(text, now)` | függvény | `HH/ÉÉ`, valódi hónap, nem a múltban (a kártya a hónap végéig érvényes) |
| `isValidCvc(text)` | függvény | Pontosan három számjegy |
| `outcomeForCardNumber(digits)` | függvény | A hamis szolgáltató minden érvényes kártyát elfogad, kivéve a `declinedTestCard`-ot |

#### app/lib/features/payment/domain/payment_event.dart

| Név | Mi ez | Leírás |
|---|---|---|
| `PaymentEventType` | enum | `succeeded`, `failed`, `cancelled` |
| `PaymentEvent` | osztály | Amit a fizetési szolgáltató a fizetési kísérletről jelent. Éles háttérrel aláírt webhookként érkezik; ez az **egyetlen**, ami kifizetetté tehet egy rendelést |
| `PaymentEvent.id` | mező | Eseményenként egyedi; a szolgáltató ugyanazt az eseményt többször is kézbesítheti |
| `PaymentEvent.orderId`, `PaymentEvent.type` | mezők | Melyik rendelésről és mi történt |
| `PaymentEventSink` | interfész | Az események fogadója |
| `PaymentEventSink.apply(event)` | metódus | Pontosan egyszer alkalmazza: ugyanazon `id` ismételt kézbesítése nem változtat semmit |

#### app/lib/features/payment/domain/payment_service.dart

| Név | Mi ez | Leírás |
|---|---|---|
| `PaymentService` | interfész | A fizetés a vásárlói app oldaláról |
| `PaymentService.submit(orderId:, outcome:)` | metódus | Jelenti a kártyalépés kimenetét a rendelésre, és visszaadja a fizetési állapotot, amelyben a rendelés kikötött. Magát a rendelést csak a szolgáltató eseménye változtatja |
| `PaymentUnavailableException` | kivétel | A fizetést nem lehetett elindítani vagy jelenteni (hálózat, szerver). A rendelés érintetlen: tovább vár a fizetésre, újra fizethető |
| `PaymentUnavailableException.cause` | mező | Az eredeti hiba |

#### app/lib/features/payment/data/fake_payment_service.dart

| Név | Mi ez | Leírás |
|---|---|---|
| `FakePaymentService` | osztály | Kártyaszolgáltatót helyettesít a szerver nélküli demóban: kártyaadatot sosem lát, átveszi a kártyalépés kimenetét, és fizetési eseményként jelenti a rendelés-tárnak, ahogy egy szolgáltató webhookja tenné |
| `sink` | mező | Az eseményfogadó |
| `orders` | mező | A rendelések (az eredmény visszaolvasásához) |
| `processingDelay` | mező | A szolgáltató feldolgozási idejének szimulációja (alapból 1,2 mp; a tesztekben nulla) |
| `_eventCounter` | mező | Az eseményazonosítók számlálója |
| `submit` | metódus | Vár, eseményt képez a kimenetből, alkalmazza, és visszaolvassa a fizetési állapotot |

#### app/lib/features/payment/data/supabase_payment_service.dart

| Név | Mi ez | Leírás |
|---|---|---|
| `SupabasePaymentService` | osztály | Az Edge Function-ökön át fizet. A `payments-create` bejelentkezett vásárlóként indítja a fizetési kísérletet és munkamenetet nyit; a hamis szolgáltató oldala (`fake-provider-confirm`) megkapja a kártyalépés kimenetét, és a háttere aláírt eseményt küld a webhooknak. Csak az az esemény tehet kifizetetté egy rendelést: ez az osztály sosem ír rendelést, csak visszaolvassa az eredményt |
| `_client` | mező | A `SupabaseClient` |
| `orders` | mező | A rendelések (az eredmény visszaolvasásához) |
| `processingDelay` | mező | Szimulált feldolgozási idő |
| `submit` | metódus | A fenti két hívás, majd az állapot visszaolvasása. **Minden hibát** (függvényhiba, adatbázishiba, hálózat, olvashatatlan válasz) `PaymentUnavailableException`-né alakít |

#### app/lib/features/payment/application/payment_providers.dart

| Név | Mi ez | Leírás |
|---|---|---|
| `paymentProcessingDelayProvider` | szolgáltató | Mennyi ideig "dolgozik" a hamis szolgáltató (1,2 mp); a tesztek nullára állítják |
| `paymentServiceProvider` | szolgáltató | Alapból a `FakePaymentService`; a `main.dart` a `SupabasePaymentService`-re cseréli |

#### app/lib/features/payment/presentation/card_input_formatters.dart

| Név | Mi ez | Leírás |
|---|---|---|
| `_digitsOnly(text)` | privát függvény | Csak a számjegyek |
| `_atEnd(text)` | privát függvény | A szöveg, a kurzor a végén |
| `CardNumberFormatter` | `TextInputFormatter` | Csak számjegy, négyes csoportokban: `4242 4242 4242 4242` |
| `CardNumberFormatter.maxDigits` | konstans | 19 |
| `CardNumberFormatter.formatEditUpdate(oldValue, newValue)` | metódus | A beírt szöveget négyes csoportokra alakítja, legfeljebb 19 számjeggyel, a kurzort a végére teszi |
| `ExpiryFormatter` | `TextInputFormatter` | Csak számjegy, a hónap után automatikus perjellel: `12/27` |
| `ExpiryFormatter.formatEditUpdate(oldValue, newValue)` | metódus | Legfeljebb négy számjegy, a perjelet a hónap után beteszi, a kurzort a végére |

#### app/lib/features/payment/presentation/payment_screen.dart

| Név | Mi ez | Leírás |
|---|---|---|
| `PaymentScreen` | `ConsumerStatefulWidget` | A (hamis) kártyás fizetés képernyője: az összeg és a rendelésszám, a tesztkártyák súgója, a kártyaűrlap, a biztonsági megjegyzés. Ha a rendelés már nem fizetésre váró, "nem fizethető" nézetet mutat |
| `PaymentScreen.orderId` | mező | A rendelés azonosítója |
| `_PaymentScreenState` | állapot | |
| `_formKey` | mező | Az űrlap kulcsa |
| `_number`, `_expiry`, `_cvc`, `_holder` | mezők | A kártyaszám, a lejárat, a biztonsági kód és a név vezérlői |
| `_processing` | mező | Folyamatban van a fizetés (a mezők, a gombok és a vissza gomb le vannak tiltva) |
| `_leaving` | mező | Kilépés előtt beállítva, hogy a képernyő ne villantsa fel a "nem fizethető" nézetet, miközben a most kifizetett rendelés állapota változik alatta |
| `_error` | mező | A hibaüzenet |
| `dispose()` | metódus | A vezérlők felszabadítása |
| `_openOrder()` | metódus | A rendelés oldalára lép |
| `_pay()` | metódus | Ellenőriz, kimenetet képez a kártyaszámból, jelenti. Siker esetén a rendelés oldalára lép; elutasításnál üzenet és a biztonsági kód törlése. **Bármilyen hibánál** (nem csak a `PaymentUnavailableException`-nél) az űrlap feloldódik, és "most nem sikerült elindítani" üzenet jelenik meg |
| `_cancel()` | metódus | "Mégse": megszakított kimenetet jelent (hiba esetén a rendelés egyszerűen tovább vár fizetésre), majd a rendelés oldalára lép |
| `_TestCardsHint` | privát widget | A demó tesztkártyáinak súgója (siker, elutasítás, egyéb). Valódi szolgáltatónál ez a képernyő lecserélődik |

### 4.10 Értesítések (`lib/features/notifications/`)

A demóban az értesítés az appon **belül** jelenik meg (sáv és lista), a rendelések állapotváltozásaiból. Az MVP ugyanezen interfész mögé tehet push- és e-mail-küldőt. Az értesítések az adott látogatáshoz tartoznak
(nem maradnak meg újratöltés után), és a bejelentkezetthez kötődnek: más felhasználó üresen indul.

#### app/lib/features/notifications/domain/app_notification.dart

| Név | Mi ez | Leírás |
|---|---|---|
| `AppNotification` | osztály | Üzenet a vásárlónak az egyik rendeléséről |
| `AppNotification.id` | mező | Egyedi azonosító (`<rendelés>-<sorszám>`) |
| `AppNotification.orderId`, `AppNotification.orderNumber` | mezők | A rendelés azonosítója és száma |
| `AppNotification.status` | mező | Az állapot, amelyet a rendelés épp elért |
| `AppNotification.refunded` | mező | Kifizetett, majd lemondott rendelés: az üzenet említi a visszatérítést |
| `AppNotification.createdAt` | mező | Mikor keletkezett |
| `NotificationSender` | interfész | Az értesítés kézbesítője |
| `NotificationSender.send(notification)` | metódus | Kézbesít egy értesítést |
| `OrderStatusChange` | osztály | Egy rendelés, amelynek az állapota megváltozott |
| `OrderStatusChange.order`, `OrderStatusChange.from` | mezők | A rendelés új állapotában, és a korábbi állapot |
| `statusChanges(previous, next)` | függvény | A `next` rendelései közül azok, amelyeknek az állapota eltér a `previous`-étól. Az először megjelenő rendelés nem változás (az új rendelés a vásárló saját tette), és `previous` nélkül (az első betöltésnél) semmi sem az: az első betöltés nem hír |

#### app/lib/features/notifications/application/notification_providers.dart

| Név | Mi ez | Leírás |
|---|---|---|
| `NotificationsState` | `@immutable` osztály | Az értesítések állapota |
| `NotificationsState.items` | mező | A lista, újak elöl |
| `NotificationsState.unread` | mező | Az olvasatlanok száma |
| `NotificationsState.banner` | mező | Az, amelyik épp a képernyő tetején látszik, ha van |
| `NotificationsNotifier` | `Notifier<NotificationsState>` | Az értesítések kezelője; a `build` a `sessionProvider`-t figyeli, így bejelentkezett-váltáskor üresen indul |
| `NotificationsNotifier._keep` | konstans | 30: ennyit őriz meg |
| `NotificationsNotifier.add(notification)` | metódus | Felvesz egy értesítést (az olvasatlanok száma nő, a sáv megjelenik) |
| `NotificationsNotifier.dismissBanner()` | metódus | Elrejti a sávot |
| `NotificationsNotifier.markAllRead()` | metódus | Mindet olvasottnak jelöli |
| `notificationsProvider` | szolgáltató | A fenti notifier |
| `InAppNotifier` | osztály | Az appon belül mutat értesítést: sávot és listabejegyzést |
| `InAppNotifier._notifications` | mező | A kezelő, amelynek átadja |
| `InAppNotifier.send(notification)` | metódus | Felveszi az értesítést a kezelőbe (`NotificationsNotifier.add`) |
| `notificationSenderProvider` | szolgáltató | Alapból az `InAppNotifier` |
| `orderNotificationsProvider` | szolgáltató | A rendelés állapotának minden változásából értesítést készít. A gyökérben figyeli az `app.dart`, így a változást bármelyik képernyőn észreveszi. Vendégnél nem csinál semmit |

#### app/lib/features/notifications/presentation/notification_labels.dart

| Név | Mi ez | Leírás |
|---|---|---|
| `AppNotificationText` | kiterjesztés az `AppNotification`-ön | |
| `AppNotificationText.title(l10n)` | metódus | Az értesítés címe az állapot szerint (a fizetésre váró állapotnál az állapot saját címe) |
| `AppNotificationText.body(l10n)` | metódus | A szöveg; lemondott, kifizetett rendelésnél a visszatérítést is említi |

#### app/lib/features/notifications/presentation/notification_banner.dart

| Név | Mi ez | Leírás |
|---|---|---|
| `NotificationBanner` | `ConsumerStatefulWidget` | A demó-szalag alatti sáv, amely egy rendelés változását jelenti be. Magától eltűnik néhány másodperc múlva; érintésre megnyílik a rendelés |
| `NotificationBanner.visibleFor` | mező | Meddig látszik (alapból 7 mp) |
| `_NotificationBannerState` | állapot | |
| `_timer` | mező | Az eltüntető időzítő |
| `dispose()` | metódus | Leállítja az időzítőt |
| `_show(notification)` | metódus | Új értesítésnél újraindítja az időzítőt |
| `_Strip` | privát widget | Maga a sáv: ikon, cím, "Rendelés ZB-1001 · szöveg", és egy bezáró gomb. Nincs súgószövege (tooltip): a sáv az app navigátora felett ül, ott nincs `Overlay`; a képernyőolvasónak felirat van rajta |
| `_Strip.notification` | mező | Az értesítés |

#### app/lib/features/notifications/presentation/notifications_screen.dart

| Név | Mi ez | Leírás |
|---|---|---|
| `NotificationsScreen` | `ConsumerStatefulWidget` | Az értesítések listája, újak elöl; a képernyő megnyitása olvasottnak jelöli őket. Üres állapottal és a demó-megjegyzéssel |
| `_NotificationsScreenState` | állapot | A `initState` az olvasottnak jelölést **nem az építés közben** végzi (különben építés közben változtatna állapotot) |

### 4.11 Admin oldal (`lib/features/admin/`)

A konyha és az üzem munkatársainak oldala, külön webes build (`lib/main_admin.dart`). **Nincs szerver nélküli módja**: két külön app nem oszthat memóriabeli rendeléseket. A jogosultságot az adatbázis érvényesíti (a rendeléseket csak a munkatárs
olvashatja, és minden változtatás az `admin_set_order_status` függvényen megy át, amely ellenőrzi a szerepkört és az állapotgépet, és az audit naplóba ír); az oldal csak azt kínálja fel, amit az adatbázis elfogadna.
Két szerepkör van: `operator` (rendeléseket kezel) és `admin` (az audit naplót is olvassa). Munkatársi fiókot nem lehet az oldalon regisztrálni: azt a `tool/create_staff_user.py` hozza létre.

#### app/lib/features/admin/domain/staff.dart

| Név | Mi ez | Leírás |
|---|---|---|
| `StaffRole` | enum | A munkatárs szerepköre: `admin`, `operator`. Az adatbázis érvényesíti, az app csak azt dönti el, mit mutasson |
| `StaffRole.fromCode(code)` | statikus metódus | A kódhoz (`admin`, `operator`) tartozó szerepkör; ismeretlen kódra `null` |

#### app/lib/features/admin/domain/order_history.dart

| Név | Mi ez | Leírás |
|---|---|---|
| `ChangeActor` | enum | Ki okozta az állapotváltást: `customer`, `operator`, `payment` |
| `StatusChange` | osztály | Egy rendelés előzményeinek egy sora |
| `StatusChange.from` | mező | A korábbi állapot; `null` az első bejegyzésnél, amikor a rendelést leadták |
| `StatusChange.to` | mező | Az új állapot |
| `StatusChange.actor` | mező | Ki változtatta |
| `StatusChange.at` | mező | Mikor |

#### app/lib/features/admin/domain/audit_entry.dart

| Név | Mi ez | Leírás |
|---|---|---|
| `AuditEntry` | osztály | Az audit napló egy sora: mit tett egy munkatárs (vagy a rendszer) |
| `AuditEntry.id` | mező | Sorszám |
| `AuditEntry.at` | mező | Mikor |
| `AuditEntry.action` | mező | A művelet, pl. `order.set_status` (a lejárati futásé `orders.expire_unpaid`) |
| `AuditEntry.entity`, `AuditEntry.entityId` | mezők | Mire vonatkozik (tábla és azonosító) |
| `AuditEntry.actorId` | mező | Ki csinálta; `null` a rendszer (pl. a lejárati futás) |
| `AuditEntry.details` | mező | A részletek (JSON) |
| `AuditEntry.fromStatus`, `AuditEntry.toStatus` | mezők | Állapotváltásnál a megtett lépés |

#### app/lib/features/admin/domain/admin_repository.dart

| Név | Mi ez | Leírás |
|---|---|---|
| `StaffOnlyException` | kivétel | A bejelentkezett nem munkatárs, ezt nem teheti |
| `AdminRepository` | interfész | Amit az admin oldal tehet. Az olvasást és minden változtatást az adatbázis a munkatársakra korlátozza |
| `AdminRepository.currentRole()` | metódus | A bejelentkezett szerepköre, vagy `null`, ha nem munkatárs |
| `AdminRepository.watchOrders()` | metódus | Minden rendelés, újak elöl; minden változásra újra ad |
| `AdminRepository.watchOrder(id)` | metódus | Egy rendelés változásai |
| `AdminRepository.watchHistory(orderId)` | metódus | Egy rendelés előzményei |
| `AdminRepository.operatorTransitions()` | metódus | Az üzemeltető által megtehető lépések az adatbázis állapotgépe szerint: állapot → az utána következő állapotok |
| `AdminRepository.setStatus(orderId, status)` | metódus | Állapotot vált; nem engedett lépésre `InvalidOrderTransitionException`, nem munkatársra `StaffOnlyException` |
| `AdminRepository.auditLog({limit})` | metódus | Az audit napló, újak elöl. Csak az `admin` olvashatja |

#### app/lib/features/admin/data/supabase_admin_repository.dart

| Név | Mi ez | Leírás |
|---|---|---|
| `SupabaseAdminRepository` | osztály | Az admin oldal nézete a Supabase-en. A sorszintű jogosultság miatt a munkatárs minden rendelést olvas; az `admin_set_order_status` függvény ellenőrzi a szerepkört és az állapotgépet, és naplóz: ez az osztály kér, nem dönt |
| `_client` | mező | A `SupabaseClient` |
| `currentRole()` | metódus | A saját `admin_users` sor szerepköre (a policy csak a sajátot mutatja) |
| `_order(id)` | metódus | Egy rendelés azonosító szerint |
| `watchOrders()` | metódus | `liveQuery` az `orders` táblán, a legutóbbi 200 rendelés újak elöl |
| `watchOrder(id)` | metódus | `liveQuery` egy rendelésre |
| `watchHistory(orderId)` | metódus | `liveQuery` az `order_status_history` táblán a rendelésre szűrve, korai elöl |
| `operatorTransitions()` | metódus | Az `order_status_transitions` tábla az üzemeltetőnek engedett sorokra szűkítve |
| `setStatus(orderId, status)` | metódus | Meghívja az `admin_set_order_status`-t; a `forbidden` hibát (vagy a 42501-et) `StaffOnlyException`-né, az `invalid_transition`-t `InvalidOrderTransitionException`-né alakítja |
| `auditLog({limit})` | metódus | Az `audit_log` tábla legfrissebb sorai |
| `_status(code)` | privát függvény | A szóból állapot; ismeretlenre `FormatException` |
| `operatorTransitionsFromRows(rows)` | függvény | Csak az üzemeltető lépései (a tábla a szolgáltatóét és a vásárlóét is tartalmazza) |
| `statusChangeFromRow(row)` | függvény | Adatbázissor → `StatusChange` (ismeretlen szereplőre `FormatException`) |
| `auditEntryFromRow(row)` | függvény | Adatbázissor → `AuditEntry` |

#### app/lib/features/admin/application/admin_providers.dart

| Név | Mi ez | Leírás |
|---|---|---|
| `adminRepositoryProvider` | szolgáltató | A `main_admin.dart` adja a Supabase-os megvalósítást; nélküle `UnimplementedError` (nincs szerver nélküli mód) |
| `staffRoleProvider` | szolgáltató | A bejelentkezett szerepköre; `null`, ha senki sincs bejelentkezve vagy nem munkatárs. Más belépésekor újra lekérdezi |
| `adminOrdersProvider` | szolgáltató | Minden rendelés élőben (vendégnek üres) |
| `adminOrderProvider` | családszolgáltató | Egy rendelés élőben |
| `orderHistoryProvider` | családszolgáltató | Egy rendelés előzményei élőben |
| `operatorTransitionsProvider` | szolgáltató | Állapot → az üzemeltető által elérhető állapotok |
| `auditLogProvider` | szolgáltató (`autoDispose`) | Az audit napló; a képernyő elhagyása eldobja |
| `AdminOrderFilter` | enum | Melyik rendeléseket mutatja a lista: `active` (fizetett és nem lezárt: amin a konyha dolgozik), `awaitingPayment`, `closed`, `all` |
| `AdminOrderFilter.matches(status)` | metódus | Az állapot beleesik-e a szűrőbe |
| `filterAdminOrders(orders, filter)` | függvény | A szűrő rendelései abban a sorrendben, ahogy a konyhának kellenek: a folyamatban lévők a szállítási ablak szerint (a legkorábbi elöl), a lezártak újak elöl |
| `AdminOrderFilterNotifier` | `Notifier<AdminOrderFilter>` | A kiválasztott szűrő (alapból `active`) |
| `AdminOrderFilterNotifier.select(filter)` | metódus | Szűrőt választ |
| `adminOrderFilterProvider` | szolgáltató | A fenti notifier |

#### app/lib/features/admin/admin_router.dart

| Név | Mi ez | Leírás |
|---|---|---|
| `adminRedirect({signedIn, path})` | függvény (tesztekhez látható) | A router egyetlen szabálya: előbb be kell lépni. Hogy a belépett munkatárs-e és milyen szerepkörű, azt az `AdminGate` dönti el képernyőnként |
| `adminRouterProvider` | szolgáltató | A `GoRouter`: `/login`, `/` (rendelések), `/orders/:id`, `/audit` (csak `admin`). A munkamenet változására újra lefuttatja az átirányítást |

#### app/lib/features/admin/presentation/admin_gate.dart

| Név | Mi ez | Leírás |
|---|---|---|
| `AdminGate` | `ConsumerWidget` | Csak a munkatársat engedi át. A bejelentkezett, de nem munkatárs eset normális (egy vásárló, aki megtalálta a címet), ezért külön képernyője van kijelentkezéssel. Az `adminOnly` képernyőknek az `admin` szerepkör kell: az operátor ugyanezt az elutasítást látja |
| `AdminGate.child` | mező | A védett képernyő |
| `AdminGate.adminOnly` | mező | Csak `admin` szerepkörnek |
| `_NoAccess` | privát widget | "Nincs hozzáférésed" kijelentkezés gombbal |

#### app/lib/features/admin/presentation/admin_labels.dart

| Név | Mi ez | Leírás |
|---|---|---|
| `StaffRoleLabel` | kiterjesztés | `StaffRole` magyar neve (`label(l10n)`) |
| `AdminOrderFilterLabel` | kiterjesztés | A szűrő magyar neve (`label(l10n)`) |
| `ChangeActorLabel` | kiterjesztés | A változtató magyar neve (`label(l10n)`: vásárló, üzemeltető, fizetés) |
| `adminActionLabel(l10n, target)` | függvény | Mit mond az a gomb, amely a rendelést ebbe az állapotba viszi (készítés megkezdése, kiszállítás indítása, kiszállítva, lemondás). A "fogadva" és "fizetésre vár" felé nincs üzemeltetői lépés: ott üres szöveg, csak a kimerítő `switch` miatt |

#### app/lib/features/admin/presentation/admin_app_bar.dart

| Név | Mi ez | Leírás |
|---|---|---|
| `AdminAppBar` | `ConsumerWidget` (`PreferredSizeWidget`) | Az admin képernyők sávja: ki van belépve (széles képernyőn az e-mail), a szerepkör címkéje, az audit napló gombja (csak `admin`), kijelentkezés |
| `AdminAppBar.title`, `AdminAppBar.leading` | mezők | A cím és az elöl álló elem |
| `AdminAppBar.preferredSize` | getter | A sáv magassága (`kToolbarHeight`) |

#### app/lib/features/admin/presentation/admin_login_screen.dart

| Név | Mi ez | Leírás |
|---|---|---|
| `adminDemoCredentialsProvider` | szolgáltató | A "belépés demó munkatársként" gomb fiókja (`ADMIN_DEMO_EMAIL`/`ADMIN_DEMO_PASSWORD`). Alapból üres: egy nyilvános weboldalba tett jelszóval bárki kezelhetné az oldalt, ezért a vásárlóknak szánt buildekben nincs benne, a munkatárs gépeli be |
| `AdminLoginScreen` | `ConsumerStatefulWidget` | A munkatársak belépése. Regisztráció nincs: a munkatársi fiókot rendszergazda hozza létre. A belépés utáni továbblépés a router dolga |
| `_AdminLoginScreenState` | állapot | |
| `_formKey`, `_email`, `_password` | mezők | Az űrlap kulcsa és a mezők vezérlői |
| `_showPassword`, `_busy`, `_checkWhileTyping`, `_failure` | mezők | Mint az `AuthScreen`-nél: a jelszó láthatósága, folyamatban a kérés, gépelés közbeni ellenőrzés, a hiba oka |
| `dispose()` | metódus | A vezérlők felszabadítása |
| `_signIn(email, password)` | metódus | Belép; hibára a `FailureBox` mutatja az okot |
| `_submit()` | metódus | Ellenőriz, majd belép |

#### app/lib/features/admin/presentation/admin_orders_screen.dart

| Név | Mi ez | Leírás |
|---|---|---|
| `AdminOrdersScreen` | `ConsumerWidget` | A rendelések élőben. Széles képernyőn (900 képponttól) egymás mellett a lista és a kiválasztott rendelés; telefonméretnél mindegyik külön képernyő |
| `AdminOrdersScreen.selectedId` | mező | A kiválasztott rendelés azonosítója |
| `AdminOrdersScreen._wideFrom` | konstans | 900: ettől a szélességtől kétoszlopos |
| `_OrderList` | privát widget | A szűrő-chipek és a szűrt lista (betöltés, hiba, üres állapottal) |
| `_OrderList.selectedId` | mező | A kijelölt rendelés (kiemelve) |
| `_OrderTile` | privát widget | Egy rendelés kártyája: szám, összeg, szállítási ablak, leadás ideje és darabszáma, állapot és fizetés |
| `_OrderTile.order`, `_OrderTile.selected` | mezők | A rendelés és hogy ki van-e jelölve |

#### app/lib/features/admin/presentation/widgets/admin_order_detail.dart

| Név | Mi ez | Leírás |
|---|---|---|
| `AdminOrderDetail` | `ConsumerStatefulWidget` | Egy rendelés a konyhának: mi a következő lépés, mit rendeltek, hova megy, és mi történt vele eddig. A gombok az adatbázis állapotgépe szerint az üzemeltetőnek engedett lépések; semmi itt nem dönti el, mi engedett |
| `AdminOrderDetail.orderId` | mező | A rendelés azonosítója |
| `_AdminOrderDetailState` | állapot | |
| `_busy` | mező | Folyamatban van egy lépés (a gombok le vannak tiltva) |
| `_move(order, target)` | metódus | Lemondás előtt megerősítést kér; aztán meghívja a `setStatus`-t, és azonnal újratölti a rendelést, az előzményeket és a listát (az élő kapcsolat is hozná). Nem engedett lépésre, nem munkatársra, és **bármilyen más hibára** (hálózat, olvashatatlan válasz) üzenetsávban szól |
| `_confirmCancel(order)` | metódus | A lemondás megerősítő ablaka (kifizetettnél a visszatérítést említi) |
| `_Card` | privát widget | Címmel ellátott kártya |
| `_Card.title`, `_Card.child` | mezők | A cím és a tartalom |
| `_Actions` | privát widget | A lépés-gombok (a lemondás körvonalas, piros; a többi kitöltött); fizetésre váró rendelésnél magyarázattal, lépés nélkül "nincs teendő" |
| `_Actions.order`, `moves`, `busy`, `onMove` | mezők | A rendelés, a megtehető lépések, a folyamatban jelző és a visszahívás |
| `_Detail` | privát widget | Címke-érték sor |
| `_Detail.label`, `_Detail.value` | mezők | A címke és az érték |
| `_HistoryRow` | privát widget | Az előzmények egy sora: idő, állapot (vagy "leadva") és a változtató |
| `_HistoryRow.change` | mező | A `StatusChange` |

#### app/lib/features/admin/presentation/admin_audit_screen.dart

| Név | Mi ez | Leírás |
|---|---|---|
| `AdminAuditScreen` | `ConsumerWidget` | Mit tettek a munkatársak, újak elöl; csak az `admin` szerepkörnek (az adatbázis mindenki mástól megtagadja) |
| `_AuditTile` | privát widget | Egy bejegyzés: állapotváltásnál "Állapot: X → Y", egyébként a művelet neve; alatta az idő és az érintett sor |
| `_AuditTile.entry` | mező | Az `AuditEntry` |

### 4.12 Szövegek (`lib/l10n/`)

| Fájl | Leírás |
|---|---|
| `app_hu.arb` | A felületi szövegek magyarul: a **sablon**, minden kulcs és a paraméteres szövegek (`@kulcs` blokkok) itt vannak. Új szöveghez ide kell kulcsot írni, aztán `flutter gen-l10n` |
| `generated/app_localizations.dart` | Generált: az `AppLocalizations` absztrakt osztály minden kulccsal (getter vagy függvény). Kézzel nem szerkeszthető |
| `generated/app_localizations_hu.dart` | Generált: a magyar megvalósítás |
| `l10n.yaml` (az `app/` mappában) | A generálás beállítása: sablon `app_hu.arb`, kimenet `lib/l10n/generated`, `nullable-getter: false` |

A szövegek kulcsai előtag szerint csoportosítva: `common...` (általános), `nav...` (alsó sáv), `menu...`, `product...`, `allergen...`, `cart...`, `price...`, `address...`, `kitchen...`, `checkout...`, `slot...`, `order...` (köztük `orderError...` a leadás
hibái és `orderStatus...` az állapotok), `payment...`, `notif...`/`notification...`, `auth...`, `profile...`, `imageCredits...`, `admin...`, `demoBanner`, `appTitle`.

## 5. A tesztek

Négy réteg van, és mindegyik máshol fut:

| Réteg | Hol | Mit bizonyít | Parancs |
|---|---|---|---|
| Dart egység- és widgetteszt | `app/test/` (`integration/` nélkül) | A logika és a képernyők viselkedése memóriabeli dublőrökkel, hálózat nélkül | `cd app && flutter test` |
| Dart integrációs teszt | `app/test/integration/` | Az app Supabase-os megvalósításai egy **valódi** háttérrel (helyi `supabase start` vagy a saját szerver): jogosultságok, függvények, élő követés. Sima `flutter test`-nél kimaradnak (`skip`) | `flutter test test/integration --dart-define=ZABA_TEST_SUPABASE_URL=... --dart-define=ZABA_TEST_SUPABASE_KEY=...` (a munkatársi tesztekhez még `ZABA_TEST_SUPABASE_SECRET_KEY`) |
| pgTAP | `supabase/tests/database/` | Az adatbázis: séma, jogosultság, árazás, idősávok, rendelés, fizetés, állapotgép | `npx supabase test db`, vagy a saját szerveren a `pg_prove` (lásd `deploy/selfhost/README.md`) |
| Edge Function (Node) | `supabase/functions/**/*.test.ts` | A függvények tiszta logikája (aláírás, kulcsválasztás, törzs-korlát, belépési pontok) | `npm run test:functions` |
| HTTP-füst | `supabase/tests/api_smoke.py`, `payment_smoke.py`, `realtime_smoke.py` | A valódi HTTP-n át: jogosultság, a teljes fizetési folyamat, Realtime | lásd a 6. fejezetet |

A Dart-tesztek **betöltik a csomagolt betűket** (`flutter_test_config.dart`), különben a szög-alakú "Ahem" betűvel futnának, és a szöveg-túlcsordulás nem látszana. A tesztek időt a `clockProvider`-en át kapnak (rögzített:
szerda, 10:00), fizetési késleltetés nincs, a hálózati hibát dublőrök szimulálják.

Egy szabály: **a hibaág-teszt a másik fele a kódnak**. Ahol a képernyő egy hívást vár (rendelés, fizetés, lemondás, admin lépés), ott van teszt arra is, hogy a hívás hibával tér vissza, sőt arra is, hogy olyan hibával, amely nem `Exception`, hanem `Error`
(`TypeError`: így viselkedik egy olvashatatlan szerverválasz). Ezek a tesztek fogták meg, hogy a gomb örökre pörögve maradna.

### 5.1 Közös tesztsegédek (`app/test/support/`)

#### app/test/support/pump_zaba.dart

| Név | Mi ez | Leírás |
|---|---|---|
| `pumpZaba(tester, {...})` | függvény | A teljes vásárlói appot felállítja egy 390 x 844 képpontos telefonképernyőn (vagy a megadott `screen` méretén, `textScale` betűnagyítással), a kis tesztétlappal az igazi demóadat helyett. Alapból bejelentkezve mint a demó vásárló (`signedIn: false` vendéget ad; `auth` saját fiókokat). Rögzített órát és nulla fizetési késleltetést állít. A további `overrides` a tesztéi |
| `scrollListTo(tester, finder)` | függvény | A listák lustán épülnek: a fő függőleges listát addig görgeti, amíg a keresett elem megépül és látszik |
| `_chipRow` | privát getter | A szűrő-chipek vízszintes görgethető sora (nem "az első vízszintes `Scrollable`": a kereső szövege is vízszintesen görög) |
| `scrollChipRowToStart(tester)` | függvény | A chip-sort az elejére viszi, ahol a vegetáriánus kapcsoló és az első chipek vannak |
| `tapCategoryChip(tester, name)` | függvény | Odagörget a `name` nevű kategória-chiphez, és megérinti |
| `navTab(label)` | függvény | Az alsó sáv adott feliratú füle |
| `enterAddress(tester)` | függvény | Kitölti a cím párbeszédablakot egy V. kerületi címmel (1051, Váci utca 12.) |

#### app/test/support/pump_admin.dart

| Név | Mi ez | Leírás |
|---|---|---|
| `staffAccount` | konstans | A munkatársi tesztfiók (`konyha@example.test`) |
| `customerAccount` | konstans | A vásárlói tesztfiók (`vevo@example.test`): a "belépett, de nem munkatárs" esethez |
| `pumpAdmin(tester, {admin, signedInAs, width, height, overrides})` | függvény | Az admin oldalt felállítja asztali méretű (1280 x 800) vagy megadott ablakban, a megadott `FakeAdminRepository`-val, a `signedInAs` e-mail-című fiókkal belépve |

#### app/test/support/fake_admin_repository.dart

| Név | Mi ez | Leírás |
|---|---|---|
| `operatorMoves` | konstans | Az üzemeltető lépései, ahogy az adatbázis táblája tartalmazza (fizetésre vár→lemondva, fogadva→készül/lemondva, készül→úton/lemondva, úton→kiszállítva) |
| `FakeAdminRepository` | osztály | Az admin oldal hátterének dublőrje: memóriában tartja a rendeléseket, alkalmazza az `operatorMoves` lépéseit, előzményt és audit-bejegyzést ír, és megmondható neki, hogy hibázzon |
| `role` | mező | Annak a szerepköre, aki kérdez; `null` = nem munkatárs |
| `failNextMove` | mező | Amit a `setStatus` egyszer dob a munka helyett (`Exception`, vagy `Error` az olvashatatlan válaszhoz) |
| `_orders`, `_history` | mezők | A rendelések és az előzmények |
| `audit` | mező | Az audit-bejegyzések, újak elöl |
| `_changes` | mező | A változásjelző |
| `setStatusCalls` | mező | A `setStatus` hívásai (rendelés, állapot) |
| `put(order)` | metódus | Felvesz vagy lecserél egy rendelést, és jelez (új rendelés "érkezik") |
| `_live(read)` | metódus | A kezdőértéket, majd minden változás után az újat adó folyam |
| `currentRole`, `watchOrders`, `watchOrder`, `watchHistory`, `setStatus`, `auditLog` | metódusok | Az `AdminRepository` szerint; a `setStatus` a `failNextMove`-ot, a jogosultságot, az átmenet-táblát, a visszatérítést, az előzményt és a naplót is utánozza |

#### app/test/support/order_fixtures.dart

| Név | Mi ez | Leírás |
|---|---|---|
| `fixedNow` | érték | A rendelés-tesztek "most"-ja: szerda 10:00 |
| `bookableSlot` | érték | Egy idősáv, amely `fixedNow`-kor foglalható (12:00-13:00) |
| `innerAddress` | konstans | Belső kerületi cím (1051) |
| `outsideAddress` | konstans | Szállítási területen kívüli cím (1181) |
| `newOrderStore({clock})` | függvény | Új `InMemoryOrderStore` a tesztétlappal és a demózónákkal |
| `validRequest({key})` | függvény | Érvényes rendelés-kérés: két carbonara (5 580 Ft, a belső zóna minimuma fölött), megjegyzéssel |
| `sampleOrder({...})` | függvény | Egy rendelés, ahogy a szerver visszaadná, olyan tesztekhez, amelyeknek csak létező rendelés kell |

#### app/test/support/checkout_steps.dart

| Név | Mi ez | Leírás |
|---|---|---|
| `forint(amount)` | függvény | Az összeg `Money.format()` szerint |
| `total` | érték | 2 carbonara (5 580 Ft) + 990 Ft szállítás a V. kerületbe |
| `reachCheckout(tester, {...})` | függvény | A szokásos út a pénztárig: cím, két carbonara, kosár, pénztár |
| `placeOrder(tester)` | függvény | Megérinti a "Rendelés leadása" gombot |
| `fillCard(tester, {number})` | függvény | Kitölti a kártyaűrlapot (alapból a `4242...` sikeres tesztkártyával) |
| `pay(tester)` | függvény | Megérinti a "Fizetés" gombot |

#### app/test/support/test_catalog.dart

| Név | Mi ez | Leírás |
|---|---|---|
| `testCategories` | konstans | Két kategória (tészták, italok) |
| `carbonara`, `arrabbiata`, `lemonade`, `rantott` | konstansok | Négy tesztterméket: a carbonara (2 790 Ft), az arrabbiata (vegetáriánus), a limonádé (ital) és a rántott sajt |
| `testProducts` | konstans | A négy termék. Apró, stabil étlap, hogy a tesztek ne függjenek a demóadattól |

#### app/test/flutter_test_config.dart

Betölti a csomagolt betűket (Baloo 2, Inter) minden teszt előtt. Nélküle a tesztek a szögletes "Ahem" betűvel futnának, és a valódi szöveg-túlcsordulást nem fognák meg.

### 5.2 A tesztfájlok

#### app/test/app_shell_test.dart

A váz: a DEMÓ-szalag és a négy fül látszik, a fülek váltanak, a profil elmagyarázza a demót és megnyitja a fejlesztői galériát.

#### app/test/small_screens_test.dart

A vevő teljes útját végigjárja a valódi telefonképernyőkön: kis telefon (320 x 568), kis telefon nagyobb betűvel, fekvő telefon (844 x 390), a legnagyobb Android-betűvel. A kiadás-build szó nélkül levágja a nem férő sort; a teszt hibaként jelenti.
Ezek fogják meg, ami a telefonokon levágódna.

| Név | Mi ez | Leírás |
|---|---|---|
| `_screens` | konstans | A négy képernyő-beállítás: név → (méret, betűnagyítás) |
| `reveal(tester, finder)` | függvény | Addig görget, amíg a keresett elem látszik, mint egy ember (a görgetési pozíciót mozgatja, nem húz: rövid képernyőn a húzást elvihetné egy másik elem) |
| `tapRevealed(tester, finder)` | függvény | Megmutatja, majd megérinti |
| `enterRevealed(tester, label, text)` | függvény | Megmutatja a feliratú mezőt, és beírja a szöveget |

#### app/test/tool/seed_sql_test.dart

A `supabase/seed/10_catalog.sql` naprakész-e a Dart demó-étlaphoz képest (az `app/tool/seed_sql.dart` generálja); és hogy az idézőjelek a nevekben helyesen kerülnek escape-elésre.

#### app/test/core/format/date_time_format_test.dart, app/test/core/money/money_test.dart, app/test/core/text/fold_text_test.dart

Az óra/dátum/időszak formázása, a `Money` formázása és számtana (tördelhetetlen szóköz, valódi mínusz, összeadás, szorzás, összehasonlítás, összegzés), az ékezet-lehántás.

#### app/test/core/realtime/live_query_test.dart

A `liveQuery` minden tulajdonsága hamis időzítővel (`fake_async`): az első lekérés, a változásra újabb lekérés, a lekérés közbeni változások összevonása, az élő kapcsolat nélküli lekérdezés, a hibák (az első érték előtt hiba, utána elnyelve), a leiratkozás.

| Név | Mi ez | Leírás |
|---|---|---|
| `FakeFeed` | osztály | Kézzel vezérelhető `ChangeFeed` |
| `FakeFeed.stopped` | mező | Leiratkoztak-e róla |
| `FakeFeed.feed` | getter | A `ChangeFeed` függvény, amelyet a `liveQuery` kap |
| `FakeFeed.change()` | metódus | "Változás történt" jelzés |
| `FakeFeed.status(live)` | metódus | A kapcsolat állapotának jelzése |

#### app/test/core/router/auth_redirect_test.dart

A vendég böngészhet, a rendelési útvonalakról a belépésre kerül (a `from` paraméterrel); a belépett nincs elzárva, és a belépő oldalról továbbmegy; a kifelé mutató visszatérési utat figyelmen kívül hagyja.

| Név | Mi ez | Leírás |
|---|---|---|
| `redirect(...)` | függvény | Rövidítés az `authRedirect` hívására egy útvonallal |

#### app/test/core/storage/preferences_test.dart

Az `openPreferences` megnyitja a tárhelyet, ha működik, és `null`-t ad (nem hibát), ha a böngésző tiltja.

| Név | Mi ez | Leírás |
|---|---|---|
| `_BlockedStore` | osztály | Tárhely-dublőr, amely minden olvasásra hibát dob |
| `_BlockedStore.getAll`, `clear`, `remove`, `setValue` | metódusok | A platform-felület metódusai (az olvasás dob, a többi hamisat ad) |

#### app/test/core/theme/app_colors_test.dart

A szövegpárok megfelelnek a WCAG-kontrasztnak (4,5:1 a szövegre, 3:1 a jelentést hordozó szegélyre).

| Név | Mi ez | Leírás |
|---|---|---|
| `contrast(a, b)` | függvény | Két szín kontrasztaránya a WCAG képlete szerint |

#### app/test/core/widgets/state_views_test.dart

A betöltés-, hiba- és üres nézet, és hogy 160%-os betűnagyításnál sem csordulnak túl.

| Név | Mi ez | Leírás |
|---|---|---|
| `host(child)` | függvény | A nézetet témával és nyelvvel körülvevő `MaterialApp` |

#### app/test/features/auth/auth_flow_test.dart

A belépés és a fiók a képernyőkön: a rendeléshez fiók kell (a vendéget a pénztár belépésre küldi, és a demó fiók visszahozza), regisztráció, a belépő űrlap ellenőrzései, rossz jelszó, jelszó mutatása, rövid jelszó és foglalt cím, a profil és a kijelentkezés,
a név és e-mail nélküli fiók.

| Név | Mi ez | Leírás |
|---|---|---|
| `total` | érték | A két carbonara és a szállítás összege |
| `guestWithFilledCart(tester)` | függvény | Vendég két carbonarával a kosárban, a kosár gombjánál |
| `tapCheckoutButton(tester)` | függvény | Megérinti a "Tovább a fizetéshez" gombot |
| `field(label)` | függvény | A feliratú űrlapmező |
| `fillAndSubmit(tester, {...})` | függvény | Kitölti az e-mailt és a jelszót, megnyomja a gombot |

#### app/test/features/auth/auth_rules_test.dart, app/test/features/auth/in_memory_auth_repository_test.dart, app/test/features/auth/supabase_auth_repository_test.dart

Az e-mail épelméjűség-vizsgálat és a `safeReturnPath` (a nyílt átirányítás elleni védelem); a memóriabeli fiókkezelő (belépés, regisztráció, a név levágása, rövid jelszó, foglalt cím); az `authFailureFrom` a **hibakód** szerint dönt, nem az üzenet szövege szerint.

| Név | Mi ez | Leírás |
|---|---|---|
| `failsWith(reason)` | függvény (az `in_memory_auth_repository_test.dart`-ban) | Olyan illesztő, amely azt várja, hogy egy hívás `AuthFailure`-t dob a megadott okkal |

#### app/test/features/catalog/menu_filter_test.dart, app/test/features/catalog/supabase_catalog_repository_test.dart

A szűrés, keresés, rendezés, csoportosítás szabályai; az adatbázis-sorok átalakítása (az ismeretlen allergénkód megállítja a betöltést, minden allergén átmegy a kódján).

| Név | Mi ez | Leírás |
|---|---|---|
| `ids(products)` | függvény (a `menu_filter_test.dart`-ban) | A termékek azonosítói, sorrendben |
| `row({allergens, imagePath})` | függvény (a `supabase_catalog_repository_test.dart`-ban) | Egy `catalog_products` sor, ahogy a szerver adná (a carbonara) |

#### app/test/features/catalog/menu_loading_test.dart

Ha a kategóriák vagy a termékek nem töltődnek be, az étlap ezt mondja, és az "Újra" gomb helyreállít.

| Név | Mi ez | Leírás |
|---|---|---|
| `FlakyCatalog` | osztály | Étlap-dublőr, amely addig hibázik, amíg az `up` be nincs állítva |
| `FlakyCatalog.categoriesFail`, `productsFail` | mezők | A kategóriák, illetve a termékek hibázzanak-e |
| `FlakyCatalog.up` | mező | Igaz után mindkettő működik |
| `FlakyCatalog.categories`, `products` | metódusok | A lekérések |

#### app/test/features/catalog/product_card_layout_test.dart

A "kosárba" gomb a kártya jobb szélén, az ár balra; a darabszám-választó a gomb helyére kerül.

| Név | Mi ez | Leírás |
|---|---|---|
| `cardOf(name)` | függvény | A megnevezett termék kártyájának keresője |

#### app/test/features/catalog/product_images_test.dart

A termékfotók: minden megadott úthoz van fájl, nincs gazdátlan fájl, a fotó nélküliek köre pontosan ismert, minden fotónak van forrása és licence, a fotók összmérete 3 MB alatt van; a `ProductImage` (fotó, csempe, az ikon a kategóriából, általános ikon); a források képernyője.

| Név | Mi ez | Leírás |
|---|---|---|
| `on Product` | kiterjesztés | Segéd a fájl végén |
| `copyWithoutImage()` | metódus | A termék másolata fotó nélkül |

#### app/test/features/cart/cart_notifier_test.dart, app/test/features/cart/in_memory_quote_service_test.dart, app/test/features/cart/shared_preferences_cart_store_test.dart, app/test/features/cart/supabase_quote_service_test.dart

A kosár (hozzáadás, csökkentés, törlés, a 99-es határ, mentés, `retainOnly`), a memóriabeli árazás (szállítási díj zónánként, ingyenes küszöb, becslés, hibás cím), a tár (a hibás vagy idegen adat figyelmen kívül marad), a szerver válaszának átalakítása.

| Név | Mi ez | Leírás |
|---|---|---|
| `preferencesWith(values)` | függvény (a tár tesztjében) | `SharedPreferences` a megadott kezdőértékkel |
| `storeWith(values)` | függvény (a tár tesztjében) | `SharedPreferencesCartStore` ugyanezzel |
| `quoteJson(...)` | függvény (a szerver-árazás tesztjében) | Egy `quote_cart` válasz, ahogy a szerver adná |

#### app/test/features/cart/cart_flow_test.dart

A kosár a képernyőn: a mentett kosár megvan induláskor, a már nem árult termék kiesik, a mentés azonnali, az árak az ajánlatéi (nem az étlapéi), az üres kosarat nem árazza, hibánál az "Újra" helyreállít.

| Név | Mi ez | Leírás |
|---|---|---|
| `forint(amount)` | függvény | Az összeg formázva |
| `ScriptedQuoteService` | osztály | Árazó-dublőr: azt válaszolja, amit az `answer` ad, és számolja a kérdéseket |
| `ScriptedQuoteService.answer` | mező | A válasz függvénye |
| `ScriptedQuoteService.calls` | mező | A kérdések száma |
| `ScriptedQuoteService.quote` | metódus | Az interfész szerint |
| `quoteOf(lines, {delivery})` | függvény | Ajánlat a sorokból (3 500 Ft minimummal) |
| `lineOf(product, {quantity, unit})` | függvény | Egy ajánlat-sor |

#### app/test/features/delivery/address_dialog_test.dart

Ha a zóna-lekérdezés hibázik, a párbeszédablak ezt kimondja, nyitva marad, és semmit sem ment.

| Név | Mi ez | Leírás |
|---|---|---|
| `_UnreachableZones` | osztály | Zóna-dublőr: az alapértelmezett zónát megadja, az irányítószám-lekérdezés hibát dob |
| `_UnreachableZones.zoneForPostalCode`, `defaultZone` | metódusok | A dublőr két metódusa |

#### app/test/features/delivery/in_memory_delivery_slot_service_test.dart, app/test/features/delivery/supabase_delivery_test.dart

Az idősávok (óránként 11-21, vasárnap 20-ig, 45 perc előfutás, a horizont a mai nap + 2); a zóna- és sávsorok átalakítása (napokba csoportosítás, UTC-idők).

#### app/test/features/menu_and_cart_flow_test.dart

Az étlap és a kosár a képernyőn: csoportosítás, kosársáv és jelvény, a minimum alatti kosár nem mehet a pénztárba, a kosár kiürítése, ékezetfüggetlen keresés, szűrők, a termék részletlapja, a szállítási területen kívüli cím elutasítása.

| Név | Mi ez | Leírás |
|---|---|---|
| `forint(amount)` | függvény | Az összeg formázva |

#### app/test/features/checkout_and_payment_flow_test.dart

A pénztár és a fizetés a képernyőn: cím, első szabad idősáv, összegzés; más nap és sáv választása; a leadás kiüríti a kosarat és a fizetésre visz; sikeres, elutasított és megszakított kártyalépés; űrlap-ellenőrzés; a fizetetlen rendelés lemondása; a kifizetett lemondása és visszatérítése; a rendelések fül; cím nélkül nincs leadás.

#### app/test/features/failure_paths_test.dart

A hibaágak: a rendelés-háttér leállt (és olyan válasz, amit az app nem tud olvasni), a fizetés-háttér leállt (és olvashatatlan válasz), a kártyalépés megszakítása hibás háttér mellett is elhagyja a képernyőt.

| Név | Mi ez | Leírás |
|---|---|---|
| `DownOrders` | osztály | Rendelés-háttér, amely leállt, vagy olvashatatlant válaszol (a `failure` dönti el: `Exception` vagy `Error`) |
| `DownOrders.failure` | mező | Amit a `placeOrder` dob |
| `DownOrders.placeCalls` | mező | A leadási kísérletek száma |
| `DownOrders.placeOrder`, `findOrder`, `watchOrders`, `watchOrder`, `cancelOrder` | metódusok | Az interfész; csak a `placeOrder` dob |
| `_Offline` | osztály | A hagyományos "nincs hálózat" kivétel |
| `DownPayments` | osztály | Fizetés-háttér, amely leállt vagy olvashatatlant válaszol |
| `DownPayments.failure` | mező | Amit a `submit` dob |
| `DownPayments.calls` | mező | A hívások száma |
| `DownPayments.submit` | metódus | Az interfész szerint |

#### app/test/features/admin/admin_flow_test.dart

Az admin oldal a képernyőn, a `FakeAdminRepository`-val: a belépés (vendég, rossz jelszó, munkatárs, belépett vásárló "nincs hozzáférés"-t kap), a rendelések listája (a szűrők, az élőben érkező új rendelés, az üres halmaz, a szerepkör címkéje), egy rendelés (széles képernyőn a lista mellett, telefonon külön oldalon, a gombok az állapotgép lépései, a lépés a képernyőn és az előzményben, a fizetésre váró rendelés csak lemondható, a lemondás előtti megerősítés, a nem engedett lépés üzenete, a háttér hibája, az olvashatatlan válasz), az audit napló (az `admin` olvassa, az operátor nem).

| Név | Mi ez | Leírás |
|---|---|---|
| `slotAt(hour)` | függvény | Egy idősáv aznap, az adott órától egy órára |
| `order(id, number, status, hour, {payment, note})` | függvény | Egy rendelés az adott állapotban és idősávban (a fizetés alapból az állapotból adódik) |
| `kitchen({role})` | függvény | Négy rendeléssel feltöltött `FakeAdminRepository` (fogadva, készül, fizetésre vár, kiszállítva) |
| `tile(number)` | függvény | A megadott rendelésszámú kártya keresője a listában |

#### app/test/features/admin/admin_logic_test.dart

Az admin oldal logikája képernyő nélkül: a lista szűrői és sorrendje (`active`, `awaitingPayment`, `closed`, `all`; minden állapot beleesik legalább egy szűrőbe), az adatbázissorok átalakítása (az üzemeltető lépései az átmenet-táblából, az előzmények szereplője, az audit-sor, minden állapot szava visszaolvasható, az ismeretlen állapotot nem találgatja, a szerepkör kódja), és az admin router átirányítása.

| Név | Mi ez | Leírás |
|---|---|---|
| `slotAt(hour)` | függvény | Egy idősáv aznap, az adott órától egy órára |

#### app/test/features/notifications/notifications_test.dart

A `statusChanges` (az első betöltés nem hír, az új rendelés nem változás), az értesítések állapota (sorrend, 30 darabos korlát, a sáv elrejtése, az olvasottság, a más felhasználó üresen indul), és az appban: a konyha lépése sávot ad, a sáv magától eltűnik, a lista és a csengő, a lemondott kifizetett rendelés említi a visszatérítést, a vendégnek nincs csengője.

| Név | Mi ez | Leírás |
|---|---|---|
| `note(...)` | függvény | Egy `AppNotification` a teszthez |

#### app/test/features/orders/in_memory_order_store_test.dart

A memóriabeli szerver minden szabálya: a rendelés felvétele (idempotencia, két egyidejű hívás egy rendelést ad, az öt fizetésre váró korlát és annak feloldása, elutasítások, az elutasított kérés nem hagy rendelést), a fizetési események (egyszeri hatás, elutasított és megszakított fizetés, a lemondott rendelésre érkező késői esemény), a lemondás, az üzemeltetői lépések (a boldog út, a kihagyás tilos, a lezárt végleges), a követés.

| Név | Mi ez | Leírás |
|---|---|---|
| `event(...)` | függvény | Egy `PaymentEvent` a teszthez |
| `rejectedWith(reason)` | függvény | Olyan illesztő, amely `OrderRejectedException`-t vár a megadott okkal |

#### app/test/features/orders/order_providers_test.dart

A vendégnek nincs rendelése és a háttérnek nem is kérdez; a belépés hozza, a kilépés viszi a rendeléseket.

| Név | Mi ez | Leírás |
|---|---|---|
| `CountingOrders` | osztály | Rendelés-dublőr, amely számolja a lekérdezéseket |
| `CountingOrders.order` | mező | Az egyetlen rendelés, amelyet ad |
| `CountingOrders.listCalls`, `CountingOrders.singleCalls` | mezők | A lista- és az egyedi lekérések száma |
| `CountingOrders.watchOrders`, `watchOrder`, `placeOrder`, `findOrder`, `cancelOrder` | metódusok | Az interfész szerint |

#### app/test/features/orders/supabase_order_repository_test.dart

Egy adatbázissor teljes rendeléssé alakul; a sorok a leadás sorrendjében jönnek; az adatbázis minden állapota megfelel az app egyikének; ismeretlen állapot vagy hiányzó idősáv hiba, nem találgatás.

| Név | Mi ez | Leírás |
|---|---|---|
| `orderRow(...)` | függvény | Egy `orders` sor, ahogy a szerver adná |

#### app/test/features/orders/cancel_failure_test.dart

A lemondás hibái: ha a konyha épp elkezdte, a vásárló megtudja, miért marad a rendelés; más hibánál azt, hogy próbálja újra, és a gomb megmarad.

| Név | Mi ez | Leírás |
|---|---|---|
| `_CancelFails` | osztály | Rendelés-dublőr: a demó-tár, kivéve hogy a lemondás a megadott hibával elbukik |
| `_CancelFails._store` | mező | A mögötte álló tár |
| `_CancelFails.failure` | mező | A lemondás hibája |
| `_CancelFails.cancelOrder`, `placeOrder`, `findOrder`, `watchOrders`, `watchOrder` | metódusok | A lemondás dob; a többi a tárra továbbít |
| `cancelPaidOrder(tester, failure)` | függvény | Kifizetett rendelést csinál, és megpróbálja lemondani |

#### app/test/features/payment/card_input_formatters_test.dart, app/test/features/payment/card_validation_test.dart, app/test/features/payment/fake_payment_service_test.dart

A kártyaszám csoportosítása (négyesével, legfeljebb 19 számjegy, a kurzor a végén), a lejárat perjele; a Luhn-ellenőrzés, a lejárat, a biztonsági kód, a hamis szolgáltató egyetlen elutasított kártyája; a hamis fizetés (az eseményen át fizet, az elutasított vár, a megszakított megszakított, az újrapróba új esemény).

| Név | Mi ez | Leírás |
|---|---|---|
| `typed(formatter, text)` | függvény (a formázó-tesztben) | Beírja a szöveget a formázón át, és az eredményt adja |

#### app/test/integration/integration_env.dart

A integrációs tesztek közös környezete: a háttér, amelyen futnak, a helyi `supabase start` (migrációk és kezdőadat betöltve, e-mail-megerősítés kikapcsolva) vagy a saját szerver. A tesztek eldobható fiókokat hoznak létre, ezért **sosem szabad éles projektre irányítani**.

| Név | Mi ez | Leírás |
|---|---|---|
| `integrationUrl`, `integrationKey` | konstansok | `ZABA_TEST_SUPABASE_URL` és `ZABA_TEST_SUPABASE_KEY` |
| `integrationSkip` | érték | A `skip:` paraméterbe adva a sima `flutter test` kihagyja ezeket a teszteket |
| `_MemoryStorage` | osztály | A PKCE-folyamat tárolója memóriában (egy sima Dart-tesztnek nincs `SharedPreferences`-e) |
| `_MemoryStorage._data` | mező | A tárolt értékek |
| `_MemoryStorage.getItem`, `setItem`, `removeItem` | metódusok | A tároló műveletei |
| `newIntegrationClient([url, key])` | függvény | Új `SupabaseClient` a teszt-háttérhez |
| `integrationSecretKey` | konstans | `ZABA_TEST_SUPABASE_SECRET_KEY`: a titkos (service-role) kulcs. Csak a munkatársi fiókot létrehozó tesztek kapják; ő tehet valakit munkatárssá, ezért éles projekt tesztjeihez nem való |
| `staffIntegrationSkip` | érték | Kihagyja a munkatársi teszteket, ha nincs titkos kulcs |
| `_staffCounter` | számláló | Az egyedi munkatársi e-mail-címekhez |
| `newStaffClient(role)` | függvény | Új eldobható fiókkal belépett kliens, amelyet a titkos kulccsal a megadott szerepkörű munkatárssá tesz |

#### app/test/integration/supabase_auth_integration_test.dart, app/test/integration/supabase_catalog_integration_test.dart, app/test/integration/supabase_cart_and_delivery_integration_test.dart, app/test/integration/supabase_orders_integration_test.dart, app/test/integration/supabase_admin_integration_test.dart

Valódi háttéren: a regisztráció és a profil, a kijelentkezés, a hibák mint a képernyők által ismert okok, az étlap a demóadat mezőről mezőre, az árazás (ugyanazt adja, mint a Dart szabályok), a zónák és sávok, a rendelés (idempotencia, elutasítások, az öt fizetetlen korlát, láthatóság), a fizetés a szolgáltató eseményén át, a lemondás és visszatérítés, az élő követés, a munkatársi szerepkörök, az állapotgép, az audit napló.

| Név | Mi ez | Leírás |
|---|---|---|
| `failsWith(reason)` | függvény (az auth-tesztben) | Mint a memóriabeli tesztben: azt várja, hogy a hívás az okkal `AuthFailure`-t dob |
| `newEmail()` | függvény (az auth-tesztben) | Egyedi eldobható e-mail-cím |
| `catalog` | érték (a kosár-tesztben) | A demó-étlap-forrás az összevetéshez |
| `describeQuote(quote)` | függvény (a kosár-tesztben) | Az ajánlat összehasonlítható szöveges alakja |
| `describeZone(zone)` | függvény (a kosár-tesztben) | A zóna összehasonlítható szöveges alakja |
| `describeCategory(category)`, `describeProduct(product)` | függvények (az étlap-tesztben) | A kategória és a termék összehasonlítható szöveges alakja |
| `_counter` | számláló (a rendelés- és admin-tesztben) | Egyedi azonosítók |

## 6. Segédeszközök (`tool/`)

Kisebb Python- és shell-programok, amelyek a fejlesztést, a kezdőadat előállítását és az ellenőrzéseket szolgálják. Titkot sosem írnak ki; a kulcsokat környezeti változóból vagy a helyi Supabase `status` kimenetéből (`--from-local`) olvassák.

#### tool/create_demo_user.py

A "belépés demó fiókkal" gomb vásárlóját hozza létre. Újra futtatható: a meglévő fiókot békén hagyja, ha a jelszava egyezik. Csak a nyilvános regisztrációs végpontot használja, titok nem kell hozzá.

| Név | Mi ez | Leírás |
|---|---|---|
| `load_config()` | függvény | Az URL-t és a nyilvános kulcsot a `--from-local` kapcsolóval a helyi `supabase status`-ból, egyébként a `SUPABASE_URL`, `SUPABASE_PUBLISHABLE_KEY`, `DEMO_EMAIL`, `DEMO_PASSWORD` változókból veszi |
| `post(path, body)` | függvény | JSON-kérést küld a háttérnek (időkorláttal) |

#### tool/create_staff_user.py

Munkatársi fiókot hoz létre az admin oldalhoz (`operator` vagy `admin`). Újra futtatható: a meglévő fiók megtartja a jelszavát, csak a szerepköre frissül. Előbb belép (hogy a meglévő fiókot felismerje), a fiókot a nyilvános regisztrációval hozza létre, a munkatársi sort a **titkos kulccsal** írja.

| Név | Mi ez | Leírás |
|---|---|---|
| `load_config()` | függvény | Mint fent, kiegészítve a `SUPABASE_SECRET_KEY`, `STAFF_EMAIL`, `STAFF_PASSWORD` változókkal. A titkos kulcs az, amely munkatársat csinálhat: nem kerülhet sem a chatbe, sem a tárolóba. **Saját szerveren a régi, service_role JWT kell**: az új `sb_secret_` kulcsot az auth admin API ott 403-mal utasítja el |
| `request(method, path, key, body, token, extra)` | függvény | HTTP-kérés időkorláttal, érthető hibaüzenettel |

#### tool/check_demo.py

Egy kitelepített demó környezetet ellenőriz kívülről, **csak olvasva**: az oldalak válaszolnak a biztonsági fejlécekkel (CSP a háttér nevével, nincs keretezés és szimatolás, nincs keresőindexelés, az indítófájlok sosem gyorsítótárazottak, a saját renderelő motor), az étlap jön a háttérből, a fizetési függvények telepítve vannak és megvan a titkuk. Hibánál 1-es kilépési kóddal áll meg.

| Név | Mi ez | Leírás |
|---|---|---|
| `check(name, condition, detail)` | függvény | Egy ellenőrzés eredménye egy sorban (`ok` vagy `FAILED`), a hibát gyűjti |
| `fetch(url, method, headers, body)` | függvény | Egy HTTP-kérés; a hibás állapotkódot is visszaadja (állapot, fejlécek kisbetűs névvel, törzs) |

#### tool/licenses.py

A Dart-csomagok licenceit listázza a helyi pub-gyorsítótár `LICENSE` fájljaiból, és a táblát a `docs/licenses.md`-be írja a két jelölő megjegyzés közé (`--write`). A licencet a szövegből ismeri fel (néhány jól ismert licenc szokásos szövege szerint); amit nem tud elhelyezni, az `UNKNOWN`, azt embernek kell elolvasnia. Leltár, nem jogi tanács.

| Név | Mi ez | Leírás |
|---|---|---|
| `pub_cache()` | függvény | A pub-gyorsítótár helye |
| `flutter_root()` | függvény | A Flutter telepítésének helye |
| `listed(heading, lines)` | függvény | A `pubspec.lock` egy szakaszának csomagjai |
| `shipped_packages()` | függvény | Az appba kerülő csomagok (a fejlesztői függőségek nélkül) |
| `lock_sources()` | függvény | Honnan jön a csomag (pub, SDK) |
| `classify(text)` | függvény | A licenc neve a szöveg alapján |
| `licence_of(name, version, source)` | függvény | Egy csomag licence |
| `table()` | függvény | A teljes Markdown-tábla |

#### tool/dev_inventory.py

A fejlesztői útmutató (`docs/development.md`) **ellenőrzése**: kilistázza, mit deklarál a kód, és ellenőrzi, hogy az útmutató mindent leír-e. Használat: `python3 tool/dev_inventory.py` (a leltár), `--check` (hibával áll meg, ha az útmutató kihagy egy nevet vagy egy fájlt), `--check --list` (és fel is sorolja a hiányt). A CI minden futásnál lefuttatja (lásd 8. fejezet), így egy új osztály, mező, függvény vagy fájl dokumentáció nélkül nem kerülhet be.

| Név | Mi ez | Leírás |
|---|---|---|
| `source_files()` | függvény | A vizsgált forrásfájlok |
| `inventory(path)` | függvény | Egy fájl deklarációi: `(fajta, tulajdonos, név)` |
| `doc_sections()` | függvény | Az útmutató szakaszai: egy fájl szakasza a fájl útvonalát tartalmazó címsortól a következő címsorig tart |
| `OTHER_FILES` | konstans | A nem Dart fájlok mintái (migrációk, függvények, szkriptek, telepítési fájlok, munkafolyamatok, beállítások), amelyeknek szerepelniük kell az útmutatóban |
| `SQL_CREATE_RE`, `TS_EXPORT_RE`, `PY_DEF_RE`, `SH_FUNCTION_RE` | konstansok | A migrációk létrehozta objektumok, a TypeScript-exportok, a Python-függvények és a shell-függvények felismerő mintái |
| `other_files()` | függvény | Az `OTHER_FILES` fájljai, amelyeket a git ismer (vagy felvenne): a kizárt fájlok és a gyorsítótárak nem számítanak |
| `word_in(name, text)` | függvény | Szerepel-e a név egész szóként a szövegben |
| `check_other(doc_text)` | függvény | A nem Dart fájlok és nevek közül azok, amelyeket az útmutató kihagy |
| `main()` | függvény | A parancssor kezelése és az ellenőrzés |

#### app/tool/seed_sql.dart

A `supabase/seed/10_catalog.sql` generátora a Dart demó-étlapból (`demo_catalog.dart`), hogy a memóriabeli demó és az adatbázis egy forrásból kapja az étlapot: `cd app && dart run tool/seed_sql.dart ../supabase/seed/10_catalog.sql`. A `test/tool/seed_sql_test.dart` elbukik, ha a bevitt fájl elavult.

| Név | Mi ez | Leírás |
|---|---|---|
| `_text(value)` | privát függvény | SQL-szöveg: aposztróf közé téve, a bennük lévő aposztrófok megkettőzve |
| `_allergens(allergens)` | privát függvény | Az allergén-halmaz SQL-tömbje (`array[...]::text[]`, a kódok sorrendben; üresre `'{}'::text[]`) |
| `catalogSeedSql()` | függvény | A teljes kezdőadat-fájl szövege: kategóriák, termékek, árak, készlet (nem követett: `null` = korlátlan) |
| `main(args)` | függvény | Kiírja a megadott fájlba |

#### tool/lan_preview.sh

Az appot és az admin oldalt a saját gépről kiszolgálja a ugyanazon a Wi-Fi-n lévő telefonoknak, a helyi Supabase ellen (nem kell hozzá Cloudflare- vagy Supabase-fiók). Az `app/build/lan` mappába épít (soha nem a `demo` mappába, amelyből telepítünk), és a demóéval azonos fejlécekkel szolgál ki a `wrangler dev`-ből. Sima http a házi hálózaton, helyi fejlesztői fiókokkal: csak a saját telefonokra. A tűzfalnak át kell engednie a 8787, 8788 és 54321 portot.

#### tool/android/create_demo_keystore.sh

Elkészíti a demó APK aláírókulcsát **a tárolón kívül** (`~/.zaba-keys/`), és megadja az Android-buildnek (`app/android/key.properties`, amelyet a git figyelmen kívül hagy). Meglévő kulcsot sosem ír felül. A kulcsot biztonsági másolatban kell tartani: egy telepített APK frissítését ugyanazzal a kulccsal kell aláírni.

#### tool/brand/make_icons.py

Az app minden ikonját és a logófájlokat egyetlen forrásból rajzolja: `app/assets/brand/zaba-mark.svg` (a Z a rolleres). Csak az `rsvg-convert` kell hozzá. A forrás változása után kell futtatni, és az eredményt commitolni.

| Név | Mi ez | Leírás |
|---|---|---|
| `mark_path()` | függvény | A jel útvonal-adata az SVG-ből |
| `composition(size, height, shape, radius)` | függvény | A jel elhelyezése egy négyzetes vásznon (szín, alak: nincs, lekerekített négyzet vagy kör) |
| `render(svg, out, width, height)` | függvény | Az SVG PNG-vé alakítása az `rsvg-convert`-tel |
| `write(path, text)` | függvény | Szöveges fájl írása |
| `main()` | függvény | Az összes kimenet: logó, jel, favicon, webes ikonok (sima és maszkolható), iOS-ikon, Android indítóikonok (adaptív is) |

#### tool/fonts/subset_fonts.py

A csomagolt betűket (`app/assets/fonts`) építi: a Google változó betűiből (0,7-0,9 MB darabja) néhány statikus vastagságot példányosít, és csak a latin/latin-kiterjesztett karaktereket tartja meg (az app egyelőre csak magyar). Mindkét betű SIL OFL 1.1, fenntartott névvel nem; a licencszövegek a betűk mellett vannak. Kell hozzá: `pip install fonttools brotli`.

| Név | Mi ez | Leírás |
|---|---|---|
| `build(source, instances, out_dir)` | függvény | Egy forrásbetűből a megadott példányok kiírása |
| `main()` | függvény | A parancssor: `--baloo`, `--inter`, `--out` |

#### tool/images/ (a termékfotók)

| Fájl | Leírás |
|---|---|
| `tool/images/commons.py` | A Wikimedia Commons API kis segédje. **Csak CC0, közkincs és CC BY** fotót fogad el: a share-alike (SA), a nem kereskedelmi (NC) és a származékot tiltó (ND) licenc kizárt, mert a fotókat átméretezzük, vágjuk, és az appot átadjuk. Függvényei: `api(params)` (hívás), `fetch_bytes(url)` (letöltés), `_meta(info, key)` (metaadat), `describe(page)` (egy találat leírása), `search(query, limit, thumb_width)` (keresés), `file_info(title, width)` (egy fájl adatai). A `USER_AGENT` és az `ACCEPTED_LICENSES` konstans a Wikimedia kérésére és az elfogadott licencekre |
| `tool/images/find_candidates.py` | Jelölt fotókat keres a demó-termékekhez, és termékenként egy kontaktlapot ír, hogy ember válogathasson szemmel. Függvényei: `contact_sheet(product_id, candidates)` (a számozott lap), `main()` |
| `tool/images/selection.json` | A kiválasztott fotók (termék → Commons-fájl) |
| `tool/images/build_images.py` | A kiválasztott fotókból építi a termékképeket: 1000 px-es letöltés, 4:3-ra vágás, 800 x 600-as WebP az `app/assets/images/products/` mappába, a forrás rögzítése a `credits.json`-ban, a `docs/image-credits.md` és az app forráslistájának (`image_credits.dart`) újragenerálása. Függvényei: `crop_to_ratio(image, ratio)`, `clean(text)`, `dart_string(text)`, `main()` |
| `tool/images/credits.json` | Minden fotó címe, szerzője, licence és forrása (a `build_images.py` írja) |

## 7. Telepítés (`deploy/`)

Kétféle környezet van, és mindkettő a repóban lévő fájlokból áll össze (nincs kézi kattintgatás). A **demó** (`deploy/demo/`) a megrendelőnek adott link: Cloudflare + felhős Supabase. A **saját szerver** (`deploy/selfhost/`) a fejlesztés alatti staging, és az éles üzem (lásd
[`real-life-plan.md`](real-life-plan.md)) alapja: a hivatalos Supabase self-host csomag, Caddy és Cloudflare Tunnel egy gépen. A lépésről lépésre leírás: [`demo-environment.md`](demo-environment.md) és [`../deploy/selfhost/README.md`](../deploy/selfhost/README.md).

### 7.1 A demó környezet (`deploy/demo/`)

#### deploy/demo/build-web.sh

A vásárlói appot vagy az admin oldalt építi a `app/build/demo/<app|admin>` mappába. A beállítást egy `--dart-define-from-file` JSON adja (alapból `config/demo.json`). A háttér címét a tartalombiztonsági szabályba (CSP) írja: az oldal csak oda csatlakozhat. `--no-web-resources-cdn` (a renderelő motor a saját hostról jön, nem a Google-éről) és `--csp` (nincs dinamikusan generált kód, így nem kell `unsafe-eval`). A `ZABA_BUILD_OUT` kimeneti mappát csak a `lan_preview.sh` és a saját szerver telepítője állítja át, hogy a telepítendő build soha ne cserélődjön le. Az admin oldal saját webes manifestet kap.

#### deploy/demo/build-apk.sh

Az aláírt Android APK-t építi, ellenőrzi, és előkészíti a letöltőoldalt (`app/build/demo/apk`). **Csak 64 bites ARM** (a 32 bites is benne 40 MB, a Cloudflare fájlonként 25 MiB-ig szolgál ki). Elutasítja az APK-t, ha nem a demó kulccsal van aláírva (a debug kulccsal sem), ha nincs benne `INTERNET` engedély, vagy ha 25 MiB fölötti. A letöltőoldalra beírja a verziót, a méretet és az SHA-256 értéket.

#### deploy/demo/deploy-web.sh

A demó egy részét építi és telepíti a Cloudflare-re erről a gépről: `app`, `admin` vagy `apk`. Mindegyik külön oldal (egy csak fájlokat kiszolgáló Cloudflare Worker), így egynek a telepítése a többit nem érinti. Cloudflare-belépés kell hozzá (`npx wrangler login`, vagy a `CLOUDFLARE_API_TOKEN` és `CLOUDFLARE_ACCOUNT_ID` környezeti változó).

#### deploy/demo/setup-supabase.sh

A felhős Supabase-projektbe teszi a háttért: séma, demó étlap, fizetési függvények és a titkuk, mind a repóból. `first` új, üres projekthez (az étlapot csak ez tölti be), `update` később (új migrációk és a függvények újra). Környezeti változók: `SUPABASE_ACCESS_TOKEN`, `SUPABASE_PROJECT_REF`, `SUPABASE_DB_PASSWORD`, `FAKE_PAYMENT_WEBHOOK_SECRET` (legalább 32 karakter), és `FAKE_PAYMENTS_ENABLED` (alapból `true`: a demó hamis kártyalépése; valódi boltnál `false`). A titkot **fájlon** át adja át (nem a parancssoron, hogy ne látszódjon a folyamatlistában). A végén kiírja a kézzel elvégzendőket (e-mail-megerősítés ki, regisztráció be, Site URL).

#### deploy/demo/_headers.template

A demó oldalainak fejlécei (Cloudflare `_headers` fájl): `nosniff`, kereső-tiltás, `Referrer-Policy`, `Permissions-Policy`, és a CSP, amelybe a `build-web.sh` a háttér két címét (`__SUPABASE_HTTP__`, `__SUPABASE_WS__`) írja. Az indítófájlok (`index.html`, `flutter_bootstrap.js`, `flutter_service_worker.js`, `version.json`, `manifest.json`, `splash.js/css`, `main.dart.js`) `no-cache`: egy új verzió így eléri a régit használókat is.

#### deploy/demo/wrangler.app.jsonc, deploy/demo/wrangler.admin.jsonc, deploy/demo/wrangler.apk.jsonc

A három Cloudflare Worker beállítása (`zaba-app`, `zaba-admin`, `zaba-apk`): csak statikus fájlokat szolgálnak ki (`assets.directory` az adott build mappája); az app és az admin kliens oldali útvonalai `index.html`-re esnek vissza (`single-page-application`), az APK-oldal nem.

#### deploy/demo/apk/index.html

Az Android letöltőoldal sablonja (`__SIZE__`, `__VERSION__`, `__SHA256__` helyőrzőkkel): letöltés gomb, telepítési lépések, a "DEMÓ" jelzés. A `build-apk.sh` tölti ki.

### 7.2 A saját szerver (`deploy/selfhost/`)

Egy Linux gépen (Docker, compose 2.24 vagy újabb) fut: a hivatalos Supabase self-host kiadás (rögzített: `self-hosted/v0.8.3`, 11 konténer), mellette a **Caddy** (összesen 12 konténer; kiszolgálja a két webes buildet, és csak az engedélyezett API-útvonalakat adja tovább) és a **cloudflared** (kimenő alagút a Cloudflare-hez: a gépen nem kell nyitott bejövő port).

#### deploy/selfhost/install.sh

Telepít vagy frissít. Újra futtatható: a titkokat csak egyszer generálja (egy új adatbázisjelszó egy meglévő adatbázist elérhetetlenné tenne), a beállításokat, az új migrációkat és az alagutat újra alkalmazza. Lépései: eszközök ellenőrzése, a hivatalos fájlok letöltése (a megadott kiadásra), titkok generálása (a `.env` 600-as módban), beállítások (`SUPABASE_PUBLIC_URL`, `API_EXTERNAL_URL`, `SITE_URL`, átirányítási címek; a demóban az e-mail automatikusan megerősítettnek számít, mert nincs kimenő levelezés), a fizetési webhook titka (egyszer generálva) és a `FAKE_PAYMENTS_ENABLED` (friss stacken `true`, a meglévőhöz nem nyúl), a Zaba rétegek (Caddy, alagút) bemásolása, az Edge Function-ök bemásolása (a tesztfájlok nélkül), képek letöltése, indítás, majd a függvények **állandó** válaszának kivárása (8 jó válasz egymás után: az átjáró 5 másodpercenként ellenőrzi a függvényeket, és egy újraindulás után még visszaeshet 503-ra), az alagút indítása, végül a migrációk, a kezdőadat és az ütemezett feladatok (`schedule.sh`). Kiírja a `config/staging.json` tartalmát (a nyilvános kulccsal: a régi JWT-vel, mert ez a kiadás csak azt fogadja a Realtime WebSocketen).

#### deploy/selfhost/docker-compose.zaba.yml

A hivatalos compose fölé rétegzett kiegészítés (`COMPOSE_FILE`). Tartalma: **naplókorlát** minden konténerre (a `x-logging` horgony: 5 fájl x 10 MB; a Docker alapból sosem forgatja a naplót, és egy forgalmas szerver lassan megtölti a lemezt); az API-átjáró (`api-gw`) csak a géphez kötve (`127.0.0.1:8000`: mögötte a Studio áll, ezért sosem lehet nyilvános); a `supavisor` portjai elhagyva; a `functions` megkapja a `FAKE_PAYMENT_WEBHOOK_SECRET`-et és a `FAKE_PAYMENTS_ENABLED`-et (alapból `false`); a `caddy` (a Caddyfile, a két webes mappa és a CSP-hez a hostnevek és sémák); a `cloudflared` (csak a `tunnel` profillal, a `CLOUDFLARE_TUNNEL_TOKEN`-nel).

#### deploy/selfhost/Caddyfile

A Caddy beállítása. A TLS a Cloudflare-nél (az alagútnál) végződik, ezért a Caddy sima HTTP-t szolgál, és `auto_https off`. A `web_security` részlet az oldalak CSP-jét és fejléceit adja (a demó `_headers` fájljával azonos szabály; az API hostnál `:*` port, mert helyi hálózati teszten az API egy másik porton érhető el). A **vásárlói app**: gzip/zstd, `/healthz` a monitorozásnak (külön `handle`, mert a `try_files` minden útvonalat átírna), az indítófájlok `no-cache`, a kliens oldali útvonalak `index.html`-re esnek vissza, de a kiterjesztéses hiányzó fájl valódi 404 (egy hibás kép ne HTML-t kapjon). Az **admin**: ugyanez `Referrer-Policy: no-referrer`, `X-Frame-Options: DENY`, `no-cache` fejlécekkel. Az **API host** csak a `/rest/v1/*`, `/auth/v1/*`, `/realtime/v1/*`, `/functions/v1/*` útvonalat adja tovább az átjáróra; a Studio, a Postgres meta API és a Storage **nem érhető el** az internetről (404). Bármely más hostnévre 404 (nem az üres 200, amelyet egy monitor működő oldalnak venne).

#### deploy/selfhost/migrate.sh

A `supabase/migrations/*.sql` fájlokat alkalmazza a saját szerver adatbázisán: mindegyiket egyszer, sorrendben, saját tranzakcióban. A verziókat a `supabase_migrations.schema_migrations` táblába jegyzi (ugyanabba, amelyet a Supabase CLI használ, így a `supabase db push` egyetért vele).

#### deploy/selfhost/schedule.sh

Az adatbázis saját ütemezett feladatait állítja be a `pg_cron`-nal (a Supabase Postgres-kép része): `zaba-expire-unpaid` 10 percenként (a `ZABA_UNPAID_MINUTES`, alapból 30, legalább 5 percnél régebben fizetésre váró rendeléseket az `expire_unpaid_orders` lemondja, a helyet visszaadja az idősávnak, és naplóz) és `zaba-cron-history` naponta (a pg_cron egy hétnél régebbi futási előzményeit törli). Újra futtatható: az azonos nevű feladatot lecseréli, így a `ZABA_UNPAID_MINUTES` változtatása egy újabb futtatással érvénybe lép. Az `install.sh` is futtatja. A jobot a `verify.sh` ellenőrzi. Anélkül egy sosem kifizetett rendelés örökre megtartja a helyét az idősávban.

#### deploy/selfhost/seed.sh

A `supabase/seed/*.sql` fájlokat tölti be, **csak egyszer**: ha az étlapon már van termék, nem csinál semmit, így az újratelepítés nem duplikál és nem írja felül a közben végzett változtatásokat.

#### deploy/selfhost/deploy-web.sh

A Flutter webes appot a fejlesztő gépen építi, és a szerverre másolja, ahol a Caddy kiszolgálja: `user@szerver [app|admin]`, vagy `local:/stack/útvonal`. A demó buildjét használja (`ZABA_BUILD_OUT`-tal saját kimeneti mappába), a Cloudflare `_headers` fájlt törli (itt a Caddy állítja a fejléceket, a fájlt bárki lekérhetné). A másolás `rsync --delay-updates`-szel történik, hogy a Caddy bind-mountja ne törjön el.

#### deploy/selfhost/verify.sh

A telepített szervert **kívülről ellenőrzi, és semmit nem változtat**. Telepítés után, minden szerver-módosítás után és időnként kell futtatni (egy cron-feladat, amely levelet küld, ha a kilépési kód nem 0, olcsó monitor). Soronként `ok`, `WARN` (érdemes ránézni) vagy `FAILED` (javítani kell); `FAILED` esetén 1-gyel lép ki. Ellenőrzi: minden konténer fut és egészséges; csak a helyi átjáró és a Caddy publikált; a Caddy azt szolgálja, amit kell, és azt rejti, amit kell (Studio, meta API, Storage); a biztonsági fejlécek; hogy egyetlen titok sem a hivatalos helyőrző értékű; hogy az adatbázisban megvan az összes migráció és be van állítva a lejárati job (`zaba-expire-unpaid`); hogy a mentés friss; hogy a lemez és a naplók korlátosak.

| Név | Mi ez | Leírás |
|---|---|---|
| `env_value(name)` | függvény | Egy érték a stack `.env` fájljából |
| `ok`, `warn`, `bad` | függvények | Egy sor kiírása `ok`, `WARN`, illetve `FAILED` előtaggal (a `bad` a kilépési kódot is 1-re állítja) |
| `check(leírás, yes/no, részlet)` | függvény | `ok` vagy `FAILED` a feltétel szerint |

#### deploy/selfhost/backup.sh

Mentést készít: a teljes adatbázist (`pg_dump`, egyéni formátum) és a stack titkait (`.env`). **Mindkettő kell**: az adat az adatbázisban van, a titkok (JWT-titok, API-kulcsok) viszont azok, amelyeken a nyilvános kulccsal épített appok és minden bejelentkezett munkamenet múlik; titkok nélkül a visszaállított adat a telepített appok kulcsát érvénytelenítené. Beállítások: `ZABA_BACKUP_DIR` (hova, alapból `~/zaba-backups`), `ZABA_BACKUP_KEEP` (hány legújabbat őriz, alapból 14), `ZABA_BACKUP_PASSPHRASE_FILE` (ha meg van adva, a mentés titkosított: `openssl aes-256-cbc`, PBKDF2, `.tar.enc`; nélküle sima `.tar`, amely a titkokat is tartalmazza: csak titkosított lemezen szabad tartani). Visszaolvasással ellenőrzi a mentést, aztán a régieket törli. Cronból vagy systemd időzítőből kell futtatni, és egy másolatot **másik helyre** is kell tenni.

#### deploy/selfhost/restore.sh

A `backup.sh` mentését állítja vissza. `data <mentés> [--yes]` az adatbázist cseréli le; `env <mentés>` a mentés titkait teszi a helyükre. **Ugyanazon a gépen adatvesztés után**: `data`. **Új gépen** (vagy ha a stack mappa elveszett): `env`, aztán `install.sh`, aztán `data` (az `env` előbb kell, mert az `install.sh` új titkot generál, ha nem talál, az új titok pedig érvénytelenítené az appok kulcsát és a munkameneteket). A `data` ugyanazt a kiadást és ugyanazokat a migrációkat kéri, mint a mentés (különben megtagadja), leállít mindent az adatbázison kívül, a `public`, `auth`, `storage` és `supabase_migrations` séma adatát **egyetlen tranzakcióban** cseréli (ha bármi elbukik, az adatbázis úgy marad, ahogy volt), és újraindítja a stacket. Az **összes** alkalmazásadatot lecseréli, ezért rákérdez (`--yes` átugorja). Mért idő: egy kis adatbázison 130 másodperc a teljes újjáépítésig.

#### deploy/selfhost/zaba-selfhost.env.example

A telepítő beállítófájljának sablonja (`zaba-selfhost.env`, git-ben nincs): a három hostnév (`ZABA_APP_HOST`, `ZABA_API_HOST`, `ZABA_ADMIN_HOST`), a séma (`ZABA_PUBLIC_SCHEME`), a stack helye (`ZABA_STACK_DIR`), az alagút tokenje (`CLOUDFLARE_TUNNEL_TOKEN`, titok), a rögzített kiadás (`SUPABASE_SELFHOST_REF`), a közvetlen elérés (`ZABA_HTTP_BIND`, `ZABA_HTTP_PORT`). Titok (adatbázisjelszó, JWT-titok, API-kulcsok) **nincs** benne: azokat a telepítő a szerver `.env` fájljába generálja.

#### Közös shell-segédfüggvények

A szkriptek kis, ismétlődő segédeket használnak:

| Név | Hol | Leírás |
|---|---|---|
| `die(üzenet)` | `install.sh`, `backup.sh`, `restore.sh`, `lan_preview.sh` | Hibaüzenetet ír a hibakimenetre, és 1-gyel kilép |
| `say(üzenet)` | `install.sh` | Egy lépés címe a kimeneten (`==> ...`) |
| `set_env(kulcs, érték)` | `install.sh` | Egy sor beállítása a stack `.env` fájljában (a régit eldobja, az újat hozzáfűzi; ideiglenes fájlon át, hogy a fájl sosem marad félig írva) |
| `psql_db(...)` | `migrate.sh`, `seed.sh`, `backup.sh`, `restore.sh`, `verify.sh` | `psql` a `db` konténerben (`ON_ERROR_STOP`, csendes) |
| `kill_tree(pid)`, `cleanup()` | `lan_preview.sh` | A háttérben indított szerverek (és gyermekfolyamataik) leállítása kilépéskor |

#### deploy/selfhost/README.md

A saját szerver üzemeltetési leírása: előfeltételek, telepítés, a webes buildek telepítése, az alagút, mentés és visszaállítás, ellenőrzés, naplók, frissítés, ismert korlátok.

## 8. Automatizálás (`.github/workflows/`)

Minden külső GitHub Action **a teljes commit-azonosítóhoz (SHA) rögzítve** van (a címkét át lehetne irányítani), mellette az olvasható verziószám megjegyzésben.

#### .github/workflows/ci.yml

Minden push-ra és kérésre lefut. Négy munka:

| Munka | Mit csinál |
|---|---|
| `app` | `flutter pub get`, `dart format --set-exit-if-changed`, `flutter analyze`, `flutter test`, a két demó webes build előállítása |
| `database` | `npm ci`, a függvények Node-tesztjei, a helyi Supabase indítása, `db reset`, **pgTAP** (`supabase test db`), `db lint`, az API-, a Realtime- és a fizetési füsttesztek, a demó és a munkatársi fiókok létrehozása (kétszer: az újra futtathatóság próbája), az **app integrációs tesztjei** a valódi helyi háttéren |
| `deploy-files` | `shellcheck` az összes shell-szkriptre, a Python-szkriptek lefordíthatósága, a Caddyfile érvényessége (`caddy validate`), a dokumentáció teljessége (`dev_inventory.py --check`) |
| `secret-scan` | `gitleaks` a **teljes történeten** |

#### .github/workflows/deploy-demo.yml

A demó webes appjait (vásárlói, admin) építi és tölti fel a Cloudflare-re. **Kézzel indítható** (`workflow_dispatch`, `target`: `both`, `app`, `admin`): egy link, amelyet a megrendelő megnyit, akkor változzon, ha valaki úgy dönt, ne minden push-ra. Az APK nem része (az aláírókulcsos gépen épül). Kell hozzá: változók `DEMO_SUPABASE_URL`, `DEMO_EMAIL`; titkok `DEMO_SUPABASE_KEY` (a nyilvános kulcs), `DEMO_PASSWORD`, `CLOUDFLARE_API_TOKEN`, `CLOUDFLARE_ACCOUNT_ID`. Egyidejűleg csak egy telepítés fut (`concurrency`).

#### .github/workflows/keepalive.yml

Naponta 05:17 UTC-kor lekéri az étlapot a felhős demó Supabase-től: az ingyenes projektet egy hét tétlenség után szüneteltetik, ez a lekérés aktivitásnak számít. A `DEMO_SUPABASE_URL` változó beállításáig nem csinál semmit. Ha nem 200-at kap, hibával áll meg.

## 9. Beállítófájlok és a gyökér

| Fájl | Leírás |
|---|---|
| `config/dev.example.json`, `config/staging.example.json`, `config/demo.example.json` | A `--dart-define-from-file` sablonjai (`APP_ENV`, `SUPABASE_URL`, `SUPABASE_ANON_KEY`, `DEMO_EMAIL`, `DEMO_PASSWORD`, `ADMIN_DEMO_EMAIL`, `ADMIN_DEMO_PASSWORD`). A valódi `config/<env>.json` fájlokat a `.gitignore` kizárja; csak nyilvános érték kerülhet beléjük |
| `supabase/config.toml` | A helyi Supabase CLI stack beállítása: az API (`schemas = public, graphql_public`, legfeljebb 1000 sor), az adatbázis (17-es főverzió), a Realtime, az auth (`enable_signup = true`, `minimum_password_length = 8`, `enable_confirmations = false`, 3600 másodperces JWT), a három Edge Function (`payments-create`: `verify_jwt = true`; `fake-provider-confirm` és `payments-webhook`: `verify_jwt = false`, mert ők saját módon, munkamenet-tokennel illetve aláírással hitelesítenek), az Edge Runtime titkai (`FAKE_PAYMENT_WEBHOOK_SECRET`, `FAKE_PAYMENTS_ENABLED` a `supabase/.env`-ből) |
| `supabase/.env.example` | A helyi stack titkainak sablonja (`supabase/.env`, git-ben nincs): a `FAKE_PAYMENT_WEBHOOK_SECRET` (a függvények nélküle nem dolgoznak) és a `FAKE_PAYMENTS_ENABLED=true` (a demó hamis kártyalépése; valódi fizetésnél kimarad) |
| `package.json` | Az eszköz-függőségek (Supabase CLI, Wrangler) és a `test:functions` parancs (`node --test supabase/functions/_shared/`) |
| `.gitignore` | Kizárja a titkokat (`.env*`, a valódi `config/*.json`, kulcstárak, `key.properties`), a `kinyert_funkciok/` mappát (idegen, kinyert kód: sosem kerülhet a tárolóba, az átadási csomagba, és nem forrása a Zaba kódjának), az eszközök mellékterméket és a saját szerver helyi beállítását |
| `README.md` | A projekt belépője: mi ez, hogyan indul, parancsok, dokumentumok listája |
| `app/pubspec.yaml`, `app/pubspec.lock` | A Flutter-projekt és a függőségei (rögzített verziókkal) |
| `app/analysis_options.yaml` | Az elemző beállítása (`flutter_lints`) |
| `app/l10n.yaml` | A szövegek generálásának beállítása |
| `app/web/` | A webes buildhez: `index.html` (betöltőképernyő, `viewport-fit=cover`), `manifest.json` és `manifest.admin.json`, `favicon.*`, `icons/`, `splash.js`/`splash.css` |
| `app/android/`, `app/ios/` | A mobil platformok projektjei (az APK aláírása a `key.properties`-szel, amely nincs a tárolóban) |
| `app/assets/` | A csomagolt eszközök: `fonts/` (Baloo 2, Inter), `images/products/` (45 termékfotó WebP-ben), `brand/` (a logó forrása és kimenetei) |
| `docs/` | Az átadási dokumentumok: `architecture.md`, `data-model.md`, `payment-flow.md`, `env-vars.md`, `handover.md`, `licenses.md`, `image-credits.md`, `contract-annex-outline.md`, `test-checklist.md`, `known-gaps.md`, `decisions.md`, `demo-environment.md`, `code-review.md`, `real-life-plan.md`, és ez a `development.md` |
