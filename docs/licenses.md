# Harmadik féltől származó anyagok és licencek

Ez egy **leltár**, nem jogi vélemény. Azt rögzíti, hogy a Zaba mit tartalmaz másoktól, milyen licenc alatt, és hol van a licencszöveg.
Az átadás előtt ügyvéddel érdemes átnézni (lásd [`contract-annex-outline.md`](contract-annex-outline.md)).

## 1. A Zaba saját kódja

A repóban **nincs licencfájl** a saját kódhoz. A felhasználás és a jogok átszállásának feltételeit tehát nem a repó, hanem a megrendelővel kötött
megállapodás rögzíti; ennek a vázlata a [`contract-annex-outline.md`](contract-annex-outline.md).

A kód eredetéről (nem tartalmaz és nem használ forrásként harmadik fél védett kódját; a felület elrendezésének forrása a tulajdonos saját „Falatozó"
demója) a [`decisions.md` Eredet szakasza](decisions.md#eredet-provenance) szól. A kódot **jelentős részben AI-asszisztens (Anthropic Claude Code)
írta a fejlesztő utasításai szerint**; a commitokban ez társszerzői sorként szerepel. Ennek szerzői jogi következményei bizonytalanok, lásd a
[szerződés-melléklet vázlatát](contract-annex-outline.md#ai-val-készült-kód).

### A logó

A logó (a Z a robogóval) terve **a tulajdonos által adott kép**; az `app/assets/brand/zaba-mark.svg` ennek **kézzel készített újrarajzolása** (mérésekből, nem automatikus képkövetés). Nem harmadik féltől vett grafika, de a kép eredetét (ki készítette, milyen eszközzel) a tulajdonosnak kell rögzítenie, és a logó **védjegy- és hasonlósági vizsgálata nem történt meg** ([`known-gaps.md`](known-gaps.md)). A "Zaba" felirat az appban a Baloo 2 betűvel készül (lásd a 3. részt).

## 2. Dart és Flutter csomagok (az app)

A táblázatot a `tool/licenses.py` állítja elő a helyi pub gyorsítótár LICENSE fájljaiból, a **gyártási függőségi fa** csomagjaira (a fejlesztői
csomagok, például a `flutter_lints`, nincsenek benne). A licencet a LICENSE szövegének szabványos megfogalmazásából ismeri fel; amit nem tud
elhelyezni, azt `UNKNOWN`-nal jelöli, és embernek kell elolvasnia. Újragenerálás: `dart pub get` az `app/` mappában, majd `python3 tool/licenses.py --write`.

A listában szereplő csomagok egy része csak más platformot szolgál (például Linux, Windows), és nem kerül a webes vagy az Android buildbe; a leltár
szándékosan a teljes fát mutatja, mert ez a biztos oldal.

<!-- dart-licences:start -->
Az összesítés: Apache-2.0: 7, BSD-3-Clause: 68, MIT: 16 (összesen 91 csomag).

| Csomag | Verzió | Függőség | Forrás | Licenc |
|---|---|---|---|---|
| `app_links` | 7.2.2 | átvitt | hosted | Apache-2.0 |
| `app_links_linux` | 1.0.4 | átvitt | hosted | Apache-2.0 |
| `app_links_platform_interface` | 2.0.4 | átvitt | hosted | Apache-2.0 |
| `app_links_web` | 1.0.5 | átvitt | hosted | Apache-2.0 |
| `args` | 2.7.0 | átvitt | hosted | BSD-3-Clause |
| `async` | 2.13.1 | átvitt | hosted | BSD-3-Clause |
| `boolean_selector` | 2.1.2 | átvitt | hosted | BSD-3-Clause |
| `characters` | 1.4.1 | átvitt | hosted | BSD-3-Clause |
| `clock` | 1.1.3 | átvitt | hosted | Apache-2.0 |
| `collection` | 1.19.1 | átvitt | hosted | BSD-3-Clause |
| `convert` | 3.1.2 | átvitt | hosted | BSD-3-Clause |
| `crypto` | 3.0.7 | átvitt | hosted | BSD-3-Clause |
| `cupertino_icons` | 2.0.0 | közvetlen | hosted | MIT |
| `cupertino_ui` | 1.1.4 | átvitt | hosted | BSD-3-Clause |
| `dart_jsonwebtoken` | 3.4.1 | átvitt | hosted | MIT |
| `fake_async` | 1.3.3 | átvitt | hosted | Apache-2.0 |
| `ffi` | 2.2.0 | átvitt | hosted | BSD-3-Clause |
| `file` | 7.0.1 | átvitt | hosted | BSD-3-Clause |
| `fixnum` | 1.1.1 | átvitt | hosted | BSD-3-Clause |
| `flutter` | 0.0.0 | közvetlen | sdk | BSD-3-Clause |
| `flutter_localizations` | 0.0.0 | közvetlen | sdk | BSD-3-Clause |
| `flutter_riverpod` | 3.4.3 | közvetlen | hosted | MIT |
| `flutter_test` | 0.0.0 | átvitt | sdk | BSD-3-Clause |
| `flutter_web_plugins` | 0.0.0 | átvitt | sdk | BSD-3-Clause |
| `functions_client` | 2.7.1 | átvitt | hosted | MIT |
| `go_router` | 18.1.1 | közvetlen | hosted | BSD-3-Clause |
| `gotrue` | 2.27.3 | átvitt | hosted | MIT |
| `http` | 1.6.0 | átvitt | hosted | BSD-3-Clause |
| `http_parser` | 4.1.2 | átvitt | hosted | BSD-3-Clause |
| `intl` | 0.20.3 | közvetlen | hosted | BSD-3-Clause |
| `jni` | 1.1.0 | átvitt | hosted | BSD-3-Clause |
| `jni_util` | 1.0.0 | átvitt | hosted | BSD-3-Clause |
| `json_annotation` | 4.12.0 | átvitt | hosted | BSD-3-Clause |
| `leak_tracker` | 11.0.2 | átvitt | hosted | BSD-3-Clause |
| `leak_tracker_flutter_testing` | 3.0.10 | átvitt | hosted | BSD-3-Clause |
| `leak_tracker_testing` | 3.0.2 | átvitt | hosted | BSD-3-Clause |
| `listen` | 1.0.1 | átvitt | hosted | BSD-3-Clause |
| `logging` | 1.3.0 | átvitt | hosted | BSD-3-Clause |
| `matcher` | 0.12.20 | átvitt | hosted | BSD-3-Clause |
| `material_color_utilities` | 0.13.0 | átvitt | hosted | Apache-2.0 |
| `material_ui` | 1.8.0 | átvitt | hosted | BSD-3-Clause |
| `meta` | 1.18.3 | átvitt | hosted | BSD-3-Clause |
| `mime` | 2.1.0 | átvitt | hosted | BSD-3-Clause |
| `package_config` | 3.0.0 | átvitt | hosted | BSD-3-Clause |
| `passkeys_platform_interface` | 2.10.0 | átvitt | hosted | BSD-3-Clause |
| `path` | 1.9.1 | átvitt | hosted | BSD-3-Clause |
| `path_provider_linux` | 2.2.2 | átvitt | hosted | BSD-3-Clause |
| `path_provider_platform_interface` | 2.1.3 | átvitt | hosted | BSD-3-Clause |
| `path_provider_windows` | 2.3.0 | átvitt | hosted | BSD-3-Clause |
| `platform` | 3.2.0 | átvitt | hosted | BSD-3-Clause |
| `plugin_platform_interface` | 2.1.8 | átvitt | hosted | BSD-3-Clause |
| `pointycastle` | 4.0.0 | átvitt | hosted | MIT |
| `postgrest` | 2.9.1 | átvitt | hosted | MIT |
| `realtime_client` | 2.13.2 | átvitt | hosted | MIT |
| `riverpod` | 3.4.3 | átvitt | hosted | MIT |
| `shared_preferences` | 2.5.6 | közvetlen | hosted | BSD-3-Clause |
| `shared_preferences_android` | 2.5.1 | átvitt | hosted | BSD-3-Clause |
| `shared_preferences_foundation` | 2.5.7 | átvitt | hosted | BSD-3-Clause |
| `shared_preferences_linux` | 2.4.1 | átvitt | hosted | BSD-3-Clause |
| `shared_preferences_platform_interface` | 2.4.2 | átvitt | hosted | BSD-3-Clause |
| `shared_preferences_web` | 2.4.3 | átvitt | hosted | BSD-3-Clause |
| `shared_preferences_windows` | 2.4.1 | átvitt | hosted | BSD-3-Clause |
| `sky_engine` | 0.0.0 | átvitt | sdk | BSD-3-Clause |
| `source_span` | 1.10.2 | átvitt | hosted | BSD-3-Clause |
| `stack_trace` | 1.12.2 | átvitt | hosted | BSD-3-Clause |
| `state_notifier` | 1.0.0 | átvitt | hosted | MIT |
| `storage_client` | 2.8.1 | átvitt | hosted | MIT |
| `stream_channel` | 2.1.4 | átvitt | hosted | BSD-3-Clause |
| `string_scanner` | 1.4.1 | átvitt | hosted | BSD-3-Clause |
| `supabase` | 2.16.5 | átvitt | hosted | MIT |
| `supabase_common` | 0.1.2 | átvitt | hosted | MIT |
| `supabase_flutter` | 2.18.3 | közvetlen | hosted | MIT |
| `term_glyph` | 1.2.2 | átvitt | hosted | BSD-3-Clause |
| `test_api` | 0.7.12 | átvitt | hosted | BSD-3-Clause |
| `typed_data` | 1.4.0 | átvitt | hosted | BSD-3-Clause |
| `url_launcher` | 6.3.3 | átvitt | hosted | BSD-3-Clause |
| `url_launcher_android` | 6.3.33 | átvitt | hosted | BSD-3-Clause |
| `url_launcher_ios` | 6.4.2 | átvitt | hosted | BSD-3-Clause |
| `url_launcher_linux` | 3.2.3 | átvitt | hosted | BSD-3-Clause |
| `url_launcher_macos` | 3.2.6 | átvitt | hosted | BSD-3-Clause |
| `url_launcher_platform_interface` | 2.3.2 | átvitt | hosted | BSD-3-Clause |
| `url_launcher_web` | 2.4.3 | átvitt | hosted | BSD-3-Clause |
| `url_launcher_windows` | 3.1.6 | átvitt | hosted | BSD-3-Clause |
| `uuid` | 4.6.0 | átvitt | hosted | MIT |
| `vector_math` | 2.4.0 | átvitt | hosted | BSD-3-Clause |
| `vm_service` | 15.4.0 | átvitt | hosted | BSD-3-Clause |
| `web` | 1.1.1 | átvitt | hosted | BSD-3-Clause |
| `web_socket` | 1.0.1 | átvitt | hosted | BSD-3-Clause |
| `web_socket_channel` | 3.0.3 | átvitt | hosted | BSD-3-Clause |
| `xdg_directories` | 1.1.0 | átvitt | hosted | BSD-3-Clause |
| `yet_another_json_isolate` | 2.1.1 | átvitt | hosted | MIT |
<!-- dart-licences:end -->

A Flutter SDK és a Dart csomagok többsége BSD-3-Clause; a Supabase kliens MIT. Mindhárom típus megköveteli a szerzői jogi közlemény és a licencszöveg
megőrzését a forrás **és** a bináris terjesztésénél. A Flutter ezt az alkalmazásba beépített licenc-nyilvántartással (`LicenseRegistry`) segíti, amelyet a
`showLicensePage` jelenít meg. **A Zaba ma nem mutat ilyen oldalt** (lásd az [ismert hiányokat](known-gaps.md)); az MVP előtt a jogi tanácsadóval egyeztetendő,
hogy kell-e.

## 3. Betűtípusok

| Betű | Licenc | Hol a szöveg |
|---|---|---|
| Baloo 2 (címsor) | SIL Open Font License 1.1 | `app/assets/fonts/OFL-Baloo2.txt` |
| Inter (törzs) | SIL Open Font License 1.1 | `app/assets/fonts/OFL-Inter.txt` |

Mindkettő a Google Fonts tárolóból (`github.com/google/fonts`) való. Az app **részhalmazt** (latin és latin-kiterjesztett karakterek, statikus példányok) tartalmaz,
amelyet a `tool/fonts/subset_fonts.py` állít elő. A script megjegyzése szerint mindkét betű OFL 1.1 alatt áll, és nem jelöl **fenntartott betűnevet** (Reserved Font
Name), ezért módosított példány terjeszthető. Ezt a megállapítást a szöveg szerint a forrásfájlok ellenőrzése adta; az átadás előtt érdemes a letöltött fájlok
szerzői jogi sorával újra egybevetni. A licencszövegek a repóban vannak, de **az app csomagjába nem kerülnek be** (a `pubspec.yaml` csak a betűfájlokat listázza).

## 4. Termékfotók

41 fotó a Wikimedia Commonsból: 15 CC0, 6 közkincs, 20 CC BY (2.0, 3.0 és 4.0 verzió). Csak CC0, közkincs és CC BY került be; a share-alike, non-commercial és
no-derivatives licencűek kizárva. A CC BY névjelzést követel: az app a Profil, Képek forrásai képernyőn megjeleníti a listát. A teljes lista szerzőkkel és
hivatkozásokkal: [`image-credits.md`](image-credits.md) (a `tool/images/build_images.py` generálja). A licenc-adatok a Commons API-ból származnak.

Négy terméknek (`chicken-paprikash`, `squash-stew`, `brasso`, `gundel-pancake`) nincs fotója, ezek csempét mutatnak. **Az éles üzemhez saját fotók kellenek**, a stock
képek a demóhoz valók.

## 5. Fejlesztői eszközök (nem kerülnek az appba és a webes buildbe)

| Eszköz | Verzió | Licenc (a csomag `license` mezője) | Mire |
|---|---|---|---|
| Supabase CLI (`supabase`, npm) | 2.121.0 | MIT | helyi stack, migrációk, függvények telepítése |
| Wrangler (`wrangler`, npm) | 4.149.0 | MIT OR Apache-2.0 | a Cloudflare-oldalak telepítése, helyi kiszolgálás |
| Flutter SDK / Dart SDK | 3.47.0 / 3.13.0 | BSD-3-Clause (Flutter) | az app építése |
| Pillow, fontTools (Python) | nincs rögzítve | nem ellenőriztem | csak a `tool/fonts` és `tool/images` scriptek (betű-részhalmaz, képek), a fejlesztő gépén |
| librsvg (`rsvg-convert`) | nincs rögzítve | nem ellenőriztem | csak a `tool/brand/make_icons.py` (az ikonok előállítása az SVG-ből), a fejlesztő gépén |
| websockets (Python) | nincs rögzítve | nem ellenőriztem | csak a `supabase/tests/realtime_smoke.py` |

A npm függőségfa (`package-lock.json`) tranzitív csomagjainak licencét nem soroltam fel; a `npm audit` 0 sebezhetőséget jelez (2026-10-21).
Ezek az eszközök a megrendelőnek átadott termékben nem szerepelnek, csak a fejlesztéshez és a telepítéshez kellenek.

## 6. Üzemeltetett szoftverek és szolgáltatások (nem a leszállítandó része)

Ezekből egyik sincs a repóban; a megrendelő üzemeltetési döntése, melyiket használja.

| Összetevő | Mire | Megjegyzés |
|---|---|---|
| Supabase (felhő vagy a hivatalos self-host csomag) | adatbázis, belépés, Realtime, Edge Functions | A self-host csomag több nyílt forrású összetevőt húz be (Postgres, Auth, Realtime, Edge Runtime, API-kapu és mások). **A licenceiket nem vizsgáltam egyenként**; a Supabase hivatalos tárolóiban kell ellenőrizni |
| Cloudflare (Workers Static Assets, Tunnel) | a demó oldalai, a saját szerver kitétele | Szolgáltatás, a használatra a Cloudflare feltételei vonatkoznak |
| Caddy, cloudflared | a saját szerveres staging | Nyílt forrású programok; a licencet a saját tárolóikban kell ellenőrizni |
| GitHub (Actions) | CI, a kézi telepítés | Szolgáltatás |

## 7. Amit szándékosan nem tartalmaz

- **`kinyert_funkciok/`**: más cég alkalmazásából kinyert kód. A `.gitignore` kizárja, **nincs a repóban és a történetében sem** (ellenőrizve:
  `git ls-files` és `git log --all --name-only` is nulla találat), és nem is forrása a Zaba kódjának. Az átadási csomagba nem kerülhet.
- Fizetési szolgáltató SDK-ja (Barion, Stripe, SimplePay): a demó szimulált szolgáltatót használ, az éles adapter az MVP dolga.
- Analitika, hirdetési vagy nyomkövető SDK: **nincs** az appban.
