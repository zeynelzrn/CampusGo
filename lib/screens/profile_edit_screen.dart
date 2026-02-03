import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart' show setEquals, debugPrint;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart'; // ImageSource enum icin gerekli
import 'package:shimmer/shimmer.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/user_profile.dart';
import '../services/profile_service.dart';
import '../data/turkish_universities.dart';
import '../widgets/app_notification.dart';
import '../providers/connectivity_provider.dart';
import '../utils/image_helper.dart';
import '../widgets/modern_animated_dialog.dart';
import '../providers/swipe_provider.dart';
import 'discovery/filters_modal.dart';
import 'user_profile_screen.dart';

class ProfileEditScreen extends ConsumerStatefulWidget {
  const ProfileEditScreen({super.key});

  @override
  ConsumerState<ProfileEditScreen> createState() => _ProfileEditScreenState();
}

class _ProfileEditScreenState extends ConsumerState<ProfileEditScreen> {
  final ProfileService _profileService = ProfileService();

  final _nameController = TextEditingController();
  final _bioController = TextEditingController();
  final _universityController = TextEditingController();
  final _departmentController = TextEditingController();
  final _clubsController = TextEditingController(); // Kullanıcı kendi topluluk/kulüplerini yazar

  // Doğum tarihi ve yaş - READ ONLY (değiştirilemez)
  DateTime? _birthDate;
  int _displayAge = 0; // Gösterim için hesaplanan yaş

  String _selectedGender = 'Erkek';
  String _selectedGrade = '';

  List<String?> _photoUrls = List.filled(6, null);
  List<File?> _localPhotos = List.filled(6, null);
  List<String> _selectedInterests = [];
  List<String> _selectedIntents = [];

  final List<String> _gradeOptions = [
    'Hazırlık',
    '1. Sınıf',
    '2. Sınıf',
    '3. Sınıf',
    '4. Sınıf',
    'Yüksek Lisans',
    'Doktora',
    'Mezun',
  ];

  final List<String> _intentOptions = [
    'Kahve içmek',
    'Ders çalışmak',
    'Spor yapmak',
    'Proje ortağı bulmak',
    'Etkinliklere katılmak',
    'Sohbet etmek',
    'Yeni arkadaşlar edinmek',
    'Networking',
  ];

  bool _isLoading = false;
  bool _isSaving = false;
  bool _hasChanges = false;

  // Initial values for change detection
  String _initialName = '';
  // NOT: Doğum tarihi/yaş değiştirilemez, bu yüzden initial değer tutmuyoruz
  String _initialBio = '';
  String _initialUniversity = '';
  String _initialDepartment = '';
  String _initialGender = 'Erkek';
  String _initialGrade = '';
  String _initialClubs = '';
  List<String> _initialInterests = [];
  List<String> _initialIntents = [];
  List<String?> _initialPhotoUrls = List.filled(6, null);

  final List<String> _allInterests = [
    'Müzik',
    'Spor',
    'Seyahat',
    'Fotoğrafçılık',
    'Sinema',
    'Kitap',
    'Yemek',
    'Kahve',
    'Doğa',
    'Yoga',
    'Dans',
    'Oyun',
    'Sanat',
    'Teknoloji',
    'Fitness',
    'Koşu',
    'Yüzme',
    'Bisiklet',
    'Kamp',
    'Tırmanış',
  ];

  @override
  void initState() {
    super.initState();
    _loadProfile();
    _addListeners();
  }

  void _addListeners() {
    _nameController.addListener(_checkForChanges);
    // NOT: Yaş değiştirilemez, listener yok
    _bioController.addListener(_checkForChanges);
    _universityController.addListener(_checkForChanges);
    _departmentController.addListener(_checkForChanges);
    _clubsController.addListener(_checkForChanges);
  }

  void _checkForChanges() {
    // Skip check if still loading initial data
    if (_isLoading) return;

    final hasChanges =
        // String comparisons with trim()
        // NOT: Yaş değiştirilemez, karşılaştırma yok
        _nameController.text.trim() != _initialName.trim() ||
        _bioController.text.trim() != _initialBio.trim() ||
        _universityController.text.trim() != _initialUniversity.trim() ||
        _departmentController.text.trim() != _initialDepartment.trim() ||
        _clubsController.text.trim() != _initialClubs.trim() ||
        _selectedGender != _initialGender ||
        _selectedGrade != _initialGrade ||
        // Set-based deep comparison for lists (order doesn't matter)
        !_setEquals(_selectedInterests, _initialInterests) ||
        !_setEquals(_selectedIntents, _initialIntents) ||
        !_photoListEquals(_photoUrls, _localPhotos, _initialPhotoUrls);

    if (hasChanges != _hasChanges) {
      setState(() => _hasChanges = hasChanges);
    }
  }

