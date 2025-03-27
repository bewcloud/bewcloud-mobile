import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'config.dart';
import 'encryption.dart';

Future<Map<String, dynamic>> makeApiConnection(String url, String username,
    String password, String apiPath, Map<String, dynamic> requestBody) async {
  final jsonString = jsonEncode(requestBody);
  final uri = Uri.parse('${url.replaceFirst("/dav", "")}/api/files/$apiPath');
  final String basicAuth =
      'Basic ${base64.encode(utf8.encode('$username:$password'))}';
  final headers = {
    HttpHeaders.contentTypeHeader: 'application/json',
    HttpHeaders.authorizationHeader: basicAuth
  };

  try {
    final response = await http.post(uri, headers: headers, body: jsonString);

    if (response.statusCode == 200) {
      final result = jsonDecode(response.body) as Map<String, dynamic>;

      if (result['success']) {
        return result;
      }
    }
  } catch (error) {
    debugPrint(error.toString());
  }

  return <String, dynamic>{};
}

class CloudDirectory {
  String parentPath;
  String name;

  CloudDirectory({required this.parentPath, required this.name});

  factory CloudDirectory.fromJson(Map<String, dynamic> json) {
    return CloudDirectory(
      parentPath: json['parent_path'] as String,
      name: json['directory_name'] as String,
    );
  }
}

class CloudFile {
  String parentPath;
  String name;
  int sizeInBytes;

  CloudFile(
      {required this.parentPath,
      required this.name,
      required this.sizeInBytes});

  factory CloudFile.fromJson(Map<String, dynamic> json) {
    return CloudFile(
      parentPath: json['parent_path'] as String,
      name: json['file_name'] as String,
      sizeInBytes: json['size_in_bytes'] as int,
    );
  }
}

class DownloadedFile {
  Uint8List bytes;
  String name;

  DownloadedFile({required this.bytes, required this.name});
}

class Api {
  CloudAccount account;
  late String decryptedPassword;

  Api({required this.account}) {
    decryptedPassword = decryptPassword(account.password);
  }

  Future<List<CloudDirectory>> fetchDirectories(String parentPath) async {
    final body = {'parentPath': parentPath};
    final result = await makeApiConnection(account.url, account.username,
        decryptedPassword, 'get-directories', body);

    if (result['success']) {
      final directories = (result['directories'] as List)
          .cast<Map<String, dynamic>>()
          .map((directoryJson) => CloudDirectory.fromJson(directoryJson))
          .toList();

      return directories;
    }

    return [];
  }

  Future<bool> createDirectory(String parentPath, String name) async {
    final body = {'parentPath': parentPath, 'name': name};
    final result = await makeApiConnection(account.url, account.username,
        decryptedPassword, 'create-directory', body);

    if (result['success']) {
      return true;
    }

    return false;
  }

  Future<List<CloudFile>> fetchFiles(String parentPath) async {
    final body = {'parentPath': parentPath};
    final result = await makeApiConnection(
        account.url, account.username, decryptedPassword, 'get', body);

    if (result['success']) {
      final directories = (result['files'] as List)
          .cast<Map<String, dynamic>>()
          .map((fileJson) => CloudFile.fromJson(fileJson))
          .toList();

      return directories;
    }

    return [];
  }

  Future<bool> ensureDirectoryExists(String path) async {
    if (path == '/') return true; // Root always exists

    final parts = path.split('/').where((p) => p.isNotEmpty).toList();
    String currentCumulativePath = '/';

    for (final part in parts) {
      String nextPath = '$currentCumulativePath$part/';
      try {
        bool exists = false;
        try {
          await fetchDirectories(currentCumulativePath); // Check parent first
          final existingDirs = await fetchDirectories(currentCumulativePath);
          exists = existingDirs.any((dir) => dir.name == part);
        } catch (e) {
           if (currentCumulativePath != '/') {
              debugPrint("Error checking parent directory $currentCumulativePath: $e");
              return false;
           }
           exists = false;
        }


        if (!exists) {
          bool created = await createDirectory(currentCumulativePath, part);
          if (!created) {
             try {
                final existingDirs = await fetchDirectories(currentCumulativePath);
                if (!existingDirs.any((dir) => dir.name == part)) {
                   debugPrint("Failed to create directory part: $part in $currentCumulativePath and it still doesn't exist.");
                   return false;
                }
             } catch (e) {
                debugPrint("Error confirming directory creation $nextPath: $e");
                return false;
             }
          }
        }
        currentCumulativePath = nextPath;
      } catch (e) {
         debugPrint("Error ensuring directory $nextPath exists: $e");
         return false;
      }
    }
    return true;
  }

  Future<DownloadedFile?> downloadFile(String filePath) async {
    final uri = Uri.parse('${account.url}$filePath');
    final String basicAuth =
        'Basic ${base64.encode(utf8.encode('${account.username}:$decryptedPassword'))}';
    final headers = {HttpHeaders.authorizationHeader: basicAuth};

    try {
      final response = await http.get(uri, headers: headers);

      if (response.statusCode == 200) {
        final fileName = filePath.split('/').removeLast();
        final downloadedFile =
            DownloadedFile(bytes: response.bodyBytes, name: fileName);

        return downloadedFile;
      }
    } catch (error) {
      debugPrint(error.toString());
    }

    return null;
  }

  Future<bool> uploadFile(String parentPath, File file) async {
    final fileName = file.path.split('/').removeLast();
    final uri = Uri.parse('${account.url}$parentPath$fileName');
    final String basicAuth =
        'Basic ${base64.encode(utf8.encode('${account.username}:$decryptedPassword'))}';
    final headers = {
      HttpHeaders.authorizationHeader: basicAuth,
      HttpHeaders.contentLengthHeader: (await file.length()).toString(),
    };

    try {
      final response =
          await http.put(uri, headers: headers, body: await file.readAsBytes());

      if (response.statusCode == 201) {
        return true;
      }
    } catch (error) {
      debugPrint(error.toString());
    }

    return false;
  }

  Future<bool> deleteFile(String parentPath, String name) async {
    final body = {'parentPath': parentPath, 'name': name};
    final result = await makeApiConnection(
        account.url, account.username, decryptedPassword, 'delete', body);

    if (result['success']) {
      return true;
    }

    return false;
  }
}
