# Szerződés-melléklet vázlata (ügyvédnek)

> **Ez nem szerződés és nem jogi tanács.** A lap egy **szerkezetet** és **kérdéseket** ad az ügyvédnek ahhoz a mellékletekhez, amelyek a Zaba demó (0. fázis) és egy esetleges
> MVP megrendeléséhez tartozhatnak. A jogi szöveget ügyvéd írja és felel érte. Ahol a lap valamit ténynek állít, ott a forrása a repóban ellenőrizhető; ahol jogi
> következmény lenne, ott csak a kérdés áll.

A „fejlesztő" a Zaba készítője, a „megrendelő" a demót kapó fél. Hogy ki a szerződő fél (cég vagy magánszemély), és mely jog alatt köt szerződést, a lap **nem tudja**: ezek a vázlat első nyitott kérdései.

## 1. A szerződés tárgya és a fázisok

Tények:

- A 0. fázis egy **bemutatható demó**: a vásárlási út végig megy, de a fizetés szimulált, az adatok kitaláltak, és éles használatra nem alkalmas ([`known-gaps.md`](known-gaps.md)).
- A demó architektúrája az MVP-be bővítéssel vihető ([`architecture.md`](architecture.md)); az MVP lépéseinek javasolt sorrendje a [`known-gaps.md` 7. részében](known-gaps.md).

Kérdés az ügyvédnek: **egy szerződés vagy két** (demó, MVP)? Az MVP-t opcióként, külön megállapodással érdemes-e kezelni? Mi a viszony a demó díja és az esetleges MVP között (beszámítás, kizárás)?

## 2. Szállítandók és átvétel

A leszállítandók tételes listája a [`handover.md`](handover.md)-ben van. Alapja: a forráskód egy **megnevezett commit**, a [`docs/`](.) dokumentumok, a telepített demó környezet, és a hozzáférések átadása.

Kérdések: Melyik commit az „átadott verzió"? Mi az **átvétel feltétele**? A fejlesztő javaslata, amit a megrendelő elfogadhat vagy módosíthat: a [`test-checklist.md`](test-checklist.md) végigmenése a megrendelő telefonjain,
a CI zöld, és a [`handover.md`](handover.md) listájának teljesülése. Mi legyen a hibajavítás és a **garancia**, ha az átvételi próba hibát talál?

## 3. Szellemi tulajdon és felhasználási jog

Tények:

- A repóban **nincs licencfájl** a saját kódhoz ([`licenses.md`](licenses.md)); a felhasználás feltételeit tehát a szerződés rögzíti.
- Az átadás része a forráskód, a migrációk, a tesztek, a dokumentáció és az építéshez szükséges scriptek.

Kérdések: **Teljes jogátruházás** vagy **kizárólagos / nem kizárólagos felhasználási jog**? Milyen terjedelemben (módosítás, továbbfejlesztés, harmadik félnek átadás, alvállalkozó)? Terület, időtartam, ellenérték?
Mi marad a fejlesztőnél (**általános know-how, saját eszközök** például a `tool/` segédscriptek, újrahasznosítható minták)? Az **MVP-ben készülő** új kód ugyanígy kezelendő-e?

## 4. Harmadik féltől származó anyagok

Tény: a leltár a [`licenses.md`](licenses.md)-ben van (Dart és Flutter csomagok BSD-3-Clause, MIT és Apache-2.0 alatt; két betű SIL OFL 1.1 alatt; 41 Wikimedia Commons fotó: CC0, közkincs és CC BY; fejlesztői eszközök).

Kérdések:

- Hogyan jelenik meg a megrendelő felé, hogy a **közlemények és licencszövegek megőrzése** a terjesztésnél kötelezettség (a Flutter licenc-nyilvántartásának megjelenítése, az OFL-szövegek, a CC BY névjelzés)? Az app ma csak a fotók névjelzését mutatja.
- A **stock fotókat** a megrendelőnek az éles üzem előtt a sajátjaira kell cserélnie? Ki viseli a felelősséget a CC BY névjelzés hibájáért?
- A **szolgáltatások** (Supabase, Cloudflare, GitHub, a majdani fizetési szolgáltató) feltételeit a megrendelő a **saját fiókjában** köti: ki vizsgálja át őket, és mit állíthat a fejlesztő róluk?

