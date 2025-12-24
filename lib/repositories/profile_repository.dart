import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';

/// Profile data model for creating/updating profiles
class ProfileData {
  final String name;
  final int age;
  final String university;
  final String department;
  final String bio;
  final String gender;
  final String lookingFor;
  final List<String> interests;

  const ProfileData({
    required this.name,
    required this.age,
    required this.university,
    required this.department,
    required this.bio,
    required this.gender,
    required this.lookingFor,
    this.interests = const [],
  });

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'age': age,
      'university': university,
      'department': department,
      'bio': bio,
      'gender': gender,
      'lookingFor': lookingFor,
      'interests': interests,
    };
  }
}

/// Repository for profile-related operations
class ProfileRepository {
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;
  final FirebaseStorage _storage;

  ProfileRepository({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
    FirebaseStorage? storage,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance,
        _storage = storage ?? FirebaseStorage.instance;

  /// Get current user ID
  String? get currentUserId => _auth.currentUser?.uid;

  /// Check if user has a complete profile
  /// Returns true only if ALL required fields are filled
  Future<bool> hasProfile() async {
    final userId = currentUserId;
    if (userId == null) return false;

    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      if (!doc.exists) return false;

      final data = doc.data();
      if (data == null) return false;

      // Check ALL required fields
      final name = data['name'] as String?;
      final age = data['age'] as int?;
      final university = data['university'] as String?;
      final department = data['department'] as String?;
      final bio = data['bio'] as String?;
      final photos = data['photos'] as List<dynamic>?;

      // All fields must be present and non-empty
      final isComplete = name != null && name.isNotEmpty &&
             age != null && age >= 18 &&
             university != null && university.isNotEmpty &&
             department != null && department.isNotEmpty &&
             bio != null && bio.isNotEmpty &&
             photos != null && photos.isNotEmpty;

      return isComplete;
    } catch (e) {
      debugPrint('hasProfile error: $e');
      return false;
    }
  }

  /// Upload profile image to Firebase Storage
  /// Returns the download URL
  Future<String> uploadProfileImage(File imageFile) async {
    final userId = currentUserId;
    if (userId == null) {
      throw Exception('Kullanıcı oturumu bulunamadı');
    }

    try {
      // Create unique filename with timestamp
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final ref = _storage.ref().child('profile_images/$userId/$timestamp.jpg');

      // Upload file with metadata
      final uploadTask = ref.putFile(
        imageFile,
        SettableMetadata(
          contentType: 'image/jpeg',
          customMetadata: {'userId': userId},
        ),
      );

      // Wait for upload to complete
      final snapshot = await uploadTask;

      // Get download URL
      final downloadUrl = await snapshot.ref.getDownloadURL();
      return downloadUrl;
    } on FirebaseException catch (e) {
      throw Exception('Fotoğraf yüklenirken hata: ${e.message}');
    }
  }

  /// Save profile data to Firestore
  Future<void> saveProfile({
    required ProfileData profileData,
    required String imageUrl,
  }) async {
    final userId = currentUserId;
    if (userId == null) {
      throw Exception('Kullanıcı oturumu bulunamadı');
    }

    try {
      final data = {
        ...profileData.toMap(),
        'photos': [imageUrl],
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      await _firestore.collection('users').doc(userId).set(
        data,
        SetOptions(merge: true),
      );
    } on FirebaseException catch (e) {
      throw Exception('Profil kaydedilirken hata: ${e.message}');
    }
  }

  /// Create profile with image upload in one operation
  Future<void> createProfile({
    required ProfileData profileData,
    required File imageFile,
  }) async {
    // Step 1: Upload image
    final imageUrl = await uploadProfileImage(imageFile);

    // Step 2: Save profile data
    await saveProfile(
      profileData: profileData,
      imageUrl: imageUrl,
    );
  }

  /// Get current user's profile
  Future<Map<String, dynamic>?> getProfile() async {
    final userId = currentUserId;
    if (userId == null) return null;

    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      if (!doc.exists) return null;
      return doc.data();
    } catch (e) {
      return null;
    }
  }

  /// Update profile fields
  Future<void> updateProfile(Map<String, dynamic> updates) async {
    final userId = currentUserId;
    if (userId == null) {
      throw Exception('Kullanıcı oturumu bulunamadı');
    }

    try {
      await _firestore.collection('users').doc(userId).update({
        ...updates,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } on FirebaseException catch (e) {
      throw Exception('Profil güncellenirken hata: ${e.message}');
    }
  }

  /// Add additional photo to profile
  Future<void> addPhoto(File imageFile) async {
    final userId = currentUserId;
    if (userId == null) {
      throw Exception('Kullanıcı oturumu bulunamadı');
    }

    // Upload new image
    final imageUrl = await uploadProfileImage(imageFile);

    // Add to photos array
    await _firestore.collection('users').doc(userId).update({
      'photos': FieldValue.arrayUnion([imageUrl]),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Remove photo from profile
  Future<void> removePhoto(String imageUrl) async {
    final userId = currentUserId;
    if (userId == null) {
      throw Exception('Kullanıcı oturumu bulunamadı');
    }

    await _firestore.collection('users').doc(userId).update({
      'photos': FieldValue.arrayRemove([imageUrl]),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    // Optionally delete from storage
    try {
      final ref = _storage.refFromURL(imageUrl);
      await ref.delete();
    } catch (_) {
      // Ignore storage deletion errors
    }
  }
}
