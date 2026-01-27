import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../models/user_profile.dart';
import '../services/profile_cache_service.dart';

/// Profile data model for creating/updating profiles
class ProfileData {
  final String name;
  final DateTime birthDate; // Doğum tarihi - yaş otomatik hesaplanır
  final String university;
  final String department;
  final String bio;
  final String gender;
  final String lookingFor;
  final List<String> interests;

  const ProfileData({
    required this.name,
    required this.birthDate,
    required this.university,
    required this.department,
    required this.bio,
    required this.gender,
    required this.lookingFor,
    this.interests = const [],
  });

  /// Doğum tarihinden yaş hesapla
  int get age {
    final now = DateTime.now();
    int calculatedAge = now.year - birthDate.year;
    if (now.month < birthDate.month ||
        (now.month == birthDate.month && now.day < birthDate.day)) {
      calculatedAge--;
    }
    return calculatedAge;
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'birthDate': Timestamp.fromDate(birthDate), // Doğum tarihi kaydet
      'age': age, // Hesaplanan yaşı da kaydet (geriye uyumluluk + hızlı sorgular)
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
  final ProfileCacheService _cacheService = ProfileCacheService.instance;

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
      final isComplete = name != null &&
          name.isNotEmpty &&
          age != null &&
          age >= 18 &&
          university != null &&
          university.isNotEmpty &&
          department != null &&
          department.isNotEmpty &&
          bio != null &&
          bio.isNotEmpty &&
          photos != null &&
          photos.isNotEmpty;

      return isComplete;
    } catch (e) {
      debugPrint('hasProfile error: $e');
      return false;
    }
  }

  /// Upload single profile image to Firebase Storage
  /// Standardized path: user_photos/{userId}/{timestamp}.jpg
  /// Returns the download URL
  Future<String> uploadProfileImage(File imageFile, {int slotIndex = 0}) async {
    final userId = currentUserId;
    if (userId == null) {
      throw Exception('Kullanıcı oturumu bulunamadı');
    }

    try {
      // Create unique filename with timestamp and slot index
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      // Standardized path: user_photos/{userId}/{timestamp}_{slot}.jpg
      final ref = _storage.ref().child('user_photos/$userId/${timestamp}_$slotIndex.jpg');

      // Upload file with metadata
      final uploadTask = ref.putFile(
        imageFile,
        SettableMetadata(
          contentType: 'image/jpeg',
          customMetadata: {
            'userId': userId,
            'slotIndex': slotIndex.toString(),
            'uploadedAt': DateTime.now().toIso8601String(),
          },
        ),
      );

      // Wait for upload to complete
      final snapshot = await uploadTask;

      // Get download URL
      final downloadUrl = await snapshot.ref.getDownloadURL();
      debugPrint('ProfileRepository: Foto yüklendi -> user_photos/$userId/${timestamp}_$slotIndex.jpg');
      return downloadUrl;
    } on FirebaseException catch (e) {
      throw Exception('Fotoğraf yüklenirken hata: ${e.message}');
    }
  }

  /// Upload multiple profile images to Firebase Storage
  /// Returns list of download URLs in the same order
  /// Emits progress via onProgress callback (0.0 - 1.0)
  Future<List<String>> uploadMultipleImages(
    List<File> imageFiles, {
    void Function(double progress)? onProgress,
  }) async {
    final userId = currentUserId;
    if (userId == null) {
      throw Exception('Kullanıcı oturumu bulunamadı');
    }

    if (imageFiles.isEmpty) {
      throw Exception('En az bir fotoğraf gerekli');
    }

    final List<String> downloadUrls = [];
    final total = imageFiles.length;

    for (int i = 0; i < total; i++) {
      final url = await uploadProfileImage(imageFiles[i], slotIndex: i);
      downloadUrls.add(url);

      // Report progress
      if (onProgress != null) {
        onProgress((i + 1) / total);
      }
    }

    return downloadUrls;
  }

  /// Save profile data to Firestore (supports multiple photos)
  Future<void> saveProfile({
    required ProfileData profileData,
    required List<String> photoUrls,
  }) async {
    final userId = currentUserId;
    if (userId == null) {
      throw Exception('Kullanıcı oturumu bulunamadı');
    }

    if (photoUrls.isEmpty) {
      throw Exception('En az bir fotoğraf gerekli');
    }

    try {
      final data = {
        ...profileData.toMap(),
        'photos': photoUrls, // All photo URLs
        'photoUrl': photoUrls.first, // Primary photo for avatar usage
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      await _firestore.collection('users').doc(userId).set(
            data,
            SetOptions(merge: true),
          );

      debugPrint('ProfileRepository: Profil kaydedildi (${photoUrls.length} fotoğraf)');
    } on FirebaseException catch (e) {
      throw Exception('Profil kaydedilirken hata: ${e.message}');
    }
  }

  /// Create profile with multiple images upload
  /// [imageFiles] - List of image files (min 1, max 6)
  /// [onProgress] - Progress callback (0.0 - 1.0)
  Future<void> createProfileWithPhotos({
    required ProfileData profileData,
    required List<File> imageFiles,
    void Function(double progress)? onProgress,
  }) async {
    // Step 1: Upload all images
    final photoUrls = await uploadMultipleImages(
      imageFiles,
      onProgress: onProgress,
    );

    // Step 2: Save profile data with all photo URLs
    await saveProfile(
      profileData: profileData,
      photoUrls: photoUrls,
    );
  }

  /// Legacy: Create profile with single image (backward compatibility)
  Future<void> createProfile({
    required ProfileData profileData,
    required File imageFile,
  }) async {
    await createProfileWithPhotos(
      profileData: profileData,
      imageFiles: [imageFile],
    );
  }

  /// Get current user's profile (Map format - legacy)
  Future<Map<String, dynamic>?> getProfile() async {
    final userId = currentUserId;
    if (userId == null) return null;

    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      if (!doc.exists) return null;

      final data = doc.data();

      // Cache the profile for instant loading next time
      if (data != null) {
        final profile = UserProfile.fromFirestore(doc);
        await _cacheService.cacheProfile(profile);
      }

      return data;
    } catch (e) {
      return null;
    }
  }

  /// Get current user's profile with Cache-First strategy
  /// Returns cached profile immediately, then fetches fresh data in background
  ///
  /// Usage with StreamController for UI updates:
  /// ```dart
  /// final cachedProfile = await repository.getCachedUserProfile();
  /// if (cachedProfile != null) {
  ///   // Show immediately
  ///   setState(() => _profile = cachedProfile);
  /// }
  /// // Fetch fresh data
  /// final freshProfile = await repository.getUserProfile(forceRefresh: cachedProfile != null);
  /// if (freshProfile != null && freshProfile != cachedProfile) {
  ///   setState(() => _profile = freshProfile);
  /// }
  /// ```
  Future<UserProfile?> getCachedUserProfile() async {
    final userId = currentUserId;
    if (userId == null) return null;

    return await _cacheService.getCachedProfile(userId);
  }

  /// Get current user's profile as UserProfile object
  /// If forceRefresh is false and cache is valid, returns cache
  /// Otherwise fetches from Firestore and updates cache
  Future<UserProfile?> getUserProfile({bool forceRefresh = false}) async {
    final userId = currentUserId;
    if (userId == null) return null;

    // Check cache first (unless force refresh)
    if (!forceRefresh) {
      final cached = await _cacheService.getCachedProfile(userId);
      final isValid = await _cacheService.isCacheValid();

      if (cached != null && isValid) {
        debugPrint('ProfileRepository: Cache\'den yüklendi (${cached.name})');
        return cached;
      }
    }

    // Fetch from Firestore
    try {
      debugPrint('ProfileRepository: Firestore\'dan yükleniyor...');
      final doc = await _firestore.collection('users').doc(userId).get();

      if (!doc.exists || doc.data() == null) {
        return null;
      }

      final profile = UserProfile.fromFirestore(doc);

      // Update cache
      await _cacheService.cacheProfile(profile);

      debugPrint('ProfileRepository: Firestore\'dan yüklendi ve önbelleğe alındı');
      return profile;
    } catch (e) {
      debugPrint('ProfileRepository: Firestore hatası: $e');

      // On network error, try to return cached version
      final cached = await _cacheService.getCachedProfile(userId);
      if (cached != null) {
        debugPrint('ProfileRepository: Hata sonrası cache\'den yüklendi');
        return cached;
      }

      return null;
    }
  }

  /// Stream that emits cached profile immediately, then fresh profile
  /// Perfect for UI that needs instant display + background refresh
  Stream<UserProfile?> watchCurrentUserProfile() async* {
    final userId = currentUserId;
    if (userId == null) {
      yield null;
      return;
    }

    // First, emit cached profile immediately (if exists)
    final cached = await _cacheService.getCachedProfile(userId);
    if (cached != null) {
      debugPrint('ProfileRepository: Stream - Cache emitted');
      yield cached;
    }

    // Then fetch fresh from Firestore
    try {
      final doc = await _firestore.collection('users').doc(userId).get();

      if (doc.exists && doc.data() != null) {
        final freshProfile = UserProfile.fromFirestore(doc);

        // Update cache
        await _cacheService.cacheProfile(freshProfile);

        // Only emit if different from cached
        if (cached == null || _hasProfileChanged(cached, freshProfile)) {
          debugPrint('ProfileRepository: Stream - Fresh profile emitted');
          yield freshProfile;
        } else {
          debugPrint('ProfileRepository: Stream - No changes detected');
        }
      } else if (cached == null) {
        yield null;
      }
    } catch (e) {
      debugPrint('ProfileRepository: Stream error: $e');
      // If error and no cache was emitted, emit null
      if (cached == null) {
        yield null;
      }
    }
  }

  /// Check if profile has meaningful changes
  bool _hasProfileChanged(UserProfile cached, UserProfile fresh) {
    return cached.name != fresh.name ||
        cached.bio != fresh.bio ||
        cached.age != fresh.age ||
        cached.university != fresh.university ||
        cached.department != fresh.department ||
        cached.grade != fresh.grade ||
        cached.photos.length != fresh.photos.length ||
        cached.interests.length != fresh.interests.length ||
        cached.clubs.length != fresh.clubs.length ||
        cached.intent.length != fresh.intent.length ||
        !_listEquals(cached.photos, fresh.photos);
  }

  bool _listEquals(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  /// Clear profile cache (call on logout)
  Future<void> clearProfileCache() async {
    await _cacheService.clearCache();
    debugPrint('ProfileRepository: Cache temizlendi');
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

      // Update cache with new values
      await _cacheService.updateCachedFields(updates);

      debugPrint('ProfileRepository: Profil güncellendi ve cache yenilendi');
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
