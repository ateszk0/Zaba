# Ismert hiányok és az MVP lépései

> **A Zaba mai állapota egy bemutatható demó, éles használatra nem alkalmas.** Ami itt hiányzik, az szándékosan hiányzik a demóból, vagy még nem készült el.
> A lap három dolgot tesz egy helyre: mi hiányzik, **miért számít**, és mit kell tenni vele. A jogi és adózási pontoknál **nem állítok semmit**, csak a kérdést
> teszem fel; ezekre ügyvéd és könyvelő felel.

Jelölés a „Ki dönt" oszlopban: **M** = a megrendelő üzleti döntése, **J** = ügyvéd, **K** = könyvelő, **F** = fejlesztői feladat.

## 1. Üzleti funkciók

| Hiány | Miért számít | Mi kell hozzá | Ki |
|---|---|---|---|
| **Éles fizetés.** A demó szimulált szolgáltatót használ | Valódi pénz csak valódi szolgáltatón át mozoghat | Szolgáltató kiválasztása (Barion, Stripe, SimplePay: az összehasonlítást az MVP elején a hivatalos dokumentációjuk alapján kell elvégezni, itt nem döntöttem), szerződés vele, adapter a `PaymentProvider` interfész mögé ([`payment-flow.md`](payment-flow.md)) | M, F |
| **Valódi visszatérítés.** Lemondáskor a státusz azonnal `refunded` | A kifizetett összeget a szolgáltatótól kell visszakérni | `refunds` migráció, a szolgáltató felé hívás | F |
| **Lemondás közben érkező sikeres fizetés.** A demó figyelmen kívül hagyja (`order_not_pending`) | Valódi szolgáltatónál ez visszatérítést igényel | Kezelés az adapterben, kézi vagy automatikus rendezés | F |
| **Számlázás.** Kód nincs, csak a hely | Hogy mi kötelező és hogyan (a NAV Online Számla és a számla tartalma) a megrendelő működési formájától függ | Könyvelői egyeztetés, számlázó adapter, `invoices` migráció | K, M, F |
| **ÁFA-kulcsok.** A demó minden terméket 27 %-kal számol, ez illusztráció | Rossz kulcs rossz számlát jelent | A kulcsokat termékenként a könyvelő adja meg (`products.vat_rate_percent`) | K |
| **Push értesítés, e-mail, SMS.** A demóban csak appon belüli sáv és lista, ami nem marad meg | Valódi rendelésnél a vásárlónak az app bezárva is értesülnie kell | `NotificationSender` új megvalósítása, `push_tokens`, e-mail-szolgáltató (SMTP) | F |
| **Készletfoglalás.** Az `inventory` tábla létezik, a logika nincs | Elfogyott ételre is lehet rendelni | Foglalás a `place_order`-ben, az étlap „elfogyott" állapota | M, F |
| **Mentett címek, profilszerkesztés.** Az adatbázis előkészített (`addresses`, `profiles.phone`), **az app nem használja**; a cím újratöltés után elvész | Kényelem, ismétlődő rendelések | Képernyők, a mentett címek RLS-sel | F |
| **Kiszállítás-kezelés.** A `deliveries` tábla létezik, felület nincs; nincs futár-szerepkör, térkép, élő követés | A kiszállítás ma csak egy állapotjelző | Futár-modell, felület, esetleg külső szolgáltatás | M, F |
| **Admin bővítés.** Nincs étlap- és árszerkesztés, képfeltöltés, nyitvatartás- és zónakezelés, statisztika, exportálás | Ma ezeket csak SQL-lel lehet módosítani | Admin képernyők a meglévő jogosultsági modellre; képeknél Supabase Storage | M, F |
| **Munkatársak kezelése.** Csak parancssori eszköz (`tool/create_staff_user.py`) | Nem a megrendelő üzemeltetője fog parancssort használni | Kezelőfelület az `admin_users` táblán | F |
| **Szándékosan kimaradt:** kupon, borravaló, elsőbbségi kiszállítás, kedvencek, több étterem | A tulajdonos „Falatozó" demójában voltak, a Zaba demójába nem kerültek át | A megrendelő döntése, hogy kell-e | M |

## 2. Belépés és fiók

