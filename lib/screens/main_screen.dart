import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/notification_service.dart';
import '../services/auth_service.dart';
import 'discover_screen.dart';
import 'likes_screen.dart';
import 'chat_list_screen.dart';
import 'profile_edit_screen.dart';
import 'settings_screen.dart';
import 'welcome_screen.dart';

// Custom scroll behavior for better swipe detection
class _CustomPageScrollBehavior extends ScrollBehavior {
  @override
  Set<PointerDeviceKind> get dragDevices => {
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
        PointerDeviceKind.stylus,
        PointerDeviceKind.trackpad,
      };
}

/// Dikey scroll kilitleme özellikli PageView
///
/// Özellikler:
/// - Dikey scroll sırasında yatay sayfa geçişini engeller
/// - Standart sade kaydırma davranışı
class _DirectionalLockPageView extends StatefulWidget {
  final PageController controller;
  final ValueChanged<int> onPageChanged;
  final List<Widget> children;

  const _DirectionalLockPageView({
    required this.controller,
    required this.onPageChanged,
    required this.children,
  });

  @override
  State<_DirectionalLockPageView> createState() => _DirectionalLockPageViewState();
}

class _DirectionalLockPageViewState extends State<_DirectionalLockPageView> {
  // Gesture tracking
  Offset? _initialPosition;
  bool _directionDetermined = false;
  bool _isVerticalScroll = false;

  // Eşik değerleri
  static const double _directionThreshold = 12.0;
  static const double _verticalRatio = 1.3;

  void _onPointerDown(PointerDownEvent event) {
    _initialPosition = event.position;
    _directionDetermined = false;
    _isVerticalScroll = false;
  }

  void _onPointerMove(PointerMoveEvent event) {
    if (_initialPosition == null || _directionDetermined) return;

    final dx = (event.position.dx - _initialPosition!.dx).abs();
    final dy = (event.position.dy - _initialPosition!.dy).abs();
    final totalMovement = dx + dy;

    if (totalMovement > _directionThreshold) {
      _directionDetermined = true;

      if (dy > dx * _verticalRatio) {
        setState(() {
          _isVerticalScroll = true;
        });
      }
    }
  }

  void _onPointerUp(PointerUpEvent event) {
    _resetState();
  }

  void _onPointerCancel(PointerCancelEvent event) {
    _resetState();
  }

  void _resetState() {
    if (_isVerticalScroll) {
      setState(() {
        _isVerticalScroll = false;
      });
    }
    _initialPosition = null;
    _directionDetermined = false;
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: _onPointerDown,
      onPointerMove: _onPointerMove,
      onPointerUp: _onPointerUp,
      onPointerCancel: _onPointerCancel,
      child: ScrollConfiguration(
        behavior: _CustomPageScrollBehavior(),
        child: PageView(
          controller: widget.controller,
          onPageChanged: widget.onPageChanged,
          physics: _isVerticalScroll
              ? const NeverScrollableScrollPhysics()
              : const PageScrollPhysics(),
          allowImplicitScrolling: false, // Ön-yüklemeyi kapat
          pageSnapping: true, // Kesin sayfa sınırları
          children: widget.children,
        ),
      ),
    );
  }
}

class MainScreen extends StatefulWidget {
  final int initialIndex;

  const MainScreen({super.key, this.initialIndex = 2});

  /// Global tab index notifier - diğer ekranlar tab değişikliğini dinleyebilir
  static final ValueNotifier<int> currentTabNotifier = ValueNotifier<int>(2);

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  late int _currentIndex;
  late PageController _pageController;
  final AuthService _authService = AuthService();

  // Ban durumu stream subscription
  Stream<DocumentSnapshot>? _userStream;

  final List<Widget> _screens = [
    const ProfileEditScreen(),
    const LikesScreen(),
    const DiscoverScreen(),
    const ChatListScreen(),
    const SettingsScreen(),
  ];

