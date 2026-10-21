import '../../../l10n/generated/app_localizations.dart';
import '../domain/allergen.dart';

extension AllergenLabel on Allergen {
  String label(AppLocalizations l10n) => switch (this) {
    Allergen.gluten => l10n.allergenGluten,
    Allergen.crustaceans => l10n.allergenCrustaceans,
    Allergen.egg => l10n.allergenEgg,
    Allergen.fish => l10n.allergenFish,
    Allergen.peanut => l10n.allergenPeanut,
    Allergen.soy => l10n.allergenSoy,
    Allergen.milk => l10n.allergenMilk,
    Allergen.nuts => l10n.allergenNuts,
    Allergen.celery => l10n.allergenCelery,
    Allergen.mustard => l10n.allergenMustard,
    Allergen.sesame => l10n.allergenSesame,
    Allergen.sulphites => l10n.allergenSulphites,
    Allergen.lupin => l10n.allergenLupin,
    Allergen.molluscs => l10n.allergenMolluscs,
  };
}
