import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// RevenueCat In-App Purchase Service
/// 
/// Apple/Google Store uzerinden abonelik yonetimi icin RevenueCat SDK wrapper'i.
/// Premium ozellikleri unlock etmek icin kullanilir.
class PurchaseService {
  // Singleton pattern
  static final PurchaseService _instance = PurchaseService._internal();
  factory PurchaseService() => _instance;
  PurchaseService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // RevenueCat API Keys (Apple onayindan sonra guncelle)
  static const String _appleApiKey = 'rc_placeholder_apple_key';
  static const String _googleApiKey = 'rc_placeholder_google_key';
  
  // Premium entitlement identifier (RevenueCat Dashboard'dan gelecek)
  static const String _premiumEntitlementId = 'premium';

  // Initialization state
  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;

  /// RevenueCat SDK'yi baslat
  /// 
  /// Bu metod app baslarken (main.dart) cagirilmalidir.
  /// 
  /// ```dart
  /// await PurchaseService().initialize();
  /// ```
  Future<void> initialize() async {
    if (_isInitialized) {
      debugPrint('PurchaseService: Already initialized');
      return;
    }

    try {
      debugPrint('PurchaseService: Initializing RevenueCat...');

      // Platform'a gore API key sec ve configure et
      if (Platform.isIOS || Platform.isMacOS) {
        await Purchases.configure(PurchasesConfiguration(_appleApiKey));
      } else if (Platform.isAndroid) {
        await Purchases.configure(PurchasesConfiguration(_googleApiKey));
      } else {
        debugPrint('PurchaseService: Platform not supported for purchases');
        return;
      }

      // Kullanici ID'sini ayarla (Firebase Auth UID)
      final user = _auth.currentUser;
      if (user != null) {
        await Purchases.logIn(user.uid);
        debugPrint('PurchaseService: Logged in user ${user.uid}');
      }

      // Debug logs
      await Purchases.setLogLevel(kDebugMode ? LogLevel.debug : LogLevel.info);

      _isInitialized = true;
      debugPrint('PurchaseService: ✅ Initialized successfully');

      // Baslangicta subscription durumunu kontrol et
      await checkSubscriptionStatus();
    } on PlatformException catch (e) {
      debugPrint('PurchaseService: ❌ Platform error: ${e.message}');
      debugPrint('PurchaseService: Error code: ${e.code}');
    } catch (e) {
      debugPrint('PurchaseService: ❌ Initialization error: $e');
    }
  }

  /// Kullaniciyi RevenueCat'e login yap (Firebase UID ile)
  /// 
  /// Authentication state degistiginde cagirilmalidir.
  Future<void> loginUser(String userId) async {
    if (!_isInitialized) {
      debugPrint('PurchaseService: Not initialized, cannot login user');
      return;
    }

    try {
      await Purchases.logIn(userId);
      debugPrint('PurchaseService: User logged in: $userId');
      
      // Login sonrasi subscription durumunu kontrol et
      await checkSubscriptionStatus();
    } catch (e) {
      debugPrint('PurchaseService: Error logging in user: $e');
    }
  }

  /// Kullaniciyi RevenueCat'ten logout yap
  Future<void> logoutUser() async {
    if (!_isInitialized) return;

    try {
      await Purchases.logOut();
      debugPrint('PurchaseService: User logged out');
    } catch (e) {
      debugPrint('PurchaseService: Error logging out user: $e');
    }
  }

  /// Mevcut offerings (abonelik paketleri) listesini getir
  /// 
  /// Returns:
  /// - Offerings nesnesi (paketler ve fiyatlar)
  /// - Hata durumunda null
  /// 
  /// Ornek kullanim:
  /// ```dart
  /// final offerings = await PurchaseService().getOfferings();
  /// if (offerings != null && offerings.current != null) {
  ///   final packages = offerings.current!.availablePackages;
  ///   for (final package in packages) {
  ///     print('${package.storeProduct.title}: ${package.storeProduct.priceString}');
  ///   }
  /// }
  /// ```
  Future<Offerings?> getOfferings() async {
    if (!_isInitialized) {
      debugPrint('PurchaseService: Not initialized, cannot fetch offerings');
      return null;
    }

    try {
      debugPrint('PurchaseService: Fetching offerings...');
      final offerings = await Purchases.getOfferings();
      
      if (offerings.current != null) {
        debugPrint('PurchaseService: Found ${offerings.current!.availablePackages.length} packages');
        for (final package in offerings.current!.availablePackages) {
          debugPrint('  - ${package.identifier}: ${package.storeProduct.priceString}');
        }
      } else {
        debugPrint('PurchaseService: No current offering found');
      }

      return offerings;
    } on PlatformException catch (e) {
      debugPrint('PurchaseService: Error fetching offerings: ${e.message}');
      return null;
    } catch (e) {
      debugPrint('PurchaseService: Error fetching offerings: $e');
      return null;
    }
  }

