import 'dart:async';
import 'dart:io';
import 'dart:ui';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:overlay_support/overlay_support.dart';
import '../main.dart';

/// Service for handling FCM token management and local notifications
class NotificationService {
  // Singleton pattern
  static final NotificationService _instance = NotificationService._internal();
  static NotificationService get instance => _instance;
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Firestore notification stream subscription
  StreamSubscription<QuerySnapshot>? _notificationSubscription;

  // Notification channel for Android
  static const AndroidNotificationChannel _channel = AndroidNotificationChannel(
    'high_importance_channel',
    'CampusGo Bildirimleri',
    description: 'Mesaj ve begeni bildirimleri',
    importance: Importance.high,
    playSound: true,
    enableVibration: true,
  );

  /// Initialize notification service
  Future<void> initialize() async {
    // Initialize local notifications
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    const settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications.initialize(
      settings,
      onDidReceiveNotificationResponse: _onNotificationTap,
    );

    // Create Android notification channel
    if (Platform.isAndroid) {
      await _localNotifications
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(_channel);
    }

    // iOS: Disable automatic foreground notification display
    // We handle foreground notifications with in-app banners instead
    await _messaging.setForegroundNotificationPresentationOptions(
      alert: false, // Don't show alert banner
      badge: true,  // Update badge count
      sound: false, // Don't play sound (we'll handle this in-app)
    );
  }

  /// Request notification permissions
  Future<bool> requestPermission() async {
    final settings = await _messaging.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
      sound: true,
    );

