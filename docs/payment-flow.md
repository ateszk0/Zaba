# Fizetési folyamat

A fizetésnek egyetlen szabálya van: **a rendelést csak a fizetési szolgáltató aláírt eseménye teheti kifizetetté.** A vásárló appja
fizetést kezdeményezhet és közölheti a (szimulált) kártyalépés kimenetét, de a rendelés állapota sosem az app kérésére változik.

## Sorozatdiagram

```mermaid
sequenceDiagram
    autonumber
    actor C as Vásárló (app)
    participant PC as payments-create
    participant DB as Adatbázis
    participant FP as fake-provider-confirm<br/>(a szolgáltató "háttere")
    participant WH as payments-webhook

    C->>DB: place_order(kulcs, kosár, cím, idősáv)
    DB-->>C: rendelés (pending_payment)
    C->>PC: order_id (a vásárló tokenjével)
    PC->>DB: start_payment(order_id) a vásárlóként
    Note over DB: csak a saját, fizetésre váró rendelés;<br/>új vagy a nyitott fizetési kísérlet
    DB-->>PC: payment_id, összeg
    PC-->>C: fizetési munkamenet (aláírt, 30 perc)
    Note over C: kártyaűrlap: a kártyaszám csak az appban marad,<br/>a kimenet (approved / declined / cancelled) megy tovább
    C->>FP: munkamenet + kimenet
    FP->>FP: munkamenet ellenőrzése (aláírás, lejárat)
    FP->>WH: aláírt esemény (HTTP, t=…,v1=HMAC)
    WH->>WH: aláírás, frissesség, szigorú értelmezés
    WH->>DB: apply_payment_event (service role)
    Note over DB: egyedi esemény-azonosító (idempotencia),<br/>csak nyitott, egyező fizetési kísérletre hat,<br/>egyetlen módosítás: státusz + fizetési státusz
    DB-->>WH: applied / duplicate / …
    DB-->>C: élő frissítés (Realtime): received
```

## Mi igazi és mi szimulált

| Rész | Igazi | Szimulált |
|---|---|---|
| `place_order`, `start_payment`, `apply_payment_event`, állapotgép | ✔ | |
| `payments-webhook`: aláírás, frissesség, szigorú értelmezés, idempotencia | ✔ | |
| A rendelés élő követése | ✔ | |
| `payments-create`: a szolgáltatói munkamenet megnyitása | a szerkezet igazi | a "szolgáltató" a mi kódunk (`FakePaymentProvider`) |
| `fake-provider-confirm` | **nem létezik élesben** | a valódi szolgáltató a saját oldalán veszi fel a kártyát és maga dönt |

**Figyelem:** a szimulált kártyalépésnél a kimenetet az app mondja meg (a `4242…` kártya jóváhagyott, a `4000 0000 0000 0002`
elutasított). Aki rendelkezik egy érvényes fizetési munkamenettel, az ezért "jóváhagyottat" jelenthet kártya nélkül is. Ez a demóban
szándékos és csak ott igaz; a valódi szolgáltatónál ez a lépés a szolgáltató oldalán dől el.

**A hamis út kapcsolója.** Mivel ez a lépés egy valódi boltban kifizetetté tenné bármelyik rendelést, a `payments-create` és a `fake-provider-confirm` **csak akkor dolgozik, ha a `FAKE_PAYMENTS_ENABLED` értéke pontosan `true`**
(`supabase/functions/_shared/flags.ts`); egyébként 503-at adnak. A kapcsoló **alapból zárt**: a demó, a helyi teszt és a saját szerveres staging (az `install.sh` friss stacken) kapcsolja be, valódi fizetésnél `false` vagy hiányzó érték kell.
A `verify.sh` figyelmeztet, amíg be van kapcsolva, és a `payment_smoke.py` érthető üzenettel jelzi, ha a kapcsoló miatt nem fut.

## Biztonsági tulajdonságok (mind tesztelt)