  /// Belirli bir paketi satin al
  /// 
  /// Parameters:
  /// - package: RevenueCat Package nesnesi
  /// 
  /// Returns:
  /// - success: Basarili mi?
  /// - isPremium: Premium aktif mi?
  /// - error: Hata mesaji (varsa)
  /// 
  /// Ornek kullanim:
  /// ```dart
  /// final result = await PurchaseService().purchasePackage(package);
  /// if (result['success']) {
  ///   print('Satin alma basarili!');
  /// } else {
  ///   print('Hata: ${result['error']}');
  /// }
  /// ```
  Future<Map<String, dynamic>> purchasePackage(Package package) async {
    if (!_isInitialized) {
      return {
        'success': false,
        'isPremium': false,
        'error': 'Purchase service not initialized'
      };
    }

    try {
      debugPrint('PurchaseService: Attempting to purchase ${package.identifier}...');
      
      final customerInfo = await Purchases.purchasePackage(package);
      
      // Premium entitlement var mi kontrol et
      final isPremium = customerInfo.entitlements.all[_premiumEntitlementId]?.isActive ?? false;
      
      if (isPremium) {
        debugPrint('PurchaseService: ✅ Purchase successful! Premium activated.');
        
        // Firestore'da isPremium flag'ini guncelle
        await _updatePremiumStatus(true);
        
        return {
          'success': true,
          'isPremium': true,
          'customerInfo': customerInfo,
        };
      } else {
        debugPrint('PurchaseService: ⚠️ Purchase completed but premium not active');
        return {
          'success': false,
          'isPremium': false,
          'error': 'Purchase completed but premium not activated'
        };
      }
    } on PlatformException catch (e) {
      final errorCode = PurchasesErrorHelper.getErrorCode(e);
      
      String errorMessage;
      switch (errorCode) {
        case PurchasesErrorCode.purchaseCancelledError:
          errorMessage = 'Satin alma iptal edildi';
          debugPrint('PurchaseService: User cancelled the purchase');
          break;
        case PurchasesErrorCode.purchaseNotAllowedError:
          errorMessage = 'Satin alma izni yok';
          debugPrint('PurchaseService: Purchase not allowed');
          break;
        case PurchasesErrorCode.paymentPendingError:
          errorMessage = 'Odeme beklemede';
          debugPrint('PurchaseService: Payment pending');
          break;
        case PurchasesErrorCode.networkError:
          errorMessage = 'Internet baglantisi hatasi';
          debugPrint('PurchaseService: Network error');
          break;
        default:
          errorMessage = 'Satin alma basarisiz: ${e.message}';
          debugPrint('PurchaseService: Purchase error: ${e.message}');
      }

      return {
        'success': false,
        'isPremium': false,
        'error': errorMessage,
        'errorCode': errorCode,
      };
    } catch (e) {
      debugPrint('PurchaseService: Unexpected error during purchase: $e');
      return {
        'success': false,
        'isPremium': false,
        'error': 'Beklenmeyen bir hata olustu'
      };
    }
  }

