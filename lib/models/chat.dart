import 'package:cloud_firestore/cloud_firestore.dart';

/// Chat model - Sohbet listesi için
class Chat {
  final String id;
  final List<String> users;
  final String peerId;
  final String peerName;
  final String? peerImage;
  final String? lastMessage;
  final DateTime? lastMessageTime;
  final bool isRead;
  final String? lastMessageSenderId;

  Chat({
    required this.id,
    required this.users,
    required this.peerId,
    required this.peerName,
    this.peerImage,
    this.lastMessage,
    this.lastMessageTime,
    this.isRead = true,
    this.lastMessageSenderId,
  });

  /// Generate chat ID from two user IDs (alphabetically sorted)
  static String generateChatId(String userId1, String userId2) {
    final sortedIds = [userId1, userId2]..sort();
    return '${sortedIds[0]}_${sortedIds[1]}';
  }

  /// Get peer ID from chat for current user
  static String getPeerId(String chatId, String currentUserId) {
    final ids = chatId.split('_');
    return ids[0] == currentUserId ? ids[1] : ids[0];
  }

  /// Create from Firestore document
  factory Chat.fromFirestore(DocumentSnapshot doc, String currentUserId) {
    final data = doc.data() as Map<String, dynamic>;

    // Determine peer info based on current user
    final users = List<String>.from(data['users'] ?? []);
    final peerId = users.firstWhere(
      (id) => id != currentUserId,
      orElse: () => '',
    );

    // Get peer-specific data
    final peerData = data['peerData'] as Map<String, dynamic>? ?? {};
    final peerName = peerId == users[0]
        ? (peerData['user1Name'] ?? 'Kullanici')
        : (peerData['user2Name'] ?? 'Kullanici');
    final peerImage = peerId == users[0]
        ? peerData['user1Image']
        : peerData['user2Image'];

    // Parse timestamp
    DateTime? lastMessageTime;
    if (data['lastMessageTime'] != null) {
      if (data['lastMessageTime'] is Timestamp) {
        lastMessageTime = (data['lastMessageTime'] as Timestamp).toDate();
      }
    }

    // Check if message is read by current user
    final readBy = List<String>.from(data['readBy'] ?? []);
    final isRead = readBy.contains(currentUserId);

    return Chat(
      id: doc.id,
      users: users,
      peerId: peerId,
      peerName: peerName,
      peerImage: peerImage,
      lastMessage: data['lastMessage'] as String?,
      lastMessageTime: lastMessageTime,
      isRead: isRead,
      lastMessageSenderId: data['lastMessageSenderId'] as String?,
    );
  }

  /// Convert to Firestore map
  Map<String, dynamic> toFirestore() {
    return {
      'users': users,
      'lastMessage': lastMessage,
      'lastMessageTime': lastMessageTime != null
          ? Timestamp.fromDate(lastMessageTime!)
          : FieldValue.serverTimestamp(),
      'lastMessageSenderId': lastMessageSenderId,
    };
  }

  /// Format time for display
  String get formattedTime {
    if (lastMessageTime == null) return '';

    final now = DateTime.now();
    final diff = now.difference(lastMessageTime!);

    if (diff.inMinutes < 1) {
      return 'Simdi';
    } else if (diff.inHours < 1) {
      return '${diff.inMinutes} dk';
    } else if (diff.inDays < 1) {
      return '${diff.inHours} sa';
    } else if (diff.inDays < 7) {
      return '${diff.inDays} gun';
    } else {
      return '${lastMessageTime!.day}/${lastMessageTime!.month}';
    }
  }

  /// Check if current user has unread messages
  bool hasUnreadFor(String currentUserId) {
    // If last message was sent by current user, it's "read"
    if (lastMessageSenderId == currentUserId) return false;
    // Otherwise check isRead status
    return !isRead;
  }

  Chat copyWith({
    String? id,
    List<String>? users,
    String? peerId,
    String? peerName,
    String? peerImage,
    String? lastMessage,
    DateTime? lastMessageTime,
    bool? isRead,
    String? lastMessageSenderId,
  }) {
    return Chat(
      id: id ?? this.id,
      users: users ?? this.users,
      peerId: peerId ?? this.peerId,
      peerName: peerName ?? this.peerName,
      peerImage: peerImage ?? this.peerImage,
      lastMessage: lastMessage ?? this.lastMessage,
      lastMessageTime: lastMessageTime ?? this.lastMessageTime,
      isRead: isRead ?? this.isRead,
      lastMessageSenderId: lastMessageSenderId ?? this.lastMessageSenderId,
    );
  }
}

/// Message model - Mesajlar için
class Message {
  final String id;
  final String senderId;
  final String text;
  final DateTime timestamp;
  final MessageType type;
  final bool isRead;

  Message({
    required this.id,
    required this.senderId,
    required this.text,
    required this.timestamp,
    this.type = MessageType.text,
    this.isRead = false,
  });

  /// Create from Firestore document
  factory Message.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    DateTime timestamp;
    if (data['timestamp'] != null && data['timestamp'] is Timestamp) {
      timestamp = (data['timestamp'] as Timestamp).toDate();
    } else {
      timestamp = DateTime.now();
    }

    return Message(
      id: doc.id,
      senderId: data['senderId'] ?? '',
      text: data['text'] ?? '',
      timestamp: timestamp,
      type: MessageType.values.firstWhere(
        (t) => t.name == data['type'],
        orElse: () => MessageType.text,
      ),
      isRead: data['isRead'] ?? false,
    );
  }

  /// Convert to Firestore map
  Map<String, dynamic> toFirestore() {
    return {
      'senderId': senderId,
      'text': text,
      'timestamp': FieldValue.serverTimestamp(),
      'type': type.name,
      'isRead': isRead,
    };
  }

  /// Format time for display
  String get formattedTime {
    final hour = timestamp.hour.toString().padLeft(2, '0');
    final minute = timestamp.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  /// Check if message is from current user
  bool isFromMe(String currentUserId) => senderId == currentUserId;
}

/// Message type enum
enum MessageType {
  text,
  image,
  system,
}