  /// Deep comparison using Set - returns true if both lists have same elements
  bool _setEquals(List<String> a, List<String> b) {
    return setEquals(a.toSet(), b.toSet());
  }

  bool _photoListEquals(List<String?> currentUrls, List<File?> localPhotos, List<String?> initialUrls) {
    for (int i = 0; i < 6; i++) {
      // If there's a local photo, it means user added/changed a photo
      if (localPhotos[i] != null) return false;
      // If URL changed
      if (currentUrls[i] != initialUrls[i]) return false;
    }
    return true;
  }

  @override
  void dispose() {
    _nameController.removeListener(_checkForChanges);
    _bioController.removeListener(_checkForChanges);
    _universityController.removeListener(_checkForChanges);
    _departmentController.removeListener(_checkForChanges);
    _clubsController.removeListener(_checkForChanges);
    _nameController.dispose();
    _bioController.dispose();
    _universityController.dispose();
    _departmentController.dispose();
    _clubsController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    setState(() => _isLoading = true);

    final profile = await _profileService.getProfile();

    if (profile != null) {
      _nameController.text = profile['name'] ?? '';

      // Doğum tarihi ve yaş yükle (READ ONLY)
      if (profile['birthDate'] != null) {
        _birthDate = (profile['birthDate'] as dynamic).toDate();
        // Yaşı doğum tarihinden hesapla
        final now = DateTime.now();
        _displayAge = now.year - _birthDate!.year;
        if (now.month < _birthDate!.month ||
            (now.month == _birthDate!.month && now.day < _birthDate!.day)) {
          _displayAge--;
        }
      } else {
        // Eski kayıtlar için sadece age varsa onu kullan
        _displayAge = profile['age'] ?? 0;
      }

      _bioController.text = profile['bio'] ?? '';
      _universityController.text = profile['university'] ?? '';
      _departmentController.text = profile['department'] ?? '';

      // Cinsiyet
      final loadedGender = profile['gender'] ?? 'Erkek';
      if (['Erkek', 'Kadın'].contains(loadedGender)) {
        _selectedGender = loadedGender;
      } else {
        _selectedGender = 'Erkek';
      }

      // lookingFor artık filters modal'dan ayarlanıyor, burada yüklemiyoruz

      _selectedInterests = List<String>.from(profile['interests'] ?? []);

      // Zenginleştirilmiş alanlar
      _selectedGrade = profile['grade'] ?? '';
      // Kulüpleri virgülle ayrılmış string olarak yükle
      final clubsList = List<String>.from(profile['clubs'] ?? []);
      _clubsController.text = clubsList.join(', ');
      _selectedIntents = List<String>.from(profile['intent'] ?? []);

      List<dynamic> photos = profile['photos'] ?? [];
      for (int i = 0; i < photos.length && i < 6; i++) {
        _photoUrls[i] = photos[i];
      }

      // Save initial values for change detection
      _saveInitialValues();
    }

    // Ensure _hasChanges is false after loading completes
    setState(() {
      _isLoading = false;
      _hasChanges = false;
    });
  }

  void _saveInitialValues() {
    _initialName = _nameController.text;
    // NOT: Yaş değiştirilemez, initial değer kaydetmiyoruz
    _initialBio = _bioController.text;
    _initialUniversity = _universityController.text;
    _initialDepartment = _departmentController.text;
    _initialGender = _selectedGender;
    _initialGrade = _selectedGrade;
    _initialClubs = _clubsController.text;
    _initialInterests = List<String>.from(_selectedInterests);
    _initialIntents = List<String>.from(_selectedIntents);
    _initialPhotoUrls = List<String?>.from(_photoUrls);
  }

  // Silinecek fotoğraf URL'leri (Kaydet'e basınca Storage'dan silinecek)
  final List<String> _urlsToDelete = [];

  /// İnternet bağlantısını kontrol et
  bool _checkConnectivity() {
    final isOnline = ref.read(isOnlineProvider);
    if (!isOnline) {
      HapticFeedback.heavyImpact();
      _showOfflineWarning();
      return false;
    }
    return true;
  }

  /// Offline uyarı dialogu göster
  void _showOfflineWarning() {
    showModernDialog(
      context: context,
      builder: (dialogContext) => ModernAnimatedDialog(
        type: DialogType.warning,
        icon: Icons.wifi_off_rounded,
        title: 'Bağlantı Yok',
        subtitle: 'İnternet bağlantınız olmadan bu işlemi yapamazsınız.\n\nLütfen bağlantınızı kontrol edip tekrar deneyin.',
        confirmText: 'Tamam',
        confirmButtonColor: const Color(0xFF5C6BC0),
        onConfirm: () => Navigator.pop(dialogContext),
      ),
    );
  }

