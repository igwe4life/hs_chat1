import 'dart:convert';
import 'dart:io';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:connectivity/connectivity.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:hs_chat/webview_screen.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'dart:math';
import 'package:path_provider/path_provider.dart';

Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  // final payloadUrl = message.data['url'];
  // if (payloadUrl != null) {
  //   navigatorKey.currentState?.push(
  //     MaterialPageRoute(
  //       builder: (context) => WebViewScreen(url: payloadUrl),
  //     ),
  //   );
  // }
  // Handle the received message and show a notification
  showNotification(message);
}

// Function to show a notification
void showNotification(RemoteMessage message) {
  // Extract the payload URL from the message
  final payloadUrl = message.data['url'];

  // Create a notification using the payload URL
  final notification = Notification(
    title: message.notification?.title,
    body: message.notification?.body,
    payloadUrl: payloadUrl,
  );

  // Show the notification
  displayNotification(notification);
}

// Function to display the notification and handle navigation
void displayNotification(Notification notification) {
  // Create a GlobalKey to access the navigatorKey
  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  // Create a callback for the notification onTap event
  void onNotificationTap() {
    // Check if a payload URL is available
    if (notification.payloadUrl != null) {
      // Navigate to the WebView screen using the payload URL
      navigatorKey.currentState?.push(
        MaterialPageRoute(
          builder: (context) => WebViewScreen(url: notification.payloadUrl!),
        ),
      );
    }
  }

  // Create a notification dialog
  showDialog(
    context: navigatorKey.currentContext!,
    builder: (context) => AlertDialog(
      title: Text(notification.title ?? ''),
      content: Text(notification.body ?? ''),
      actions: [
        // Add an "Open" button to handle navigation
        TextButton(
          onPressed: onNotificationTap,
          child: Text('Open'),
        ),
      ],
    ),
  );
}

// Define the Notification class to hold the notification details
class Notification {
  final String? title;
  final String? body;
  final String? payloadUrl;

  Notification({this.title, this.body, required this.payloadUrl});
}

AndroidNotificationChannel? channel;

