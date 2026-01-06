import 'dart:io';
import 'package:flutter/foundation.dart' show setEquals, debugPrint;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart'; // ImageSource enum icin gerekli
import '../models/user_profile.dart';
import '../services/profile_service.dart';
import '../data/turkish_universities.dart';
import '../widgets/custom_notification.dart';
import '../providers/swipe_provider.dart';
import '../utils/image_helper.dart';
import 'user_profile_screen.dart';

class ProfileEditScreen extends ConsumerStatefulWidget {
  const ProfileEditScreen({super.key});

  @override
  ConsumerState<ProfileEditScreen> createState() => _ProfileEditScreenState();
}

class _ProfileEditScreenState extends ConsumerState<ProfileEditScreen> {
  final ProfileService _profileService = ProfileService();

  final _nameController = TextEditingController();
  final _ageController = TextEditingController();
  final _bioController = TextEditingController();
  final _universityController = TextEditingController();
  final _departmentController = TextEditingController();
  final _clubsController = TextEditingController(); // Kullanıcı kendi topluluk/kulüplerini yazar

  String _selectedGender = 'Erkek';
  String _lookingFor = 'Kadın';
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
  String _initialAge = '';
  String _initialBio = '';
  String _initialUniversity = '';
  String _initialDepartment = '';
  String _initialGender = 'Erkek';
  String _initialLookingFor = 'Kadın';
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
    _ageController.addListener(_checkForChanges);
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
        _nameController.text.trim() != _initialName.trim() ||
        _ageController.text.trim() != _initialAge.trim() ||
        _bioController.text.trim() != _initialBio.trim() ||
        _universityController.text.trim() != _initialUniversity.trim() ||
        _departmentController.text.trim() != _initialDepartment.trim() ||
        _clubsController.text.trim() != _initialClubs.trim() ||
        _selectedGender != _initialGender ||
        _lookingFor != _initialLookingFor ||
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
    _ageController.removeListener(_checkForChanges);
    _bioController.removeListener(_checkForChanges);
    _universityController.removeListener(_checkForChanges);
    _departmentController.removeListener(_checkForChanges);
    _clubsController.removeListener(_checkForChanges);
    _nameController.dispose();
    _ageController.dispose();
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
      _ageController.text = (profile['age'] ?? '').toString();
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