  @override
  void initState() {
    super.initState();
    // Uygulama her açıldığında token'ı sessizce güncelle
    NotificationService.instance.getAndSaveToken();

    // Firestore Stream notification listener başlat (iOS fallback)
    NotificationService.instance.listenToInAppNotifications();

    // Navigasyon callback'i ayarla
    NotificationService.setNavigationCallback(_navigateToTab);

    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: _currentIndex);
    // Global notifier'ı başlangıç değeriyle ayarla
    MainScreen.currentTabNotifier.value = _currentIndex;

    // Ban durumu kontrolü başlat
    _startBanCheck();
  }

  /// Kullanıcının ban durumunu gerçek zamanlı dinle
  void _startBanCheck() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    _userStream = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .snapshots();

    _userStream!.listen((snapshot) {
      if (!mounted) return;

      if (snapshot.exists) {
        final data = snapshot.data() as Map<String, dynamic>?;
        final isBanned = data?['isBanned'] as bool? ?? false;

        if (isBanned) {
          _handleBannedUser();
        }
      }
    });
  }

  /// Banlı kullanıcıyı çıkış yaptır ve uyarı göster
  Future<void> _handleBannedUser() async {
    // Önce çıkış yap
    await _authService.signOut();

    if (!mounted) return;

    // Uyarı dialog göster
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.block_rounded,
                color: Colors.red,
                size: 28,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Hesap Askıya Alındı',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.bold,
                  color: Colors.red,
                  fontSize: 18,
                ),
              ),
            ),
          ],
        ),
        content: Text(
          'Hesabınız topluluk kurallarını ihlal ettiği için askıya alınmıştır.\n\n'
          'Bu kararın hatalı olduğunu düşünüyorsanız destek ekibimizle iletişime geçebilirsiniz.',
          style: GoogleFonts.poppins(
            fontSize: 14,
            color: Colors.grey[700],
          ),
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              // Login ekranına yönlendir
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => WelcomeScreen()),
                (route) => false,
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              'Tamam',
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _navigateToTab(int index) {
    if (mounted) {
      _pageController.animateToPage(
        index,
        duration: const Duration(milliseconds: 380),
        curve: Curves.easeInOutCubic,
      );
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    // Listener'ı durdur
    NotificationService.instance.stopListeningToNotifications();
    super.dispose();
  }

  void _onTabTapped(int index) {
    HapticFeedback.lightImpact();
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 380),
      curve: Curves.easeInOutCubic,
    );
  }

  void _onPageChanged(int index) {
    HapticFeedback.selectionClick();
    setState(() {
      _currentIndex = index;
    });
    // Global notifier'ı güncelle - diğer ekranlar dinleyebilir
    MainScreen.currentTabNotifier.value = index;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _DirectionalLockPageView(
        controller: _pageController,
        onPageChanged: _onPageChanged,
        children: _screens,
      ),
      bottomNavigationBar: _SlidingNavigationBar(
        currentIndex: _currentIndex,
        onTap: _onTabTapped,
      ),
    );
  }

}