  /// Satin alimlari geri yukle (Restore Purchases)
  /// 
  /// Kullanici yeni cihazda veya app yeniden yuklediginde
  /// onceki satin alimlarini geri yuklemek icin kullanilir.
  /// 
  /// Returns:
  /// - success: Basarili mi?
  /// - isPremium: Premium aktif mi?
  /// - restoredCount: Kac tane aktif subscription bulundu
  Future<Map<String, dynamic>> restorePurchases() async {
    if (!_isInitialized) {
      return {
        'success': false,
        'isPremium': false,
        'error': 'Purchase service not initialized'
      };
    }

    try {
      debugPrint('PurchaseService: Restoring purchases...');
      
      final customerInfo = await Purchases.restorePurchases();
      
      // Premium entitlement var mi kontrol et
      final isPremium = customerInfo.entitlements.all[_premiumEntitlementId]?.isActive ?? false;
      
      // Aktif subscription sayisi
      final activeEntitlements = customerInfo.entitlements.all.values
          .where((e) => e.isActive)
          .length;
      
      if (isPremium) {
        debugPrint('PurchaseService: ✅ Premium restored successfully!');
        
        // Firestore'da isPremium flag'ini guncelle
        await _updatePremiumStatus(true);
        
        return {
          'success': true,
          'isPremium': true,
          'restoredCount': activeEntitlements,
        };
      } else {
        debugPrint('PurchaseService: No active premium subscription found');
        
        // Firestore'da isPremium flag'ini false yap
        await _updatePremiumStatus(false);
        
        return {
          'success': true,
          'isPremium': false,
          'restoredCount': 0,
        };
      }
    } on PlatformException catch (e) {
      debugPrint('PurchaseService: Error restoring purchases: ${e.message}');
      return {
        'success': false,
        'isPremium': false,
        'error': 'Geri yukleme basarisiz: ${e.message}'
      };
    } catch (e) {
      debugPrint('PurchaseService: Unexpected error during restore: $e');
      return {
        'success': false,
        'isPremium': false,
        'error': 'Beklenmeyen bir hata olustu'
      };
    }
  }

  /// Kullanicinin subscription durumunu kontrol et
  /// 
  /// Returns:
  /// - isPremium: Premium aktif mi?
  /// - expirationDate: Son kullanma tarihi (varsa)
  /// - willRenew: Otomatik yenilenecek mi?
  /// 
  /// Bu metod app acilistinda ve satin alma/geri yukleme sonrasi cagirilir.
  Future<Map<String, dynamic>> checkSubscriptionStatus() async {
    if (!_isInitialized) {
      debugPrint('PurchaseService: Not initialized, cannot check status');
      return {'isPremium': false};
    }

    try {
      debugPrint('PurchaseService: Checking subscription status...');
      
      final customerInfo = await Purchases.getCustomerInfo();
      final entitlement = customerInfo.entitlements.all[_premiumEntitlementId];
      
      if (entitlement != null && entitlement.isActive) {
        debugPrint('PurchaseService: ✅ Premium is ACTIVE');
        debugPrint('  - Product ID: ${entitlement.productIdentifier}');
        debugPrint('  - Expires: ${entitlement.expirationDate}');
        debugPrint('  - Will Renew: ${entitlement.willRenew}');
        
        // Firestore'da isPremium flag'ini guncelle
        await _updatePremiumStatus(true);
        
        // AUTO-RENEWAL RESET: Abonelik yenilendiğinde Rewind Rights'ı sıfırla
        await _checkAndResetRewindRights(customerInfo, entitlement);
        
        return {
          'isPremium': true,
          'expirationDate': entitlement.expirationDate,
          'willRenew': entitlement.willRenew,
          'productId': entitlement.productIdentifier,
        };
      } else {
        debugPrint('PurchaseService: Premium is NOT active');
        
        // Firestore'da isPremium flag'ini false yap
        await _updatePremiumStatus(false);
        
        return {'isPremium': false};
      }
    } on PlatformException catch (e) {
      debugPrint('PurchaseService: Error checking status: ${e.message}');
      return {'isPremium': false};
    } catch (e) {
      debugPrint('PurchaseService: Error checking status: $e');
      return {'isPremium': false};
    }
  }

  /// Kullanicinin premium durumunu hemen kontrol et (cache'den)
  /// 
  /// Bu metod Firestore'a gitmeyen hizli bir kontrol icin kullanilir.
  Future<bool> isPremiumUser() async {
    if (!_isInitialized) return false;

    try {
      final customerInfo = await Purchases.getCustomerInfo();
      return customerInfo.entitlements.all[_premiumEntitlementId]?.isActive ?? false;
    } catch (e) {
      debugPrint('PurchaseService: Error checking premium status: $e');
      return false;
    }
  }

