import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../models/user_profile.dart';
import '../services/chat_service.dart';
import '../services/user_service.dart';

/// Repository for swipe-related Firestore operations
class SwipeRepository {
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  // Batch size for pagination
  static const int batchSize = 10;
  // Fetch more than needed to account for filtering
  static const int fetchBatchSize = 20;

  SwipeRepository({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  /// Get current user ID
  String? get currentUserId => _auth.currentUser?.uid;

  /// Collection references
  CollectionReference<Map<String, dynamic>> get _usersCollection =>
      _firestore.collection('users');

  CollectionReference<Map<String, dynamic>> get _actionsCollection =>
      _firestore.collection('actions');

  CollectionReference<Map<String, dynamic>> get _matchesCollection =>
      _firestore.collection('matches');

  /// Fetch ALL exclusion IDs for the current user (for client-side filtering)
  /// This includes:
  /// 1. Users already swiped (actions)
  /// 2. BLACKLIST: blocked_users (I blocked them) + blocked_by (they blocked me)
  /// This is called once on init and stored in memory
  Future<Set<String>> fetchAllActionIds() async {
    final userId = currentUserId;
    if (userId == null) return {};

    try {
      debugPrint('========== FETCHING EXCLUSION LIST ==========');

      // Fetch actions and blacklist in parallel
      final userService = UserService();
      final results = await Future.wait([
        _actionsCollection.where('fromUserId', isEqualTo: userId).get(),
        userService.getAllRestrictedUserIds(), // BLACKLIST
      ]);

      final actionsSnapshot = results[0] as QuerySnapshot<Map<String, dynamic>>;
      final restrictedIds = results[1] as Set<String>;

      debugPrint('SwipeRepository: Found ${actionsSnapshot.docs.length} actions for user $userId');
      debugPrint('SwipeRepository: Found ${restrictedIds.length} restricted (blocked) users');

      // Extract target user IDs from actions
      final actionIds = <String>{};
      for (final doc in actionsSnapshot.docs) {
        final data = doc.data();
        final toUserId = data['toUserId'] as String?;
        final actionType = data['type'] as String?;
        if (toUserId != null) {
          actionIds.add(toUserId);
          debugPrint('  - Excluding $toUserId (action: $actionType)');
        }
      }

      // Also add current user's own ID to exclusion set
      actionIds.add(userId);

      // COMBINE: actions + blacklist
      final allExcludedIds = <String>{
        ...actionIds,
        ...restrictedIds,
      };

      // Log restricted users
      for (final id in restrictedIds) {
        debugPrint('  - Excluding $id (BLOCKED/BLACKLIST)');
      }

      debugPrint('Total swiped: ${actionIds.length - 1}'); // -1 for self
      debugPrint('Total blocked: ${restrictedIds.length}');
      debugPrint('SwipeRepository: Total excluded IDs: ${allExcludedIds.length}');
      debugPrint('==============================================');

      return allExcludedIds;
    } catch (e) {
      debugPrint('Error fetching action IDs: $e');
      return {userId}; // At minimum, exclude self
    }
  }

  /// Refresh exclusion list (call after blocking someone)
  Future<Set<String>> refreshExclusionList() async {
    debugPrint('SwipeRepository: Refreshing exclusion list after block action');
    return await fetchAllActionIds();
  }

  /// Fetch a batch of users with pagination
  /// Returns raw users - filtering should be done by the provider
  /// If gender filter returns no results, falls back to showing all users
  Future<List<UserProfile>> fetchUserBatch({
    DocumentSnapshot? lastDocument,
    String? genderFilter,
  }) async {
    final userId = currentUserId;
    if (userId == null) return [];

    try {
      // First, try with gender filter
      List<UserProfile> results = await _fetchUsersWithFilter(
        lastDocument: lastDocument,
        genderFilter: genderFilter,
      );

      debugPrint('SwipeRepository: Fetched ${results.length} users with filter: $genderFilter');

      // FALLBACK: If no results with filter and we have a filter, try without it
      if (results.isEmpty && genderFilter != null && genderFilter != 'Herkes' && genderFilter.isNotEmpty) {
        debugPrint('SwipeRepository: No users with gender filter "$genderFilter", trying without filter...');
        results = await _fetchUsersWithFilter(
          lastDocument: lastDocument,
          genderFilter: null, // No filter - show everyone
        );
        debugPrint('SwipeRepository: Fetched ${results.length} users without filter (fallback)');
      }

      return results;
    } catch (e) {
      debugPrint('Error fetching user batch: $e');
      return [];
    }
  }

  /// Internal helper to fetch users with optional filter
  Future<List<UserProfile>> _fetchUsersWithFilter({
    DocumentSnapshot? lastDocument,
    String? genderFilter,
  }) async {
    Query<Map<String, dynamic>> query = _usersCollection
        .orderBy('createdAt', descending: true)
        .limit(fetchBatchSize);

    // Apply gender filter if specified
    if (genderFilter != null &&
        genderFilter.isNotEmpty &&
        genderFilter != 'Herkes') {
      query = query.where('gender', isEqualTo: genderFilter);
    }

    // Apply pagination cursor
    if (lastDocument != null) {
      query = query.startAfterDocument(lastDocument);
    }

    final snapshot = await query.get();

    return snapshot.docs
        .map((doc) => UserProfile.fromFirestore(doc))
        .where((profile) => profile.isComplete) // Only show complete profiles
        .toList();
  }

  /// Record a swipe action
  /// Returns a map with:
  /// - 'success': bool - whether the action was recorded
  /// - 'isMatch': bool - whether this created a mutual match
  Future<Map<String, dynamic>> recordSwipeAction({
    required String targetUserId,
    required SwipeActionType actionType,
  }) async {
    final userId = currentUserId;
    if (userId == null) {
      return {'success': false, 'isMatch': false};
    }

    try {
      final actionId = SwipeAction.generateId(userId, targetUserId);

      await _actionsCollection.doc(actionId).set({
        'fromUserId': userId,
        'toUserId': targetUserId,
        'type': actionType.name,
        'timestamp': FieldValue.serverTimestamp(),
      });

      // If it's a like or superlike, check for MUTUAL match
      bool isMatch = false;
      if (actionType == SwipeActionType.like ||
          actionType == SwipeActionType.superlike) {
        isMatch = await _checkAndCreateMatch(targetUserId);
      }

      return {'success': true, 'isMatch': isMatch};
    } catch (e) {
      debugPrint('Error recording swipe action: $e');
      return {'success': false, 'isMatch': false};
    }
  }

  /// Check if target user ALREADY liked current user (MUTUAL LIKE check)
  /// Only creates match if BOTH users have liked each other
  Future<bool> _checkAndCreateMatch(String targetUserId) async {
    final userId = currentUserId;
    if (userId == null) return false;

    try {
      // Check if target user ALREADY liked current user BEFORE
      final reverseActionId = SwipeAction.generateId(targetUserId, userId);
      final reverseAction = await _actionsCollection.doc(reverseActionId).get();

      // MUTUAL LIKE: Target user must have liked us FIRST
      if (reverseAction.exists) {
        final data = reverseAction.data();
        final type = data?['type'] as String?;

        // Only create match if it's a mutual like/superlike
        if (type == SwipeActionType.like.name ||
            type == SwipeActionType.superlike.name) {
          debugPrint('MUTUAL MATCH! $userId <-> $targetUserId');
          await _createMatchAndChat(userId, targetUserId);
          return true; // IT'S A MATCH!
        }
      }

      // No mutual like - target hasn't liked us yet
      // The like is recorded but no match created
      debugPrint('Like recorded, waiting for mutual: $userId -> $targetUserId');
      return false;
    } catch (e) {
      debugPrint('Error checking for match: $e');
      return false;
    }
  }

  /// Create a match document AND initialize chat room
  /// Called ONLY when there's a MUTUAL like
  Future<void> _createMatchAndChat(String userId1, String userId2) async {
    // Sort IDs to create consistent match ID
    final sortedIds = [userId1, userId2]..sort();
    final matchId = '${sortedIds[0]}_${sortedIds[1]}';

    try {
      // Check if match already exists
      final existingMatch = await _matchesCollection.doc(matchId).get();
      if (existingMatch.exists) {
        debugPrint('Match already exists: $matchId');
        return;
      }

      debugPrint('Creating new match: $matchId');

      // Create match document
      await _matchesCollection.doc(matchId).set({
        'users': sortedIds,
        'timestamp': FieldValue.serverTimestamp(),
      });

      // Add to each user's matches subcollection
      final batch = _firestore.batch();

      batch.set(
        _usersCollection.doc(userId1).collection('matches').doc(userId2),
        {'timestamp': FieldValue.serverTimestamp(), 'matchId': matchId},
      );

      batch.set(
        _usersCollection.doc(userId2).collection('matches').doc(userId1),
        {'timestamp': FieldValue.serverTimestamp(), 'matchId': matchId},
      );

      await batch.commit();

      // === CRITICAL: Create chat room for the match ===
      debugPrint('Creating chat room for match: $matchId');
      final chatService = ChatService();
      final chatId = await chatService.createMatchChat(userId1, userId2);
      debugPrint('Chat room created: $chatId');
    } catch (e) {
      debugPrint('Error creating match and chat: $e');
    }
  }

  /// Get current user's profile
  Future<UserProfile?> getCurrentUserProfile() async {
    final userId = currentUserId;
    if (userId == null) return null;

    try {
      final doc = await _usersCollection.doc(userId).get();
      if (!doc.exists) return null;

      return UserProfile.fromFirestore(doc);
    } catch (e) {
      debugPrint('Error fetching current user profile: $e');
      return null;
    }
  }

  /// Get user's looking for preference
  Future<String?> getUserLookingForPreference() async {
    final profile = await getCurrentUserProfile();
    return profile?.lookingFor;
  }

  /// Stream user's matches
  Stream<List<Match>> watchMatches() {
    final userId = currentUserId;
    if (userId == null) return Stream.value([]);

    return _matchesCollection
        .where('users', arrayContains: userId)
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => Match.fromFirestore(doc)).toList());
  }

  /// Get a specific user profile by ID
  Future<UserProfile?> getUserProfile(String userId) async {
    try {
      final doc = await _usersCollection.doc(userId).get();
      if (!doc.exists) return null;

      return UserProfile.fromFirestore(doc);
    } catch (e) {
      debugPrint('Error fetching user profile: $e');
      return null;
    }
  }

  /// Undo last swipe action
  Future<bool> undoLastSwipe(String targetUserId) async {
    final userId = currentUserId;
    if (userId == null) return false;

    try {
      final actionId = SwipeAction.generateId(userId, targetUserId);
      await _actionsCollection.doc(actionId).delete();
      return true;
    } catch (e) {
      debugPrint('Error undoing swipe: $e');
      return false;
    }
  }
}
