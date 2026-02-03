import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../data/university_data.dart';

/// Test profilleri oluşturmak için servis
class SeedService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final Random _random = Random();

  /// Test profilleri ekle
  Future<void> seedTestProfiles() async {
    final batch = _firestore.batch();
    final usersCollection = _firestore.collection('users');

    final testProfiles = [
      {
        'name': 'Elif',
        'age': 22,
        'bio':
            'Kahve bağımlısından kitap kurduna. Yeni insanlarla tanışmaya açığım.',
        'university': 'Boğaziçi Üniversitesi',
        'department': 'Bilgisayar Mühendisliği',
        'gender': 'Kadın',
        'lookingFor': 'Erkek',
        'photos': [
          'https://images.unsplash.com/photo-1494790108377-be9c29b29330?w=400&h=600&fit=crop',
          'https://images.unsplash.com/photo-1524504388940-b1c1722653e1?w=400&h=600&fit=crop',
        ],
        'interests': ['Kitap', 'Kahve', 'Yoga', 'Seyahat'],
        'createdAt': FieldValue.serverTimestamp(),
        'isDemoUser': true, // Demo kullanici bayragi - GERCEK KULLANICILAR KORUNUR
      },
      {
        'name': 'Zeynep',
        'age': 21,
        'bio':
            'Hayatında anlam arayan bir ruh. Seyahat etmeyi ve yeni kültürleri keşfetmeyi seviyorum.',
        'university': 'ODTÜ',
        'department': 'Psikoloji',
        'gender': 'Kadın',
        'lookingFor': 'Erkek',
        'photos': [
          'https://images.unsplash.com/photo-1438761681033-6461ffad8d80?w=400&h=600&fit=crop',
          'https://images.unsplash.com/photo-1517841905240-472988babdf9?w=400&h=600&fit=crop',
        ],
        'interests': ['Seyahat', 'Fotoğrafçılık', 'Müzik', 'Dans'],
        'createdAt': FieldValue.serverTimestamp(),
        'isDemoUser': true,
      },
      {
        'name': 'Selin',
        'age': 23,
        'bio':
            'Kitap okumak, yoga ve doğada vakit geçirmek en sevdiğim aktiviteler.',
        'university': 'Koç Üniversitesi',
        'department': 'Hukuk',
        'gender': 'Kadın',
        'lookingFor': 'Erkek',
        'photos': [
          'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=400&h=600&fit=crop',
          'https://images.unsplash.com/photo-1488426862026-3ee34a7d66df?w=400&h=600&fit=crop',
        ],
        'interests': ['Hukuk', 'Kitap', 'Yoga', 'Doğa'],
        'createdAt': FieldValue.serverTimestamp(),
        'isDemoUser': true,
      },
      {
        'name': 'Defne',
        'age': 20,
        'bio': 'Sanat ve müzik tutkunu. Gitar çalıyorum ve resim yapıyorum.',
        'university': 'Mimar Sinan',
        'department': 'Güzel Sanatlar',
        'gender': 'Kadın',
        'lookingFor': 'Erkek',
        'photos': [
          'https://images.unsplash.com/photo-1529626455594-4ff0802cfb7e?w=400&h=600&fit=crop',
          'https://images.unsplash.com/photo-1502823403499-6ccfcf4fb453?w=400&h=600&fit=crop',
        ],
        'interests': ['Müzik', 'Resim', 'Gitar', 'Sinema'],
        'createdAt': FieldValue.serverTimestamp(),
        'isDemoUser': true,
      },
      {
        'name': 'Ahmet',
        'age': 24,
        'bio': 'Müzik ve teknoloji tutkunu. Gitar çalarım, kod yazarım.',
        'university': 'İTÜ',
        'department': 'Elektrik Elektronik',
        'gender': 'Erkek',
        'lookingFor': 'Kadın',
        'photos': [
          'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=400&h=600&fit=crop',
          'https://images.unsplash.com/photo-1492562080023-ab3db95bfbce?w=400&h=600&fit=crop',
        ],
        'interests': ['Müzik', 'Teknoloji', 'Gitar', 'Kod'],
        'createdAt': FieldValue.serverTimestamp(),
        'isDemoUser': true,
      },
      {
        'name': 'Can',
        'age': 23,
        'bio':
            'Spor, sinema ve iyi sohbetler. Hayatı dolu dolu yaşamak istiyorum.',
        'university': 'Bilkent',
        'department': 'İşletme',
        'gender': 'Erkek',
        'lookingFor': 'Kadın',
        'photos': [
          'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=400&h=600&fit=crop',
          'https://images.unsplash.com/photo-1472099645785-5658abf4ff4e?w=400&h=600&fit=crop',
        ],
        'interests': ['Spor', 'Sinema', 'Basketbol', 'Yüzme'],
        'createdAt': FieldValue.serverTimestamp(),
        'isDemoUser': true,
      },
      {
        'name': 'Emre',
        'age': 25,
        'bio':
            'Girişimci ruhu olan biri. Yeni fikirler ve projeler üzerinde çalışmayı seviyorum.',
        'university': 'Sabancı Üniversitesi',
        'department': 'Endüstri Mühendisliği',
        'gender': 'Erkek',
        'lookingFor': 'Kadın',
        'photos': [
          'https://images.unsplash.com/photo-1506794778202-cad84cf45f1d?w=400&h=600&fit=crop',
          'https://images.unsplash.com/photo-1519085360753-af0119f7cbe7?w=400&h=600&fit=crop',
        ],
        'interests': ['Girişimcilik', 'Teknoloji', 'Kitap', 'Koşu'],
        'createdAt': FieldValue.serverTimestamp(),
        'isDemoUser': true,
      },
      {
        'name': 'Burak',
        'age': 22,
        'bio':
            'Futbol fanatiği ve oyun tutkunu. Eğlenceli vakit geçirmeyi seven biri.',
        'university': 'Galatasaray Üniversitesi',
        'department': 'İletişim',
        'gender': 'Erkek',
        'lookingFor': 'Kadın',
        'photos': [
          'https://images.unsplash.com/photo-1463453091185-61582044d556?w=400&h=600&fit=crop',
          'https://images.unsplash.com/photo-1504257432389-52343af06ae3?w=400&h=600&fit=crop',
        ],
        'interests': ['Futbol', 'Oyun', 'Film', 'Müzik'],
        'createdAt': FieldValue.serverTimestamp(),
        'isDemoUser': true,
      },
      {
        'name': 'Ece',
        'age': 21,
        'bio':
            'Tatlı bir gülümseme ve pozitif enerji. Hayattan keyif almayı biliyorum.',
        'university': 'İstanbul Üniversitesi',
        'department': 'Tıp',
        'gender': 'Kadın',
        'lookingFor': 'Erkek',
        'photos': [
          'https://images.unsplash.com/photo-1544005313-94ddf0286df2?w=400&h=600&fit=crop',
          'https://images.unsplash.com/photo-1531746020798-e6953c6e8e04?w=400&h=600&fit=crop',
        ],
        'interests': ['Tıp', 'Yoga', 'Yemek', 'Seyahat'],
        'createdAt': FieldValue.serverTimestamp(),
        'isDemoUser': true,
      },
      {
        'name': 'Deniz',
        'age': 24,
        'bio':
            'Deniz ve doğa aşığı. Sörf yapmayı ve kamp kurmayı çok seviyorum.',
        'university': 'Ege Üniversitesi',
        'department': 'Turizm',
        'gender': 'Kadın',
        'lookingFor': 'Erkek',
        'photos': [
          'https://images.unsplash.com/photo-1502767089025-6572583495f9?w=400&h=600&fit=crop',
          'https://images.unsplash.com/photo-1496440737103-cd596325d314?w=400&h=600&fit=crop',
        ],
        'interests': ['Sörf', 'Kamp', 'Doğa', 'Fotoğrafçılık'],
        'createdAt': FieldValue.serverTimestamp(),
        'isDemoUser': true,
      },
      {
        'name': 'Kaan',
        'age': 26,
        'bio':
            'Yazılım geliştirici. Gece kodlama, gündüz kahve. Bazen tam tersi.',
        'university': 'Hacettepe',
        'department': 'Yazılım Mühendisliği',
        'gender': 'Erkek',
        'lookingFor': 'Kadın',
        'photos': [
          'https://images.unsplash.com/photo-1539571696357-5a69c17a67c6?w=400&h=600&fit=crop',
          'https://images.unsplash.com/photo-1507591064344-4c6ce005b128?w=400&h=600&fit=crop',
        ],
        'interests': ['Yazılım', 'Kahve', 'Oyun', 'Anime'],
        'createdAt': FieldValue.serverTimestamp(),
        'isDemoUser': true,
      },
      {
        'name': 'Merve',
        'age': 22,
        'bio': 'Moda ve tasarım tutkunu. Renkli bir hayat yaşamayı seviyorum.',
        'university': 'Marmara Üniversitesi',
        'department': 'Moda Tasarımı',
        'gender': 'Kadın',
        'lookingFor': 'Erkek',
        'photos': [
          'https://images.unsplash.com/photo-1524250502761-1ac6f2e30d43?w=400&h=600&fit=crop',
          'https://images.unsplash.com/photo-1509967419530-da38b4704bc6?w=400&h=600&fit=crop',
        ],
        'interests': ['Moda', 'Tasarım', 'Alışveriş', 'Fotoğraf'],
        'createdAt': FieldValue.serverTimestamp(),
        'isDemoUser': true,
      },
    ];

    for (final profile in testProfiles) {
      final docRef = usersCollection.doc();
      
      // Üniversiteye göre şehri otomatik belirle
      final university = profile['university'] as String?;
      final universityCity = university != null 
          ? UniversityData.getCityForUniversity(university)
          : null;
      
      // universityCity ve isComplete alanlarını profile ekle
      final profileWithCity = {
        ...profile,
        if (universityCity != null) 'universityCity': universityCity,
        'isComplete': true, // Demo kullanıcılar her zaman complete!
      };
      
      batch.set(docRef, profileWithCity);
    }

    await batch.commit();
  }

  /// Tüm test profillerini sil (SADECE isDemoUser: true olanlar)
  /// GERCEK KULLANICILAR KORUNUR!
  /// Alt koleksiyonlar ve ilişkili veriler de temizlenir
  Future<void> clearTestProfiles() async {
    final currentUserId = _auth.currentUser?.uid;
    final snapshot = await _firestore.collection('users').get();
    int deletedCount = 0;
    int protectedCount = 0;

    // Silinecek demo kullanıcı ID'lerini topla
    final demoUserIds = <String>[];

    for (final doc in snapshot.docs) {
      final data = doc.data();
      final isDemoUser = data['isDemoUser'] == true;

      // GUVENLIK KONTROLU:
      // 1. Mevcut kullaniciyi ASLA silme
      // 2. isDemoUser: true OLMAYAN kullanicilari ASLA silme
      if (doc.id == currentUserId) {
        protectedCount++;
        debugPrint('SeedService: KORUNDU (mevcut kullanici): ${data['name'] ?? doc.id}');
        continue;
      }

      if (!isDemoUser) {
        protectedCount++;
        debugPrint('SeedService: KORUNDU (gercek kullanici): ${data['name'] ?? data['email'] ?? doc.id}');
        continue;
      }

      demoUserIds.add(doc.id);
    }

    debugPrint('SeedService: ${demoUserIds.length} demo kullanici silinecek...');

    // Her demo kullanıcı için alt koleksiyonları ve ilişkili verileri sil
    for (final userId in demoUserIds) {
      await _deleteUserWithSubcollections(userId);
      deletedCount++;
      debugPrint('SeedService: Silindi ($deletedCount/${demoUserIds.length}): $userId');
    }

    debugPrint('SeedService: ✓ Silindi: $deletedCount demo profil');
    debugPrint('SeedService: ✓ Korundu: $protectedCount gercek profil');
  }

  /// Kullanıcı ve tüm alt koleksiyonlarını + ilişkili verileri sil
  /// Ghost document oluşmasını önler
  /// ÇAPRAZ TEMİZLİK: Diğer kullanıcıların subcollection'larındaki referansları da siler
  Future<void> _deleteUserWithSubcollections(String userId) async {
    final userRef = _firestore.collection('users').doc(userId);

    // ═══════════════════════════════════════════════════════════════════
    // 1. ÇAPRAZ TEMİZLİK - DİĞER KULLANICILARIN ALT KOLEKSİYONLARINI TEMİZLE
    // Bu demo kullanıcının diğer kullanıcılarda bıraktığı tüm izleri sil
    // ═══════════════════════════════════════════════════════════════════

    await _crossCleanupForDeletedUser(userId);

    // ═══════════════════════════════════════════════════════════════════
    // 2. KENDİ ALT KOLEKSİYONLARINI SİL
    // ═══════════════════════════════════════════════════════════════════
    const subcollections = [
      'notifications',
      'matches',
      'likes',
      'blocked_users',
      'blocked_by',
      'swipes',
    ];

    for (final subcollection in subcollections) {
      await _deleteSubcollection(userRef.collection(subcollection));
    }

    // ═══════════════════════════════════════════════════════════════════
    // 3. ÜST SEVİYE İLİŞKİLİ DÖKÜMALARI SİL
    // ═══════════════════════════════════════════════════════════════════

    // 3a. matches koleksiyonundan bu kullanıcıyı içeren dökümanları sil
    final matchesSnapshot = await _firestore
        .collection('matches')
        .where('users', arrayContains: userId)
        .get();

    for (final doc in matchesSnapshot.docs) {
      await doc.reference.delete();
    }
    if (matchesSnapshot.docs.isNotEmpty) {
      debugPrint('  → ${matchesSnapshot.docs.length} global match silindi');
    }

    // 3b. chats koleksiyonundan bu kullanıcıyı içeren dökümanları sil
    final chatsSnapshot = await _firestore
        .collection('chats')
        .where('users', arrayContains: userId)
        .get();

    for (final chatDoc in chatsSnapshot.docs) {
      await _deleteSubcollection(chatDoc.reference.collection('messages'));
      await chatDoc.reference.delete();
    }
    if (chatsSnapshot.docs.isNotEmpty) {
      debugPrint('  → ${chatsSnapshot.docs.length} chat silindi');
    }

    // 3c. actions koleksiyonundan bu kullanıcıyla ilişkili dökümanları sil
    final actionsFromSnapshot = await _firestore
        .collection('actions')
        .where('fromUserId', isEqualTo: userId)
        .get();

    final actionsToSnapshot = await _firestore
        .collection('actions')
        .where('toUserId', isEqualTo: userId)
        .get();

    for (final doc in actionsFromSnapshot.docs) {
      await doc.reference.delete();
    }
    for (final doc in actionsToSnapshot.docs) {
      await doc.reference.delete();
    }

    final totalActions = actionsFromSnapshot.docs.length + actionsToSnapshot.docs.length;
    if (totalActions > 0) {
      debugPrint('  → $totalActions action silindi');
    }

    // ═══════════════════════════════════════════════════════════════════
    // 4. ANA KULLANICI DÖKÜMANINI SİL
    // ═══════════════════════════════════════════════════════════════════
    await userRef.delete();
  }

  /// ÇAPRAZ TEMİZLİK: Silinen kullanıcının diğer kullanıcılardaki izlerini temizle
  /// Collection Group Query kullanarak tüm veritabanını tarar
  Future<void> _crossCleanupForDeletedUser(String deletedUserId) async {
    int totalCleaned = 0;

    // ─────────────────────────────────────────────────────────────────────
    // 1. LIKES: Diğer kullanıcıların "likes" subcollection'larında
    //    bu demo kullanıcının ID'sine sahip dökümanları sil
    //    Path: users/{anyUserId}/likes/{deletedUserId}
    // ─────────────────────────────────────────────────────────────────────
    try {
      final likesSnapshot = await _firestore
          .collectionGroup('likes')
          .where(FieldPath.documentId, isEqualTo: deletedUserId)
          .get();

      for (final doc in likesSnapshot.docs) {
        await doc.reference.delete();
        totalCleaned++;
      }
      if (likesSnapshot.docs.isNotEmpty) {
        debugPrint('  ⨯ ${likesSnapshot.docs.length} like referansı temizlendi (collectionGroup)');
      }
    } catch (e) {
      // Collection Group Query index yoksa manuel temizlik yap
      debugPrint('  ⚠ likes collectionGroup hatası, manuel temizlik yapılıyor: $e');
      totalCleaned += await _manualCrossCleanupLikes(deletedUserId);
    }

    // ─────────────────────────────────────────────────────────────────────
    // 2. MATCHES: Diğer kullanıcıların "matches" subcollection'larında
    //    bu demo kullanıcının ID'sine sahip dökümanları sil
    //    Path: users/{anyUserId}/matches/{deletedUserId}
    // ─────────────────────────────────────────────────────────────────────
    try {
      final matchesSnapshot = await _firestore
          .collectionGroup('matches')
          .where(FieldPath.documentId, isEqualTo: deletedUserId)
          .get();

      for (final doc in matchesSnapshot.docs) {
        // Sadece users/{uid}/matches altındakileri sil, global matches koleksiyonunu değil
        if (doc.reference.parent.parent?.parent.id == 'users') {
          await doc.reference.delete();
          totalCleaned++;
        }
      }
      if (matchesSnapshot.docs.isNotEmpty) {
        debugPrint('  ⨯ Subcollection match referansları temizlendi');
      }
    } catch (e) {
      debugPrint('  ⚠ matches collectionGroup hatası: $e');
      totalCleaned += await _manualCrossCleanupMatches(deletedUserId);
    }

    // ─────────────────────────────────────────────────────────────────────
    // 3. NOTIFICATIONS: fromUserId bu kullanıcı olan bildirimleri sil
    //    Path: users/{anyUserId}/notifications/{notifId} where fromUserId == deletedUserId
    // ─────────────────────────────────────────────────────────────────────
    try {
      final notificationsSnapshot = await _firestore
          .collectionGroup('notifications')
          .where('fromUserId', isEqualTo: deletedUserId)
          .get();

      for (final doc in notificationsSnapshot.docs) {
        await doc.reference.delete();
        totalCleaned++;
      }
      if (notificationsSnapshot.docs.isNotEmpty) {
        debugPrint('  ⨯ ${notificationsSnapshot.docs.length} bildirim temizlendi');
      }
    } catch (e) {
      debugPrint('  ⚠ notifications collectionGroup hatası: $e');
    }

    // ─────────────────────────────────────────────────────────────────────
    // 4. BLOCKED İLİŞKİLERİ: Bu kullanıcıyı engelleyen/engellediği kayıtlar
    // ─────────────────────────────────────────────────────────────────────
    try {
      // blocked_users subcollection'larında bu kullanıcıya ait kayıtlar
      final blockedUsersSnapshot = await _firestore
          .collectionGroup('blocked_users')
          .where(FieldPath.documentId, isEqualTo: deletedUserId)
          .get();

      for (final doc in blockedUsersSnapshot.docs) {
        await doc.reference.delete();
        totalCleaned++;
      }

      // blocked_by subcollection'larında bu kullanıcıya ait kayıtlar
      final blockedBySnapshot = await _firestore
          .collectionGroup('blocked_by')
          .where(FieldPath.documentId, isEqualTo: deletedUserId)
          .get();

      for (final doc in blockedBySnapshot.docs) {
        await doc.reference.delete();
        totalCleaned++;
      }
    } catch (e) {
      debugPrint('  ⚠ blocked collectionGroup hatası: $e');
    }

    if (totalCleaned > 0) {
      debugPrint('  ✓ Çapraz temizlik: $totalCleaned referans silindi');
    }
  }

  /// Manuel çapraz temizlik - likes için (index yoksa)
  Future<int> _manualCrossCleanupLikes(String deletedUserId) async {
    int cleaned = 0;
    final usersSnapshot = await _firestore.collection('users').get();

    for (final userDoc in usersSnapshot.docs) {
      // Silinen kullanıcının kendi dökümanını atla
      if (userDoc.id == deletedUserId) continue;

      final likeDoc = await _firestore
          .collection('users')
          .doc(userDoc.id)
          .collection('likes')
          .doc(deletedUserId)
          .get();

      if (likeDoc.exists) {
        await likeDoc.reference.delete();
        cleaned++;
        debugPrint('  ⨯ Like silindi: users/${userDoc.id}/likes/$deletedUserId');
      }
    }
    return cleaned;
  }

  /// Manuel çapraz temizlik - matches için (index yoksa)
  Future<int> _manualCrossCleanupMatches(String deletedUserId) async {
    int cleaned = 0;
    final usersSnapshot = await _firestore.collection('users').get();

    for (final userDoc in usersSnapshot.docs) {
      if (userDoc.id == deletedUserId) continue;

      final matchDoc = await _firestore
          .collection('users')
          .doc(userDoc.id)
          .collection('matches')
          .doc(deletedUserId)
          .get();

      if (matchDoc.exists) {
        await matchDoc.reference.delete();
        cleaned++;
        debugPrint('  ⨯ Match ref silindi: users/${userDoc.id}/matches/$deletedUserId');
      }
    }
    return cleaned;
  }

  /// Alt koleksiyondaki tüm dökümanları sil
  Future<void> _deleteSubcollection(CollectionReference collection) async {
    final snapshot = await collection.get();

    if (snapshot.docs.isEmpty) return;

    // Batch ile toplu silme (500 limit)
    const batchLimit = 500;
    var batch = _firestore.batch();
    var count = 0;

    for (final doc in snapshot.docs) {
      batch.delete(doc.reference);
      count++;

      // Batch limiti aşıldıysa commit et ve yeni batch başlat
      if (count >= batchLimit) {
        await batch.commit();
        batch = _firestore.batch();
        count = 0;
      }
    }

    // Kalan dökümanları commit et
    if (count > 0) {
      await batch.commit();
    }

    debugPrint('  → ${collection.path}: ${snapshot.docs.length} doküman silindi');
  }

  /// Demo kullanıcıların mevcut kullanıcıyı beğenmesini sağla
  /// Bu fonksiyon "Beni Beğenenler" sayfasını test etmek için kullanılır
  /// [likePercentage] yüzde kaçının beğeneceğini belirler (default %40-60 arası rastgele)
  Future<int> seedDemoLikesToCurrentUser({int? likePercentage}) async {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) {
      debugPrint('SeedService: No current user logged in');
      return 0;
    }

    debugPrint('SeedService: Creating demo likes for user $currentUserId');

    try {
      // Get all demo users (excluding current user)
      final usersSnapshot = await _firestore.collection('users').get();

      final allDemoUsers =
          usersSnapshot.docs.where((doc) => doc.id != currentUserId).toList();

      if (allDemoUsers.isEmpty) {
        debugPrint('SeedService: No demo users found');
        return 0;
      }

      // Rastgele yüzde belirle (40-60 arası) veya verilen değeri kullan
      final percentage = likePercentage ?? (40 + _random.nextInt(21)); // 40-60
      final likeCount = (allDemoUsers.length * percentage / 100).round();

      debugPrint(
          'SeedService: ${allDemoUsers.length} demo user found, $percentage% ($likeCount) will like');

      // Listeyi karıştır ve rastgele seç
      allDemoUsers.shuffle(_random);
      final selectedUsers = allDemoUsers.take(likeCount).toList();

      final batch = _firestore.batch();
      int count = 0;

      for (final userDoc in selectedUsers) {
        final fromUserId = userDoc.id;
        final actionId = '${fromUserId}_$currentUserId';

        batch.set(
          _firestore.collection('actions').doc(actionId),
          {
            'fromUserId': fromUserId,
            'toUserId': currentUserId,
            'type': 'like',
            'timestamp': FieldValue.serverTimestamp(),
          },
        );
        count++;
        debugPrint(
            'SeedService: Created like from ${userDoc.data()['name']} to current user');
      }

      if (count > 0) {
        await batch.commit();
      }

      debugPrint('SeedService: Created $count new demo likes');
      return count;
    } catch (e) {
      debugPrint('SeedService Error: $e');
      return 0;
    }
  }

  /// Demo beğenileri temizle
  Future<void> clearDemoLikes() async {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) return;

    try {
      // Delete actions where current user is the target
      final actionsSnapshot = await _firestore
          .collection('actions')
          .where('toUserId', isEqualTo: currentUserId)
          .get();

      final batch = _firestore.batch();
      for (final doc in actionsSnapshot.docs) {
        batch.delete(doc.reference);
      }

      await batch.commit();
      debugPrint(
          'SeedService: Cleared ${actionsSnapshot.docs.length} demo likes');
    } catch (e) {
      debugPrint('SeedService Error clearing likes: $e');
    }
  }

  /// Tüm action'ları temizle (mevcut kullanıcının action'ları dahil)
  Future<void> clearAllActions() async {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) return;

    try {
      // Mevcut kullanıcının yaptığı tüm action'lar
      final myActionsSnapshot = await _firestore
          .collection('actions')
          .where('fromUserId', isEqualTo: currentUserId)
          .get();

      // Mevcut kullanıcıya yapılan tüm action'lar
      final actionsToMeSnapshot = await _firestore
          .collection('actions')
          .where('toUserId', isEqualTo: currentUserId)
          .get();

      final batch = _firestore.batch();

      for (final doc in myActionsSnapshot.docs) {
        batch.delete(doc.reference);
      }

      for (final doc in actionsToMeSnapshot.docs) {
        batch.delete(doc.reference);
      }

      await batch.commit();
      debugPrint(
          'SeedService: Cleared ${myActionsSnapshot.docs.length + actionsToMeSnapshot.docs.length} total actions');
    } catch (e) {
      debugPrint('SeedService Error clearing actions: $e');
    }
  }

  /// Tüm match'leri temizle
  Future<void> clearAllMatches() async {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) return;

    try {
      // Mevcut kullanıcının match'leri
      final matchesSnapshot = await _firestore
          .collection('matches')
          .where('users', arrayContains: currentUserId)
          .get();

      final batch = _firestore.batch();

      for (final doc in matchesSnapshot.docs) {
        batch.delete(doc.reference);
      }

      // Kullanıcının matches subcollection'ını da temizle
      final userMatchesSnapshot = await _firestore
          .collection('users')
          .doc(currentUserId)
          .collection('matches')
          .get();

      for (final doc in userMatchesSnapshot.docs) {
        batch.delete(doc.reference);
      }

      await batch.commit();
      debugPrint('SeedService: Cleared ${matchesSnapshot.docs.length} matches');
    } catch (e) {
      debugPrint('SeedService Error clearing matches: $e');
    }
  }

  /// TAM SIFIRLAMA: Tüm demo verileri sil ve yeniden oluştur
  /// Mevcut kullanıcının profili korunur, sadece demo veriler sıfırlanır
  Future<Map<String, int>> resetAllDemoData() async {
    debugPrint('SeedService: === FULL RESET STARTING ===');

    try {
      // 1. Tüm action'ları temizle
      debugPrint('SeedService: Step 1 - Clearing all actions...');
      await clearAllActions();

      // 2. Tüm match'leri temizle
      debugPrint('SeedService: Step 2 - Clearing all matches...');
      await clearAllMatches();

      // 3. Tüm demo profilleri sil (mevcut kullanıcı hariç)
      debugPrint('SeedService: Step 3 - Clearing demo profiles...');
      await clearTestProfiles();

      // 4. Yeni demo profiller oluştur
      debugPrint('SeedService: Step 4 - Creating new demo profiles...');
      await seedTestProfiles();

      // 5. Rastgele bazı kullanıcıların beni beğenmesini sağla (%40-60)
      debugPrint('SeedService: Step 5 - Creating random likes...');
      final likeCount = await seedDemoLikesToCurrentUser();

      debugPrint('SeedService: === FULL RESET COMPLETE ===');
      debugPrint('SeedService: Created 12 demo profiles, $likeCount likes');

      return {
        'profiles': 12,
        'likes': likeCount,
      };
    } catch (e) {
      debugPrint('SeedService Error in full reset: $e');
      return {
        'profiles': 0,
        'likes': 0,
      };
    }
  }
}
