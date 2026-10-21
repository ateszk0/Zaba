# Telefonos ellenőrző lista (i lépés)

Ezt a listát te futtatod valódi telefonokon. A gépemen csak egy Chromium és egy Android-emulátor volt, **iPhone Safarit, Android Chrome-ot és valódi
Android készüléket nem tudtam kipróbálni**, ezért minden, ami itt szerepel, addig "nem tesztelt", amíg te végig nem mész rajta.

**A ★ jelű sorokkal kezdd:** ezek a legkockázatosabb pontok (iPhone alsó sáv és billentyűzet, élő követés, kezdőképernyős mód). Ha időd csak
ennyire van, azok is megmondják, hogy a demó megmutatható-e.

## Hogyan jelezz vissza

Elég egy rövid üzenet, a sorok azonosítójával:

```
iPhone 13, iOS 18.x, Safari. A1 ok, A4 hiba: az alsó sáv a gesztus-sáv alá lóg. D4 hiba: a kártyaszám nem tördelődik.
```

Hibánál a legtöbbet egy **képernyőkép** segít (iPhone: oldalsó gomb + hangerő fel; Android: bekapcsoló + hangerő le), és az, hogy hányadik lépésnél
és milyen böngészőben történt. Ha valamit nem tudtál kipróbálni, azt írd: "nem próbáltam".

## 0. Előkészület: két út

| | **A. Saját gépről, ugyanazon a Wi-Fi-n** | **B. A felhős demó** |
|---|---|---|
| Mikor | Most azonnal, fiókok nélkül | Ha a [demó környezet](demo-environment.md) fel van telepítve |
| Cím | `http://<a gép címe>:8787` (app), `:8788` (admin) | `https://zaba-app.<fiók>.workers.dev`, `https://zaba-admin.<fiók>.workers.dev` |
| Biztonságos környezet (https) | **nem** (sima http) | igen |
| Mit nem lehet így kipróbálni | mobilhálózatot, az Android-appot (az Android alapból tiltja a sima http-t, a release app így nem érné el a helyi backendet), a "telepítés" ajánlatot | semmit, ez a végleges forma |

Az **Android-app (G rész) és a mobilhálózat (J rész) csak a B úton** próbálható. Minden más az A úton is.

### A út: a gépről

A gépen (a repó gyökeréből):

```sh
npx supabase start
python3 tool/create_demo_user.py --from-local
python3 tool/create_staff_user.py --from-local --role operator
tool/lan_preview.sh                 # kiírja a két címet; Ctrl-C-vel leáll
```

- A script az **egyetlen Wi-Fi címet** keresi ki (a VPN-t, a Dockert és a virtuális hidakat kihagyja). Ha több címet talál, kiírja, és
  megadhatod: `tool/lan_preview.sh 192.168.1.20`.
- A telefon **ugyanazon a Wi-Fi-n** legyen, mint a gép (ne vendég-hálózaton, ne mobilneten).
- Ha a telefon nem éri el az oldalt: a gép tűzfala a valószínű ok. `sudo ufw status`; ha fut, engedd be a helyi hálózatról a három portot, és a
  vizsgálat végén vedd vissza:
  ```sh
  sudo ufw allow from 192.168.1.0/24 to any port 8787,8788,54321 proto tcp     # a saját hálózatodra írd át
  sudo ufw delete allow from 192.168.1.0/24 to any port 8787,8788,54321 proto tcp
  ```
- Ez a helyi fejlesztői adatbázis, a helyi fejlesztői fiókokkal: **csak a saját telefonjaidhoz**, soha ne add másnak.

### Közös: a két szereplő

A legtöbb sor a **vásárló** (telefon). Az **E rész** két eszközt kér: a telefont és mellé egy gépet (vagy második telefont), amelyen az **admin oldal**
nyitva van, és munkatársként be van lépve (az A úton a "Belépés demó munkatársként" gomb; a B úton a munkatársi fiókkal, lásd a demó leírást).

### Mit jegyezz fel az elején

Telefon típusa, rendszer-verzió, böngésző (Safari / Chrome) és verziója, Wi-Fi vagy mobilnet. Ez minden hibajelentés alapja.

## A. Első benyomás (mindkét telefonon)