    return settings.authorizationStatus == AuthorizationStatus.authorized ||
        settings.authorizationStatus == AuthorizationStatus.provisional;
  }

  /// Get FCM token
  Future<String?> getFCMToken() async {
    try {
      final token = await _messaging.getToken();
      return token;
    } catch (e) {
      print('Error getting FCM token: $e');
      return null;
    }
  }

  /// Save FCM token to Firestore
  Future<void> saveTokenToFirestore(String userId) async {
    try {
      final token = await getFCMToken();
      if (token != null) {
        await _firestore.collection('users').doc(userId).update({
          'fcmToken': token,
          'fcmTokenUpdatedAt': FieldValue.serverTimestamp(),
        });
        print('FCM token saved for user: $userId');
      }
    } catch (e) {
      print('Error saving FCM token: $e');
    }
  }

  /// Delete FCM token from Firestore (on logout)
  Future<void> deleteTokenFromFirestore(String userId) async {
    try {
      await _firestore.collection('users').doc(userId).update({
        'fcmToken': FieldValue.delete(),
        'fcmTokenUpdatedAt': FieldValue.delete(),
      });
      print('FCM token deleted for user: $userId');
    } catch (e) {
      print('Error deleting FCM token: $e');
    }
  }

  /// Listen for token refresh and update Firestore
  void listenToTokenRefresh(String userId) {
    _messaging.onTokenRefresh.listen((newToken) async {
      await _firestore.collection('users').doc(userId).update({
        'fcmToken': newToken,
        'fcmTokenUpdatedAt': FieldValue.serverTimestamp(),
      });
      print('FCM token refreshed for user: $userId');
    });
  }

  /// Get and save FCM token for current user (auto-login support)
  /// Called when app starts to ensure token is always up-to-date
  Future<void> getAndSaveToken() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await saveTokenToFirestore(user.uid);
        listenToTokenRefresh(user.uid);
      }
    } catch (e) {
      print('Error in getAndSaveToken: $e');
    }
  }

  /// Show local notification (for foreground messages)
  Future<void> showLocalNotification({
    required String title,
    required String body,
    String? payload,
  }) async {
    final androidDetails = AndroidNotificationDetails(
      'high_importance_channel',
      'CampusGo Bildirimleri',
      channelDescription: 'Mesaj ve begeni bildirimleri',
      importance: Importance.high,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
      icon: '@mipmap/ic_launcher',
      color: const Color(0xFFFF2C60),
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    final details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _localNotifications.show(
      DateTime.now().millisecondsSinceEpoch.remainder(100000),
      title,
      body,
      details,
      payload: payload,
    );
  }

  /// Handle notification tap
  void _onNotificationTap(NotificationResponse response) {
    // This will be handled by the global navigator
    // The payload contains navigation data (e.g., chatId, type)
    print('Notification tapped with payload: ${response.payload}');
  }

  /// Get user's FCM token from Firestore
  Future<String?> getUserFCMToken(String userId) async {
    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      return doc.data()?['fcmToken'] as String?;
    } catch (e) {
      print('Error getting user FCM token: $e');
      return null;
    }
  }

  /// Listen to Firestore notifications for in-app display
  /// This is the iOS fallback when FCM token is not available
  void listenToInAppNotifications() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      print('No user logged in, cannot listen to notifications');
      return;
    }

    // Cancel existing subscription if any
    _notificationSubscription?.cancel();

    print('Starting Firestore notification listener for user: ${user.uid}');

    _notificationSubscription = _firestore
        .collection('users')
        .doc(user.uid)
        .collection('notifications')
        .where('isRead', isEqualTo: false)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .listen((snapshot) {
      for (final change in snapshot.docChanges) {
        // Only process newly added documents
        if (change.type == DocumentChangeType.added) {
          final doc = change.doc;
          final data = doc.data();
          if (data != null) {
            _showInAppNotification(doc.id, data);
          }
        }
      }
    }, onError: (error) {
      print('Error listening to notifications: $error');
    });
  }

  /// Show in-app notification and mark as read
  void _showInAppNotification(String docId, Map<String, dynamic> data) {
    final title = data['title'] as String? ?? '';
    final body = data['body'] as String? ?? '';
    final type = data['type'] as String? ?? '';

    print('Showing in-app notification: $type - $title');

    // Haptic feedback
    HapticFeedback.mediumImpact();

    // Show appropriate notification based on type
    switch (type) {
      case 'like':
        _showLikeOverlay(title, body, data);
        break;
      case 'message':
        _showMessageOverlay(title, body, data);
        break;
      case 'match':
        _showMatchOverlay(title, body, data);
        break;
      default:
        _showGenericOverlay(title, body);
    }

    // Mark notification as read
    _markNotificationAsRead(docId);
  }

  /// Mark Firestore notification as read
  Future<void> _markNotificationAsRead(String docId) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('notifications')
          .doc(docId)
          .update({'isRead': true});

      print('Notification marked as read: $docId');
    } catch (e) {
      print('Error marking notification as read: $e');
    }
  }

  /// Pink overlay for likes
  void _showLikeOverlay(String title, String body, Map<String, dynamic> data) {
    showOverlayNotification(
      (context) {
        return GestureDetector(
          onTap: () {
            OverlaySupportEntry.of(context)?.dismiss();
            _navigateToScreen(data);
          },
          child: SafeArea(
            child: Material(
              color: Colors.transparent,
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFF2C60), Color(0xFFFF6B9D)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFFF2C60).withValues(alpha: 0.4),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.favorite_rounded,
                          color: Colors.white,
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              title.isNotEmpty ? title : 'Biri seni begendi!',
                              style: GoogleFonts.poppins(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            if (body.isNotEmpty)
                              Text(
                                body,
                                style: GoogleFonts.poppins(
                                  color: Colors.white.withValues(alpha: 0.9),
                                  fontSize: 13,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                          ],
                        ),
                      ),
                      Icon(
                        Icons.chevron_right_rounded,
                        color: Colors.white.withValues(alpha: 0.7),
                        size: 24,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
      duration: const Duration(seconds: 4),
      position: NotificationPosition.top,
    );
  }

  /// Purple overlay for messages
  void _showMessageOverlay(String title, String body, Map<String, dynamic> data) {
    showOverlayNotification(
      (context) {
        return GestureDetector(
          onTap: () {
            OverlaySupportEntry.of(context)?.dismiss();
            _navigateToScreen(data);
          },
          child: SafeArea(
            child: Material(
              color: Colors.transparent,
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF7C4DFF), Color(0xFFB388FF)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF7C4DFF).withValues(alpha: 0.4),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.chat_bubble_rounded,
                          color: Colors.white,
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              title.isNotEmpty ? title : 'Yeni mesajin var!',
                              style: GoogleFonts.poppins(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            if (body.isNotEmpty)
                              Text(
                                body,
                                style: GoogleFonts.poppins(
                                  color: Colors.white.withValues(alpha: 0.9),
                                  fontSize: 13,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                          ],
                        ),
                      ),
                      Icon(
                        Icons.chevron_right_rounded,
                        color: Colors.white.withValues(alpha: 0.7),
                        size: 24,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
      duration: const Duration(seconds: 4),
      position: NotificationPosition.top,
    );
  }

  /// Pink-orange overlay for matches
  void _showMatchOverlay(String title, String body, Map<String, dynamic> data) {
    showOverlayNotification(
      (context) {
        return GestureDetector(
          onTap: () {
            OverlaySupportEntry.of(context)?.dismiss();
            _navigateToScreen(data);
          },
          child: SafeArea(
            child: Material(
              color: Colors.transparent,
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFF2C60), Color(0xFFFF8A65)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFFF2C60).withValues(alpha: 0.4),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.celebration_rounded,
                          color: Colors.white,
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              title.isNotEmpty ? title : 'Yeni Eslesme!',
                              style: GoogleFonts.poppins(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              body.isNotEmpty ? body : 'Biriyle eslestiniz!',
                              style: GoogleFonts.poppins(
                                color: Colors.white.withValues(alpha: 0.9),
                                fontSize: 13,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        Icons.chevron_right_rounded,
                        color: Colors.white.withValues(alpha: 0.7),
                        size: 24,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
      duration: const Duration(seconds: 4),
      position: NotificationPosition.top,
    );
  }

  /// Generic overlay notification
  void _showGenericOverlay(String title, String body) {
    showSimpleNotification(
      Text(
        title.isNotEmpty ? title : 'CampusGo',
        style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
      ),
      subtitle: body.isNotEmpty
          ? Text(body, style: GoogleFonts.poppins(fontSize: 13))
          : null,
      background: const Color(0xFFFF2C60),
      foreground: Colors.white,
      duration: const Duration(seconds: 4),
      slideDismissDirection: DismissDirection.up,
    );
  }

  /// Navigate to appropriate screen based on notification type
  void _navigateToScreen(Map<String, dynamic> data) {
    final type = data['type'] as String?;
    final navigator = navigatorKey.currentState;

    if (navigator == null) return;

    int? targetIndex;
    switch (type) {
      case 'message':
        targetIndex = 3; // Chat tab
        break;
      case 'like':
        targetIndex = 1; // Likes tab
        break;
      case 'match':
        targetIndex = 3; // Chat tab
        break;
      default:
        break;
    }

    if (targetIndex != null) {
      // Use the global callback to navigate
      _onNavigateToTab?.call(targetIndex);
    }
  }

  // Callback for navigation (set by MainScreen)
  static void Function(int)? _onNavigateToTab;

  /// Set the navigation callback (called by MainScreen)
  static void setNavigationCallback(void Function(int) callback) {
    _onNavigateToTab = callback;
  }

  /// Stop listening to Firestore notifications
  void stopListeningToNotifications() {
    _notificationSubscription?.cancel();
    _notificationSubscription = null;
    print('Stopped listening to Firestore notifications');
  }
}
