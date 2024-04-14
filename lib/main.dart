import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:workmanager/workmanager.dart';

import 'files_page.dart';
import 'settings_page.dart';
import 'config.dart';
import 'photos.dart';
import 'api.dart';

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    await dotenv.load(fileName: ".env");

    switch (task) {
      case Workmanager.iOSBackgroundTask:
      case "autoUploadPhotos":
      case "auto-upload-photos":
        final config = await ConfigStorage().readConfig();

        final isThereAnyAutoUploadConfig = config.accounts
            .any((account) => account.autoUploadDestinationDirectory != null);

        if (!isThereAnyAutoUploadConfig) {
          break;
        }

        final List<RecentFile> recentFiles = await getRecentFiles();

        for (var account in config.accounts) {
          final destinationDirectoryPath =
              account.autoUploadDestinationDirectory;

          if (destinationDirectoryPath == null) {
            continue;
          }

          final api = Api(account: account);

          final accountDestinationFiles =
              await api.fetchFiles(destinationDirectoryPath);

          for (var recentFile in recentFiles) {
            final fileName = recentFile.file.path.split('/').removeLast();

            // Check if file exists in destination
            if (accountDestinationFiles
                .any((destinationFile) => destinationFile.name == fileName)) {
              continue;
            }

            await api.uploadFile(destinationDirectoryPath, recentFile.file);
          }
        }
        break;
    }
    bool success = true;
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
  int currentPageIndex = 0;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        leading: Padding(
          padding: const EdgeInsets.only(top: 0, bottom: 0, left: 8, right: 0),
          child: Image.asset(
            "assets/images/app-icon.png",
          ),
        ),
        title: const Text(
          'bewCloud',
          style: TextStyle(fontWeight: FontWeight.w300),
        ),
      ),
      bottomNavigationBar: NavigationBar(
        onDestinationSelected: (int index) {
          setState(() {
            currentPageIndex = index;
          });
        },
        indicatorColor: Colors.lightBlue,
        selectedIndex: currentPageIndex,
        destinations: const <Widget>[
          NavigationDestination(
            selectedIcon: Icon(Icons.folder),
            icon: Icon(Icons.folder_outlined),
            label: 'Files',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
      body: <Widget>[
        FilesPage(theme: theme),
        SettingsPage(theme: theme),
      ][currentPageIndex],
    );
  }
}
