const _folded = {
  'á': 'a',
  'é': 'e',
  'í': 'i',
  'ó': 'o',
  'ö': 'o',
  'ő': 'o',
  'ú': 'u',
  'ü': 'u',
  'ű': 'u',
};

/// Lower-cases [input] and removes Hungarian diacritics, so a search for
/// "rantott" finds "Rántott". Used to filter the small in-memory demo catalog;
/// the real backend does the same with Postgres `unaccent`.
String foldText(String input) {
  final buffer = StringBuffer();
  for (final rune in input.toLowerCase().runes) {
    final char = String.fromCharCode(rune);
    buffer.write(_folded[char] ?? char);
  }
  return buffer.toString();
}
