// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Hungarian (`hu`).
class AppLocalizationsHu extends AppLocalizations {
  AppLocalizationsHu([String locale = 'hu']) : super(locale);

  @override
  String get appTitle => 'Zaba';

  @override
  String get demoBanner => 'DEMÓ · kitalált adatok, nem valódi rendelés';

  @override
  String get navMenu => 'Étlap';

  @override
  String get navCart => 'Kosár';

  @override
  String get navOrders => 'Rendeléseim';

  @override
  String get navProfile => 'Profil';

  @override
  String get commonLoading => 'Betöltés…';

  @override
  String get commonRetry => 'Újra';

  @override
  String get commonErrorTitle => 'Hoppá, valami elromlott';

  @override
  String get commonErrorBody =>
      'Nem sikerült betölteni a tartalmat. Ellenőrizd a kapcsolatot, és próbáld újra.';

  @override
  String get commonCancel => 'Mégse';

  @override
  String get commonSave => 'Mentés';

  @override
  String get quantityLess => 'Kevesebb';

  @override
  String get quantityMore => 'Több';

  @override
  String get menuDeliverTo => 'Szállítás ide';

  @override
  String get menuAddressPlaceholder => 'Add meg a címed';

  @override
  String get menuSearchHint => 'Étel keresése';

  @override
  String get menuSearchClear => 'Törlés';

  @override
  String get menuCategoryAll => 'Összes';

  @override
  String get menuVegetarian => 'Vegetáriánus';

  @override
  String get menuSortPopular => 'Népszerű';

  @override
  String get menuSortPriceAsc => 'Olcsóbb';

  @override
  String get menuSortPriceDesc => 'Drágább';

  @override
  String get menuEmptyTitle => 'Az étlap még üres';

  @override
  String get menuEmptyBody => 'Hamarosan ide kerülnek a Zaba ételei.';

  @override
  String get menuNoResultsTitle => 'Nincs találat';

  @override
  String get menuNoResultsBody => 'Próbálj másik keresést vagy kategóriát.';

  @override
  String get menuClearFilters => 'Szűrők törlése';

  @override
  String menuCartBar(int count) {
    return 'Kosár megtekintése · $count tétel';
  }

  @override
  String kitchenEta(int min, int max) {
    return '$min–$max perc';
  }

  @override
  String kitchenDeliveryFee(String fee) {
    return 'Szállítás $fee';
  }

  @override
  String kitchenMinOrder(String amount) {
    return 'Min. rendelés $amount';
  }

  @override
  String get productAdd => 'Hozzáadás';

  @override
  String productAddWithPrice(String price) {
    return 'Hozzáadás · $price';
  }

  @override
  String get productAllergens => 'Allergének';

  @override
  String get productNoAllergens => 'Nem tartalmaz jelölt allergént.';

  @override
  String get productAllergenNote =>
      'Az allergén-adatok a demóban illusztratívak.';

  @override
  String get productVegetarian => 'Vegetáriánus';

  @override
  String get allergenGluten => 'Glutén';

  @override
  String get allergenCrustaceans => 'Rákfélék';

  @override
  String get allergenEgg => 'Tojás';

  @override
  String get allergenFish => 'Hal';

  @override
  String get allergenPeanut => 'Földimogyoró';

  @override
  String get allergenSoy => 'Szója';

  @override
  String get allergenMilk => 'Tej';

  @override
  String get allergenNuts => 'Diófélék';

  @override
  String get allergenCelery => 'Zeller';

  @override
  String get allergenMustard => 'Mustár';

  @override
  String get allergenSesame => 'Szezámmag';

  @override
  String get allergenSulphites => 'Kén-dioxid és szulfitok';

  @override
  String get allergenLupin => 'Csillagfürt';

  @override
  String get allergenMolluscs => 'Puhatestűek';

  @override
  String get cartClear => 'Ürítés';

  @override
  String get cartEmptyTitle => 'Üres a kosarad';

  @override
  String get cartEmptyBody =>
      'Válassz valamit az étlapról, és itt fogod látni.';

  @override
  String get cartEmptyAction => 'Étlap megtekintése';

  @override
  String cartMinOrderShortfall(String amount, String min) {
    return 'Még $amount hiányzik a minimális rendelési értékig ($min).';
  }

