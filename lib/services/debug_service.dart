import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// Debug service for development and testing operations
/// WARNING: These operations are destructive and cannot be undone!
class DebugService {
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  DebugService({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  /// Get current user ID
  String? get currentUserId => _auth.currentUser?.uid;

  /// Collection references
  CollectionReference<Map<String, dynamic>> get _usersCollection =>
      _firestore.collection('users');

  CollectionReference<Map<String, dynamic>> get _matchesCollection =>
      _firestore.collection('matches');

  CollectionReference<Map<String, dynamic>> get _chatsCollection =>
      _firestore.collection('chats');

  CollectionReference<Map<String, dynamic>> get _actionsCollection =>
      _firestore.collection('actions');

  // ==================== RESET MATCHES & CHATS ====================

  /// Reset all matches and chats (keeps users, removes relationships)
  /// Returns a result map with success status and statistics
  Future<Map<String, dynamic>> resetAllMatchesAndChats() async {
    final userId = currentUserId;
    if (userId == null) {
      return {
        'success': false,
        'error': 'Kullanici girisi yapilmamis',
      };
    }

    int deletedMatches = 0;
    int deletedChats = 0;
    int deletedMessages = 0;
    int deletedActions = 0;
    int clearedUserData = 0;

    try {
      debugPrint('DebugService: Starting reset all matches and chats...');

      // 1. Delete all matches
      debugPrint('DebugService: Deleting matches collection...');
      final matchesSnapshot = await _matchesCollection.get();
      for (final doc in matchesSnapshot.docs) {
        await doc.reference.delete();
        deletedMatches++;
      }
      debugPrint('DebugService: Deleted $deletedMatches matches');

      // 2. Delete all chats (with messages subcollection - recursive delete)
      debugPrint('DebugService: Deleting chats collection (with messages)...');
      final chatsSnapshot = await _chatsCollection.get();
      for (final chatDoc in chatsSnapshot.docs) {
        // First, delete all messages in the subcollection
        final messagesSnapshot =
            await chatDoc.reference.collection('messages').get();
        for (final messageDoc in messagesSnapshot.docs) {
          await messageDoc.reference.delete();
          deletedMessages++;
        }
        // Then delete the chat document itself
        await chatDoc.reference.delete();
        deletedChats++;
      }
      debugPrint(
          'DebugService: Deleted $deletedChats chats with $deletedMessages messages');

      // 3. Delete all actions (likes, dislikes, superlikes)
      debugPrint('DebugService: Deleting actions collection...');
      final actionsSnapshot = await _actionsCollection.get();
      for (final doc in actionsSnapshot.docs) {
        await doc.reference.delete();
        deletedActions++;
      }
      debugPrint('DebugService: Deleted $deletedActions actions');

      // 4. Clear ALL user relationship subcollections
      debugPrint('DebugService: Clearing user relationship subcollections...');
      final usersSnapshot = await _usersCollection.get();

      // All subcollections that might store relationship data
      final subcollectionsToClean = [
        'matches',
        'sent_likes',
        'received_likes',
        'dislikes',
        'seen_users',
        'blocked',
        'likes',
      ];

      for (final userDoc in usersSnapshot.docs) {
        for (final subcollection in subcollectionsToClean) {
          try {
            final snapshot = await userDoc.reference.collection(subcollection).get();
            for (final doc in snapshot.docs) {
              await doc.reference.delete();
              clearedUserData++;
            }
          } catch (e) {
            // Silent - subcollection might not exist
          }
        }
      }
      debugPrint('DebugService: Cleared $clearedUserData user relationship records');

      // 5. Add placeholder documents to keep collections visible in Firebase Console
      debugPrint('DebugService: Adding placeholder documents...');
      await _addPlaceholderDocuments();
      debugPrint('DebugService: Placeholder documents added');

      debugPrint('DebugService: Reset completed successfully!');

      return {
        'success': true,
        'deletedMatches': deletedMatches,
        'deletedChats': deletedChats,
        'deletedMessages': deletedMessages,
        'deletedActions': deletedActions,
        'clearedUserData': clearedUserData,
      };
    } catch (e) {
      debugPrint('DebugService: Error during reset: $e');
      return {
        'success': false,
        'error': e.toString(),
        'deletedMatches': deletedMatches,
        'deletedChats': deletedChats,
        'deletedMessages': deletedMessages,
        'deletedActions': deletedActions,
        'clearedUserData': clearedUserData,
      };
    }
  }

  /// Add placeholder documents to keep collections visible in Firebase Console
  Future<void> _addPlaceholderDocuments() async {
    final timestamp = FieldValue.serverTimestamp();
    final placeholderData = {
      '_placeholder': true,
      '_description': 'Bu dokuman koleksiyonun gorunur kalmasini saglar. Silebilirsiniz.',
      '_createdAt': timestamp,
    };

    try {
      // Add placeholder to matches collection
      await _matchesCollection.doc('_init').set(placeholderData);
      debugPrint('  ✅ matches/_init eklendi');

      // Add placeholder to chats collection
      await _chatsCollection.doc('_init').set(placeholderData);
      debugPrint('  ✅ chats/_init eklendi');

      // Add placeholder to actions collection
      await _actionsCollection.doc('_init').set(placeholderData);
      debugPrint('  ✅ actions/_init eklendi');
    } catch (e) {
      debugPrint('  ⚠️ Placeholder ekleme hatasi: $e');
    }
  }

  // ==================== DELETE DEMO USERS (SIMPLE UID WHITELIST) ====================

  /// PROTECTED UIDs: Only these 2 accounts will NEVER be deleted
  /// Everything else gets deleted - no email checks, no domain checks
  static const List<String> _protectedUids = [
    'KJcDoC0XTZZRAKP6QNu6ahOugCA3', // zeynel gmail.    
    'GEE22M3nqpNR890Fz4igFIzFQoj1', // zeyneltcr gmail
    'KhpezrxgStV67YYYo6fHWGkwlxm1', // (Okul Maili)
  ];

  /// Delete all users EXCEPT the 2 protected UIDs
  /// Simple and clean - no complex email/domain logic
  Future<Map<String, dynamic>> deleteAllDemoUsers() async {
    int deletedUsers = 0;
    int protectedUsers = 0;
    List<String> deletedList = [];
    List<String> protectedList = [];

    try {
      debugPrint('');
      debugPrint('╔═══════════════════════════════════════════════════════╗');
      debugPrint('║         SIMPLE UID WHITELIST - 2 HESAP KORUMALI       ║');
      debugPrint('╠═══════════════════════════════════════════════════════╣');
      debugPrint('║  Korunan UID\'ler:');
      for (final uid in _protectedUids) {
        debugPrint('║    🔐 $uid');
      }
      debugPrint('╚═══════════════════════════════════════════════════════╝');
      debugPrint('');

      // Fetch ALL users from Firestore
      final usersSnapshot = await _usersCollection.get();
      final totalUsers = usersSnapshot.docs.length;
      debugPrint('Firestore: $totalUsers kullanici bulundu');
      debugPrint('');

      for (final userDoc in usersSnapshot.docs) {
        final docId = userDoc.id;
        final data = userDoc.data();
        final email = data['email'] as String? ?? 'NO_EMAIL';
        final name = data['name'] as String? ?? 'NO_NAME';

        // TEK KONTROL: UID listede mi?
        if (_protectedUids.contains(docId)) {
          debugPrint('🔐 KORUNDU: $email ($name) [UID: $docId]');
          protectedUsers++;
          protectedList.add('$email ($name)');
        } else {
          debugPrint('🗑️  SİLİNDİ: $email ($name) [UID: $docId]');
          await _deleteUserSubcollections(userDoc.reference);
          await userDoc.reference.delete();
          deletedUsers++;
          deletedList.add('$email ($name)');
        }
      }

      debugPrint('');
      debugPrint('╔═══════════════════════════════════════════════════════╗');
      debugPrint('║                   İŞLEM TAMAMLANDI                    ║');
      debugPrint('╠═══════════════════════════════════════════════════════╣');
      debugPrint('║  🗑️  SİLİNEN: $deletedUsers');
      debugPrint('║  ✅ KORUNAN: $protectedUsers');
      debugPrint('╚═══════════════════════════════════════════════════════╝');

      return {
        'success': true,
        'deletedUsers': deletedUsers,
        'protectedUsers': protectedUsers,
        'deletedEmails': deletedList,
        'protectedEmails': protectedList,
      };
    } catch (e) {
      debugPrint('❌ Hata: $e');
      return {
        'success': false,
        'error': e.toString(),
        'deletedUsers': deletedUsers,
        'protectedUsers': protectedUsers,
      };
    }
  }

  /// Delete all subcollections for a user
  Future<void> _deleteUserSubcollections(DocumentReference userRef) async {
    // List of ALL known subcollections (including seen_users for complete reset)
    final subcollections = [
      'matches',
      'sent_likes',
      'received_likes',
      'dislikes',
      'seen_users',  // In case this is used
      'blocked',     // In case blocking feature exists
      'likes',       // Alternative naming
    ];

    for (final subcollection in subcollections) {
      try {
        final snapshot = await userRef.collection(subcollection).get();
        for (final doc in snapshot.docs) {
          await doc.reference.delete();
        }
      } catch (e) {
        // Silent fail - subcollection might not exist
        debugPrint('DebugService: Subcollection $subcollection: ${e.toString().contains('NOT_FOUND') ? 'not found (OK)' : e}');
      }
    }
  }

  // ==================== STATISTICS ====================

  /// Get current database statistics
  /// Uses simple UID whitelist logic
  Future<Map<String, int>> getDatabaseStats() async {
    try {
      final usersSnapshot = await _usersCollection.get();
      final matchesCount = (await _matchesCollection.get()).docs.length;
      final chatsCount = (await _chatsCollection.get()).docs.length;
      final actionsCount = (await _actionsCollection.get()).docs.length;

      int protectedUsersCount = 0;
      int deletableUsersCount = 0;

      for (final doc in usersSnapshot.docs) {
        if (_protectedUids.contains(doc.id)) {
          protectedUsersCount++;
        } else {
          deletableUsersCount++;
        }
      }

      return {
        'users': usersSnapshot.docs.length,
        'protectedUsers': protectedUsersCount,
        'deletableUsers': deletableUsersCount,
        'matches': matchesCount,
        'chats': chatsCount,
        'actions': actionsCount,
      };
    } catch (e) {
      debugPrint('DebugService: Error getting stats: $e');
      return {
        'users': 0,
        'protectedUsers': 0,
        'deletableUsers': 0,
        'matches': 0,
        'chats': 0,
        'actions': 0,
      };
    }
  }
}
