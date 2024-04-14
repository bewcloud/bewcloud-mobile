import 'dart:io';

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
