/// A menu category. [iconKey] is a plain string so the domain stays free of
/// Flutter types; the presentation layer maps it to an icon.
class Category {
  const Category({required this.id, required this.name, required this.iconKey});

  final String id;
  final String name;
  final String iconKey;
}