  /// Firestore'da kullanicinin isPremium flag'ini guncelle
  /// 
  /// Bu sayede profil verisi premium durumunu yansitir.
  Future<void> _updatePremiumStatus(bool isPremium) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        debugPrint('PurchaseService: No user logged in, cannot update Firestore');
        return;
      }

      await _firestore.collection('users').doc(user.uid).update({
        'isPremium': isPremium,
        'premiumUpdatedAt': FieldValue.serverTimestamp(),
      });

      debugPrint('PurchaseService: Firestore updated - isPremium: $isPremium');
    } catch (e) {
      debugPrint('PurchaseService: Error updating Firestore: $e');
    }
  }

  /// Abonelik yenilendiğinde Rewind Rights'ı otomatik sıfırla
  /// 
  /// Bu metod her uygulama açılışında çağrılır ve şu mantıkla çalışır:
  /// 1. RevenueCat'ten son satın alma tarihini al
  /// 2. Firestore'dan son reset tarihini al
  /// 3. Eğer yeni bir ödeme yapılmışsa (veya ilk kez alınmışsa), hakları 5'e sıfırla
  /// 4. Bu sayede abonelik yenilendiğinde otomatik olarak haklar yenilenir
  Future<void> _checkAndResetRewindRights(
    CustomerInfo customerInfo,
    EntitlementInfo entitlement,
  ) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        debugPrint('PurchaseService: No user logged in, cannot reset rewind rights');
        return;
      }

      // ADIM 1: RevenueCat'ten son satın alma tarihini al
      // latestPurchaseDate: En son yapılan ödemenin tarihi (yenileme dahil)
      // Not: RevenueCat bu tarihi ISO 8601 String formatında döner
      final latestPurchaseDateStr = entitlement.latestPurchaseDate;
      final originalPurchaseDateStr = entitlement.originalPurchaseDate;
      
      // En son satın alma tarihini parse et (varsa latestPurchaseDate, yoksa originalPurchaseDate)
      DateTime? purchaseDateTime;
      
      // latestPurchaseDate kullan (en son ödeme tarihi - yenilemeler dahil)
      try {
        purchaseDateTime = DateTime.parse(latestPurchaseDateStr);
        debugPrint('PurchaseService: Using latestPurchaseDate: $purchaseDateTime');
      } catch (e) {
        debugPrint('PurchaseService: Error parsing latestPurchaseDate: $e');
        
        // Fallback: originalPurchaseDate kullan (ilk satın alma)
        try {
          purchaseDateTime = DateTime.parse(originalPurchaseDateStr);
          debugPrint('PurchaseService: Using originalPurchaseDate: $purchaseDateTime');
        } catch (e2) {
          debugPrint('PurchaseService: Error parsing originalPurchaseDate: $e2');
        }
      }
      
      if (purchaseDateTime == null) {
        debugPrint('PurchaseService: No valid purchase date found, skipping reset');
        return;
      }

      // ADIM 2: Firestore'dan son reset tarihini al
      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      
      if (!userDoc.exists) {
        debugPrint('PurchaseService: User document does not exist, skipping reset');
        return;
      }

      final userData = userDoc.data();
      final lastRewindResetDate = (userData?['lastRewindResetDate'] as Timestamp?)?.toDate();
      
      debugPrint('PurchaseService: 🔍 Checking renewal cycle...');
      debugPrint('  - Purchase Date: $purchaseDateTime');
      debugPrint('  - Last Reset Date: $lastRewindResetDate');

      // ADIM 3: Karşılaştırma Mantığı (Cycle Check)
      bool shouldReset = false;
      
      if (lastRewindResetDate == null) {
        // İlk kez Premium alınmış, henüz reset yapılmamış
        debugPrint('PurchaseService: ✨ First time premium - resetting rights');
        shouldReset = true;
      } else if (purchaseDateTime.isAfter(lastRewindResetDate)) {
        // Yeni bir ödeme yapılmış (abonelik yenilenmiş)
        debugPrint('PurchaseService: 🔄 Subscription renewed - resetting rights');
        shouldReset = true;
      } else {
        debugPrint('PurchaseService: ✅ No renewal detected, keeping current rights');
      }

      // ADIM 4: Gerekiyorsa Firestore'u Güncelle
      if (shouldReset) {
        await _firestore.collection('users').doc(user.uid).update({
          'monthlyRewindRights': 5, // Her yeni döngüde 5 hak ver
          'lastRewindResetDate': FieldValue.serverTimestamp(), // Reset zamanını güncelle
        });

        debugPrint('PurchaseService: ✅ Rewind rights reset to 5/5');
      }
    } catch (e) {
      debugPrint('PurchaseService: ⚠️ Error resetting rewind rights: $e');
      // Hata olsa bile uygulama çalışmaya devam etsin (silent fail)
    }
  }

  /// Firebase tabanlı aylık hak sıfırlama kontrolü (RevenueCat'ten bağımsız)
  /// 
  /// Bu metod her uygulama açılışında çağrılmalıdır.
  /// RevenueCat çalışmasa bile (test ortamı, placeholder key vb.) Firebase'den
  /// isPremium kontrolü yaparak 30 günlük döngüde hakları sıfırlar.
  /// 
  /// Çağrılacak yer: main.dart veya AuthWrapper (login sonrası)
  Future<void> checkAndResetMonthlyRights() async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        debugPrint('PurchaseService: No user logged in, skipping monthly reset check');
        return;
      }

      // Firebase'den kullanıcı verisini al
      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      
      if (!userDoc.exists) {
        debugPrint('PurchaseService: User document does not exist, skipping monthly reset check');
        return;
      }

      final userData = userDoc.data();
      if (userData == null) return;

      final isPremium = userData['isPremium'] as bool? ?? false;
      
      // Sadece Premium kullanıcılar için kontrol yap
      if (!isPremium) {
        debugPrint('PurchaseService: User is not premium, skipping monthly reset check');
        return;
      }

      final lastResetDate = (userData['lastRewindResetDate'] as Timestamp?)?.toDate();
      final now = DateTime.now();
      
      debugPrint('PurchaseService: 🔍 Checking monthly cycle (Firebase-based)...');
      debugPrint('  - Current Premium Status: $isPremium');
      debugPrint('  - Last Reset Date: $lastResetDate');
      debugPrint('  - Current Date: $now');

      bool shouldReset = false;
      
      if (lastResetDate == null) {
        // İlk kez Premium alınmış veya henüz reset yapılmamış
        debugPrint('PurchaseService: ✨ First time premium detected (no reset date) - resetting rights');
        shouldReset = true;
      } else {
        // 30 gün geçmiş mi kontrol et
        final daysSinceReset = now.difference(lastResetDate).inDays;
        debugPrint('  - Days since last reset: $daysSinceReset');
        
        if (daysSinceReset >= 30) {
          // 30 gün geçmiş, yeni döngü başlatılmalı
          debugPrint('PurchaseService: 🔄 Monthly cycle completed (30+ days) - resetting rights');
          shouldReset = true;
        } else {
          debugPrint('PurchaseService: ✅ Within monthly cycle ($daysSinceReset/30 days), keeping current rights');
        }
      }

      // Gerekiyorsa hakları sıfırla
      if (shouldReset) {
        await _firestore.collection('users').doc(user.uid).update({
          'monthlyRewindRights': 5, // 5 hak ver
          'lastRewindResetDate': FieldValue.serverTimestamp(), // Reset zamanını güncelle
        });

        debugPrint('PurchaseService: ✅ Monthly rewind rights reset to 5/5');
      }
    } catch (e) {
      debugPrint('PurchaseService: ⚠️ Error in monthly reset check: $e');
      // Silent fail - uygulama çalışmaya devam etsin
    }
  }

  /// Premium ozelliklerini listele (UI icin)
  /// 
  /// Bu liste PremiumOfferScreen'de gosterilir.
  static List<Map<String, dynamic>> get premiumFeatures => [
        {
          'icon': '💖',
          'title': 'Sınırsız Beğeni',
          'description': 'İstediğin kadar kişiye beğeni gönder',
        },
        {
          'icon': '👁️',
          'title': 'Kimin İstek Attığını Gör',
          'description': 'Sana kim istek attı, hepsini gör ve onlarla eşleş',
        },
        {
          'icon': '⚡',
          'title': 'Öncelikli Gösterim',
          'description': 'Profilin daha çok kişiye gösterilir',
        },
        {
          'icon': '🔄',
          'title': '5 Geri Al Hakkı',
          'description': 'Yanlış kaydırdıklarını ayda 5 kez geri al',
        },
        {
          'icon': '🎯',
          'title': 'Gelişmiş Filtreler',
          'description': "Üniversite, bölüm ve il'e göre filtrele",
        },
      ];
}
