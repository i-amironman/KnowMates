import 'package:flutter_test/flutter_test.dart';
import 'package:knowmates/setup/weekday.dart';

void main() {
  test('UI dropdown index matches API weekday Mon=0 Sun=6', () {
    expect(apiWeekdayLabel(0), 'Mon');
    expect(apiWeekdayLabel(6), 'Sun');
    for (var i = 0; i < 7; i++) {
      expect(apiWeekdayLabel(i), kApiWeekdayLabels[i]);
    }
  });
}
