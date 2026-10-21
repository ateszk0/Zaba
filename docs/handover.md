# Átadási lista

Ez a lap azt rögzíti, **mi adódik át**, mit kell a megrendelőnek a **saját fiókjaiban újracsinálnia** (mert titok vagy fiókhoz kötött), mit kell **cserélni**, mielőtt a demóból bármi éles lenne, és hogyan
ellenőrizhető az átadás. A jogi háttérkérdések a [`contract-annex-outline.md`](contract-annex-outline.md)-ben vannak, a hiányok az [`known-gaps.md`](known-gaps.md)-ben.

## 1. Mi adódik át

| Tétel | Hol van | Megjegyzés |
|---|---|---|
| **Forráskód** (app, backend, telepítő eszközök, tesztek) | a Git tároló (`github.com/ateszk0/Zaba`, privát); ajánlott egy **megnevezett verzió** (git címke) az átvételkor | A címkét az átvételkor te hozod létre és nevezed meg; a lap nem hoz létre ilyet |
| **Dokumentáció** | [`docs/`](.) és a [`README.md`](../README.md) | indexe: lent, a 6. részben |
| **Adatbázis-séma és kiinduló adatok** | `supabase/migrations/`, `supabase/seed/` | minden környezet ebből épül, nincs kézi lépés |
| **Szerveroldali függvények** (fizetés) | `supabase/functions/` | |
| **Demó környezet** | Cloudflare (3 oldal) és egy Supabase projekt, ha a telepítés megtörtént | **fiókhoz kötött**: lásd a 2. részt |
| **Android app** | a letöltő oldal APK-ja | demó kulccsal aláírva, **helyőrző azonosítóval** |
| **CI és telepítő workflow-k** | `.github/workflows/` | a titkok a GitHub fiókban vannak, nem a tárolóban |
| **Licenc-leltár** | [`licenses.md`](licenses.md), `tool/licenses.py` | |
| **Átvételi próba** | [`test-checklist.md`](test-checklist.md) | |

Ami **nem** adódik át, és nem is lehet: a fejlesztő gépén lévő helyi adatbázisok, a fejlesztő helyi kulcstára (`~/.zaba-keys/`), a fejlesztői fiókok tokenjei. Más cég alkalmazásából kinyert referenciaanyag **soha** nem része az átadásnak
(lásd az 5. részt).

## 2. Amit a megrendelő a saját fiókjaiban csinál meg

**A titkokat és a fiókokhoz kötött dolgokat nem lehet „átvenni": újra kell csinálni.** Aki a régit ismerte (a fejlesztő), annak a kulcsai az átadás után érvénytelenek legyenek.

| Mit | Hogyan | Hol van leírva |
|---|---|---|
| **GitHub tároló** | tulajdonjog átadása, vagy a tároló másolása a megrendelő szervezetébe; az Actions titkok újak | [`env-vars.md`](env-vars.md), 8. rész |
| **Supabase projekt** | új projekt a megrendelő szervezetében (EU régió); a migrációk, a kiinduló adatok és a függvények a repóból telepíthetők; vagy a projekt átadása a Supabase fiókbeállításai szerint (az aktuális dokumentáció szerint) | [`demo-environment.md`](demo-environment.md) |
| **Supabase kulcsok és adatbázis-jelszó** | a megrendelő projektjében újak; a fejlesztőé semmi sem marad érvényben | [`env-vars.md`](env-vars.md), 4–5. rész |
| **Fizetési webhook-titok** | új, erős érték; **éles szolgáltatónál a szolgáltató titka** | [`payment-flow.md`](payment-flow.md) |
| **Cloudflare fiók, oldalak, token** | a megrendelő fiókjában; saját `workers.dev` aldomain vagy saját domain | [`demo-environment.md`](demo-environment.md) |
| **Domain és DNS** | a megrendelő nevén | |
| **Android azonosító és aláíró kulcs** | a megrendelő a **saját `applicationId`-t** és **saját kulcstárat** választ; a kulcstárat a repón kívül, **mentve** őrzi (elvesztésekor az app nem frissíthető) | [`env-vars.md`](env-vars.md), 6. rész |
| **Apple Developer és Google Play fiók** | a megrendelő nevén, ha mobil áruházi megjelenés kell | [`known-gaps.md`](known-gaps.md), 5. rész |
| **Munkatársi fiókok** | a demó munkatársi fiókok (`konyha@zaba.example`, `admin@zaba.example`) törlése; valós munkatársak felvétele erős jelszóval | `tool/create_staff_user.py` |
| **A demó vásárlói fiók és a tesztfiókok** | törlés, vagy a jelszó cseréje (a demó jelszava az appba van fordítva) | [`demo-environment.md`](demo-environment.md), E rész (SQL) |

