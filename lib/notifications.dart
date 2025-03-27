import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  static final NotificationService _notificationService =
      NotificationService._internal();

  factory NotificationService() {
    return _notificationService;
  }

  NotificationService._internal();

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  static const String _channelId = 'bewcloud_sync_channel';
  static const String _channelName = 'Photo Sync';
  static const String _channelDescription =
      'Notifications for photo synchronization status';
  static const int _notificationId = 0;

  Future<void> init() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/launcher_icon');

    const DarwinInitializationSettings initializationSettingsIOS =
        DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    const InitializationSettings initializationSettings =
        InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
      macOS: null,
      linux: null,
    );

    await flutterLocalNotificationsPlugin.initialize(initializationSettings);

    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      _channelId,
      _channelName,
      description: _channelDescription,
      importance: Importance.low,
    );

    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
  }

  NotificationDetails _getNotificationDetails({bool ongoing = false}) {
    return NotificationDetails(
      android: AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: _channelDescription,
        importance: Importance.low,
        priority: Priority.low,
        ongoing: ongoing,
        autoCancel: !ongoing,
        onlyAlertOnce: true,
      ),
      iOS: const DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: false,
        presentSound: false,
      ),
    );
  }

  Future<void> showSyncProgressNotification(
      {String message = 'Syncing photos...'}) async {
    await flutterLocalNotificationsPlugin.show(
      _notificationId,
      'bewCloud Photo Sync',
      message,
      _getNotificationDetails(ongoing: true),
    );
  }

  Future<void> showSyncCompleteNotification(
      {String message = 'Photo sync complete.'}) async {
    await flutterLocalNotificationsPlugin.show(
      _notificationId,
      'bewCloud Photo Sync',
      message,
      _getNotificationDetails(ongoing: false),
    );
  }

  Future<void> showSyncErrorNotification(
      {String message = 'Photo sync failed. Check app for details.'}) async {
    await flutterLocalNotificationsPlugin.show(
      _notificationId,
      'bewCloud Photo Sync',
      message,
      _getNotificationDetails(ongoing: false),
    );
  }

  Future<void> requestPermissions() async {
    final plugin =
        flutterLocalNotificationsPlugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    if (plugin != null) {
      await plugin.requestNotificationsPermission();
    }
    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        );
  }
}
