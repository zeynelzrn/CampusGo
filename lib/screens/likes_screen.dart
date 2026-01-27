import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shimmer/shimmer.dart';
import '../models/user_profile.dart';
import '../widgets/app_notification.dart';
import '../widgets/swipe_card.dart';
import '../widgets/modern_animated_dialog.dart';
import '../services/seed_service.dart';
import '../services/chat_service.dart';
import '../providers/likes_provider.dart';
import '../providers/connectivity_provider.dart';
import '../utils/image_helper.dart';
import 'chat_detail_screen.dart';
import 'user_profile_screen.dart';
import 'main_screen.dart';

class LikesScreen extends ConsumerStatefulWidget {
  const LikesScreen({super.key});

  @override
  ConsumerState<LikesScreen> createState() => _LikesScreenState();
}

class _LikesScreenState extends ConsumerState<LikesScreen>
    with AutoRefreshMixin {
  /// Admin durumu (Firestore'dan yüklenir)
  bool _isAdmin = false;

  /// Manuel yenileme durumu (sağ üst buton için)
  bool _isManualRefreshing = false;

  @override
  List<ProviderOrFamily> get providersToRefresh => [receivedLikesProvider];

  @override
  void initState() {
    super.initState();
    // Initialize eliminated IDs from repository
    _initializeEliminatedIds();
    // Admin durumunu kontrol et
    _checkAdminStatus();
  }

  /// Kullanıcının admin olup olmadığını kontrol et
  Future<void> _checkAdminStatus() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (doc.exists && mounted) {
        final data = doc.data();
        setState(() {
          _isAdmin = data?['isAdmin'] as bool? ?? false;
        });
      }
    } catch (e) {
      debugPrint('Error checking admin status: $e');
    }
  }

  Future<void> _initializeEliminatedIds() async {
    final eliminatedIds = await ref.read(likesRepositoryProvider).getEliminatedUserIds();
    ref.read(likesUIProvider.notifier).initializeEliminatedIds(eliminatedIds);
  }

  /// Pull-to-refresh veya manuel yenileme fonksiyonu
  /// Haptic feedback verir ve veriyi yeniler
  Future<void> _handleRefresh() async {
    // Haptic feedback - yenileme başladığında titreşim
    HapticFeedback.mediumImpact();

    // Provider'ı invalidate et
    ref.invalidate(receivedLikesProvider);

    // Kısa bir bekleme (UX için)
    await Future.delayed(const Duration(milliseconds: 300));
  }

  /// Manuel yenileme butonu için (sağ üst)
  Future<void> _handleManualRefresh() async {
    if (_isManualRefreshing) return;

    // Haptic feedback
    HapticFeedback.mediumImpact();

    // Loading state'i başlat
    setState(() => _isManualRefreshing = true);

    // Veriyi yenile
    await _handleRefresh();

    // Loading state'i bitir
    if (mounted) {
      setState(() => _isManualRefreshing = false);
    }
  }

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

  Future<void> _likeUser(UserProfile user) async {
    // İnternet kontrolü
    if (!_checkConnectivity()) return;

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
          AppNotification.error(title: 'Bir hata oluştu');
        }
      }
    } catch (e) {
      debugPrint('Error liking user: $e');
      if (mounted) {
        AppNotification.error(title: 'Bir hata oluştu');
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
    // İnternet kontrolü
    if (!_checkConnectivity()) return;

    HapticFeedback.mediumImpact();

    try {
      // Use repository to dislike user
      final result = await ref.read(likesRepositoryProvider).dislikeUser(user.id);

      if (result['success'] == true) {
        // Mark as eliminated in UI state
        ref.read(likesUIProvider.notifier).markAsEliminated(user.id);
      } else {
        if (mounted) {
          AppNotification.error(title: 'Bir hata oluştu');
        }
      }
    } catch (e) {
      debugPrint('Error disliking user: $e');
      if (mounted) {
        AppNotification.error(title: 'Bir hata oluştu');
      }
    }
  }

  /// Elenmiş kullanıcıyı tamamen listeden kaldır (X butonuna basıldığında)
  Future<void> _dismissUser(UserProfile user) async {
    // İnternet kontrolü
    if (!_checkConnectivity()) return;

    final uiState = ref.read(likesUIProvider);

    // Zaten animasyon oynatılıyorsa veya zaten kaldırılmışsa tekrar başlatma
    if (uiState.dismissingUserIds.contains(user.id) ||
        uiState.removedUserIds.contains(user.id)) {
      return;
    }

    HapticFeedback.mediumImpact();

    // Step 1: Çıkış animasyonunu başlat
    // Animasyon bittiğinde _AnimatedLikeCard callback'i removeUser çağıracak
    ref.read(likesUIProvider.notifier).startDismissing(user.id);

    // Step 2: Firestore'u güncelle (arka planda, animasyondan bağımsız)
    try {
      await ref.read(likesRepositoryProvider).dismissUser(user.id);
    } catch (e) {
      debugPrint('Error dismissing user in Firestore: $e');
      // Firestore hatası olsa bile animasyon devam etsin
      // Kullanıcı yeniden giriş yapınca stream güncellenecek
    }
  }

  void _showProfileDetail(UserProfile user) {
    // UserProfileScreen ile profil detayına git
    // Engelleme özelliği ve like/dislike butonları UserProfileScreen'de mevcut
    Navigator.of(context).push(
      CupertinoPageRoute(
        builder: (context) => UserProfileScreen(
          userId: user.id,
          onUserBlocked: (blockedUserId) {
            // Kullanıcı engellendiğinde:
            // 1. Önce profil ekranını kapat
            Navigator.of(context).pop();
            // 2. Sonra animasyonu tetikle (bir frame sonra state güncellenir)
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                // startDismissing ile animasyonu başlat
                ref.read(likesUIProvider.notifier).startDismissing(blockedUserId);
              }
            });
          },
          onLike: () => _likeUser(user),
          onDislike: () => _dislikeUser(user),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Watch the stream of received likes
    final likesAsync = ref.watch(receivedLikesProvider);
    final uiState = ref.watch(likesUIProvider);
    // Global ConnectivityBanner handles offline state

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
              backgroundColor: const Color(0xFF5C6BC0),
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
                colors: [Color(0xFF5C6BC0), Color(0xFF7986CB)],
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.waving_hand_rounded,
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
                      'Istekler',
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
                  '$count kisi seninle tanismak istiyor',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          // Refresh button (manual refresh with loading state)
          _isManualRefreshing
              ? Container(
                  width: 48,
                  height: 48,
                  padding: const EdgeInsets.all(12),
                  child: const CircularProgressIndicator(
                    strokeWidth: 2.5,
                    valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF5C6BC0)),
                  ),
                )
              : IconButton(
                  onPressed: _handleManualRefresh,
                  icon: Icon(
                    Icons.refresh_rounded,
                    color: Colors.grey[600],
                  ),
                  tooltip: 'Yenile',
                ),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    // Bouncing scroll physics ile kaydırılabilir
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(
        parent: BouncingScrollPhysics(),
      ),
      child: SizedBox(
        height: MediaQuery.of(context).size.height - 200,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF5C6BC0)),
                strokeWidth: 3.0,
              ),
              const SizedBox(height: 16),
              Text(
                'Istekler yukleniyor...',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
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
          AppNotification.success(
            title: 'Demo veriler eklendi',
            subtitle: '$count kişi seninle tanışmak istiyor!',
          );
        }
      } else {
        if (mounted) {
          AppNotification.error(title: 'Demo veri eklenemedi');
        }
      }
    } catch (e) {
      debugPrint('Error seeding demo likes: $e');
      if (mounted) {
        AppNotification.error(title: 'Bir hata oluştu');
      }
    }
  }

  Widget _buildEmptyState() {
    // Bouncing scroll physics ile kaydırılabilir - pull-to-refresh için gerekli
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(
        parent: BouncingScrollPhysics(),
      ),
      child: SizedBox(
        height: MediaQuery.of(context).size.height - 200,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // El sallama ikonu
                Container(
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    color: const Color(0xFF5C6BC0).withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.waving_hand_outlined,
                    size: 80,
                    color: Color(0xFF5C6BC0),
                  ),
                ),
                const SizedBox(height: 32),
                // Başlık
                Text(
                  'Henuz istek yok',
                  style: GoogleFonts.poppins(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[800],
                  ),
                ),
                const SizedBox(height: 12),
                // Alt başlık
                Text(
                  'Profilini guncelle ve daha fazla kisi\ntarafindan kesfedil!',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    color: Colors.grey[600],
                    height: 1.5,
                  ),
                ),
                // Pull-to-refresh ipucu
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.arrow_downward, size: 14, color: Colors.grey[400]),
                    const SizedBox(width: 6),
                    Text(
                      'Yenilemek için aşağı çek',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: Colors.grey[400],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                // Demo veri ekleme butonu - sadece adminler için
                if (_isAdmin) ...[
                  GestureDetector(
                    onTap: _seedDemoLikes,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF5C6BC0), Color(0xFF7986CB)],
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF5C6BC0).withValues(alpha: 0.3),
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
                            'Demo Istek Ekle',
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
                ],
                // Keşfete Git butonu
                GestureDetector(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    MainScreen.currentTabNotifier.value = 2;
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF5C6BC0), Color(0xFF7986CB)],
                      ),
                      borderRadius: BorderRadius.circular(30),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF5C6BC0).withValues(alpha: 0.4),
                          blurRadius: 15,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.explore_rounded,
                          color: Colors.white,
                          size: 22,
                        ),
                        const SizedBox(width: 10),
                        Text(
                          'Kesfete Git',
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                // İpucu kutusu
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
        ),
      ),
    );
  }

  Widget _buildLikesList(List<UserProfile> likedByUsers, LikesUIState uiState) {
    // removedUserIds'teki kullanıcıları listeden tamamen çıkar
    // Bu sayede GridView'daki index'ler düzgün çalışır ve boşluk kalmaz
    final filteredUsers = likedByUsers
        .where((user) => !uiState.removedUserIds.contains(user.id))
        .toList();

    if (filteredUsers.isEmpty) {
      return _buildEmptyState();
    }

    return RefreshIndicator(
      onRefresh: _handleRefresh,
      color: const Color(0xFF5C6BC0),
      backgroundColor: Colors.white,
      strokeWidth: 3.0,
      displacement: 50.0,
      child: GridView.builder(
        // Bouncing scroll physics - esneme efekti
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: 0.75,
        ),
        itemCount: filteredUsers.length,
        itemBuilder: (context, index) {
          final user = filteredUsers[index];
          final isEliminated = uiState.eliminatedUserIds.contains(user.id);
          final isDismissing = uiState.dismissingUserIds.contains(user.id);

          // Animasyonlu kart - silinme animasyonu bitince removeUser çağrılır
          return _AnimatedLikeCard(
            key: ValueKey(user.id),
            user: user,
            isEliminated: isEliminated,
            isDismissing: isDismissing,
            onDismissAnimationComplete: () {
              // Animasyon bitince kullanıcıyı listeden tamamen kaldır
              ref.read(likesUIProvider.notifier).removeUser(user.id);
            },
            child: _buildLikeCard(
              user,
              isEliminated: isEliminated,
              isDismissing: isDismissing,
            ),
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
                                cacheManager: AppCacheManager.instance,
                                // RAM Optimizasyonu: Sadece genişlik belirle, yükseklik otomatik
                                // (orijinal oran korunur, ezilme önlenir)
                                memCacheWidth: 300,
                                placeholder: (context, url) => Shimmer.fromColors(
                                  baseColor: Colors.grey[300]!,
                                  highlightColor: Colors.grey[100]!,
                                  child: Container(
                                    color: Colors.grey[200],
                                    child: Center(
                                      child: Icon(Icons.person, size: 60, color: Colors.grey[400]),
                                    ),
                                  ),
                                ),
                                errorWidget: (context, url, error) => Shimmer.fromColors(
                                  baseColor: Colors.grey[300]!,
                                  highlightColor: Colors.grey[100]!,
                                  child: Container(
                                    color: Colors.grey[200],
                                    child: Center(
                                      child: Icon(Icons.person, size: 60, color: Colors.grey[400]),
                                    ),
                                  ),
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
                              color: const Color(0xFF5C6BC0),
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF5C6BC0).withValues(alpha: 0.4),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.waving_hand_rounded,
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
                          colors: [Color(0xFF5C6BC0), Color(0xFF7986CB)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF5C6BC0).withValues(alpha: 0.5),
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

/// Animasyonlu kart - silinirken fade out + scale animasyonu yapar
/// Animasyon bittiğinde callback çağrılır ve kart listeden fiziksel olarak çıkar
class _AnimatedLikeCard extends StatefulWidget {
  final Widget child;
  final UserProfile user;
  final bool isDismissing;
  final bool isEliminated;
  final VoidCallback onDismissAnimationComplete;

  const _AnimatedLikeCard({
    super.key,
    required this.child,
    required this.user,
    required this.isDismissing,
    required this.isEliminated,
    required this.onDismissAnimationComplete,
  });

  @override
  State<_AnimatedLikeCard> createState() => _AnimatedLikeCardState();
}

class _AnimatedLikeCardState extends State<_AnimatedLikeCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;
  bool _animationCompleted = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.8).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOut,
      ),
    );

    _opacityAnimation = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOut,
      ),
    );

    // Animasyon bittiğinde callback çağır
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed && !_animationCompleted) {
        _animationCompleted = true;
        widget.onDismissAnimationComplete();
      }
    });
  }

  @override
  void didUpdateWidget(covariant _AnimatedLikeCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Dismissing durumu değiştiğinde animasyonu başlat
    if (widget.isDismissing && !oldWidget.isDismissing && !_animationCompleted) {
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Opacity(
          opacity: _opacityAnimation.value,
          child: Transform.scale(
            scale: _scaleAnimation.value,
            child: child,
          ),
        );
      },
      child: widget.child,
    );
  }
}
