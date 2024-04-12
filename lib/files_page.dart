import 'dart:io';
import 'dart:math';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:prompt_dialog/prompt_dialog.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';

import 'config.dart';
import 'api.dart';

double log10(num x) => log(x) / ln10;

String readableFileSize(int sizeInBytes) {
  if (sizeInBytes <= 0) return "0";

  const base = 1024;
  final units = ["B", "KB", "MB", "GB", "TB"];

  int digitGroups = (log10(sizeInBytes) / log10(base)).floor();
  return "${NumberFormat("#,##0.#").format(sizeInBytes / pow(base, digitGroups))} ${units[digitGroups]}";
}

class FilesPage extends StatefulWidget {
  const FilesPage({super.key, required this.theme});

  final ThemeData theme;

  @override
  State<FilesPage> createState() => _FilesPageState();
}

class FileListItem extends CloudDirectory {
  String label;
  int sizeInBytes;

  FileListItem(
      {required super.parentPath,
      required super.name,
      required this.label,
      required this.sizeInBytes});
}

class _FilesPageState extends State<FilesPage> {
  int _chosenAccountIndex = 0;
  String _currentPath = '/';
  List<CloudAccount> accounts = [];
  List<CloudDirectory> directories = [];
  List<CloudFile> files = [];
  Api? api;

  @override
  void initState() {
    super.initState();
    _loadCloudAccounts();
    _loadChosenAccountIndex();
  }

  Future<void> _loadChosenAccountIndex() async {
    final prefs = await SharedPreferences.getInstance();

    setState(() {
      _chosenAccountIndex = prefs.getInt('chosenAccountIndex') ?? 0;
    });
  }

  Future<void> _updateChosenAccountIndex(int newIndex) async {
    final prefs = await SharedPreferences.getInstance();

    setState(() {
      _chosenAccountIndex = newIndex;
      prefs.setInt('chosenAccountIndex', _chosenAccountIndex);
    });
  }

  Future<void> _loadCloudAccounts() async {
    final config = await ConfigStorage().readConfig();

    setState(() {
      accounts = config.accounts;
    });

    _loadDirectoriesAndFiles();
  }

  Future<void> _loadDirectoriesAndFiles() async {
    CloudAccount? cloudAccount =
        accounts.isNotEmpty ? accounts[_chosenAccountIndex] : null;

    if (cloudAccount == null) {
      return;
    }

    if (api == null) {
      setState(() {
        api = Api(account: cloudAccount);
      });
    }

    final resultDirectories = await api!.fetchDirectories(_currentPath);

    setState(() {
      directories = resultDirectories;
    });

    final resultFiles = await api!.fetchFiles(_currentPath);

    setState(() {
      files = resultFiles;
    });
  }

  Future<void> _downloadFile(String filePath, BuildContext context) async {
    CloudAccount? cloudAccount =
        accounts.isNotEmpty ? accounts[_chosenAccountIndex] : null;

    if (cloudAccount == null) {
      return;
    }

    if (api == null) {
      setState(() {
        api = Api(account: cloudAccount);
      });
    }

    final downloadedFile = await api!.downloadFile(filePath);

    if (downloadedFile == null) {
      if (!context.mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to download file.'),
          duration: Duration(seconds: 5),
          backgroundColor: Colors.red,
        ),
      );

      return;
    }

