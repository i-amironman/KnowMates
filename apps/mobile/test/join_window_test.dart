import 'package:flutter_test/flutter_test.dart';
import 'package:knowmates/call/join_window.dart';

void main() {
  test('join opens ten minutes before start', () {
    final start = DateTime.utc(2026, 10, 19, 12);
    expect(canJoin(start.subtract(const Duration(minutes: 11)), 'scheduled', start), isFalse);
    expect(canJoin(start.subtract(const Duration(minutes: 9)), 'scheduled', start), isTrue);
    expect(canJoin(start.add(const Duration(hours: 2)), 'scheduled', start), isTrue);
    expect(canJoin(start, 'cancelled', start), isFalse);
    expect(canJoin(start, 'disputed', start), isFalse);
  });
}
