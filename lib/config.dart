import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

class CloudAccount {
  String url;
  String username;
  String password;
  String? autoUploadDestinationDirectory;
  List<String>? selectedPhotoAlbumIds;

  CloudAccount(
      {required this.url,
      required this.username,
      required this.password,
      this.autoUploadDestinationDirectory,
      this.selectedPhotoAlbumIds});

  factory CloudAccount.fromJson(Map<String, dynamic> json) {
    List<String>? albumIds;
    if (json['selectedPhotoAlbumIds'] != null) {
      albumIds = List<String>.from(json['selectedPhotoAlbumIds'] as List);
    }

    return CloudAccount(
      url: json['url'] as String,
      username: json['username'] as String,
      password: json['password'] as String,
      autoUploadDestinationDirectory:
          json['autoUploadDestinationDirectory'] as String?,
      selectedPhotoAlbumIds: albumIds,
    );
  }

  Map<String, dynamic> toJson() => {
        'url': url,
        'username': username,
        'password': password,
        'autoUploadDestinationDirectory': autoUploadDestinationDirectory,
        'selectedPhotoAlbumIds': selectedPhotoAlbumIds,
      };
}

class Config {
  List<CloudAccount> accounts;

  Config({required this.accounts});

  factory Config.fromJson(Map<String, dynamic> json) {
    final accounts = (json['accounts'] as List)
        .cast<Map<String, dynamic>>()
        .map((jsonAccount) => CloudAccount.fromJson(jsonAccount))
        .toList();

    return Config(accounts: accounts);
  }

  Map<String, dynamic> toJson() => {
        'accounts': accounts.map((account) => account.toJson()).toList(),
      };
}

Config parseConfig(String jsonString) {
  final configJson = jsonDecode(jsonString) as Map<String, dynamic>;

  final config = Config.fromJson(configJson);

  return config;
}

String stringifyConfig(Config config) {
  final jsonString = jsonEncode(config.toJson());

  return jsonString;
}

class ConfigStorage {
  Future<String> get _localPath async {
    final directory = await getApplicationDocumentsDirectory();
    return directory.path;
  }

  Future<File> get _localFile async {
    final path = await _localPath;
    return File('$path/config.json');
  }

  Future<Config> readConfig() async {
    try {
      final file = await _localFile;
      final contents = await file.readAsString();
      return parseConfig(contents);
    } catch (e) {
      // If encountering an error, return default config
      return Config(accounts: []);
    }
  }

  Future<File> writeConfig(Config config) async {
    final file = await _localFile;
    final jsonString = stringifyConfig(config);
    return file.writeAsString(jsonString);
  }
}
