import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/user_profile.dart';
import '../widgets/custom_notification.dart';
import '../widgets/swipe_card.dart';
import '../services/seed_service.dart';
import '../services/chat_service.dart';
import '../providers/likes_provider.dart';
import 'chat_detail_screen.dart';

class LikesScreen extends ConsumerStatefulWidget {
  const LikesScreen({super.key});

  @override
  ConsumerState<LikesScreen> createState() => _LikesScreenState();
}

class _LikesScreenState extends ConsumerState<LikesScreen> {
  @override
  void initState() {
    super.initState();
    // Initialize eliminated IDs from repository
    _initializeEliminatedIds();
  }

  Future<void> _initializeEliminatedIds() async {
    final eliminatedIds = await ref.read(likesRepositoryProvider).getEliminatedUserIds();
    ref.read(likesUIProvider.notifier).initializeEliminatedIds(eliminatedIds);
  }

  Future<void> _likeUser(UserProfile user) async {
    HapticFeedback.mediumImpact();

    try {
      final currentUserId = FirebaseAuth.instance.currentUser?.uid;
      if (currentUserId == null) return;

      // Use repository to like user
      final result = await ref.read(likesRepositoryProvider).likeUser(user.id);

      if (result['success'] == true) {
        // Create chat room for the match
        final chatService = ChatService();
        await chatService.createMatchChat(currentUserId, user.id);

        // Show full-screen Match Popup
        if (mounted) {
          _showMatchScreen(user);
        }
      } else {
        if (mounted) {
          CustomNotification.error(context, 'Bir hata olustu');
        }
      }
    } catch (e) {
      debugPrint('Error liking user: $e');
      if (mounted) {
        CustomNotification.error(context, 'Bir hata olustu');
      }
    }
  }

