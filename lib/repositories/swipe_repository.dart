import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
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
      // Fetch actions and blacklist in parallel
      final userService = UserService();
      final results = await Future.wait([
        _actionsCollection.where('fromUserId', isEqualTo: userId).get(),
        userService.getAllRestrictedUserIds(), // BLACKLIST
      ]);

      final actionsSnapshot = results[0] as QuerySnapshot<Map<String, dynamic>>;
      final restrictedIds = results[1] as Set<String>;

      // Extract target user IDs from actions
      final actionIds = <String>{};
      for (final doc in actionsSnapshot.docs) {
        final data = doc.data();
        final toUserId = data['toUserId'] as String?;
        if (toUserId != null) {
          actionIds.add(toUserId);
        }
      }

      // Also add current user's own ID to exclusion set
      actionIds.add(userId);

      // COMBINE: actions + blacklist
      return <String>{
        ...actionIds,
        ...restrictedIds,
      };
    } catch (e) {
      return {userId}; // At minimum, exclude self
    }
  }

  /// Refresh exclusion list (call after blocking someone)
  Future<Set<String>> refreshExclusionList() async {
    return await fetchAllActionIds();
  }

  /// Fetch a batch of users with pagination
  /// Returns profiles and lastDocument for pagination
  /// If gender filter returns no results, falls back to showing all users
  Future<({List<UserProfile> profiles, DocumentSnapshot? lastDoc})> fetchUserBatch({
    DocumentSnapshot? lastDocument,
    String? genderFilter,
  }) async {
    final userId = currentUserId;
    if (userId == null) return (profiles: <UserProfile>[], lastDoc: null);

    try {
      // First, try with gender filter
      var result = await _fetchUsersWithFilter(
        lastDocument: lastDocument,
        genderFilter: genderFilter,
      );

      // FALLBACK: If no results with filter and we have a filter, try without it
      if (result.profiles.isEmpty && genderFilter != null && genderFilter != 'Herkes' && genderFilter.isNotEmpty) {
        result = await _fetchUsersWithFilter(
          lastDocument: lastDocument,
          genderFilter: null, // No filter - show everyone
        );
      }

      return result;
    } catch (e) {
      return (profiles: <UserProfile>[], lastDoc: null);
    }
  }

  /// Internal helper to fetch users with optional filter
  /// Returns a record with profiles and the last document for pagination
  Future<({List<UserProfile> profiles, DocumentSnapshot? lastDoc})> _fetchUsersWithFilter({
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

    // Get last document for pagination
    final lastDoc = snapshot.docs.isNotEmpty ? snapshot.docs.last : null;

    final profiles = snapshot.docs
        .map((doc) => UserProfile.fromFirestore(doc))
        .where((profile) => profile.isComplete) // Only show complete profiles
        .toList();

    return (profiles: profiles, lastDoc: lastDoc);
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
          await _createMatchAndChat(userId, targetUserId);
          return true; // IT'S A MATCH!
        }
      }

      return false;
    } catch (e) {
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
      if (existingMatch.exists) return;

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

      // Create chat room for the match
      final chatService = ChatService();
      await chatService.createMatchChat(userId1, userId2);
    } catch (e) {
      // Silent fail - match creation is not critical
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
      return false;
    }
  }
}