  @override
  String cartFreeDeliveryHint(String amount) {
    return 'Még $amount és ingyenes a szállítás.';
  }

  @override
  String get cartEstimatedFee => 'A szállítási díj a megadott címtől függ.';

  @override
  String get cartVatNote => 'Az árak bruttó árak, az ÁFÁ-t tartalmazzák.';

  @override
  String cartCheckout(String total) {
    return 'Tovább a fizetéshez · $total';
  }

  @override
  String get priceSubtotal => 'Részösszeg';

  @override
  String get priceDeliveryFee => 'Szállítási díj';

  @override
  String get priceFree => 'Ingyenes';

  @override
  String get priceTotal => 'Összesen';

  @override
  String get addressTitle => 'Szállítási cím';

  @override
  String get addressPostalCode => 'Irányítószám';

  @override
  String get addressStreet => 'Utca, házszám';

  @override
  String get addressErrorPostalCode =>
      'Adj meg érvényes, 4 jegyű irányítószámot.';

  @override
  String get addressErrorOutOfZone => 'Erre a címre nem szállítunk.';

  @override
  String get addressErrorStreet => 'Add meg az utcát és a házszámot.';

  @override
  String addressFormatted(String postalCode, String street) {
    return '$postalCode Budapest, $street';
  }

  @override
  String get checkoutTitle => 'Pénztár';

  @override
  String get checkoutAddressSection => 'Szállítási cím';

  @override
  String get checkoutAddressMissing => 'Add meg a szállítási címet';

  @override
  String get checkoutSlotSection => 'Szállítási idő';

  @override
  String get checkoutNoSlots => 'Most nincs szabad idősáv. Próbáld meg később.';

  @override
  String get checkoutNoteSection => 'Megjegyzés';

  @override
  String get checkoutNoteLabel => 'Megjegyzés a konyhának és a futárnak';

  @override
  String get checkoutNoteHint => 'pl. a csengő nem működik, hívjon fel';

  @override
  String get checkoutPaymentSection => 'Fizetés';

  @override
  String get checkoutPaymentCard => 'Bankkártyás fizetés';

  @override
  String get checkoutPaymentDemoNote =>
      'Demó: valódi kártyaadatot nem kérünk, a fizetés szimulált.';

  @override
  String get checkoutSummarySection => 'Összegzés';

  @override
  String checkoutPlaceOrder(String total) {
    return 'Rendelés leadása · $total';
  }

  @override
  String checkoutQuantityTimes(int quantity, String name) {
    return '$quantity × $name';
  }

  @override
  String get slotToday => 'Ma';

  @override
  String get slotTomorrow => 'Holnap';

  @override
  String slotWeekdayDate(String weekday, int day) {
    String _temp0 = intl.Intl.selectLogic(weekday, {
      '1': 'Hétfő',
      '2': 'Kedd',
      '3': 'Szerda',
      '4': 'Csütörtök',
      '5': 'Péntek',
      '6': 'Szombat',
      '7': 'Vasárnap',
      'other': '',
    });
    return '$_temp0 $day.';
  }

  @override
  String get orderErrorEmptyCart => 'A kosarad üres.';

  @override
  String get orderErrorOutOfArea => 'Erre a címre nem szállítunk.';

  @override
  String get orderErrorBelowMinimum =>
      'A rendelés nem éri el a minimális értéket.';

  @override
  String get orderErrorSlotUnavailable =>
      'Ez az idősáv már nem elérhető, válassz másikat.';

  @override
  String get orderErrorGeneric =>
      'A rendelést nem sikerült leadni. Próbáld meg újra.';

  @override
  String get paymentTitle => 'Fizetés';

  @override
  String get paymentAmountDue => 'Fizetendő';

  @override
  String paymentOrderNumber(String number) {
    return 'Rendelés: $number';
  }

  @override
  String get paymentTestCardsTitle => 'Demó teszt kártyák';

  @override
  String get paymentTestCardsSuccess => '4242 4242 4242 4242: sikeres fizetés';

  @override
  String get paymentTestCardsDeclined =>
      '4000 0000 0000 0002: elutasított kártya';

  @override
  String get paymentTestCardsOther =>
      'Lejáratnak bármely jövőbeli hónap, biztonsági kódnak bármely 3 jegyű szám jó.';

