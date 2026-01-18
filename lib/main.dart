import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:overlay_support/overlay_support.dart';
import 'firebase_options.dart';
import 'widgets/app_notification.dart';
import 'widgets/connectivity_banner.dart';
import 'screens/splash_screen.dart';
import 'screens/main_screen.dart';
import 'services/notification_service.dart';
import 'services/message_cache_service.dart';

// Global navigator key for navigation from notifications
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

// Background message handler (must be top-level function)
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  // Background handler - system notification will be shown automatically
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // CRITICAL: Set up background handler BEFORE Firebase initialization
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  // Initialize Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Initialize Hive (Message Cache)
  await MessageCacheService.initialize();

  // Initialize notification service
  final notificationService = NotificationService();
  await notificationService.initialize();
  await notificationService.requestPermission();

  runApp(
    const ProviderScope(
      child: MyApp(),
    ),
  );
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();
    _setupFCMListeners();
  }

  void _setupFCMListeners() {
    // Handle foreground messages - show overlay notification
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      _handleForegroundMessage(message);
    });

    // Handle when user taps notification while app is in background
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      _handleNotificationTap(message);
    });

    // Handle when app is opened from terminated state via notification
    FirebaseMessaging.instance.getInitialMessage().then((message) {
      if (message != null) {
        Future.delayed(const Duration(seconds: 1), () {
          _handleNotificationTap(message);
        });
      }
    });
  }

  void _handleForegroundMessage(RemoteMessage message) {
    final data = message.data;
    final notification = message.notification;
    final type = data['type'] as String?;

    String title = notification?.title ?? data['title'] as String? ?? '';
    String body = notification?.body ?? data['body'] as String? ?? '';

    // Haptic feedback
    HapticFeedback.mediumImpact();

    // Show overlay notification based on type
    if (type == 'like') {
      _showLikeNotification(title, body, data);
    } else if (type == 'message' || type == 'chat') {
      _showMessageNotification(title, body, data);
    } else if (type == 'match') {
      _showMatchNotification(title, body, data);
    } else {
      _showGenericNotification(title, body);
    }
  }

  /// Pink notification for likes
  void _showLikeNotification(String title, String body, Map<String, dynamic> data) {
    AppNotification.like(
      title: title.isNotEmpty ? title : 'Biri seninle tanışmak istiyor!',
      subtitle: body.isNotEmpty ? body : null,
      duration: const Duration(seconds: 4),
      onTap: () => _navigateToScreen(data),
    );
  }

  /// Purple notification for messages
  void _showMessageNotification(String title, String body, Map<String, dynamic> data) {
    AppNotification.message(
      title: title.isNotEmpty ? title : 'Yeni mesajın var!',
      subtitle: body.isNotEmpty ? body : null,
      duration: const Duration(seconds: 4),
      onTap: () => _navigateToScreen(data),
    );
  }

  /// Pink notification for matches
  void _showMatchNotification(String title, String body, Map<String, dynamic> data) {
    AppNotification.custom(
      title: title.isNotEmpty ? title : 'Yeni Bağlantı!',
      subtitle: body.isNotEmpty ? body : 'Yeni bir arkadaşlık kuruldu!',
      icon: Icons.celebration_rounded,
      gradientColors: [const Color(0xFF5C6BC0), const Color(0xFFFF7043)],
      shadowColor: const Color(0xFF5C6BC0),
      duration: const Duration(seconds: 4),
      onTap: () => _navigateToScreen(data),
    );
  }

  /// Generic notification
  void _showGenericNotification(String title, String body) {
    AppNotification.info(
      title: title.isNotEmpty ? title : 'CampusGo',
      subtitle: body.isNotEmpty ? body : null,
      duration: const Duration(seconds: 4),
    );
  }

  void _handleNotificationTap(RemoteMessage message) {
    final data = message.data;
    _navigateToScreen(data);
  }

  void _navigateToScreen(Map<String, dynamic> data) {
    final type = data['type'] as String?;
    final navigator = navigatorKey.currentState;

    if (navigator == null) return;

    switch (type) {
      case 'message':
      case 'chat':
        navigator.pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (_) => const MainScreen(initialIndex: 3),
          ),
          (route) => false,
        );
        break;
      case 'like':
        navigator.pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (_) => const MainScreen(initialIndex: 1),
          ),
          (route) => false,
        );
        break;
      case 'match':
        navigator.pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (_) => const MainScreen(initialIndex: 3),
          ),
          (route) => false,
        );
        break;
      default:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    // CRITICAL: OverlaySupport.global wraps MaterialApp for overlay notifications
    return OverlaySupport.global(
      child: MaterialApp(
        navigatorKey: navigatorKey,
        title: 'Campus Go',
        debugShowCheckedModeBanner: false,
        debugShowMaterialGrid: false,
        // ConnectivityWrapper inside builder to have access to MaterialApp's Directionality
        builder: (context, child) {
          return ConnectivityWrapper(
            child: child ?? const SizedBox.shrink(),
          );
        },
        home: const SplashScreen(),
      ),
    );
  }
}