**Mit rotálj, ha a fejlesztő gépén bármikor volt az éles érték:** minden, ami az [`env-vars.md`](env-vars.md)-ben **T**-vel van jelölve. A legbiztosabb út az **újragenerálás** a megrendelő fiókjaiban, nem a régi értékek átvétele.

## 3. Mi helyőrző vagy demó, és cserélendő

| Mit | Mivé | Hol |
|---|---|---|
| `applicationId` `hu.zaba.zaba` | a megrendelő végleges azonosítója | `app/android/app/build.gradle.kts`, az `AndroidManifest.xml` |
| Android aláíró kulcs (demó) | a megrendelő saját kulcsa | `tool/android/create_demo_keystore.sh` a mintája |
| Logó és ikonok (a Z a robogóval) | **kész**, de a megrendelő saját arculatára cserélhető: egyetlen SVG a forrás (`app/assets/brand/zaba-mark.svg`), `python3 tool/brand/make_icons.py` rajzol belőle mindent (webes és Android ikonok, adaptív ikon, az appon belüli jel). A logó **védjegy- és hasonlósági vizsgálata nem történt meg** | `app/web/icons`, `app/android/…/mipmap-*`, `app/assets/brand/` |
| A 41 stock fotó (Wikimedia) | a megrendelő saját fotói | `app/assets/images/products/`, [`image-credits.md`](image-credits.md); 4 terméknek ma nincs fotója |
| **DEMÓ szalag, a profil „Ez egy demó" kártyája, a regisztrációs figyelmeztetés** | éles buildben **nem jelenhet meg** | `demoBanner`, `profileDemo…`, `authRegisterDemoNote` az `app_hu.arb`-ban; a `demo_banner.dart` |
| **Szimulált fizetés** (`FakePaymentProvider`, a három Edge Function) | az éles szolgáltató adaptere | [`payment-flow.md`](payment-flow.md), [`architecture.md`](architecture.md) |
| **Demó fiók gomb** (`DEMO_EMAIL`, `DEMO_PASSWORD`) | éles buildből ki | a `config/<env>.json`-ban nem szerepelhet |
| **Admin demó gomb** (`ADMIN_DEMO_*`) | **soha** nem lehet a megrendelő által megnyitható buildben | ugyanott |
| Étlap, árak, szállítási zónák és nyitvatartás (kiinduló adatok) | a valódi étlap és üzleti szabályok | `supabase/seed/`; az ÁFA-kulcsot és az allergén-adatot a könyvelő / szakember adja meg |
| E-mail megerősítés kikapcsolva | bekapcsolva, SMTP-vel | [`known-gaps.md`](known-gaps.md), 2. rész |
| A függvények CORS-fejléce `*` | az app eredeteire szűkítve | `supabase/functions/_shared/http.ts` |
| Az oldalak nevei (`zaba-app`, `zaba-admin`, `zaba-apk`) és a `workers.dev` címek | a megrendelő nevei és címei | `deploy/demo/wrangler.*.jsonc` |
| A Supabase Free csomag | fizetős csomag (szünetelés nélkül, mentéssel) | [`known-gaps.md`](known-gaps.md), 4. rész |

## 4. Átadás előtti ellenőrzések

Futtasd őket a tároló gyökeréből; mindegyik mellett az **elvárt eredmény** áll. (A kimenetek a lap írásakori állapotról, a 2026-10-21-i lépés végéről valók.)

| Mit ellenőriz | Parancs | Elvárt |
|---|---|---|
| Nincs kulcs, jelszófájl a nyomon követett fájlok közt | `git ls-files \| grep -iE '\.(jks\|keystore\|pem\|p12)$\|key\.properties\|(^\|/)\.env$'` | üres |
| Nincs titok a **teljes történetben** | `docker run --rm -v "$PWD:/repo" -w /repo zricethezav/gitleaks:latest git --config .gitleaks.toml --redact` | `no leaks found` (a CI is ezt futtatja) |
| A tiltott referenciaanyag nincs a tárolóban | `git ls-files \| grep -c kinyert` és `git log --all --name-only --pretty=format: \| grep -c kinyert` | mindkettő `0` |
| Az app és a tesztek rendben vannak | a `README.md` „Helyi indítás" és „Backend" szakasza szerint: `flutter analyze`, `flutter test`, pgTAP, smoke tesztek, `npm run test:functions`, integrációs tesztek | zöld |
| A licenc-leltár naprakész | `python3 tool/licenses.py --write`, majd `git diff docs/licenses.md` | nincs eltérés, és nincs `UNKNOWN` sor |
| Függőségek sebezhetőségei | `npm audit` | `found 0 vulnerabilities` |
| A telepített demó rendben van | `python3 tool/check_demo.py --app … --admin … --supabase-url … --key …` ([`demo-environment.md`](demo-environment.md), E rész) | minden sor `ok`, a végén: `The demo environment looks right.` |
| Az APK rendben van | `deploy/demo/build-apk.sh` (ellenőrzi az aláírást, az INTERNET jogosultságot és a méretet) | sikeres |
| A tesztadatok el vannak takarítva | a [`demo-environment.md`](demo-environment.md), E rész SQL-je | nincs `@example.test` fiók és rendelés |
| A telefonos próba lefutott | [`test-checklist.md`](test-checklist.md) | a ★ sorok rendben |

