import 'dart:io';

import 'package:photo_gallery/photo_gallery.dart';

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

  final List<Album> imageAlbums = await PhotoGallery.listAlbums(
    mediumType: MediumType.image,
    newest: true,
    hideIfEmpty: true,
  );

  final List<Album> videoAlbums = await PhotoGallery.listAlbums(
    mediumType: MediumType.video,
    newest: true,
    hideIfEmpty: true,
  );

  List<RecentFile> recentFiles = [];

  for (var imageAlbum in imageAlbums) {
    final media = await imageAlbum.listMedia();

    for (var item in media.items) {
      if (item.creationDate == null) {
        continue;
      }

      if (item.creationDate!.isAfter(lastWeek)) {
        recentFiles.add(RecentFile(
            file: await item.getFile(), isPhoto: true, isVideo: false));
      }
    }
  }

  for (var videoAlbum in videoAlbums) {
    final media = await videoAlbum.listMedia();

    for (var item in media.items) {
      if (item.creationDate == null) {
        continue;
      }

      if (item.creationDate!.isAfter(lastWeek)) {
        recentFiles.add(RecentFile(
            file: await item.getFile(), isPhoto: false, isVideo: true));
      }
    }
  }

  return recentFiles;
}
