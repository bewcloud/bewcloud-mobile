import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'config.dart';
import 'encryption.dart';

Future<bool> testApiConnection(
    String url, String username, String password) async {
  final body = {'parentPath': '/'};
  final jsonString = jsonEncode(body);
  final uri =
      Uri.parse('${url.replaceFirst("/dav", "")}/api/files/get-directories');
  final String basicAuth =
      'Basic ${base64.encode(utf8.encode('$username:$password'))}';
  final headers = {
    HttpHeaders.contentTypeHeader: 'application/json',
    HttpHeaders.authorizationHeader: basicAuth
  };

  try {
    final response = await http.post(uri, headers: headers, body: jsonString);

    if (response.statusCode == 200) {
      final result = jsonDecode(response.body) as Map<String, dynamic>;

      if (result['success'] == true) {
        return true;
      }
    }
  } catch (error) {
    debugPrint(error.toString());
  }

  return false;
}

class AddAccountPage extends StatefulWidget {
  const AddAccountPage({super.key});

  @override
  State<AddAccountPage> createState() => _AddAccountPageState();
}

class _AddAccountPageState extends State<AddAccountPage> {
  final TextEditingController _urlTextFieldController = TextEditingController();
  final TextEditingController _usernameTextFieldController =
      TextEditingController();
  final TextEditingController _passwordTextFieldController =
      TextEditingController();

  List<CloudAccount> accounts = [];

  String newAccountUrl = "";
  String newAccountUsername = "";
  String newAccountPassword = "";

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

  Future<void> _saveNewCloudAccount() async {
    var config = await ConfigStorage().readConfig();

    final encryptedPassword = encryptPassword(newAccountPassword);

    final newCloudAccount = CloudAccount(
        url: newAccountUrl,
        username: newAccountUsername,
        password: encryptedPassword.base64);

    config.accounts.add(newCloudAccount);

    await ConfigStorage().writeConfig(config);

    setState(() {
      accounts = config.accounts;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Add new account',
          style: TextStyle(fontWeight: FontWeight.w300),
        ),
      ),
      body: Align(
        alignment: Alignment.topCenter,
        child: Align(
          alignment: Alignment.topLeft,
          child: Container(
            margin: const EdgeInsets.all(8.0),
            padding: const EdgeInsets.all(8.0),
            child: Column(
              children: [
                Expanded(
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(14.0),
                      child: TextField(
                        keyboardType: TextInputType.url,
                        autocorrect: false,
                        onChanged: (value) {
                          setState(() {
                            newAccountUrl = value;
                          });
                        },
                        controller: _urlTextFieldController,
                        decoration: const InputDecoration(
                            label: Text('WebDav URL'),
                            hintText: 'https://bewcloud.example.com/dav'),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(14.0),
                      child: TextField(
                        keyboardType: TextInputType.emailAddress,
                        autocorrect: false,
                        onChanged: (value) {
                          setState(() {
                            newAccountUsername = value;
                          });
                        },
                        controller: _usernameTextFieldController,
                        decoration: const InputDecoration(
                            label: Text('Email'),
                            hintText: 'jane.doe@example.com'),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(14.0),
                      child: TextField(
                        keyboardType: TextInputType.visiblePassword,
                        obscureText: true,
                        enableSuggestions: false,
                        autocorrect: false,
                        onChanged: (value) {
                          setState(() {
                            newAccountPassword = value;
                          });
                        },
                        controller: _passwordTextFieldController,
                        decoration: const InputDecoration(
                            label: Text('WebDav Password'),
                            hintText: 'super-SECRET-passphrase'),
                      ),
                    ),
                  ),
                ),
                const Spacer(flex: 4),
              ],
            ),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          if (newAccountUrl.isEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('WebDav URL is required!'),
                duration: Duration(seconds: 5),
                backgroundColor: Colors.red,
              ),
            );
            return;
          }

          if (newAccountUsername.isEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Email is required!'),
                duration: Duration(seconds: 5),
                backgroundColor: Colors.red,
              ),
            );
            return;
          }

          if (newAccountPassword.isEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('WebDav Password is required!'),
                duration: Duration(seconds: 5),
                backgroundColor: Colors.red,
              ),
            );
            return;
          }

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Testing account details...')),
          );

          final doesConnectionWork = await testApiConnection(
              newAccountUrl, newAccountUsername, newAccountPassword);

          if (!context.mounted) {
            return;
          }

          ScaffoldMessenger.of(context).hideCurrentSnackBar();

          if (!doesConnectionWork) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content:
                    Text('Could not connect! Please check the details again.'),
                duration: Duration(seconds: 5),
                backgroundColor: Colors.red,
              ),
            );

            return;
          }

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Adding account...')),
          );

          await _saveNewCloudAccount();

          if (!context.mounted) {
            return;
          }

          ScaffoldMessenger.of(context).hideCurrentSnackBar();

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Account added!'),
              duration: Duration(seconds: 5),
              backgroundColor: Colors.green,
            ),
          );

          setState(() {
            newAccountUrl = "";
            newAccountUsername = "";
            newAccountPassword = "";
          });

          Navigator.pop(context);
        },
        tooltip: 'Save',
        foregroundColor: Theme.of(context).primaryColor,
        backgroundColor: Colors.lightBlue,
        shape: const CircleBorder(),
        child: const Icon(Icons.check),
      ),
    );
  }
}