| Hiány | Miért számít | Mi kell hozzá | Ki |
|---|---|---|---|
| **E-mail megerősítés kikapcsolva** (a demó nem küld levelet) | Bárki regisztrálhat bárki e-mail-címével | SMTP-szolgáltató, megerősítés bekapcsolása | F |
| **Elfelejtett jelszó nincs** | Levelezés nélkül nem működik | Ugyanaz az SMTP | F |
| **A „már van fiók ezzel a címmel" üzenet elárulja, hogy egy cím regisztrált-e** | Felhasználó-felderítést tesz lehetővé | Megerősítéssel elkerülhető | F |
| **Fiók törlése nincs.** A `orders.user_id` `on delete restrict`: a rendelésnek túl kell élnie a fiókot | Az érintett kérheti az adatai törlését; a törlés és a megőrzési kötelezettségek viszonyát nem én döntöm el | Anonimizáló függvény a fiókon (és a rendelés személyes mezőin), a szabályok jogi egyeztetése | J, K, F |
| **Apple és Google belépés nincs** | Mobilfelhasználók gyakran várják; az áruházak belépésre vonatkozó szabályait az MVP-ben, a beadás előtt ellenőrizni kell | Ha kell, a Supabase támogatja | M, F |
| **A demó fiók az appba van fordítva** (`DEMO_EMAIL`, `DEMO_PASSWORD`) | Szándékosan nyilvános, de éles buildbe nem való | A `config/<env>.json`-ból kivenni | F |
| **A belépések nincsenek naplózva** (az `audit_log` csak az állapotváltásokat rögzíti) | Visszakövethetőség | Auth-naplózás, megőrzési idő | F, J |

## 3. Jogi, adatvédelmi és megfelelőségi kérdések

Semmi sincs eldöntve vagy állítva; ez a **kérdéslista az ügyvédnek és a könyvelőnek**. A [`contract-annex-outline.md`](contract-annex-outline.md) a szerződéses részét
tartalmazza.

