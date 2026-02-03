import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../providers/swipe_provider.dart';
import '../premium/premium_offer_screen.dart';
import '../../data/university_data.dart';
import '../../data/turkish_universities.dart';

/// Gelişmiş Filtre Modalı (Premium Özelliği)
/// 
/// Stratej: "Görünsün ama Premium değilse Seçilmesin"
/// - Tüm filtreler görünür
/// - Premium değilse tıklandığında PremiumOfferScreen açılır
class FiltersModal extends ConsumerStatefulWidget {
  const FiltersModal({super.key});

  @override
  ConsumerState<FiltersModal> createState() => _FiltersModalState();
}

class _FiltersModalState extends ConsumerState<FiltersModal> {
  bool _isPremium = false;
  bool _isApplying = false; // Uygula / Temizle sırasında loading overlay
  String _applyingMessage = 'Uygulanıyor...'; // "Uygulanıyor..." veya "Temizleniyor..."

  String? _selectedGender; // PREMIUM DEĞİL - Herkes kullanabilir
  String? _selectedCity;
  String? _selectedUniversity;
  String? _selectedDepartment;
  String? _selectedGrade;

  @override
  void initState() {
    super.initState();
    _checkPremiumStatus();
    _loadCurrentFilters();
  }

  Future<void> _checkPremiumStatus() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (userDoc.exists) {
        final isPremium = userDoc.data()?['isPremium'] as bool? ?? false;
        setState(() => _isPremium = isPremium);
      }
    } catch (e) {
      debugPrint('Error checking premium status: $e');
    }
  }

  void _loadCurrentFilters() {
    debugPrint('📥 [FiltersModal] Mevcut filtreler yükleniyor...');
    final swipeState = ref.read(swipeProvider);
    debugPrint('   - Provider\'dan gelen genderFilter: ${swipeState.genderFilter}');
    debugPrint('   - Provider\'dan gelen filterCity: ${swipeState.filterCity}');
    debugPrint('   - Provider\'dan gelen filterUniversity: ${swipeState.filterUniversity}');
    debugPrint('   - Provider\'dan gelen filterDepartment: ${swipeState.filterDepartment}');
    debugPrint('   - Provider\'dan gelen filterGrade: ${swipeState.filterGrade}');

    setState(() {
      // Gender filtresi: null veya boş ise otomatik "Herkes"e çevir
      _selectedGender = (swipeState.genderFilter == null || swipeState.genderFilter!.isEmpty) 
          ? 'Herkes' 
          : swipeState.genderFilter;
      _selectedCity = swipeState.filterCity;
      _selectedUniversity = swipeState.filterUniversity;
      _selectedDepartment = swipeState.filterDepartment;
      _selectedGrade = swipeState.filterGrade;
    });

    debugPrint('✅ [FiltersModal] Local state güncellendi:');
    debugPrint('   - _selectedGender: $_selectedGender');
    debugPrint('   - _selectedCity: $_selectedCity');
    debugPrint('   - _selectedUniversity: $_selectedUniversity');
    debugPrint('   - _selectedDepartment: $_selectedDepartment');
    debugPrint('   - _selectedGrade: $_selectedGrade');
  }

  void _handleFilterTap(BuildContext context) {
    if (!_isPremium) {
      Navigator.pop(context); // Modalı kapat
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => const PremiumOfferScreen(),
        ),
      );
    }
  }

  Future<void> _applyFilters() async {
    HapticFeedback.mediumImpact();
    debugPrint('🔍 [FiltersModal] Uygula butonuna basıldı');
    debugPrint('📍 Gender: $_selectedGender');
    debugPrint('📍 City: $_selectedCity');
    debugPrint('📍 University: $_selectedUniversity');
    debugPrint('📍 Department: $_selectedDepartment');
    debugPrint('📍 Grade: $_selectedGrade');
    debugPrint('👤 isPremium: $_isPremium');

    // Gender filtresi için premium kontrolü YOK!
    // Premium filtreler için kontrol yap
    if (!_isPremium && 
        (_selectedCity != null || 
         _selectedUniversity != null || 
         _selectedDepartment != null || 
         _selectedGrade != null)) {
      debugPrint('⚠️ Premium değil ama premium filtre seçili - Premium ekranına yönlendiriliyor');
      _handleFilterTap(context);
      return;
    }

    if (!mounted) return;
    setState(() {
      _isApplying = true;
      _applyingMessage = 'Uygulanıyor...';
    });

    try {
      debugPrint('✅ Filtreler uygulanıyor...');
      await ref.read(swipeProvider.notifier).setFilters(
            gender: _selectedGender,
            city: _selectedCity,
            university: _selectedUniversity,
            department: _selectedDepartment,
            grade: _selectedGrade,
          );
      debugPrint('✅ Filtreler uygulandı, modal kapatılıyor');
      if (mounted) Navigator.pop(context);
    } finally {
      if (mounted) setState(() => _isApplying = false);
    }
  }

  Future<void> _clearFilters() async {
    HapticFeedback.mediumImpact();
    // Gender filtresini temizlemek için premium gerekmez
    setState(() {
      _selectedGender = 'Herkes'; // ← Gender otomatik "Herkes"e dönüyor! ✅
      _selectedCity = null;
      _selectedUniversity = null;
      _selectedDepartment = null;
      _selectedGrade = null;
      _isApplying = true;
      _applyingMessage = 'Temizleniyor...';
    });

    try {
      await ref.read(swipeProvider.notifier).clearFilters();
      if (mounted) Navigator.pop(context);
    } finally {
      if (mounted) setState(() => _isApplying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Stack(
        children: [
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Drag Handle
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Gelişmiş Filtreler',
                  style: GoogleFonts.poppins(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF212121),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFFFB300), Color(0xFFFFA000)],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.workspace_premium_rounded, size: 16, color: Colors.white),
                      const SizedBox(width: 4),
                      Text(
                        'Premium',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const Divider(height: 1),

          // Filters List
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  // Kiminle Tanışmak İstiyorsun (FREE - Premium değil!)
                  _buildFilterTile(
                    icon: Icons.people_rounded,
                    label: 'Kiminle Tanışmak İstiyorsun?',
                    value: _selectedGender,
                    options: _genderOptions,
                    isPremiumOnly: false, // FREE özellik!
                    showClearOption: false, // Gender için "Seçim Yapma" yok! ✅
                    onSelect: (value) {
                      setState(() => _selectedGender = value);
                    },
                  ),

                  const SizedBox(height: 16),

                  // İl Filter
                  _buildFilterTile(
                    icon: Icons.location_city_rounded,
                    label: 'İl',
                    value: _selectedCity,
                    options: _cityOptions,
                    isPremiumOnly: true,
                    onSelect: (value) {
                      if (_isPremium) {
                        setState(() {
                          _selectedCity = value;
                          // İl değişince: Seçili üniversite yeni ilde yoksa temizle
                          if (value != null &&
                              _selectedUniversity != null &&
                              !UniversityData.getUniversitiesInCity(value).contains(_selectedUniversity)) {
                            _selectedUniversity = null;
                          }
                        });
                      } else {
                        _handleFilterTap(context);
                      }
                    },
                  ),

                  const SizedBox(height: 16),

                  // Üniversite Filter (seçilen ile senkronize)
                  _buildFilterTile(
                    icon: Icons.school_rounded,
                    label: 'Üniversite',
                    value: _selectedUniversity,
                    options: _getUniversityOptions(),
                    isPremiumOnly: true,
                    onSelect: (value) {
                      if (_isPremium) {
                        setState(() => _selectedUniversity = value);
                      } else {
                        _handleFilterTap(context);
                      }
                    },
                  ),

                  const SizedBox(height: 16),

                  // Bölüm Filter
                  _buildFilterTile(
                    icon: Icons.book_rounded,
                    label: 'Bölüm',
                    value: _selectedDepartment,
                    options: _departmentOptions,
                    isPremiumOnly: true,
                    onSelect: (value) {
                      if (_isPremium) {
                        setState(() => _selectedDepartment = value);
                      } else {
                        _handleFilterTap(context);
                      }
                    },
                  ),

                  const SizedBox(height: 16),

                  // Sınıf Filter
                  _buildFilterTile(
                    icon: Icons.calendar_today_rounded,
                    label: 'Sınıf',
                    value: _selectedGrade,
                    options: _gradeOptions,
                    isPremiumOnly: true,
                    onSelect: (value) {
                      if (_isPremium) {
                        setState(() => _selectedGrade = value);
                      } else {
                        _handleFilterTap(context);
                      }
                    },
                  ),
                ],
              ),
            ),
          ),

          const Divider(height: 1),

          // Action Buttons
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                // Clear Button
                Expanded(
                  child: OutlinedButton(
                    onPressed: _isApplying ? null : _clearFilters,
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      side: const BorderSide(color: Color(0xFFFF4458)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: Text(
                      'Temizle',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFFFF4458),
                      ),
                    ),
                  ),
                ),

                const SizedBox(width: 12),

                // Apply Button
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: _isApplying ? null : _applyFilters,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: const Color(0xFF5C6BC0),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 0,
                    ),
                    child: Text(
                      'Uygula',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
            ],
          ),
          // Loading overlay (Uygula / Temizle sırasında) - animasyonlu ve şık
          if (_isApplying)
            Positioned.fill(
              child: TweenAnimationBuilder<double>(
                key: const ValueKey('filter_loading_overlay'),
                tween: Tween(begin: 0, end: 1),
                duration: const Duration(milliseconds: 280),
                curve: Curves.easeOutCubic,
                builder: (context, value, _) {
                  return Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.92 * value),
                      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                    ),
                    child: Center(
                      child: TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0.85, end: 1),
                        duration: const Duration(milliseconds: 350),
                        curve: Curves.easeOutBack,
                        builder: (context, scale, _) {
                          return Transform.scale(
                            scale: scale * value,
                            child: _buildLoadingCard(),
                          );
                        },
                      ),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  /// Animasyonlu, şık loading kartı (Uygulanıyor / Temizleniyor)
  Widget _buildLoadingCard() {
    const indigo = Color(0xFF5C6BC0);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: indigo.withValues(alpha: 0.12),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Çift halkalı spinner
          SizedBox(
            width: 64,
            height: 64,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Arka halka (track)
                SizedBox(
                  width: 64,
                  height: 64,
                  child: CircularProgressIndicator(
                    value: 1,
                    strokeWidth: 4,
                    valueColor: AlwaysStoppedAnimation<Color>(indigo.withValues(alpha: 0.18)),
                    backgroundColor: Colors.transparent,
                  ),
                ),
                // Ön halka (indeterminate animasyon)
                SizedBox(
                  width: 56,
                  height: 56,
                  child: CircularProgressIndicator(
                    strokeWidth: 3,
                    valueColor: const AlwaysStoppedAnimation<Color>(indigo),
                    backgroundColor: Colors.transparent,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Text(
            _applyingMessage,
            style: GoogleFonts.poppins(
              fontSize: 17,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF37474F),
              letterSpacing: 0.2,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Lütfen bekleyin',
            style: GoogleFonts.poppins(
              fontSize: 13,
              fontWeight: FontWeight.w400,
              color: Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterTile({
    required IconData icon,
    required String label,
    required String? value,
    required List<String> options,
    required ValueChanged<String?> onSelect,
    bool isPremiumOnly = true, // Varsayılan: Premium gerekli
    bool showClearOption = true, // Gender için false
  }) {
    final isLocked = isPremiumOnly && !_isPremium;

    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        if (isLocked) {
          _handleFilterTap(context);
        } else {
          _showOptionsBottomSheet(
            label: label,
            options: options,
            currentValue: value,
            onSelect: onSelect,
            showClearOption: showClearOption, // ← YENİ parametre! ✅
          );
        }
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isLocked ? Colors.grey[100] : Colors.white,
          border: Border.all(
            color: isLocked ? Colors.grey[300]! : const Color(0xFFE0E0E0),
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            // Icon
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFF5C6BC0).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, size: 24, color: const Color(0xFF5C6BC0)),
            ),

            const SizedBox(width: 16),

            // Label & Value
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF616161),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    value ?? 'Seçilmedi',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: value != null ? const Color(0xFF212121) : const Color(0xFF9E9E9E),
                    ),
                  ),
                ],
              ),
            ),

            // Lock Icon or Arrow
            if (isLocked)
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFFB300), Color(0xFFFFA000)],
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.lock_rounded, size: 20, color: Colors.white),
              )
            else
              const Icon(Icons.chevron_right_rounded, size: 24, color: Color(0xFF9E9E9E)),
          ],
        ),
      ),
    );
  }

  void _showOptionsBottomSheet({
    required String label,
    required List<String> options,
    required String? currentValue,
    required ValueChanged<String?> onSelect,
    bool showClearOption = true, // Gender için false olacak
  }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => _SearchableOptionsSheet(
        label: label,
        options: options,
        currentValue: currentValue,
        onSelect: onSelect,
        showClearOption: showClearOption,
      ),
    );
  }

  // ============ STATİK FİLTRE SEÇENEKLERİ ============

  static final List<String> _genderOptions = [
    'Kadın',
    'Erkek',
    'Herkes',
  ];

  // İl seçenekleri - UniversityData'dan dinamik olarak yükleniyor
  static final List<String> _cityOptions = UniversityData.getAllCitiesSorted();

  /// Üniversite seçenekleri: İl seçiliyse sadece o ildeki üniversiteler, değilse tümü
  List<String> _getUniversityOptions() {
    if (_selectedCity == null || _selectedCity!.isEmpty) {
      return UniversityData.getAllUniversitiesSorted();
    }
    return UniversityData.getUniversitiesInCity(_selectedCity!);
  }

  // Bölüm seçenekleri - TurkishUniversities'ten (popülerler üstte, arama ile)
  static final List<String> _departmentOptions =
      TurkishUniversities.getAllDepartmentsSorted();

  static final List<String> _gradeOptions = [
    'Hazırlık',
    '1. Sınıf',
    '2. Sınıf',
    '3. Sınıf',
    '4. Sınıf',
    'Yüksek Lisans',
  ];
}

