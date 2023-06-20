import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'dart:math';
import 'package:device_info_plus/device_info_plus.dart';

Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
}

AndroidNotificationChannel? channel;

FlutterLocalNotificationsPlugin? flutterLocalNotificationsPlugin;
late FirebaseMessaging messaging;

final GlobalKey<NavigatorState> navigatorKey = new GlobalKey<NavigatorState>();

void notificationTapBackground(NotificationResponse notificationResponse) {
  print('notification(${notificationResponse.id}) action tapped: '
      '${notificationResponse.actionId} with'
      ' payload: ${notificationResponse.payload}');
  if (notificationResponse.input?.isNotEmpty ?? false) {
    print(
        'notification action tapped with input: ${notificationResponse.input}');
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  messaging = FirebaseMessaging.instance;

  await messaging.requestPermission(
    alert: true,
    announcement: false,
    badge: true,
    carPlay: false,
    criticalAlert: false,
    provisional: false,
    sound: true,
  );

  // If subscribe based sent notification then use this token
  final fcmToken = await messaging.getToken();
  print(fcmToken);

  // If subscribe based on topic then use this
  await messaging.subscribeToTopic('hschat_notification99');

  // Set the background messaging handler early on, as a named top-level function
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  if (!kIsWeb) {
    channel = const AndroidNotificationChannel(
      'hschat_notification', // id
      'hschat_notification_title', // title
      importance: Importance.max,
      enableLights: true,
      enableVibration: true,
      showBadge: true,
      playSound: true,
    );

    flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

    final android =
        AndroidInitializationSettings('@drawable/ic_notifications_icon');
    final iOS = DarwinInitializationSettings();
    final initSettings = InitializationSettings(android: android, iOS: iOS);

    await flutterLocalNotificationsPlugin!.initialize(initSettings,
        onDidReceiveNotificationResponse: notificationTapBackground,
        onDidReceiveBackgroundNotificationResponse: notificationTapBackground);

    await messaging.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );
  }

  runApp(
    const MaterialApp(
      home: WebViewApp(),
    ),
  );
}

class WebViewApp extends StatefulWidget {
  const WebViewApp({Key? key}) : super(key: key);

  @override
  State<WebViewApp> createState() => _WebViewAppState();
}

class _WebViewAppState extends State<WebViewApp> {
  late final WebViewController controller;

  late SharedPreferences _prefs;
  late String _uniqueId;

  @override
  void initState() {
    // final baseUrl = 'https://hschat.pro/app/index.php';
    // final uid = generateRandomUid();
    // final url = '$baseUrl?uid=$uid';
    //_initUniqueId();
    final random = Random();
    final uid = random.nextInt(999999999999).toString().padLeft(12, '0');
    final baseUrl = 'https://hschat.pro/app/index.php';
    final encodedUid = Uri.encodeComponent(uid);
    final url = '$baseUrl?uid=$encodedUid';
    controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..loadRequest(
          Uri.parse('https://hschat.pro/app/index.php?uid=09090909090'));
    //..loadRequest(Uri.parse(url));
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: WebViewWidget(controller: controller),
    );
  }

  void _initUniqueId() async {
    _prefs = await SharedPreferences.getInstance();
    _uniqueId = _prefs.getString('uniqueId') ?? generateRandomUid();
    if (_uniqueId.isEmpty) {
      _uniqueId = generateRandomUid();
      await _prefs.setString('uniqueId', _uniqueId);
    }
  }

  String generateRandomUid() {
    final random = Random();
    final uid = random.nextInt(999999999999).toString().padLeft(12, '0');
    return uid;
  }
}