## 5. Eredet-nyilatkozat

Tények ([`decisions.md`, Eredet](decisions.md#eredet-provenance)):

- A kód önállóan készült, és **nem tartalmaz, nem használ forrásként harmadik fél védett kódját**. Az ilyen referenciaanyag a repón kívül van, a `.gitignore` kizárja; ellenőrizve: a nyomon követett fájlok és a teljes commit-történet között **nincs** ilyen.
- A felület elrendezésének forrása a tulajdonos által átadott, **saját munkaként megnevezett** „Falatozó" Flutter demó; a kódja nem lett átvéve, a Zaba architektúrájában újraíródott. A tulajdonos ezt a fejlesztői beszélgetésben megerősítette (2026-10-21).

- A **logó** terve a tulajdonos által adott kép; az SVG ennek újrarajzolása. A kép eredetét (ki készítette, milyen eszközzel) a tulajdonos rögzítse. A logó és a „Zaba” név **védjegy- és hasonlósági vizsgálata nem történt meg.**

Kérdések: Milyen **mértékű nyilatkozat** adható („legjobb tudomásom szerint", a vizsgált körre)? A „Falatozó" saját munka voltát **külön, írásos nyilatkozatban** érdemes-e rögzíteni, és ki írja alá? Szükséges-e, hogy a megrendelő is nyilatkozzon valamiről (például a saját átadott anyagairól)?

## AI-val készült kód

**Tényállás.** A repó kódját jelentős részben **AI-asszisztens (Anthropic Claude Code)** írta a fejlesztő utasításai szerint; a commitokban ez társszerzői sorként szerepel (`Co-Authored-By: Claude …`), és az átadásnál is így kell
bemutatni. A fejlesztő határozta meg a feladatot, a lépéseket és az elfogadást minden lépés végén; az egyes kódrészek átnézésének mértékéről a fejlesztő tud nyilatkozni, ezt a lap nem állítja.
A helyességet **tesztek** fedik (Dart, pgTAP, HTTP, Node; a futtatásuk a [`README.md`](../README.md)-ben van), a titokmentességet és az eredetet **ellenőrzések** (gitleaks a teljes történeten, a tiltott mappa hiánya).

**Bizonytalanságok** (nem állítások, kérdések):

1. **Szerzői jogi védettség.** Hogy az ilyen módon létrejött kód milyen mértékben szerzői jogi védelem tárgya, jogrendszerenként eltérhet, és **bizonytalan** lehet. Mit jelent ez a **jogátruházásra** (mit lehet átruházni, ha egy rész nem védett)? Hogyan
   fogalmazandó a szerződés úgy, hogy ne ígérjen többet, mint ami a fejlesztőt megilleti?
2. **Szavatosság.** Nem zárható ki, hogy az AI kimenete hasonlít harmadik fél kódjára. Mekkora a kockázat, és **ki viseli**? Mely ellenőrzéseket vállalja a fejlesztő (lásd a lehetséges lépéseket lent)?
3. **Az eszköz feltételei.** Az AI-eszköz szolgáltatójának feltételei a **kimenet használatáról és tulajdonáról** mit mondanak? Ezt a szerződés előtt el kell olvasni és a szerződéssel összevetni; a lap nem állítja a tartalmát.
4. **Tájékoztatás.** A megrendelőt tájékoztatni kell az AI használatáról, és milyen formában (szerződéses nyilatkozat, a `README`, az átadási lista)?
5. **Adatvédelem a fejlesztés alatt.** A repóban és a tesztekben kitalált adat van. Az MVP-ben, ahol már valós adat lesz, külön szabályozni kell, hogy mi kerülhet az AI-eszköz elé (például éles adatbázis-kivonat, titkok, ügyféladat).

**Lehetséges csökkentő lépések** (a fejlesztő vállalhatja, a szerződés rögzítheti): kódátnézés az átadás előtt; a függőségi és licenc-leltár naprakészen tartása ([`licenses.md`](licenses.md), a `tool/licenses.py`); kód-hasonlósági vizsgálat egy erre alkalmas eszközzel a
kritikus modulokra; az eredet-ellenőrzések (gitleaks, tiltott mappa) futtatása az átadáskor; a tesztek és a CI átadása.

## 6. Adatvédelem és adatkezelői szerepek

Tények: a demóban **csak kitalált adat** van, valós személyes adat nem; a tárolt adatok tételes leltára a [`known-gaps.md` 3. részében](known-gaps.md). Kártyaadatot a rendszer nem kap és nem tárol.

Kérdések: Az MVP-ben ki az **adatkezelő** és ki az **adatfeldolgozó** (a megrendelő, a fejlesztő, a Supabase, a Cloudflare)? Kell-e **adatfeldolgozói megállapodás**, és kivel? Hozzáfér-e a fejlesztő az éles adatokhoz az átadás után (ha igen, milyen feltétellel)?
Ki készíti az **adatkezelési tájékoztatót**, ki felel az érintetti kérések (hozzáférés, törlés, export) kiszolgálásáért, és mi az **incidenskezelés** rendje? Hol tárolódhatnak az adatok (régió)?

## 7. Fizetés, számlázás, adózás

Tények: a fizetés a demóban szimulált; az éles szolgáltatót az MVP elején kell kiválasztani; számlázó kód nincs; az ÁFA-kulcsok a demóban illusztratívak ([`payment-flow.md`](payment-flow.md), [`known-gaps.md`](known-gaps.md)).

Kérdések: Ki köti a **szerződést a fizetési szolgáltatóval**, és kinek a nevén fut a fiók? A kártyaadatok kezelésének modellje (a szolgáltató oldala vagy az app) a szolgáltató kiválasztásakor dől el: ki vizsgálja a követelményeit?
A számlázás és az ÁFA a **könyvelő** feladata: milyen formában vesz részt a projektben?

## 8. Üzemeltetés, támogatás, költségek

Tények: a demó **ingyenes szinteken** fut (Supabase Free: egy hét inaktivitás után szünetel; Cloudflare), a `keepalive.yml` a szünetelést hárítja; a saját szerveres staging fejlesztői, szolgáltatási szint nélkül ([`demo-environment.md`](demo-environment.md)).

Kérdések: Ki **üzemelteti** az éles rendszert, mi a **szolgáltatási szint** és a hibajavítás időtartama? Ki fizeti a hosting- és fiókköltségeket (Supabase fizetős csomag, Cloudflare, domain, Apple Developer és Google Play fiók)? A függőségek és a szolgáltatók
**változásai** (például a Supabase régi API-kulcsainak 2026 végi kivezetése) kinek a feladata? Van-e karbantartási megállapodás az átvétel után, és meddig tart a garancia?

## 9. Az átadás menete, titkok, hozzáférések

A tételes lista a [`handover.md`](handover.md)-ben van. Kérdések: Mikor és hogyan **szűnnek meg a fejlesztő hozzáférései** (GitHub, Supabase, Cloudflare, domain, kulcstár)? Ki őrzi az Android **aláíró kulcsot**, és mi történik, ha elvész?
A titkok **újragenerálását** (a megrendelő fiókjaiban) átvételi feltételnek kell-e tekinteni?

## 10. Általános, jogászra bízott részek

Díj és fizetési ütemezés, módosítások kezelése, felelősség és annak korlátozása, titoktartás, alvállalkozók (az AI-eszköz szolgáltatója ilyennek minősül-e), szerződésszegés és felmondás, alkalmazandó jog és jogviták. A lap ezekhez **nem ad tartalmat**.

## Mellékletek (a repóból)

[`handover.md`](handover.md) (átadási lista) · [`known-gaps.md`](known-gaps.md) (hiányok, MVP-lépések, adatleltár) · [`licenses.md`](licenses.md) (licenc-leltár) · [`env-vars.md`](env-vars.md) (titkok és beállítások) ·
[`architecture.md`](architecture.md) · [`decisions.md`](decisions.md) (eredet, döntések) · [`test-checklist.md`](test-checklist.md) (átvételi próba) · [`image-credits.md`](image-credits.md).

## Amit a megrendelőtől kell kérdezni

- Ki a szerződő fél, és mely jog alatt?
- Kereskedelmi célú használat és célpiac (ország, nyelv)?
- Ki üzemeltet az átadás után, és milyen költségkereten belül?
- Van-e saját jogásza és könyvelője, vagy a fejlesztő hozza őket?