/// Arama Özellikli Seçenek Listesi
class _SearchableOptionsSheet extends StatefulWidget {
  final String label;
  final List<String> options;
  final String? currentValue;
  final ValueChanged<String?> onSelect;
  final bool showClearOption;

  const _SearchableOptionsSheet({
    required this.label,
    required this.options,
    required this.currentValue,
    required this.onSelect,
    required this.showClearOption,
  });

  @override
  State<_SearchableOptionsSheet> createState() => _SearchableOptionsSheetState();
}

class _SearchableOptionsSheetState extends State<_SearchableOptionsSheet> {
  late List<String> _filteredOptions;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _filteredOptions = widget.options;
    _searchController.addListener(_filterOptions);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _filterOptions() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _filteredOptions = widget.options;
      } else {
        _filteredOptions = widget.options
            .where((option) => option.toLowerCase().contains(query))
            .toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag Handle
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.all(20),
            child: Text(
              widget.label,
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF212121),
              ),
            ),
          ),

          const Divider(height: 1),

          // Search Field (Sadece çok seçenek varsa göster)
          if (widget.options.length > 10)
            Padding(
              padding: const EdgeInsets.all(16),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Ara...',
                  hintStyle: GoogleFonts.poppins(
                    fontSize: 14,
                    color: Colors.grey[400],
                  ),
                  prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF5C6BC0)),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear_rounded, size: 20),
                          onPressed: () {
                            _searchController.clear();
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: Colors.grey[100],
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
              ),
            ),

          // Options List
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: widget.showClearOption ? _filteredOptions.length + 1 : _filteredOptions.length,
              itemBuilder: (context, index) {
                if (widget.showClearOption && index == 0) {
                  // "Seçim Yapma" option (SADECE premium filtreler için)
                  return ListTile(
                    leading: const Icon(Icons.clear_rounded, color: Color(0xFFFF4458)),
                    title: Text(
                      'Seçim Yapma',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: const Color(0xFFFF4458),
                      ),
                    ),
                    trailing: widget.currentValue == null
                        ? const Icon(Icons.check_rounded, color: Color(0xFF5C6BC0))
                        : null,
                    onTap: () {
                      HapticFeedback.selectionClick();
                      debugPrint('🔄 [Filter] Seçim kaldırıldı: ${widget.label}');
                      widget.onSelect(null);
                      Navigator.pop(context);
                    },
                  );
                }

                final optionIndex = widget.showClearOption ? index - 1 : index;
                final option = _filteredOptions[optionIndex];
                final isSelected = widget.currentValue == option;

                return ListTile(
                  title: Text(
                    option,
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                      color: isSelected ? const Color(0xFF5C6BC0) : const Color(0xFF212121),
                    ),
                  ),
                  trailing: isSelected
                      ? const Icon(Icons.check_rounded, color: Color(0xFF5C6BC0))
                      : null,
                  onTap: () {
                    HapticFeedback.selectionClick();
                    debugPrint('✅ [Filter] Seçim yapıldı: ${widget.label} = $option');
                    widget.onSelect(option);
                    Navigator.pop(context);
                  },
                );
              },
            ),
          ),

          const SizedBox(height: 20),
        ],
      ),
    );
  }
}