- A webhook aláírás nélküli, rosszul aláírt, módosított törzsű, régi (5 percnél idősebb) vagy értelmezhetetlen eseményt elutasít, és az
  okot csak a naplóba írja, a válaszba nem.
- Az ugyanaz az esemény kétszer (ugyanaz az azonosító) egyszer hat.
- Egy lezárt (elutasított vagy megszakított) fizetési kísérlet késve érkező "sikeres" eseménye **nem fizeti ki** a rendelést. Ezt a
  `payment_smoke.py` és a `080_payment_matching_and_slot_visibility.test.sql` őrzi; korábban az adatbázis-függvény ilyenkor mégis
  kifizetettnek jelölte a rendelést.
- Másik vásárló nem indíthat fizetést a rendelésre; vendég sem.
- A munkamenet-token és az esemény aláírása közös titokkal készül, de külön előtaggal (`session:`, illetve az időbélyeg), így az
  egyik nem használható a másik helyett.
- A titok (`FAKE_PAYMENT_WEBHOOK_SECRET`) csak a függvények környezetében él. Hiányában a függvények hibával leállnak, nincs
  alapértelmezett érték.

## Valódi szolgáltatóra váltás (MVP)

0. **`FAKE_PAYMENTS_ENABLED=false`** és a függvények újraindítása; a tesztkártya-súgó (`payment_screen.dart`) a valódi szolgáltatóval lecserélődik.
1. Egy új osztály a `PaymentProvider` interfészhez (`supabase/functions/_shared/payments/provider.ts`): `createSession` a szolgáltató
   API-ját hívja, `verifyWebhook` a szolgáltató aláírását ellenőrzi.
2. A `payments-create` a valódi osztályt példányosítja; a `fake-provider-confirm` megszűnik.
3. A `payments-webhook` a szolgáltató címe lesz. A felhős Supabase-en ehhez a függvényen ki kell kapcsolni a JWT-ellenőrzést
   (`verify_jwt = false`), mert a szolgáltató nem küld Supabase tokent; a hitelesítést az aláírás adja.
4. **Összeg- és pénznem-ellenőrzés a webhookban (kötelező).** Az `apply_payment_event` az eseményt a nyitott fizetési kísérlethez illeszti, de nem hasonlítja össze a szolgáltató által jelentett összeget a `payments.amount_huf`-fal (a hamis szolgáltató eseménye nem hordoz összeget). Az éles adapternek ezt az `apply_payment_event` hívása **előtt** kell elvégeznie (eltérésnél az esemény ne hasson, a rendelés maradjon fizetésre váró, és kézi vizsgálat induljon); teszt kell hozzá.
5. A visszatérítés (`refunds`) a szolgáltató API-ján át megy; a demóban a lemondás azonnal `refunded`-re állítja a fizetést.
6. A szolgáltató kiválasztása és a szerződés az MVP elején, a szolgáltató hivatalos dokumentációja alapján.

## Ismert korlátok (demó)

- Ha a webhook hibát ad (500), a valódi szolgáltató újrapróbálna; a fake szolgáltató nem, az app ilyenkor "a fizetést most nem sikerült
  elindítani" üzenetet ad, a rendelés fizetésre vár, és újra fizethető.
- A fizetésre váró rendelés **lejár**: a vásárlónként legfeljebb 5 fizetetlen rendelés korlát és az `expire_unpaid_orders` (a `schedule.sh` ütemezi, alapból 30 perc után) a lemondott rendelés helyét visszaadja az idősávnak. A lejárat `payment` szereplővel jelenik meg az előzményben, és a lejárat után érkező sikeres esemény nem fizeti ki a rendelést (`order_not_pending`; a pgTAP `100` őrzi).
- Egy sikeres fizetés utáni, lemondás közbeni versenyhelyzetet (lemondott rendelésre érkező sikeres esemény) a demó nem kezeli:
  `order_not_pending` néven figyelmen kívül marad; a valódi szolgáltatónál ez visszatérítést igényel.
