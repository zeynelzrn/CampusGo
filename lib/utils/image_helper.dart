import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart' show getTemporaryDirectory;
import 'package:path/path.dart' as path;
import 'package:permission_handler/permission_handler.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:shimmer/shimmer.dart';

// ==================== GLOBAL CACHE MANAGER ====================

/// 7 gün önbellekleme süreli global cache manager
/// Tüm uygulama genelinde kullanılır
class AppCacheManager {
  static const key = 'campusgo_image_cache';

  static CacheManager? _instance;

  static CacheManager get instance {
    _instance ??= CacheManager(
      Config(
        key,
        stalePeriod: const Duration(days: 7), // 7 gün önbellekleme
        maxNrOfCacheObjects: 500, // Maksimum 500 görsel
        repo: JsonCacheInfoRepository(databaseName: key),
        fileService: HttpFileService(),
      ),
    );
    return _instance!;
  }

  /// Yüksek öncelikli cache manager (kullanıcı profil fotoğrafları için)
  static CacheManager? _highPriorityInstance;

  static CacheManager get highPriorityInstance {
    _highPriorityInstance ??= CacheManager(
      Config(
        '${key}_high_priority',
        stalePeriod: const Duration(days: 30), // 30 gün önbellekleme
        maxNrOfCacheObjects: 100, // Maksimum 100 görsel
        repo: JsonCacheInfoRepository(databaseName: '${key}_high_priority'),
        fileService: HttpFileService(),
      ),
    );
    return _highPriorityInstance!;
  }

  /// Önbelleği temizle
  static Future<void> clearCache() async {
    await _instance?.emptyCache();
    await _highPriorityInstance?.emptyCache();
  }
}

// ==================== CACHED IMAGE WIDGET BUILDERS ====================

/// Standart önbellekli görsel widget'ı (Shimmer placeholder ile)
/// Tüm uygulama genelinde kullanılacak
Widget buildCachedImage({
  required String imageUrl,
  BoxFit fit = BoxFit.cover,
  double? width,
  double? height,
  BorderRadius? borderRadius,
  bool highPriority = false,
  Color shimmerBaseColor = const Color(0xFFE0E0E0),
  Color shimmerHighlightColor = const Color(0xFFF5F5F5),
  IconData placeholderIcon = Icons.person,
  double iconSize = 60,
}) {
  final cacheManager = highPriority
      ? AppCacheManager.highPriorityInstance
      : AppCacheManager.instance;

  Widget shimmerPlaceholder() {
    return Shimmer.fromColors(
      baseColor: shimmerBaseColor,
      highlightColor: shimmerHighlightColor,
      child: Container(
        width: width,
        height: height,
        color: shimmerBaseColor,
        child: Center(
          child: Icon(
            placeholderIcon,
            size: iconSize,
            color: shimmerHighlightColor,
          ),
        ),
      ),
    );
  }

  Widget image = CachedNetworkImage(
    imageUrl: imageUrl,
    fit: fit,
    width: width,
    height: height,
    cacheManager: cacheManager,
    placeholder: (context, url) => shimmerPlaceholder(),
    errorWidget: (context, url, error) => shimmerPlaceholder(),
    fadeInDuration: const Duration(milliseconds: 300),
    fadeOutDuration: const Duration(milliseconds: 300),
  );

  if (borderRadius != null) {
    return ClipRRect(
      borderRadius: borderRadius,
      child: image,
    );
  }

  return image;
}

/// Profil fotoğrafı için özel widget (yüksek öncelikli önbellekleme)
Widget buildProfileImage({
  required String imageUrl,
  BoxFit fit = BoxFit.cover,
  double? width,
  double? height,
  BorderRadius? borderRadius,
}) {
  return buildCachedImage(
    imageUrl: imageUrl,
    fit: fit,
    width: width,
    height: height,
    borderRadius: borderRadius,
    highPriority: true,
    shimmerBaseColor: const Color(0xFF5C6BC0),
    shimmerHighlightColor: const Color(0xFF7986CB),
    placeholderIcon: Icons.person,
    iconSize: 80,
  );
}

/// Avatar için özel widget (küçük boyutlu)
Widget buildAvatarImage({
  required String imageUrl,
  double size = 56,
  bool highPriority = false,
}) {
  return ClipOval(
    child: buildCachedImage(
      imageUrl: imageUrl,
      fit: BoxFit.cover,
      width: size,
      height: size,
      highPriority: highPriority,
      iconSize: size * 0.5,
    ),
  );
}

/// Swipe kartı için özel widget (tam ekran)
Widget buildSwipeCardImage({
  required String imageUrl,
  BoxFit fit = BoxFit.cover,
}) {
  return buildCachedImage(
    imageUrl: imageUrl,
    fit: fit,
    shimmerBaseColor: Colors.grey[300]!,
    shimmerHighlightColor: Colors.grey[100]!,
    iconSize: 80,
  );
}

/// Resim sikistirma, secme ve izin yonetimi icin yardimci sinif
class ImageHelper {
  ImageHelper._();

  static final ImagePicker _picker = ImagePicker();

  /// Varsayilan sikistirma ayarlari
  static const int defaultMinWidth = 1080;
  static const int defaultMinHeight = 1080;
  static const int defaultQuality = 85;

  // ==================== IZIN YONETIMI ====================

  /// Galeri izni iste (Android 13+ ve eski surumleri destekler)
  static Future<bool> requestGalleryPermission() async {
    PermissionStatus status;

    // Android 13+ icin photos izni, eski surumlerde storage
    if (Platform.isAndroid) {
      // Oncelikle photos iznini dene (Android 13+)
      status = await Permission.photos.request();

      // Eger photos izni yoksa (eski Android), storage dene
      if (status.isDenied || status.isPermanentlyDenied) {
        status = await Permission.storage.request();
      }
    } else {
      // iOS icin photos izni
      status = await Permission.photos.request();
    }

    return status.isGranted || status.isLimited;
  }

