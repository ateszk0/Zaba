import 'package:flutter_test/flutter_test.dart';
import 'package:zaba/core/text/fold_text.dart';

void main() {
  test('removes Hungarian diacritics and lower-cases', () {
    expect(foldText('Rántott CSIRKEMELL'), 'rantott csirkemell');
    expect(
      foldText('Őszibarack, Űrlap, Túrógombóc'),
      'oszibarack, urlap, turogomboc',
    );
    expect(foldText('Árvíztűrő tükörfúrógép'), 'arvizturo tukorfurogep');
  });

  test('leaves other characters untouched', () {
    expect(foldText('Cola 0,33 l'), 'cola 0,33 l');
    expect(foldText(''), '');
  });
}
