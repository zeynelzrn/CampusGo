import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../models/user_profile.dart';

/// Repository for handling likes data with real-time Stream support
class LikesRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// In-memory cache for user profiles (prevents re-fetching)
  static final Map<String, UserProfile> _profileCache = {};

  /// Cache validity duration
  static const Duration _cacheValidityDuration = Duration(minutes: 5);
  static final Map<String, DateTime> _cacheTimestamps = {};

  String? get currentUserId => _auth.currentUser?.uid;

  /// Batch fetch profiles using Firestore whereIn (max 30 IDs per query)
  /// This optimizes N+1 queries: 100 users = 4 reads instead of 100 reads
  Future<List<UserProfile>> _batchFetchProfiles(List<String> userIds) async {
    if (userIds.isEmpty) return [];

    final now = DateTime.now();
    final idsToFetch = <String>[];
    final cachedProfiles = <String, UserProfile>{};

    // Check cache first - only use if not expired
    for (final id in userIds) {
      final cacheTime = _cacheTimestamps[id];
      final isCacheValid = cacheTime != null &&
          now.difference(cacheTime) < _cacheValidityDuration;

      if (isCacheValid && _profileCache.containsKey(id)) {
        cachedProfiles[id] = _profileCache[id]!;
      } else {
        idsToFetch.add(id);
      }
    }

    // Fetch uncached profiles in chunks of 30 (Firestore whereIn limit)
    if (idsToFetch.isNotEmpty) {
      const chunkSize = 30;

      for (var i = 0; i < idsToFetch.length; i += chunkSize) {
        final end = (i + chunkSize > idsToFetch.length)
            ? idsToFetch.length
            : i + chunkSize;
        final chunk = idsToFetch.sublist(i, end);

        try {
          final snapshot = await _firestore
              .collection('users')
              .where(FieldPath.documentId, whereIn: chunk)
              .get();

          for (final doc in snapshot.docs) {
            // snapshot.docs already contains existing documents
            final data = doc.data();
            if (data.isNotEmpty) {
              final profile = UserProfile.fromFirestore(doc);
              _profileCache[profile.id] = profile;
              _cacheTimestamps[profile.id] = now;
              cachedProfiles[profile.id] = profile;
            }
          }
        } catch (e) {
          debugPrint('Error batch fetching profiles chunk: $e');
        }
      }
    }

    // Preserve original order (important for sorted likes list)
    final orderedResult = <UserProfile>[];
    for (final id in userIds) {
      if (cachedProfiles.containsKey(id)) {
        orderedResult.add(cachedProfiles[id]!);
      }
    }

    return orderedResult;
  }

  /// Clear profile cache (call when user logs out or data changes)
  static void clearCache() {
    _profileCache.clear();
    _cacheTimestamps.clear();
  }

  /// Remove a specific user from cache (call after blocking/unblocking)
  static void invalidateUser(String userId) {
    _profileCache.remove(userId);
    _cacheTimestamps.remove(userId);
  }

  /// Watch received likes in real-time
  /// Returns a Stream of UserProfiles who have liked the current user
  /// Sorted by timestamp (newest first)
  Stream<List<UserProfile>> watchReceivedLikes() {
    final userId = currentUserId;
    if (userId == null) {
      return Stream.value([]);
    }

    // Listen to actions where toUserId == currentUserId
    return _firestore
        .collection('actions')
        .where('toUserId', isEqualTo: userId)
        .snapshots()
        .asyncMap((actionsSnapshot) async {
      // Step 1: Filter only likes and superLikes
      var likeActions = actionsSnapshot.docs.where((doc) {
        final type = doc.data()['type'] as String?;
        return type == 'like' || type == 'superlike';
      }).toList();

      if (likeActions.isEmpty) {
        return <UserProfile>[];
      }

      // Sort by timestamp (newest first) - client-side sorting
      likeActions.sort((a, b) {
        final aTimestamp = a.data()['timestamp'] as Timestamp?;
        final bTimestamp = b.data()['timestamp'] as Timestamp?;
        if (aTimestamp == null && bTimestamp == null) return 0;
        if (aTimestamp == null) return 1;
        if (bTimestamp == null) return -1;
        return bTimestamp.compareTo(aTimestamp); // Descending (newest first)
      });

      // Collect fromUserIds (now in sorted order)
      final likedByUserIds =
          likeActions.map((doc) => doc.data()['fromUserId'] as String).toList();

      // Step 2: Get my actions (to filter out already liked back or dismissed)
      final myActionsSnapshot = await _firestore
          .collection('actions')
          .where('fromUserId', isEqualTo: userId)
          .get();

      final likedBackIds = <String>{};
      final dismissedIds = <String>{};

      for (var doc in myActionsSnapshot.docs) {
        final data = doc.data();
        final toUserId = data['toUserId'] as String?;
        final type = data['type'] as String?;

        if (toUserId != null) {
          if (type == 'like' || type == 'superlike') {
            likedBackIds.add(toUserId);
          } else if (type == 'dismissed') {
            dismissedIds.add(toUserId);
          }
        }
      }

      // Filter out liked back and dismissed users
      final filteredUserIds = likedByUserIds
          .where((id) => !likedBackIds.contains(id) && !dismissedIds.contains(id))
          .toList();

      // Step 3: Filter out already matched users
      final matchesSnapshot = await _firestore
          .collection('matches')
          .where('users', arrayContains: userId)
          .get();

      final matchedUserIds = <String>{};
      for (var doc in matchesSnapshot.docs) {
        final users = List<String>.from(doc.data()['users'] ?? []);
        matchedUserIds.addAll(users.where((id) => id != userId));
      }

      final finalUserIds = filteredUserIds
          .where((id) => !matchedUserIds.contains(id))
          .toList();

      if (finalUserIds.isEmpty) {
        return <UserProfile>[];
      }

      // Step 4: Batch fetch user profiles (OPTIMIZED - 30 IDs per query)
      // Old: 100 users = 100 reads (N+1 problem)
      // New: 100 users = 4 reads (whereIn with 30-item chunks)
      final profiles = await _batchFetchProfiles(finalUserIds);

      return profiles;
    });
  }

  /// Get eliminated user IDs (disliked from likes screen)
  Future<Set<String>> getEliminatedUserIds() async {
    final userId = currentUserId;
    if (userId == null) return {};

    final myActionsSnapshot = await _firestore
        .collection('actions')
        .where('fromUserId', isEqualTo: userId)
        .get();

    final eliminatedIds = <String>{};
    for (var doc in myActionsSnapshot.docs) {
      final data = doc.data();
      final toUserId = data['toUserId'] as String?;
      final type = data['type'] as String?;

      if (toUserId != null && type == 'dislike') {
        eliminatedIds.add(toUserId);
      }
    }

    return eliminatedIds;
  }

  /// Like a user who has liked the current user (creates a match)
  Future<Map<String, dynamic>> likeUser(String targetUserId) async {
    final userId = currentUserId;
    if (userId == null) {
      return {'success': false, 'error': 'Not authenticated'};
    }

    try {
      final actionId = '${userId}_$targetUserId';

      // Record the like action
      await _firestore.collection('actions').doc(actionId).set({
        'fromUserId': userId,
        'toUserId': targetUserId,
        'type': 'like',
        'timestamp': FieldValue.serverTimestamp(),
      });

      // Since they already liked us, this is a match
      final sortedIds = [userId, targetUserId]..sort();
      final matchId = '${sortedIds[0]}_${sortedIds[1]}';

      // Check if match already exists
      final existingMatch =
          await _firestore.collection('matches').doc(matchId).get();

      if (!existingMatch.exists) {
        // Create match document
        await _firestore.collection('matches').doc(matchId).set({
          'users': sortedIds,
          'timestamp': FieldValue.serverTimestamp(),
        });

        // Add to each user's matches subcollection
        final batch = _firestore.batch();

        batch.set(
          _firestore
              .collection('users')
              .doc(userId)
              .collection('matches')
              .doc(targetUserId),
          {'timestamp': FieldValue.serverTimestamp(), 'matchId': matchId},
        );

        batch.set(
          _firestore
              .collection('users')
              .doc(targetUserId)
              .collection('matches')
              .doc(userId),
          {'timestamp': FieldValue.serverTimestamp(), 'matchId': matchId},
        );

        await batch.commit();
      }

      return {'success': true, 'isMatch': true, 'matchId': matchId};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Dislike a user who has liked the current user
  Future<Map<String, dynamic>> dislikeUser(String targetUserId) async {
    final userId = currentUserId;
    if (userId == null) {
      return {'success': false, 'error': 'Not authenticated'};
    }

    try {
      final actionId = '${userId}_$targetUserId';

      await _firestore.collection('actions').doc(actionId).set({
        'fromUserId': userId,
        'toUserId': targetUserId,
        'type': 'dislike',
        'timestamp': FieldValue.serverTimestamp(),
      });

      return {'success': true};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Dismiss a user from the likes list (after disliking, remove from view)
  /// Uses set instead of update to create the document if it doesn't exist
  Future<Map<String, dynamic>> dismissUser(String targetUserId) async {
    final userId = currentUserId;
    if (userId == null) {
      return {'success': false, 'error': 'Not authenticated'};
    }

    try {
      final actionId = '${userId}_$targetUserId';

      // set kullanarak doküman yoksa oluştur, varsa güncelle
      await _firestore.collection('actions').doc(actionId).set({
        'fromUserId': userId,
        'toUserId': targetUserId,
        'type': 'dismissed',
        'timestamp': FieldValue.serverTimestamp(),
      });

      return {'success': true};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }
}