      // Aranan cinsiyet
      final loadedLookingFor = profile['lookingFor'] ?? 'Kadın';
      if (['Erkek', 'Kadın', 'Herkes'].contains(loadedLookingFor)) {
        _lookingFor = loadedLookingFor;
      } else {
        _lookingFor = 'Kadın';
      }

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
    _initialAge = _ageController.text;
    _initialBio = _bioController.text;
    _initialUniversity = _universityController.text;
    _initialDepartment = _departmentController.text;
    _initialGender = _selectedGender;
    _initialLookingFor = _lookingFor;
    _initialGrade = _selectedGrade;
    _initialClubs = _clubsController.text;
    _initialInterests = List<String>.from(_selectedInterests);
    _initialIntents = List<String>.from(_selectedIntents);
    _initialPhotoUrls = List<String?>.from(_photoUrls);
  }

  // Silinecek fotoğraf URL'leri (Kaydet'e basınca Storage'dan silinecek)
  final List<String> _urlsToDelete = [];

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
    if (_nameController.text.isEmpty) {
      _showError('Lütfen adınızı girin');
      return;
    }

    if (_ageController.text.isEmpty) {
      _showError('Lütfen yaşınızı girin');
      return;
    }

    int? age = int.tryParse(_ageController.text);
    if (age == null || age < 18 || age > 99) {
      _showError('Geçerli bir yaş girin (18-99)');
      return;
    }

    // Ana fotoğraf kontrolü - en az 1 fotoğraf olmalı
    final bool hasMainPhoto = _photoUrls[0] != null || _localPhotos[0] != null;
    if (!hasMainPhoto) {
      _showError('Ana fotoğraf (ilk slot) zorunludur');
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

      // 3. Profili kaydet
      bool success = await _profileService.saveProfile(
        name: _nameController.text.trim(),
        age: age,
        bio: _bioController.text.trim(),
        university: _universityController.text.trim(),
        department: _departmentController.text.trim(),
        interests: _selectedInterests,
        photoUrls: finalPhotoUrls,
        gender: _selectedGender,
        lookingFor: _lookingFor,
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

          // IMPORTANT: Check if lookingFor changed BEFORE saving initial values!
          final lookingForChanged = _lookingFor != _initialLookingFor;
          final newLookingFor = _lookingFor;

          if (lookingForChanged) {
            debugPrint('ProfileEdit: lookingFor changed from $_initialLookingFor to $newLookingFor');
          }

          // Save new initial values (current state becomes the new baseline)
          _saveInitialValues();

          // Reset hasChanges flag
          setState(() => _hasChanges = false);

          // Close keyboard
          FocusScope.of(context).unfocus();

          // Update gender filter if lookingFor changed
          if (lookingForChanged) {
            debugPrint('ProfileEdit: Updating gender filter to $newLookingFor');
            await ref.read(swipeProvider.notifier).updateGenderFilter(newLookingFor);
            debugPrint('ProfileEdit: Gender filter updated successfully');
          }

          // Show beautiful success notification (check mounted after async)
          if (mounted) {
            CustomNotification.success(
              context,
              'Profil Güncellendi',
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
    CustomNotification.error(context, message);
  }

  void _showWarning(String message) {
    if (!mounted) return;
    CustomNotification.warning(context, message);
  }

  /// Navigate to UserProfileScreen to preview own profile as others see it
  /// Uses real-time form data (not saved to Firestore yet) for instant preview
  void _previewProfile() {
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
          ? 'İsimsiz'
          : _nameController.text.trim(),
      age: int.tryParse(_ageController.text) ?? 0,
      bio: _bioController.text.trim(),
      university: _universityController.text.trim(),
      department: _departmentController.text.trim(),
      photos: previewPhotos,
      interests: List<String>.from(_selectedInterests),
      gender: _selectedGender,
      lookingFor: _lookingFor,
      grade: _selectedGrade,
      clubs: previewClubs,
      socialLinks: {},
      intent: List<String>.from(_selectedIntents),
    );

    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            UserProfileScreen(
          userId: currentUserId,
          previewProfile: previewProfile,
        ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          // Scale + Fade transition for a premium feel
          return FadeTransition(
            opacity: animation,
            child: ScaleTransition(
              scale: Tween<double>(begin: 0.90, end: 1.0).animate(
                CurvedAnimation(parent: animation, curve: Curves.easeOutBack),
              ),
              child: child,
            ),
          );
        },
        transitionDuration: const Duration(milliseconds: 400),
        reverseTransitionDuration: const Duration(milliseconds: 300),
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
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
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
                    _buildTextField(
                      controller: _ageController,
                      label: 'Yaş',
                      hint: '18',
                      icon: Icons.cake,
                      keyboardType: TextInputType.number,
                    ),
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
                  _buildSection('Kiminle Tanışmak İstiyorsun?', [
                    _buildLookingForSelector(),
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
                    : Image.network(
                        _photoUrls[index]!,
                        fit: BoxFit.cover,
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) return child;
                          return Center(
                            child: CircularProgressIndicator(
                              value: loadingProgress.expectedTotalBytes != null
                                  ? loadingProgress.cumulativeBytesLoaded /
                                      loadingProgress.expectedTotalBytes!
                                  : null,
                              strokeWidth: 2,
                            ),
                          );
                        },
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

  Widget _buildLookingForSelector() {
    return Row(
      children: [
        Expanded(
          child: _buildSelectableOption(
            'Erkek',
            Icons.male,
            _lookingFor == 'Erkek',
            () {
              setState(() => _lookingFor = 'Erkek');
              _checkForChanges();
            },
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildSelectableOption(
            'Kadın',
            Icons.female,
            _lookingFor == 'Kadın',
            () {
              setState(() => _lookingFor = 'Kadın');
              _checkForChanges();
            },
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildSelectableOption(
            'Herkes',
            Icons.people,
            _lookingFor == 'Herkes',
            () {
              setState(() => _lookingFor = 'Herkes');
              _checkForChanges();
            },
          ),
        ),
      ],
    );
  }

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
