import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import '../providers/profile_provider.dart';
import '../repositories/profile_repository.dart';
import '../data/turkish_universities.dart';
import '../widgets/app_notification.dart';
import '../utils/image_helper.dart';
import '../services/auth_service.dart';
import 'email_verification_screen.dart';
import 'welcome_screen.dart';

class CreateProfileScreen extends ConsumerStatefulWidget {
  const CreateProfileScreen({super.key});

  @override
  ConsumerState<CreateProfileScreen> createState() =>
      _CreateProfileScreenState();
}

class _CreateProfileScreenState extends ConsumerState<CreateProfileScreen>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _universityController = TextEditingController();
  final _departmentController = TextEditingController();
  final _bioController = TextEditingController();

  // 6 slotlu fotoğraf listesi (null = boş slot)
  final List<File?> _selectedPhotos = List.filled(6, null);

  DateTime? _selectedBirthDate;
  String _selectedGender = 'Erkek';
  String _selectedLookingFor = 'Kadın';

  final List<String> _genderOptions = ['Erkek', 'Kadın', 'Diğer'];
  final List<String> _lookingForOptions = ['Erkek', 'Kadın', 'Herkes'];

  // Animation controllers
  late AnimationController _gridAnimationController;

  @override
  void initState() {
    super.initState();
    _gridAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _gridAnimationController.forward();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _universityController.dispose();
    _departmentController.dispose();
    _bioController.dispose();
    _gridAnimationController.dispose();
    super.dispose();
  }

  /// Yüklenen fotoğraf sayısı
  int get _photoCount => _selectedPhotos.where((p) => p != null).length;

  /// En az 1 fotoğraf var mı?
  bool get _hasMinimumPhotos => _photoCount >= 1;

  /// Seçilen doğum tarihinden yaş hesapla
  int? get _calculatedAge {
    if (_selectedBirthDate == null) return null;
    final now = DateTime.now();
    int age = now.year - _selectedBirthDate!.year;
    if (now.month < _selectedBirthDate!.month ||
        (now.month == _selectedBirthDate!.month &&
            now.day < _selectedBirthDate!.day)) {
      age--;
    }
    return age;
  }

  /// 18 yaş kontrolü
  bool get _isAdult => (_calculatedAge ?? 0) >= 18;

  /// Doğum tarihi seçici göster
  void _showBirthDatePicker() {
    final initialDate =
        _selectedBirthDate ?? DateTime.now().subtract(const Duration(days: 365 * 20));
    final minDate = DateTime.now().subtract(const Duration(days: 365 * 100));
    final maxDate = DateTime.now().subtract(const Duration(days: 365 * 18));

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: 340,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(
                      'İptal',
                      style: GoogleFonts.poppins(
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  Text(
                    'Doğum Tarihi',
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[800],
                    ),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(
                      'Tamam',
                      style: GoogleFonts.poppins(
                        color: const Color(0xFF5C6BC0),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: CupertinoDatePicker(
                mode: CupertinoDatePickerMode.date,
                initialDateTime:
                    initialDate.isAfter(maxDate) ? maxDate : initialDate,
                minimumDate: minDate,
                maximumDate: maxDate,
                dateOrder: DatePickerDateOrder.dmy,
                onDateTimeChanged: (DateTime newDate) {
                  setState(() {
                    _selectedBirthDate = newDate;
                  });
                },
              ),
            ),
            Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.amber.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.amber[700], size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Uygulamayı kullanmak için 18 yaşından büyük olmalısınız',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: Colors.amber[800],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Fotoğraf seç (belirli slot için)
  Future<void> _pickPhotoForSlot(int slotIndex, ImageSource source) async {
    Navigator.pop(context); // Close bottom sheet

    try {
      final File? compressedFile = await ImageHelper.pickAndCompressImage(
        context,
        source,
      );

      if (compressedFile != null) {
        setState(() {
          _selectedPhotos[slotIndex] = compressedFile;
        });
      }
    } catch (e) {
      _showError('Fotoğraf seçilirken hata oluştu');
    }
  }

  /// Fotoğraf seçici bottom sheet göster
  void _showImagePickerForSlot(int slotIndex) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
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
            Text(
              slotIndex == 0 ? 'Ana Fotoğrafını Seç' : 'Fotoğraf Ekle',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              slotIndex == 0
                  ? 'Bu fotoğraf profil avatarın olarak görünecek'
                  : 'Galerini zenginleştir',
              style: GoogleFonts.poppins(
                fontSize: 13,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildImageSourceOption(
                  icon: Icons.camera_alt,
                  label: 'Kamera',
                  onTap: () => _pickPhotoForSlot(slotIndex, ImageSource.camera),
                ),
                _buildImageSourceOption(
                  icon: Icons.photo_library,
                  label: 'Galeri',
                  onTap: () => _pickPhotoForSlot(slotIndex, ImageSource.gallery),
                ),
              ],
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  /// Fotoğraf sil
  void _removePhoto(int slotIndex) {
    setState(() {
      _selectedPhotos[slotIndex] = null;
      // Fotoğrafları sola kaydır (boşlukları doldur)
      _compactPhotos();
    });
  }

  /// Boş slotları doldur (fotoğrafları sola kaydır)
  void _compactPhotos() {
    final nonNullPhotos = _selectedPhotos.where((p) => p != null).toList();
    for (int i = 0; i < 6; i++) {
      _selectedPhotos[i] = i < nonNullPhotos.length ? nonNullPhotos[i] : null;
    }
  }

  Widget _buildImageSourceOption({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 70,
            height: 70,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF5C6BC0), Color(0xFF7986CB)],
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(icon, color: Colors.white, size: 32),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  void _showError(String message) {
    if (!mounted) return;
    AppNotification.error(title: message);
  }

  void _showSuccess(String message, {String? subtitle}) {
    if (!mounted) return;
    AppNotification.success(title: message, subtitle: subtitle);
  }

  Future<void> _submitProfile() async {
    // Fotoğraf kontrolü
    if (!_hasMinimumPhotos) {
      _showError('En az 1 fotoğraf eklemelisin');
      return;
    }

    // Doğum tarihi kontrolü
    if (_selectedBirthDate == null) {
      _showError('Lütfen doğum tarihinizi seçin');
      return;
    }

    // 18 yaş kontrolü
    if (!_isAdult) {
      _showError('Uygulamayı kullanmak için 18 yaşından büyük olmalısınız');
      return;
    }

    if (!_formKey.currentState!.validate()) {
      return;
    }

    final profileData = ProfileData(
      name: _nameController.text.trim(),
      birthDate: _selectedBirthDate!,
      university: _universityController.text.trim(),
      department: _departmentController.text.trim(),
      bio: _bioController.text.trim(),
      gender: _selectedGender,
      lookingFor: _selectedLookingFor,
    );

    // Sadece dolu slotları al
    final photoFiles = _selectedPhotos.whereType<File>().toList();

    final success = await ref
        .read(profileCreationProvider.notifier)
        .createProfileWithPhotos(
          profileData: profileData,
          imageFiles: photoFiles,
        );

    if (success && mounted) {
      // Profil oluşturuldu, şimdi e-posta doğrulama ekranına git
      final authService = AuthService();
      
      _showSuccess('Profil Oluşturuldu',
          subtitle: 'Şimdi e-posta adresini doğrula!');

      await Future.delayed(const Duration(milliseconds: 800));
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => EmailVerificationScreen(
              email: authService.currentUserEmail,
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final creationState = ref.watch(profileCreationProvider);

    ref.listen<ProfileCreationState>(profileCreationProvider,
        (previous, current) {
      if (current.error != null && previous?.error != current.error) {
        _showError(current.error!);
      }
    });

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFFF5F8FF),
              Color(0xFFE8F0FE),
              Color(0xFFF0F4FF),
            ],
            stops: [0.0, 0.5, 1.0],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildHeader(),
                  const SizedBox(height: 24),

                  // Photo Grid Section
                  _buildPhotoGridSection(),
                  const SizedBox(height: 24),

                  // Form Fields
                  _buildFormFields(),
                  const SizedBox(height: 24),

                  // Gender Selection
                  _buildGenderSection(),
                  const SizedBox(height: 24),

                  // Looking For Selection
                  _buildLookingForSection(),
                  const SizedBox(height: 32),

                  // Submit Button with Progress
                  _buildSubmitButton(creationState),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.9),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF5C6BC0).withValues(alpha: 0.15),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: IconButton(
            onPressed: () => _showExitConfirmDialog(),
            icon: const Icon(
              Icons.arrow_back_ios_new,
              color: Color(0xFF5C6BC0),
              size: 22,
            ),
          ),
        ),
        const SizedBox(height: 24),
        Center(
          child: Column(
            children: [
              ShaderMask(
                shaderCallback: (bounds) => const LinearGradient(
                  colors: [Color(0xFF5C6BC0), Color(0xFF7986CB)],
                ).createShader(bounds),
                child: Text(
                  'Profilini Oluştur',
                  style: GoogleFonts.poppins(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Diğer kullanıcıların seni tanıması için\nprofilini tamamla',
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: Colors.grey[600],
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _showExitConfirmDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Text(
          'Profil Oluşturmayı İptal Et',
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
        ),
        content: Text(
          'Profil oluşturmadan çıkmak istediğinize emin misiniz? Tüm girdiğiniz bilgiler kaybolacak.',
          style: GoogleFonts.poppins(
            fontSize: 14,
            color: Colors.grey[600],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Devam Et',
              style: GoogleFonts.poppins(color: Colors.grey),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (context) => WelcomeScreen()),
                (route) => false,
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF5C6BC0),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              'Çıkış Yap',
              style: GoogleFonts.poppins(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  /// 6 slotlu fotoğraf grid bölümü
  Widget _buildPhotoGridSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF5C6BC0), Color(0xFF7986CB)],
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.photo_library,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'En İyi Fotoğraflarını Ekle',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[800],
                      ),
                    ),
                    Text(
                      '$_photoCount / 6 fotoğraf eklendi',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: _hasMinimumPhotos
                            ? const Color(0xFF5C6BC0)
                            : Colors.grey[500],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Photo Grid (2x3 layout with first slot larger)
          _buildPhotoGrid(),

          // Hint
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.amber.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Icon(Icons.tips_and_updates, color: Colors.amber[700], size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'İlk fotoğraf ana profil fotoğrafın olacak',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: Colors.amber[800],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Fotoğraf grid yapısı - Tinder/Bumble tarzı 6 slot
  Widget _buildPhotoGrid() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final gridWidth = constraints.maxWidth;
        final smallSlotSize = (gridWidth - 16) / 3; // 3 küçük slot (2 gap * 8px)
        final largeSlotHeight = smallSlotSize * 2 + 8; // 2 satır yüksekliği

        return Column(
          children: [
            // Üst satır: Ana fotoğraf (2x2) + 2 küçük fotoğraf
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Sol taraf: Ana fotoğraf (2x2 boyutunda)
                _buildPhotoSlot(
                  index: 0,
                  width: smallSlotSize * 2 + 8,
                  height: largeSlotHeight,
                  isPrimary: true,
                ),
                const SizedBox(width: 8),
                // Sağ taraf: 2 küçük fotoğraf (dikey)
                Column(
                  children: [
                    _buildPhotoSlot(
                      index: 1,
                      width: smallSlotSize,
                      height: smallSlotSize,
                    ),
                    const SizedBox(height: 8),
                    _buildPhotoSlot(
                      index: 2,
                      width: smallSlotSize,
                      height: smallSlotSize,
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Alt satır: 3 küçük fotoğraf
            Row(
              children: [
                _buildPhotoSlot(
                  index: 3,
                  width: smallSlotSize,
                  height: smallSlotSize,
                ),
                const SizedBox(width: 8),
                _buildPhotoSlot(
                  index: 4,
                  width: smallSlotSize,
                  height: smallSlotSize,
                ),
                const SizedBox(width: 8),
                _buildPhotoSlot(
                  index: 5,
                  width: smallSlotSize,
                  height: smallSlotSize,
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  /// Tek bir fotoğraf slotu
  Widget _buildPhotoSlot({
    required int index,
    required double width,
    required double height,
    bool isPrimary = false,
  }) {
    final photo = _selectedPhotos[index];
    final hasPhoto = photo != null;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: hasPhoto ? null : Colors.grey[100],
        borderRadius: BorderRadius.circular(isPrimary ? 16 : 12),
        border: Border.all(
          color: isPrimary
              ? (hasPhoto ? const Color(0xFF5C6BC0) : Colors.grey[300]!)
              : Colors.grey[300]!,
          width: isPrimary ? 2 : 1,
        ),
        image: hasPhoto
            ? DecorationImage(
                image: FileImage(photo),
                fit: BoxFit.cover,
              )
            : null,
        boxShadow: hasPhoto
            ? [
                BoxShadow(
                  color: const Color(0xFF5C6BC0).withValues(alpha: 0.2),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: hasPhoto ? null : () => _showImagePickerForSlot(index),
          borderRadius: BorderRadius.circular(isPrimary ? 16 : 12),
          child: Stack(
            children: [
              // Boş slot içeriği
              if (!hasPhoto)
                Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.1),
                              blurRadius: 10,
                            ),
                          ],
                        ),
                        child: Icon(
                          Icons.add_photo_alternate,
                          color: const Color(0xFF5C6BC0),
                          size: isPrimary ? 32 : 24,
                        ),
                      ),
                      if (isPrimary) ...[
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF5C6BC0),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            'Ana Fotoğraf',
                            style: GoogleFonts.poppins(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

              // Fotoğraf varsa: Ana fotoğraf etiketi
              if (hasPhoto && isPrimary)
                Positioned(
                  bottom: 8,
                  left: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.95),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.2),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.star,
                          size: 14,
                          color: Color(0xFF5C6BC0),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Ana Fotoğraf',
                          style: GoogleFonts.poppins(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF5C6BC0),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              // Silme butonu
              if (hasPhoto)
                Positioned(
                  top: 6,
                  right: 6,
                  child: GestureDetector(
                    onTap: () => _removePhoto(index),
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.6),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.close,
                        color: Colors.white,
                        size: 16,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFormFields() {
    return Column(
      children: [
        _buildTextField(
          controller: _nameController,
          label: 'İsim',
          hint: 'Adınızı girin',
          icon: Icons.person_outline,
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'İsim gerekli';
            }
            if (value.trim().length < 2) {
              return 'İsim en az 2 karakter olmalı';
            }
            return null;
          },
        ),
        const SizedBox(height: 16),
        _buildBirthDateField(),
        const SizedBox(height: 16),
        _buildAutocompleteField(
          controller: _universityController,
          label: 'Üniversite',
          hint: 'Üniversite ara...',
          icon: Icons.school_outlined,
          suggestions: TurkishUniversities.universities,
        ),
        const SizedBox(height: 16),
        _buildAutocompleteField(
          controller: _departmentController,
          label: 'Bölüm',
          hint: 'Bölüm ara...',
          icon: Icons.work_outline,
          suggestions: TurkishUniversities.departments,
        ),
        const SizedBox(height: 16),
        _buildTextField(
          controller: _bioController,
          label: 'Hakkında',
          hint: 'Kendinden bahset...',
          icon: Icons.edit_note,
          maxLines: 4,
          maxLength: 300,
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Bio gerekli';
            }
            if (value.trim().length < 10) {
              return 'En az 10 karakter yazın';
            }
            return null;
          },
        ),
      ],
    );
  }

  static const _turkishMonths = [
    'Ocak', 'Şubat', 'Mart', 'Nisan', 'Mayıs', 'Haziran',
    'Temmuz', 'Ağustos', 'Eylül', 'Ekim', 'Kasım', 'Aralık'
  ];

  Widget _buildBirthDateField() {
    final hasDate = _selectedBirthDate != null;
    final formattedDate = hasDate
        ? '${_selectedBirthDate!.day} ${_turkishMonths[_selectedBirthDate!.month - 1]} ${_selectedBirthDate!.year}'
        : null;

    return GestureDetector(
      onTap: _showBirthDatePicker,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
          border: !hasDate
              ? null
              : Border.all(
                  color: _isAdult ? const Color(0xFF5C6BC0) : Colors.red,
                  width: 2,
                ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        child: Row(
          children: [
            Icon(
              Icons.cake_outlined,
              color: hasDate
                  ? (_isAdult ? const Color(0xFF5C6BC0) : Colors.red)
                  : const Color(0xFF5C6BC0),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Doğum Tarihi',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    hasDate ? formattedDate! : 'Tarih seçin',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: hasDate ? FontWeight.w500 : FontWeight.normal,
                      color: hasDate ? Colors.grey[800] : Colors.grey[400],
                    ),
                  ),
                ],
              ),
            ),
            if (hasDate) ...[
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: _isAdult
                      ? const Color(0xFF5C6BC0).withValues(alpha: 0.1)
                      : Colors.red.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '$_calculatedAge yaş',
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: _isAdult ? const Color(0xFF5C6BC0) : Colors.red,
                  ),
                ),
              ),
            ] else ...[
              Icon(Icons.calendar_month, color: Colors.grey[400]),
            ],
          ],
        ),
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
    String? Function(String?)? validator,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: TextFormField(
        controller: controller,
        maxLines: maxLines,
        maxLength: maxLength,
        keyboardType: keyboardType,
        validator: validator,
        style: GoogleFonts.poppins(fontSize: 14),
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          prefixIcon: Icon(icon, color: const Color(0xFF5C6BC0)),
          labelStyle: GoogleFonts.poppins(color: Colors.grey[600]),
          hintStyle: GoogleFonts.poppins(color: Colors.grey[400]),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: Color(0xFF5C6BC0), width: 2),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: Colors.red, width: 1),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: Colors.red, width: 2),
          ),
          filled: true,
          fillColor: Colors.white,
          counterStyle: GoogleFonts.poppins(fontSize: 12),
        ),
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
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Autocomplete<String>(
        optionsBuilder: (TextEditingValue textEditingValue) {
          if (textEditingValue.text.isEmpty) {
            return suggestions.take(10);
          }
          final query = textEditingValue.text.toLowerCase();
          return suggestions
              .where((option) => option.toLowerCase().contains(query))
              .take(20);
        },
        onSelected: (String selection) {
          controller.text = selection;
        },
        fieldViewBuilder:
            (context, textController, focusNode, onFieldSubmitted) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (controller.text.isNotEmpty && textController.text.isEmpty) {
              textController.text = controller.text;
            }
          });

          return TextFormField(
            controller: textController,
            focusNode: focusNode,
            style: GoogleFonts.poppins(fontSize: 14),
            onChanged: (value) {
              controller.text = value;
            },
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return '$label gerekli';
              }
              return null;
            },
            decoration: InputDecoration(
              labelText: label,
              hintText: hint,
              prefixIcon: Icon(icon, color: const Color(0xFF5C6BC0)),
              suffixIcon: const Icon(Icons.arrow_drop_down, color: Colors.grey),
              labelStyle: GoogleFonts.poppins(color: Colors.grey[600]),
              hintStyle: GoogleFonts.poppins(color: Colors.grey[400]),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide:
                    const BorderSide(color: Color(0xFF5C6BC0), width: 2),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: Colors.red, width: 1),
              ),
              focusedErrorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: Colors.red, width: 2),
              ),
              filled: true,
              fillColor: Colors.white,
            ),
          );
        },
        optionsViewBuilder: (context, onSelected, options) {
          return Align(
            alignment: Alignment.topLeft,
            child: Material(
              elevation: 4,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                constraints: const BoxConstraints(maxHeight: 200),
                width: MediaQuery.of(context).size.width - 48,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ListView.builder(
                  padding: EdgeInsets.zero,
                  shrinkWrap: true,
                  itemCount: options.length,
                  itemBuilder: (context, index) {
                    final option = options.elementAt(index);
                    return ListTile(
                      dense: true,
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
      ),
    );
  }

  Widget _buildGenderSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 12),
          child: Text(
            'Cinsiyetiniz',
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.grey[800],
            ),
          ),
        ),
        Row(
          children: _genderOptions.map((gender) {
            final isSelected = _selectedGender == gender;
            return Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _selectedGender = gender),
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    gradient: isSelected
                        ? const LinearGradient(
                            colors: [Color(0xFF5C6BC0), Color(0xFF7986CB)],
                          )
                        : null,
                    color: isSelected ? null : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: isSelected
                            ? const Color(0xFF5C6BC0).withValues(alpha: 0.3)
                            : Colors.black.withValues(alpha: 0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Text(
                    gender,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: isSelected ? Colors.white : Colors.grey[700],
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildLookingForSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 12),
          child: Text(
            'Kimleri arıyorsun?',
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.grey[800],
            ),
          ),
        ),
        Row(
          children: _lookingForOptions.map((option) {
            final isSelected = _selectedLookingFor == option;
            return Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _selectedLookingFor = option),
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    gradient: isSelected
                        ? const LinearGradient(
                            colors: [Color(0xFF5C6BC0), Color(0xFF7986CB)],
                          )
                        : null,
                    color: isSelected ? null : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: isSelected
                            ? const Color(0xFF5C6BC0).withValues(alpha: 0.3)
                            : Colors.black.withValues(alpha: 0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Text(
                    option,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: isSelected ? Colors.white : Colors.grey[700],
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildSubmitButton(ProfileCreationState state) {
    final isUploading = state.status == ProfileCreationStatus.uploadingImage;
    final isSaving = state.status == ProfileCreationStatus.savingProfile;

    return Column(
      children: [
        // Progress bar (only when uploading)
        if (isUploading)
          Container(
            margin: const EdgeInsets.only(bottom: 16),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Fotoğraflar yükleniyor...',
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        color: Colors.grey[600],
                      ),
                    ),
                    Text(
                      '${(state.uploadProgress * 100).toInt()}%',
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF5C6BC0),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: state.uploadProgress,
                    minHeight: 8,
                    backgroundColor: Colors.grey[200],
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      Color(0xFF5C6BC0),
                    ),
                  ),
                ),
              ],
            ),
          ),

        // Submit button
        Container(
          height: 56,
          decoration: BoxDecoration(
            gradient: _hasMinimumPhotos
                ? const LinearGradient(
                    colors: [Color(0xFF5C6BC0), Color(0xFF7986CB)],
                  )
                : null,
            color: _hasMinimumPhotos ? null : Colors.grey[300],
            borderRadius: BorderRadius.circular(16),
            boxShadow: _hasMinimumPhotos
                ? [
                    BoxShadow(
                      color: const Color(0xFF5C6BC0).withValues(alpha: 0.4),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ]
                : null,
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: state.isLoading || !_hasMinimumPhotos
                  ? null
                  : _submitProfile,
              borderRadius: BorderRadius.circular(16),
              child: Center(
                child: state.isLoading
                    ? Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            isSaving
                                ? 'Profil kaydediliyor...'
                                : 'Fotoğraflar yükleniyor...',
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      )
                    : Text(
                        _hasMinimumPhotos
                            ? 'Kaydet ve Başla'
                            : 'En az 1 fotoğraf ekle',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: _hasMinimumPhotos
                              ? Colors.white
                              : Colors.grey[600],
                        ),
                      ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
