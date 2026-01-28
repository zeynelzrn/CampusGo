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

  /// Premium ozelliklerini listele (UI icin)
  /// 
  /// Bu liste PremiumOfferScreen'de gosterilir.
  static List<Map<String, dynamic>> get premiumFeatures => [
        {
          'icon': '💖',
          'title': 'Sinirsiz Beğeni',
          'description': 'Istedigin kadar kisiye super like gonder',
        },
        {
          'icon': '👁️',
          'title': 'Kimin Begendini Gor',
          'description': 'Seni kim begendi, hepsini gor',
        },
        {
          'icon': '⚡',
          'title': 'Oncelikli Gosterim',
          'description': 'Profilin daha cok kisiye gosterilir',
        },
        {
          'icon': '🔄',
          'title': 'Sinirsiz Geri Al',
          'description': 'Yanlis swipe\'lari geri al',
        },
        {
          'icon': '🎯',
          'title': 'Gelismis Filtreler',
          'description': 'Universite, bolum ve ilgi alanlarina gore filtrele',
        },
        {
          'icon': '👑',
          'title': 'Premium Rozet',
          'description': 'Profilinde ozel premium rozeti gorun',
        },
        {
          'icon': '🚫',
          'title': 'Reklamsiz Deneyim',
          'description': 'Hic reklam gormeden kesfet',
        },
        {
          'icon': '📍',
          'title': 'Konum Degistir',
          'description': 'Istedigin kampuste kesfet',
        },
      ];
}