| # | Mit csinálj | Mit kell látnod |
|---|---|---|
| A1 | Nyisd meg az app címét (új, privát lapon is) | Először a zöld "Z" betöltőképernyő, utána az étlap. **Jegyezd fel, hány másodperc** telt el (Wi-Fi-n, és ha B út, mobilneten is) |
| A2 | Nézd a képernyő tetejét | A piros **DEMÓ szalag** látszik, **nem** lóg a notch / állapotsor alá |
| A3 ★ | Nézd az alsó sávot (Étlap, Kosár, Rendeléseim, Profil) | **Nem** takarja a gesztus-sáv / home-jelző; a négy gomb koppintható. (A böngésző a képernyő alján a gesztus-sáv alatt egy **krémszínű csíkot** hagyhat: ez várható, nem hiba. Hiba, ha az alsó sáv ikonjai a gesztus-sáv mögé csúsznak) |
| A4 | Étlap: ő, ű, Ő, Ű betűk (pl. "Tojásos-sajtos szósz, ropogós bacon, frissen őrölt bors.") | Minden betű helyes, **nincs doboz (□)** |
| A5 | Termékképek | Minden kártyán betöltődik a kép (lassú hálózaton késhet) |
| A6 ★ | Fordítsd **fekvő** helyzetbe, majd vissza | Semmi nem lóg le és nem vágódik le; a tartalom nem megy a notch alá. (Fekvőben az étlap fejléce majdnem kitölti a képernyőt: a lista **görgetéssel** elérhető, ez várható) |
| A7 | Húzd le az ujjad az étlap tetején (lehúzásos frissítés) | Az oldal **nem** töltődik újra magától (Android Chrome-on a "lehúzás frissítésre" nem jöhet elő) |

## B. Étlap és kosár

| # | Mit csinálj | Mit kell látnod |
|---|---|---|
| B1 ★ | Koppints az "Étel keresése" mezőre | Billentyűzet jön fel, a mező **a billentyűzet fölött marad**, az oldal **nem nagyít be** magától (iPhone-on előfordulhat, ha a mező betűmérete kicsi) |
| B2 | Írd be: `teszta`, majd `TÉSZTA`, majd `carbonara` | Az ékezet nélküli és a nagybetűs keresés is a tésztákat hozza (az app az ékezeteket és a kis/nagybetűt összevonja); a törlés gomb (×) törli a mezőt |
| B3 | Húzd az ujjad vízszintesen a szűrők (Vegetáriánus, Összes, Tészták…) során | Vízszintesen görög; ha ferdén indítod, a **függőleges** görgetés nem akad el |
| B4 | Koppints egy termék **kártyájára** (nem a + gombra) | Lap csúszik fel az allergénekkel; bezárható lehúzással / a háttérre koppintással / Android Vissza gombbal |
| B5 | Koppints a **+** gombra, majd a **+** és **−** gombokra a kártyán | A mennyiség változik; megjelenik a "Kosár megtekintése · N tétel" sáv, és **nem takarja** a lista utolsó termékének gombjait (görgess a lista aljára) |
| B6 | Kosár fül | A tételek, a részösszeg, a szállítási díj, a végösszeg; a "Még … hiányzik a minimális rendelési értékig" üzenet, amíg kevés a kosár |
| B7 | Frissítsd az oldalt (Safari: ⟳; Chrome: ⟳) a kosárral | A kosár tartalma **megmarad** |

## C. Belépés

| # | Mit csinálj | Mit kell látnod |
|---|---|---|
| C1 | Profil, Belépés, **Belépés demó fiókkal** | Belépsz, a Profil a fiókot mutatja |
| C2 ★ | Kijelentkezés, majd **kézzel**: e-mail (`demo@zaba.example` az A úton; a B úton a demó fiók) és jelszó | Az e-mail mezőn **@ jel** is elérhető a billentyűzeten, nem javítja át nagybetűre / szóra a böngésző; a jelszó **szem** ikonja mutatja / elrejti; "Belépés" működik |
| C3 | Hibás jelszó | "Hibás e-mail-cím vagy jelszó." (nem üres hiba) |
| C4 | Regisztráció **kitalált** e-mail-címmel (`teszt1@example.test`) és legalább 8 karakteres jelszóval | A fiók létrejön és be vagy lépve |
| C5 ★ | Belépve **zárd be a lapot / az appot, nyisd meg újra** | **Belépve maradsz** (Safarin a privát lapon ez nem működik: az várható, a böngésző nem tárol) |

