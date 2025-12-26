import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Mevcut kullanıcıyı al
  User? get currentUser => _auth.currentUser;

  // Auth durumunu dinle
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Kayıt ol
  Future<Map<String, dynamic>> register({
    required String email,
    required String password,
  }) async {
    try {
      UserCredential result = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      User? user = result.user;

      if (user != null) {
        return {'success': true, 'user': user};
      }

      return {'success': false, 'error': 'Kullanici olusturulamadi'};
    } on FirebaseAuthException catch (e) {
      String errorMessage;
      switch (e.code) {
        case 'weak-password':
          errorMessage = 'Şifre çok zayıf';
          break;
        case 'email-already-in-use':
          errorMessage = 'Bu e-posta zaten kullanımda';
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
        return {'success': false, 'error': 'Bu e-posta zaten kullanımda'};
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

  // Hesabı sil
  Future<void> deleteAccount(String password) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw Exception('Kullanıcı bulunamadı');
      }

      // Önce yeniden kimlik doğrulama yap
      final credential = EmailAuthProvider.credential(
        email: user.email!,
        password: password,
      );
      await user.reauthenticateWithCredential(credential);

      // Hesabı sil
      await user.delete();
    } on FirebaseAuthException catch (e) {
      String errorMessage;
      switch (e.code) {
        case 'wrong-password':
          errorMessage = 'Yanlış şifre';
          break;
        case 'requires-recent-login':
          errorMessage = 'Lütfen tekrar giriş yapın';
          break;
        default:
          errorMessage = 'Bir hata oluştu: ${e.message}';
      }
      throw Exception(errorMessage);
    } catch (e) {
      throw Exception('Hesap silinemedi: $e');
    }
  }
}
