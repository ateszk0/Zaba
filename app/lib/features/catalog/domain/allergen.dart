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
}
