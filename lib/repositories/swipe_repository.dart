import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:internet_connection_checker_plus/internet_connection_checker_plus.dart';
import '../models/user_profile.dart';
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

  // ==================== CONNECTIVITY CHECK ====================

  /// İnternet bağlantısını kontrol et
  Future<bool> _checkInternetConnection() async {
    try {
      final hasConnection = await InternetConnection().hasInternetAccess;
      if (!hasConnection) {
        debugPrint('SwipeRepository: İnternet bağlantısı yok!');
      }
      return hasConnection;
    } catch (e) {
      debugPrint('SwipeRepository: İnternet kontrolü hatası: $e');
      return false;
    }
  }

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

  // ==================== USER FETCHING WITH FILTERS ====================

  /// Main fetch method called by provider
  Future<({List<UserProfile> profiles, DocumentSnapshot? lastDoc})>
      fetchUserBatch({
    DocumentSnapshot? lastDocument,
    String? genderFilter,
    String? filterCity,
    String? filterUniversity,
    String? filterDepartment,
    String? filterGrade,
    Set<String>? excludedIds,
  }) async {
    return await _fetchUsersWithFilter(
      lastDocument: lastDocument,
      genderFilter: genderFilter,
      filterCity: filterCity,
      filterUniversity: filterUniversity,
      filterDepartment: filterDepartment,
      filterGrade: filterGrade,
      excludedIds: excludedIds,
    );
  }

  /// Index hatası durumunda yedek: Sadece createdAt ile çek, filtreleri client-side uygula.
  Future<({List<UserProfile> profiles, DocumentSnapshot? lastDoc})> _fetchWithClientSideFilters({
    required String userId,
    required Set<String> excluded,
    required String? genderFilter,
    required String? filterCity,
    required String? filterUniversity,
    required String? filterDepartment,
    required String? filterGrade,
    required int fetchBatchSize,
  }) async {
    try {
      final q = _usersCollection
          .orderBy('createdAt', descending: true)
          .limit(80);

      final snapshot = await q.get();
      final list = snapshot.docs
          .map((doc) => UserProfile.fromFirestore(doc))
          .where((p) {
        if (!p.isComplete || p.id == userId || excluded.contains(p.id)) return false;
        if (genderFilter != null && genderFilter.isNotEmpty && genderFilter != 'Herkes') {
          if (p.gender != genderFilter) return false;
        }
        if (filterCity != null && filterCity.isNotEmpty) {
          if (p.universityCity != filterCity) return false;
        }
        if (filterUniversity != null && filterUniversity.isNotEmpty) {
          if (p.university != filterUniversity) return false;
        }
        if (filterDepartment != null && filterDepartment.isNotEmpty) {
          if (p.department != filterDepartment) return false;
        }
        if (filterGrade != null && filterGrade.isNotEmpty) {
          if (p.grade != filterGrade) return false;
        }
        return true;
      })
          .take(fetchBatchSize)
          .toList();

      debugPrint('─────────────────────────────────────');
      return (profiles: list, lastDoc: null);
    } catch (e) {
      debugPrint('⚠️ Yedek sorgu da başarısız: $e');
      return (profiles: <UserProfile>[], lastDoc: null);
    }
  }

  /// Smart Filter System with Waterfall Priority
  /// 
  /// MANTIK:
  /// 1. Eğer HERHANGI BİR premium filtre aktifse (city, university, department, grade):
  ///    → Waterfall algoritmasını ATLA, sadece filtrelere göre getir
  /// 2. Eğer SADECE gender filtresi varsa:
  ///    → Waterfall algoritmasını ÇALIŞTIR (normal akış)
  Future<({List<UserProfile> profiles, DocumentSnapshot? lastDoc})>
      _fetchUsersWithFilter({
    DocumentSnapshot? lastDocument,
    String? genderFilter,
    String? filterCity,
    String? filterUniversity,
    String? filterDepartment,
    String? filterGrade,
    Set<String>? excludedIds,
  }) async {
    final userId = currentUserId;
    if (userId == null) return (profiles: <UserProfile>[], lastDoc: null);
    
    // excludedIds boşsa boş set kullan
    final excluded = excludedIds ?? <String>{};

    // ============ ADIM 0: PREMIUM FİLTRE KONTROLÜ ============
    final hasPremiumFilters =
        (filterCity != null && filterCity.isNotEmpty) ||
            (filterUniversity != null && filterUniversity.isNotEmpty) ||
            (filterDepartment != null && filterDepartment.isNotEmpty) ||
            (filterGrade != null && filterGrade.isNotEmpty);

    if (hasPremiumFilters) {
      // ========== PREMIUM FİLTRE MODU: WATERFALL ATLA ==========
      debugPrint('═════════════════════════════════════');
      debugPrint('🔍 Premium Filtre Modu Aktif!');
      debugPrint('🚫 Waterfall algoritması devre dışı');
      debugPrint('📍 Filtreler:');
      if (filterCity != null) debugPrint('   - İl: $filterCity');
      if (filterUniversity != null) {
        debugPrint('   - Üniversite: $filterUniversity');
      }
      if (filterDepartment != null) debugPrint('   - Bölüm: $filterDepartment');
      if (filterGrade != null) debugPrint('   - Sınıf: $filterGrade');
      if (genderFilter != null && genderFilter != 'Herkes') {
        debugPrint('   - Cinsiyet: $genderFilter');
      }

      Query<Map<String, dynamic>> query = _usersCollection
          .orderBy('createdAt', descending: true)
          .limit(fetchBatchSize);

      // Gender filtresi (FREE)
      if (genderFilter != null &&
          genderFilter.isNotEmpty &&
          genderFilter != 'Herkes') {
        query = query.where('gender', isEqualTo: genderFilter);
      }

      // İl filtresi (universityCity alanı!)
      if (filterCity != null && filterCity.isNotEmpty) {
        query = query.where('universityCity', isEqualTo: filterCity);
      }

      // Üniversite filtresi
      if (filterUniversity != null && filterUniversity.isNotEmpty) {
        query = query.where('university', isEqualTo: filterUniversity);
      }

      // Bölüm filtresi
      if (filterDepartment != null && filterDepartment.isNotEmpty) {
        query = query.where('department', isEqualTo: filterDepartment);
      }

      // Sınıf filtresi
      if (filterGrade != null && filterGrade.isNotEmpty) {
        query = query.where('grade', isEqualTo: filterGrade);
      }

      // 🎯 OPTİMİZASYON: Son 10 excluded ID'yi SERVER-SIDE filtrele (whereNotIn)
      final recentExcluded = excluded.take(10).toList();
      if (recentExcluded.isNotEmpty) {
        query = query.where(FieldPath.documentId, whereNotIn: recentExcluded);
        debugPrint('🚀 whereNotIn optimizasyonu: ${recentExcluded.length} ID server-side elendi');
      }

      // Pagination
      if (lastDocument != null) {
        query = query.startAfterDocument(lastDocument);
      }

      try {
        final snapshot = await query.get();
        // Geri kalan excluded ID'leri client-side filtrele
        final profiles = snapshot.docs
            .map((doc) => UserProfile.fromFirestore(doc))
            .where((profile) => 
              profile.isComplete && 
              profile.id != userId &&
              !excluded.contains(profile.id))  // ← Geri kalanlar client-side eleniyor
            .toList();

        final lastDoc = snapshot.docs.isNotEmpty ? snapshot.docs.last : null;

        debugPrint('✅ Filtrelenmiş sonuç: ${profiles.length} profil bulundu (Server: ${recentExcluded.length}, Client: ${excluded.length - recentExcluded.length} kişi elendi)');
        debugPrint('─────────────────────────────────────');

        return (profiles: profiles, lastDoc: lastDoc);
      } catch (e) {
        debugPrint(
            '⚠️ Filtre sorgusu hatası (composite index gerekli olabilir): $e');
        // Yedek: Sadece createdAt ile çek, tüm filtreleri client-side uygula
        final fallback = await _fetchWithClientSideFilters(
          userId: userId,
          excluded: excluded,
          genderFilter: genderFilter,
          filterCity: filterCity,
          filterUniversity: filterUniversity,
          filterDepartment: filterDepartment,
          filterGrade: filterGrade,
          fetchBatchSize: fetchBatchSize,
        );
        if (fallback.profiles.isNotEmpty) {
          debugPrint('✅ Yedek sorgu (client-side filtre): ${fallback.profiles.length} profil bulundu');
        }
        return fallback;
      }
    }

    // ========== WATERFALL MODU: NORMAL AKIŞ (SADECE GENDER FİLTRESİ) ==========
    debugPrint('═════════════════════════════════════');
    debugPrint('🌊 Waterfall Algoritması Aktif');
    if (genderFilter != null && genderFilter != 'Herkes') {
      debugPrint('👥 Gender Filtresi: $genderFilter');
    }

    // 🔍 Önce current user'ın universityCity'sini al
    final currentUserDoc = await _usersCollection.doc(userId).get();
    final currentUserCity =
        currentUserDoc.data()?['universityCity'] as String?;
    debugPrint('📍 Current User City: $currentUserCity');

    List<UserProfile> allProfiles = [];
    DocumentSnapshot? finalLastDoc;

    // ============ ADIM 1: YEREL SORGU (Aynı Şehir) ============
    if (currentUserCity != null && currentUserCity.isNotEmpty) {
      debugPrint('🏙️ Yerel sorgu başlatılıyor: $currentUserCity');

      Query<Map<String, dynamic>> localQuery = _usersCollection
          .orderBy('createdAt', descending: true)
          .limit(fetchBatchSize);

      // universityCity filtresi ekle
      localQuery =
          localQuery.where('universityCity', isEqualTo: currentUserCity);

      // Gender filtresi
      if (genderFilter != null &&
          genderFilter.isNotEmpty &&
          genderFilter != 'Herkes') {
        localQuery = localQuery.where('gender', isEqualTo: genderFilter);
      }

      // 🎯 OPTİMİZASYON: Son 10 excluded ID'yi SERVER-SIDE filtrele (whereNotIn)
      final recentExcluded = excluded.take(10).toList();
      if (recentExcluded.isNotEmpty) {
        localQuery = localQuery.where(FieldPath.documentId, whereNotIn: recentExcluded);
      }

      // Pagination
      if (lastDocument != null) {
        localQuery = localQuery.startAfterDocument(lastDocument);
      }

      final localSnapshot = await localQuery.get();
      // Geri kalan excluded ID'leri client-side filtrele
      final localProfiles = localSnapshot.docs
          .map((doc) => UserProfile.fromFirestore(doc))
          .where((profile) => 
            profile.isComplete && 
            profile.id != userId &&
            !excluded.contains(profile.id))
          .toList();

      allProfiles.addAll(localProfiles);
      finalLastDoc =
          localSnapshot.docs.isNotEmpty ? localSnapshot.docs.last : null;

      debugPrint('✅ Yerel sorgu: ${localProfiles.length} profil bulundu (Server: ${recentExcluded.length}, Client: ${excluded.length - recentExcluded.length} elendi)');
      debugPrint('📊 Hedef: $fetchBatchSize, Mevcut: ${allProfiles.length}');
    }

    // ============ ADIM 2: YEREL YETMEDI Mİ? GENEL HAVUZA GEÇ ============
    if (allProfiles.length < fetchBatchSize) {
      final remaining = fetchBatchSize - allProfiles.length;
      debugPrint(
          '🌍 Yerel havuz yetmedi! Genel havuzdan $remaining profil çekiliyor...');

      Query<Map<String, dynamic>> generalQuery = _usersCollection
          .orderBy('createdAt', descending: true)
          .limit(remaining);

      // universityCity farklı olanları getir
      if (currentUserCity != null && currentUserCity.isNotEmpty) {
        generalQuery =
            generalQuery.where('universityCity', isNotEqualTo: currentUserCity);
      }

      // Gender filtresi
      if (genderFilter != null &&
          genderFilter.isNotEmpty &&
          genderFilter != 'Herkes') {
        generalQuery = generalQuery.where('gender', isEqualTo: genderFilter);
      }

      // ⚠️ NOT: Genel sorguda isNotEqualTo kullanıldığı için whereNotIn eklenemez (Firestore kısıtlaması)
      // Bu yüzden diğer excluded ID'ler client-side filtreleniyor

      try {
        final generalSnapshot = await generalQuery.get();
        final allFromGeneral = generalSnapshot.docs
            .map((doc) => UserProfile.fromFirestore(doc))
            .where((p) => p.isComplete && p.id != userId)
            .toList();
        // excludedIds'te olanları ele (kendi ID veya daha önce aksiyon alınanlar)
        final eliminated = allFromGeneral.where((p) => excluded.contains(p.id)).toList();
        final generalProfiles = allFromGeneral.where((p) => !excluded.contains(p.id)).toList();
        if (eliminated.isNotEmpty) {
          for (final p in eliminated) {
            debugPrint('   🚫 Genel havuzdan elenen: ${p.id} (${p.name}) ${p.id == userId ? "- KENDİ PROFİLİM" : "- excludedIds\'te"}');
          }
        }

        allProfiles.addAll(generalProfiles);

        if (generalSnapshot.docs.isNotEmpty) {
          finalLastDoc = generalSnapshot.docs.last;
        }

        debugPrint('✅ Genel sorgu: ${generalProfiles.length} profil bulundu (Server: ${generalSnapshot.docs.length} doc, elenen: ${eliminated.length}, excludedIds: ${excluded.length})');
      } catch (e) {
        debugPrint('⚠️ Genel sorgu hatası: $e');
      }
    }

    // ============ ADIM 3: FALLBACK: universityCity null/boş kullanıcılar (genel 0 döndüyse) ============
    // Firestore'da universityCity null olanlar isNotEqualTo('İstanbul') ile gelmez; bu yüzden ayrı çekiyoruz
    if (allProfiles.isEmpty && lastDocument == null) {
      try {
        debugPrint('📍 Genel havuz 0 döndü; universityCity null/boş kullanıcılar deneniyor...');
        final nullCityQuery = _usersCollection
            .orderBy('createdAt', descending: true)
            .limit(50);
        final nullCitySnapshot = await nullCityQuery.get();
        final nullCityProfiles = nullCitySnapshot.docs
            .map((doc) => UserProfile.fromFirestore(doc))
            .where((p) {
              if (!p.isComplete || p.id == userId || excluded.contains(p.id)) return false;
              if (p.universityCity != null && p.universityCity!.isNotEmpty) return false;
              // Cinsiyet filtresi: Kadın/Erkek seçiliyse sadece o cinsiyet
              if (genderFilter != null && genderFilter.isNotEmpty && genderFilter != 'Herkes') {
                if (p.gender != genderFilter) return false;
              }
              return true;
            })
            .take(fetchBatchSize)
            .toList();
        allProfiles.addAll(nullCityProfiles);
        if (nullCityProfiles.isNotEmpty) {
          if (nullCitySnapshot.docs.isNotEmpty) {
            finalLastDoc = nullCitySnapshot.docs.last;
          }
          debugPrint('✅ universityCity null/boş: ${nullCityProfiles.length} profil eklendi');
        }
      } catch (e) {
        debugPrint('⚠️ universityCity null fallback hatası: $e');
      }
    }

    debugPrint('🎯 Toplam döndürülen: ${allProfiles.length} profil');
    debugPrint('─────────────────────────────────────');

    return (profiles: allProfiles, lastDoc: finalLastDoc);
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

    // İnternet bağlantısı kontrolü
    if (!await _checkInternetConnection()) {
      debugPrint(
          'SwipeRepository: İnternet bağlantısı yok - swipe kaydedilemedi');
      throw const SocketException('İnternet bağlantısı yok');
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
      // Check if target user has already liked current user
      final reverseActionId = SwipeAction.generateId(targetUserId, userId);
      final reverseAction =
          await _actionsCollection.doc(reverseActionId).get();

      if (reverseAction.exists) {
        final actionType = reverseAction.data()?['type'] as String?;
        if (actionType == SwipeActionType.like.name ||
            actionType == SwipeActionType.superlike.name) {
          // MUTUAL MATCH! Create match document
          await _createMatch(userId, targetUserId);

          return true;
        }
      }

      return false;
    } catch (e) {
      return false;
    }
  }

  /// Create a match document when BOTH users have liked each other
  Future<void> _createMatch(String userId, String targetUserId) async {
    try {
      // Use consistent match ID (sorted user IDs)
      final matchId = SwipeAction.generateId(userId, targetUserId);

      await _matchesCollection.doc(matchId).set({
        'users': [userId, targetUserId],
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      // Log error but don't throw - match creation failure shouldn't break flow
      debugPrint('Error creating match: $e');
    }
  }

  /// Undo last swipe by deleting action document
  Future<void> undoLastSwipe(String targetUserId) async {
    final userId = currentUserId;
    if (userId == null) return;

    try {
      final actionId = SwipeAction.generateId(userId, targetUserId);
      await _actionsCollection.doc(actionId).delete();
    } catch (e) {
      // Silently fail - undo is optional
    }
  }

  /// Get user's looking for preference (for gender filtering)
  Future<String?> getUserLookingForPreference() async {
    final userId = currentUserId;
    if (userId == null) return null;

    try {
      final userDoc = await _usersCollection.doc(userId).get();
      if (userDoc.exists) {
        return userDoc.data()?['lookingFor'] as String?;
      }
      return null;
    } catch (e) {
      debugPrint('Error getting user lookingFor: $e');
      return null;
    }
  }

  /// Watch matches for current user (for realtime updates)
  Stream<List<Match>> watchMatches() {
    final userId = currentUserId;
    if (userId == null) {
      return Stream.value([]);
    }

    return _matchesCollection
        .where('users', arrayContains: userId)
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => Match.fromFirestore(doc))
          .toList();
    });
  }
}
