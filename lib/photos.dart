import 'dart:io';

import 'package:flutter/material.dart'; // Import for debugPrint
import 'package:photo_manager/photo_manager.dart';

class RecentFile {
  File file;
  bool isPhoto;
  bool isVideo;

  RecentFile(
      {required this.file, required this.isPhoto, required this.isVideo});
}

Future<List<RecentFile>> getRecentFiles() async {
  final now = DateTime.now();
  final lastWeek = now.subtract(const Duration(days: 7));

  await PhotoManager.setIgnorePermissionCheck(true);

  final List<AssetPathEntity> imageAlbumPaths =
      await PhotoManager.getAssetPathList(
          onlyAll: true, type: RequestType.image);
  final List<AssetPathEntity> videoAlbumPaths =
      await PhotoManager.getAssetPathList(
          onlyAll: true, type: RequestType.video);

  List<RecentFile> recentFiles = [];

  for (var imageAlbumPath in imageAlbumPaths) {
    final List<AssetEntity> items =
        await imageAlbumPath.getAssetListPaged(page: 0, size: 100);

    for (var item in items) {
      if (item.createDateTime.isAfter(lastWeek)) {
        recentFiles.add(RecentFile(
            file: (await item.originFile)!, isPhoto: true, isVideo: false));
      }
    }
  }

  for (var videoAlbumPath in videoAlbumPaths) {
    final List<AssetEntity> items =
        await videoAlbumPath.getAssetListPaged(page: 0, size: 100);

    for (var item in items) {
      if (item.createDateTime.isAfter(lastWeek)) {
        recentFiles.add(RecentFile(
            file: (await item.originFile)!, isPhoto: false, isVideo: true));
      }
    }
  }

  return recentFiles;
}

Future<Map<String, List<File>>> getFilesFromAlbums(List<String> albumIds) async {
  Map<String, List<File>> albumFiles = {};
  final List<AssetPathEntity> allAlbums = await PhotoManager.getAssetPathList(
    type: RequestType.all,
  );

  final Map<String, AssetPathEntity> albumMap = {
    for (var album in allAlbums) album.id: album
  };

  for (String albumId in albumIds) {
    final album = albumMap[albumId];
    if (album == null) {
      debugPrint("Could not find album with ID: $albumId");
      continue;
    }

    try {
      List<AssetEntity> assets = [];
      int page = 0;
      int size = 100;
      List<AssetEntity> currentPageAssets;
      do {
        currentPageAssets = await album.getAssetListPaged(page: page, size: size);
        assets.addAll(currentPageAssets);
        page++;
      } while (currentPageAssets.isNotEmpty);


      List<File> files = [];
      for (var asset in assets) {
        if (asset.type != AssetType.image && asset.type != AssetType.video) {
          continue;
        }
        try {
          final file = await asset.originFile;
          if (file != null) {
            files.add(file);
          } else {
             debugPrint("Could not get originFile for asset ${asset.id} in album ${album.name}");
          }
        } catch (e) {
           debugPrint("Error getting file for asset ${asset.id}: $e");
        }
      }
      albumFiles[album.name] = files;
    } catch (e) {
      debugPrint("Error processing album '${album.name}' (ID $albumId): $e");
    }
  }
  return albumFiles;
}