    await FilePicker.platform.saveFile(
      dialogTitle: 'Save file:',
      fileName: downloadedFile.name,
      bytes: downloadedFile.bytes,
    );
  }

  Future<void> _uploadFile(BuildContext context) async {
    CloudAccount? cloudAccount =
        accounts.isNotEmpty ? accounts[_chosenAccountIndex] : null;

    if (cloudAccount == null) {
      return;
    }

    if (api == null) {
      setState(() {
        api = Api(account: cloudAccount);
      });
    }

    FilePickerResult? result =
        await FilePicker.platform.pickFiles(allowMultiple: true);

    if (result == null) {
      return;
    }

    List<File> files = result.paths.map((path) => File(path!)).toList();

    for (final newFile in files) {
      final uploadedFile = await api!.uploadFile(_currentPath, newFile);

      if (!uploadedFile) {
        if (!context.mounted) {
          return;
        }

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to upload file.'),
            duration: Duration(seconds: 5),
            backgroundColor: Colors.red,
          ),
        );

        return;
      }
    }

    _loadDirectoriesAndFiles();
  }

  Future<void> _createDirectory(BuildContext context) async {
    CloudAccount? cloudAccount =
        accounts.isNotEmpty ? accounts[_chosenAccountIndex] : null;

    if (cloudAccount == null) {
      return;
    }

    if (api == null) {
      setState(() {
        api = Api(account: cloudAccount);
      });
    }

    String? directoryName =
        await prompt(context, title: const Text('Directory name'));

    if (directoryName == null) {
      return;
    }

    final createdDirectory =
        await api!.createDirectory(_currentPath, directoryName);

    if (!createdDirectory) {
      if (!context.mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to create directory.'),
          duration: Duration(seconds: 5),
          backgroundColor: Colors.red,
        ),
      );

      return;
    }

    _loadDirectoriesAndFiles();
  }

  Future<void> _deleteFile(String fileName, BuildContext context) async {
    CloudAccount? cloudAccount =
        accounts.isNotEmpty ? accounts[_chosenAccountIndex] : null;

    if (cloudAccount == null) {
      return;
    }

    if (api == null) {
      setState(() {
        api = Api(account: cloudAccount);
      });
    }

    final deletedFile = await api!.deleteFile(_currentPath, fileName);

    if (!deletedFile) {
      if (!context.mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to delete file.'),
          duration: Duration(seconds: 5),
          backgroundColor: Colors.red,
        ),
      );

      return;
    }

    _loadDirectoriesAndFiles();
  }

  @override
  Widget build(BuildContext context) {
    CloudAccount? cloudAccount =
        accounts.isNotEmpty ? accounts[_chosenAccountIndex] : null;

    var listAccountIndex = 0;

    final accountsToChooseFrom = (accounts.map((account) {
      final thisAccountIndex = listAccountIndex++;

      List<Widget> children = [
        Text('${account.username} - ${account.url}'),
      ];

      if (thisAccountIndex == _chosenAccountIndex) {
        children.add(const Spacer());
        children.add(const Icon(
          Icons.check,
          size: 18,
        ));
      }

      return ElevatedButton(
        style: const ButtonStyle(
            backgroundColor: MaterialStatePropertyAll(Colors.lightBlue),
            foregroundColor: MaterialStatePropertyAll(Colors.black)),
        onPressed: () async {
          await _updateChosenAccountIndex(thisAccountIndex);

          if (!context.mounted) {
            return;
          }

          Navigator.pop(context);
        },
        child: Row(
          children: children,
        ),
      );
    }).toList());

    List<FileListItem> listItems = directories
        .map((directory) => FileListItem(
              parentPath: directory.parentPath,
              name: directory.name,
              label: directory.name,
              sizeInBytes: 0,
            ))
        .toList();

    final pathParts = _currentPath.split('/');
    pathParts.removeAt(0);
    pathParts.removeLast();
    final parentName = pathParts.isNotEmpty ? pathParts.removeLast() : '';

    if (_currentPath != '/') {
      var parentPath = '/${pathParts.join('/')}/';
      parentPath = parentPath.replaceAll('//', '/');

      listItems.insert(
          0,
          FileListItem(
            parentPath: parentPath,
            name: '',
            label: '..',
            sizeInBytes: 0,
          ));
    }

    listItems.addAll(files.map((file) => FileListItem(
          parentPath: file.parentPath,
          name: file.name,
          label: file.name,
          sizeInBytes: file.sizeInBytes,
        )));

    return Scaffold(
      appBar: accounts.isEmpty
          ? null
          : AppBar(
              title: GestureDetector(
                child: Row(
                  children: [
                    Expanded(
                        child: Text(
                      parentName.isEmpty ? _currentPath : parentName,
                      overflow: TextOverflow.ellipsis,
                    )),
                    Padding(
                      padding: const EdgeInsets.only(left: 12.0),
                      child: Text(cloudAccount!.username),
                    ),
                    const Padding(
                      padding: EdgeInsets.only(left: 12),
                      child: Icon(Icons.arrow_drop_down_circle_outlined),
                    ),
                  ],
                ),
                onTap: () {
                  showModalBottomSheet<void>(
                      context: context,
                      builder: (BuildContext context) {
                        return Container(
                          height: 200,
                          color: Colors.black45,
                          child: Padding(
                            padding: const EdgeInsets.all(12.0),
                            child: Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Text(
                                    'Choose account',
                                    style:
                                        TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                  const Spacer(),
                                  ...accountsToChooseFrom,
                                  const Spacer(flex: 1),
                                  ElevatedButton(
                                    style: const ButtonStyle(
                                        backgroundColor:
                                            MaterialStatePropertyAll(
                                                Colors.black),
                                        foregroundColor:
                                            MaterialStatePropertyAll(
                                                Colors.white)),
                                    onPressed: () {
                                      Navigator.pop(context);
                                    },
                                    child: const Text('Cancel / Close'),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      });
                },
              ),
            ),
      body: listItems.isEmpty
          ? Center(
              child: Text(
              accounts.isEmpty
                  ? 'No accounts found.\n\nAdd a new one from the settings tab.'
                  : 'No directories or files found. Add a new one below!',
              textAlign: TextAlign.center,
            ))
          : ListView.builder(
              scrollDirection: Axis.vertical,
              physics: const AlwaysScrollableScrollPhysics(),
              shrinkWrap: false,
              itemCount: listItems.length,
              itemBuilder: (BuildContext context, int index) {
                final item = listItems[index];
                var itemIcon = const Icon(Icons.folder_outlined);

                if (item.name == '.Trash' && item.parentPath == '/') {
                  itemIcon = const Icon(Icons.delete_outline);
                }

                var children = [
                  itemIcon,
                  Padding(
                    padding: const EdgeInsets.only(left: 12.0),
                    child: Text(item.label),
                  ),
                ];

                if (item.sizeInBytes > 0) {
                  children.add(const Spacer());
                  children.add(
                    Padding(
                      padding: const EdgeInsets.only(left: 12.0),
                      child: Text(readableFileSize(item.sizeInBytes)),
                    ),
                  );
                }

                return GestureDetector(
                  onTap: () {
                    if (item.sizeInBytes == 0) {
                      setState(() {
                        directories = [];
                        files = [];

                        if (item.name.isNotEmpty) {
                          _currentPath = '${item.parentPath}${item.name}/';
                        } else {
                          _currentPath = item.parentPath;
                        }
                      });

                      _loadDirectoriesAndFiles();
                      return;
                    }

                    showModalBottomSheet<void>(
                        context: context,
                        builder: (BuildContext context) {
                          return Container(
                            height: 200,
                            color: Colors.black45,
                            child: Padding(
                              padding: const EdgeInsets.all(12.0),
                              child: Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Text(
                                      'Choose action',
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold),
                                    ),
                                    const Spacer(),
                                    ElevatedButton(
                                      style: const ButtonStyle(
                                          backgroundColor:
                                              MaterialStatePropertyAll(
                                                  Colors.lightBlue),
                                          foregroundColor:
                                              MaterialStatePropertyAll(
                                                  Colors.black)),
                                      onPressed: () async {
                                        await _downloadFile(
                                            '${item.parentPath}${item.name}',
                                            context);

                                        if (!context.mounted) {
                                          return;
                                        }

                                        Navigator.pop(context);
                                      },
                                      child: const Text('Download file'),
                                    ),
                                    const Spacer(),
                                    ElevatedButton(
                                      style: const ButtonStyle(
                                          backgroundColor:
                                              MaterialStatePropertyAll(
                                                  Colors.red),
                                          foregroundColor:
                                              MaterialStatePropertyAll(
                                                  Colors.white)),
                                      onPressed: () async {
                                        Navigator.pop(context);

                                        showDialog(
                                            context: context,
                                            builder: (BuildContext subContext) {
                                              return AlertDialog(
                                                title:
                                                    const Text('Are you sure?'),
                                                content: const Text(
                                                    'Are you sure you want to delete this file?'),
                                                actions: [
                                                  TextButton(
                                                      onPressed: () async {
                                                        await _deleteFile(
                                                            item.name, context);

                                                        if (!subContext
                                                            .mounted) {
                                                          return;
                                                        }

                                                        Navigator.pop(
                                                            subContext);
                                                      },
                                                      child: const Text('Yes')),
                                                  TextButton(
                                                      onPressed: () {
                                                        Navigator.pop(
                                                            subContext);
                                                      },
                                                      child: const Text('No'))
                                                ],
                                              );
                                            });
                                      },
                                      child: const Text('Delete file'),
                                    ),
                                    const Spacer(flex: 1),
                                    ElevatedButton(
                                      style: const ButtonStyle(
                                          backgroundColor:
                                              MaterialStatePropertyAll(
                                                  Colors.black),
                                          foregroundColor:
                                              MaterialStatePropertyAll(
                                                  Colors.white)),
                                      onPressed: () {
                                        Navigator.pop(context);
                                      },
                                      child: const Text('Cancel / Close'),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        });
                  },
                  child: Card(
                    child: Container(
                      margin: const EdgeInsets.all(8.0),
                      padding: const EdgeInsets.all(8.0),
                      child: Row(
                        children: children,
                      ),
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: accounts.isEmpty
          ? null
          : FloatingActionButton(
              onPressed: () {
                showModalBottomSheet<void>(
                    context: context,
                    builder: (BuildContext context) {
                      return Container(
                        height: 200,
                        color: Colors.black45,
                        child: Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Text(
                                  'Choose action',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                                const Spacer(),
                                ElevatedButton(
                                  style: const ButtonStyle(
                                      backgroundColor: MaterialStatePropertyAll(
                                          Colors.lightBlue),
                                      foregroundColor: MaterialStatePropertyAll(
                                          Colors.black)),
                                  onPressed: () async {
                                    await _uploadFile(context);

                                    if (!context.mounted) {
                                      return;
                                    }

                                    Navigator.pop(context);
                                  },
                                  child: const Text('Upload file'),
                                ),
                                const Spacer(),
                                ElevatedButton(
                                  style: const ButtonStyle(
                                      backgroundColor: MaterialStatePropertyAll(
                                          Colors.lightBlue),
                                      foregroundColor: MaterialStatePropertyAll(
                                          Colors.black)),
                                  onPressed: () async {
                                    await _createDirectory(context);

                                    if (!context.mounted) {
                                      return;
                                    }

                                    Navigator.pop(context);
                                  },
                                  child: const Text('Create directory'),
                                ),
                                const Spacer(flex: 1),
                                ElevatedButton(
                                  style: const ButtonStyle(
                                      backgroundColor: MaterialStatePropertyAll(
                                          Colors.black),
                                      foregroundColor: MaterialStatePropertyAll(
                                          Colors.white)),
                                  onPressed: () {
                                    Navigator.pop(context);
                                  },
                                  child: const Text('Cancel / Close'),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    });
              },
              tooltip: 'Upload file or create directory',
              foregroundColor: Theme.of(context).primaryColor,
              backgroundColor: Colors.lightBlue,
              shape: const CircleBorder(),
              child: const Icon(Icons.add),
            ),
    );
  }
}
