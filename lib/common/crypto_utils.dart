import 'dart:convert';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:encrypt/encrypt.dart';

import 'package:x25519/x25519.dart';

class CryptoUtils {
  static String aesKey = "";
  static String salt = "";
  static List<int>? dhPrivateKey;
  static List<int>? dhPublicKey;

  static init() {
    var keyPair = generateKeyPair();
    dhPrivateKey = keyPair.privateKey;
    dhPublicKey = keyPair.publicKey;
  }

  static generateMD5(String content) {
    return md5.convert(utf8.encode(content)).toString();
  }

  static setServerKeyAndSalt(String serverKey, String salt) {
    CryptoUtils.salt = salt;
    var sharedSecret = X25519(dhPrivateKey!, base64Decode(serverKey));
    var key = generateMD5(base64Encode(sharedSecret));
    if (key != "" && key.length > 16) {
      aesKey = key.substring(0, 16);
    } else {
      aesKey = key;
    }
  }

  // 加密
  static String aesEncrypt(String content) {
    final iv = IV(Uint8List.fromList(salt.codeUnits));
    final key = Key(Uint8List.fromList(aesKey.codeUnits));
    final encrypter = Encrypter(AES(key, mode: AESMode.cbc));
    return encrypter.encrypt(content, iv: iv).base64;
  }

  // 解密
  static String aesDecrypt(String content) {
    final iv = IV(Uint8List.fromList(salt.codeUnits));
    final key = Key(Uint8List.fromList(aesKey.codeUnits));
    var encrypter = Encrypter(AES(key, mode: AESMode.cbc));
    Encrypted encrypted = Encrypted(base64Decode(content));
    var decrypted = encrypter.decrypt(encrypted, iv: iv);
    return decrypted;
  }
}
