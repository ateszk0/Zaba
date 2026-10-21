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
/// "rantott" finds "Rántott". The menu is downloaded once and searched here, in
/// the app (docs/decisions.md says when this has to move to the server).
String foldText(String input) {
  final buffer = StringBuffer();
  for (final rune in input.toLowerCase().runes) {
    final char = String.fromCharCode(rune);
    buffer.write(_folded[char] ?? char);
  }
  return buffer.toString();
}