/// Yüzen Baloncuk (Floating Bubble) animasyonlu özel navigation bar
///
/// Aktif ikon arkasında neon pembe baloncuk jöle efektiyle kayar
class _SlidingNavigationBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const _SlidingNavigationBar({
    required this.currentIndex,
    required this.onTap,
  });

  // Navigation item verileri
  static const List<_NavItemData> _items = [
    _NavItemData(Icons.person_outline_rounded, Icons.person_rounded, 'Profil'),
    _NavItemData(Icons.waving_hand_outlined, Icons.waving_hand_rounded, 'Istekler'),
    _NavItemData(Icons.explore_outlined, Icons.explore_rounded, 'Kesif'),
    _NavItemData(Icons.chat_bubble_outline_rounded, Icons.chat_bubble_rounded, 'Sohbet'),
    _NavItemData(Icons.settings_outlined, Icons.settings_rounded, 'Ayarlar'),
  ];

  // Animasyon sabitleri - Jöle efekti için elasticOut
  static const Duration _animationDuration = Duration(milliseconds: 500);
  static const Curve _animationCurve = Curves.elasticOut;

  // Boyutlar - Taşma sorununu çözmek için arttırıldı
  static const double _bubbleSize = 52.0;
  static const double _contentHeight = 70.0; // İçerik alanı
  static const double _topPadding = 8.0;
  static const double _bottomPadding = 6.0;

  @override
  Widget build(BuildContext context) {
    final bottomSafeArea = MediaQuery.of(context).padding.bottom;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 20,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      // SafeArea yerine manuel padding - daha iyi kontrol
      padding: EdgeInsets.only(
        top: _topPadding,
        bottom: bottomSafeArea + _bottomPadding,
        left: 8,
        right: 8,
      ),
      child: SizedBox(
        height: _contentHeight,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final itemWidth = constraints.maxWidth / _items.length;
            // Baloncuk dikey ortalama
            final bubbleTop = (_contentHeight - _bubbleSize) / 2;

            return Stack(
              clipBehavior: Clip.none,
              children: [
                // Yüzen Baloncuk (Floating Bubble) - Tam ortalanmış
                AnimatedPositioned(
                  duration: _animationDuration,
                  curve: _animationCurve,
                  left: (itemWidth * currentIndex) + (itemWidth - _bubbleSize) / 2,
                  top: bubbleTop - 4, // Hafif yukarıda (yüzen efekt)
                  child: Container(
                    width: _bubbleSize,
                    height: _bubbleSize,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [
                          Color(0xFF5C6BC0),
                          Color(0xFF7986CB),
                          Color(0xFF9FA8DA),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF5C6BC0).withValues(alpha: 0.45),
                          blurRadius: 16,
                          spreadRadius: 1,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                  ),
                ),

                // Navigation Items - Tam hizalanmış
                Row(
                  children: List.generate(_items.length, (index) {
                    final item = _items[index];
                    final isSelected = currentIndex == index;

                    return Expanded(
                      child: GestureDetector(
                        onTap: () {
                          HapticFeedback.mediumImpact();
                          onTap(index);
                        },
                        behavior: HitTestBehavior.opaque,
                        child: SizedBox(
                          height: _contentHeight,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              // İkon Container - Baloncukla aynı yükseklikte ortalanır
                              AnimatedContainer(
                                duration: const Duration(milliseconds: 300),
                                curve: Curves.easeOutCubic,
                                height: _bubbleSize,
                                alignment: Alignment.center,
                                // Aktif ikon hafif yukarı kayar
                                transform: Matrix4.translationValues(
                                  0,
                                  isSelected ? -4 : 0,
                                  0,
                                ),
                                child: TweenAnimationBuilder<double>(
                                  duration: const Duration(milliseconds: 300),
                                  tween: Tween<double>(
                                    begin: isSelected ? 22 : 26,
                                    end: isSelected ? 26 : 22,
                                  ),
                                  builder: (context, size, _) {
                                    return TweenAnimationBuilder<Color?>(
                                      duration: const Duration(milliseconds: 300),
                                      tween: ColorTween(
                                        end: isSelected ? Colors.white : Colors.grey[500],
                                      ),
                                      builder: (context, color, _) {
                                        return Icon(
                                          isSelected ? item.activeIcon : item.icon,
                                          color: color,
                                          size: size,
                                        );
                                      },
                                    );
                                  },
                                ),
                              ),

                              // Label - Pasif ikonların altında
                              AnimatedContainer(
                                duration: const Duration(milliseconds: 250),
                                curve: Curves.easeOutCubic,
                                height: isSelected ? 0 : 18,
                                child: AnimatedOpacity(
                                  duration: const Duration(milliseconds: 200),
                                  opacity: isSelected ? 0.0 : 1.0,
                                  child: FittedBox(
                                    fit: BoxFit.scaleDown,
                                    child: Text(
                                      item.label,
                                      style: GoogleFonts.poppins(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w500,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Navigation item verisi
class _NavItemData {
  final IconData icon;
  final IconData activeIcon;
  final String label;

  const _NavItemData(this.icon, this.activeIcon, this.label);
}
