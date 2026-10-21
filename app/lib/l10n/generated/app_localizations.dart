import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_hu.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[Locale('hu')];

  /// Application name shown in the OS task switcher and app bars.
  ///
  /// In hu, this message translates to:
  /// **'Zaba'**
  String get appTitle;

  /// Permanent strip at the top of every screen so nobody mistakes the demo for the real service.
  ///
  /// In hu, this message translates to:
  /// **'DEMÓ · kitalált adatok, nem valódi rendelés'**
  String get demoBanner;

  /// No description provided for @navMenu.
  ///
  /// In hu, this message translates to:
  /// **'Étlap'**
  String get navMenu;

  /// No description provided for @navCart.
  ///
  /// In hu, this message translates to:
  /// **'Kosár'**
  String get navCart;

  /// No description provided for @navOrders.
  ///
  /// In hu, this message translates to:
  /// **'Rendeléseim'**
  String get navOrders;

  /// No description provided for @navProfile.
  ///
  /// In hu, this message translates to:
  /// **'Profil'**
  String get navProfile;

  /// No description provided for @commonLoading.
  ///
  /// In hu, this message translates to:
  /// **'Betöltés…'**
  String get commonLoading;

  /// No description provided for @commonRetry.
  ///
  /// In hu, this message translates to:
  /// **'Újra'**
  String get commonRetry;

  /// No description provided for @commonErrorTitle.
  ///
  /// In hu, this message translates to:
  /// **'Hoppá, valami elromlott'**
  String get commonErrorTitle;

  /// No description provided for @commonErrorBody.
  ///
  /// In hu, this message translates to:
  /// **'Nem sikerült betölteni a tartalmat. Ellenőrizd a kapcsolatot, és próbáld újra.'**
  String get commonErrorBody;

  /// No description provided for @commonCancel.
  ///
  /// In hu, this message translates to:
  /// **'Mégse'**
  String get commonCancel;

  /// No description provided for @commonSave.
  ///
  /// In hu, this message translates to:
  /// **'Mentés'**
  String get commonSave;

  /// No description provided for @quantityLess.
  ///
  /// In hu, this message translates to:
  /// **'Kevesebb'**
  String get quantityLess;

  /// No description provided for @quantityMore.
  ///
  /// In hu, this message translates to:
  /// **'Több'**
  String get quantityMore;

  /// No description provided for @menuDeliverTo.
  ///
  /// In hu, this message translates to:
  /// **'Szállítás ide'**
  String get menuDeliverTo;

  /// No description provided for @menuAddressPlaceholder.
  ///
  /// In hu, this message translates to:
  /// **'Add meg a címed'**
  String get menuAddressPlaceholder;

  /// No description provided for @menuSearchHint.
  ///
  /// In hu, this message translates to:
  /// **'Étel keresése'**
  String get menuSearchHint;

  /// No description provided for @menuSearchClear.
  ///
  /// In hu, this message translates to:
  /// **'Törlés'**
  String get menuSearchClear;

  /// No description provided for @menuCategoryAll.
  ///
  /// In hu, this message translates to:
  /// **'Összes'**
  String get menuCategoryAll;

  /// No description provided for @menuVegetarian.
  ///
  /// In hu, this message translates to:
  /// **'Vegetáriánus'**
  String get menuVegetarian;

  /// No description provided for @menuSortPopular.
  ///
  /// In hu, this message translates to:
  /// **'Népszerű'**
  String get menuSortPopular;

  /// No description provided for @menuSortPriceAsc.
  ///
  /// In hu, this message translates to:
  /// **'Olcsóbb'**
  String get menuSortPriceAsc;

  /// No description provided for @menuSortPriceDesc.
  ///
  /// In hu, this message translates to:
  /// **'Drágább'**
  String get menuSortPriceDesc;

  /// No description provided for @menuEmptyTitle.
  ///
  /// In hu, this message translates to:
  /// **'Az étlap még üres'**
  String get menuEmptyTitle;

  /// No description provided for @menuEmptyBody.
  ///
  /// In hu, this message translates to:
  /// **'Hamarosan ide kerülnek a Zaba ételei.'**
  String get menuEmptyBody;

  /// No description provided for @menuNoResultsTitle.
  ///
  /// In hu, this message translates to:
  /// **'Nincs találat'**
  String get menuNoResultsTitle;

  /// No description provided for @menuNoResultsBody.
  ///
  /// In hu, this message translates to:
  /// **'Próbálj másik keresést vagy kategóriát.'**
  String get menuNoResultsBody;

  /// No description provided for @menuClearFilters.
  ///
  /// In hu, this message translates to:
  /// **'Szűrők törlése'**
  String get menuClearFilters;

  /// No description provided for @menuCartBar.
  ///
  /// In hu, this message translates to:
  /// **'Kosár megtekintése · {count} tétel'**
  String menuCartBar(int count);

  /// No description provided for @kitchenEta.
  ///
  /// In hu, this message translates to:
  /// **'{min}–{max} perc'**
  String kitchenEta(int min, int max);

  /// No description provided for @kitchenDeliveryFee.
  ///
  /// In hu, this message translates to:
  /// **'Szállítás {fee}'**
  String kitchenDeliveryFee(String fee);

  /// No description provided for @kitchenMinOrder.
  ///
  /// In hu, this message translates to:
  /// **'Min. rendelés {amount}'**
  String kitchenMinOrder(String amount);

  /// No description provided for @productAdd.
  ///
  /// In hu, this message translates to:
  /// **'Hozzáadás'**
  String get productAdd;

  /// No description provided for @productAddWithPrice.
  ///
  /// In hu, this message translates to:
  /// **'Hozzáadás · {price}'**
  String productAddWithPrice(String price);

  /// No description provided for @productAllergens.
  ///
  /// In hu, this message translates to:
  /// **'Allergének'**
  String get productAllergens;

  /// No description provided for @productNoAllergens.
  ///
  /// In hu, this message translates to:
  /// **'Nem tartalmaz jelölt allergént.'**
  String get productNoAllergens;

  /// No description provided for @productAllergenNote.
  ///
  /// In hu, this message translates to:
  /// **'Az allergén-adatok a demóban illusztratívak.'**
  String get productAllergenNote;

  /// No description provided for @productVegetarian.
  ///
  /// In hu, this message translates to:
  /// **'Vegetáriánus'**
  String get productVegetarian;

  /// No description provided for @allergenGluten.
  ///
  /// In hu, this message translates to:
  /// **'Glutén'**
  String get allergenGluten;

  /// No description provided for @allergenCrustaceans.
  ///
  /// In hu, this message translates to:
  /// **'Rákfélék'**
  String get allergenCrustaceans;

  /// No description provided for @allergenEgg.
  ///
  /// In hu, this message translates to:
  /// **'Tojás'**
  String get allergenEgg;

  /// No description provided for @allergenFish.
  ///
  /// In hu, this message translates to:
  /// **'Hal'**
  String get allergenFish;

  /// No description provided for @allergenPeanut.
  ///
  /// In hu, this message translates to:
  /// **'Földimogyoró'**
  String get allergenPeanut;

  /// No description provided for @allergenSoy.
  ///
  /// In hu, this message translates to:
  /// **'Szója'**
  String get allergenSoy;

  /// No description provided for @allergenMilk.
  ///
  /// In hu, this message translates to:
  /// **'Tej'**
  String get allergenMilk;

  /// No description provided for @allergenNuts.
  ///
  /// In hu, this message translates to:
  /// **'Diófélék'**
  String get allergenNuts;

  /// No description provided for @allergenCelery.
  ///
  /// In hu, this message translates to:
  /// **'Zeller'**
  String get allergenCelery;

  /// No description provided for @allergenMustard.
  ///
  /// In hu, this message translates to:
  /// **'Mustár'**
  String get allergenMustard;

  /// No description provided for @allergenSesame.
  ///
  /// In hu, this message translates to:
  /// **'Szezámmag'**
  String get allergenSesame;

  /// No description provided for @allergenSulphites.
  ///
  /// In hu, this message translates to:
  /// **'Kén-dioxid és szulfitok'**
  String get allergenSulphites;

  /// No description provided for @allergenLupin.
  ///
  /// In hu, this message translates to:
  /// **'Csillagfürt'**
  String get allergenLupin;

  /// No description provided for @allergenMolluscs.
  ///
  /// In hu, this message translates to:
  /// **'Puhatestűek'**
  String get allergenMolluscs;

  /// No description provided for @cartClear.
  ///
  /// In hu, this message translates to:
  /// **'Ürítés'**
  String get cartClear;

  /// No description provided for @cartEmptyTitle.
  ///
  /// In hu, this message translates to:
  /// **'Üres a kosarad'**
  String get cartEmptyTitle;

  /// No description provided for @cartEmptyBody.
  ///
  /// In hu, this message translates to:
  /// **'Válassz valamit az étlapról, és itt fogod látni.'**
  String get cartEmptyBody;

  /// No description provided for @cartEmptyAction.
  ///
  /// In hu, this message translates to:
  /// **'Étlap megtekintése'**
  String get cartEmptyAction;

  /// No description provided for @cartMinOrderShortfall.
  ///
  /// In hu, this message translates to:
  /// **'Még {amount} hiányzik a minimális rendelési értékig ({min}).'**
  String cartMinOrderShortfall(String amount, String min);

  /// No description provided for @cartFreeDeliveryHint.
  ///
  /// In hu, this message translates to:
  /// **'Még {amount} és ingyenes a szállítás.'**
  String cartFreeDeliveryHint(String amount);

  /// No description provided for @cartEstimatedFee.
  ///
  /// In hu, this message translates to:
  /// **'A szállítási díj a megadott címtől függ.'**
  String get cartEstimatedFee;

  /// No description provided for @cartVatNote.
  ///
  /// In hu, this message translates to:
  /// **'Az árak bruttó árak, az ÁFÁ-t tartalmazzák.'**
  String get cartVatNote;

  /// No description provided for @cartCheckout.
  ///
  /// In hu, this message translates to:
  /// **'Tovább a fizetéshez · {total}'**
  String cartCheckout(String total);

  /// No description provided for @priceSubtotal.
  ///
  /// In hu, this message translates to:
  /// **'Részösszeg'**
  String get priceSubtotal;

  /// No description provided for @priceDeliveryFee.
  ///
  /// In hu, this message translates to:
  /// **'Szállítási díj'**
  String get priceDeliveryFee;

  /// No description provided for @priceFree.
  ///
  /// In hu, this message translates to:
  /// **'Ingyenes'**
  String get priceFree;

  /// No description provided for @priceTotal.
  ///
  /// In hu, this message translates to:
  /// **'Összesen'**
  String get priceTotal;

  /// No description provided for @addressTitle.
  ///
  /// In hu, this message translates to:
  /// **'Szállítási cím'**
  String get addressTitle;

  /// No description provided for @addressPostalCode.
  ///
  /// In hu, this message translates to:
  /// **'Irányítószám'**
  String get addressPostalCode;

  /// No description provided for @addressStreet.
  ///
  /// In hu, this message translates to:
  /// **'Utca, házszám'**
  String get addressStreet;

  /// No description provided for @addressErrorPostalCode.
  ///
  /// In hu, this message translates to:
  /// **'Adj meg érvényes, 4 jegyű irányítószámot.'**
  String get addressErrorPostalCode;

  /// No description provided for @addressErrorOutOfZone.
  ///
  /// In hu, this message translates to:
  /// **'Erre a címre nem szállítunk.'**
  String get addressErrorOutOfZone;

  /// No description provided for @addressErrorLookup.
  ///
  /// In hu, this message translates to:
  /// **'Most nem sikerült ellenőrizni az irányítószámot. Próbáld újra.'**
  String get addressErrorLookup;

  /// No description provided for @addressErrorStreet.
  ///
  /// In hu, this message translates to:
  /// **'Add meg az utcát és a házszámot.'**
  String get addressErrorStreet;

  /// No description provided for @addressFormatted.
  ///
  /// In hu, this message translates to:
  /// **'{postalCode} Budapest, {street}'**
  String addressFormatted(String postalCode, String street);

  /// No description provided for @checkoutTitle.
  ///
  /// In hu, this message translates to:
  /// **'Pénztár'**
  String get checkoutTitle;

  /// No description provided for @checkoutAddressSection.
  ///
  /// In hu, this message translates to:
  /// **'Szállítási cím'**
  String get checkoutAddressSection;

  /// No description provided for @checkoutAddressMissing.
  ///
  /// In hu, this message translates to:
  /// **'Add meg a szállítási címet'**
  String get checkoutAddressMissing;

  /// No description provided for @checkoutSlotSection.
  ///
  /// In hu, this message translates to:
  /// **'Szállítási idő'**
  String get checkoutSlotSection;

  /// No description provided for @checkoutNoSlots.
  ///
  /// In hu, this message translates to:
  /// **'Most nincs szabad idősáv. Próbáld meg később.'**
  String get checkoutNoSlots;

  /// No description provided for @checkoutNoteSection.
  ///
  /// In hu, this message translates to:
  /// **'Megjegyzés'**
  String get checkoutNoteSection;

  /// No description provided for @checkoutNoteLabel.
  ///
  /// In hu, this message translates to:
  /// **'Megjegyzés a konyhának és a futárnak'**
  String get checkoutNoteLabel;

  /// No description provided for @checkoutNoteHint.
  ///
  /// In hu, this message translates to:
  /// **'pl. a csengő nem működik, hívjon fel'**
  String get checkoutNoteHint;

  /// No description provided for @checkoutPaymentSection.
  ///
  /// In hu, this message translates to:
  /// **'Fizetés'**
  String get checkoutPaymentSection;

  /// No description provided for @checkoutPaymentCard.
  ///
  /// In hu, this message translates to:
  /// **'Bankkártyás fizetés'**
  String get checkoutPaymentCard;

  /// No description provided for @checkoutPaymentDemoNote.
  ///
  /// In hu, this message translates to:
  /// **'Demó: valódi kártyaadatot nem kérünk, a fizetés szimulált.'**
  String get checkoutPaymentDemoNote;

  /// No description provided for @checkoutSummarySection.
  ///
  /// In hu, this message translates to:
  /// **'Összegzés'**
  String get checkoutSummarySection;

  /// No description provided for @checkoutPlaceOrder.
  ///
  /// In hu, this message translates to:
  /// **'Rendelés leadása · {total}'**
  String checkoutPlaceOrder(String total);

  /// No description provided for @checkoutQuantityTimes.
  ///
  /// In hu, this message translates to:
  /// **'{quantity} × {name}'**
  String checkoutQuantityTimes(int quantity, String name);

  /// No description provided for @slotToday.
  ///
  /// In hu, this message translates to:
  /// **'Ma'**
  String get slotToday;

  /// No description provided for @slotTomorrow.
  ///
  /// In hu, this message translates to:
  /// **'Holnap'**
  String get slotTomorrow;

  /// No description provided for @slotWeekdayDate.
  ///
  /// In hu, this message translates to:
  /// **'{weekday, select, 1{Hétfő} 2{Kedd} 3{Szerda} 4{Csütörtök} 5{Péntek} 6{Szombat} 7{Vasárnap} other{}} {day}.'**
  String slotWeekdayDate(String weekday, int day);

  /// No description provided for @orderErrorEmptyCart.
  ///
  /// In hu, this message translates to:
  /// **'A kosarad üres.'**
  String get orderErrorEmptyCart;

  /// No description provided for @orderErrorOutOfArea.
  ///
  /// In hu, this message translates to:
  /// **'Erre a címre nem szállítunk.'**
  String get orderErrorOutOfArea;

  /// No description provided for @orderErrorBelowMinimum.
  ///
  /// In hu, this message translates to:
  /// **'A rendelés nem éri el a minimális értéket.'**
  String get orderErrorBelowMinimum;

  /// No description provided for @orderErrorSlotUnavailable.
  ///
  /// In hu, this message translates to:
  /// **'Ez az idősáv már nem elérhető, válassz másikat.'**
  String get orderErrorSlotUnavailable;

  /// No description provided for @orderErrorTooManyUnpaid.
  ///
  /// In hu, this message translates to:
  /// **'Már van néhány kifizetetlen rendelésed. Fizesd ki vagy told le őket, mielőtt újat adsz le.'**
  String get orderErrorTooManyUnpaid;

  /// No description provided for @orderErrorGeneric.
  ///
  /// In hu, this message translates to:
  /// **'A rendelést nem sikerült leadni. Próbáld meg újra.'**
  String get orderErrorGeneric;

  /// No description provided for @paymentTitle.
  ///
  /// In hu, this message translates to:
  /// **'Fizetés'**
  String get paymentTitle;

  /// No description provided for @paymentAmountDue.
  ///
  /// In hu, this message translates to:
  /// **'Fizetendő'**
  String get paymentAmountDue;

  /// No description provided for @paymentOrderNumber.
  ///
  /// In hu, this message translates to:
  /// **'Rendelés: {number}'**
  String paymentOrderNumber(String number);

  /// No description provided for @paymentTestCardsTitle.
  ///
  /// In hu, this message translates to:
  /// **'Demó teszt kártyák'**
  String get paymentTestCardsTitle;

  /// No description provided for @paymentTestCardsSuccess.
  ///
  /// In hu, this message translates to:
  /// **'4242 4242 4242 4242: sikeres fizetés'**
  String get paymentTestCardsSuccess;

  /// No description provided for @paymentTestCardsDeclined.
  ///
  /// In hu, this message translates to:
  /// **'4000 0000 0000 0002: elutasított kártya'**
  String get paymentTestCardsDeclined;

  /// No description provided for @paymentTestCardsOther.
  ///
  /// In hu, this message translates to:
  /// **'Lejáratnak bármely jövőbeli hónap, biztonsági kódnak bármely 3 jegyű szám jó.'**
  String get paymentTestCardsOther;

  /// No description provided for @paymentCardNumber.
  ///
  /// In hu, this message translates to:
  /// **'Kártyaszám'**
  String get paymentCardNumber;

  /// No description provided for @paymentExpiry.
  ///
  /// In hu, this message translates to:
  /// **'Lejárat (HH/ÉÉ)'**
  String get paymentExpiry;

  /// No description provided for @paymentCvc.
  ///
  /// In hu, this message translates to:
  /// **'Biztonsági kód'**
  String get paymentCvc;

  /// No description provided for @paymentCardHolder.
  ///
  /// In hu, this message translates to:
  /// **'Név a kártyán'**
  String get paymentCardHolder;

  /// No description provided for @paymentPay.
  ///
  /// In hu, this message translates to:
  /// **'Fizetés · {total}'**
  String paymentPay(String total);

  /// No description provided for @paymentCancel.
  ///
  /// In hu, this message translates to:
  /// **'Mégse'**
  String get paymentCancel;

  /// No description provided for @paymentProcessing.
  ///
  /// In hu, this message translates to:
  /// **'Fizetés feldolgozása…'**
  String get paymentProcessing;

  /// No description provided for @paymentDeclined.
  ///
  /// In hu, this message translates to:
  /// **'A kártyádat elutasították. Próbálj meg másik kártyát.'**
  String get paymentDeclined;

  /// No description provided for @paymentUnavailable.
  ///
  /// In hu, this message translates to:
  /// **'A fizetést most nem sikerült elindítani. Ellenőrizd a kapcsolatot, és próbáld újra.'**
  String get paymentUnavailable;

  /// No description provided for @paymentErrorCardNumber.
  ///
  /// In hu, this message translates to:
  /// **'Érvénytelen kártyaszám.'**
  String get paymentErrorCardNumber;

  /// No description provided for @paymentErrorExpiry.
  ///
  /// In hu, this message translates to:
  /// **'Érvénytelen lejárati dátum.'**
  String get paymentErrorExpiry;

  /// No description provided for @paymentErrorCvc.
  ///
  /// In hu, this message translates to:
  /// **'3 jegyű biztonsági kód kell.'**
  String get paymentErrorCvc;

  /// No description provided for @paymentErrorHolder.
  ///
  /// In hu, this message translates to:
  /// **'Add meg a kártyabirtokos nevét.'**
  String get paymentErrorHolder;

  /// No description provided for @paymentSecurityNote.
  ///
  /// In hu, this message translates to:
  /// **'A kártyaadataid nem hagyják el a készüléket, a szerverre csak a fizetés eredménye kerül.'**
  String get paymentSecurityNote;

  /// No description provided for @paymentNotPayableTitle.
  ///
  /// In hu, this message translates to:
  /// **'Ez a rendelés már nem fizethető'**
  String get paymentNotPayableTitle;

  /// No description provided for @paymentNotPayableAction.
  ///
  /// In hu, this message translates to:
  /// **'Rendelés megnyitása'**
  String get paymentNotPayableAction;

  /// No description provided for @ordersEmptyTitle.
  ///
  /// In hu, this message translates to:
  /// **'Még nincs rendelésed'**
  String get ordersEmptyTitle;

  /// No description provided for @ordersEmptyBody.
  ///
  /// In hu, this message translates to:
  /// **'A leadott rendeléseid és azok állapota itt jelenik meg.'**
  String get ordersEmptyBody;

  /// No description provided for @ordersEmptyAction.
  ///
  /// In hu, this message translates to:
  /// **'Étlap megtekintése'**
  String get ordersEmptyAction;

  /// No description provided for @orderTitle.
  ///
  /// In hu, this message translates to:
  /// **'Rendelés {number}'**
  String orderTitle(String number);

  /// No description provided for @orderListSubtitle.
  ///
  /// In hu, this message translates to:
  /// **'{date} {time} · {count} tétel'**
  String orderListSubtitle(String date, String time, int count);

  /// No description provided for @orderNotFound.
  ///
  /// In hu, this message translates to:
  /// **'A rendelés nem található.'**
  String get orderNotFound;

  /// No description provided for @orderStatusPendingPaymentTitle.
  ///
  /// In hu, this message translates to:
  /// **'Fizetésre vár'**
  String get orderStatusPendingPaymentTitle;

  /// No description provided for @orderStatusPendingPaymentSubtitle.
  ///
  /// In hu, this message translates to:
  /// **'A konyha a fizetés után kezdi el a rendelést.'**
  String get orderStatusPendingPaymentSubtitle;

  /// No description provided for @orderStatusReceivedTitle.
  ///
  /// In hu, this message translates to:
  /// **'Rendelés fogadva'**
  String get orderStatusReceivedTitle;

  /// No description provided for @orderStatusReceivedSubtitle.
  ///
  /// In hu, this message translates to:
  /// **'A konyha megkapta a rendelésedet.'**
  String get orderStatusReceivedSubtitle;

  /// No description provided for @orderStatusPreparingTitle.
  ///
  /// In hu, this message translates to:
  /// **'Készül'**
  String get orderStatusPreparingTitle;

  /// No description provided for @orderStatusPreparingSubtitle.
  ///
  /// In hu, this message translates to:
  /// **'Elkészítjük az ételeidet.'**
  String get orderStatusPreparingSubtitle;

  /// No description provided for @orderStatusOutForDeliveryTitle.
  ///
  /// In hu, this message translates to:
  /// **'Úton van'**
  String get orderStatusOutForDeliveryTitle;

  /// No description provided for @orderStatusOutForDeliverySubtitle.
  ///
  /// In hu, this message translates to:
  /// **'A futár már úton van hozzád.'**
  String get orderStatusOutForDeliverySubtitle;

  /// No description provided for @orderStatusDeliveredTitle.
  ///
  /// In hu, this message translates to:
  /// **'Kiszállítva'**
  String get orderStatusDeliveredTitle;

  /// No description provided for @orderStatusDeliveredSubtitle.
  ///
  /// In hu, this message translates to:
  /// **'Jó étvágyat!'**
  String get orderStatusDeliveredSubtitle;

  /// No description provided for @orderStatusCancelledTitle.
  ///
  /// In hu, this message translates to:
  /// **'Lemondva'**
  String get orderStatusCancelledTitle;

  /// No description provided for @orderStatusCancelledSubtitle.
  ///
  /// In hu, this message translates to:
  /// **'A rendelés lemondásra került.'**
  String get orderStatusCancelledSubtitle;

  /// No description provided for @orderPayNowTitle.
  ///
  /// In hu, this message translates to:
  /// **'A rendelés még nem fizetett'**
  String get orderPayNowTitle;

  /// No description provided for @orderPayNow.
  ///
  /// In hu, this message translates to:
  /// **'Fizetés · {total}'**
  String orderPayNow(String total);

  /// No description provided for @orderDeliveryWindow.
  ///
  /// In hu, this message translates to:
  /// **'Kiszállítás: {date} {slot}'**
  String orderDeliveryWindow(String date, String slot);

  /// No description provided for @orderAdvanceDemo.
  ///
  /// In hu, this message translates to:
  /// **'Következő állapot (demó)'**
  String get orderAdvanceDemo;

  /// No description provided for @orderCancel.
  ///
  /// In hu, this message translates to:
  /// **'Rendelés lemondása'**
  String get orderCancel;

  /// No description provided for @orderCancelTitle.
  ///
  /// In hu, this message translates to:
  /// **'Lemondod a rendelést?'**
  String get orderCancelTitle;

  /// No description provided for @orderCancelBodyPaid.
  ///
  /// In hu, this message translates to:
  /// **'A kifizetett összeget visszatérítjük.'**
  String get orderCancelBodyPaid;

  /// No description provided for @orderCancelBodyUnpaid.
  ///
  /// In hu, this message translates to:
  /// **'A rendelés nem kerül elkészítésre.'**
  String get orderCancelBodyUnpaid;

  /// No description provided for @orderCancelConfirm.
  ///
  /// In hu, this message translates to:
  /// **'Lemondom'**
  String get orderCancelConfirm;

  /// No description provided for @orderCancelKeep.
  ///
  /// In hu, this message translates to:
  /// **'Mégsem'**
  String get orderCancelKeep;

  /// No description provided for @orderCancelTooLate.
  ///
  /// In hu, this message translates to:
  /// **'A rendelést már nem lehet lemondani: a konyha elkezdte készíteni.'**
  String get orderCancelTooLate;

  /// No description provided for @orderCancelFailed.
  ///
  /// In hu, this message translates to:
  /// **'A lemondás nem sikerült. Próbáld meg újra.'**
  String get orderCancelFailed;

  /// No description provided for @orderSummarySection.
  ///
  /// In hu, this message translates to:
  /// **'Rendelés összegzése'**
  String get orderSummarySection;

  /// No description provided for @orderAddressLabel.
  ///
  /// In hu, this message translates to:
  /// **'Cím'**
  String get orderAddressLabel;

  /// No description provided for @orderSlotLabel.
  ///
  /// In hu, this message translates to:
  /// **'Idősáv'**
  String get orderSlotLabel;

  /// No description provided for @orderPaymentLabel.
  ///
  /// In hu, this message translates to:
  /// **'Fizetés'**
  String get orderPaymentLabel;

  /// No description provided for @orderNoteLabel.
  ///
  /// In hu, this message translates to:
  /// **'Megjegyzés'**
  String get orderNoteLabel;

  /// No description provided for @paymentStatusPending.
  ///
  /// In hu, this message translates to:
  /// **'Fizetésre vár'**
  String get paymentStatusPending;

  /// No description provided for @paymentStatusSucceeded.
  ///
  /// In hu, this message translates to:
  /// **'Kifizetve'**
  String get paymentStatusSucceeded;

  /// No description provided for @paymentStatusFailed.
  ///
  /// In hu, this message translates to:
  /// **'Sikertelen'**
  String get paymentStatusFailed;

  /// No description provided for @paymentStatusCancelled.
  ///
  /// In hu, this message translates to:
  /// **'Megszakítva'**
  String get paymentStatusCancelled;

  /// No description provided for @paymentStatusRefunded.
  ///
  /// In hu, this message translates to:
  /// **'Visszatérítve'**
  String get paymentStatusRefunded;

  /// No description provided for @profileDemoTitle.
  ///
  /// In hu, this message translates to:
  /// **'Ez egy demó'**
  String get profileDemoTitle;

  /// No description provided for @profileDemoBody.
  ///
  /// In hu, this message translates to:
  /// **'A Zaba bemutató változatát használod. Az adatok kitaláltak, a fizetés szimulált, rendelés nem érkezik meg senkihez.'**
  String get profileDemoBody;

  /// No description provided for @profileDevGallery.
  ///
  /// In hu, this message translates to:
  /// **'Komponens-galéria (fejlesztői)'**
  String get profileDevGallery;

  /// No description provided for @profileImageCredits.
  ///
  /// In hu, this message translates to:
  /// **'Képek forrásai'**
  String get profileImageCredits;

  /// No description provided for @profileSignedOutTitle.
  ///
  /// In hu, this message translates to:
  /// **'Nem vagy bejelentkezve'**
  String get profileSignedOutTitle;

  /// No description provided for @profileSignedOutBody.
  ///
  /// In hu, this message translates to:
  /// **'Lépj be vagy regisztrálj, hogy rendelni tudj, és lásd a korábbi rendeléseidet.'**
  String get profileSignedOutBody;

  /// No description provided for @profileSignOut.
  ///
  /// In hu, this message translates to:
  /// **'Kijelentkezés'**
  String get profileSignOut;

  /// No description provided for @ordersSignedOutTitle.
  ///
  /// In hu, this message translates to:
  /// **'Lépj be a rendeléseidhez'**
  String get ordersSignedOutTitle;

  /// No description provided for @ordersSignedOutBody.
  ///
  /// In hu, this message translates to:
  /// **'A leadott rendeléseid és azok állapota itt jelenik meg, ha bejelentkezel.'**
  String get ordersSignedOutBody;

  /// No description provided for @authLoginTitle.
  ///
  /// In hu, this message translates to:
  /// **'Belépés'**
  String get authLoginTitle;

  /// No description provided for @authRegisterTitle.
  ///
  /// In hu, this message translates to:
  /// **'Regisztráció'**
  String get authRegisterTitle;

  /// No description provided for @authCheckoutHint.
  ///
  /// In hu, this message translates to:
  /// **'A rendelés leadásához be kell jelentkezned.'**
  String get authCheckoutHint;

  /// No description provided for @authNameLabel.
  ///
  /// In hu, this message translates to:
  /// **'Név (nem kötelező)'**
  String get authNameLabel;

  /// No description provided for @authEmailLabel.
  ///
  /// In hu, this message translates to:
  /// **'E-mail-cím'**
  String get authEmailLabel;

  /// No description provided for @authPasswordLabel.
  ///
  /// In hu, this message translates to:
  /// **'Jelszó'**
  String get authPasswordLabel;

  /// No description provided for @authPasswordHelper.
  ///
  /// In hu, this message translates to:
  /// **'Legalább {min} karakter'**
  String authPasswordHelper(int min);

  /// No description provided for @authShowPassword.
  ///
  /// In hu, this message translates to:
  /// **'Jelszó megjelenítése'**
  String get authShowPassword;

  /// No description provided for @authHidePassword.
  ///
  /// In hu, this message translates to:
  /// **'Jelszó elrejtése'**
  String get authHidePassword;

  /// No description provided for @authLoginAction.
  ///
  /// In hu, this message translates to:
  /// **'Belépés'**
  String get authLoginAction;

  /// No description provided for @authRegisterAction.
  ///
  /// In hu, this message translates to:
  /// **'Fiók létrehozása'**
  String get authRegisterAction;

  /// No description provided for @authSwitchToRegister.
  ///
  /// In hu, this message translates to:
  /// **'Még nincs fiókod? Regisztrálj'**
  String get authSwitchToRegister;

  /// No description provided for @authSwitchToLogin.
  ///
  /// In hu, this message translates to:
  /// **'Már van fiókod? Lépj be'**
  String get authSwitchToLogin;

  /// No description provided for @authDemoAccount.
  ///
  /// In hu, this message translates to:
  /// **'Belépés demó fiókkal'**
  String get authDemoAccount;

  /// No description provided for @authOr.
  ///
  /// In hu, this message translates to:
  /// **'vagy'**
  String get authOr;

  /// No description provided for @authRegisterDemoNote.
  ///
  /// In hu, this message translates to:
  /// **'Demó: kitalált adatokat adj meg, ne valós személyes adatot.'**
  String get authRegisterDemoNote;

  /// No description provided for @authEmailRequired.
  ///
  /// In hu, this message translates to:
  /// **'Add meg az e-mail-címet.'**
  String get authEmailRequired;

  /// No description provided for @authEmailInvalid.
  ///
  /// In hu, this message translates to:
  /// **'Ez nem tűnik érvényes e-mail-címnek.'**
  String get authEmailInvalid;

  /// No description provided for @authPasswordRequired.
  ///
  /// In hu, this message translates to:
  /// **'Add meg a jelszót.'**
  String get authPasswordRequired;

  /// No description provided for @authPasswordTooShort.
  ///
  /// In hu, this message translates to:
  /// **'A jelszó legalább {min} karakter legyen.'**
  String authPasswordTooShort(int min);

  /// No description provided for @authErrorInvalidCredentials.
  ///
  /// In hu, this message translates to:
  /// **'Hibás e-mail-cím vagy jelszó.'**
  String get authErrorInvalidCredentials;

  /// No description provided for @authErrorEmailTaken.
  ///
  /// In hu, this message translates to:
  /// **'Ezzel az e-mail-címmel már van fiók. Próbálj belépni.'**
  String get authErrorEmailTaken;

  /// No description provided for @authErrorWeakPassword.
  ///
  /// In hu, this message translates to:
  /// **'Ez a jelszó túl gyenge. Válassz hosszabbat vagy bonyolultabbat.'**
  String get authErrorWeakPassword;

  /// No description provided for @authErrorEmailNotConfirmed.
  ///
  /// In hu, this message translates to:
  /// **'Az e-mail-címet még meg kell erősíteni. A demó nem küld e-mailt, szólj a fejlesztőnek.'**
  String get authErrorEmailNotConfirmed;

  /// No description provided for @authErrorTooManyRequests.
  ///
  /// In hu, this message translates to:
  /// **'Túl sok próbálkozás. Várj egy kicsit, és próbáld újra.'**
  String get authErrorTooManyRequests;

  /// No description provided for @authErrorNetwork.
  ///
  /// In hu, this message translates to:
  /// **'Nem sikerült elérni a szervert. Ellenőrizd a netkapcsolatot.'**
  String get authErrorNetwork;

  /// No description provided for @authErrorUnknown.
  ///
  /// In hu, this message translates to:
  /// **'Valami nem sikerült. Próbáld újra.'**
  String get authErrorUnknown;

  /// No description provided for @notificationsTitle.
  ///
  /// In hu, this message translates to:
  /// **'Értesítések'**
  String get notificationsTitle;

  /// No description provided for @notificationsTooltip.
  ///
  /// In hu, this message translates to:
  /// **'Értesítések'**
  String get notificationsTooltip;

  /// No description provided for @notificationsEmptyTitle.
  ///
  /// In hu, this message translates to:
  /// **'Még nincs értesítésed'**
  String get notificationsEmptyTitle;

  /// No description provided for @notificationsEmptyBody.
  ///
  /// In hu, this message translates to:
  /// **'Ha változik a rendelésed állapota, itt is megjelenik.'**
  String get notificationsEmptyBody;

  /// No description provided for @notificationsDemoNote.
  ///
  /// In hu, this message translates to:
  /// **'Demó: az értesítések az appon belül jelennek meg, telefonos push értesítés nincs.'**
  String get notificationsDemoNote;

  /// No description provided for @notificationDismiss.
  ///
  /// In hu, this message translates to:
  /// **'Bezárás'**
  String get notificationDismiss;

  /// No description provided for @notificationOrder.
  ///
  /// In hu, this message translates to:
  /// **'Rendelés {number}'**
  String notificationOrder(String number);

  /// No description provided for @notifReceivedTitle.
  ///
  /// In hu, this message translates to:
  /// **'Megkaptuk a rendelésed'**
  String get notifReceivedTitle;

  /// No description provided for @notifReceivedBody.
  ///
  /// In hu, this message translates to:
  /// **'A fizetés megvan, a konyha hamarosan elkezdi.'**
  String get notifReceivedBody;

  /// No description provided for @notifPreparingTitle.
  ///
  /// In hu, this message translates to:
  /// **'Készül a rendelésed'**
  String get notifPreparingTitle;

  /// No description provided for @notifPreparingBody.
  ///
  /// In hu, this message translates to:
  /// **'Elkezdtük elkészíteni az ételeidet.'**
  String get notifPreparingBody;

  /// No description provided for @notifOutForDeliveryTitle.
  ///
  /// In hu, this message translates to:
  /// **'Úton a futár'**
  String get notifOutForDeliveryTitle;

  /// No description provided for @notifOutForDeliveryBody.
  ///
  /// In hu, this message translates to:
  /// **'A rendelésed már úton van hozzád.'**
  String get notifOutForDeliveryBody;

  /// No description provided for @notifDeliveredTitle.
  ///
  /// In hu, this message translates to:
  /// **'Kiszállítottuk a rendelésed'**
  String get notifDeliveredTitle;

  /// No description provided for @notifDeliveredBody.
  ///
  /// In hu, this message translates to:
  /// **'Jó étvágyat!'**
  String get notifDeliveredBody;

  /// No description provided for @notifCancelledTitle.
  ///
  /// In hu, this message translates to:
  /// **'A rendelésed lemondva'**
  String get notifCancelledTitle;

  /// No description provided for @notifCancelledBody.
  ///
  /// In hu, this message translates to:
  /// **'A rendelés nem kerül elkészítésre.'**
  String get notifCancelledBody;

  /// No description provided for @notifCancelledRefundedBody.
  ///
  /// In hu, this message translates to:
  /// **'A rendelés lemondva, a kifizetett összeget visszatérítjük.'**
  String get notifCancelledRefundedBody;

  /// No description provided for @adminTitle.
  ///
  /// In hu, this message translates to:
  /// **'Zaba kezelőfelület'**
  String get adminTitle;

  /// No description provided for @adminBanner.
  ///
  /// In hu, this message translates to:
  /// **'DEMÓ · kezelőfelület · kitalált adatok'**
  String get adminBanner;

  /// No description provided for @adminLoginTitle.
  ///
  /// In hu, this message translates to:
  /// **'Munkatársi belépés'**
  String get adminLoginTitle;

  /// No description provided for @adminLoginBody.
  ///
  /// In hu, this message translates to:
  /// **'A konyha és az üzemeltetés munkatársainak.'**
  String get adminLoginBody;

  /// No description provided for @adminDemoLogin.
  ///
  /// In hu, this message translates to:
  /// **'Belépés demó munkatársként'**
  String get adminDemoLogin;

  /// No description provided for @adminNoAccessTitle.
  ///
  /// In hu, this message translates to:
  /// **'Nincs jogosultságod'**
  String get adminNoAccessTitle;

  /// No description provided for @adminNoAccessBody.
  ///
  /// In hu, this message translates to:
  /// **'Ezzel a fiókkal nem lehet belépni a kezelőfelületre. Kérd meg egy adminisztrátort, hogy vegyen fel munkatársnak.'**
  String get adminNoAccessBody;

  /// No description provided for @adminRoleAdmin.
  ///
  /// In hu, this message translates to:
  /// **'Admin'**
  String get adminRoleAdmin;

  /// No description provided for @adminRoleOperator.
  ///
  /// In hu, this message translates to:
  /// **'Konyha'**
  String get adminRoleOperator;

  /// No description provided for @adminOrdersTitle.
  ///
  /// In hu, this message translates to:
  /// **'Rendelések'**
  String get adminOrdersTitle;

  /// No description provided for @adminOrderCount.
  ///
  /// In hu, this message translates to:
  /// **'{count} rendelés'**
  String adminOrderCount(int count);

  /// No description provided for @adminOrderPlaced.
  ///
  /// In hu, this message translates to:
  /// **'Leadva: {time} · {count} tétel'**
  String adminOrderPlaced(String time, int count);

  /// No description provided for @adminFilterActive.
  ///
  /// In hu, this message translates to:
  /// **'Aktív'**
  String get adminFilterActive;

  /// No description provided for @adminFilterAwaitingPayment.
  ///
  /// In hu, this message translates to:
  /// **'Fizetésre vár'**
  String get adminFilterAwaitingPayment;

  /// No description provided for @adminFilterClosed.
  ///
  /// In hu, this message translates to:
  /// **'Lezárt'**
  String get adminFilterClosed;

  /// No description provided for @adminFilterAll.
  ///
  /// In hu, this message translates to:
  /// **'Mind'**
  String get adminFilterAll;

  /// No description provided for @adminOrdersEmptyTitle.
  ///
  /// In hu, this message translates to:
  /// **'Nincs ilyen rendelés'**
  String get adminOrdersEmptyTitle;

  /// No description provided for @adminOrdersEmptyBody.
  ///
  /// In hu, this message translates to:
  /// **'Ha új rendelés érkezik, itt azonnal megjelenik.'**
  String get adminOrdersEmptyBody;

  /// No description provided for @adminSelectOrder.
  ///
  /// In hu, this message translates to:
  /// **'Válassz egy rendelést a részletekhez.'**
  String get adminSelectOrder;

  /// No description provided for @adminOrderNotFound.
  ///
  /// In hu, this message translates to:
  /// **'Ez a rendelés nem található.'**
  String get adminOrderNotFound;

  /// No description provided for @adminActionsTitle.
  ///
  /// In hu, this message translates to:
  /// **'Állapot léptetése'**
  String get adminActionsTitle;

  /// No description provided for @adminActionPreparing.
  ///
  /// In hu, this message translates to:
  /// **'Készítés megkezdése'**
  String get adminActionPreparing;

  /// No description provided for @adminActionOutForDelivery.
  ///
  /// In hu, this message translates to:
  /// **'Kiszállítás indítása'**
  String get adminActionOutForDelivery;

  /// No description provided for @adminActionDelivered.
  ///
  /// In hu, this message translates to:
  /// **'Kiszállítva'**
  String get adminActionDelivered;

  /// No description provided for @adminNoActions.
  ///
  /// In hu, this message translates to:
  /// **'Ezen a rendelésen már nincs további teendő.'**
  String get adminNoActions;

  /// No description provided for @adminAwaitingPaymentHint.
  ///
  /// In hu, this message translates to:
  /// **'A rendelés fizetésre vár: a konyha a fizetés után kezdheti el. Állapotot nem léptethetsz, csak lemondhatod.'**
  String get adminAwaitingPaymentHint;

  /// No description provided for @adminCancelBodyPaid.
  ///
  /// In hu, this message translates to:
  /// **'A vásárló kifizette, ezért a fizetés visszatérítésre kerül.'**
  String get adminCancelBodyPaid;

  /// No description provided for @adminCancelBodyUnpaid.
  ///
  /// In hu, this message translates to:
  /// **'A rendelés még nincs kifizetve.'**
  String get adminCancelBodyUnpaid;

  /// No description provided for @adminActionNotAllowed.
  ///
  /// In hu, this message translates to:
  /// **'Ez az állapotváltás most nem engedélyezett, talán közben megváltozott a rendelés.'**
  String get adminActionNotAllowed;

  /// No description provided for @adminActionFailed.
  ///
  /// In hu, this message translates to:
  /// **'A művelet nem sikerült. Próbáld újra.'**
  String get adminActionFailed;

  /// No description provided for @adminHistoryTitle.
  ///
  /// In hu, this message translates to:
  /// **'Előzmények'**
  String get adminHistoryTitle;

  /// No description provided for @adminHistoryPlaced.
  ///
  /// In hu, this message translates to:
  /// **'Rendelés leadva'**
  String get adminHistoryPlaced;

  /// No description provided for @adminActorCustomer.
  ///
  /// In hu, this message translates to:
  /// **'vásárló'**
  String get adminActorCustomer;

  /// No description provided for @adminActorOperator.
  ///
  /// In hu, this message translates to:
  /// **'konyha'**
  String get adminActorOperator;

  /// No description provided for @adminActorPayment.
  ///
  /// In hu, this message translates to:
  /// **'fizetés'**
  String get adminActorPayment;

  /// No description provided for @adminAuditTooltip.
  ///
  /// In hu, this message translates to:
  /// **'Naplózott műveletek'**
  String get adminAuditTooltip;

  /// No description provided for @adminAuditTitle.
  ///
  /// In hu, this message translates to:
  /// **'Naplózott műveletek'**
  String get adminAuditTitle;

  /// No description provided for @adminAuditEmpty.
  ///
  /// In hu, this message translates to:
  /// **'Még nincs naplózott művelet.'**
  String get adminAuditEmpty;

  /// No description provided for @adminAuditSetStatus.
  ///
  /// In hu, this message translates to:
  /// **'Állapotváltás: {from} → {to}'**
  String adminAuditSetStatus(String from, String to);

  /// No description provided for @adminAuditOther.
  ///
  /// In hu, this message translates to:
  /// **'{action}'**
  String adminAuditOther(String action);

  /// No description provided for @adminBackToOrders.
  ///
  /// In hu, this message translates to:
  /// **'Vissza a rendelésekhez'**
  String get adminBackToOrders;

  /// No description provided for @imageCreditsTitle.
  ///
  /// In hu, this message translates to:
  /// **'Képek forrásai'**
  String get imageCreditsTitle;

  /// No description provided for @imageCreditsIntro.
  ///
  /// In hu, this message translates to:
  /// **'A termékfotók a Wikimedia Commonsból származnak, szabad licenc alatt (CC0, közkincs vagy CC BY). A névjelzések:'**
  String get imageCreditsIntro;

  /// No description provided for @imageCreditsEntry.
  ///
  /// In hu, this message translates to:
  /// **'Fotó: {title} · Szerző: {author} · {license}'**
  String imageCreditsEntry(String title, String author, String license);
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['hu'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'hu':
      return AppLocalizationsHu();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
