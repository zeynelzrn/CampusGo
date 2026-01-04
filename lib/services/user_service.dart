import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// Service for user-related operations like blocking and reporting
class UserService {
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  UserService({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  /// Get current user ID
  String? get currentUserId => _auth.currentUser?.uid;

  /// Collection references
  CollectionReference<Map<String, dynamic>> get _usersCollection =>
      _firestore.collection('users');

  CollectionReference<Map<String, dynamic>> get _reportsCollection =>
      _firestore.collection('reports');

  CollectionReference<Map<String, dynamic>> get _chatsCollection =>
      _firestore.collection('chats');

  // ==================== BLOCK OPERATIONS ====================

  /// Block a user
  /// Adds the target user to the current user's blocked_users subcollection
  /// Also archives any existing chat with the blocked user
  Future<bool> blockUser(String targetUserId) async {
    final currentUid = currentUserId;

    debugPrint('========== BLOCK USER START ==========');
    debugPrint('Current User ID: $currentUid');
    debugPrint('Target User ID: $targetUserId');

    if (currentUid == null) {
      debugPrint('ERROR: User not logged in - currentUserId is null');
      debugPrint('Auth state: ${_auth.currentUser}');
      return false;
    }

    if (currentUid == targetUserId) {
      debugPrint('ERROR: Cannot block yourself');
      return false;
    }

    try {
      // Method 1: Direct writes (more reliable than batch for debugging)
      debugPrint('Writing to: users/$currentUid/blocked_users/$targetUserId');

      // 1. Add to blocked_users subcollection - DIRECT WRITE
      await _firestore
          .collection('users')
          .doc(currentUid)
          .collection('blocked_users')
          .doc(targetUserId)
          .set({
        'blockedAt': FieldValue.serverTimestamp(),
        'userId': targetUserId,
        'blockedBy': currentUid,
      });
      debugPrint('SUCCESS: Written to blocked_users');

      // 2. Add reverse block - DIRECT WRITE
      debugPrint('Writing to: users/$targetUserId/blocked_by/$currentUid');
      await _firestore
          .collection('users')
          .doc(targetUserId)
          .collection('blocked_by')
          .doc(currentUid)
          .set({
        'blockedAt': FieldValue.serverTimestamp(),
        'userId': currentUid,
        'blockedBy': currentUid,
      });
      debugPrint('SUCCESS: Written to blocked_by');

      // 3. Archive existing chat (if any)
      final chatId = _generateChatId(currentUid, targetUserId);
      debugPrint('Checking chat: $chatId');

      final chatDoc = await _chatsCollection.doc(chatId).get();
      if (chatDoc.exists) {
        debugPrint('Chat exists, archiving...');
        await _chatsCollection.doc(chatId).update({
          'isArchived': true,
          'archivedBy': FieldValue.arrayUnion([currentUid]),
          'archivedAt': FieldValue.serverTimestamp(),
          'blockedBy': currentUid,
        });
        debugPrint('SUCCESS: Chat archived');
      } else {
        debugPrint('No existing chat found');
      }

      // 4. Verify the write
      final verifyDoc = await _firestore
          .collection('users')
          .doc(currentUid)
          .collection('blocked_users')
          .doc(targetUserId)
          .get();

      if (verifyDoc.exists) {
        debugPrint('VERIFIED: Block record exists in Firestore');
        debugPrint('Data: ${verifyDoc.data()}');
      } else {
        debugPrint('WARNING: Block record NOT found after write!');
      }

      debugPrint('========== BLOCK USER SUCCESS ==========');
      return true;
    } catch (e, stackTrace) {
      debugPrint('========== BLOCK USER ERROR ==========');
      debugPrint('Error Type: ${e.runtimeType}');
      debugPrint('Error Message: $e');
      debugPrint('Stack Trace: $stackTrace');

      // Check for specific error types
      final errorStr = e.toString();
      if (errorStr.contains('PERMISSION_DENIED') || errorStr.contains('permission')) {
        debugPrint('>>> PERMISSION DENIED! Check Firestore Security Rules <<<');
        debugPrint('Required rule: allow write on users/{userId}/blocked_users/{blockedId}');
      }
      if (errorStr.contains('NOT_FOUND')) {
        debugPrint('>>> DOCUMENT NOT FOUND! User document may not exist <<<');
      }
      debugPrint('=======================================');
      return false;
    }
  }

  /// Unblock a user
  Future<bool> unblockUser(String targetUserId) async {
    final currentUid = currentUserId;
    if (currentUid == null) return false;

    try {
      final batch = _firestore.batch();

      // Remove from blocked_users
      final blockedRef = _usersCollection
          .doc(currentUid)
          .collection('blocked_users')
          .doc(targetUserId);
      batch.delete(blockedRef);

      // Remove reverse block
      final reverseBlockRef = _usersCollection
          .doc(targetUserId)
          .collection('blocked_by')
          .doc(currentUid);
      batch.delete(reverseBlockRef);

      await batch.commit();
      debugPrint('UserService: Successfully unblocked user $targetUserId');
      return true;
    } catch (e) {
      debugPrint('UserService: Error unblocking user: $e');
      return false;
    }
  }

  /// Check if a user is blocked
  Future<bool> isUserBlocked(String targetUserId) async {
    final currentUid = currentUserId;
    if (currentUid == null) return false;

    try {
      final doc = await _usersCollection
          .doc(currentUid)
          .collection('blocked_users')
          .doc(targetUserId)
          .get();

      return doc.exists;
    } catch (e) {
      debugPrint('UserService: Error checking block status: $e');
      return false;
    }
  }

  /// Get list of blocked user IDs
  Future<List<String>> getBlockedUserIds() async {
    final currentUid = currentUserId;
    if (currentUid == null) return [];

    try {
      final snapshot = await _usersCollection
          .doc(currentUid)
          .collection('blocked_users')
          .get();

      return snapshot.docs.map((doc) => doc.id).toList();
    } catch (e) {
      debugPrint('UserService: Error getting blocked users: $e');
      return [];
    }
  }

  /// Stream blocked user IDs for real-time updates
  Stream<List<String>> watchBlockedUserIds() {
    final currentUid = currentUserId;
    if (currentUid == null) return Stream.value([]);

    return _usersCollection
        .doc(currentUid)
        .collection('blocked_users')
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => doc.id).toList());
  }

