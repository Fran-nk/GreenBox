import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/foundation.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  Future<void>? _initFuture;

  /// Safe to call many times; every caller awaits the same initialization.
  Future<void> init() => _initFuture ??= _init();

  Future<void> _init() async {
    // Initialization for Android
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    // Initialization for iOS
    const DarwinInitializationSettings initializationSettingsIOS =
        DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );

    await flutterLocalNotificationsPlugin.initialize(
      settings: initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        debugPrint('Notification clicked: ${response.payload}');
      },
    );
  }

  Future<void> showHumidityAlert({
    required String plantName,
    required String deviceName,
  }) async {
    await init();

    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      'greenbox_alerts_channel',
      'Alertas de Cultivo',
      channelDescription: 'Notificaciones sobre el estado de tu cultivo GreenBox',
      importance: Importance.max,
      priority: Priority.high,
      showWhen: true,
    );

    const DarwinNotificationDetails iOSPlatformChannelSpecifics =
        DarwinNotificationDetails();

    const NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
      iOS: iOSPlatformChannelSpecifics,
    );

    await flutterLocalNotificationsPlugin.show(
      id: 0, // ID fijo para no saturar con múltiples notificaciones de lo mismo
      title: '¡Atención! Humedad fuera de rango',
      body: 'Cuidado con tu cultivo de $plantName | $deviceName',
      notificationDetails: platformChannelSpecifics,
      payload: 'humidity_alert',
    );
  }
}
