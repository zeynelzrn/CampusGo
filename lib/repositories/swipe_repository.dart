import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/user_profile.dart';

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

  /// Fetch ALL action IDs for the current user (for client-side filtering)
  /// This is called once on init and stored in memory
  Future<Set<String>> fetchAllActionIds() async {
    final userId = currentUserId;
    if (userId == null) return {};

    try {
      // Get all actions where current user is the initiator
      final snapshot =
          await _actionsCollection.where('fromUserId', isEqualTo: userId).get();

      // Extract target user IDs
      final actionIds = <String>{};
      for (final doc in snapshot.docs) {
        final data = doc.data();
        final toUserId = data['toUserId'] as String?;
        if (toUserId != null) {
          actionIds.add(toUserId);
        }
      }

      // Also add current user's own ID to exclusion set
      actionIds.add(userId);

      return actionIds;
    } catch (e) {
      print('Error fetching action IDs: $e');
      return {userId}; // At minimum, exclude self
    }
  }

  /// Fetch a batch of users with pagination
  /// Returns raw users - filtering should be done by the provider
  Future<List<UserProfile>> fetchUserBatch({
    DocumentSnapshot? lastDocument,
    String? genderFilter,
  }) async {
    final userId = currentUserId;
    if (userId == null) return [];

    try {
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
    } catch (e) {
      print('Error fetching user batch: $e');
      return [];
    }
  }

  /// Record a swipe action
  Future<bool> recordSwipeAction({
    required String targetUserId,
    required SwipeActionType actionType,
  }) async {
    final userId = currentUserId;
    if (userId == null) return false;

    try {
      final actionId = SwipeAction.generateId(userId, targetUserId);

      await _actionsCollection.doc(actionId).set({
        'fromUserId': userId,
        'toUserId': targetUserId,
        'type': actionType.name,
        'timestamp': FieldValue.serverTimestamp(),
      });

      // If it's a like, check for match
      if (actionType == SwipeActionType.like ||
          actionType == SwipeActionType.superlike) {
        await _checkAndCreateMatch(targetUserId);
      }

      return true;
    } catch (e) {
      print('Error recording swipe action: $e');
      return false;
    }
  }

  /// Check if target user also liked current user and create match
  Future<bool> _checkAndCreateMatch(String targetUserId) async {
    final userId = currentUserId;
    if (userId == null) return false;

    try {
      // Check if target user liked current user
      final reverseActionId = SwipeAction.generateId(targetUserId, userId);
      final reverseAction = await _actionsCollection.doc(reverseActionId).get();

      if (reverseAction.exists) {
        final data = reverseAction.data();
        final type = data?['type'] as String?;

        // If mutual like, create match
        if (type == SwipeActionType.like.name ||
            type == SwipeActionType.superlike.name) {
          await _createMatch(userId, targetUserId);
          return true;
        }
      }

      return false;
    } catch (e) {
      print('Error checking for match: $e');
      return false;
    }
  }

  /// Create a match document
  Future<void> _createMatch(String userId1, String userId2) async {
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
    } catch (e) {
      print('Error creating match: $e');
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
      print('Error fetching current user profile: $e');
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
      print('Error fetching user profile: $e');
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
      print('Error undoing swipe: $e');
      return false;
    }
  }
}