## D. Rendelés és fizetés

| # | Mit csinálj | Mit kell látnod |
|---|---|---|
| D1 ★ | Étlap tetején "Add meg a címed": irányítószám `1051`, utca `Váci utca 12.` | A **számbillentyűzet** jön fel az irányítószámhoz; mentés után a cím az étlap tetején. `2000`-es irányítószámra: "Erre a címre nem szállítunk." |
| D2 | Tegyél a kosárba legalább 2 db carbonarát, kosár, "Tovább a fizetéshez" | Pénztár: a cím, az első szabad idősáv kiválasztva, az összegzés |
| D3 ★ | Írj a **Megjegyzés** mezőbe (ékezetekkel, hosszan) | Gépelés közben a mező látszik a billentyűzet fölött; az ékezetek helyesek. (Emoji **dobozként** jelenik meg: ismert korlát) |
| D4 ★ | "Rendelés leadása", kártyaoldal: gépeld be `4242424242424242` | A szám **négyesével tördelődik** (`4242 4242 4242 4242`), számbillentyűzet jön fel |
| D5 ★ | Lejárat: `1228`; biztonsági kód `123`; név `Teszt Elek`. A mezők közt **koppintással** lépj (a számbillentyűzeten, főleg iPhone-on, nincs "tovább" gomb) | A lejárat automatikusan `12/28`. Egyik fókuszált mezőt sem takarja el a billentyűzet; a **"Fizetés" gomb elérhető** akkor is, ha a billentyűzet fent van (görgess, vagy zárd le a billentyűzetet a mezőn kívüli koppintással) |
| D6 | "Fizetés" | Rövid "feldolgozás", majd a **rendelés követő oldala**: "Rendelés fogadva", "Kifizetve" |
| D7 | Új rendelés, a kártyaszám `4000000000000002` | "A kártyádat elutasították. Próbálj meg másik kártyát."; a rendelés fizetésre vár; ugyanazon az oldalon `4242…`-vel újra próbálva sikerül |
| D8 | Új rendelés, a kártyaoldalon **Mégse** | Visszatérsz; Rendeléseim: "Fizetésre vár", és onnan a "Fizetés" gombbal folytatható |
| D9 | A "Rendelés leadása" gombra koppints **gyorsan kétszer** | A Rendeléseim listában **egy** rendelés van, nem kettő |
| D10 | Rendeléseim, a rendelés megnyitása | Tételek, idősáv, cím, a megjegyzés (kétszer sem duplázódik) |

## E. Élő követés ★ (a telefon + az admin oldal)

Ez a legfontosabb rész: itt derül ki, hogy a Realtime / WebSocket átmegy-e a telefon hálózatán.

| # | Mit csinálj | Mit kell látnod |
|---|---|---|
| E1 ★ | A telefonon nyisd meg a (kifizetett) rendelés követő oldalát. Az admin oldalon: **Készítés megkezdése** | A telefonon **néhány másodpercen belül** "Készül"-re vált az idővonal, és **felül sáv** jelzi az értesítést. Nem kell frissíteni |
| E2 ★ | Az admin: **Kiszállítás indítása**, majd **Kiszállítva** | Mindkettőnél a telefon követi |
| E3 ★ | Új rendelés (kifizetve), a telefon **háttérbe**: válts másik appra vagy zárd le a képernyőt **kb. 1 percre**. Közben az admin léptet egyet. Nyisd vissza a böngészőt | Visszatéréskor az állapot **~10 másodpercen belül** a friss (a háttérben a böngésző megszakíthatja a kapcsolatot, ezt az app pótolja) |
| E4 | A telefon **repülő módba** 20 mp-re, közben az admin léptet; kapcsold ki a repülő módot | Az oldal nem lesz használhatatlan; a kapcsolat visszatértével frissül. Hibaüzenet esetén "Újra" gomb van |
| E5 | Új, **kifizetett** rendelés, "Rendelés lemondása", megerősítés | "Lemondva", a fizetés "Visszatérítve". Az adminban a rendelés lemondott |
| E6 | Csengő ikon a Rendeléseim tetején | Az értesítések listája az eddigi változásokkal |

