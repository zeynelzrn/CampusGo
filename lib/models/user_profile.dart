import 'package:cloud_firestore/cloud_firestore.dart';

/// User profile model for swipe cards
class UserProfile {
  final String id;
  final String name;
  final DateTime? birthDate; // Doğum tarihi - yaş buradan hesaplanır
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

  // Admin ve Ban Durumu
  final bool isAdmin; // Admin yetkisi (Firebase Console'dan manuel verilir)
  final bool isBanned; // Banlı kullanıcı (Adminler tarafından verilir)

  // Legacy age field for backward compatibility (eski kayıtlar için)
  final int? _legacyAge;

  const UserProfile({
    required this.id,
    required this.name,
    this.birthDate,
    int? legacyAge, // Eski kayıtlardan gelen yaş değeri
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
    this.isAdmin = false,
    this.isBanned = false,
  }) : _legacyAge = legacyAge;

  /// Dinamik yaş hesaplama - doğum tarihinden otomatik hesaplanır
  /// Eğer birthDate yoksa legacy age değerini kullanır (geriye uyumluluk)
  int get age {
    if (birthDate != null) {
      final now = DateTime.now();
      int calculatedAge = now.year - birthDate!.year;
      // Doğum günü henüz gelmemişse 1 çıkar
      if (now.month < birthDate!.month ||
          (now.month == birthDate!.month && now.day < birthDate!.day)) {
        calculatedAge--;
      }
      return calculatedAge;
    }
    // Eski kayıtlar için legacy age kullan
    return _legacyAge ?? 0;
  }

  /// Create from Firestore document
  factory UserProfile.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};

    return UserProfile(
      id: doc.id,
      name: data['name'] as String? ?? 'İsimsiz',
      birthDate: (data['birthDate'] as Timestamp?)?.toDate(),
      legacyAge: data['age'] as int?, // Eski kayıtlar için geriye uyumluluk
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
      // Admin ve Ban durumu - varsayılan olarak false (güvenlik için kritik)
      isAdmin: data['isAdmin'] as bool? ?? false,
      isBanned: data['isBanned'] as bool? ?? false,
    );
  }

  /// Convert to Firestore map
  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      if (birthDate != null) 'birthDate': Timestamp.fromDate(birthDate!),
      // age alanını da kaydet (geriye uyumluluk ve hızlı sorgular için)
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

  /// Convert to JSON for SharedPreferences caching
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'birthDate': birthDate?.toIso8601String(),
      'legacyAge': _legacyAge,
      'bio': bio,
      'university': university,
      'department': department,
      'photos': photos,
      'interests': interests,
      'gender': gender,
      'lookingFor': lookingFor,
      'createdAt': createdAt?.toIso8601String(),
      'grade': grade,
      'clubs': clubs,
      'socialLinks': socialLinks,
      'intent': intent,
      'isAdmin': isAdmin,
      'isBanned': isBanned,
      // Note: GeoPoint is not serialized to JSON cache
    };
  }

  /// Create from JSON (SharedPreferences cache)
  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? 'İsimsiz',
      birthDate: json['birthDate'] != null
          ? DateTime.tryParse(json['birthDate'] as String)
          : null,
      legacyAge: json['legacyAge'] as int? ?? json['age'] as int?,
      bio: json['bio'] as String? ?? '',
      university: json['university'] as String? ?? '',
      department: json['department'] as String? ?? '',
      photos: List<String>.from(json['photos'] ?? []),
      interests: List<String>.from(json['interests'] ?? []),
      gender: json['gender'] as String? ?? '',
      lookingFor: json['lookingFor'] as String? ?? '',
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'] as String)
          : null,
      grade: json['grade'] as String? ?? '',
      clubs: List<String>.from(json['clubs'] ?? []),
      socialLinks: Map<String, String>.from(json['socialLinks'] ?? {}),
      intent: List<String>.from(json['intent'] ?? []),
      isAdmin: json['isAdmin'] as bool? ?? false,
      isBanned: json['isBanned'] as bool? ?? false,
    );
  }

  /// Get primary photo or placeholder
  String get primaryPhoto => photos.isNotEmpty
      ? photos.first
      : 'https://via.placeholder.com/400x600?text=No+Photo';

  /// Check if profile is complete
  bool get isComplete => name.isNotEmpty && age > 0 && photos.isNotEmpty;

  /// Doğum tarihi var mı kontrol et
  bool get hasBirthDate => birthDate != null;

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