  Future<void> _pickImage(int index) async {
    final bool hasPhoto = _photoUrls[index] != null || _localPhotos[index] != null;
    final bool isMainPhoto = index == 0;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),

            // Başlık
            Text(
              isMainPhoto ? 'Ana Fotoğraf' : 'Fotoğraf ${index + 1}',
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (isMainPhoto)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  'Ana fotoğraf silinemez, sadece değiştirilebilir',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: Colors.grey[500],
                  ),
                ),
              ),
            const SizedBox(height: 16),

            // Kamera seçeneği
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.indigo.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.camera_alt, color: Colors.indigo),
              ),
              title: Text(hasPhoto ? 'Kamera ile Değiştir' : 'Kamera'),
              onTap: () {
                Navigator.pop(ctx);
                _getImage(ImageSource.camera, index);
              },
            ),

            // Galeri seçeneği
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.indigo.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.photo_library, color: Colors.indigo),
              ),
              title: Text(hasPhoto ? 'Galeriden Değiştir' : 'Galeri'),
              onTap: () {
                Navigator.pop(ctx);
                _getImage(ImageSource.gallery, index);
              },
            ),

            // Silme seçeneği - SADECE index > 0 için göster
            if (hasPhoto && !isMainPhoto)
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.delete, color: Colors.red),
                ),
                title: const Text('Fotoğrafı Sil'),
                onTap: () {
                  Navigator.pop(ctx);
                  _deletePhoto(index);
                },
              ),

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  /// Fotoğrafı sil (Storage'dan silme işlemi Kaydet'e basınca yapılır)
  void _deletePhoto(int index) {
    // Ana fotoğraf silinemez
    if (index == 0) {
      _showError('Ana fotoğraf silinemez, sadece değiştirilebilir');
      return;
    }

    // Eğer URL varsa, silme listesine ekle (Kaydet'e basınca Storage'dan silinecek)
    final urlToDelete = _photoUrls[index];
    if (urlToDelete != null && urlToDelete.isNotEmpty) {
      _urlsToDelete.add(urlToDelete);
      debugPrint('ProfileEdit: Silinecek URL eklendi: $urlToDelete');
    }

    setState(() {
      _photoUrls[index] = null;
      _localPhotos[index] = null;
    });
    _checkForChanges();
  }

  Future<void> _getImage(ImageSource source, int index) async {
    try {
      // ImageHelper ile izin kontrolu + resim secme + sikistirma (hepsi bir arada)
      final File? compressedFile = await ImageHelper.pickAndCompressImage(
        context,
        source,
      );

      if (compressedFile != null) {
        // Eğer bu slotta eski bir URL varsa, silme listesine ekle
        final oldUrl = _photoUrls[index];
        if (oldUrl != null && oldUrl.isNotEmpty) {
          _urlsToDelete.add(oldUrl);
          debugPrint('ProfileEdit: Degistirilecek foto silme listesine eklendi: $oldUrl');
        }

        setState(() {
          _localPhotos[index] = compressedFile;
          _photoUrls[index] = null;
        });
        _checkForChanges();
      }
    } catch (e) {
      _showError('Fotoğraf seçilemedi: $e');
    }
  }

  Future<void> _saveProfile() async {
    // İnternet kontrolü
    if (!_checkConnectivity()) return;

    if (_nameController.text.isEmpty) {
      _showError('Lutfen adinizi girin');
      return;
    }

    // NOT: Yaş kontrol edilmiyor - değiştirilemez

    // Ana fotoğraf kontrolü - en az 1 fotoğraf olmalı
    final bool hasMainPhoto = _photoUrls[0] != null || _localPhotos[0] != null;
    if (!hasMainPhoto) {
      _showError('Ana fotograf (ilk slot) zorunludur');
      return;
    }

    setState(() => _isSaving = true);

    try {
      // 1. Önce silme listesindeki eski fotoğrafları Storage'dan sil
      if (_urlsToDelete.isNotEmpty) {
        debugPrint('ProfileEdit: ${_urlsToDelete.length} foto Storage\'dan siliniyor...');
        for (final url in _urlsToDelete) {
          await _profileService.deletePhotoByUrl(url);
        }
        _urlsToDelete.clear(); // Silme listesini temizle
      }

      // 2. Yeni fotoğrafları yükle
      List<String?> finalPhotoUrls = List.from(_photoUrls);

      for (int i = 0; i < 6; i++) {
        if (_localPhotos[i] != null) {
          String? uploadedUrl =
              await _profileService.uploadPhoto(_localPhotos[i]!, i);
          if (uploadedUrl != null) {
            finalPhotoUrls[i] = uploadedUrl;
          }
        }
      }

      // Kulüpleri virgülle ayrılmış string'den list'e çevir
      final clubsList = _clubsController.text.trim().isEmpty
          ? <String>[]
          : _clubsController.text.split(',').map((c) => c.trim()).where((c) => c.isNotEmpty).toList();

      // 3. Profili kaydet (yaş değiştirilemez - mevcut değeri gönder)
      bool success = await _profileService.saveProfile(
        name: _nameController.text.trim(),
        age: _displayAge, // Yaş değiştirilemez
        bio: _bioController.text.trim(),
        university: _universityController.text.trim(),
        department: _departmentController.text.trim(),
        interests: _selectedInterests,
        photoUrls: finalPhotoUrls,
        gender: _selectedGender,
        lookingFor: 'Herkes', // Varsayılan değer - artık filters modal'dan ayarlanacak
        grade: _selectedGrade,
        clubs: clubsList,
        socialLinks: {},
        intent: _selectedIntents,
      );

      if (success) {
        if (mounted) {
          // Update photo URLs with uploaded ones and clear local photos
          for (int i = 0; i < 6; i++) {
            if (finalPhotoUrls[i] != null) {
              _photoUrls[i] = finalPhotoUrls[i];
            }
            _localPhotos[i] = null;
          }

          // Save new initial values (current state becomes the new baseline)
          _saveInitialValues();

          // Reset hasChanges flag
          setState(() => _hasChanges = false);

          // Close keyboard
          FocusScope.of(context).unfocus();

          // Show beautiful success notification (check mounted after async)
          if (mounted) {
            AppNotification.success(
              title: 'Profil Güncellendi',
              subtitle: 'Değişiklikler başarıyla kaydedildi',
            );
          }
        }
      } else {
        _showError('Profil kaydedilemedi');
      }
    } catch (e) {
      _showError('Bir hata oluştu: $e');
    }

    if (mounted) {
      setState(() => _isSaving = false);
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    AppNotification.error(title: message);
  }

  void _showWarning(String message) {
    if (!mounted) return;
    AppNotification.warning(title: message);
  }

  /// Navigate to UserProfileScreen to preview own profile as others see it
  /// Uses real-time form data (not saved to Firestore yet) for instant preview
  void _previewProfile() {
    // Haptic feedback - kullanıcı butona bastığını hissetsin
    HapticFeedback.mediumImpact();

    final currentUserId = _profileService.currentUserId;
    if (currentUserId == null) {
      _showWarning('Profil onizlemesi icin giris yapmis olmaniz gerekiyor');
      return;
    }

    // Build photo list: prioritize local photos, then remote URLs
    final List<String> previewPhotos = [];
    for (int i = 0; i < 6; i++) {
      if (_localPhotos[i] != null) {
        // Local file - use file:// URI for preview
        previewPhotos.add(_localPhotos[i]!.path);
      } else if (_photoUrls[i] != null) {
        previewPhotos.add(_photoUrls[i]!);
      }
    }

    // Kulüpleri virgülle ayrılmış string'den list'e çevir
    final previewClubs = _clubsController.text.trim().isEmpty
        ? <String>[]
        : _clubsController.text.split(',').map((c) => c.trim()).where((c) => c.isNotEmpty).toList();

    // Create temporary UserProfile from current form state
    final previewProfile = UserProfile(
      id: currentUserId,
      name: _nameController.text.trim().isEmpty
          ? 'Isimsiz'
          : _nameController.text.trim(),
      birthDate: _birthDate, // Doğum tarihi (varsa)
      legacyAge: _displayAge, // Eski kayıtlar için yaş
      bio: _bioController.text.trim(),
      university: _universityController.text.trim(),
      department: _departmentController.text.trim(),
      photos: previewPhotos,
      interests: List<String>.from(_selectedInterests),
      gender: _selectedGender,
      lookingFor: 'Herkes', // Varsayılan - artık filters modal'dan ayarlanacak
      grade: _selectedGrade,
      clubs: previewClubs,
      socialLinks: {},
      intent: List<String>.from(_selectedIntents),
    );

    // CupertinoPageRoute - iOS style swipe-back gesture desteği
    Navigator.of(context).push(
      CupertinoPageRoute(
        builder: (context) => UserProfileScreen(
          userId: currentUserId,
          previewProfile: previewProfile,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leadingWidth: 145,
        leading: Padding(
          padding: const EdgeInsets.only(left: 12, top: 6, bottom: 6),
          child: GestureDetector(
            onTap: _previewProfile,
            child: Container(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [
                    Color(0xFF5C6BC0), // Indigo (navigation bar ile uyumlu)
                    Color(0xFF7986CB), // Açık indigo
                    Color(0xFF9FA8DA), // Lavender
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(25),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF5C6BC0).withValues(alpha: 0.4),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.visibility_outlined,
                    color: Colors.white,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Önizle',
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        title: const SizedBox.shrink(),
        actions: [
          // Kaydet Butonu - AnimatedSwitcher ile pürüzsüz geçiş
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: SizedBox(
              width: 90, // Sabit genişlik - layout shift önleme
              height: 36,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                transitionBuilder: (Widget child, Animation<double> animation) {
                  // Fade + Scale geçişi (0.9 → 1.0)
                  return FadeTransition(
                    opacity: animation,
                    child: ScaleTransition(
                      scale: Tween<double>(begin: 0.9, end: 1.0).animate(
                        CurvedAnimation(
                          parent: animation,
                          curve: Curves.easeOutCubic,
                        ),
                      ),
                      child: child,
                    ),
                  );
                },
                child: _isSaving
                    ? Container(
                        key: const ValueKey('save_loading'),
                        alignment: Alignment.center,
                        child: const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.indigo,
                          ),
                        ),
                      )
                    : _hasChanges
                        // DURUM B: Aktif - Flat, canlı buton (gölge yok)
                        ? GestureDetector(
                            key: const ValueKey('save_enabled'),
                            onTap: _saveProfile,
                            child: Container(
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: Colors.indigo,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              child: Text(
                                'Kaydet',
                                style: GoogleFonts.poppins(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          )
                        // DURUM A: Pasif - Silik, sade metin
                        : Container(
                            key: const ValueKey('save_disabled'),
                            alignment: Alignment.center,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            child: Text(
                              'Kaydet',
                              style: GoogleFonts.poppins(
                                color: Colors.grey.shade400,
                                fontWeight: FontWeight.w400,
                                fontSize: 14,
                              ),
                            ),
                          ),
              ),
            ),
          ),
        ],
      ),
      // Global ConnectivityBanner handles offline state
      body: _isLoading
                ? Container(
                    color: const Color(0xFFF8F9FA), // Solid background
                    child: const Center(
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF5C6BC0)),
                      ),
                    ),
                  )
                : SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildPhotoGrid(),
                        const SizedBox(height: 24),
                        _buildSection('Hakkında', [
                          _buildTextField(
                            controller: _nameController,
                            label: 'Ad',
                            hint: 'Adınızı girin',
                            icon: Icons.person,
                          ),
                          const SizedBox(height: 12),
                          _buildReadOnlyAgeField(),
                          const SizedBox(height: 12),
                          _buildTextField(
                            controller: _bioController,
                            label: 'Biyografi',
                            hint: 'Kendinizden bahsedin...',
                            icon: Icons.edit,
                            maxLines: 3,
                            maxLength: 500,
                          ),
                        ]),
                        const SizedBox(height: 24),
                        _buildSection('Cinsiyet', [
                          _buildGenderSelector(),
                        ]),
                        const SizedBox(height: 24),
                        _buildSection('Eğitim', [
                          _buildAutocompleteField(
                            controller: _universityController,
                            label: 'Üniversite',
                            hint: 'Üniversitenizi arayın',
                            icon: Icons.school,
                            suggestions: TurkishUniversities.universities,
                          ),
                          const SizedBox(height: 12),
                          _buildAutocompleteField(
                            controller: _departmentController,
                            label: 'Bölüm',
                            hint: 'Bölümünüzü arayın',
                            icon: Icons.book,
                            suggestions: TurkishUniversities.departments,
                          ),
                        ]),
                        const SizedBox(height: 24),
                        _buildSection('Sınıf Seviyesi', [
                          _buildGradeSelector(),
                        ]),
                        const SizedBox(height: 24),
                        _buildDiscoverFiltersCard(),
                        const SizedBox(height: 24),
                        _buildSection('Topluluklar / Kulüpler', [
                          _buildClubsSelector(),
                        ]),
                        const SizedBox(height: 24),
                        _buildSection('Ne İçin Buradayım?', [
                          _buildIntentSelector(),
                        ]),
                        const SizedBox(height: 24),
                        _buildSection('İlgi Alanları', [
                          _buildInterestsSelector(),
                        ]),
                        const SizedBox(height: 100),
                      ],
                    ),
                  ),
    );
  }

  Widget _buildPhotoGrid() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.photo_library, color: Colors.indigo),
              const SizedBox(width: 8),
              Text(
                'Fotoğraflar',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'En az 1 fotoğraf ekleyin. İlk fotoğraf ana fotoğrafınız olacak.',
            style: GoogleFonts.poppins(
              fontSize: 12,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 16),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              childAspectRatio: 0.75,
            ),
            itemCount: 6,
            itemBuilder: (context, index) => _buildPhotoSlot(index),
          ),
        ],
      ),
    );
  }

  Widget _buildPhotoSlot(int index) {
    bool hasPhoto = _photoUrls[index] != null || _localPhotos[index] != null;
    bool isMainPhoto = index == 0;

    return GestureDetector(
      onTap: () => _pickImage(index),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.grey[200],
          borderRadius: BorderRadius.circular(12),
          border: isMainPhoto ? Border.all(color: Colors.indigo, width: 2) : null,
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (hasPhoto)
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: _localPhotos[index] != null
                    ? Image.file(
                        _localPhotos[index]!,
                        fit: BoxFit.cover,
                      )
                    : CachedNetworkImage(
                        imageUrl: _photoUrls[index]!,
                        fit: BoxFit.cover,
                        cacheManager: AppCacheManager.highPriorityInstance,
                        placeholder: (context, url) => Shimmer.fromColors(
                          baseColor: Colors.grey[300]!,
                          highlightColor: Colors.grey[100]!,
                          child: Container(
                            color: Colors.grey[200],
                            child: Center(
                              child: Icon(Icons.person, size: 32, color: Colors.grey[400]),
                            ),
                          ),
                        ),
                        errorWidget: (context, url, error) => Shimmer.fromColors(
                          baseColor: Colors.grey[300]!,
                          highlightColor: Colors.grey[100]!,
                          child: Container(
                            color: Colors.grey[200],
                            child: Center(
                              child: Icon(Icons.person, size: 32, color: Colors.grey[400]),
                            ),
                          ),
                        ),
                      ),
              )
            else
              Center(
                child: Icon(
                  Icons.add_a_photo,
                  color: Colors.grey[400],
                  size: 32,
                ),
              ),
            Positioned(
              bottom: 4,
              right: 4,
              child: Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: hasPhoto ? Colors.white : Colors.indigo,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.2),
                      blurRadius: 4,
                    ),
                  ],
                ),
                child: Icon(
                  hasPhoto ? Icons.edit : Icons.add,
                  size: 14,
                  color: hasPhoto ? Colors.indigo : Colors.white,
                ),
              ),
            ),
            if (isMainPhoto)
              Positioned(
                top: 4,
                left: 4,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.indigo,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'Ana',
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(String title, List<Widget> children) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  /// Yaş alanı - READ ONLY (değiştirilemez)
  /// Doğum tarihi profil oluşturulurken belirlenir ve sonra değiştirilemez
  Widget _buildReadOnlyAgeField() {
    // Türkçe ay isimleri
    const turkishMonths = [
      'Ocak', 'Şubat', 'Mart', 'Nisan', 'Mayıs', 'Haziran',
      'Temmuz', 'Ağustos', 'Eylül', 'Ekim', 'Kasım', 'Aralık'
    ];

    String birthDateText = 'Belirtilmemiş';
    if (_birthDate != null) {
      final day = _birthDate!.day;
      final month = turkishMonths[_birthDate!.month - 1];
      final year = _birthDate!.year;
      birthDateText = '$day $month $year';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Row(
        children: [
          Icon(Icons.cake, color: Colors.grey[600]),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Yaş',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '$_displayAge yaşında',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey[800],
                  ),
                ),
                if (_birthDate != null)
                  Text(
                    birthDateText,
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: Colors.grey[500],
                    ),
                  ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.orange[50],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.orange[200]!),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.lock_outline, size: 14, color: Colors.orange[700]),
                const SizedBox(width: 4),
                Text(
                  'Değiştirilemez',
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: Colors.orange[700],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    int maxLines = 1,
    int? maxLength,
    TextInputType? keyboardType,
  }) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      maxLength: maxLength,
      keyboardType: keyboardType,
      style: GoogleFonts.poppins(),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, color: Colors.indigo),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.indigo),
        ),
        filled: true,
        fillColor: Colors.grey[50],
      ),
    );
  }

  Widget _buildAutocompleteField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    required List<String> suggestions,
  }) {
    return Autocomplete<String>(
      optionsBuilder: (TextEditingValue textEditingValue) {
        if (textEditingValue.text.isEmpty) {
          return suggestions.take(10);
        }
        final query = textEditingValue.text.toLowerCase();
        return suggestions
            .where((option) => option.toLowerCase().contains(query))
            .take(20);
      },
      initialValue: TextEditingValue(text: controller.text),
      onSelected: (String selection) {
        controller.text = selection;
      },
      fieldViewBuilder: (context, textController, focusNode, onFieldSubmitted) {
        // Sync initial value only once
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (textController.text.isEmpty && controller.text.isNotEmpty) {
            textController.text = controller.text;
          }
        });

        return TextField(
          controller: textController,
          focusNode: focusNode,
          style: GoogleFonts.poppins(),
          onChanged: (value) {
            controller.text = value;
          },
          decoration: InputDecoration(
            labelText: label,
            hintText: hint,
            prefixIcon: Icon(icon, color: Colors.indigo),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.indigo),
            ),
            filled: true,
            fillColor: Colors.grey[50],
          ),
        );
      },
      optionsViewBuilder: (context, onSelected, options) {
        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 4,
            borderRadius: BorderRadius.circular(12),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: 200,
                maxWidth: MediaQuery.of(context).size.width - 64,
              ),
              child: ListView.builder(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                itemCount: options.length,
                itemBuilder: (context, index) {
                  final option = options.elementAt(index);
                  return ListTile(
                    title: Text(
                      option,
                      style: GoogleFonts.poppins(fontSize: 14),
                    ),
                    onTap: () => onSelected(option),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildGenderSelector() {
    return Row(
      children: [
        Expanded(
          child: _buildSelectableOption(
            'Erkek',
            Icons.male,
            _selectedGender == 'Erkek',
            () {
              setState(() => _selectedGender = 'Erkek');
              _checkForChanges();
            },
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildSelectableOption(
            'Kadın',
            Icons.female,
            _selectedGender == 'Kadın',
            () {
              setState(() => _selectedGender = 'Kadın');
              _checkForChanges();
            },
          ),
        ),
      ],
    );
  }

  // lookingFor selector kaldırıldı - artık Discovery Filters'da!

  Widget _buildSelectableOption(
    String label,
    IconData icon,
    bool isSelected,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? Colors.indigo : Colors.grey[100],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? Colors.indigo : Colors.grey[300]!,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: isSelected ? Colors.white : Colors.grey[600],
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: GoogleFonts.poppins(
                color: isSelected ? Colors.white : Colors.grey[600],
                fontWeight: FontWeight.w500,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInterestsSelector() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _allInterests.map((interest) {
        bool isSelected = _selectedInterests.contains(interest);
        return GestureDetector(
          onTap: () {
            setState(() {
              if (isSelected) {
                _selectedInterests.remove(interest);
              } else if (_selectedInterests.length < 5) {
                _selectedInterests.add(interest);
              } else {
                _showWarning('En fazla 5 ilgi alanı seçebilirsiniz');
              }
            });
            _checkForChanges();
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: isSelected ? Colors.indigo : Colors.grey[100],
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isSelected ? Colors.indigo : Colors.grey[300]!,
              ),
            ),
            child: Text(
              interest,
              style: GoogleFonts.poppins(
                color: isSelected ? Colors.white : Colors.grey[700],
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                fontSize: 13,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildGradeSelector() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _gradeOptions.map((grade) {
        bool isSelected = _selectedGrade == grade;
        return GestureDetector(
          onTap: () {
            setState(() {
              _selectedGrade = isSelected ? '' : grade;
            });
            _checkForChanges();
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: isSelected ? Colors.indigo : Colors.grey[100],
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isSelected ? Colors.indigo : Colors.grey[300]!,
              ),
            ),
            child: Text(
              grade,
              style: GoogleFonts.poppins(
                color: isSelected ? Colors.white : Colors.grey[700],
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                fontSize: 13,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  /// Keşfet sayfasındaki filtrelerle senkron kart. Sınıf seviyesi kartının altında.
  Widget _buildDiscoverFiltersCard() {
    final swipeState = ref.watch(swipeProvider);
    final gender = swipeState.genderFilter ?? 'Herkes';
    final hasAnyFilter = swipeState.filterCity != null ||
        swipeState.filterUniversity != null ||
        swipeState.filterDepartment != null ||
        swipeState.filterGrade != null ||
        (swipeState.genderFilter != null && swipeState.genderFilter != 'Herkes');

    const amber = Color(0xFFFFB300);
    const amberDark = Color(0xFFE65100);

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(20),
      elevation: 0,
      child: InkWell(
        onTap: () {
          HapticFeedback.mediumImpact();
          showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            builder: (context) => const FiltersModal(),
          );
        },
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                const Color(0xFFFFF8E1),
                const Color(0xFFFFECB3).withValues(alpha: 0.6),
              ],
            ),
            border: Border.all(color: amber.withValues(alpha: 0.6), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: amber.withValues(alpha: 0.15),
                blurRadius: 20,
                offset: const Offset(0, 6),
              ),
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: amber.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.tune_rounded, color: amberDark, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Keşfet\'te Kimleri Göreceğini Sen Belirle',
                      style: GoogleFonts.poppins(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF37474F),
                      ),
                    ),
                  ),
                  const Icon(Icons.arrow_forward_ios_rounded, color: Color(0xFFFFB300), size: 16),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'İl, üniversite ve bölüme göre filtrele • Dokun ve ayarla',
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  color: const Color(0xFF5D4037),
                  height: 1.3,
                ),
              ),
              const SizedBox(height: 12),
              if (hasAnyFilter) ...[
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (gender.isNotEmpty && gender != 'Herkes')
                      _buildFilterChip('Kiminle', gender),
                    if (swipeState.filterCity != null)
                      _buildFilterChip('İl', swipeState.filterCity!),
                    if (swipeState.filterUniversity != null)
                      _buildFilterChip('Üniversite', swipeState.filterUniversity!),
                    if (swipeState.filterDepartment != null)
                      _buildFilterChip('Bölüm', swipeState.filterDepartment!),
                    if (swipeState.filterGrade != null)
                      _buildFilterChip('Sınıf', swipeState.filterGrade!),
                  ],
                ),
              ] else
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    children: [
                      Icon(Icons.touch_app_rounded, size: 18, color: amberDark.withValues(alpha: 0.8)),
                      const SizedBox(width: 6),
                      Text(
                        'Dokun, keşfetmeyi kişiselleştir',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: amberDark,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFFFB300).withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFFFFB300).withValues(alpha: 0.4),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$label: ',
            style: GoogleFonts.poppins(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF5C6BC0),
            ),
          ),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 140),
            child: Text(
              value,
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: Colors.grey[800],
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildClubsSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Üye olduğunuz topluluk veya kulüpleri virgülle ayırarak yazın',
          style: GoogleFonts.poppins(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: Colors.grey[50],
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey[200]!),
          ),
          child: TextField(
            controller: _clubsController,
            maxLines: 2,
            style: GoogleFonts.poppins(fontSize: 14),
            decoration: InputDecoration(
              hintText: 'Örn: Yazılım Kulübü, Münazara, Dans Topluluğu',
              hintStyle: GoogleFonts.poppins(
                color: Colors.grey[400],
                fontSize: 14,
              ),
              prefixIcon: Icon(
                Icons.groups_outlined,
                color: Colors.grey[400],
              ),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildIntentSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Neden burada olduğunu paylaş (en fazla 3)',
          style: GoogleFonts.poppins(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _intentOptions.map((intent) {
            bool isSelected = _selectedIntents.contains(intent);
            return GestureDetector(
              onTap: () {
                setState(() {
                  if (isSelected) {
                    _selectedIntents.remove(intent);
                  } else if (_selectedIntents.length < 3) {
                    _selectedIntents.add(intent);
                  } else {
                    _showWarning('En fazla 3 niyet seçebilirsiniz');
                  }
                });
                _checkForChanges();
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected ? Colors.deepPurple : Colors.grey[100],
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isSelected ? Colors.deepPurple : Colors.grey[300]!,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _getIntentIcon(intent),
                      size: 16,
                      color: isSelected ? Colors.white : Colors.grey[600],
                    ),
                    const SizedBox(width: 6),
                    Text(
                      intent,
                      style: GoogleFonts.poppins(
                        color: isSelected ? Colors.white : Colors.grey[700],
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  IconData _getIntentIcon(String intent) {
    switch (intent) {
      case 'Kahve içmek':
        return Icons.coffee_outlined;
      case 'Ders çalışmak':
        return Icons.menu_book_outlined;
      case 'Spor yapmak':
        return Icons.fitness_center_outlined;
      case 'Proje ortağı bulmak':
        return Icons.handshake_outlined;
      case 'Etkinliklere katılmak':
        return Icons.event_outlined;
      case 'Sohbet etmek':
        return Icons.chat_bubble_outline;
      case 'Yeni arkadaşlar edinmek':
        return Icons.people_outline;
      case 'Networking':
        return Icons.hub_outlined;
      default:
        return Icons.star_outline;
    }
  }

}