Az admin oldal élő frissülése (új rendelés megjelenik **frissítés nélkül**) a gépen próbálható: a telefonon adj le egy rendelést, az admin listában
magától megjelenik.

## F. Kezdőképernyő és "telepített" mód ★

| # | Mit csinálj | Mit kell látnod |
|---|---|---|
| F1 ★ | **iPhone Safari:** Megosztás, **Főképernyőhöz adás** | A név "Zaba", az ikon a zöld "Z" (helyőrző; a végleges logó a k lépésben) |
| F2 ★ | Nyisd meg a főképernyős ikonról | **Teljes képernyőn** nyílik (nincs Safari-sáv), az állapotsor olvasható; **az alsó sáv a gesztus-sáv fölött / mellett jól használható** (lásd A3) |
| F3 ★ | Ebben a módban: belépés, rendelés, kilépés az appból, újranyitás | A belépés megmarad. (Az iPhone főképernyős módja általában **külön tárhelyet** használ a Safaritól, ezért ott elölről kell belépni: ez várható, nem hiba) |
| F4 | **Android Chrome:** menü, "Alkalmazás telepítése" vagy "Hozzáadás a kezdőképernyőhöz" | Csak **https** címen (B út) jön fel. Az ikon és a név a manifest szerinti |
| F5 | Nyisd meg a telepített appot | Önálló ablakban nyílik, nincs címsor; a **Vissza** gomb / gesztus az appon belül lépked |

## G. Az Android-app (APK), csak a B úton

Az APK az oldalon (`https://zaba-apk.<fiók>.workers.dev`) tölthető le. Az APK csak 64 bites ARM telefonra készül (2017 óta szinte mind az).

| # | Mit csinálj | Mit kell látnod |
|---|---|---|
| G1 | Nyisd meg a letöltő oldalt a telefon böngészőjében, töltsd le | A leírás érthető, a letöltés elindul |
| G2 | Telepítés: a telefon rákérdez az **ismeretlen forrás** engedélyezésére; engedd meg az adott böngészőnek | A telepítés lefut. **A Play Protect figyelmeztethet** ("ismeretlen fejlesztő"): az APK nem Play Store-ból jön, ez várható |
| G3 ★ | Indítsd el | Étlap, a DEMÓ szalag; **nem** ragad a betöltésnél (az első release build erre hajlamos volt: itt a valódi telefonon kell igazolódnia) |
| G4 | Belépés, kosár, rendelés, fizetés (`4242…`) | Mint a D rész |
| G5 ★ | **Vissza gomb / gesztus**: kosárból, pénztárból, kártyaoldalról, étlapról | Egy lépést vissza; az étlapról kilép az appból; a pénztárról nem dob ki |
| G6 | Zárd be az appot (kapcsolók közül is), nyisd újra | A kosár **és** a belépés megmarad |
| G7 ★ | Nézd az állapotsort és a navigációs sávot (különösen **Android 15**-ön) | A tartalom nem csúszik a rendszersávok alá; a DEMÓ szalag olvasható |
| G8 | Fordítás fekvőbe | Nincs levágott tartalom |
| G9 | Rendszer **sötét mód** be | Az app világos marad, minden olvasható |
| G10 | Rendszer **nagy betűméret** (Beállítások, Megjelenítés, Betűméret: a legnagyobb) | Az étlap, a kosár, a pénztár olvasható, **semmi nem vágódik le**; a gombok elérhetők |

## H. Az admin oldal telefonon vagy tabletről

Az admin elsősorban gépre készült; itt csak az kell, hogy telefonon se legyen használhatatlan.

| # | Mit csinálj | Mit kell látnod |
|---|---|---|
| H1 | Nyisd meg az admin címét | "Munkatársi belépés"; belépés a munkatársi fiókkal |
| H2 | Rendelések lista, egy rendelés megnyitása | A lista és a részletek olvashatók, a szűrők (Aktív, Fizetésre vár, Lezárt, Mind) működnek |
| H3 | Állapotléptetés | A gombok működnek; **fizetésre váró rendelésnél** nincs léptetés, csak lemondás |

