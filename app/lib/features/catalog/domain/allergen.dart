/// The 14 allergens that must be declared in the EU. [code] is the value stored
/// in the database (`products.allergens`).
enum Allergen {
  gluten('gluten'),
  crustaceans('crustaceans'),
  egg('egg'),
  fish('fish'),
  peanut('peanut'),
  soy('soy'),
  milk('milk'),
  nuts('nuts'),
  celery('celery'),
  mustard('mustard'),
  sesame('sesame'),
  sulphites('sulphites'),
  lupin('lupin'),
  molluscs('molluscs');

  const Allergen(this.code);

  final String code;

  /// Throws a [FormatException] for a code this app does not know. Allergen
  /// information is a safety matter: an unknown code must stop the menu from
  /// loading, never be dropped quietly.
  static Allergen fromCode(String code) {
    for (final allergen in values) {
      if (allergen.code == code) {
        return allergen;
      }
    }
    throw FormatException('Unknown allergen code', code);
  }
}
