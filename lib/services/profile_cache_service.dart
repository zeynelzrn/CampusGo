import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_profile.dart';

/// Service for caching current user's profile in SharedPreferences
/// This enables instant profile display on app startup (Cache-First strategy)
class ProfileCacheService {
  static const String _profileKey = 'cached_user_profile';
  static const String _cacheTimestampKey = 'cached_profile_timestamp';
  static const String _userIdKey = 'cached_profile_user_id';

  /// Cache validity duration (24 hours)
  /// Profile is still shown from cache, but background refresh is triggered
  static const Duration _cacheValidityDuration = Duration(hours: 24);

  static ProfileCacheService? _instance;
  SharedPreferences? _prefs;

  ProfileCacheService._();

  /// Singleton instance
  static ProfileCacheService get instance {
    _instance ??= ProfileCacheService._();
    return _instance!;
  }

  /// Initialize SharedPreferences
  Future<void> _ensureInitialized() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  /// Save user profile to cache
  /// Call this after successful Firestore fetch or profile update
  Future<void> cacheProfile(UserProfile profile) async {
    try {
      await _ensureInitialized();

      final jsonString = jsonEncode(profile.toJson());
      final timestamp = DateTime.now().toIso8601String();

      await Future.wait([
        _prefs!.setString(_profileKey, jsonString),
        _prefs!.setString(_cacheTimestampKey, timestamp),
        _prefs!.setString(_userIdKey, profile.id),
      ]);

      debugPrint('ProfileCache: Profil önbelleğe alındı (${profile.name})');
    } catch (e) {
      debugPrint('ProfileCache: Önbelleğe alma hatası: $e');
    }
  }

  /// Get cached profile (if exists and belongs to current user)
  /// Returns null if no cache or cache belongs to different user
  Future<UserProfile?> getCachedProfile(String currentUserId) async {
    try {
      await _ensureInitialized();

      final cachedUserId = _prefs!.getString(_userIdKey);

      // Check if cache belongs to current user
      if (cachedUserId != currentUserId) {
        debugPrint('ProfileCache: Farklı kullanıcı - cache geçersiz');
        await clearCache();
        return null;
      }

      final jsonString = _prefs!.getString(_profileKey);
      if (jsonString == null) {
        debugPrint('ProfileCache: Cache bulunamadı');
        return null;
      }

      final json = jsonDecode(jsonString) as Map<String, dynamic>;
      final profile = UserProfile.fromJson(json);

      debugPrint('ProfileCache: Profil cache\'den yüklendi (${profile.name})');
      return profile;
    } catch (e) {
      debugPrint('ProfileCache: Cache okuma hatası: $e');
      return null;
    }
  }

  /// Check if cache is still valid (not expired)
  Future<bool> isCacheValid() async {
    try {
      await _ensureInitialized();

      final timestampStr = _prefs!.getString(_cacheTimestampKey);
      if (timestampStr == null) return false;

      final cacheTime = DateTime.tryParse(timestampStr);
      if (cacheTime == null) return false;

      final isValid = DateTime.now().difference(cacheTime) < _cacheValidityDuration;
      debugPrint('ProfileCache: Cache geçerlilik: $isValid');
      return isValid;
    } catch (e) {
      return false;
    }
  }

  /// Get cache age in minutes (for debugging)
  Future<int?> getCacheAgeMinutes() async {
    try {
      await _ensureInitialized();

      final timestampStr = _prefs!.getString(_cacheTimestampKey);
      if (timestampStr == null) return null;

      final cacheTime = DateTime.tryParse(timestampStr);
      if (cacheTime == null) return null;

      return DateTime.now().difference(cacheTime).inMinutes;
    } catch (e) {
      return null;
    }
  }

  /// Clear cached profile
  /// Call this on logout or when profile needs to be refreshed
  Future<void> clearCache() async {
    try {
      await _ensureInitialized();

      await Future.wait([
        _prefs!.remove(_profileKey),
        _prefs!.remove(_cacheTimestampKey),
        _prefs!.remove(_userIdKey),
      ]);

      debugPrint('ProfileCache: Önbellek temizlendi');
    } catch (e) {
      debugPrint('ProfileCache: Önbellek temizleme hatası: $e');
    }
  }

  /// Update specific fields in cached profile (partial update)
  /// Useful when only some fields change (like bio or interests)
  Future<void> updateCachedFields(Map<String, dynamic> updates) async {
    try {
      await _ensureInitialized();

      final jsonString = _prefs!.getString(_profileKey);
      if (jsonString == null) return;

      final json = jsonDecode(jsonString) as Map<String, dynamic>;

      // Merge updates
      json.addAll(updates);

      // Save updated profile
      await _prefs!.setString(_profileKey, jsonEncode(json));
      await _prefs!.setString(_cacheTimestampKey, DateTime.now().toIso8601String());

      debugPrint('ProfileCache: Cache güncellendi (${updates.keys.join(', ')})');
    } catch (e) {
      debugPrint('ProfileCache: Cache güncelleme hatası: $e');
    }
  }

  /// Check if any cache exists (regardless of validity)
  Future<bool> hasCache() async {
    try {
      await _ensureInitialized();
      return _prefs!.containsKey(_profileKey);
    } catch (e) {
      return false;
    }
  }
}
