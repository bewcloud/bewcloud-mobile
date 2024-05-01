import 'package:flutter/material.dart';

import 'config.dart';
import 'add_account_page.dart';
import 'api.dart';
import 'photos.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key, required this.theme});

  final ThemeData theme;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  List<CloudAccount> accounts = [];

  @override
  void initState() {
    super.initState();
    _loadCloudAccounts();
  }

  Future<void> _loadCloudAccounts() async {
    final config = await ConfigStorage().readConfig();

    setState(() {
      accounts = config.accounts;
    });
  }

  Future<void> _deleteCloudAccount(int indexToRemove) async {
    var config = await ConfigStorage().readConfig();

    config.accounts.removeAt(indexToRemove);

    await ConfigStorage().writeConfig(config);

    setState(() {
      accounts = config.accounts;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: accounts.isEmpty
          ? const Center(child: Text('No accounts found. Add a new one below!'))
          : ListView.builder(
              itemCount: accounts.length,
              itemBuilder: (BuildContext context, int index) {
                final account = accounts[index];

                var children = [
                  Text(
                    'Manage ${account.username}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  ElevatedButton(
                    style: const ButtonStyle(
                        backgroundColor: MaterialStatePropertyAll(Colors.red),
                        foregroundColor:
                            MaterialStatePropertyAll(Colors.white)),
                    onPressed: () {
                      Navigator.pop(context);

                      showDialog(
                          context: context,
                          builder: (BuildContext subContext) {
                            return AlertDialog(
                              title: const Text('Are you sure?'),
                              content: const Text(
                                  'Are you sure you want to delete this account?'),
                              actions: [
                                TextButton(
                                    onPressed: () async {
                                      await _deleteCloudAccount(index);

                                      if (!subContext.mounted) {
                                        return;
                                      }

                                      Navigator.pop(subContext);
                                    },
                                    child: const Text('Yes')),
                                TextButton(
                                    onPressed: () {
                                      Navigator.pop(subContext);
                                    },
                                    child: const Text('No'))
                              ],
                            );
                          });
                    },
                    child: const Text('Delete account'),
                  ),
                  const Spacer(flex: 1),
                  ElevatedButton(
                    style: const ButtonStyle(
                        backgroundColor: MaterialStatePropertyAll(Colors.black),
                        foregroundColor:
                            MaterialStatePropertyAll(Colors.white)),
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel / Close'),
                  ),
                ];

                // If account has auto-upload set, add button to manually trigger it
                final destinationDirectoryPath =
                    account.autoUploadDestinationDirectory;
                if (destinationDirectoryPath != null) {
                  children.insertAll(1, [
                    const Spacer(),
                    ElevatedButton(
                      style: const ButtonStyle(
                          backgroundColor:
                              MaterialStatePropertyAll(Colors.lightBlue),
                          foregroundColor:
                              MaterialStatePropertyAll(Colors.black)),
                      onPressed: () async {
                        Navigator.pop(context);

                        final List<RecentFile> recentFiles =
                            await getRecentFiles();

                        if (!context.mounted) {
                          return;
                        }

                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                              content: Text(
                                  'Uploading ${recentFiles.length} file${recentFiles.length == 1 ? '' : 's'}...')),
                        );

                        final api = Api(account: account);

                        final accountDestinationFiles =
                            await api.fetchFiles(destinationDirectoryPath);

                        for (var recentFile in recentFiles) {
                          final fileName =
                              recentFile.file.path.split('/').removeLast();

                          // Check if file exists in destination
                          if (accountDestinationFiles.any((destinationFile) =>
                              destinationFile.name == fileName)) {
                            continue;
                          }

                          await api.uploadFile(
                              destinationDirectoryPath, recentFile.file);
                        }

                        if (!context.mounted) {
                          return;
                        }

                        ScaffoldMessenger.of(context).hideCurrentSnackBar();

                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Files uploaded!'),
                            duration: Duration(seconds: 5),
                            backgroundColor: Colors.green,
                          ),
                        );
                      },
                      child: const Text('Force auto-upload now'),
                    ),
                  ]);
                }

                return Align(
                  alignment: Alignment.topLeft,
                  child: GestureDetector(
                    onTap: () {
                      showModalBottomSheet<void>(
                          context: context,
                          builder: (BuildContext context) {
                            return Container(
                              height: 250,
                              color: Colors.black45,
                              child: Padding(
                                padding: const EdgeInsets.all(12.0),
                                child: Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    mainAxisSize: MainAxisSize.min,
                                    children: children,
                                  ),
                                ),
                              ),
                            );
                          });
                    },
                    child: Container(
                      margin: const EdgeInsets.all(8.0),
                      padding: const EdgeInsets.all(8.0),
                      child: Card(
                          child: Padding(
                        padding: const EdgeInsets.all(14.0),
                        child: Text(
                          '${accounts[index].username} - ${accounts[index].url}',
                          overflow: TextOverflow.ellipsis,
                        ),
                      )),
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const AddAccountPage()),
          );
        },
        tooltip: 'Add new account',
        foregroundColor: Theme.of(context).primaryColor,
        backgroundColor: Colors.lightBlue,
        shape: const CircleBorder(),
        child: const Icon(Icons.add),
      ),
    );
  }
}
