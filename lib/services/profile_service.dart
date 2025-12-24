import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ProfileService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Mevcut kullanıcı ID'si
  String? get currentUserId => _auth.currentUser?.uid;

  // Fotoğraf yükle
  Future<String?> uploadPhoto(File imageFile, int photoIndex) async {
    try {
      if (currentUserId == null) return null;

      String fileName = 'photo_$photoIndex.jpg';
      Reference ref = _storage.ref().child('users/$currentUserId/photos/$fileName');

      UploadTask uploadTask = ref.putFile(
        imageFile,
        SettableMetadata(contentType: 'image/jpeg'),
      );

      TaskSnapshot snapshot = await uploadTask;
      String downloadUrl = await snapshot.ref.getDownloadURL();

      return downloadUrl;
    } catch (e) {
      print('Fotoğraf yükleme hatası: $e');
      return null;
    }
  }

  // Fotoğraf sil
  Future<bool> deletePhoto(int photoIndex) async {
    try {
      if (currentUserId == null) return false;

      String fileName = 'photo_$photoIndex.jpg';
      Reference ref = _storage.ref().child('users/$currentUserId/photos/$fileName');

      await ref.delete();
      return true;
    } catch (e) {
      print('Fotoğraf silme hatası: $e');
      return false;
    }
  }

  // Profili kaydet
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
  }) async {
    try {
      if (currentUserId == null) return false;

      await _firestore.collection('users').doc(currentUserId).set({
        'name': name,
        'age': age,
        'bio': bio,
        'university': university,
        'department': department,
        'interests': interests,
        'photos': photoUrls.where((url) => url != null).toList(),
        'gender': gender,
        'lookingFor': lookingFor,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      return true;
    } catch (e) {
      print('Profil kaydetme hatası: $e');
      return false;
    }
  }

  // Profili getir
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
      print('Profil getirme hatası: $e');
      return null;
    }
  }

  // Tüm profilleri getir (match için)
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
      print('Profilleri getirme hatası: $e');
      return [];
    }
  }

  // Like/Dislike kaydet
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
      print('Swipe hatası: $e');
      return false;
    }
  }

  // Match oluştur
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
      print('Match oluşturma hatası: $e');
    }
  }
}