FlutterLocalNotificationsPlugin? flutterLocalNotificationsPlugin;
late FirebaseMessaging messaging;

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void notificationTapBackground(NotificationResponse notificationResponse) {
  print('notification(${notificationResponse.id}) action tapped: '
      '${notificationResponse.actionId} with'
      ' payload: ${notificationResponse.payload}');
  if (notificationResponse.input?.isNotEmpty ?? false) {
    print(
        'notification action tapped with input: ${notificationResponse.input}');
  }

  // Navigate to the desired screen when the notification is tapped
  navigatorKey.currentState?.pushNamed('/desired-screen');
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
  await messaging.subscribeToTopic('hschat_notification999');
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
    MaterialApp(
      navigatorKey: navigatorKey, // Set the navigatorKey
      onGenerateRoute: (settings) {
        if (settings.name == '/desired-screen') {
          // Define the route for the desired screen
          return MaterialPageRoute(
            builder: (context) => const WebViewApp(),
          );
        }
        // You can define other routes here if needed
        return null;
      },
      home: const WebViewApp(),
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
  bool isInternetConnected = true;
  late String _uniqueId;

  @override
  void initState() {
    super.initState();
    checkInternetConnectivity();
    _initUniqueId().then((value) {
      setState(() {
        _uniqueId = value;
      });
    });

    // Add listener for incoming messages when the app is in the foreground
    /* FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      // Handle the received message and navigate to the desired screen
      //navigatorKey.currentState?.pushNamed('/desired-screen');
      final payloadUrl = message.data['url'];
      if (payloadUrl != null) {
        navigatorKey.currentState?.push(
          MaterialPageRoute(
            builder: (context) => WebViewScreen(url: payloadUrl),
          ),
        );
      }
    }); */

    setupInteractedMessage();

    FirebaseMessaging.instance
        .getInitialMessage()
        .then((RemoteMessage? message) async {
      RemoteNotification? notification = message?.notification!;

      print(notification != null ? notification.title : '');
    });

    /* FirebaseMessaging.onMessage.listen((message) async {
      RemoteNotification? notification = message.notification;
      AndroidNotification? android = message.notification?.android;

      if (notification != null && android != null && !kIsWeb) {
        String action = jsonEncode(message.data);

        flutterLocalNotificationsPlugin!.show(
            notification.hashCode,
            notification.title,
            notification.body,
            NotificationDetails(
              android: AndroidNotificationDetails(
                channel!.id,
                channel!.name,
                priority: Priority.high,
                importance: Importance.max,
                setAsGroupSummary: true,
                styleInformation: DefaultStyleInformation(true, true),
                largeIcon: DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
                channelShowBadge: true,
                autoCancel: true,
                icon: '@drawable/ic_notifications_icon',
              ),
            ),
            payload: action);
      }
      print('A new event was published!');
    }); */

    Future<String> _base64encodedImage(String url) async {
      final http.Response response = await http.get(Uri.parse(url));
      final String base64Data = base64Encode(response.bodyBytes);
      return base64Data;
    }

    Future<void> _showBigPictureNotificationBase64(
        Map<String, dynamic> payload) async {
      final String largeIcon =
          await _base64encodedImage('https://hschat.pro/app/images/logo.png');
      final String bigPicture =
          await _base64encodedImage(payload['bigPictureUrl']);

      final BigPictureStyleInformation bigPictureStyleInformation =
          BigPictureStyleInformation(
        ByteArrayAndroidBitmap.fromBase64String(bigPicture),
        largeIcon: ByteArrayAndroidBitmap.fromBase64String(largeIcon),
        contentTitle: payload['title'],
        htmlFormatContentTitle: true,
        summaryText: payload['body'],
        htmlFormatSummaryText: true,
      );

      final AndroidNotificationDetails androidNotificationDetails =
          AndroidNotificationDetails(
        'big_picture_channel',
        'Big Picture Channel',
        channelDescription: 'Channel for displaying big picture notifications',
        styleInformation: bigPictureStyleInformation,
      );

      FirebaseMessaging.onMessage.listen((message) async {
        RemoteNotification? notification = message.notification;
        AndroidNotification? android = message.notification?.android;

        if (notification != null && android != null && !kIsWeb) {
          String action = jsonEncode(message.data);
          _showBigPictureNotificationBase64(action as Map<String, dynamic>);
        }
        print('A new event was published!');
      });

      final NotificationDetails notificationDetails =
          NotificationDetails(android: androidNotificationDetails);

      await flutterLocalNotificationsPlugin!.show(
        0,
        payload['title'],
        payload['body'],
        notificationDetails,
      );
    }

    FirebaseMessaging.onMessageOpenedApp
        .listen((message) => _handleMessage(message.data));
  }

  Future<dynamic> onSelectNotification(payload) async {
    Map<String, dynamic> action = jsonDecode(payload);
    _handleMessage(action);
  }

  Future<void> setupInteractedMessage() async {
    await FirebaseMessaging.instance
        .getInitialMessage()
        .then((value) => _handleMessage(value != null ? value.data : Map()));
  }

  void _handleMessage(Map<String, dynamic> data) {
    final payloadUrl = data['url'];
    if (payloadUrl != null) {
      navigatorKey.currentState?.push(
        MaterialPageRoute(
          builder: (context) => WebViewScreen(url: payloadUrl),
        ),
      );
    }
    // if (data['redirect'] == "product") {
    //   Navigator.push(
    //       context,
    //       MaterialPageRoute(
    //           builder: (context) => ProductPage(message: data['message'])));
    // }
  }

  @override
  Widget build(BuildContext context) {
    if (isInternetConnected) {
      final uuid = _uniqueId ?? Uuid().v4();
      final url = 'https://hschat.pro/app/index.php?uid=$uuid';
      controller = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..loadRequest(Uri.parse(url));
      return Scaffold(
        body: WebViewWidget(controller: controller),
      );
    } else {
      return const Scaffold(
        body: Center(
          child: Text(
            'No Internet Connection.\nPlease check your internet connection.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16),
          ),
        ),
      );
    }
  }

  Future<String> _initUniqueId() async {
    final directory = await getApplicationDocumentsDirectory();
    final file = File('${directory.path}/uniqueId.txt');
    if (await file.exists()) {
      return file.readAsString();
    } else {
      final uuid = const Uuid().v4();
      await file.writeAsString(uuid);
      return uuid;
    }
  }

  Future<void> checkInternetConnectivity() async {
    final connectivityResult = await Connectivity().checkConnectivity();
    if (connectivityResult == ConnectivityResult.none) {
      showNoInternetToast();
    }
  }

  Future<void> showNoInternetToast() async {
    setState(() {
      isInternetConnected = false;
    });
    Fluttertoast.showToast(
      msg: 'No Internet Connection',
      toastLength: Toast.LENGTH_SHORT,
      gravity: ToastGravity.BOTTOM,
      timeInSecForIosWeb: 1,
      backgroundColor: Colors.red,
      textColor: Colors.white,
    ).then((value) {
      // Navigate to the desired screen when the toast message is tapped
      navigatorKey.currentState?.pushNamed('/desired-screen');
    });
  }

  String generateRandomUid() {
    final random = Random();
    final uid = random.nextInt(999999999999).toString().padLeft(12, '0');
    return uid;
  }
}

class DesiredScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Desired Screen'),
      ),
      body: const Center(
        child: Text(
          'This is the desired screen.',
          style: TextStyle(fontSize: 24),
        ),
      ),
    );
  }
}
