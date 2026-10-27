import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// X25519 + ChaCha20-Poly1305; server only sees ciphertext (Signal-style building block).
class E2eCrypto {
  E2eCrypto({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  static const _privateKeyKey = 'e2e_x25519_private_v1';
  static const _info = 'knowmates-chat-v1';

  final FlutterSecureStorage _storage;
  final _x25519 = X25519();
  final _cipher = Chacha20.poly1305Aead();

  Future<SimpleKeyPair> _keyPair() async {
    final saved = await _storage.read(key: _privateKeyKey);
    if (saved != null) {
      final seed = base64Decode(saved);
      return _x25519.newKeyPairFromSeed(seed);
    }
    final pair = await _x25519.newKeyPair();
    final private = await pair.extractPrivateKeyBytes();
    await _storage.write(key: _privateKeyKey, value: base64Encode(private));
    return pair;
  }

  Future<String> myPublicKeyBase64() async {
    final pair = await _keyPair();
    final pub = await pair.extractPublicKey();
    return base64Encode(pub.bytes);
  }

  Future<SecretKey> _shared(String theirPublicKeyBase64) async {
    final pair = await _keyPair();
    final remote = SimplePublicKey(
      base64Decode(theirPublicKeyBase64),
      type: KeyPairType.x25519,
    );
    final raw = await _x25519.sharedSecretKey(
      keyPair: pair,
      remotePublicKey: remote,
    );
    return await Hkdf(
      hmac: Hmac.sha256(),
      outputLength: 32,
    ).deriveKey(
      secretKey: raw,
      info: utf8.encode(_info),
    );
  }

  Future<({String ciphertext, String nonce})> encrypt(
    String plaintext,
    String theirPublicKeyBase64,
  ) async {
    final secret = await _shared(theirPublicKeyBase64);
    final box = await _cipher.encrypt(
      utf8.encode(plaintext),
      secretKey: secret,
    );
    final packed = [...box.cipherText, ...box.mac.bytes];
    return (
      ciphertext: base64Encode(packed),
      nonce: base64Encode(box.nonce),
    );
  }

  Future<String> decrypt({
    required String ciphertextBase64,
    required String nonceBase64,
    required String theirPublicKeyBase64,
  }) async {
    final secret = await _shared(theirPublicKeyBase64);
    final packed = base64Decode(ciphertextBase64);
    if (packed.length < 17) {
      throw StateError('bad ciphertext');
    }
    final cipherText = packed.sublist(0, packed.length - 16);
    final mac = Mac(packed.sublist(packed.length - 16));
    final clear = await _cipher.decrypt(
      SecretBox(cipherText, nonce: base64Decode(nonceBase64), mac: mac),
      secretKey: secret,
    );
    return utf8.decode(clear);
  }
}
