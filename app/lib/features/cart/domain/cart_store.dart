/// Where the cart is kept between visits.
abstract interface class CartStore {
  /// The saved cart (product id to quantity); empty if there is none.
  Map<String, int> load();

  void save(Map<String, int> lines);
}

/// Keeps nothing. For tests and as the default.
class MemoryCartStore implements CartStore {
  MemoryCartStore([Map<String, int> initial = const {}])
    : _lines = Map.of(initial);

  Map<String, int> _lines;

  @override
  Map<String, int> load() => Map.of(_lines);

  @override
  void save(Map<String, int> lines) => _lines = Map.of(lines);
}