  @override
  String get paymentCardNumber => 'Kártyaszám';

  @override
  String get paymentExpiry => 'Lejárat (HH/ÉÉ)';

  @override
  String get paymentCvc => 'Biztonsági kód';

  @override
  String get paymentCardHolder => 'Név a kártyán';

  @override
  String paymentPay(String total) {
    return 'Fizetés · $total';
  }

  @override
  String get paymentCancel => 'Mégse';

  @override
  String get paymentProcessing => 'Fizetés feldolgozása…';

  @override
  String get paymentDeclined =>
      'A kártyádat elutasították. Próbálj meg másik kártyát.';

  @override
  String get paymentUnavailable =>
      'A fizetést most nem sikerült elindítani. Ellenőrizd a kapcsolatot, és próbáld újra.';

  @override
  String get paymentErrorCardNumber => 'Érvénytelen kártyaszám.';

  @override
  String get paymentErrorExpiry => 'Érvénytelen lejárati dátum.';

  @override
  String get paymentErrorCvc => '3 jegyű biztonsági kód kell.';

  @override
  String get paymentErrorHolder => 'Add meg a kártyabirtokos nevét.';

  @override
  String get paymentSecurityNote =>
      'A kártyaadataid nem hagyják el a készüléket, a szerverre csak a fizetés eredménye kerül.';

  @override
  String get paymentNotPayableTitle => 'Ez a rendelés már nem fizethető';

  @override
  String get paymentNotPayableAction => 'Rendelés megnyitása';

  @override
  String get ordersEmptyTitle => 'Még nincs rendelésed';

  @override
  String get ordersEmptyBody =>
      'A leadott rendeléseid és azok állapota itt jelenik meg.';

  @override
  String get ordersEmptyAction => 'Étlap megtekintése';

  @override
  String orderTitle(String number) {
    return 'Rendelés $number';
  }

  @override
  String orderListSubtitle(String date, String time, int count) {
    return '$date $time · $count tétel';
  }

  @override
  String get orderNotFound => 'A rendelés nem található.';

  @override
  String get orderStatusPendingPaymentTitle => 'Fizetésre vár';

  @override
  String get orderStatusPendingPaymentSubtitle =>
      'A konyha a fizetés után kezdi el a rendelést.';

  @override
  String get orderStatusReceivedTitle => 'Rendelés fogadva';

  @override
  String get orderStatusReceivedSubtitle => 'A konyha megkapta a rendelésedet.';

  @override
  String get orderStatusPreparingTitle => 'Készül';

  @override
  String get orderStatusPreparingSubtitle => 'Elkészítjük az ételeidet.';

  @override
  String get orderStatusOutForDeliveryTitle => 'Úton van';

  @override
  String get orderStatusOutForDeliverySubtitle =>
      'A futár már úton van hozzád.';

  @override
  String get orderStatusDeliveredTitle => 'Kiszállítva';

  @override
  String get orderStatusDeliveredSubtitle => 'Jó étvágyat!';

  @override
  String get orderStatusCancelledTitle => 'Lemondva';

  @override
  String get orderStatusCancelledSubtitle => 'A rendelés lemondásra került.';

  @override
  String get orderPayNowTitle => 'A rendelés még nem fizetett';

  @override
  String orderPayNow(String total) {
    return 'Fizetés · $total';
  }

  @override
  String orderDeliveryWindow(String date, String slot) {
    return 'Kiszállítás: $date $slot';
  }

  @override
  String get orderAdvanceDemo => 'Következő állapot (demó)';

  @override
  String get orderCancel => 'Rendelés lemondása';

  @override
  String get orderCancelTitle => 'Lemondod a rendelést?';

  @override
  String get orderCancelBodyPaid => 'A kifizetett összeget visszatérítjük.';

  @override
  String get orderCancelBodyUnpaid => 'A rendelés nem kerül elkészítésre.';

  @override
  String get orderCancelConfirm => 'Lemondom';

  @override
  String get orderCancelKeep => 'Mégsem';

  @override
  String get orderSummarySection => 'Rendelés összegzése';

  @override
  String get orderAddressLabel => 'Cím';

  @override
  String get orderSlotLabel => 'Idősáv';

  @override
  String get orderPaymentLabel => 'Fizetés';

  @override
  String get orderNoteLabel => 'Megjegyzés';

