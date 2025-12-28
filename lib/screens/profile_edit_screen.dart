import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import '../services/profile_service.dart';
import '../data/turkish_universities.dart';
import '../widgets/custom_notification.dart';

class ProfileEditScreen extends StatefulWidget {
  const ProfileEditScreen({super.key});

  @override
  State<ProfileEditScreen> createState() => _ProfileEditScreenState();
}

class _ProfileEditScreenState extends State<ProfileEditScreen> {
  final ProfileService _profileService = ProfileService();
  final ImagePicker _picker = ImagePicker();

  final _nameController = TextEditingController();
  final _ageController = TextEditingController();
  final _bioController = TextEditingController();
  final _universityController = TextEditingController();
  final _departmentController = TextEditingController();

  String _selectedGender = 'Erkek';
  String _lookingFor = 'Kadın';

  List<String?> _photoUrls = List.filled(6, null);
  List<File?> _localPhotos = List.filled(6, null);
  List<String> _selectedInterests = [];

  bool _isLoading = false;
  bool _isSaving = false;

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
  }

  @override
  void dispose() {
    _nameController.dispose();
    _ageController.dispose();
    _bioController.dispose();
    _universityController.dispose();
    _departmentController.dispose();
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

      List<dynamic> photos = profile['photos'] ?? [];
      for (int i = 0; i < photos.length && i < 6; i++) {
        _photoUrls[i] = photos[i];
      }
    }

    setState(() => _isLoading = false);
  }

  Future<void> _pickImage(int index) async {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
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
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.pink.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.camera_alt, color: Colors.pink),
              ),
              title: const Text('Kamera'),
              onTap: () {
                Navigator.pop(context);
                _getImage(ImageSource.camera, index);
              },
            ),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.pink.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.photo_library, color: Colors.pink),
              ),
              title: const Text('Galeri'),
              onTap: () {
                Navigator.pop(context);
                _getImage(ImageSource.gallery, index);
              },
            ),
            if (_photoUrls[index] != null || _localPhotos[index] != null)
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.delete, color: Colors.red),
                ),
                title: const Text('Fotoğrafı Sil'),
                onTap: () {
                  Navigator.pop(context);
                  setState(() {
                    _photoUrls[index] = null;
                    _localPhotos[index] = null;
                  });
                },
              ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Future<void> _getImage(ImageSource source, int index) async {
    try {
      final XFile? image = await _picker.pickImage(
        source: source,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );

      if (image != null) {
        setState(() {
          _localPhotos[index] = File(image.path);
          _photoUrls[index] = null;
        });
      }
    } catch (e) {
      _showError('Fotoğraf seçilemedi');
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

    if (_photoUrls[0] == null && _localPhotos[0] == null) {
      _showError('En az bir fotoğraf eklemelisiniz');
      return;
    }

    setState(() => _isSaving = true);

    try {
      // Önce yeni fotoğrafları yükle
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

      // Profili kaydet
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
      );

      if (success) {
        if (mounted) {
          _showSuccess('Profil Kaydedildi',
              subtitle: 'Değişiklikleriniz başarıyla güncellendi');
          await Future.delayed(const Duration(milliseconds: 500));
          if (mounted) Navigator.pop(context, true);
        }
      } else {
        _showError('Profil kaydedilemedi');
      }
    } catch (e) {
      _showError('Bir hata oluştu: $e');
    }

    setState(() => _isSaving = false);
  }

  void _showError(String message) {
    if (!mounted) return;
    CustomNotification.error(context, message);
  }

  void _showSuccess(String message, {String? subtitle}) {
    if (!mounted) return;
    CustomNotification.success(context, message, subtitle: subtitle);
  }

  void _showWarning(String message) {
    if (!mounted) return;
    CustomNotification.warning(context, message);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: Text(
          'Profili Düzenle',
          style: GoogleFonts.poppins(
            color: Colors.black,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
        actions: [
          TextButton(
            onPressed: _isSaving ? null : _saveProfile,
            child: _isSaving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(
                    'Kaydet',
                    style: GoogleFonts.poppins(
                      color: Colors.pink,
                      fontWeight: FontWeight.w600,
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
              const Icon(Icons.photo_library, color: Colors.pink),
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
          border: isMainPhoto ? Border.all(color: Colors.pink, width: 2) : null,
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
                  color: hasPhoto ? Colors.white : Colors.pink,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 4,
                    ),
                  ],
                ),
                child: Icon(
                  hasPhoto ? Icons.edit : Icons.add,
                  size: 14,
                  color: hasPhoto ? Colors.pink : Colors.white,
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
                    color: Colors.pink,
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
        prefixIcon: Icon(icon, color: Colors.pink),
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
          borderSide: const BorderSide(color: Colors.pink),
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
            prefixIcon: Icon(icon, color: Colors.pink),
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
              borderSide: const BorderSide(color: Colors.pink),
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
            () => setState(() => _selectedGender = 'Erkek'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildSelectableOption(
            'Kadın',
            Icons.female,
            _selectedGender == 'Kadın',
            () => setState(() => _selectedGender = 'Kadın'),
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
            () => setState(() => _lookingFor = 'Erkek'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildSelectableOption(
            'Kadın',
            Icons.female,
            _lookingFor == 'Kadın',
            () => setState(() => _lookingFor = 'Kadın'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildSelectableOption(
            'Herkes',
            Icons.people,
            _lookingFor == 'Herkes',
            () => setState(() => _lookingFor = 'Herkes'),
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
          color: isSelected ? Colors.pink : Colors.grey[100],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? Colors.pink : Colors.grey[300]!,
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
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: isSelected ? Colors.pink : Colors.grey[100],
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isSelected ? Colors.pink : Colors.grey[300]!,
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

}
