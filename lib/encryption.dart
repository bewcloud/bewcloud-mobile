import 'dart:convert';

import 'package:encrypt/encrypt.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

final stringKey = dotenv.env['PASSWORD_SECRET_KEY']!;

Encrypted encryptPassword(String plainText) {
  final key = Key.fromUtf8(stringKey);
  final base64key = Key.fromUtf8(base64Url.encode(key.bytes).substring(0, 32));

  final fernet = Fernet(base64key);
  final encrypter = Encrypter(fernet);

  var encrypted = encrypter.encrypt(plainText);
  return encrypted;
}

String decryptPassword(String encryptedBase64) {
  final key = Key.fromUtf8(stringKey);
  final base64key = Key.fromUtf8(base64Url.encode(key.bytes).substring(0, 32));

  final fernet = Fernet(base64key);
  final encrypter = Encrypter(fernet);

  var decrypted = encrypter.decrypt64(encryptedBase64);
  return decrypted;
}