## J. Hálózat, csak a B úton

| # | Mit csinálj | Mit kell látnod |
|---|---|---|
| J1 ★ | **Mobilnet** (4G/5G), Wi-Fi ki: A1 és a teljes D rész | Betölt; **jegyezd fel a betöltési időt** |
| J2 ★ | Mobilneten az **E1** (élő követés) | Mint Wi-Fi-n. Ha **nem** frissül magától, de kb. 5–10 mp után igen, az a polling-tartalék: a WebSocket itt nem ment át (írd meg) |
| J3 | Gyenge térerő / lassú hálózat (pl. lift, pince) | Hibaüzenet "Újra" gombbal, nem fehér képernyő |

## Mit ellenőriztem már én (nem kell megismételned)

- A teljes vásárlói és admin út **asztali Chromiumban**, mobil méretű nézetben és érintéssel, a helyi backend ellen; két gazdát ér el (az oldalét és a backendét), nincs
  Content-Security-Policy sérülés, a Realtime WebSocket felépül (a LAN-címen is).
- Az app **kis és fekvő képernyőn, nagy betűvel** (320 × 568; ugyanaz 1,3-szoros betűvel; 844 × 390 fekvő; 390 × 844 2-szeres betűvel): a vásárlói út a kosártól a követésig, az
  étlap, a termék-lap, a profil, a belépés és a regisztráció űrlapja **nem csúszik túl** (automatikus teszt: `app/test/small_screens_test.dart`). Ez találta meg, hogy a
  termékkártya ár/mennyiség sora 320 px szélességen kilógott: javítva.
- Az **Android release APK** egy emulátoron (x86_64 build, ugyanaz a kód): indul, étlap, belépés, kosár, újraindítás utáni megmaradás.
- Az **iPhone biztonságos terület**: a Flutter web **nem veszi át** a böngésző `safe-area` értékeit (kipróbáltam egy emulált 47 px felső és 34 px alsó beszúrással: az elrendezés nem mozdult).
  Ezért az `index.html`-ből **kivettem a `viewport-fit=cover`-t**: így az iPhone a tartalmat a biztonságos területen belül jeleníti meg, a maradék sávot az oldal háttérszínével (krém) tölti ki.
  Ez a WebKit dokumentációja szerinti viselkedés (2017-es forrás), **iPhone-on nem tesztelt**: az A3, A6 és F2 sorok ezt igazolják vagy cáfolják.

## Ismert korlátok (nem hibák)

- Az emoji és a nem csomagolt írásjegyek (cirill, kínai) **doboz** (□): a Content-Security-Policy tiltja a külső tartalék betűt.
- Az értesítések csak az appon belül jelennek meg (nincs telefonos push), és nem maradnak meg újranyitás után.
- A "Következő állapot (demó)" gomb a vásárlói appban nincs (az adminból léptetsz).
- Az ÁFA-kulcsok, az allergén-adatok és a jogi jellegű szövegek **illusztratívak**, a helyességüket könyvelővel / ügyvéddel kell egyeztetni.
- Az ikon és a betöltőképernyő **helyőrző**; a végleges logó a k lépésben készül.
- A telepítés ajánlata (F4) csak https-en jön fel; a Play Protect figyelmeztetése az APK-nál (G2) várható.

## Jegyzőlap (másold ki)

```
Eszköz:            (pl. iPhone 13)
Rendszer:          (pl. iOS 18.x / Android 15)
Böngésző:          (Safari / Chrome, verzió)
Út:                (A: saját gép Wi-Fi / B: felhős demó)   Hálózat: (Wi-Fi / mobilnet)

A1 (mp):        A2:    A3:    A4:    A5:    A6:    A7:
B1:  B2:  B3:  B4:  B5:  B6:  B7:
C1:  C2:  C3:  C4:  C5:
D1:  D2:  D3:  D4:  D5:  D6:  D7:  D8:  D9:  D10:
E1:  E2:  E3:  E4:  E5:  E6:
F1:  F2:  F3:  F4:  F5:
G1:  G2:  G3:  G4:  G5:  G6:  G7:  G8:  G9:  G10:
H1:  H2:  H3:
J1 (mp):  J2:  J3:

Hibák (azonosító, mit láttál, képernyőkép):
```