  // ==================== MUTUAL INVISIBILITY (BLACKLIST) ====================

  /// Get list of user IDs who blocked the current user (blocked_by)
  Future<List<String>> getBlockedByUserIds() async {
    final currentUid = currentUserId;
    if (currentUid == null) return [];

    try {
      final snapshot = await _usersCollection
          .doc(currentUid)
          .collection('blocked_by')
          .get();

      final ids = snapshot.docs.map((doc) => doc.id).toList();
      debugPrint('UserService: Found ${ids.length} users who blocked me');
      return ids;
    } catch (e) {
      debugPrint('UserService: Error getting blocked_by users: $e');
      return [];
    }
  }

  /// Stream user IDs who blocked the current user (blocked_by) for real-time updates
  Stream<List<String>> watchBlockedByUserIds() {
    final currentUid = currentUserId;
    if (currentUid == null) return Stream.value([]);

    return _usersCollection
        .doc(currentUid)
        .collection('blocked_by')
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => doc.id).toList());
  }

  /// Get ALL restricted user IDs (BLACKLIST)
  /// Combines: blocked_users (I blocked them) + blocked_by (they blocked me)
  /// Any user in this list should be INVISIBLE to current user
  Future<Set<String>> getAllRestrictedUserIds() async {
    final currentUid = currentUserId;
    if (currentUid == null) return {};

    try {
      debugPrint('========== FETCHING BLACKLIST ==========');

      // Fetch both lists in parallel
      final results = await Future.wait([
        getBlockedUserIds(),    // Users I blocked
        getBlockedByUserIds(),  // Users who blocked me
      ]);

      final blockedUsers = results[0];
      final blockedByUsers = results[1];

      // Combine into single set
      final allRestricted = <String>{
        ...blockedUsers,
        ...blockedByUsers,
      };

      debugPrint('Blocked by me: ${blockedUsers.length} users');
      debugPrint('Blocked me: ${blockedByUsers.length} users');
      debugPrint('Total BLACKLIST: ${allRestricted.length} users');
      debugPrint('IDs: $allRestricted');
      debugPrint('==========================================');

      return allRestricted;
    } catch (e) {
      debugPrint('UserService: Error getting restricted users: $e');
      return {};
    }
  }

  /// Stream ALL restricted user IDs for real-time updates
  /// Used for live filtering in UI (Combines blocked_users + blocked_by)
  Stream<Set<String>> watchAllRestrictedUserIds() {
    final currentUid = currentUserId;
    if (currentUid == null) return Stream.value({});

    // Watch blocked_users and combine with blocked_by on each update
    return watchBlockedUserIds().asyncMap((blockedUsers) async {
      // Get blocked_by users when blocked_users changes
      final blockedByUsers = await getBlockedByUserIds();
      return <String>{...blockedUsers, ...blockedByUsers};
    });
  }

  /// Check if a specific user has blocked the current user
  Future<bool> isBlockedByUser(String targetUserId) async {
    final currentUid = currentUserId;
    if (currentUid == null) return false;

    try {
      final doc = await _usersCollection
          .doc(currentUid)
          .collection('blocked_by')
          .doc(targetUserId)
          .get();

      final isBlocked = doc.exists;
      debugPrint('UserService: Am I blocked by $targetUserId? $isBlocked');
      return isBlocked;
    } catch (e) {
      debugPrint('UserService: Error checking blocked_by status: $e');
      return false;
    }
  }

  /// Check if there is ANY block relationship between current user and target
  /// Returns true if EITHER user blocked the other
  Future<bool> hasBlockRelationship(String targetUserId) async {
    final currentUid = currentUserId;
    if (currentUid == null) return false;

    try {
      final results = await Future.wait([
        isUserBlocked(targetUserId),   // Did I block them?
        isBlockedByUser(targetUserId), // Did they block me?
      ]);

      final iBlocked = results[0];
      final theyBlockedMe = results[1];

      debugPrint('Block relationship with $targetUserId: I blocked=$iBlocked, They blocked me=$theyBlockedMe');
      return iBlocked || theyBlockedMe;
    } catch (e) {
      debugPrint('UserService: Error checking block relationship: $e');
      return false;
    }
  }

  // ==================== REPORT OPERATIONS ====================

  /// Report reasons for App Store compliance
  static const List<ReportReason> reportReasons = [
    ReportReason(
      id: 'harassment',
      label: 'Rahatsiz edici mesajlar / Taciz',
      icon: 'warning',
    ),
    ReportReason(
      id: 'fake_profile',
      label: 'Sahte Profil / Spam',
      icon: 'person_off',
    ),
    ReportReason(
      id: 'inappropriate_content',
      label: 'Uygunsuz Icerik / Fotograf',
      icon: 'image_not_supported',
    ),
    ReportReason(
      id: 'underage',
      label: 'Reşit olmayan kullanici',
      icon: 'child_care',
    ),
    ReportReason(
      id: 'scam',
      label: 'Dolandiricilik',
      icon: 'money_off',
    ),
    ReportReason(
      id: 'other',
      label: 'Diger',
      icon: 'more_horiz',
    ),
  ];

  /// Report a user
  /// Creates a report document in the reports collection
  Future<bool> reportUser({
    required String targetUserId,
    required String reason,
    String? description,
    String? chatId,
  }) async {
    final currentUid = currentUserId;
    if (currentUid == null) {
      debugPrint('UserService: User not logged in');
      return false;
    }

    if (currentUid == targetUserId) {
      debugPrint('UserService: Cannot report yourself');
      return false;
    }

    try {
      // Create report document
      await _reportsCollection.add({
        'reporterId': currentUid,
        'reportedId': targetUserId,
        'reason': reason,
        'description': description ?? '',
        'chatId': chatId,
        'timestamp': FieldValue.serverTimestamp(),
        'status': 'pending', // pending, reviewed, resolved, dismissed
        'reviewedAt': null,
        'reviewedBy': null,
        'action': null, // warning, suspension, ban, none
      });

      debugPrint('UserService: Successfully reported user $targetUserId');
      return true;
    } catch (e) {
      debugPrint('UserService: Error reporting user: $e');
      return false;
    }
  }

  /// Check if user has already reported this target
  Future<bool> hasAlreadyReported(String targetUserId) async {
    final currentUid = currentUserId;
    if (currentUid == null) return false;

    try {
      final snapshot = await _reportsCollection
          .where('reporterId', isEqualTo: currentUid)
          .where('reportedId', isEqualTo: targetUserId)
          .limit(1)
          .get();

      return snapshot.docs.isNotEmpty;
    } catch (e) {
      debugPrint('UserService: Error checking report status: $e');
      return false;
    }
  }

  // ==================== HELPER METHODS ====================

  /// Generate consistent chat ID from two user IDs
  String _generateChatId(String uid1, String uid2) {
    final sortedIds = [uid1, uid2]..sort();
    return '${sortedIds[0]}_${sortedIds[1]}';
  }
}

/// Report reason model
class ReportReason {
  final String id;
  final String label;
  final String icon;

  const ReportReason({
    required this.id,
    required this.label,
    required this.icon,
  });
}
