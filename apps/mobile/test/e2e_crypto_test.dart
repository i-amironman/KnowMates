import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:knowmates/chat/e2e_crypto.dart';

class _MemStorage extends FlutterSecureStorage {
  _MemStorage(this._ns);

  final String _ns;
  static final _data = <String, String>{};

  String _k(String key) => '$_ns::$key';

  @override
  Future<void> write({
    required String key,
    required String? value,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    _data[_k(key)] = value ?? '';
  }

  @override
  Future<String?> read({
    required String key,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async =>
      _data[_k(key)];

  @override
  Future<void> delete({
    required String key,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    _data.remove(_k(key));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('encrypt roundtrip between two identities', () async {
    const channel = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async => null);

    final alice = E2eCrypto(storage: _MemStorage('alice'));
    final bob = E2eCrypto(storage: _MemStorage('bob'));

    final aPub = await alice.myPublicKeyBase64();
    final bPub = await bob.myPublicKeyBase64();

    final sealed = await alice.encrypt('Hello secure world', bPub);
    final plain = await bob.decrypt(
      ciphertextBase64: sealed.ciphertext,
      nonceBase64: sealed.nonce,
      theirPublicKeyBase64: aPub,
    );
    expect(plain, 'Hello secure world');

    final back = await bob.encrypt('Reply', aPub);
    final reply = await alice.decrypt(
      ciphertextBase64: back.ciphertext,
      nonceBase64: back.nonce,
      theirPublicKeyBase64: bPub,
    );
    expect(reply, 'Reply');
  });
}
