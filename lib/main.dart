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
import 'notifications.dart';

final NotificationService notificationService = NotificationService();

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    await dotenv.load(fileName: ".env");
    await notificationService.init();
    bool success = false;
    String errorMessage = 'An unknown error occurred.';

    try {
      switch (task) {
        case Workmanager.iOSBackgroundTask:
        case "autoUploadPhotos":
        case "auto-upload-photos":
          await notificationService.showSyncProgressNotification();
          final config = await ConfigStorage().readConfig();

          await PhotoManager.setIgnorePermissionCheck(true);

          bool anyAccountSynced = false;
          int totalFilesUploaded = 0;
          int totalFilesSkipped = 0;

          for (var account in config.accounts) {
            final selectedAlbumIds = account.selectedPhotoAlbumIds;

            if (selectedAlbumIds == null || selectedAlbumIds.isEmpty) {
              continue;
            }
            anyAccountSynced = true;

            final api = Api(account: account);
            const String basePhotoDir = '/Photos/';

            bool baseDirExists = await api.ensureDirectoryExists(basePhotoDir);
            if (!baseDirExists) {
               errorMessage = 'Failed to ensure base directory $basePhotoDir for ${account.username}.';
               throw Exception(errorMessage);
            }

            final Map<String, List<File>> filesToUploadByAlbum =
                await getFilesFromAlbums(selectedAlbumIds);

            if (filesToUploadByAlbum.isEmpty) {
               continue;
            }

            for (var albumEntry in filesToUploadByAlbum.entries) {
              final albumName = albumEntry.key;
              final filesInAlbum = albumEntry.value;
              final sanitizedAlbumName = albumName.replaceAll(RegExp(r'[<>:"/\\|?*]'), '_').trim();
              if (sanitizedAlbumName.isEmpty) {
                 continue;
              }
              final String targetDirectoryPath = '$basePhotoDir$sanitizedAlbumName/';

              bool albumDirExists = await api.ensureDirectoryExists(targetDirectoryPath);
              if (!albumDirExists) {
                errorMessage = 'Failed ensure album directory $targetDirectoryPath for ${account.username}.';
                throw Exception(errorMessage);
              }

              List<CloudFile> existingFiles = [];
              try {
                 existingFiles = await api.fetchFiles(targetDirectoryPath);
              } catch (e) {
                 errorMessage = 'Error fetching existing files from $targetDirectoryPath: $e';
                 throw Exception(errorMessage);
              }

              for (var fileToUpload in filesInAlbum) {
                final fileName = fileToUpload.path.split('/').last;

                if (existingFiles.any((existingFile) => existingFile.name == fileName)) {
                  totalFilesSkipped++;
                  continue;
                }

                try {
                  bool uploaded = await api.uploadFile(targetDirectoryPath, fileToUpload);
                  if (uploaded) {
                    totalFilesUploaded++;
                  } else {
                  }
                } catch (e) {
                   errorMessage = 'Error uploading $fileName to $targetDirectoryPath: $e';
                   throw Exception(errorMessage);
                }
              }
            }
          }

          if (!anyAccountSynced) {
             await notificationService.showSyncCompleteNotification(message: 'No accounts configured for photo sync.');
          } else {
             await notificationService.showSyncCompleteNotification(message: 'Sync complete. Uploaded $totalFilesUploaded file(s). Skipped $totalFilesSkipped existing.');
          }
          success = true;
          break;

        default:
           success = true;
           break;
      }
    } catch (e, stacktrace) {
       debugPrint("Workmanager: Error during background task execution: $e\n$stacktrace");
       await notificationService.showSyncErrorNotification(message: errorMessage);
       success = false;
    }

    return Future.value(success);
  });
}

Future main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await dotenv.load(fileName: ".env");
  await notificationService.init();
  await notificationService.requestPermissions();

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
            icon: Icon(Icons.settings),
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
