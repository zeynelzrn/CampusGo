import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_card_swiper/flutter_card_swiper.dart';
import '../services/auth_service.dart';
import '../services/seed_service.dart';
import '../providers/swipe_provider.dart';
import '../widgets/swipe_card.dart';
import '../widgets/custom_notification.dart';
import '../models/user_profile.dart';
import 'login_screen.dart';
import 'profile_edit_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final AuthService _authService = AuthService();
  late CardSwiperController _cardSwiperController;

  @override
  void initState() {
    super.initState();
    _cardSwiperController = CardSwiperController();
  }

  @override
  void dispose() {
    _cardSwiperController.dispose();
    super.dispose();
  }

  void _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('remember_me', false);
    await _authService.signOut();

    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => LoginScreen()),
      );
    }
  }

  bool _onSwipe(
    int previousIndex,
    int? currentIndex,
    CardSwiperDirection direction,
  ) {
    final notifier = ref.read(swipeProvider.notifier);

    if (direction == CardSwiperDirection.left) {
      notifier.swipeLeft(previousIndex);
    } else if (direction == CardSwiperDirection.right) {
      notifier.swipeRight(previousIndex);
    } else if (direction == CardSwiperDirection.top) {
      notifier.superLike(previousIndex);
    }

    return true;
  }

  bool _onUndoSwipe(
    int? previousIndex,
    int currentIndex,
    CardSwiperDirection direction,
  ) {
    return false; // Disable undo via swipe
  }

  void _onSwipeLeft() {
    _cardSwiperController.swipe(CardSwiperDirection.left);
  }

  void _onSwipeRight() {
    _cardSwiperController.swipe(CardSwiperDirection.right);
  }

  void _onSuperLike() {
    _cardSwiperController.swipe(CardSwiperDirection.top);
  }

  Future<void> _handleUndo() async {
    final notifier = ref.read(swipeProvider.notifier);
    final success = await notifier.undoLastSwipe();
    if (success && mounted) {
      _cardSwiperController.undo();
    }
  }

  @override
  Widget build(BuildContext context) {
    final swipeState = ref.watch(swipeProvider);

    // Listen for match notification
    ref.listen<SwipeState>(swipeProvider, (previous, current) {
      if (current.isMatch && current.lastSwipedProfile != null) {
        _showMatchDialog(current.lastSwipedProfile!);
        ref.read(swipeProvider.notifier).clearMatchNotification();
      }
    });

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFFDF6F0),
              Color(0xFFF8EDE3),
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Header
              _buildHeader(),

              // Swipe Cards
              Expanded(
                child: _buildCardSection(swipeState),
              ),

              // Action buttons
              if (swipeState.profiles.isNotEmpty && !swipeState.isLoading)
                _buildActionButtons(swipeState),

              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Profile button
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: IconButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => const ProfileEditScreen()),
                );
              },
              icon: const Icon(Icons.person, color: Color(0xFF5C6BC0)),
            ),
          ),

          // Logo
          ShaderMask(
            shaderCallback: (bounds) => const LinearGradient(
              colors: [Color(0xFF5C6BC0), Color(0xFF7986CB)],
            ).createShader(bounds),
            child: Text(
              'CampusGo',
              style: GoogleFonts.poppins(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),

          // Logout button
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: IconButton(
              onPressed: _logout,
              icon: const Icon(Icons.logout, color: Color(0xFF5C6BC0)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCardSection(SwipeState state) {
    if (state.isLoading && state.profiles.isEmpty) {
      return _buildLoadingState();
    }

    if (state.error != null && state.profiles.isEmpty) {
      return _buildErrorState(state.error!);
    }

    if (state.profiles.isEmpty) {
      return _buildEmptyState();
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: CardSwiper(
        controller: _cardSwiperController,
        cardsCount: state.profiles.length,
        numberOfCardsDisplayed:
            state.profiles.length >= 3 ? 3 : state.profiles.length,
        backCardOffset: const Offset(0, 40),
        padding: const EdgeInsets.symmetric(vertical: 20),
        onSwipe: _onSwipe,
        onUndo: _onUndoSwipe,
        allowedSwipeDirection: const AllowedSwipeDirection.only(
          left: true,
          right: true,
          up: true,
        ),
        cardBuilder: (context, index, horizontalOffsetPercentage,
            verticalOffsetPercentage) {
          if (index >= state.profiles.length) return const SizedBox();

          final profile = state.profiles[index];
          return SwipeCard(
            key: ValueKey(profile.id),
            profile: profile,
            horizontalOffset: horizontalOffsetPercentage.toDouble(),
            verticalOffset: verticalOffsetPercentage.toDouble(),
          );
        },
      ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF5C6BC0).withValues(alpha: 0.2),
                  blurRadius: 20,
                  spreadRadius: 5,
                ),
              ],
            ),
            child: const CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF5C6BC0)),
              strokeWidth: 3,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Profiller yükleniyor...',
            style: GoogleFonts.poppins(
              fontSize: 16,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.error_outline,
                size: 48,
                color: Colors.red,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Bir hata oluştu',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.grey[800],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              error,
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => ref.read(swipeProvider.notifier).refresh(),
              icon: const Icon(Icons.refresh),
              label: Text(
                'Tekrar Dene',
                style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF5C6BC0),
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xFF5C6BC0).withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.search_off,
                size: 64,
                color: Color(0xFF5C6BC0),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Şu an için profil kalmadı',
              style: GoogleFonts.poppins(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: Colors.grey[800],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Daha sonra tekrar kontrol et veya\ntest profilleri ekle',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: Colors.grey[600],
                height: 1.5,
              ),
            ),
            const SizedBox(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton.icon(
                  onPressed: () => ref.read(swipeProvider.notifier).refresh(),
                  icon: const Icon(Icons.refresh),
                  label: Text(
                    'Yenile',
                    style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF5C6BC0),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  onPressed: _seedTestProfiles,
                  icon: const Icon(Icons.people),
                  label: Text(
                    'Test Profili Ekle',
                    style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _seedTestProfiles() async {
    // Show loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Center(
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF5C6BC0)),
              ),
              const SizedBox(height: 16),
              Text(
                'Test profilleri ekleniyor...',
                style: GoogleFonts.poppins(fontSize: 14),
              ),
            ],
          ),
        ),
      ),
    );

    try {
      final seedService = SeedService();
      await seedService.seedTestProfiles();

      if (mounted) {
        Navigator.pop(context); // Close loading
        CustomNotification.success(
          context,
          'Test Profilleri Eklendi',
          subtitle: 'Yeni profiller keşfetmeye hazır',
        );
        ref.read(swipeProvider.notifier).refresh();
      }
    } catch (e, stackTrace) {
      debugPrint('Seed error: $e');
      debugPrint('Stack trace: $stackTrace');
      if (mounted) {
        Navigator.pop(context); // Close loading
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Hata'),
            content: Text('Profiller eklenemedi:\n\n$e'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Tamam'),
              ),
            ],
          ),
        );
      }
    }
  }

  Widget _buildActionButtons(SwipeState state) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: SwipeActionButtons(
        onDislike: _onSwipeLeft,
        onSuperLike: _onSuperLike,
        onLike: _onSwipeRight,
        onUndo: state.lastSwipedProfile != null ? () => _handleUndo() : null,
        canUndo: state.lastSwipedProfile != null,
      ),
    );
  }

  void _showMatchDialog(UserProfile profile) {
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => MatchPopup(
          matchedProfile: profile,
          onSendMessage: () {
            Navigator.pop(context);
            // TODO: Navigate to chat screen
          },
          onKeepSwiping: () {
            Navigator.pop(context);
          },
        ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: animation,
            child: ScaleTransition(
              scale: Tween<double>(begin: 0.8, end: 1.0).animate(
                CurvedAnimation(parent: animation, curve: Curves.easeOutBack),
              ),
              child: child,
            ),
          );
        },
        transitionDuration: const Duration(milliseconds: 400),
      ),
    );
  }
}
