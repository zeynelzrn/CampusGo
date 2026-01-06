import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';

/// Service for user-related operations like blocking and reporting
class UserService {
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;
  final FirebaseStorage _storage;

  UserService({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
    FirebaseStorage? storage,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance,
        _storage = storage ?? FirebaseStorage.instance;

  /// Get current user ID
  String? get currentUserId => _auth.currentUser?.uid;

  /// Collection references
  CollectionReference<Map<String, dynamic>> get _usersCollection =>
      _firestore.collection('users');

  CollectionReference<Map<String, dynamic>> get _reportsCollection =>
      _firestore.collection('reports');

  CollectionReference<Map<String, dynamic>> get _chatsCollection =>
      _firestore.collection('chats');

  // ==================== BLOCK OPERATIONS ====================

  /// Block a user
  /// Adds the target user to the current user's blocked_users subcollection
  /// Also archives any existing chat with the blocked user
  Future<bool> blockUser(String targetUserId) async {
    final currentUid = currentUserId;

    debugPrint('========== BLOCK USER START ==========');
    debugPrint('Current User ID: $currentUid');
    debugPrint('Target User ID: $targetUserId');

    if (currentUid == null) {
      debugPrint('ERROR: User not logged in - currentUserId is null');
      debugPrint('Auth state: ${_auth.currentUser}');
      return false;
    }

    if (currentUid == targetUserId) {
      debugPrint('ERROR: Cannot block yourself');
      return false;
    }

    try {
      // Method 1: Direct writes (more reliable than batch for debugging)
      debugPrint('Writing to: users/$currentUid/blocked_users/$targetUserId');

      // 1. Add to blocked_users subcollection - DIRECT WRITE
      await _firestore
          .collection('users')
          .doc(currentUid)
          .collection('blocked_users')
          .doc(targetUserId)
          .set({
        'blockedAt': FieldValue.serverTimestamp(),
        'userId': targetUserId,
        'blockedBy': currentUid,
      });
      debugPrint('SUCCESS: Written to blocked_users');

      // 2. Add reverse block - DIRECT WRITE
      debugPrint('Writing to: users/$targetUserId/blocked_by/$currentUid');
      await _firestore
          .collection('users')
          .doc(targetUserId)
          .collection('blocked_by')
          .doc(currentUid)
          .set({
        'blockedAt': FieldValue.serverTimestamp(),
        'userId': currentUid,
        'blockedBy': currentUid,
      });
      debugPrint('SUCCESS: Written to blocked_by');

      // 3. Archive existing chat (if any)
      final chatId = _generateChatId(currentUid, targetUserId);
      debugPrint('Checking chat: $chatId');

      final chatDoc = await _chatsCollection.doc(chatId).get();
      if (chatDoc.exists) {
        debugPrint('Chat exists, archiving...');
        await _chatsCollection.doc(chatId).update({
          'isArchived': true,
          'archivedBy': FieldValue.arrayUnion([currentUid]),
          'archivedAt': FieldValue.serverTimestamp(),
          'blockedBy': currentUid,
        });
        debugPrint('SUCCESS: Chat archived');
      } else {
        debugPrint('No existing chat found');
      }

      // 4. Verify the write
      final verifyDoc = await _firestore
          .collection('users')
          .doc(currentUid)
          .collection('blocked_users')
          .doc(targetUserId)
          .get();

      if (verifyDoc.exists) {
        debugPrint('VERIFIED: Block record exists in Firestore');
        debugPrint('Data: ${verifyDoc.data()}');
      } else {
        debugPrint('WARNING: Block record NOT found after write!');
      }

      debugPrint('========== BLOCK USER SUCCESS ==========');
      return true;
    } catch (e, stackTrace) {
      debugPrint('========== BLOCK USER ERROR ==========');
      debugPrint('Error Type: ${e.runtimeType}');
      debugPrint('Error Message: $e');
      debugPrint('Stack Trace: $stackTrace');

      // Check for specific error types
      final errorStr = e.toString();
      if (errorStr.contains('PERMISSION_DENIED') || errorStr.contains('permission')) {
        debugPrint('>>> PERMISSION DENIED! Check Firestore Security Rules <<<');
        debugPrint('Required rule: allow write on users/{userId}/blocked_users/{blockedId}');
      }
      if (errorStr.contains('NOT_FOUND')) {
        debugPrint('>>> DOCUMENT NOT FOUND! User document may not exist <<<');
      }
      debugPrint('=======================================');
      return false;
    }
  }

  /// Unblock a user
  Future<bool> unblockUser(String targetUserId) async {
    final currentUid = currentUserId;
    if (currentUid == null) return false;

    try {
      final batch = _firestore.batch();

      // Remove from blocked_users
      final blockedRef = _usersCollection
          .doc(currentUid)
          .collection('blocked_users')
          .doc(targetUserId);
      batch.delete(blockedRef);

      // Remove reverse block
      final reverseBlockRef = _usersCollection
          .doc(targetUserId)
          .collection('blocked_by')
          .doc(currentUid);
      batch.delete(reverseBlockRef);

      await batch.commit();
      debugPrint('UserService: Successfully unblocked user $targetUserId');
      return true;
    } catch (e) {
      debugPrint('UserService: Error unblocking user: $e');
      return false;
    }
  }

  /// Check if a user is blocked
  Future<bool> isUserBlocked(String targetUserId) async {
    final currentUid = currentUserId;
    if (currentUid == null) return false;

    try {
      final doc = await _usersCollection
          .doc(currentUid)
          .collection('blocked_users')
          .doc(targetUserId)
          .get();

      return doc.exists;
    } catch (e) {
      debugPrint('UserService: Error checking block status: $e');
      return false;
    }
  }

  /// Get list of blocked user IDs
  Future<List<String>> getBlockedUserIds() async {
    final currentUid = currentUserId;
    if (currentUid == null) return [];

    try {
      final snapshot = await _usersCollection
          .doc(currentUid)
          .collection('blocked_users')
          .get();

      return snapshot.docs.map((doc) => doc.id).toList();
    } catch (e) {
      debugPrint('UserService: Error getting blocked users: $e');
      return [];
    }
  }

  /// Stream blocked user IDs for real-time updates
  Stream<List<String>> watchBlockedUserIds() {
    final currentUid = currentUserId;
    if (currentUid == null) return Stream.value([]);

    return _usersCollection
        .doc(currentUid)
        .collection('blocked_users')
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => doc.id).toList());
  }

