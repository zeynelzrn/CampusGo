import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:internet_connection_checker_plus/internet_connection_checker_plus.dart';
import 'notification_service.dart';
import 'user_service.dart';
import 'profile_cache_service.dart';
import 'message_cache_service.dart';
import '../repositories/likes_repository.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final NotificationService _notificationService = NotificationService();
  final UserService _userService = UserService();

  // Mevcut kullanıcıyı al
  User? get currentUser => _auth.currentUser;

  /// İnternet bağlantısını kontrol et
  Future<bool> _checkInternetConnection() async {
    try {
      final hasConnection = await InternetConnection().hasInternetAccess;
      if (!hasConnection) {
        debugPrint('AuthService: İnternet bağlantısı yok!');
      }
      return hasConnection;
    } catch (e) {
      debugPrint('AuthService: İnternet kontrolü hatası: $e');
      return false;
    }
  }

  // Auth durumunu dinle
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  /// Kullanıcı ayarlarını kaydet (kayıt sırasında)
  /// ETK (Ticari Elektronik İleti) tercihi burada saklanır
  Future<void> _saveUserSettings({
    required String userId,
    required String email,
    required bool isCommercialNotificationsEnabled,
  }) async {
    try {
      await _firestore.collection('user_settings').doc(userId).set({
        'email': email,
        'isCommercialNotificationsEnabled': isCommercialNotificationsEnabled,
        'eulaAcceptedAt': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      debugPrint('AuthService: User settings saved - ETK: $isCommercialNotificationsEnabled');
    } catch (e) {
      debugPrint('AuthService: Error saving user settings: $e');
      // Hata olsa bile kayıt işlemini durdurmuyoruz
    }
  }

  /// Ticari ileti tercihini güncelle (ayarlar sayfasından)
  Future<bool> updateCommercialNotificationPreference({
    required String userId,
    required bool isEnabled,
  }) async {
    try {
      await _firestore.collection('user_settings').doc(userId).update({
        'isCommercialNotificationsEnabled': isEnabled,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      debugPrint('AuthService: Commercial notification preference updated: $isEnabled');
      return true;
    } catch (e) {
      debugPrint('AuthService: Error updating commercial notification preference: $e');
      return false;
    }
  }

  /// Ticari ileti tercihini oku
  Future<bool> getCommercialNotificationPreference(String userId) async {
    try {
      final doc = await _firestore.collection('user_settings').doc(userId).get();
      if (doc.exists) {
        return doc.data()?['isCommercialNotificationsEnabled'] as bool? ?? false;
      }
      return false;
    } catch (e) {
      debugPrint('AuthService: Error getting commercial notification preference: $e');
      return false;
    }
  }

  // ═══════════════════════════════════════════════════════════════
  // EMAIL DOĞRULAMA (VERIFICATION) İŞLEMLERİ
  // ═══════════════════════════════════════════════════════════════

  /// Test hesapları e-posta doğrulamasından muaf (doğrudan ana sayfaya geçiş).
  /// Sadece 'test-' ile başlayan e-postalar.
  static bool isTestEmail(String? email) {
    if (email == null || email.isEmpty) return false;
    final e = email.trim().toLowerCase();
    return e.startsWith('test-');
  }

  /// E-posta doğrulama linki gönder
  Future<Map<String, dynamic>> sendEmailVerification() async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        return {'success': false, 'error': 'Kullanıcı bulunamadı'};
      }

      if (user.emailVerified) {
        return {'success': true, 'message': 'E-posta zaten doğrulanmış'};
      }

      await user.sendEmailVerification();
      debugPrint('AuthService: Verification email sent to ${user.email}');
      return {'success': true, 'message': 'Doğrulama maili gönderildi'};
    } catch (e) {
      debugPrint('AuthService: Error sending verification email: $e');
      String errorMessage = 'Doğrulama maili gönderilemedi';
      if (e.toString().contains('too-many-requests')) {
        errorMessage = 'Çok fazla istek gönderildi. Lütfen biraz bekleyin.';
      }
      return {'success': false, 'error': errorMessage};
    }
  }

  /// E-posta doğrulama durumunu kontrol et (reload ile güncel bilgi al).
  /// Test e-postaları (test-* ile başlayanlar) için true döner, doğrulama atlanır.
  Future<bool> checkEmailVerified() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return false;

      if (isTestEmail(user.email)) {
        debugPrint('AuthService: Test account, skipping email verification');
        return true;
      }

      await user.reload();
      final refreshedUser = _auth.currentUser;
      final isVerified = refreshedUser?.emailVerified ?? false;

      debugPrint('AuthService: Email verified status: $isVerified');
      return isVerified;
    } catch (e) {
      debugPrint('AuthService: Error checking email verification: $e');
      return false;
    }
  }

  /// Kullanıcının email doğrulama durumunu al (reload yapmadan)
  bool get isEmailVerified => _auth.currentUser?.emailVerified ?? false;

  /// Mevcut kullanıcının email adresini al
  String? get currentUserEmail => _auth.currentUser?.email;

  // Kayıt ol
  Future<Map<String, dynamic>> register({
    required String email,
    required String password,
    bool isCommercialNotificationsEnabled = false, // ETK tercihi
  }) async {
    try {
      UserCredential result = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      User? user = result.user;

      if (user != null) {
        // Save FCM token on successful registration
        await _notificationService.saveTokenToFirestore(user.uid);
        _notificationService.listenToTokenRefresh(user.uid);

        // Save user settings (ETK/commercial notifications preference)
        await _saveUserSettings(
          userId: user.uid,
          email: email,
          isCommercialNotificationsEnabled: isCommercialNotificationsEnabled,
        );

        // E-posta doğrulama linki gönder
        try {
          await user.sendEmailVerification();
          debugPrint('AuthService: Verification email sent to $email');
        } catch (e) {
          debugPrint('AuthService: Could not send verification email: $e');
          // Doğrulama maili gönderilemese bile kayıt başarılı sayılır
        }

        return {'success': true, 'user': user, 'emailSent': true};
      }

      return {'success': false, 'error': 'Kullanici olusturulamadi'};
    } on FirebaseAuthException catch (e) {
      String errorMessage;
      switch (e.code) {
        case 'weak-password':
          errorMessage = 'Şifre çok zayıf';
          break;
        case 'email-already-in-use':
          errorMessage = 'Bu e-posta adresi zaten kullanımda. Lütfen giriş yapın.';
          break;
        case 'invalid-email':
          errorMessage = 'Geçersiz e-posta adresi';
          break;
        default:
          errorMessage = 'Bir hata oluştu: ${e.message}';
      }
      return {'success': false, 'error': errorMessage};
    } catch (e) {
      String errorStr = e.toString();
      if (errorStr.contains('network')) {
        return {'success': false, 'error': 'İnternet bağlantısı yok'};
      } else if (errorStr.contains('email-already-in-use')) {
        return {'success': false, 'error': 'Bu e-posta adresi zaten kullanımda. Lütfen giriş yapın.'};
      }
      return {'success': false, 'error': 'Kayıt hatası. Lütfen tekrar deneyin.'};
    }
  }

  // Giriş yap
  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    try {
      UserCredential result = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      User? user = result.user;

      if (user != null) {
        // Save FCM token on successful login
        await _notificationService.saveTokenToFirestore(user.uid);
        _notificationService.listenToTokenRefresh(user.uid);
        return {'success': true, 'user': user};
      }

      return {'success': false, 'error': 'Giriş yapılamadı'};
    } on FirebaseAuthException catch (e) {
      String errorMessage;
      switch (e.code) {
        case 'user-not-found':
          errorMessage = 'Bu e-posta ile kayıtlı kullanıcı bulunamadı';
          break;
        case 'wrong-password':
          errorMessage = 'Yanlış şifre';
          break;
        case 'invalid-email':
          errorMessage = 'Geçersiz e-posta adresi';
          break;
        case 'user-disabled':
          errorMessage = 'Bu hesap devre dışı bırakılmış';
          break;
        case 'invalid-credential':
          errorMessage = 'E-posta veya şifre hatalı';
          break;
        case 'network-request-failed':
          errorMessage = 'İnternet bağlantısı yok';
          break;
        case 'too-many-requests':
          errorMessage = 'Çok fazla deneme. Lütfen bekleyin';
          break;
        case 'operation-not-allowed':
          errorMessage = 'E-posta/şifre girişi etkin değil';
          break;
        default:
          errorMessage = 'Giriş hatası: ${e.code}';
      }
      return {'success': false, 'error': errorMessage};
    } catch (e) {
      // Detaylı hata mesajı
      String errorStr = e.toString();
      if (errorStr.contains('network')) {
        return {'success': false, 'error': 'İnternet bağlantısı yok'};
      } else if (errorStr.contains('invalid-credential') || errorStr.contains('INVALID_LOGIN_CREDENTIALS')) {
        return {'success': false, 'error': 'E-posta veya şifre hatalı'};
      } else if (errorStr.contains('user-not-found')) {
        return {'success': false, 'error': 'Bu e-posta ile kayıtlı kullanıcı yok'};
      }
      return {'success': false, 'error': 'Giriş hatası. Lütfen tekrar deneyin.'};
    }
  }

  // Çıkış yap
  Future<void> signOut() async {
    // Delete FCM token before signing out
    final user = _auth.currentUser;
    if (user != null) {
      await _notificationService.deleteTokenFromFirestore(user.uid);
    }

    // Clear all caches on logout
    await ProfileCacheService.instance.clearCache();
    await MessageCacheService().clearAllCache(); // Hive mesaj cache'ini temizle
    LikesRepository.clearCache();

    debugPrint('AuthService: Çıkış yapıldı - tüm cache temizlendi (Profil, Mesaj, Likes)');

    await _auth.signOut();
  }

  // Şifre sıfırlama e-postası gönder
  Future<Map<String, dynamic>> resetPassword({required String email}) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
      return {
        'success': true,
        'message': 'Şifre sıfırlama linki e-posta adresinize gönderildi'
      };
    } on FirebaseAuthException catch (e) {
      String errorMessage;
      switch (e.code) {
        case 'user-not-found':
          errorMessage = 'Bu e-posta ile kayıtlı kullanıcı bulunamadı';
          break;
        case 'invalid-email':
          errorMessage = 'Geçersiz e-posta adresi';
          break;
        default:
          errorMessage = 'Bir hata oluştu: ${e.message}';
      }
      return {'success': false, 'error': errorMessage};
    } catch (e) {
      return {'success': false, 'error': 'Bir hata oluştu: $e'};
    }
  }

  // Hesabı sil (HARD DELETE - Tüm veriler dahil)
  //
  // SIRALAMA KRİTİK - Race Condition Önleme:
  // 1. Şifre ile yeniden kimlik doğrulama
  // 2. userId'yi kaydet (Auth silinmeden önce)
  // 3. Storage temizliği (ÖNCE - Auth yetkisi gerekli)
  // 4. Firestore temizliği
  // 5. FCM token temizliği
  // 6. Firebase Auth hesabını sil (EN SON)
  Future<Map<String, dynamic>> deleteAccountWithData(String password) async {
    // İnternet bağlantısı kontrolü - EN BAŞTA!
    if (!await _checkInternetConnection()) {
      debugPrint('AuthService: İnternet bağlantısı yok - hesap silinemedi');
      return {
        'success': false,
        'error': 'İnternet bağlantınız yok. Lütfen bağlantınızı kontrol edin.',
      };
    }

    debugPrint('');
    debugPrint('╔══════════════════════════════════════════════════════════════╗');
    debugPrint('║         HESAP SİLME İŞLEMİ BAŞLIYOR                          ║');
    debugPrint('║         (HARD DELETE - TÜM VERİLER)                          ║');
    debugPrint('╚══════════════════════════════════════════════════════════════╝');

    try {
      // ════════════════════════════════════════════════════════════
      // ADIM 0: KULLANICI KONTROLÜ
      // ════════════════════════════════════════════════════════════
      debugPrint('\n┌─ ADIM 0: Kullanıcı Kontrolü');
      final user = _auth.currentUser;
      if (user == null) {
        debugPrint('│  ✗ HATA: Oturum açmış kullanıcı bulunamadı');
        return {'success': false, 'error': 'Kullanıcı bulunamadı'};
      }

      // KRİTİK: userId'yi şimdi kaydet, Auth silinmeden önce kullanacağız
      final String userId = user.uid;
      final String? userEmail = user.email;

      debugPrint('│  ✓ Kullanıcı bulundu');
      debugPrint('│    User ID: $userId');
      debugPrint('│    Email: $userEmail');
      debugPrint('└─────────────────────────────────────────────');

      // ════════════════════════════════════════════════════════════
      // ADIM 1: ŞİFRE İLE YENİDEN KİMLİK DOĞRULAMA
      // ════════════════════════════════════════════════════════════
      debugPrint('\n┌─ ADIM 1: Kimlik Doğrulama (Re-Authentication)');
      debugPrint('│  → Şifre ile doğrulanıyor...');

      try {
        final credential = EmailAuthProvider.credential(
          email: userEmail!,
          password: password,
        );
        await user.reauthenticateWithCredential(credential);
        debugPrint('│  ✓ Kimlik doğrulama BAŞARILI');
        debugPrint('└─────────────────────────────────────────────');
      } on FirebaseAuthException catch (e) {
        debugPrint('│  ✗ Kimlik doğrulama HATASI: ${e.code}');
        debugPrint('└─────────────────────────────────────────────');

        String errorMessage;
        switch (e.code) {
          case 'wrong-password':
          case 'invalid-credential':
            errorMessage = 'Yanlış şifre';
            break;
          case 'requires-recent-login':
            errorMessage = 'Güvenlik nedeniyle tekrar giriş yapmanız gerekiyor';
            break;
          case 'too-many-requests':
            errorMessage = 'Çok fazla deneme. Lütfen bekleyin';
            break;
          default:
            errorMessage = 'Kimlik doğrulama hatası: ${e.code}';
        }
        return {'success': false, 'error': errorMessage};
      }

      // ════════════════════════════════════════════════════════════
      // ADIM 2: TÜM VERİLERİ SİL (Storage + Firestore)
      // ════════════════════════════════════════════════════════════
      debugPrint('\n┌─ ADIM 2: Veri Temizliği (Storage + Firestore)');
      debugPrint('│  → UserService.deleteUserEntireData çağrılıyor...');
      debugPrint('│  → User ID: $userId');
      debugPrint('│');

      // KRİTİK: Bu işlem TAMAMEN bitmeden devam etme!
      Map<String, dynamic> deleteResult = {};
      try {
        deleteResult = await _userService.deleteUserEntireData(userId);

        debugPrint('│');
        debugPrint('│  ✓ Veri temizliği tamamlandı');
        debugPrint('│    Sonuç: ${deleteResult['success'] == true ? 'BAŞARILI' : 'HATALI'}');
        debugPrint('│    Silinen fotoğraf: ${deleteResult['deletedPhotos']}');
        debugPrint('│    Silinen eşleşme: ${deleteResult['deletedMatches']}');
        debugPrint('│    Silinen sohbet: ${deleteResult['deletedChats']}');
        debugPrint('│    Silinen mesaj: ${deleteResult['deletedMessages']}');
        debugPrint('│    Hatalar: ${deleteResult['errors']}');
        debugPrint('└─────────────────────────────────────────────');
      } catch (e) {
        debugPrint('│  ⚠ Veri temizliği sırasında hata (devam ediliyor): $e');
        debugPrint('└─────────────────────────────────────────────');
        deleteResult = {'success': false, 'error': e.toString()};
      }

      // ════════════════════════════════════════════════════════════
      // ADIM 3: FCM TOKEN SİL
      // ════════════════════════════════════════════════════════════
      debugPrint('\n┌─ ADIM 3: FCM Token Temizliği');
      try {
        await _notificationService.deleteTokenFromFirestore(userId);
        debugPrint('│  ✓ FCM token silindi');
      } catch (e) {
        debugPrint('│  ⚠ FCM token silinemedi (kritik değil): $e');
      }
      debugPrint('└─────────────────────────────────────────────');

      // ════════════════════════════════════════════════════════════
      // ADIM 4: FİREBASE AUTH HESABINI SİL (EN SON!)
      // ════════════════════════════════════════════════════════════
      debugPrint('\n┌─ ADIM 4: Firebase Auth Hesabını Sil');
      debugPrint('│  → Auth hesabı siliniyor...');

      try {
        // KRİTİK: Bu noktada tüm veriler silinmiş olmalı
        await user.delete();
        debugPrint('│  ✓ Firebase Auth hesabı SİLİNDİ');
        debugPrint('└─────────────────────────────────────────────');
      } on FirebaseAuthException catch (e) {
        debugPrint('│  ✗ Auth silme HATASI: ${e.code}');
        debugPrint('└─────────────────────────────────────────────');

        if (e.code == 'requires-recent-login') {
          return {
            'success': false,
            'error': 'Güvenlik nedeniyle tekrar giriş yapmanız gerekiyor',
            'requiresReauth': true,
          };
        }
        return {'success': false, 'error': 'Hesap silinemedi: ${e.code}'};
      }

      // ════════════════════════════════════════════════════════════
      // BAŞARILI SONUÇ
      // ════════════════════════════════════════════════════════════
      debugPrint('');
      debugPrint('╔══════════════════════════════════════════════════════════════╗');
      debugPrint('║         ✅ HESAP BAŞARIYLA SİLİNDİ                           ║');
      debugPrint('╚══════════════════════════════════════════════════════════════╝');
      debugPrint('');

      return {
        'success': true,
        'deletedData': deleteResult,
      };

    } catch (e, stackTrace) {
      debugPrint('');
      debugPrint('╔══════════════════════════════════════════════════════════════╗');
      debugPrint('║         ❌ HESAP SİLME HATASI                                ║');
      debugPrint('╠══════════════════════════════════════════════════════════════╣');
      debugPrint('║  Error: $e');
      debugPrint('║  Stack: $stackTrace');
      debugPrint('╚══════════════════════════════════════════════════════════════╝');

      return {'success': false, 'error': 'Hesap silinemedi: $e'};
    }
  }

  // Eski metod (geriye uyumluluk için korunuyor)
  @Deprecated('Use deleteAccountWithData instead for complete data cleanup')
  Future<void> deleteAccount(String password) async {
    final result = await deleteAccountWithData(password);
    if (result['success'] != true) {
      throw Exception(result['error'] ?? 'Hesap silinemedi');
    }
  }
}