| Kérdés | Háttér |
|---|---|
| **Kell-e és milyen tartalmú ÁSZF, adatkezelési tájékoztató, impresszum, elállási jogról szóló tájékoztatás** az éles szolgáltatáshoz? Az appban egyik sincs | Nincsenek linkelve a regisztrációnál és a láblécben sem |
| **Mi a személyes adatok kezelésének jogalapja és megőrzési ideje** az egyes adatokra? | Lásd az alábbi leltárt |
| **Kell-e hozzájárulás vagy tájékoztatás** a böngésző tárolójának (`localStorage`) használatáról? | A munkamenet és a kosár a böngészőben tárolódik; analitika és hirdetési süti nincs |
| **Adatfeldolgozói megállapodások** a Supabase-zel és a Cloudflare-rel; **hol tárolódnak az adatok** (a Supabase projekt régiója: Frankfurt)? | A szolgáltatók feltételeit nem én vizsgáltam |
| **Adatexport és törlés folyamata** az érintett kérésére | Lásd a „Fiók törlése nincs" sort |
| **Az allergén-tájékoztatás és az ÁFA-kulcsok** jogszerű kezelése | A demó adatai illusztratívak, az app és a README jelzi |
| **Kell-e licenc-oldal az appban** (a Flutter `showLicensePage`), és a betűtípusok OFL-szövegének kísérnie kell-e a terjesztést? | A licenceket lásd [`licenses.md`](licenses.md); az app ma nem mutat licenc-oldalt, és az OFL-szövegek nincsenek az app csomagjában |
| **Az AI-val írt kód szerzői jogi helyzete és a szerződéses felelősség** | Lásd [`contract-annex-outline.md`](contract-annex-outline.md#ai-val-készült-kód) |
| **Fogyasztóvédelmi és az ételrendelésre vonatkozó egyéb előírások** | Ezek körét nem ismerem fel teljes biztonsággal; a jogász jelölje ki |

**Mit gyűjt ma az app** (a tájékoztató alapja; tételes, hogy ne maradjon ki semmi):

| Adat | Hol van | Megjegyzés |
|---|---|---|
| E-mail-cím | Supabase Auth | belépéshez |
| Név (nem kötelező, legfeljebb 200 karakter) | `profiles.full_name` | regisztrációkor adható meg |
| Szállítási cím (irányítószám, utca) és megjegyzés (legfeljebb 500 karakter) | `orders`; a mentett cím az appban csak memóriában | a rendelés része, a kiszállításhoz kell |
| Rendelési előzmény és állapotváltások | `orders`, `order_items`, `order_status_history` | a munkatárs látja a rendeléseket; az `audit_log`-ot csak az `admin` szerepkör |
| Fizetési státusz | `payments`, `payment_events` | **kártyaadatot a rendszer nem kap és nem tárol**: a kártyaszám az appban marad, a szervernek csak a kimenet megy. (A demóban a kártyaszám valódi sem kell: a szolgáltató szimulált) |
| Munkamenet és kosár | a böngésző `localStorage`-a, Android-on a `shared_preferences` | a munkamenet-token és a `zaba.cart.v1` kulcs |
| IP-cím és kérésnaplók | a Supabase és a Cloudflare üzemi naplói | az alkalmazás nem gyűjt belőle semmit, de a szolgáltatók naplóznak |
| Telefonszám | `profiles.phone` | **az app nem kéri és nem tölti**; a mező az MVP-nek van előkészítve |

A **harmadik felek**: Supabase (adatbázis, belépés), Cloudflare (hosting, a saját szerver kitétele), GitHub (a forráskód és a CI). Az app futás közben **más külső szerverrel nem érintkezik**
(ellenőrizve: böngészőben a teljes vásárlási út csak az oldal és a Supabase címét éri el; analitikai és hirdetési SDK nincs). Nyilvános tárhely (Supabase Storage) **nincs használatban**, a termékképek
az app csomagjában vannak.

## 4. Biztonság és üzemeltetés

| Hiány | Miért számít | Mi kell hozzá | Ki |
|---|---|---|---|
| **Nincs saját alkalmazás-szintű rate limiting, bot- és visszaélés-védelem** a regisztrációra és a rendelésre. A Supabase Auth beépített korlátai vannak, CAPTCHA nincs | Tömeges hamis regisztráció és rendelés | Korlátok a függvényekben, CAPTCHA (a Supabase támogatja a hCaptchát és a Turnstile-t) | F |
| **Admin 2FA nincs**, jelszópolitika csak a Supabase alapja (legalább 8 karakter) | Az admin a legérzékenyebb belépés | Többfaktoros belépés a munkatársaknak | F |
| **A függvények CORS-fejléce `*`** (`Access-Control-Allow-Origin`) | A függvények maguk hitelesítenek (token, aláírás), de szigorúbb is lehet | Az app eredeteire szűkíteni | F |
| **Monitoring, hibakövetés, riasztás nincs** | Egy leállást nem veszel észre | Hibakövető és üzemi riasztás | F |
| **Mentés és visszaállítási eljárás nincs kipróbálva** | Adatvesztés ellen | Fizetős Supabase-csomag mentéssel, **visszaállítási próba**; a Free csomag lehetőségeit a Supabase aktuális dokumentációja szerint kell ellenőrizni | F |
| **A Free csomag egy hét inaktivitás után szünetel** (a `keepalive.yml` ezt hárítja) | Éles szolgáltatásnál elfogadhatatlan | Fizetős csomag (a szünetelés megszűnik) | M |
| **Biztonsági átvizsgálás nem történt** | Éles indulás előtt kell | Külső átvizsgálás / penteszt | M |
| **A függőségek frissítési rendje nincs kialakítva** | A `flutter pub outdated` három frissíthető és több, a korlátok miatt beragadt csomagot jelez; a `npm audit` ma 0 | Rendszeres frissítés (pl. Dependabot) és a tesztek futtatása utána | F |
| **A Supabase régi kulcsai 2026 végéig kivezetődnek** | A függvények már az újakat részesítik előnyben (régi tartalékkal), de a kliens és a szerver beállítása ellenőrzendő | Átállás az új (`sb_publishable_`, `sb_secret_`) kulcsokra mindenhol, és a saját szerveres Realtime-hoz külön ellenőrzés | F |
| **A saját szerveres staging nincs a Proxmoxon kipróbálva**, és nincs szolgáltatási szint (otthoni net és áram) | Éles szolgáltatásra nem alkalmas | Felhős üzemeltetés az élesre | M |
| **A munkamenet weben `localStorage`-ban él** (a `flutter_secure_storage` weben nem használható) | A böngésző tárolója kevésbé védett | Mobilon Keychain/Keystore az MVP-ben | F |

## 5. Mobil és platform

| Hiány | Miért számít | Mi kell hozzá | Ki |
|---|---|---|---|
| **Nincs iOS app** (a webes változat iPhone-on is megy) | App Store-ban csak natív app jelenhet meg | Apple Developer fiók, aláírás, TestFlight | M, F |
| **Android: helyőrző `applicationId` (`hu.zaba.zaba`) és demó aláíró kulcs** | Az éles azonosítót és kulcsot a tulajdonos választja; a kulcs elvesztése frissítés-képtelenné tesz | Saját azonosító, saját kulcstár (a repón kívül, mentve) | M, F |
| **Áruházi beadás (Google Play)** nincs | Az áruház saját kötelező elemeket kér (például adatvédelmi nyilatkozat) | A beadás előkészítése | M, F |
| **Az ikon és a betöltőképernyő helyőrző, a logó nincs kész** | Arculat | A végleges logó (k lépés) | M |
| **Telefonos ellenőrzés még nem futott** valódi eszközön | iPhone Safari, Android Chrome, az APK ismeretlen kockázatok | A [`test-checklist.md`](test-checklist.md) végigmenése | M |
| **A `viewport-fit=cover` kikerült** (a Flutter web nem veszi át a safe-area értékeket); a hatása iPhone-on **nem tesztelt** | Az alsó sáv a home-jelző alá kerülhetne | A listában az A3, A6, F2 sor | F |
| **Emoji és nem csomagolt írásjegyek dobozként jelennek meg** (a CSP tiltja a külső betűt) | A vásárló megjegyzésében előfordulhat | Betűcsomag bővítése vagy a CSP átgondolása | F |
| **Képernyőolvasó-támogatás nem tesztelt** (a kontraszt tesztelt: WCAG AA/AAA) | Hozzáférhetőség | Teszt képernyőolvasóval | F |
| **Csak magyar nyelv** | | ARB-fájlok bővítése | M, F |

## 6. Minőség és ellenőrizetlen pontok

Ezek **nem futottak** (nincs hozzáférésem hozzájuk), tehát „nem tesztelt":

- A felhős **Supabase projekt** és a **Cloudflare** telepítése (`setup-supabase.sh`, `deploy-web.sh`, a két workflow). Helyben a ténylegesen kiadott fájlokon és fejléceken próbáltam.
- A **Proxmox VM** és a **Cloudflare Tunnel**, benne a Realtime WebSocket átmegy-e. Tartalék az 5 mp-es lekérdezés.
- **iPhone Safari, Android Chrome, valódi Android készülék.** Az Android app egy emulátoron futott.
- **Terheléses teszt** nincs; két egyidejű rendelés a kapacitás utolsó helyére nincs külön terhelés alatt kipróbálva.
- Az **end-to-end** böngészős tesztek nem részei a repónak (a helyi ellenőrzéshez használt scriptek a fejlesztő gépén voltak).
- Az integrációs tesztek a CI-ban a helyi stacken futnak, éles projekten nem.

## 7. Javasolt sorrend az MVP-hez

Javaslat, a megrendelővel egyeztetendő. A sorrend a kockázatot követi: ami nélkül nem szabad élesben indulni, megy előre.

1. **Jogi és adatvédelmi alap** (3. rész) ügyvéddel és könyvelővel, párhuzamosan az összes többivel, mert ez a leghosszabb átfutású.
2. **Éles fizetés és visszatérítés** az 1. részből: szolgáltató kiválasztása, adapter, a webhook átállítása.
3. **Fiók:** e-mail megerősítés, elfelejtett jelszó, fiók törlése (anonimizálás).
4. **Üzemeltetés:** fizetős Supabase csomag mentéssel és visszaállítási próbával, monitoring, a saját domain, a titkok újragenerálása a megrendelő fiókjaiban ([`handover.md`](handover.md)).
5. **Admin bővítés:** étlap- és árszerkesztés, képek, munkatárs-kezelés, 2FA.
6. **Számlázás, push értesítés**, majd az **iOS app** és a **Google Play** beadás.
7. **Biztonsági átvizsgálás** az éles indulás előtt.
