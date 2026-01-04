import 'package:cloud_firestore/cloud_firestore.dart';

/// User profile model for swipe cards
class UserProfile {
  final String id;
  final String name;
  final int age;
  final String bio;
  final String university;
  final String department;
  final List<String> photos;
  final List<String> interests;
  final String gender;
  final String lookingFor;
  final DateTime? createdAt;
  final GeoPoint? location;

  // Zenginleştirilmiş Profil Alanları
  final String grade; // Sınıf Seviyesi (Hazırlık, 1. Sınıf, 2. Sınıf, vb.)
  final List<String> clubs; // Topluluklar/Kulüpler
  final Map<String, String> socialLinks; // Sosyal medya linkleri (instagram, linkedin, vb.)
  final List<String> intent; // Niyet (Kahve içmek, Ders çalışmak, Spor yapmak, vb.)

  const UserProfile({
    required this.id,
    required this.name,
    required this.age,
    this.bio = '',
    this.university = '',
    this.department = '',
    this.photos = const [],
    this.interests = const [],
    this.gender = '',
    this.lookingFor = '',
    this.createdAt,
    this.location,
    this.grade = '',
    this.clubs = const [],
    this.socialLinks = const {},
    this.intent = const [],
  });

  /// Create from Firestore document
  factory UserProfile.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};

    return UserProfile(
      id: doc.id,
      name: data['name'] as String? ?? 'İsimsiz',
      age: data['age'] as int? ?? 0,
      bio: data['bio'] as String? ?? '',
      university: data['university'] as String? ?? '',
      department: data['department'] as String? ?? '',
      photos: List<String>.from(data['photos'] ?? []),
      interests: List<String>.from(data['interests'] ?? []),
      gender: data['gender'] as String? ?? '',
      lookingFor: data['lookingFor'] as String? ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      location: data['location'] as GeoPoint?,
      grade: data['grade'] as String? ?? '',
      clubs: List<String>.from(data['clubs'] ?? []),
      socialLinks: Map<String, String>.from(data['socialLinks'] ?? {}),
      intent: List<String>.from(data['intent'] ?? []),
    );
  }

  /// Convert to Firestore map
  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'age': age,
      'bio': bio,
      'university': university,
      'department': department,
      'photos': photos,
      'interests': interests,
      'gender': gender,
      'lookingFor': lookingFor,
      'createdAt': createdAt != null
          ? Timestamp.fromDate(createdAt!)
          : FieldValue.serverTimestamp(),
      if (location != null) 'location': location,
      'grade': grade,
      'clubs': clubs,
      'socialLinks': socialLinks,
      'intent': intent,
    };
  }

  /// Get primary photo or placeholder
  String get primaryPhoto => photos.isNotEmpty
      ? photos.first
      : 'https://via.placeholder.com/400x600?text=No+Photo';

  /// Check if profile is complete
  bool get isComplete => name.isNotEmpty && age > 0 && photos.isNotEmpty;

  @override
  String toString() => 'UserProfile(id: $id, name: $name, age: $age)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UserProfile &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}

/// Swipe action types
enum SwipeActionType {
  like,
  dislike,
  superlike,
}

/// Swipe action model for Firestore
class SwipeAction {
  final String id;
  final String fromUserId;
  final String toUserId;
  final SwipeActionType type;
  final DateTime timestamp;

  const SwipeAction({
    required this.id,
    required this.fromUserId,
    required this.toUserId,
    required this.type,
    required this.timestamp,
  });

  factory SwipeAction.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};

    return SwipeAction(
      id: doc.id,
      fromUserId: data['fromUserId'] as String? ?? '',
      toUserId: data['toUserId'] as String? ?? '',
      type: SwipeActionType.values.firstWhere(
        (e) => e.name == data['type'],
        orElse: () => SwipeActionType.dislike,
      ),
      timestamp: (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'fromUserId': fromUserId,
      'toUserId': toUserId,
      'type': type.name,
      'timestamp': Timestamp.fromDate(timestamp),
    };
  }

  /// Generate document ID
  static String generateId(String fromUserId, String toUserId) {
    return '${fromUserId}_$toUserId';
  }
}

/// Match model
class Match {
  final String id;
  final List<String> userIds;
  final DateTime matchedAt;
  final DateTime? lastMessageAt;

  const Match({
    required this.id,
    required this.userIds,
    required this.matchedAt,
    this.lastMessageAt,
  });

  factory Match.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};

    return Match(
      id: doc.id,
      userIds: List<String>.from(data['users'] ?? []),
      matchedAt: (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      lastMessageAt: (data['lastMessageAt'] as Timestamp?)?.toDate(),
    );
  }
}
