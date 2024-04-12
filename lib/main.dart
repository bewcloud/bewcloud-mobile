import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

// import 'types.dart';
import 'files_page.dart';
import 'settings_page.dart';

Future main() async {
  await dotenv.load(fileName: ".env");

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