## 5. Az eredet rögzítése

Az átadásnál a megrendelő felé az alábbi tényeket kell közölni és (a [szerződés-melléklet vázlata](contract-annex-outline.md) szerint, ügyvéddel) rögzíteni:

- A kód önállóan készült, **nem tartalmaz és nem használ forrásként harmadik fél védett kódját** ([`decisions.md`, Eredet](decisions.md#eredet-provenance)); a `kinyert_funkciok/` mappa a tárolón kívül van, és a történetében sincs.
- A felület elrendezésének forrása a tulajdonos saját „Falatozó" demója (a tulajdonos megerősítette: 2026-10-21); a kódja nem lett átvéve.
- A kódot jelentős részben **AI-asszisztens írta** a fejlesztő irányításával; ennek szerzői jogi következményei bizonytalanok ([`contract-annex-outline.md`](contract-annex-outline.md#ai-val-készült-kód)).
- A harmadik féltől származó anyagok: [`licenses.md`](licenses.md).

## 6. Hol van az üzemeltetési leírás

| Feladat | Leírás |
|---|---|
| Helyi fejlesztői környezet indítása, tesztek | [`README.md`](../README.md) |
| A demó telepítése (Cloudflare, Supabase, APK), a demó előtti ellenőrzés | [`demo-environment.md`](demo-environment.md) |
| A saját szerveres környezet (Proxmox, Cloudflare Tunnel) | [`deploy/selfhost/README.md`](../deploy/selfhost/README.md) |
| Minden beállítás és titok | [`env-vars.md`](env-vars.md) |
| Hogyan áll össze a rendszer, hol bővíthető | [`architecture.md`](architecture.md) |
| Adatmodell, jogosultságok, az állapotgép | [`data-model.md`](data-model.md) |
| A fizetés folyamata, az éles szolgáltatóra váltás | [`payment-flow.md`](payment-flow.md) |
| Döntések, mérések, nyitott ellenőrzések | [`decisions.md`](decisions.md) |
| Hiányok, az MVP lépései, adatleltár | [`known-gaps.md`](known-gaps.md) |
| Licencek | [`licenses.md`](licenses.md), [`image-credits.md`](image-credits.md) |
| Telefonos ellenőrzés, előnézet a saját gépről | [`test-checklist.md`](test-checklist.md) |
| Szerződés-melléklet vázlata (ügyvédnek) | [`contract-annex-outline.md`](contract-annex-outline.md) |

Gyakori teendők: **új verzió telepítése** a `deploy/demo/deploy-web.sh app|admin|apk` és a `deploy/demo/setup-supabase.sh update`; **munkatárs felvétele** a `tool/create_staff_user.py`; **szünetelő Supabase projekt** helyreállítása a dashboardról
(a Free csomagon egy hét inaktivitás után szünetel; a dokumentáció szerint egy ideig visszaállítható).

## 7. Az átvételről szóló jegyzőkönyv (sablon)

```
Átadott verzió (git címke / commit):
Átadás dátuma:
Átadó:                          Átvevő:

Elvégzett ellenőrzések (4. rész):    [ ] mind rendben   Eltérések:
Átvételi próba (test-checklist ★):   [ ] rendben        Eltérések:
Fiókok és titkok újragenerálva (2. rész):
  [ ] GitHub  [ ] Supabase  [ ] Cloudflare  [ ] domain  [ ] Android kulcs  [ ] webhook-titok  [ ] munkatársi fiókok
A fejlesztő hozzáférései megszüntetve:      [ ] igen   Dátum:
Ismert hiányok (known-gaps.md) tudomásul véve:   [ ] igen
Az AI-val való készítés közölve (5. rész):       [ ] igen

Aláírás (átadó):                Aláírás (átvevő):
```