  /// Show full-screen Match Popup (same as Discovery screen)
  void _showMatchScreen(UserProfile matchedProfile) {
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => MatchPopup(
          matchedProfile: matchedProfile,
          onSendMessage: () {
            Navigator.pop(context);
            // Navigate to chat with the matched user
            _navigateToChat(matchedProfile);
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

  /// Navigate to chat screen with matched user
  void _navigateToChat(UserProfile matchedProfile) async {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    if (currentUserId == null) return;

    // Generate chat ID (same format as ChatService)
    final sortedIds = [currentUserId, matchedProfile.id]..sort();
    final chatId = '${sortedIds[0]}_${sortedIds[1]}';

    // Navigate to chat detail screen
    if (mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ChatDetailScreen(
            chatId: chatId,
            peerId: matchedProfile.id,
            peerName: matchedProfile.name,
            peerImage: matchedProfile.primaryPhoto,
          ),
        ),
      );
    }
  }

  Future<void> _dislikeUser(UserProfile user) async {
    HapticFeedback.mediumImpact();

    try {
      // Use repository to dislike user
      final result = await ref.read(likesRepositoryProvider).dislikeUser(user.id);

      if (result['success'] == true) {
        // Mark as eliminated in UI state
        ref.read(likesUIProvider.notifier).markAsEliminated(user.id);
      } else {
        if (mounted) {
          CustomNotification.error(context, 'Bir hata olustu');
        }
      }
    } catch (e) {
      debugPrint('Error disliking user: $e');
      if (mounted) {
        CustomNotification.error(context, 'Bir hata olustu');
      }
    }
  }

  /// Elenmiş kullanıcıyı tamamen listeden kaldır (X butonuna basıldığında)
  Future<void> _dismissUser(UserProfile user) async {
    final uiState = ref.read(likesUIProvider);

    // Zaten animasyon oynatılıyorsa tekrar başlatma
    if (uiState.dismissingUserIds.contains(user.id)) return;

    HapticFeedback.mediumImpact();

    // Step 1: Çıkış animasyonunu başlat
    ref.read(likesUIProvider.notifier).startDismissing(user.id);

    // Step 2: Animasyon süresince bekle
    await Future.delayed(_animationDuration);

    // Step 3: Animasyon bittikten sonra veritabanını güncelle
    try {
      final result = await ref.read(likesRepositoryProvider).dismissUser(user.id);

      if (result['success'] == true) {
        // Stream will automatically update the list
        ref.read(likesUIProvider.notifier).finishDismissing(user.id);
      } else {
        if (mounted) {
          ref.read(likesUIProvider.notifier).cancelDismissing(user.id);
          CustomNotification.error(context, 'Bir hata olustu');
        }
      }
    } catch (e) {
      debugPrint('Error dismissing user: $e');
      if (mounted) {
        ref.read(likesUIProvider.notifier).cancelDismissing(user.id);
        CustomNotification.error(context, 'Bir hata olustu');
      }
    }
  }

  void _showProfileDetail(UserProfile user) {
    // Hero Animation + iOS Swipe-Back ile detay sayfasına git
    Navigator.of(context).push(
      CupertinoPageRoute(
        builder: (context) => _ProfileDetailPage(
          user: user,
          onLike: () {
            Navigator.pop(context);
            _likeUser(user);
          },
          onDislike: () {
            Navigator.pop(context);
            _dislikeUser(user);
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Watch the stream of received likes
    final likesAsync = ref.watch(receivedLikesProvider);
    final uiState = ref.watch(likesUIProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(likesAsync),
            Expanded(
              child: likesAsync.when(
                loading: () => _buildLoadingState(),
                error: (error, stack) => _buildErrorState(error.toString()),
                data: (likedByUsers) {
                  if (likedByUsers.isEmpty) {
                    return _buildEmptyState();
                  }
                  return _buildLikesList(likedByUsers, uiState);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(String error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline_rounded,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'Bir hata olustu',
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.grey[700],
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              error,
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: Colors.grey[500],
              ),
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => ref.invalidate(receivedLikesProvider),
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Tekrar Dene'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF2C60),
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(AsyncValue<List<UserProfile>> likesAsync) {
    final count = likesAsync.valueOrNull?.length ?? 0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFFF2C60), Color(0xFFFF6B9D)],
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.favorite_rounded,
              color: Colors.white,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'Begeniler',
                      style: GoogleFonts.poppins(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[800],
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Real-time indicator
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.green.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: const BoxDecoration(
                              color: Colors.green,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Canli',
                            style: GoogleFonts.poppins(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: Colors.green,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                Text(
                  '$count kisi seni begendi',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          // Refresh button (manual refresh still available)
          IconButton(
            onPressed: () => ref.invalidate(receivedLikesProvider),
            icon: Icon(
              Icons.refresh_rounded,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFF2C60)),
          ),
          const SizedBox(height: 16),
          Text(
            'Begeniler yukleniyor...',
            style: GoogleFonts.poppins(
              fontSize: 16,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _seedDemoLikes() async {
    try {
      final seedService = SeedService();
      final count = await seedService.seedDemoLikesToCurrentUser();

      if (count > 0) {
        // Invalidate the provider to refresh the stream
        ref.invalidate(receivedLikesProvider);
        if (mounted) {
          CustomNotification.success(
            context,
            'Demo veriler eklendi',
            subtitle: '$count kisi seni begendi!',
          );
        }
      } else {
        if (mounted) {
          CustomNotification.error(context, 'Demo veri eklenemedi');
        }
      }
    } catch (e) {
      debugPrint('Error seeding demo likes: $e');
      if (mounted) {
        CustomNotification.error(context, 'Bir hata olustu');
      }
    }
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: const Color(0xFFFF2C60).withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.favorite_border_rounded,
                size: 80,
                color: Color(0xFFFF2C60),
              ),
            ),
            const SizedBox(height: 32),
            Text(
              'Henuz begeni yok',
              style: GoogleFonts.poppins(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Profilini guncelle ve daha fazla kisi\ntarafindan kesfedil!',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 16,
                color: Colors.grey[600],
                height: 1.5,
              ),
            ),
            const SizedBox(height: 32),
            // Demo veri ekleme butonu (test icin)
            GestureDetector(
              onTap: _seedDemoLikes,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFF2C60), Color(0xFFFF6B9D)],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFFF2C60).withValues(alpha: 0.3),
                      blurRadius: 15,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.auto_awesome,
                      color: Colors.white,
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Demo Begeni Ekle',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              decoration: BoxDecoration(
                color: Colors.amber.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Colors.amber.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.lightbulb_outline_rounded,
                    color: Colors.amber,
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Ipucu: Daha fazla fotograf ekle!',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Colors.amber[800],
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

  Widget _buildLikesList(List<UserProfile> likedByUsers, LikesUIState uiState) {
    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(receivedLikesProvider),
      color: const Color(0xFFFF2C60),
      child: GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: 0.75,
        ),
        itemCount: likedByUsers.length,
        itemBuilder: (context, index) {
          final user = likedByUsers[index];
          final isEliminated = uiState.eliminatedUserIds.contains(user.id);
          final isDismissing = uiState.dismissingUserIds.contains(user.id);
          return _buildLikeCard(
            user,
            isEliminated: isEliminated,
            isDismissing: isDismissing,
          );
        },
      ),
    );
  }

  // Animasyon sabitleri
  static const Duration _animationDuration = Duration(milliseconds: 400);
  static const Curve _animationCurve = Curves.easeInOut;

  Widget _buildLikeCard(
    UserProfile user, {
    bool isEliminated = false,
    bool isDismissing = false,
  }) {
    // Exit animation wrapper - fade out and scale down when dismissing
    return AnimatedOpacity(
      duration: _animationDuration,
      curve: _animationCurve,
      opacity: isDismissing ? 0.0 : 1.0,
      child: AnimatedScale(
        duration: _animationDuration,
        curve: _animationCurve,
        scale: isDismissing ? 0.8 : 1.0,
        child: Stack(
          children: [
            // Ana kart - Bounce efekti ile
            _BounceCard(
              isEliminated: isEliminated,
              onTap: isEliminated ? null : () => _showProfileDetail(user),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: isEliminated ? 0.05 : 0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      // Photo with animated grayscale transition (Hero kaldırıldı)
                      TweenAnimationBuilder<double>(
                        duration: _animationDuration,
                        curve: _animationCurve,
                        tween: Tween<double>(
                          begin: isEliminated ? 0.0 : 1.0,
                          end: isEliminated ? 1.0 : 0.0,
                        ),
                        builder: (context, grayscaleAmount, child) {
                          final colorMatrix = <double>[
                            1.0 - 0.7874 * grayscaleAmount,
                            0.7152 * grayscaleAmount,
                            0.0722 * grayscaleAmount,
                            0,
                            0,
                            0.2126 * grayscaleAmount,
                            1.0 - 0.2848 * grayscaleAmount,
                            0.0722 * grayscaleAmount,
                            0,
                            0,
                            0.2126 * grayscaleAmount,
                            0.7152 * grayscaleAmount,
                            1.0 - 0.9278 * grayscaleAmount,
                            0,
                            0,
                            0,
                            0,
                            0,
                            1,
                            0,
                          ];
                          return ColorFiltered(
                            colorFilter: ColorFilter.matrix(colorMatrix),
                            child: child,
                          );
                        },
                        child: user.photos.isNotEmpty
                            ? CachedNetworkImage(
                                imageUrl: user.photos.first,
                                fit: BoxFit.cover,
                                placeholder: (context, url) => Container(
                                  color: Colors.grey[200],
                                  child: const Center(
                                    child: CircularProgressIndicator(
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        Color(0xFFFF2C60),
                                      ),
                                    ),
                                  ),
                                ),
                                errorWidget: (context, url, error) => Container(
                                  color: Colors.grey[200],
                                  child: Icon(Icons.person, size: 60, color: Colors.grey[400]),
                                ),
                              )
                            : Container(
                                color: Colors.grey[200],
                                child: Icon(Icons.person, size: 60, color: Colors.grey[400]),
                              ),
                      ),

                      // Gradient overlay
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              Colors.black.withValues(alpha: 0.7),
                            ],
                            stops: const [0.5, 1.0],
                          ),
                        ),
                      ),

                      // User info
                      Positioned(
                        bottom: 12,
                        left: 12,
                        right: 12,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${user.name}, ${user.age}',
                              style: GoogleFonts.poppins(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            if (user.university.isNotEmpty)
                              Text(
                                user.university,
                                style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  color: Colors.white70,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                          ],
                        ),
                      ),

                      // Tap hint
                      Positioned(
                        top: 12,
                        left: 12,
                        child: AnimatedOpacity(
                          duration: _animationDuration,
                          curve: _animationCurve,
                          opacity: isEliminated ? 0.0 : 1.0,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.5),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              'Dokun',
                              style: GoogleFonts.poppins(
                                fontSize: 10,
                                color: Colors.white,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ),
                      ),

                      // Like indicator
                      Positioned(
                        top: 12,
                        right: 12,
                        child: AnimatedOpacity(
                          duration: _animationDuration,
                          curve: _animationCurve,
                          opacity: isEliminated ? 0.0 : 1.0,
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFF2C60),
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFFFF2C60).withValues(alpha: 0.4),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.favorite_rounded,
                              color: Colors.white,
                              size: 16,
                            ),
                          ),
                        ),
                      ),

                      // Eliminated overlay
                      Positioned.fill(
                        child: IgnorePointer(
                          child: AnimatedOpacity(
                            duration: _animationDuration,
                            curve: _animationCurve,
                            opacity: isEliminated ? 1.0 : 0.0,
                            child: Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(20),
                                color: Colors.black.withValues(alpha: 0.3),
                              ),
                              child: Center(
                                child: AnimatedScale(
                                  duration: _animationDuration,
                                  curve: _animationCurve,
                                  scale: isEliminated ? 1.0 : 0.5,
                                  child: Container(
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: Colors.black.withValues(alpha: 0.5),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.close_rounded,
                                      color: Colors.white,
                                      size: 40,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Dismiss button (X) - dışarıda, her zaman görünür
            Positioned(
              top: 8,
              right: 8,
              child: AnimatedOpacity(
                duration: _animationDuration,
                curve: _animationCurve,
                opacity: isEliminated ? 1.0 : 0.0,
                child: AnimatedScale(
                  duration: _animationDuration,
                  curve: _animationCurve,
                  scale: isEliminated ? 1.0 : 0.0,
                  child: GestureDetector(
                    onTap: isEliminated ? () => _dismissUser(user) : null,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFFF2C60), Color(0xFFFF6B9D)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFFF2C60).withValues(alpha: 0.5),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.close_rounded,
                        color: Colors.white,
                        size: 18,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Bounce animasyonlu kart widget'ı
class _BounceCard extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final bool isEliminated;

  const _BounceCard({
    required this.child,
    this.onTap,
    this.isEliminated = false,
  });

  @override
  State<_BounceCard> createState() => _BounceCardState();
}

class _BounceCardState extends State<_BounceCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 100),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.95,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _handleTap() async {
    if (widget.onTap == null) return;

    // Haptic feedback
    HapticFeedback.lightImpact();

    // Bounce animasyonu: küçül
    await _controller.forward();

    // Bounce animasyonu: büyü
    await _controller.reverse();

    // Callback'i çağır
    widget.onTap?.call();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: widget.onTap != null ? (_) => _controller.forward() : null,
      onTapUp: widget.onTap != null ? (_) => _handleTap() : null,
      onTapCancel: widget.onTap != null ? () => _controller.reverse() : null,
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: child,
          );
        },
        child: widget.child,
      ),
    );
  }
}

// Profile Detail Page with CustomScrollView + iOS Swipe-Back
class _ProfileDetailPage extends StatelessWidget {
  final UserProfile user;
  final VoidCallback onLike;
  final VoidCallback onDislike;

  const _ProfileDetailPage({
    required this.user,
    required this.onLike,
    required this.onDislike,
  });

  /// X butonuna basıldığında özel tasarımlı onay dialog'u göster
  Future<void> _showDislikeConfirmation(BuildContext context) async {
    final confirmed = await showGeneralDialog<bool>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Dismiss',
      barrierColor: Colors.black.withValues(alpha: 0.5),
      transitionDuration: const Duration(milliseconds: 300),
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        return ScaleTransition(
          scale: CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutBack,
          ),
          child: FadeTransition(
            opacity: animation,
            child: child,
          ),
        );
      },
      pageBuilder: (context, animation, secondaryAnimation) {
        return Center(
          child: Material(
            color: Colors.transparent,
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 32),
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.15),
                    blurRadius: 30,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Üzgün yüz ikonu
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF2C60).withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.sentiment_dissatisfied_rounded,
                      color: Color(0xFFFF2C60),
                      size: 36,
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Başlık
                  Text(
                    'Emin misiniz?',
                    style: GoogleFonts.poppins(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[900],
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Açıklama
                  Text(
                    '${user.name} ile arkadas olmak istemediginize emin misiniz?',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                      fontSize: 15,
                      color: Colors.grey[600],
                      height: 1.5,
                    ),
                  ),

                  const SizedBox(height: 8),

                  // Uyarı
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.amber.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.info_outline_rounded,
                          size: 16,
                          color: Colors.amber[700],
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Bu islem geri alinamaz',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: Colors.amber[700],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Butonlar
                  Row(
                    children: [
                      // Vazgeç butonu
                      Expanded(
                        child: GestureDetector(
                          onTap: () => Navigator.of(context).pop(false),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            decoration: BoxDecoration(
                              color: Colors.grey[100],
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Center(
                              child: Text(
                                'Vazgec',
                                style: GoogleFonts.poppins(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey[700],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(width: 12),

                      // Evet butonu - Gradient
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            HapticFeedback.mediumImpact();
                            Navigator.of(context).pop(true);
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFFFF2C60), Color(0xFFFF6B9D)],
                                begin: Alignment.centerLeft,
                                end: Alignment.centerRight,
                              ),
                              borderRadius: BorderRadius.circular(14),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFFFF2C60).withValues(alpha: 0.4),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Center(
                              child: Text(
                                'Evet',
                                style: GoogleFonts.poppins(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );

    if (confirmed == true) {
      onDislike();
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final expandedHeight = screenHeight * 0.6; // Ekranın %60'ı fotoğraf

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // Ana içerik - CustomScrollView ile tek scroll
          CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              // SliverAppBar - Collapsing fotoğraf
              SliverAppBar(
                expandedHeight: expandedHeight,
                pinned: false,
                floating: false,
                stretch: true,
                backgroundColor: Colors.white,
                elevation: 0,
                automaticallyImplyLeading: false,
                flexibleSpace: FlexibleSpaceBar(
                  stretchModes: const [
                    StretchMode.zoomBackground,
                    StretchMode.blurBackground,
                  ],
                  background: Stack(
                    fit: StackFit.expand,
                    children: [
                      // Fotoğraf (Hero kaldırıldı)
                      user.photos.isNotEmpty
                          ? CachedNetworkImage(
                              imageUrl: user.photos.first,
                              fit: BoxFit.cover,
                            )
                          : Container(
                              color: Colors.grey[300],
                              child: const Icon(Icons.person, size: 100),
                            ),

                      // Alt gradient (içerik okunabilirliği için)
                      Positioned(
                        bottom: 0,
                        left: 0,
                        right: 0,
                        height: 150,
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.bottomCenter,
                              end: Alignment.topCenter,
                              colors: [
                                Colors.black.withValues(alpha: 0.6),
                                Colors.transparent,
                              ],
                            ),
                          ),
                        ),
                      ),

                      // Üst gradient (status bar için)
                      Positioned(
                        top: 0,
                        left: 0,
                        right: 0,
                        height: 100,
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.black.withValues(alpha: 0.4),
                                Colors.transparent,
                              ],
                            ),
                          ),
                        ),
                      ),

                      // İsim ve yaş (fotoğraf üzerinde)
                      Positioned(
                        bottom: 20,
                        left: 20,
                        right: 20,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${user.name}, ${user.age}',
                              style: GoogleFonts.poppins(
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                shadows: [
                                  Shadow(
                                    color: Colors.black.withValues(alpha: 0.5),
                                    blurRadius: 10,
                                  ),
                                ],
                              ),
                            ),
                            if (user.university.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Icon(
                                    Icons.school_rounded,
                                    color: Colors.white.withValues(alpha: 0.9),
                                    size: 18,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    user.university,
                                    style: GoogleFonts.poppins(
                                      fontSize: 16,
                                      color: Colors.white.withValues(alpha: 0.9),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // İçerik
              SliverToBoxAdapter(
                child: Container(
                  color: Colors.white,
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Bölüm
                      if (user.department.isNotEmpty) ...[
                        _buildInfoRow(
                          Icons.menu_book_rounded,
                          user.department,
                        ),
                        const SizedBox(height: 20),
                      ],

                      // Biyografi
                      if (user.bio.isNotEmpty) ...[
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.grey[50],
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Hakkinda',
                                style: GoogleFonts.poppins(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey[700],
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                user.bio,
                                style: GoogleFonts.poppins(
                                  fontSize: 15,
                                  color: Colors.grey[800],
                                  height: 1.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],

                      // İlgi alanları
                      if (user.interests.isNotEmpty) ...[
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.grey[50],
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Ilgi Alanlari',
                                style: GoogleFonts.poppins(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey[700],
                                ),
                              ),
                              const SizedBox(height: 12),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: user.interests.map((interest) {
                                  return Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 8,
                                    ),
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [
                                          const Color(0xFFFF2C60).withValues(alpha: 0.1),
                                          const Color(0xFFFF6B9D).withValues(alpha: 0.1),
                                        ],
                                      ),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(
                                      interest,
                                      style: GoogleFonts.poppins(
                                        fontSize: 13,
                                        color: const Color(0xFFFF2C60),
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                      ],

                      // Diğer fotoğraflar
                      if (user.photos.length > 1) ...[
                        ...user.photos.skip(1).map((photo) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 16),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(20),
                              child: CachedNetworkImage(
                                imageUrl: photo,
                                fit: BoxFit.cover,
                                width: double.infinity,
                              ),
                            ),
                          );
                        }),
                      ],

                      // Alt butonlar için boşluk
                      SizedBox(height: MediaQuery.of(context).padding.bottom + 100),
                    ],
                  ),
                ),
              ),
            ],
          ),

          // Geri butonu (sabit üst sol)
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            left: 16,
            child: GestureDetector(
              onTap: () => Navigator.of(context).pop(),
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.3),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.arrow_back_ios_new_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
            ),
          ),

          // Aksiyon butonları (sabit alt kısım)
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: EdgeInsets.fromLTRB(
                32,
                16,
                32,
                MediaQuery.of(context).padding.bottom + 16,
              ),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 20,
                    offset: const Offset(0, -5),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // Dislike butonu - Onay dialog'u ile
                  _buildActionButton(
                    onTap: () => _showDislikeConfirmation(context),
                    icon: Icons.close_rounded,
                    size: 60,
                    iconSize: 28,
                    colors: [Colors.grey[100]!, Colors.grey[200]!],
                    iconColor: Colors.grey[600]!,
                    shadowColor: Colors.grey.withValues(alpha: 0.3),
                  ),

                  // Like butonu (büyük)
                  _buildActionButton(
                    onTap: onLike,
                    icon: Icons.favorite_rounded,
                    size: 72,
                    iconSize: 34,
                    colors: const [Color(0xFFFF2C60), Color(0xFFFF6B9D)],
                    iconColor: Colors.white,
                    shadowColor: const Color(0xFFFF2C60).withValues(alpha: 0.4),
                    isGradient: true,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String text) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xFFFF2C60).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            icon,
            color: const Color(0xFFFF2C60),
            size: 18,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: GoogleFonts.poppins(
              fontSize: 15,
              color: Colors.grey[700],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActionButton({
    required VoidCallback onTap,
    required IconData icon,
    required double size,
    required double iconSize,
    required List<Color> colors,
    required Color iconColor,
    required Color shadowColor,
    bool isGradient = false,
  }) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.mediumImpact();
        onTap();
      },
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          gradient: isGradient
              ? LinearGradient(
                  colors: colors,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
          color: isGradient ? null : colors.first,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: shadowColor,
              blurRadius: 16,
              spreadRadius: 2,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Icon(
          icon,
          color: iconColor,
          size: iconSize,
        ),
      ),
    );
  }
}