  /// Kamera izni iste
  static Future<bool> requestCameraPermission() async {
    final status = await Permission.camera.request();
    return status.isGranted;
  }

  /// Izin durumunu kontrol et ve gerekirse ayarlara yonlendir
  static Future<bool> checkAndRequestPermission(
    BuildContext context,
    ImageSource source,
  ) async {
    bool hasPermission;

    if (source == ImageSource.camera) {
      hasPermission = await requestCameraPermission();
    } else {
      hasPermission = await requestGalleryPermission();
    }

    if (!hasPermission && context.mounted) {
      // Kullaniciya izin gerektigini bildir
      final shouldOpenSettings = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(source == ImageSource.camera ? 'Kamera Izni' : 'Galeri Izni'),
          content: Text(
            source == ImageSource.camera
                ? 'Fotograf cekmek icin kamera iznine ihtiyacimiz var. Ayarlardan izin verebilirsiniz.'
                : 'Fotograf secmek icin galeri iznine ihtiyacimiz var. Ayarlardan izin verebilirsiniz.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Iptal'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Ayarlara Git'),
            ),
          ],
        ),
      );

      if (shouldOpenSettings == true) {
        await openAppSettings();
      }
      return false;
    }

    return hasPermission;
  }

  // ==================== RESIM SECME ====================

  /// Galeriden veya kameradan resim sec (izin kontrolu dahil)
  /// Secilen resim otomatik olarak sikistirilir
  static Future<File?> pickAndCompressImage(
    BuildContext context,
    ImageSource source,
  ) async {
    // Izin kontrolu
    final hasPermission = await checkAndRequestPermission(context, source);
    if (!hasPermission) return null;

    try {
      final XFile? pickedFile = await _picker.pickImage(source: source);

      if (pickedFile != null) {
        final originalFile = File(pickedFile.path);
        // Otomatik sikistir ve dondur
        return await compressImage(originalFile);
      }

      return null;
    } catch (e) {
      debugPrint('ImageHelper: Resim secme hatasi: $e');
      return null;
    }
  }

  /// Sadece resim sec (sikistirma olmadan, izin kontrolu dahil)
  static Future<File?> pickImage(
    BuildContext context,
    ImageSource source,
  ) async {
    // Izin kontrolu
    final hasPermission = await checkAndRequestPermission(context, source);
    if (!hasPermission) return null;

    try {
      final XFile? pickedFile = await _picker.pickImage(source: source);

      if (pickedFile != null) {
        return File(pickedFile.path);
      }

      return null;
    } catch (e) {
      debugPrint('ImageHelper: Resim secme hatasi: $e');
      return null;
    }
  }

  // ==================== SIKISTIRMA ====================

  /// Resmi JPEG formatinda sikistirir
  ///
  /// [file] - ImagePicker'dan gelen orijinal dosya
  /// [minWidth] - Minimum genislik (varsayilan: 1080)
  /// [minHeight] - Minimum yukseklik (varsayilan: 1080)
  /// [quality] - JPEG kalitesi 0-100 (varsayilan: 85)
  ///
  /// Basarisiz olursa orijinal dosyayi dondurur
  static Future<File> compressImage(
    File file, {
    int minWidth = defaultMinWidth,
    int minHeight = defaultMinHeight,
    int quality = defaultQuality,
  }) async {
    try {
      // Gecici dizin al
      final tempDir = await getTemporaryDirectory();

      // Benzersiz dosya adi olustur
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final targetPath = path.join(
        tempDir.path,
        'compressed_$timestamp.jpg',
      );

      // Resmi sikistir
      final XFile? compressedXFile = await FlutterImageCompress.compressAndGetFile(
        file.absolute.path,
        targetPath,
        minWidth: minWidth,
        minHeight: minHeight,
        quality: quality,
        format: CompressFormat.jpeg,
      );

      // Basarili ise sikistirilmis dosyayi dondur
      if (compressedXFile != null) {
        final compressedFile = File(compressedXFile.path);

        // Boyut karsilastirmasi (debug icin)
        final originalSize = await file.length();
        final compressedSize = await compressedFile.length();
        final savedPercent = ((1 - (compressedSize / originalSize)) * 100).toStringAsFixed(1);

        debugPrint('ImageHelper: Sikistirma tamamlandi');
        debugPrint('  Orijinal: ${(originalSize / 1024).toStringAsFixed(1)} KB');
        debugPrint('  Sikistirilmis: ${(compressedSize / 1024).toStringAsFixed(1)} KB');
        debugPrint('  Tasarruf: $savedPercent%');

        return compressedFile;
      }

      // Sikistirma basarisiz - orijinali dondur
      return file;
    } catch (e) {
      // Hata durumunda orijinal dosyayi dondur
      debugPrint('ImageHelper: Sikistirma hatasi: $e');
      return file;
    }
  }

  /// Profil fotografi icin optimize edilmis sikistirma
  /// Daha yuksek kalite (90) ve daha buyuk boyut (1200px)
  static Future<File> compressProfileImage(File file) async {
    return compressImage(
      file,
      minWidth: 1200,
      minHeight: 1200,
      quality: 90,
    );
  }

  /// Galeri/grid gosterimi icin daha agresif sikistirma
  /// Daha dusuk kalite (75) ve daha kucuk boyut (800px)
  static Future<File> compressThumbnail(File file) async {
    return compressImage(
      file,
      minWidth: 800,
      minHeight: 800,
      quality: 75,
    );
  }
}