  // ==================== MUTUAL INVISIBILITY (BLACKLIST) ====================

  /// Get list of user IDs who blocked the current user (blocked_by)
  Future<List<String>> getBlockedByUserIds() async {
    final currentUid = currentUserId;
    if (currentUid == null) return [];

    try {
      final snapshot = await _usersCollection
          .doc(currentUid)
          .collection('blocked_by')
          .get();

      final ids = snapshot.docs.map((doc) => doc.id).toList();
      debugPrint('UserService: Found ${ids.length} users who blocked me');
      return ids;
    } catch (e) {
      debugPrint('UserService: Error getting blocked_by users: $e');
      return [];
    }
  }

  /// Stream user IDs who blocked the current user (blocked_by) for real-time updates
  Stream<List<String>> watchBlockedByUserIds() {
    final currentUid = currentUserId;
    if (currentUid == null) return Stream.value([]);

    return _usersCollection
        .doc(currentUid)
        .collection('blocked_by')
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => doc.id).toList());
  }

  /// Get ALL restricted user IDs (BLACKLIST)
  /// Combines: blocked_users (I blocked them) + blocked_by (they blocked me)
  /// Any user in this list should be INVISIBLE to current user
  Future<Set<String>> getAllRestrictedUserIds() async {
    final currentUid = currentUserId;
    if (currentUid == null) return {};

    try {
      debugPrint('========== FETCHING BLACKLIST ==========');

      // Fetch both lists in parallel
      final results = await Future.wait([
        getBlockedUserIds(),    // Users I blocked
        getBlockedByUserIds(),  // Users who blocked me
      ]);

      final blockedUsers = results[0];
      final blockedByUsers = results[1];

      // Combine into single set
      final allRestricted = <String>{
        ...blockedUsers,
        ...blockedByUsers,
      };

      debugPrint('Blocked by me: ${blockedUsers.length} users');
      debugPrint('Blocked me: ${blockedByUsers.length} users');
      debugPrint('Total BLACKLIST: ${allRestricted.length} users');
      debugPrint('IDs: $allRestricted');
      debugPrint('==========================================');

      return allRestricted;
    } catch (e) {
      debugPrint('UserService: Error getting restricted users: $e');
      return {};
    }
  }

  /// Stream ALL restricted user IDs for real-time updates
  /// Used for live filtering in UI (Combines blocked_users + blocked_by)
  Stream<Set<String>> watchAllRestrictedUserIds() {
    final currentUid = currentUserId;
    if (currentUid == null) return Stream.value({});

    // Watch blocked_users and combine with blocked_by on each update
    return watchBlockedUserIds().asyncMap((blockedUsers) async {
      // Get blocked_by users when blocked_users changes
      final blockedByUsers = await getBlockedByUserIds();
      return <String>{...blockedUsers, ...blockedByUsers};
    });
  }

  /// Check if a specific user has blocked the current user
  Future<bool> isBlockedByUser(String targetUserId) async {
    final currentUid = currentUserId;
    if (currentUid == null) return false;

    try {
      final doc = await _usersCollection
          .doc(currentUid)
          .collection('blocked_by')
          .doc(targetUserId)
          .get();

      final isBlocked = doc.exists;
      debugPrint('UserService: Am I blocked by $targetUserId? $isBlocked');
      return isBlocked;
    } catch (e) {
      debugPrint('UserService: Error checking blocked_by status: $e');
      return false;
    }
  }

  /// Check if there is ANY block relationship between current user and target
  /// Returns true if EITHER user blocked the other
  Future<bool> hasBlockRelationship(String targetUserId) async {
    final currentUid = currentUserId;
    if (currentUid == null) return false;

    try {
      final results = await Future.wait([
        isUserBlocked(targetUserId),   // Did I block them?
        isBlockedByUser(targetUserId), // Did they block me?
      ]);

      final iBlocked = results[0];
      final theyBlockedMe = results[1];

      debugPrint('Block relationship with $targetUserId: I blocked=$iBlocked, They blocked me=$theyBlockedMe');
      return iBlocked || theyBlockedMe;
    } catch (e) {
      debugPrint('UserService: Error checking block relationship: $e');
      return false;
    }
  }

  // ==================== REPORT OPERATIONS ====================

  /// Report reasons for App Store compliance
  static const List<ReportReason> reportReasons = [
    ReportReason(
      id: 'harassment',
      label: 'Rahatsiz edici mesajlar / Taciz',
      icon: 'warning',
    ),
    ReportReason(
      id: 'fake_profile',
      label: 'Sahte Profil / Spam',
      icon: 'person_off',
    ),
    ReportReason(
      id: 'inappropriate_content',
      label: 'Uygunsuz Icerik / Fotograf',
      icon: 'image_not_supported',
    ),
    ReportReason(
      id: 'underage',
      label: 'Reşit olmayan kullanici',
      icon: 'child_care',
    ),
    ReportReason(
      id: 'scam',
      label: 'Dolandiricilik',
      icon: 'money_off',
    ),
    ReportReason(
      id: 'other',
      label: 'Diger',
      icon: 'more_horiz',
    ),
  ];

  /// Report a user
  /// Creates a report document in the reports collection
  Future<bool> reportUser({
    required String targetUserId,
    required String reason,
    String? description,
    String? chatId,
  }) async {
    final currentUid = currentUserId;
    if (currentUid == null) {
      debugPrint('UserService: User not logged in');
      return false;
    }

    if (currentUid == targetUserId) {
      debugPrint('UserService: Cannot report yourself');
      return false;
    }

    try {
      // Create report document
      await _reportsCollection.add({
        'reporterId': currentUid,
        'reportedId': targetUserId,
        'reason': reason,
        'description': description ?? '',
        'chatId': chatId,
        'timestamp': FieldValue.serverTimestamp(),
        'status': 'pending', // pending, reviewed, resolved, dismissed
        'reviewedAt': null,
        'reviewedBy': null,
        'action': null, // warning, suspension, ban, none
      });

      debugPrint('UserService: Successfully reported user $targetUserId');
      return true;
    } catch (e) {
      debugPrint('UserService: Error reporting user: $e');
      return false;
    }
  }

  /// Check if user has already reported this target
  Future<bool> hasAlreadyReported(String targetUserId) async {
    final currentUid = currentUserId;
    if (currentUid == null) return false;

    try {
      final snapshot = await _reportsCollection
          .where('reporterId', isEqualTo: currentUid)
          .where('reportedId', isEqualTo: targetUserId)
          .limit(1)
          .get();

      return snapshot.docs.isNotEmpty;
    } catch (e) {
      debugPrint('UserService: Error checking report status: $e');
      return false;
    }
  }

  // ==================== ACCOUNT DELETION (HARD DELETE) ====================

  /// Kullanıcının TÜM verilerini siler (Deep Clean / Hard Delete)
  ///
  /// SIRALAMA KRİTİK: Auth yetkisi kaybolmadan önce tüm veriler temizlenmeli!
  ///
  /// Adım 1: Storage Temizliği (user_photos/{userId}/)
  /// Adım 2: Firestore İlişkisel Veri Temizliği:
  ///   - matches (users array contains userId)
  ///   - chats + messages subcollection
  ///   - actions (fromUserId veya toUserId)
  ///   - reports (reporterId veya reportedId)
  ///   - user profile + subcollections
  ///
  /// NOT: Bu fonksiyon Firebase Auth hesabını SİLMEZ.
  /// Auth silme işlemi AuthService.deleteAccountWithData() içinde yapılır.
  Future<Map<String, dynamic>> deleteUserEntireData(String userId) async {
    debugPrint('');
    debugPrint('╔══════════════════════════════════════════════════════════╗');
    debugPrint('║           HARD DELETE - DEEP CLEAN START                 ║');
    debugPrint('╠══════════════════════════════════════════════════════════╣');
    debugPrint('║  User ID: $userId');
    debugPrint('╚══════════════════════════════════════════════════════════╝');

    // Silme istatistikleri
    final stats = _DeleteStats();

    // ════════════════════════════════════════════════════════════
    // ADIM 1: STORAGE TEMİZLİĞİ (ÖNCELİKLİ)
    // ════════════════════════════════════════════════════════════
    debugPrint('\n┌─ ADIM 1: Storage Temizliği');
    await _cleanupStorage(userId, stats);

    // ════════════════════════════════════════════════════════════
    // ADIM 2: FİRESTORE İLİŞKİSEL VERİ TEMİZLİĞİ
    // ════════════════════════════════════════════════════════════
    debugPrint('\n┌─ ADIM 2: Firestore İlişkisel Veri Temizliği');

    // Paralel silme için Future listesi
    await Future.wait([
      _cleanupMatches(userId, stats),
      _cleanupActions(userId, stats),
      _cleanupReports(userId, stats),
    ]);

    // Chats ayrı çünkü subcollection (messages) silmesi gerekiyor
    await _cleanupChatsWithMessages(userId, stats);

    // ════════════════════════════════════════════════════════════
    // ADIM 3: KULLANICI PROFİLİ VE ALT KOLEKSİYONLAR
    // ════════════════════════════════════════════════════════════
    debugPrint('\n┌─ ADIM 3: Kullanıcı Profili Temizliği');
    await _cleanupUserProfile(userId, stats);

    // ════════════════════════════════════════════════════════════
    // SONUÇ RAPORU
    // ════════════════════════════════════════════════════════════
    debugPrint('\n╔══════════════════════════════════════════════════════════╗');
    debugPrint('║           HARD DELETE - SONUÇ RAPORU                     ║');
    debugPrint('╠══════════════════════════════════════════════════════════╣');
    debugPrint('║  📸 Fotoğraflar:     ${stats.photos.toString().padLeft(5)}                            ║');
    debugPrint('║  💕 Eşleşmeler:      ${stats.matches.toString().padLeft(5)}                            ║');
    debugPrint('║  💬 Sohbetler:       ${stats.chats.toString().padLeft(5)}                            ║');
    debugPrint('║  📝 Mesajlar:        ${stats.messages.toString().padLeft(5)}                            ║');
    debugPrint('║  👆 Aksiyonlar:      ${stats.actions.toString().padLeft(5)}                            ║');
    debugPrint('║  🚨 Raporlar:        ${stats.reports.toString().padLeft(5)}                            ║');
    debugPrint('║  👤 Alt Koleksiyon:  ${stats.subcollections.toString().padLeft(5)}                            ║');
    debugPrint('║  ✅ Profil Silindi:  ${stats.userDocDeleted ? 'EVET ' : 'HAYIR'}                            ║');
    debugPrint('║  ⚠️  Hatalar:        ${stats.errors.toString().padLeft(5)}                            ║');
    debugPrint('╚══════════════════════════════════════════════════════════╝');
    debugPrint('');

    return {
      'success': stats.errors == 0,
      'deletedPhotos': stats.photos,
      'deletedMatches': stats.matches,
      'deletedChats': stats.chats,
      'deletedMessages': stats.messages,
      'deletedActions': stats.actions,
      'deletedReports': stats.reports,
      'deletedSubcollections': stats.subcollections,
      'userDocDeleted': stats.userDocDeleted,
      'errors': stats.errors,
    };
  }

  /// Storage temizliği - TÜM OLASI KLASÖRLER
  /// FAIL-SAFE: Hem yeni hem eski klasör yapısını kontrol eder
  ///
  /// Kontrol Edilen Yollar:
  /// - user_photos/{userId}/     (Yeni yapı)
  /// - profile_images/{userId}/  (Eski yapı - Geriye dönük uyumluluk)
  Future<void> _cleanupStorage(String userId, _DeleteStats stats) async {
    debugPrint('│');
    debugPrint('│  ┌─────────────────────────────────────────────');
    debugPrint('│  │ STORAGE TEMİZLİĞİ BAŞLIYOR');
    debugPrint('│  │ User ID: $userId');
    debugPrint('│  │ Kontrol edilecek klasörler:');
    debugPrint('│  │   1. user_photos/$userId (YENİ)');
    debugPrint('│  │   2. profile_images/$userId (ESKİ)');
    debugPrint('│  └─────────────────────────────────────────────');

    // Kontrol edilecek tüm olası yollar
    final storagePaths = [
      'user_photos/$userId',      // Yeni yapı
      'profile_images/$userId',   // Eski yapı
    ];

    int pathIndex = 0;
    for (final path in storagePaths) {
      pathIndex++;
      debugPrint('│');
      debugPrint('│  ┌─ [$pathIndex/${storagePaths.length}] Klasör: $path');

      try {
        // 1. Referans oluştur
        final storageRef = _storage.ref().child(path);
        debugPrint('│  │  ├─ Referans oluşturuldu');

        // 2. Dosyaları listele
        debugPrint('│  │  ├─ Dosyalar listeleniyor...');
        final ListResult listResult;
        try {
          listResult = await storageRef.listAll();
        } catch (e) {
          // Klasör yoksa veya erişim hatası varsa devam et
          debugPrint('│  │  ├─ ⚠ Klasör bulunamadı veya boş: $e');
          debugPrint('│  │  └─ Atlanıyor, sonraki klasöre geçiliyor...');
          continue;
        }

        // 3. Dosya sayısını kontrol et
        final itemCount = listResult.items.length;
        final prefixCount = listResult.prefixes.length;

        debugPrint('│  │  ├─ Bulunan: $itemCount dosya, $prefixCount alt klasör');

        if (itemCount == 0 && prefixCount == 0) {
          debugPrint('│  │  └─ Klasör boş, atlanıyor');
          continue;
        }

        // 4. Dosyaları listele ve sil
        if (itemCount > 0) {
          debugPrint('│  │  ├─ Dosyalar:');
          for (int i = 0; i < listResult.items.length; i++) {
            final item = listResult.items[i];
            debugPrint('│  │  │    ${i + 1}. ${item.name}');
          }

          debugPrint('│  │  ├─ Silme işlemi başlıyor...');
          for (final item in listResult.items) {
            try {
              await item.delete();
              stats.photos++;
              debugPrint('│  │  │    ✓ SİLİNDİ: ${item.name}');
            } catch (e) {
              debugPrint('│  │  │    ✗ HATA: ${item.name} - $e');
              stats.errors++;
            }
          }
        }

        // 5. Alt klasörleri recursive sil
        if (prefixCount > 0) {
          debugPrint('│  │  ├─ Alt klasörler siliniyor...');
          for (final prefix in listResult.prefixes) {
            await _deleteStorageFolder(prefix, stats);
          }
        }

        debugPrint('│  │  └─ ✓ Klasör temizliği tamamlandı');

      } catch (e) {
        debugPrint('│  │  └─ ⚠ Beklenmeyen hata: $e (devam ediliyor)');
        stats.errors++;
      }
    }

    // Özet
    debugPrint('│');
    debugPrint('│  ┌─────────────────────────────────────────────');
    debugPrint('│  │ STORAGE TEMİZLİĞİ TAMAMLANDI');
    debugPrint('│  │ Toplam silinen dosya: ${stats.photos}');
    debugPrint('│  │ Hata sayısı: ${stats.errors}');
    debugPrint('│  └─────────────────────────────────────────────');
  }

  /// Alt klasörleri recursive sil
  Future<void> _deleteStorageFolder(Reference folderRef, _DeleteStats stats) async {
    try {
      debugPrint('│  │      → Alt klasör: ${folderRef.fullPath}');
      final listResult = await folderRef.listAll();

      // Dosyaları sil
      for (final item in listResult.items) {
        try {
          await item.delete();
          stats.photos++;
          debugPrint('│  │        ✓ Silindi: ${item.name}');
        } catch (e) {
          debugPrint('│  │        ✗ Hata: ${item.name} - $e');
          stats.errors++;
        }
      }

      // Alt klasörleri recursive sil
      for (final prefix in listResult.prefixes) {
        await _deleteStorageFolder(prefix, stats);
      }
    } catch (e) {
      debugPrint('│  │        ✗ Alt klasör hatası: $e');
      stats.errors++;
    }
  }

  /// Matches koleksiyonu temizliği
  Future<void> _cleanupMatches(String userId, _DeleteStats stats) async {
    debugPrint('│  ├─ Matches temizleniyor...');
    try {
      final snapshot = await _firestore
          .collection('matches')
          .where('users', arrayContains: userId)
          .get();

      if (snapshot.docs.isEmpty) {
        debugPrint('│  │  └─ Eşleşme bulunamadı');
        return;
      }

      // Batch delete (500 limit)
      final batches = _createBatches(snapshot.docs);
      for (final batch in batches) {
        for (final doc in batch) {
          _firestore.batch().delete(doc.reference);
        }
      }

      // Paralel silme
      await Future.wait(
        snapshot.docs.map((doc) => doc.reference.delete()),
      );

      stats.matches = snapshot.docs.length;
      debugPrint('│  │  └─ ✓ ${stats.matches} eşleşme silindi');
    } catch (e) {
      debugPrint('│  │  └─ ✗ Matches hatası: $e');
      stats.errors++;
    }
  }

  /// Chats ve Messages temizliği (subcollection dikkatli silinmeli)
  Future<void> _cleanupChatsWithMessages(String userId, _DeleteStats stats) async {
    debugPrint('│  ├─ Chats ve Messages temizleniyor...');
    try {
      final chatsSnapshot = await _firestore
          .collection('chats')
          .where('users', arrayContains: userId)
          .get();

      if (chatsSnapshot.docs.isEmpty) {
        debugPrint('│  │  └─ Sohbet bulunamadı');
        return;
      }

      for (final chatDoc in chatsSnapshot.docs) {
        // Önce messages subcollection'ı sil
        try {
          final messagesSnapshot = await chatDoc.reference
              .collection('messages')
              .get();

          if (messagesSnapshot.docs.isNotEmpty) {
            // Paralel mesaj silme
            await Future.wait(
              messagesSnapshot.docs.map((msg) => msg.reference.delete()),
            );
            stats.messages += messagesSnapshot.docs.length;
          }
        } catch (e) {
          debugPrint('│  │  ├─ ⚠ Messages hatası (${chatDoc.id}): $e');
          stats.errors++;
        }

        // Sonra chat dokümanını sil
        try {
          await chatDoc.reference.delete();
          stats.chats++;
        } catch (e) {
          debugPrint('│  │  ├─ ✗ Chat silme hatası (${chatDoc.id}): $e');
          stats.errors++;
        }
      }

      debugPrint('│  │  └─ ✓ ${stats.chats} sohbet, ${stats.messages} mesaj silindi');
    } catch (e) {
      debugPrint('│  │  └─ ✗ Chats hatası: $e');
      stats.errors++;
    }
  }

  /// Actions koleksiyonu temizliği (fromUserId ve toUserId)
  Future<void> _cleanupActions(String userId, _DeleteStats stats) async {
    debugPrint('│  ├─ Actions temizleniyor...');
    try {
      // fromUserId ve toUserId için paralel sorgu
      final results = await Future.wait([
        _firestore
            .collection('actions')
            .where('fromUserId', isEqualTo: userId)
            .get(),
        _firestore
            .collection('actions')
            .where('toUserId', isEqualTo: userId)
            .get(),
      ]);

      final allDocs = <DocumentSnapshot>{};
      for (final result in results) {
        allDocs.addAll(result.docs);
      }

      if (allDocs.isEmpty) {
        debugPrint('│  │  └─ Aksiyon bulunamadı');
        return;
      }

      // Paralel silme
      await Future.wait(
        allDocs.map((doc) => doc.reference.delete()),
      );

      stats.actions = allDocs.length;
      debugPrint('│  │  └─ ✓ ${stats.actions} aksiyon silindi');
    } catch (e) {
      debugPrint('│  │  └─ ✗ Actions hatası: $e');
      stats.errors++;
    }
  }

  /// Reports koleksiyonu temizliği (reporterId ve reportedId)
  Future<void> _cleanupReports(String userId, _DeleteStats stats) async {
    debugPrint('│  ├─ Reports temizleniyor...');
    try {
      // reporterId ve reportedId için paralel sorgu
      final results = await Future.wait([
        _firestore
            .collection('reports')
            .where('reporterId', isEqualTo: userId)
            .get(),
        _firestore
            .collection('reports')
            .where('reportedId', isEqualTo: userId)
            .get(),
      ]);

      final allDocs = <DocumentSnapshot>{};
      for (final result in results) {
        allDocs.addAll(result.docs);
      }

      if (allDocs.isEmpty) {
        debugPrint('│  │  └─ Rapor bulunamadı');
        return;
      }

      // Paralel silme
      await Future.wait(
        allDocs.map((doc) => doc.reference.delete()),
      );

      stats.reports = allDocs.length;
      debugPrint('│  │  └─ ✓ ${stats.reports} rapor silindi');
    } catch (e) {
      debugPrint('│  │  └─ ✗ Reports hatası: $e');
      stats.errors++;
    }
  }

  /// Kullanıcı profili ve alt koleksiyonları temizliği
  Future<void> _cleanupUserProfile(String userId, _DeleteStats stats) async {
    try {
      final userDocRef = _firestore.collection('users').doc(userId);

      // Alt koleksiyonlar listesi
      const subcollections = [
        'blocked_users',
        'blocked_by',
        'matches',
        'likes',
        'dislikes',
        'notifications',
      ];

      // Alt koleksiyonları paralel sil
      await Future.wait(
        subcollections.map((subcollection) async {
          try {
            final subSnapshot = await userDocRef.collection(subcollection).get();
            if (subSnapshot.docs.isNotEmpty) {
              await Future.wait(
                subSnapshot.docs.map((doc) => doc.reference.delete()),
              );
              stats.subcollections += subSnapshot.docs.length;
              debugPrint('│  ├─ ✓ $subcollection: ${subSnapshot.docs.length} döküman');
            }
          } catch (e) {
            debugPrint('│  ├─ ⚠ $subcollection hatası: $e');
          }
        }),
      );

      // Ana kullanıcı dokümanını sil
      await userDocRef.delete();
      stats.userDocDeleted = true;
      debugPrint('│  └─ ✓ Kullanıcı profili silindi');
    } catch (e) {
      debugPrint('│  └─ ✗ Profil silme hatası: $e');
      stats.errors++;
    }
  }

  /// Batch işlemleri için dökümanları 500'lük gruplara böl
  List<List<DocumentSnapshot>> _createBatches(List<DocumentSnapshot> docs) {
    const batchSize = 500;
    final batches = <List<DocumentSnapshot>>[];
    for (var i = 0; i < docs.length; i += batchSize) {
      batches.add(docs.sublist(
        i,
        i + batchSize > docs.length ? docs.length : i + batchSize,
      ));
    }
    return batches;
  }

  // ==================== HELPER METHODS ====================

  /// Generate consistent chat ID from two user IDs
  String _generateChatId(String uid1, String uid2) {
    final sortedIds = [uid1, uid2]..sort();
    return '${sortedIds[0]}_${sortedIds[1]}';
  }
}

/// Report reason model
class ReportReason {
  final String id;
  final String label;
  final String icon;

  const ReportReason({
    required this.id,
    required this.label,
    required this.icon,
  });
}

/// Silme istatistikleri için yardımcı sınıf
class _DeleteStats {
  int photos = 0;
  int matches = 0;
  int chats = 0;
  int messages = 0;
  int actions = 0;
  int reports = 0;
  int subcollections = 0;
  int errors = 0;
  bool userDocDeleted = false;
}
