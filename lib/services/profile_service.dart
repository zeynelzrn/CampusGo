import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

class ProfileService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Mevcut kullanıcı ID'si
  String? get currentUserId => _auth.currentUser?.uid;

  // ==================== FOTO YONETIMI ====================

  /// Fotoğraf yükle - Yeni klasör yapısı: user_photos/{userId}/{timestamp}.jpg
  ///
  /// [imageFile] - Yüklenecek dosya
  /// [slotIndex] - Hangi slot'a yüklendiği (metadata için, dosya adında kullanılmıyor)
  ///
  /// Returns: Download URL veya null
  /// Throws: Exception with detailed message for UI handling
  Future<String?> uploadPhoto(File imageFile, int slotIndex) async {
    try {
      if (currentUserId == null) {
        debugPrint('ProfileService: Kullanici girisi yapilmamis');
        throw Exception('Oturum açılmamış. Lütfen tekrar giriş yapın.');
      }

      // Dosya var mı kontrol et
      if (!await imageFile.exists()) {
        debugPrint('ProfileService: Dosya bulunamadi: ${imageFile.path}');
        throw Exception('Fotoğraf dosyası bulunamadı.');
      }

      // Benzersiz dosya adı: timestamp + random suffix
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = '${timestamp}_$slotIndex.jpg';

      // Yeni klasör yapısı: user_photos/{userId}/{fileName}
      final ref = _storage.ref().child('user_photos/$currentUserId/$fileName');

      debugPrint('ProfileService: Foto yukleniyor -> $fileName');
      debugPrint('ProfileService: Storage path -> user_photos/$currentUserId/$fileName');

      // Metadata ile yükle
      final uploadTask = ref.putFile(
        imageFile,
        SettableMetadata(
          contentType: 'image/jpeg',
          customMetadata: {
            'slotIndex': slotIndex.toString(),
            'uploadedAt': DateTime.now().toIso8601String(),
          },
        ),
      );

      final snapshot = await uploadTask;
      final downloadUrl = await snapshot.ref.getDownloadURL();

      debugPrint('ProfileService: Foto yuklendi -> $fileName');
      return downloadUrl;
    } on FirebaseException catch (e) {
      // Firebase-specific error handling
      debugPrint('ProfileService: Firebase hatasi: ${e.code} - ${e.message}');

      switch (e.code) {
        case 'unauthorized':
        case 'permission-denied':
          throw Exception(
            'Storage izni yok. Firebase Console\'da Storage Rules\'u kontrol edin.\n'
            'Gerekli kural: user_photos/{userId}/* için read/write izni.',
          );
        case 'object-not-found':
          throw Exception('Dosya bulunamadı.');
        case 'bucket-not-found':
          throw Exception('Storage bucket bulunamadı. Firebase yapılandırmasını kontrol edin.');
        case 'quota-exceeded':
          throw Exception('Storage kotası aşıldı.');
        case 'unauthenticated':
          throw Exception('Oturum süresi dolmuş. Lütfen tekrar giriş yapın.');
        case 'retry-limit-exceeded':
          throw Exception('Bağlantı hatası. İnternet bağlantınızı kontrol edin.');
        case 'canceled':
          throw Exception('Yükleme iptal edildi.');
        default:
          throw Exception('Firebase hatası: ${e.message}');
      }
    } catch (e) {
      debugPrint('ProfileService: Foto yukleme hatasi: $e');
      // Re-throw if it's already our custom exception
      if (e is Exception) rethrow;
      throw Exception('Fotoğraf yüklenemedi: $e');
    }
  }

  /// URL'den fotoğraf sil (Storage'dan)
  ///
  /// [photoUrl] - Silinecek fotoğrafın Firebase Storage URL'i
  ///
  /// Returns: Başarılı mı?
  Future<bool> deletePhotoByUrl(String photoUrl) async {
    try {
      if (currentUserId == null) return false;
      if (photoUrl.isEmpty) return false;

      // URL'den Reference oluştur
      final ref = _storage.refFromURL(photoUrl);

      // Silmeden önce dosyanın bu kullanıcıya ait olduğunu doğrula
      // (Güvenlik için - başkasının fotoğrafını silmeyi engelle)
      final fullPath = ref.fullPath;
      if (!fullPath.contains(currentUserId!)) {
        debugPrint('ProfileService: Guvenlik hatasi - bu foto size ait degil');
        return false;
      }

      await ref.delete();
      debugPrint('ProfileService: Foto silindi -> $fullPath');
      return true;
    } catch (e) {
      // Dosya zaten silinmiş olabilir - hata değil
      debugPrint('ProfileService: Foto silme hatasi (muhtemelen zaten silinmis): $e');
      return true; // Dosya yoksa da başarılı say
    }
  }

  /// Eski index-based silme (geriye uyumluluk için - kullanımdan kaldırılacak)
  @Deprecated('Use deletePhotoByUrl instead')
  Future<bool> deletePhoto(int photoIndex) async {
    try {
      if (currentUserId == null) return false;

      String fileName = 'photo_$photoIndex.jpg';
      Reference ref = _storage.ref().child('users/$currentUserId/photos/$fileName');

      await ref.delete();
      return true;
    } catch (e) {
      debugPrint('ProfileService: Eski foto silme hatasi: $e');
      return false;
    }
  }

  // ==================== PROFIL YONETIMI ====================

  /// Profili kaydet
  ///
  /// [photoUrls] - 6 elemanlı liste, null olan slotlar boş demek
  /// Firestore'a kaydederken null'ları KORUYORUZ (indeks pozisyonları için)
  Future<bool> saveProfile({
    required String name,
    required int age,
    required String bio,
    required String university,
    required String department,
    required List<String> interests,
    required List<String?> photoUrls,
    required String gender,
    required String lookingFor,
    String grade = '',
    List<String> clubs = const [],
    Map<String, String> socialLinks = const {},
    List<String> intent = const [],
  }) async {
    try {
      if (currentUserId == null) return false;

      // Photos array'ini hazırla - NULL DEĞERLERİ KALDIRARAK kaydet
      // Ama sırayı korumak için önce compaction yapalım
      final List<String> cleanedPhotos = [];
      for (int i = 0; i < photoUrls.length; i++) {
        if (photoUrls[i] != null && photoUrls[i]!.isNotEmpty) {
          cleanedPhotos.add(photoUrls[i]!);
        }
      }

      // En az 1 fotoğraf olmalı
      if (cleanedPhotos.isEmpty) {
        debugPrint('ProfileService: En az 1 fotograf gerekli');
        return false;
      }

      await _firestore.collection('users').doc(currentUserId).set({
        'name': name,
        'age': age,
        'bio': bio,
        'university': university,
        'department': department,
        'interests': interests,
        'photos': cleanedPhotos, // Temizlenmiş array
        'gender': gender,
        'lookingFor': lookingFor,
        'grade': grade,
        'clubs': clubs,
        'socialLinks': socialLinks,
        'intent': intent,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // createdAt sadece ilk kayıtta set edilsin
      final doc = await _firestore.collection('users').doc(currentUserId).get();
      if (doc.exists && doc.data()?['createdAt'] == null) {
        await _firestore.collection('users').doc(currentUserId).update({
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      debugPrint('ProfileService: Profil kaydedildi (${cleanedPhotos.length} foto)');
      return true;
    } catch (e) {
      debugPrint('ProfileService: Profil kaydetme hatasi: $e');
      return false;
    }
  }

  /// Sadece fotoğrafları güncelle (hızlı güncelleme için)
  Future<bool> updatePhotos(List<String?> photoUrls) async {
    try {
      if (currentUserId == null) return false;

      final List<String> cleanedPhotos = photoUrls
          .where((url) => url != null && url.isNotEmpty)
          .cast<String>()
          .toList();

      if (cleanedPhotos.isEmpty) {
        debugPrint('ProfileService: En az 1 fotograf gerekli');
        return false;
      }

      await _firestore.collection('users').doc(currentUserId).update({
        'photos': cleanedPhotos,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      debugPrint('ProfileService: Fotolar guncellendi (${cleanedPhotos.length} foto)');
      return true;
    } catch (e) {
      debugPrint('ProfileService: Foto guncelleme hatasi: $e');
      return false;
    }
  }

  /// Profili getir
  Future<Map<String, dynamic>?> getProfile() async {
    try {
      if (currentUserId == null) return null;

      DocumentSnapshot doc =
          await _firestore.collection('users').doc(currentUserId).get();

      if (doc.exists) {
        return doc.data() as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      debugPrint('ProfileService: Profil getirme hatasi: $e');
      return null;
    }
  }

  // ==================== DIGER METODLAR ====================

  /// Tüm profilleri getir (match için)
  Future<List<Map<String, dynamic>>> getAllProfiles() async {
    try {
      if (currentUserId == null) return [];

      QuerySnapshot snapshot = await _firestore
          .collection('users')
          .where(FieldPath.documentId, isNotEqualTo: currentUserId)
          .limit(50)
          .get();

      return snapshot.docs.map((doc) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;
        return data;
      }).toList();
    } catch (e) {
      debugPrint('ProfileService: Profilleri getirme hatasi: $e');
      return [];
    }
  }

  /// Like/Dislike kaydet
  Future<bool> swipeProfile(String targetUserId, bool isLike) async {
    try {
      if (currentUserId == null) return false;

      String collection = isLike ? 'likes' : 'dislikes';

      await _firestore
          .collection('users')
          .doc(currentUserId)
          .collection(collection)
          .doc(targetUserId)
          .set({
        'timestamp': FieldValue.serverTimestamp(),
      });

      // Eğer like ise, karşılıklı like kontrolü yap
      if (isLike) {
        DocumentSnapshot otherUserLike = await _firestore
            .collection('users')
            .doc(targetUserId)
            .collection('likes')
            .doc(currentUserId)
            .get();

        if (otherUserLike.exists) {
          // Match oluştur
          await _createMatch(targetUserId);
          return true; // Match oldu
        }
      }

      return false;
    } catch (e) {
      debugPrint('ProfileService: Swipe hatasi: $e');
      return false;
    }
  }

  /// Match oluştur
  Future<void> _createMatch(String otherUserId) async {
    try {
      if (currentUserId == null) return;

      String matchId = currentUserId!.compareTo(otherUserId) < 0
          ? '${currentUserId}_$otherUserId'
          : '${otherUserId}_$currentUserId';

      await _firestore.collection('matches').doc(matchId).set({
        'users': [currentUserId, otherUserId],
        'timestamp': FieldValue.serverTimestamp(),
      });

      // Her iki kullanıcının matches koleksiyonuna ekle
      await _firestore
          .collection('users')
          .doc(currentUserId)
          .collection('matches')
          .doc(otherUserId)
          .set({'timestamp': FieldValue.serverTimestamp()});

      await _firestore
          .collection('users')
          .doc(otherUserId)
          .collection('matches')
          .doc(currentUserId)
          .set({'timestamp': FieldValue.serverTimestamp()});
    } catch (e) {
      debugPrint('ProfileService: Match olusturma hatasi: $e');
    }
  }
}
