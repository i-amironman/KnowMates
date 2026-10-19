import 'package:flutter_test/flutter_test.dart';
import 'package:knowmates/api/client.dart';
import 'package:knowmates/push/device_token.dart';

void main() {
  test('registerDeviceToken completes off mobile hosts', () async {
    final client = ApiClient(
      baseUrl: 'http://127.0.0.1:1',
      readTokens: () async => (access: 'a', refresh: 'r'),
      writeTokens: (_) async {},
    );
    await registerDeviceToken(client);
  });
}
