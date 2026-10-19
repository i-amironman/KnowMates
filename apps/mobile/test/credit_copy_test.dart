import 'package:flutter_test/flutter_test.dart';
import 'package:knowmates/credit/ledger_label.dart';

void main() {
  test('ledger reason copy', () {
    expect(ledgerLabel('starter_grant'), 'Starter credits');
    expect(ledgerLabel('session_hold'), 'Session booked');
    expect(ledgerLabel('session_release'), 'Session cancelled');
    expect(ledgerLabel('teach_completed'), 'Taught a session');
  });
}