  @override
  String get paymentStatusPending => 'Fizetésre vár';

  @override
  String get paymentStatusSucceeded => 'Kifizetve';

  @override
  String get paymentStatusFailed => 'Sikertelen';

  @override
  String get paymentStatusCancelled => 'Megszakítva';

  @override
  String get paymentStatusRefunded => 'Visszatérítve';

  @override
  String get profileDemoTitle => 'Ez egy demó';

  @override
  String get profileDemoBody =>
      'A Zaba bemutató változatát használod. Az adatok kitaláltak, a fizetés szimulált, rendelés nem érkezik meg senkihez.';

  @override
  String get profileDevGallery => 'Komponens-galéria (fejlesztői)';

  @override
  String get profileImageCredits => 'Képek forrásai';

  @override
  String get profileSignedOutTitle => 'Nem vagy bejelentkezve';

  @override
  String get profileSignedOutBody =>
      'Lépj be vagy regisztrálj, hogy rendelni tudj, és lásd a korábbi rendeléseidet.';

  @override
  String get profileSignOut => 'Kijelentkezés';

  @override
  String get ordersSignedOutTitle => 'Lépj be a rendeléseidhez';

  @override
  String get ordersSignedOutBody =>
      'A leadott rendeléseid és azok állapota itt jelenik meg, ha bejelentkezel.';

  @override
  String get authLoginTitle => 'Belépés';

  @override
  String get authRegisterTitle => 'Regisztráció';

  @override
  String get authCheckoutHint => 'A rendelés leadásához be kell jelentkezned.';

  @override
  String get authNameLabel => 'Név (nem kötelező)';

  @override
  String get authEmailLabel => 'E-mail-cím';

  @override
  String get authPasswordLabel => 'Jelszó';

  @override
  String authPasswordHelper(int min) {
    return 'Legalább $min karakter';
  }

  @override
  String get authShowPassword => 'Jelszó megjelenítése';

  @override
  String get authHidePassword => 'Jelszó elrejtése';

  @override
  String get authLoginAction => 'Belépés';

  @override
  String get authRegisterAction => 'Fiók létrehozása';

  @override
  String get authSwitchToRegister => 'Még nincs fiókod? Regisztrálj';

  @override
  String get authSwitchToLogin => 'Már van fiókod? Lépj be';

  @override
  String get authDemoAccount => 'Belépés demó fiókkal';

  @override
  String get authOr => 'vagy';

  @override
  String get authRegisterDemoNote =>
      'Demó: kitalált adatokat adj meg, ne valós személyes adatot.';

  @override
  String get authEmailRequired => 'Add meg az e-mail-címet.';

  @override
  String get authEmailInvalid => 'Ez nem tűnik érvényes e-mail-címnek.';

  @override
  String get authPasswordRequired => 'Add meg a jelszót.';

  @override
  String authPasswordTooShort(int min) {
    return 'A jelszó legalább $min karakter legyen.';
  }

  @override
  String get authErrorInvalidCredentials => 'Hibás e-mail-cím vagy jelszó.';

  @override
  String get authErrorEmailTaken =>
      'Ezzel az e-mail-címmel már van fiók. Próbálj belépni.';

  @override
  String get authErrorWeakPassword =>
      'Ez a jelszó túl gyenge. Válassz hosszabbat vagy bonyolultabbat.';

  @override
  String get authErrorEmailNotConfirmed =>
      'Az e-mail-címet még meg kell erősíteni. A demó nem küld e-mailt, szólj a fejlesztőnek.';

  @override
  String get authErrorTooManyRequests =>
      'Túl sok próbálkozás. Várj egy kicsit, és próbáld újra.';

  @override
  String get authErrorNetwork =>
      'Nem sikerült elérni a szervert. Ellenőrizd a netkapcsolatot.';

  @override
  String get authErrorUnknown => 'Valami nem sikerült. Próbáld újra.';

  @override
  String get imageCreditsTitle => 'Képek forrásai';

  @override
  String get imageCreditsIntro =>
      'A termékfotók a Wikimedia Commonsból származnak, szabad licenc alatt (CC0, közkincs vagy CC BY). A névjelzések:';

  @override
  String imageCreditsEntry(String title, String author, String license) {
    return 'Fotó: $title · Szerző: $author · $license';
  }
}
