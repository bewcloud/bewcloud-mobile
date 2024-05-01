# bewCloud Mobile

[![](https://github.com/bewcloud/bewcloud-mobile/workflows/Run%20Tests/badge.svg)](https://github.com/bewcloud/bewcloud-mobile/actions?workflow=Run+Tests)

This is the Mobile client for [bewCloud](https://github.com/bewcloud/bewcloud). It is built with [`Flutter`](https://flutter.dev) and relies on the [WebDav](https://github.com/bewcloud/bewcloud/blob/main/routes/dav.tsx) and [REST](https://github.com/bewcloud/bewcloud/tree/main/routes/api/files) APIs.

Usernames, passwords, and URLs are stored on the device, with passwords [being encrypted](/lib/encryption.dart).

If you're looking for the desktop sync app, it's at [`bewcloud-desktop`](https://github.com/bewcloud/bewcloud-desktop).

## Install

Download the appropriate binary [from the releases page](https://github.com/bewcloud/bewcloud-mobile/releases) for your mobile device and run it.

Alternatively, you can [build from source](#build-from-source)!

> [!CAUTION]
> I _know_ the key used to encrypt the config passwords in the automatic release builds, and anyone who cares to reverse-engineer the app binaries can too, so you should [build your own client](#build-from-source) instead, with your own key.

## Development

You need to have [Flutter](https://docs.flutter.dev/get-started/install) installed and setup, with `flutter doctor` passing.

Don't forget to set up your `.env` file based on `.env.sample`.

```sh
make start # runs the app
make format # formats the code
make test # runs tests
```

## Build from source

Don't forget to check the [development](#development) section above first!

> [!NOTE]
> If you're releasing a new version, update it in `pubspec.yaml` first.

```sh
make build/android # builds the APK for Android
make build/ios # builds the IPA for iOS
make install # installs the app directly on a connected device
```

### Generate icons

If the icons change, just run the following to re-generate them:

```sh
dart pub get
dart run flutter_launcher_icons
```
