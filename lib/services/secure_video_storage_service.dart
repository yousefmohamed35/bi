import 'dart:convert';
import 'dart:io';

import 'package:cryptography/cryptography.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Encrypts downloaded videos at rest (AES-GCM) and binds keys to the device.
///
/// Important security notes:
/// - This is best-effort protection in Flutter. Rooted devices / dynamic
///   instrumentation can still capture frames or decrypted bytes at runtime.
/// - We keep the *stored* file encrypted and only decrypt to a temporary file
///   for playback, then delete it.
class SecureVideoStorageService {
  SecureVideoStorageService._();
  static final instance = SecureVideoStorageService._();

  final _algo = AesGcm.with256bits();

  Future<String> _deviceBindingString() async {
    final info = DeviceInfoPlugin();
    if (Platform.isAndroid) {
      final a = await info.androidInfo;
      return '${a.brand}|${a.model}|${a.id}|${a.fingerprint}';
    }
    if (Platform.isIOS) {
      final i = await info.iosInfo;
      return '${i.name}|${i.model}|${i.identifierForVendor}';
    }
    return 'unknown-device';
  }

  Future<SecretKey> _deriveKey({
    required String lessonId,
    required String userId,
  }) async {
    final binding = await _deviceBindingString();
    final input = utf8.encode('stp.video|$binding|$userId|$lessonId');

    // Derive a deterministic 32-byte key (SHA-256).
    final hash = await Sha256().hash(input);
    return SecretKey(hash.bytes);
  }

  Future<Directory> _vaultDir() async {
    final dir = await getApplicationDocumentsDirectory();
    final vault = Directory(p.join(dir.path, 'secure_videos'));
    if (!await vault.exists()) {
      await vault.create(recursive: true);
    }
    return vault;
  }

  /// Encrypt a plaintext mp4 file and return encrypted path.
  ///
  /// Output format:
  /// - `<path>.enc` containing: nonce(12) + mac(16) + ciphertext(N)
  Future<String> encryptFile({
    required File inputFile,
    required String lessonId,
    required String userId,
  }) async {
    final key = await _deriveKey(lessonId: lessonId, userId: userId);
    final bytes = await inputFile.readAsBytes();
    final nonce = _algo.newNonce();

    final secretBox = await _algo.encrypt(
      bytes,
      secretKey: key,
      nonce: nonce,
    );

    final vault = await _vaultDir();
    final outName =
        '${p.basenameWithoutExtension(inputFile.path)}_$lessonId.enc';
    final outFile = File(p.join(vault.path, outName));

    final outBytes = <int>[
      ...secretBox.nonce,
      ...secretBox.mac.bytes,
      ...secretBox.cipherText,
    ];
    await outFile.writeAsBytes(outBytes, flush: true);
    return outFile.path;
  }

  /// Decrypt an encrypted file to a temp mp4 file for playback.
  Future<File> decryptToTempFile({
    required File encryptedFile,
    required String lessonId,
    required String userId,
  }) async {
    final key = await _deriveKey(lessonId: lessonId, userId: userId);
    final bytes = await encryptedFile.readAsBytes();
    if (bytes.length < (12 + 16)) {
      throw StateError('Encrypted file is too small');
    }
    final nonce = bytes.sublist(0, 12);
    final mac = Mac(bytes.sublist(12, 28));
    final cipherText = bytes.sublist(28);

    final clear = await _algo.decrypt(
      SecretBox(cipherText, nonce: nonce, mac: mac),
      secretKey: key,
    );

    final tempDir = await getTemporaryDirectory();
    final out = File(p.join(
      tempDir.path,
      'lesson_${lessonId}_${DateTime.now().millisecondsSinceEpoch}.mp4',
    ));
    await out.writeAsBytes(clear, flush: true);
    return out;
  }
}
