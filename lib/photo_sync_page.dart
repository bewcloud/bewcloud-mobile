import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';

import 'config.dart';

class PhotoSyncPage extends StatefulWidget {
  const PhotoSyncPage({super.key});

  @override
  State<PhotoSyncPage> createState() => _PhotoSyncPageState();
}

class _PhotoSyncPageState extends State<PhotoSyncPage> {
  List<AssetPathEntity> _albums = [];
  Set<String> _selectedAlbumIds = {};
  bool _isLoading = true;
  int _chosenAccountIndex = 0;
  List<CloudAccount> _accounts = [];
  final ConfigStorage _configStorage = ConfigStorage();

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    setState(() {
      _isLoading = true;
    });
    await _loadCloudAccounts();
    await _loadChosenAccountIndex();
    await _loadAlbums();
    await _loadSelectedAlbums();
    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _loadCloudAccounts() async {
    final config = await _configStorage.readConfig();
    if (!mounted) return;
    setState(() {
      _accounts = config.accounts;
    });
  }

  Future<void> _loadChosenAccountIndex() async {
    final prefs = await SharedPreferences.getInstance();
    final loadedIndex = prefs.getInt('chosenAccountIndex') ?? 0;
    if (!mounted) return;
    setState(() {
      _chosenAccountIndex = (loadedIndex >= 0 && loadedIndex < _accounts.length)
          ? loadedIndex
          : 0;
    });
  }

  Future<void> _updateChosenAccountIndex(int newIndex) async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _chosenAccountIndex = newIndex;
      prefs.setInt('chosenAccountIndex', _chosenAccountIndex);
      _loadSelectedAlbums();
    });
  }

  Future<void> _loadAlbums() async {
    final permissionState = await PhotoManager.requestPermissionExtend();
    if (permissionState.isAuth) {
      final albums = await PhotoManager.getAssetPathList(
        type: RequestType.image,
      );
      setState(() {
        _albums = albums;
      });
    } else {
      PhotoManager.openSetting();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Photo library permission is required.')),
      );
    }
  }

  Future<void> _loadSelectedAlbums() async {
    final currentAccount = _currentAccount;
    if (currentAccount != null) {
      if (!mounted) return;
      setState(() {
        _selectedAlbumIds =
            (currentAccount.selectedPhotoAlbumIds ?? []).toSet();
      });
    } else {
      if (!mounted) return;
      setState(() {
        _selectedAlbumIds = {};
      });
    }
  }

  Future<void> _saveSelectedAlbums() async {
    final currentAccount = _currentAccount;
    if (currentAccount == null) return;

    final config = await _configStorage.readConfig();
    final accountIndex = config.accounts.indexWhere((acc) =>
        acc.url == currentAccount.url &&
        acc.username == currentAccount.username);

    if (accountIndex != -1) {
      config.accounts[accountIndex].selectedPhotoAlbumIds =
          _selectedAlbumIds.toList();
      await _configStorage.writeConfig(config);
    }
    // Optionally show a confirmation message
    // ScaffoldMessenger.of(context).showSnackBar(
    //   const SnackBar(content: Text('Sync settings saved.')),
    // );
  }

  void _toggleAlbumSelection(String albumId) {
    if (!mounted) return;
    setState(() {
      if (_selectedAlbumIds.contains(albumId)) {
        _selectedAlbumIds.remove(albumId);
      } else {
        _selectedAlbumIds.add(albumId);
      }
    });
    _saveSelectedAlbums();
  }

  CloudAccount? get _currentAccount {
    if (_accounts.isNotEmpty && _chosenAccountIndex < _accounts.length) {
      return _accounts[_chosenAccountIndex];
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final currentAccount = _currentAccount;

    var listAccountIndex = 0;
    final accountsToChooseFrom = (_accounts.map((account) {
      final thisAccountIndex = listAccountIndex++;
      List<Widget> children = [
        Text('${account.username} - ${account.url}',
            overflow: TextOverflow.ellipsis),
      ];
      if (thisAccountIndex == _chosenAccountIndex) {
        children.add(const Spacer());
        children.add(const Icon(Icons.check, size: 18));
      }
      return ElevatedButton(
        style: const ButtonStyle(
            backgroundColor: MaterialStatePropertyAll(Colors.lightBlue),
            foregroundColor: MaterialStatePropertyAll(Colors.black)),
        onPressed: () async {
          await _updateChosenAccountIndex(thisAccountIndex);
          if (!context.mounted) return;
          Navigator.pop(context);
        },
        child: Row(children: children),
      );
    }).toList());

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Select Photo Folders to Sync'),
            if (currentAccount != null)
              Text(
                'Account: ${currentAccount.username}',
                style: Theme.of(context).textTheme.titleSmall,
              )
          ],
        ),
        actions: [
          if (_accounts.length > 1)
            IconButton(
              icon: const Icon(Icons.switch_account_outlined),
              tooltip: 'Switch Account',
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (BuildContext context) {
                    return AlertDialog(
                      title: const Text('Choose Account'),
                      content: SingleChildScrollView(
                        child: ListBody(
                          children: accountsToChooseFrom,
                        ),
                      ),
                      actions: <Widget>[
                        TextButton(
                          child: const Text('Cancel'),
                          onPressed: () {
                            Navigator.of(context).pop();
                          },
                        ),
                      ],
                    );
                  },
                );
              },
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : currentAccount == null
              ? const Center(
                  child: Text(
                      'No accounts configured. Please add an account in Settings.'))
              : _albums.isEmpty
                  ? const Center(
                      child:
                          Text('No photo albums found or permission denied.'))
                  : ListView.builder(
                      itemCount: _albums.length,
                      itemBuilder: (context, index) {
                        final album = _albums[index];
                        final isSelected = _selectedAlbumIds.contains(album.id);
                        return CheckboxListTile(
                          title: Text(album.name),
                          value: isSelected,
                          onChanged: (bool? value) {
                            if (value != null) {
                              _toggleAlbumSelection(album.id);
                            }
                          },
                        );
                      },
                    ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Workmanager().registerOneOffTask(
            "manualPhotoSync_${DateTime.now().millisecondsSinceEpoch}",
            "auto-upload-photos",
            constraints: Constraints(
              networkType: NetworkType.connected,
            ),
          );

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                  'Manual photo sync initiated. It will run in the background.'),
              duration: Duration(seconds: 3),
            ),
          );
        },
        tooltip: 'Sync Photos Now',
        icon: const Icon(Icons.sync),
        label: const Text('Sync Now'),
      ),
    );
  }
}
