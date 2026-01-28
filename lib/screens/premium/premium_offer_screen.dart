import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import '../../services/purchase_service.dart';
import '../../widgets/app_notification.dart';

/// Premium satış ekranı
/// 
/// RevenueCat ile entegre, şık ve modern tasarım.
/// Abonelik paketlerini gösterir ve satın alma işlemini yönetir.
class PremiumOfferScreen extends StatefulWidget {
  const PremiumOfferScreen({super.key});

  @override
  State<PremiumOfferScreen> createState() => _PremiumOfferScreenState();
}

class _PremiumOfferScreenState extends State<PremiumOfferScreen>
    with SingleTickerProviderStateMixin {
  final PurchaseService _purchaseService = PurchaseService();

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  // Seçili plan (0: Aylık, 1: 6 Aylık)
  int _selectedPlanIndex = 1; // Varsayılan olarak 6 aylık seçili

  // RevenueCat offerings (paketler)
  Offerings? _offerings;

  // Satın alma durumu
  bool _isPurchasing = false;
  bool _isRestoring = false;

  // Statik paket bilgileri (RevenueCat bağlanana kadar)
  final List<Map<String, dynamic>> _staticPlans = [
    {
      'id': 'monthly',
      'title': 'Aylık Plan',
      'price': '₺59,99',
      'period': '/ay',
      'description': 'İstediğin zaman iptal et',
      'isPopular': false,
      'discount': null,
    },
    {
      'id': 'sixmonth',
      'title': '6 Aylık Plan',
      'price': '₺299,99',
      'period': '/6 ay',
      'description': 'Ayda sadece ₺49,99 - %17 tasarruf',
      'isPopular': true,
      'discount': '17% İNDİRİM',
    },
  ];

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _loadOfferings();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _setupAnimations() {
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
      ),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.3, 1.0, curve: Curves.easeOutCubic),
      ),
    );

    _animationController.forward();
  }

  /// RevenueCat'ten offerings yükle
  Future<void> _loadOfferings() async {
    try {
      final offerings = await _purchaseService.getOfferings();
      if (mounted) {
        setState(() {
          _offerings = offerings;
        });
      }
    } catch (e) {
      debugPrint('Error loading offerings: $e');
    }
  }

  /// Satın alma işlemi
  Future<void> _handlePurchase() async {
    setState(() => _isPurchasing = true);

    try {
      // RevenueCat bağlıysa gerçek paket kullan
      if (_offerings?.current != null) {
        final packages = _offerings!.current!.availablePackages;
        if (packages.isEmpty) {
          _showError('Paket bulunamadı');
          setState(() => _isPurchasing = false);
          return;
        }

        // Seçili paketi bul (identifier'a göre)
        final selectedPackageId = _staticPlans[_selectedPlanIndex]['id'];
        final package = packages.firstWhere(
          (p) => p.identifier.contains(selectedPackageId),
          orElse: () => packages.first,
        );

        final result = await _purchaseService.purchasePackage(package);

        if (!mounted) return;

        if (result['success']) {
          _showSuccess('Premium Aktif! 🎉');
          // 1 saniye bekle ve geri dön
          await Future.delayed(const Duration(seconds: 1));
          if (mounted) {
            Navigator.pop(context, true); // true = premium activated
          }
        } else {
          final errorMsg = result['error'] ?? 'Satın alma başarısız';
          _showError(errorMsg);
        }
      } else {
        // RevenueCat bağlı değilse, placeholder mesajı göster
        _showError(
          'RevenueCat API Key\'leri henüz yapılandırılmadı.\n'
          'Apple onayından sonra aktif olacak.',
        );
      }
    } catch (e) {
      debugPrint('Purchase error: $e');
      _showError('Bir hata oluştu: $e');
    } finally {
      if (mounted) {
        setState(() => _isPurchasing = false);
      }
    }
  }

  /// Satın alımları geri yükle
  Future<void> _handleRestore() async {
    setState(() => _isRestoring = true);

    try {
      final result = await _purchaseService.restorePurchases();

      if (!mounted) return;

      if (result['success']) {
        if (result['isPremium']) {
          _showSuccess('Premium geri yüklendi! 🎉');
          await Future.delayed(const Duration(seconds: 1));
          if (mounted) {
            Navigator.pop(context, true);
          }
        } else {
          _showError('Aktif abonelik bulunamadı');
        }
      } else {
        _showError(result['error'] ?? 'Geri yükleme başarısız');
      }
    } catch (e) {
      debugPrint('Restore error: $e');
      _showError('Bir hata oluştu: $e');
    } finally {
      if (mounted) {
        setState(() => _isRestoring = false);
      }
    }
  }

  void _showSuccess(String message) {
    AppNotification.success(
      title: 'Başarılı',
      subtitle: message,
    );
  }

  void _showError(String message) {
    AppNotification.error(
      title: 'Hata',
      subtitle: message,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: SlideTransition(
            position: _slideAnimation,
            child: CustomScrollView(
              slivers: [
                // AppBar
                _buildAppBar(),

                // Premium header
                _buildPremiumHeader(),

                // Features list
                _buildFeaturesList(),

                // Plans selection
                _buildPlansSelection(),

                // Purchase button & restore
                _buildBottomActions(),

                // Bottom padding
                const SliverToBoxAdapter(
                  child: SizedBox(height: 32),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAppBar() {
    return SliverAppBar(
      floating: true,
      backgroundColor: Colors.transparent,
      elevation: 0,
      leading: IconButton(
        icon: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: const Icon(
            Icons.close_rounded,
            color: Color(0xFF5C6BC0),
            size: 20,
          ),
        ),
        onPressed: () => Navigator.pop(context),
      ),
    );
  }

  Widget _buildPremiumHeader() {
    return SliverToBoxAdapter(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF5C6BC0), Color(0xFF7E57C2)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF5C6BC0).withOpacity(0.4),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          children: [
            // Crown icon
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.workspace_premium_rounded,
                color: Colors.white,
                size: 48,
              ),
            ),
            const SizedBox(height: 16),
            // Title
            Text(
              'CampusGo Premium',
              style: GoogleFonts.poppins(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            // Subtitle
            Text(
              'Sınırsız eğlence, daha fazla eşleşme',
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: Colors.white.withOpacity(0.9),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeaturesList() {
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final feature = PurchaseService.premiumFeatures[index];
            return _buildFeatureItem(
              icon: feature['icon'],
              title: feature['title'],
              description: feature['description'],
              delay: index * 50,
            );
          },
          childCount: PurchaseService.premiumFeatures.length,
        ),
      ),
    );
  }

  Widget _buildFeatureItem({
    required String icon,
    required String title,
    required String description,
    required int delay,
  }) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 600 + delay),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 20 * (1 - value)),
            child: child,
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            // Icon
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF5C6BC0), Color(0xFF7E57C2)],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                icon,
                style: const TextStyle(fontSize: 24),
              ),
            ),
            const SizedBox(width: 16),
            // Text
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.poppins(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF212121),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    description,
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: const Color(0xFF757575),
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

  Widget _buildPlansSelection() {
    return SliverToBoxAdapter(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 12),
              child: Text(
                'Planını Seç',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF212121),
                ),
              ),
            ),
            ...List.generate(_staticPlans.length, (index) {
              return _buildPlanCard(index);
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildPlanCard(int index) {
    final plan = _staticPlans[index];
    final isSelected = _selectedPlanIndex == index;
    final isPopular = plan['isPopular'] == true;

    return GestureDetector(
      onTap: () => setState(() => _selectedPlanIndex = index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? const Color(0xFF5C6BC0) : Colors.transparent,
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: isSelected
                  ? const Color(0xFF5C6BC0).withOpacity(0.2)
                  : Colors.black.withOpacity(0.05),
              blurRadius: isSelected ? 16 : 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Stack(
          children: [
            // Popular badge
            if (isPopular)
              Positioned(
                top: -8,
                right: -8,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFFF6B6B), Color(0xFFFF8E53)],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'POPÜLER',
                    style: GoogleFonts.poppins(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),

            Row(
              children: [
                // Radio button
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isSelected
                          ? const Color(0xFF5C6BC0)
                          : const Color(0xFFBDBDBD),
                      width: 2,
                    ),
                    color: isSelected ? const Color(0xFF5C6BC0) : Colors.white,
                  ),
                  child: isSelected
                      ? const Icon(
                          Icons.check_rounded,
                          size: 16,
                          color: Colors.white,
                        )
                      : null,
                ),
                const SizedBox(width: 16),

                // Plan info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            plan['title'],
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF212121),
                            ),
                          ),
                          if (plan['discount'] != null) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFF4CAF50),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                plan['discount'],
                                style: GoogleFonts.poppins(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        plan['description'],
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: const Color(0xFF757575),
                        ),
                      ),
                    ],
                  ),
                ),

                // Price
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      plan['price'],
                      style: GoogleFonts.poppins(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF5C6BC0),
                      ),
                    ),
                    Text(
                      plan['period'],
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: const Color(0xFF757575),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomActions() {
    return SliverToBoxAdapter(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          children: [
            // Purchase button
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: _isPurchasing || _isRestoring ? null : _handlePurchase,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF5C6BC0),
                  foregroundColor: Colors.white,
                  elevation: 8,
                  shadowColor: const Color(0xFF5C6BC0).withOpacity(0.4),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  disabledBackgroundColor: const Color(0xFFBDBDBD),
                ),
                child: _isPurchasing
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : Text(
                        'Satın Al',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),

            const SizedBox(height: 16),

            // Restore button
            TextButton(
              onPressed: _isPurchasing || _isRestoring ? null : _handleRestore,
              child: _isRestoring
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF5C6BC0)),
                      ),
                    )
                  : Text(
                      'Satın Alımları Geri Yükle',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF5C6BC0),
                      ),
                    ),
            ),

            const SizedBox(height: 8),

            // Legal text
            Text(
              'Satın alma, otomatik yenileme aboneliğidir.\n'
              'İptal etmediğin sürece her dönem sonunda otomatik yenilenir.',
              style: GoogleFonts.poppins(
                fontSize: 11,
                color: const Color(0xFF9E9E9E),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
