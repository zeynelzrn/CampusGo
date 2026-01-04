import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../models/chat.dart';
import '../models/user_profile.dart';

/// Service for real-time chat operations
class ChatService {
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  ChatService({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  /// Get current user ID
  String? get currentUserId => _auth.currentUser?.uid;

  /// Collection references
  CollectionReference<Map<String, dynamic>> get _chatsCollection =>
      _firestore.collection('chats');

  CollectionReference<Map<String, dynamic>> get _usersCollection =>
      _firestore.collection('users');

  // ==================== CHAT LIST OPERATIONS ====================

  /// Stream all chats for current user (sorted by lastMessageTime descending)
  ///
  /// NOT: Bu sorgu Composite Index gerektirir!
  /// Firestore Console'da 'chats' koleksiyonu icin:
  /// - users (Arrays) + lastMessageTime (Descending) indexi olusturun
  Stream<List<Chat>> watchChats() {
    final userId = currentUserId;
    if (userId == null) {
      debugPrint('ChatService: User not logged in');
      return Stream.value([]);
    }

    debugPrint('ChatService: Watching chats for user: $userId');

    return _chatsCollection
        .where('users', arrayContains: userId)
        .orderBy('lastMessageTime', descending: true)
        .snapshots()
        .handleError((error, stackTrace) {
          debugPrint('========== FIRESTORE CHAT ERROR ==========');
          debugPrint('Error: $error');
          debugPrint('Stack: $stackTrace');

          final errorStr = error.toString();
          if (errorStr.contains('FAILED_PRECONDITION') ||
              errorStr.contains('index') ||
              errorStr.contains('Index')) {
            debugPrint('');
            debugPrint('>>> COMPOSITE INDEX GEREKIYOR! <<<');
            debugPrint('Firebase Console\'a gidin ve asagidaki indexi olusturun:');
            debugPrint('Collection: chats');
            debugPrint('Fields: users (Arrays) + lastMessageTime (Descending)');
            debugPrint('');
            debugPrint('VEYA hata mesajindaki linke tiklayin!');
          }

          if (errorStr.contains('PERMISSION_DENIED') ||
              errorStr.contains('permission')) {
            debugPrint('');
            debugPrint('>>> PERMISSION DENIED! <<<');
            debugPrint('Firestore Security Rules kontrol edin.');
          }
          debugPrint('============================================');
        })
        .map((snapshot) {
          debugPrint('ChatService: Received ${snapshot.docs.length} chats');
          return snapshot.docs.map((doc) {
            return Chat.fromFirestore(doc, userId);
          }).toList();
        });
  }

  /// Get a specific chat by ID
  Future<Chat?> getChat(String chatId) async {
    final userId = currentUserId;
    if (userId == null) return null;

    try {
      final doc = await _chatsCollection.doc(chatId).get();
      if (!doc.exists) return null;
      return Chat.fromFirestore(doc, userId);
    } catch (e) {
      print('Error getting chat: $e');
      return null;
    }
  }

  /// Create or get existing chat between two users
  Future<String?> createOrGetChat(String peerId) async {
    final userId = currentUserId;
    if (userId == null) return null;

    try {
      final chatId = Chat.generateChatId(userId, peerId);

      // Check if chat already exists
      final existingChat = await _chatsCollection.doc(chatId).get();
      if (existingChat.exists) {
        return chatId;
      }

      // Get both user profiles for peer data
      final currentUserDoc = await _usersCollection.doc(userId).get();
      final peerDoc = await _usersCollection.doc(peerId).get();

      if (!peerDoc.exists) return null;

      final currentUserData = currentUserDoc.data() ?? {};
      final peerData = peerDoc.data() ?? {};

      // Sort users alphabetically to maintain consistency
      final sortedIds = [userId, peerId]..sort();
      final isCurrentUserFirst = sortedIds[0] == userId;

      // Create chat document with peer data for both users
      await _chatsCollection.doc(chatId).set({
        'users': sortedIds,
        'peerData': {
          'user1Name': isCurrentUserFirst
              ? currentUserData['name'] ?? 'Kullanici'
              : peerData['name'] ?? 'Kullanici',
          'user1Image': isCurrentUserFirst
              ? (currentUserData['photos'] as List?)?.firstOrNull
              : (peerData['photos'] as List?)?.firstOrNull,
          'user2Name': isCurrentUserFirst
              ? peerData['name'] ?? 'Kullanici'
              : currentUserData['name'] ?? 'Kullanici',
          'user2Image': isCurrentUserFirst
              ? (peerData['photos'] as List?)?.firstOrNull
              : (currentUserData['photos'] as List?)?.firstOrNull,
        },
        'lastMessage': null,
        'lastMessageTime': FieldValue.serverTimestamp(),
        'lastMessageSenderId': null,
        'readBy': [userId, peerId], // Both users have "read" the empty chat
        'createdAt': FieldValue.serverTimestamp(),
      });

      return chatId;
    } catch (e) {
      print('Error creating chat: $e');
      return null;
    }
  }

  /// Create chat when match happens (called from SwipeRepository)
  /// Takes both user IDs to ensure proper chat creation
  Future<String?> createMatchChat(String userId1, String userId2) async {
    try {
      final chatId = Chat.generateChatId(userId1, userId2);

      // Check if chat already exists
      final existingChat = await _chatsCollection.doc(chatId).get();
      if (existingChat.exists) {
        debugPrint('ChatService: Chat already exists: $chatId');
        return chatId;
      }

      // Get both user profiles for peer data
      final user1Doc = await _usersCollection.doc(userId1).get();
      final user2Doc = await _usersCollection.doc(userId2).get();

      if (!user1Doc.exists || !user2Doc.exists) {
        debugPrint('ChatService: One or both users not found');
        return null;
      }

      final user1Data = user1Doc.data() ?? {};
      final user2Data = user2Doc.data() ?? {};

      // Sort users alphabetically to maintain consistency
      final sortedIds = [userId1, userId2]..sort();
      final isUser1First = sortedIds[0] == userId1;

      debugPrint('ChatService: Creating chat room: $chatId');

      // Create chat document with peer data for both users
      await _chatsCollection.doc(chatId).set({
        'users': sortedIds,
        'peerData': {
          'user1Name': isUser1First
              ? user1Data['name'] ?? 'Kullanici'
              : user2Data['name'] ?? 'Kullanici',
          'user1Image': isUser1First
              ? (user1Data['photos'] as List?)?.firstOrNull
              : (user2Data['photos'] as List?)?.firstOrNull,
          'user2Name': isUser1First
              ? user2Data['name'] ?? 'Kullanici'
              : user1Data['name'] ?? 'Kullanici',
          'user2Image': isUser1First
              ? (user2Data['photos'] as List?)?.firstOrNull
              : (user1Data['photos'] as List?)?.firstOrNull,
        },
        'lastMessage': null,
        'lastMessageTime': FieldValue.serverTimestamp(), // Current time for sorting
        'lastMessageSenderId': null,
        'readBy': [userId1, userId2], // Both users have "read" the empty chat
        'createdAt': FieldValue.serverTimestamp(),
        'isNewMatch': true, // Flag for new match
      });

      debugPrint('ChatService: Chat room created successfully: $chatId');
      return chatId;
    } catch (e) {
      debugPrint('ChatService: Error creating match chat: $e');
      return null;
    }
  }

  /// Legacy method - redirects to createMatchChat
  Future<String?> createChatOnMatch(String matchedUserId) async {
    final userId = currentUserId;
    if (userId == null) return null;
    return await createMatchChat(userId, matchedUserId);
  }

  // ==================== MESSAGE OPERATIONS ====================

  /// Stream messages for a specific chat (ordered by timestamp ascending)
  Stream<List<Message>> watchMessages(String chatId) {
    return _chatsCollection
        .doc(chatId)
        .collection('messages')
        .orderBy('timestamp', descending: false)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => Message.fromFirestore(doc)).toList();
    });
  }

  /// Send a message and update chat's last message
  Future<bool> sendMessage({
    required String chatId,
    required String text,
    MessageType type = MessageType.text,
  }) async {
    final userId = currentUserId;
    if (userId == null || text.trim().isEmpty) return false;

    try {
      // Use batch write for atomicity
      final batch = _firestore.batch();

      // 1. Add message to messages subcollection
      final messageRef = _chatsCollection.doc(chatId).collection('messages').doc();
      batch.set(messageRef, {
        'senderId': userId,
        'text': text.trim(),
        'timestamp': FieldValue.serverTimestamp(),
        'type': type.name,
        'isRead': false,
      });

      // 2. Update chat's lastMessage, lastMessageTime, and readBy
      final chatRef = _chatsCollection.doc(chatId);
      batch.update(chatRef, {
        'lastMessage': text.trim(),
        'lastMessageTime': FieldValue.serverTimestamp(),
        'lastMessageSenderId': userId,
        'readBy': [userId], // Only sender has "read" the message
      });

      await batch.commit();
      return true;
    } catch (e) {
      print('Error sending message: $e');
      return false;
    }
  }

  /// Mark chat as read by current user
  Future<void> markChatAsRead(String chatId) async {
    final userId = currentUserId;
    if (userId == null) return;

    try {
      await _chatsCollection.doc(chatId).update({
        'readBy': FieldValue.arrayUnion([userId]),
      });
    } catch (e) {
      print('Error marking chat as read: $e');
    }
  }

  /// Get unread message count for current user
  Stream<int> watchUnreadCount() {
    final userId = currentUserId;
    if (userId == null) return Stream.value(0);

    return _chatsCollection
        .where('users', arrayContains: userId)
        .snapshots()
        .map((snapshot) {
      int count = 0;
      for (final doc in snapshot.docs) {
        final data = doc.data();
        final readBy = List<String>.from(data['readBy'] ?? []);
        final lastMessageSenderId = data['lastMessageSenderId'] as String?;

        // Count as unread if:
        // 1. Current user hasn't read it
        // 2. Last message was NOT sent by current user
        // 3. There IS a last message
        if (!readBy.contains(userId) &&
            lastMessageSenderId != null &&
            lastMessageSenderId != userId) {
          count++;
        }
      }
      return count;
    });
  }

  // ==================== USER OPERATIONS ====================

  /// Get user profile by ID
  Future<UserProfile?> getUserProfile(String userId) async {
    try {
      final doc = await _usersCollection.doc(userId).get();
      if (!doc.exists) return null;
      return UserProfile.fromFirestore(doc);
    } catch (e) {
      print('Error getting user profile: $e');
      return null;
    }
  }

  /// Clear all messages in a chat (keeps the chat but removes messages)
  Future<bool> clearChat(String chatId) async {
    final userId = currentUserId;
    if (userId == null) return false;

    try {
      // Delete all messages
      final messagesSnapshot =
          await _chatsCollection.doc(chatId).collection('messages').get();

      final batch = _firestore.batch();
      for (final doc in messagesSnapshot.docs) {
        batch.delete(doc.reference);
      }

      // Reset chat metadata (but keep the chat)
      batch.update(_chatsCollection.doc(chatId), {
        'lastMessage': null,
        'lastMessageTime': FieldValue.serverTimestamp(),
        'lastMessageSenderId': null,
        'readBy': FieldValue.arrayUnion([userId]),
      });

      await batch.commit();
      return true;
    } catch (e) {
      print('Error clearing chat: $e');
      return false;
    }
  }

  /// Delete a chat and all its messages
  Future<bool> deleteChat(String chatId) async {
    final userId = currentUserId;
    if (userId == null) return false;

    try {
      // Delete all messages first
      final messagesSnapshot =
          await _chatsCollection.doc(chatId).collection('messages').get();

      final batch = _firestore.batch();
      for (final doc in messagesSnapshot.docs) {
        batch.delete(doc.reference);
      }

      // Delete the chat document
      batch.delete(_chatsCollection.doc(chatId));

      await batch.commit();
      return true;
    } catch (e) {
      print('Error deleting chat: $e');
      return false;
    }
  }
}
