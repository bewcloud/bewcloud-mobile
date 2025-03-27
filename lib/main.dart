import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:workmanager/workmanager.dart';
import 'dart:io';

import 'files_page.dart';
import 'settings_page.dart';
import 'config.dart';
import 'photos.dart';
import 'api.dart';
import 'photo_sync_page.dart';

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    await dotenv.load(fileName: ".env");
    bool success = false;

    try {
      switch (task) {
        case Workmanager.iOSBackgroundTask:
        case "autoUploadPhotos":
        case "auto-upload-photos":
          debugPrint("Workmanager: Running auto-upload task");
          final config = await ConfigStorage().readConfig();

          final permissionState = await PhotoManager.requestPermissionExtend();
          if (!permissionState.isAuth) {
            debugPrint("Workmanager: Photo permission not granted. Skipping task.");
            return Future.value(false);
          }
          await PhotoManager.setIgnorePermissionCheck(true);

          for (var account in config.accounts) {
            final selectedAlbumIds = account.selectedPhotoAlbumIds;

            if (selectedAlbumIds == null || selectedAlbumIds.isEmpty) {
              debugPrint("Workmanager: Account ${account.username} has no albums selected. Skipping.");
              continue;
            }

            debugPrint("Workmanager: Processing account ${account.username}");
            final api = Api(account: account);
            const String basePhotoDir = '/Photos/';

            bool baseDirExists = await api.ensureDirectoryExists(basePhotoDir);
            if (!baseDirExists) {
               debugPrint("Workmanager: Failed to ensure base directory $basePhotoDir exists for account ${account.username}. Skipping account.");
               continue;
            }

            final Map<String, List<File>> filesToUploadByAlbum =
                await getFilesFromAlbums(selectedAlbumIds);

            if (filesToUploadByAlbum.isEmpty) {
               debugPrint("Workmanager: No files found in selected albums for account ${account.username}.");
               continue;
            }

            for (var albumEntry in filesToUploadByAlbum.entries) {
              final albumName = albumEntry.key;
              final filesInAlbum = albumEntry.value;
              final sanitizedAlbumName = albumName.replaceAll(RegExp(r'[<>:"/\\|?*]'), '_').trim();
              if (sanitizedAlbumName.isEmpty) {
                 debugPrint("Workmanager: Skipping album with empty sanitized name (original: '$albumName').");
                 continue;
              }
              final String targetDirectoryPath = '$basePhotoDir$sanitizedAlbumName/';

              debugPrint("Workmanager: Processing album '$albumName' -> $targetDirectoryPath");

              bool albumDirExists = await api.ensureDirectoryExists(targetDirectoryPath);
              if (!albumDirExists) {
                debugPrint("Workmanager: Failed to ensure album directory $targetDirectoryPath exists. Skipping album '$albumName'.");
                continue;
              }

              List<CloudFile> existingFiles = [];
              try {
                 existingFiles = await api.fetchFiles(targetDirectoryPath);
              } catch (e) {
                 debugPrint("Workmanager: Error fetching existing files from $targetDirectoryPath: $e. Proceeding with uploads.");
                 existingFiles = [];
              }

              for (var fileToUpload in filesInAlbum) {
                final fileName = fileToUpload.path.split('/').last;

                if (existingFiles.any((existingFile) => existingFile.name == fileName)) {
                  // debugPrint("Workmanager: File '$fileName' already exists in $targetDirectoryPath. Skipping.");
                  continue;
                }

                debugPrint("Workmanager: Uploading '$fileName' to $targetDirectoryPath");
                try {
                  bool uploaded = await api.uploadFile(targetDirectoryPath, fileToUpload);
                  if (!uploaded) {
                     debugPrint("Workmanager: Failed to upload '$fileName' to $targetDirectoryPath.");
                  }
                } catch (e) {
                   debugPrint("Workmanager: Error uploading '$fileName' to $targetDirectoryPath: $e");
                }
              }
            }
          }
          success = true;
          debugPrint("Workmanager: Auto-upload task finished.");
          break;

        default:
           debugPrint("Workmanager: Received unknown task: $task");
           success = true;
           break;
      }
    } catch (e, stacktrace) {
       debugPrint("Workmanager: Error during background task execution: $e\n$stacktrace");
       success = false;
    }

    return Future.value(success);
  });
}

Future main() async {
  await dotenv.load(fileName: ".env");

  Workmanager().initialize(callbackDispatcher, isInDebugMode: false);
  Workmanager().registerPeriodicTask(
    "auto-upload-photos",
    "autoUploadPhotos",
    constraints: Constraints(
      networkType: NetworkType.unmetered,
      requiresBatteryNotLow: true,
      requiresCharging: false,
    ),
    frequency: const Duration(hours: 2),
  );

  await PhotoManager.clearFileCache();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData(
          useMaterial3: true,
          primarySwatch: Colors.lightBlue,
          brightness: Brightness.dark,
          colorScheme: const ColorScheme.dark()),
      home: const AppNavigation(),
    );
  }
}

class AppNavigation extends StatefulWidget {
  const AppNavigation({super.key});

  @override
  State<AppNavigation> createState() => _AppNavigationState();
}

class _AppNavigationState extends State<AppNavigation> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final List<Widget> _widgetOptions = [
      FilesPage(theme: theme),
      PhotoSyncPage(),
      SettingsPage(theme: theme),
    ];
    
    return Scaffold(
      body: Center(
        child: _widgetOptions.elementAt(_selectedIndex),
      ),
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.folder_outlined),
            activeIcon: Icon(Icons.folder),
            label: 'Files',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.photo_library_outlined),
            activeIcon: Icon(Icons.photo_library),
            label: 'Photos Sync',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings_outlined),
            activeIcon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
      ),
    );
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }
}
