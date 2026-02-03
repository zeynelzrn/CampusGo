import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shimmer/shimmer.dart';
import '../providers/swipe_provider.dart';
import '../providers/likes_provider.dart';
import '../providers/connectivity_provider.dart';
import '../models/user_profile.dart';
import '../widgets/swipe_card.dart';
import '../widgets/modern_animated_dialog.dart';
import '../widgets/report_sheet.dart';
import '../services/seed_service.dart';
import '../services/user_service.dart';
import '../services/chat_service.dart';
import '../widgets/app_notification.dart';
import '../utils/image_helper.dart';
import 'chat_detail_screen.dart';
import 'premium/premium_offer_screen.dart';
import 'discovery/filters_modal.dart';

class DiscoverScreen extends ConsumerStatefulWidget {
  const DiscoverScreen({super.key});

  @override
  ConsumerState<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends ConsumerState<DiscoverScreen>
    with AutoRefreshMixin {
  final PageController _pageController = PageController();
  final ScrollController _scrollController = ScrollController();
  final UserService _userService = UserService();
  final ChatService _chatService = ChatService();

  /// Admin durumu (Firestore'dan yüklenir)
  bool _isAdmin = false;

  /// Yenileme durumu (loading indicator için)
  bool _isRefreshing = false;

  /// Son 5 dislike edilen kullanıcı geçmişi (Stack - LIFO mantığı)
  final List<UserProfile> _dislikedHistory = [];

  @override
  List<ProviderOrFamily> get providersToRefresh => [swipeProvider];

  @override
  void initState() {
    super.initState();
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

  /// Profil listesini yenile (loading indicator ile)
  Future<void> _refreshProfiles() async {
    if (_isRefreshing) return;

    setState(() => _isRefreshing = true);
    HapticFeedback.mediumImpact();

    try {
      // Provider'ı yenile - bu Firestore sorgusunu tekrar tetikler
      ref.invalidate(swipeProvider);

      // Kısa bir gecikme ile loading göster
      await Future.delayed(const Duration(milliseconds: 800));
    } finally {
      if (mounted) {
        setState(() => _isRefreshing = false);
      }
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _onLike() async {
    debugPrint('🟢 DEBUG: _onLike tetiklendi');
    
    if (!_checkConnectivity()) {
      debugPrint('❌ DEBUG: İnternet bağlantısı yok');
      return;
    }
    
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      debugPrint('❌ DEBUG: Kullanıcı giriş yapmamış');
      return;
    }
    debugPrint('🟢 DEBUG: User ID: ${user.uid}');

    try {
      // Kullanıcı verisini al
      debugPrint('🟢 DEBUG: Firebase\'den kullanıcı verisi çekiliyor...');
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (!userDoc.exists) {
        debugPrint('❌ DEBUG: Kullanıcı dokümanı bulunamadı');
        return;
      }

      final userData = userDoc.data()!;
      final isPremium = userData['isPremium'] as bool? ?? false;
      debugPrint('🟢 DEBUG: Is Premium: $isPremium');

      // ADIM A: Premium Kontrolü
      if (isPremium) {
        // Premium kullanıcı - limit yok
        debugPrint('🟢 DEBUG: Premium kullanıcı - limit yok, direkt swipe yapılıyor');
        HapticFeedback.mediumImpact();
        final notifier = ref.read(swipeProvider.notifier);
        notifier.swipeRight(0);
        return;
      }

      // ADIM B: Süre ve Reset Kontrolü (Lazy Reset)
      int remainingFreeLikes = userData['remainingFreeLikes'] as int? ?? 5;
      DateTime? likeWindowStartTime = (userData['likeWindowStartTime'] as Timestamp?)?.toDate();
      debugPrint('🟢 DEBUG: Kalan like hakkı: $remainingFreeLikes/5');
      debugPrint('🟢 DEBUG: Pencere başlangıç: $likeWindowStartTime');

      final now = DateTime.now();
      bool needsReset = false;

      if (likeWindowStartTime == null) {
        needsReset = true;
        debugPrint('🟢 DEBUG: İlk like - pencere başlatılıyor');
      } else {
        final hoursSinceStart = now.difference(likeWindowStartTime).inHours;
        debugPrint('🟢 DEBUG: Geçen süre: $hoursSinceStart saat');
        if (hoursSinceStart >= 8) {
          needsReset = true;
          debugPrint('🟢 DEBUG: 8 saat geçti - haklar resetleniyor');
        }
      }

      // Reset gerekiyorsa hakları 5'e eşitle
      if (needsReset) {
        remainingFreeLikes = 5;
        likeWindowStartTime = now;
        debugPrint('🟢 DEBUG: Reset sonrası: $remainingFreeLikes/5');
      }

      // ADIM C: Hak Kontrolü
      if (remainingFreeLikes > 0) {
        // Hakkı azalt
        final newLikes = remainingFreeLikes - 1;
        debugPrint('🟢 DEBUG: Yeni like sayısı: $newLikes/5');
        
        // Firebase'i güncelle (set + merge: true ile güvenli güncelleme)
        try {
          debugPrint('🟢 DEBUG: Firebase güncelleniyor...');
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .set({
            'remainingFreeLikes': newLikes,
            'likeWindowStartTime': Timestamp.fromDate(likeWindowStartTime!),
          }, SetOptions(merge: true)); // merge: true ile güvenli güncelleme
          
          debugPrint('✅ DEBUG: Firebase başarıyla güncellendi!');
        } catch (firebaseError) {
          debugPrint('❌ DEBUG: Firebase güncelleme hatası: $firebaseError');
          throw firebaseError; // Hatayı üst bloğa at
        }

        // Like işlemini gerçekleştir
        debugPrint('🟢 DEBUG: Swipe tetikleniyor...');
        HapticFeedback.mediumImpact();
        final notifier = ref.read(swipeProvider.notifier);
        notifier.swipeRight(0);

        // Kullanıcıya bilgi ver
        if (newLikes > 0) {
          debugPrint('💚 Like atıldı! Kalan hakkın: $newLikes/5');
        } else {
          debugPrint('⚠️ Son like hakkını kullandın! 8 saat sonra yenilenecek.');
        }
      } else {
        // Hak dolmuş - Dialog göster
        debugPrint('❌ DEBUG: Like hakkı doldu - Dialog gösteriliyor');
        HapticFeedback.heavyImpact();
        
        // Kalan süreyi hesapla
        final remainingMinutes = (8 * 60) - now.difference(likeWindowStartTime!).inMinutes;
        final displayHours = remainingMinutes ~/ 60;
        final displayMinutes = remainingMinutes % 60;
        debugPrint('🟢 DEBUG: Kalan süre: ${displayHours}s ${displayMinutes}dk');
        
        _showLikeQuotaDialog(displayHours, displayMinutes);
      }
    } catch (e, stackTrace) {
      debugPrint('❌ DEBUG: Like quota error: $e');
      debugPrint('❌ DEBUG: StackTrace: $stackTrace');
      // Hata olursa direkt like'ı geçir (fallback)
      debugPrint('⚠️ DEBUG: Fallback - Hata oluştu ama swipe tetikleniyor');
      HapticFeedback.mediumImpact();
      final notifier = ref.read(swipeProvider.notifier);
      notifier.swipeRight(0);
    }
  }

  void _onDislike() {
    if (!_checkConnectivity()) return;
    HapticFeedback.mediumImpact();
    
    // Son 5 dislike edilen kullanıcıyı geçmişe ekle (Stack - LIFO)
    final swipeState = ref.read(swipeProvider);
    if (swipeState.profiles.isNotEmpty) {
      setState(() {
        // Listeye ekle (sona)
        _dislikedHistory.add(swipeState.profiles.first);
        
        // 5'ten fazla ise en eskiyi sil (baştan)
        if (_dislikedHistory.length > 5) {
          _dislikedHistory.removeAt(0);
        }
      });
    }
    
    final notifier = ref.read(swipeProvider.notifier);
    notifier.swipeLeft(0);
  }

  /// Geri Al (Rewind) - Premium özelliği
  Future<void> _onRewind() async {
    if (!_checkConnectivity()) return;
    
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      // Kullanıcı verisini al
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (!userDoc.exists) return;

      final userData = userDoc.data()!;
      final isPremium = userData['isPremium'] as bool? ?? false;

      // ADIM A: Premium Kontrolü
      if (!isPremium) {
        HapticFeedback.heavyImpact();
        _showPremiumRequiredDialog();
        return;
      }

      // ADIM B: Tarih ve Reset Kontrolü
      int monthlyRewindRights = userData['monthlyRewindRights'] as int? ?? 5;
      DateTime? lastRewindResetDate = (userData['lastRewindResetDate'] as Timestamp?)?.toDate();

      final now = DateTime.now();
      bool needsReset = false;

      if (lastRewindResetDate == null) {
        needsReset = true;
      } else {
        final daysSinceReset = now.difference(lastRewindResetDate).inDays;
        if (daysSinceReset >= 30) {
          needsReset = true;
        }
      }

      // Reset gerekiyorsa hakları 5'e eşitle
      if (needsReset) {
        monthlyRewindRights = 5;
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .update({
          'monthlyRewindRights': 5,
          'lastRewindResetDate': FieldValue.serverTimestamp(),
        });
      }

      // ADIM C: Hak Kullanımı
      if (monthlyRewindRights > 0) {
        // Geri alınacak kullanıcı var mı? (Stack boş mu?)
        if (_dislikedHistory.isEmpty) {
          HapticFeedback.lightImpact();
          AppNotification.error(
            title: 'Geri Alınamıyor',
            subtitle: 'Henüz kimseyi geçmedin!',
          );
          return;
        }

        // Geri alma işlemi - Stack'ten son kişiyi al (LIFO)
        HapticFeedback.mediumImpact();
        
        // Son dislike edilen kullanıcıyı al (ama henüz listeden çıkarma)
        final lastDislikedUser = _dislikedHistory.last;
        
        // Kartı geri ekle (Provider'a manuel ekle)
        final notifier = ref.read(swipeProvider.notifier);
        notifier.rewindLastSwipe(lastDislikedUser);
        
        // Hakkı azalt
        final newRights = monthlyRewindRights - 1;
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .update({
          'monthlyRewindRights': newRights,
        });

        // Kullanıcıya bildir
        AppNotification.success(
          title: 'Geri Alındı! ✨',
          subtitle: 'Kalan hakkın: $newRights/5',
        );

        // Stack'ten son kullanıcıyı çıkar (LIFO - removeLast)
        setState(() {
          _dislikedHistory.removeLast();
        });
      } else {
        // Hak dolmuş
        HapticFeedback.heavyImpact();
        AppNotification.error(
          title: 'Hakkın Doldu',
          subtitle: 'Bu ayki geri alma hakkın doldu (5/5). Gelecek ay yenilenecek!',
        );
      }
    } catch (e) {
      debugPrint('Rewind error: $e');
      AppNotification.error(
        title: 'Hata',
        subtitle: 'Geri alma işlemi başarısız oldu.',
      );
    }
  }

  /// Premium gerekli uyarısı göster
  void _showPremiumRequiredDialog() {
    showModernDialog(
      context: context,
      builder: (dialogContext) => ModernAnimatedDialog(
        type: DialogType.warning,
        icon: Icons.workspace_premium_rounded,
        title: 'Premium Özellik',
        subtitle: 'Geri alma özelliği sadece Premium üyelere özeldir!',
        confirmText: 'Premium\'a Geç',
        confirmButtonColor: const Color(0xFFFFB300),
        onConfirm: () async {
          Navigator.pop(dialogContext);
          await Navigator.push(context, PremiumOfferScreen.route());
        },
        cancelText: 'İptal',
        onCancel: () => Navigator.pop(dialogContext),
      ),
    );
  }

  /// Like hakkı doldu dialog'u
  void _showLikeQuotaDialog(int hours, int minutes) {
    // Zaman formatı: "X saat Y dakika" (daha okunaklı)
    final timeText = hours > 0 
        ? '$hours saat ${minutes > 0 ? "$minutes dakika" : ""}'.trim()
        : '$minutes dakika';
    
    showModernDialog(
      context: context,
      builder: (dialogContext) => ModernAnimatedDialog(
        type: DialogType.warning,
        icon: Icons.favorite_border_rounded,
        title: 'Hızına Yetişemiyoruz!',
        subtitle: 'Çok fazla kişiyi beğendin. Bir sonraki beğenini $timeText sonra atabilirsin.\n\nBeklemek istemiyorsan Premium\'a geç ve sınırları kaldır!',
        confirmText: 'Premium\'a Geç',
        confirmButtonColor: const Color(0xFFFF4458),
        onConfirm: () async {
          Navigator.pop(dialogContext);
          await Navigator.push(context, PremiumOfferScreen.route());
        },
        cancelText: 'Tamam',
        onCancel: () => Navigator.pop(dialogContext),
      ),
    );
  }

  /// İnternet bağlantısını kontrol et, yoksa uyarı göster
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

  /// Modern raporlama bottom sheet göster (Apple App Store UGC compliance)
  void _showReportSheet(UserProfile profile) {
    ReportBottomSheet.show(
      context: context,
      userName: profile.name,
      onSubmit: (reason, description) => _submitReport(profile, reason, description),
    );
  }

  /// Raporu gönder ve otomatik engelle (Apple UGC compliance)
  Future<void> _submitReport(UserProfile profile, String reason, String description) async {
    // Loading göster
    showModernDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const PopScope(
        canPop: false,
        child: ModernLoadingDialog(
          message: 'Sikayet gonderiliyor...',
          color: Colors.orange,
        ),
      ),
    );

    final result = await _userService.reportAndBlockUser(
      targetUserId: profile.id,
      reason: reason,
      description: description.isNotEmpty ? description : null,
    );

    if (mounted) {
      Navigator.pop(context); // Loading'i kapat

      if (result.success) {
        // Kullanıcıyı listeden kaldır
        ref.read(swipeProvider.notifier).removeBlockedUser(profile.id);
        ref.read(likesUIProvider.notifier).removeUser(profile.id);

        AppNotification.success(
          title: 'Sikayetiniz Alindi',
          subtitle: '24 saat icinde incelenecektir. ${profile.name} engellendi.',
          duration: const Duration(seconds: 5),
        );
      } else {
        AppNotification.error(
          title: 'Hata Olustu',
          subtitle: 'Sikayet gonderilemedi. Lutfen tekrar deneyin.',
          duration: const Duration(seconds: 4),
        );
      }
    }
  }

  /// Engelleme dialogunu göster
  void _showBlockDialog(UserProfile profile) {
    HapticFeedback.mediumImpact();

    showModernDialog(
      context: context,
      builder: (dialogContext) => ModernAnimatedDialog(
        type: DialogType.danger,
        icon: Icons.block_rounded,
        title: 'Kullanıcıyı Engelle',
        subtitle:
            '${profile.name} adlı kullanıcıyı engellemek istediğinize emin misiniz?\n\nBirbirinizi bir daha göremeyecek ve mesajlaşamayacaksınız.',
        cancelText: 'İptal',
        confirmText: 'Engelle',
        confirmButtonColor: Colors.red,
        onConfirm: () async {
          HapticFeedback.mediumImpact();
          Navigator.pop(dialogContext);
          await _blockUserGlobally(profile);
        },
      ),
    );
  }

  /// Global bloklama - Keşfet, Beğeniler ve Sohbetlerden kaldır
  Future<void> _blockUserGlobally(UserProfile profile) async {
    // Loading göster
    showModernDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const PopScope(
        canPop: false,
        child: ModernLoadingDialog(
          message: 'Engelleniyor...',
          color: Colors.red,
        ),
      ),
    );

    try {
      // 1. Firestore'da engelle
      final success = await _userService.blockUser(profile.id);

      if (success) {
        // 2. Keşfet'ten kaldır (bir sonraki profile geç)
        ref.read(swipeProvider.notifier).removeBlockedUser(profile.id);

        // 3. Beğenilerden kaldır
        ref.read(likesUIProvider.notifier).removeUser(profile.id);

        // 4. Sohbeti sil (varsa)
        await _chatService.deleteChatWithUser(profile.id);

        if (mounted) {
          Navigator.pop(context); // Loading'i kapat

          AppNotification.blocked(
            title: 'Kullanıcı Engellendi',
            subtitle: '${profile.name} artık sizi göremez',
          );
        }
      } else {
        if (mounted) {
          Navigator.pop(context);
          AppNotification.error(title: 'Engelleme başarısız oldu');
        }
      }
    } catch (e) {
      debugPrint('Error blocking user: $e');
      if (mounted) {
        Navigator.pop(context);
        AppNotification.error(title: 'Bir hata oluştu');
      }
    }
  }

  /// Filtre butonu (Gelişmiş filtreler - Premium özelliği)
  Widget _buildFilterButton() {
    final swipeState = ref.watch(swipeProvider);
    final hasActiveFilters = swipeState.filterCity != null ||
        swipeState.filterUniversity != null ||
        swipeState.filterDepartment != null ||
        swipeState.filterGrade != null;

    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        showModalBottomSheet(
          context: context,
          backgroundColor: Colors.transparent,
          isScrollControlled: true,
          builder: (context) => const FiltersModal(),
        );
      },
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Main Button
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Icon(
              Icons.tune_rounded,
              size: 24,
              color: hasActiveFilters ? const Color(0xFF5C6BC0) : const Color(0xFF616161),
            ),
          ),

          // Active Filter Badge
          if (hasActiveFilters)
            Positioned(
              top: -4,
              right: -4,
              child: Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: const Color(0xFFFF4458),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final swipeState = ref.watch(swipeProvider);

    // Listen for match notification – önce sohbeti oluştur, sonra match popup göster
    ref.listen<SwipeState>(swipeProvider, (previous, current) {
      if (current.isMatch && current.lastSwipedProfile != null) {
        final profile = current.lastSwipedProfile!;
        ref.read(swipeProvider.notifier).clearMatchNotification();
        _createChatAndShowMatch(profile);
      }
    });

    // Immersive mode - transparent status bar with light icons
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light, // White icons for dark photos
      statusBarBrightness: Brightness.dark, // iOS
    ));

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      extendBodyBehindAppBar: true,
      extendBody: true,
      body: _buildBody(swipeState),
    );
  }

  Widget _buildBody(SwipeState state) {
    // Full immersive view - no header, content extends to top
    return _buildContent(state);
  }

  Widget _buildContent(SwipeState state) {
    if (state.isLoading && state.profiles.isEmpty) {
      return _buildLoadingState();
    }

    if (state.error != null && state.profiles.isEmpty) {
      return _buildErrorState(state.error!);
    }

    if (state.profiles.isEmpty) {
      return _buildEmptyState();
    }

    final profile = state.profiles.first;
    return _buildProfileView(profile);
  }

  Widget _buildProfileView(UserProfile profile) {
    // Full immersive view - no top padding, photo starts from edge-to-edge
    return Stack(
      children: [
        // Scrollable profile content - starts from very top
        // ValueKey ile her kullanıcı için yeni widget instance oluştur
        // Bu sayede scroll pozisyonu her kullanıcı için sıfırdan başlar
        CustomScrollView(
          key: ValueKey(profile.id), // BU SATIR ÇOK ÖNEMLİ - Scroll state sıfırlama
          controller: _scrollController,
          slivers: [
            // Main photo with action buttons - no top spacing
            SliverToBoxAdapter(
              child: _buildMainPhotoSection(profile),
            ),
            // Profile info
            SliverToBoxAdapter(
              child: _buildInfoSection(profile),
            ),
            // Second photo (if exists)
            if (profile.photos.length > 1)
              SliverToBoxAdapter(
                child: _buildPhotoCard(profile.photos[1], 1),
              ),
            // Interests section
            if (profile.interests.isNotEmpty)
              SliverToBoxAdapter(
                child: _buildInterestsSection(profile),
              ),
            // Third photo (if exists)
            if (profile.photos.length > 2)
              SliverToBoxAdapter(
                child: _buildPhotoCard(profile.photos[2], 2),
              ),
            // Bio section
            if (profile.bio.isNotEmpty)
              SliverToBoxAdapter(
                child: _buildBioSection(profile),
              ),
            // Remaining photos
            if (profile.photos.length > 3)
              ...profile.photos.skip(3).toList().asMap().entries.map(
                    (entry) => SliverToBoxAdapter(
                      child: _buildPhotoCard(entry.value, entry.key + 3),
                    ),
                  ),
            // Bottom padding
            const SliverToBoxAdapter(
              child: SizedBox(height: 120),
            ),
          ],
        ),
        // Filtre butonu - sol üst köşe (Premium özelliği)
        Positioned(
          top: MediaQuery.of(context).padding.top + 12,
          left: 16,
          child: _buildFilterButton(),
        ),

        // Seçenekler menüsü - sağ üst köşe (Üç Nokta)
        // Modern Bottom Sheet: Şikayet Et + Engelle (Apple App Store UGC compliance)
        Positioned(
          top: MediaQuery.of(context).padding.top + 12,
          right: 16,
          child: UserOptionsMenu(
            backgroundColor: Colors.black.withValues(alpha: 0.4),
            iconColor: Colors.white,
            onReport: () => _showReportSheet(profile),
            onBlock: () => _showBlockDialog(profile),
          ),
        ),
        // Fixed action buttons at bottom
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: _buildActionButtons(),
        ),
      ],
    );
  }

  Widget _buildMainPhotoSection(UserProfile profile) {
    return Stack(
      children: [
        // Main photo
        AspectRatio(
          aspectRatio: 0.75,
          child: CachedNetworkImage(
            imageUrl: profile.primaryPhoto,
            fit: BoxFit.cover,
            cacheManager: AppCacheManager.instance,
            placeholder: (context, url) => Shimmer.fromColors(
              baseColor: Colors.grey[300]!,
              highlightColor: Colors.grey[100]!,
              child: Container(
                color: Colors.grey[200],
                child: const Center(
                  child: Icon(Icons.person, size: 80, color: Colors.grey),
                ),
              ),
            ),
            errorWidget: (context, url, error) => Shimmer.fromColors(
              baseColor: Colors.grey[300]!,
              highlightColor: Colors.grey[100]!,
              child: Container(
                color: Colors.grey[200],
                child: const Center(
                  child: Icon(Icons.person, size: 80, color: Colors.grey),
                ),
              ),
            ),
          ),
        ),
        // Gradient overlay at bottom
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          height: 200,
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  Colors.black.withValues(alpha: 0.7),
                ],
              ),
            ),
          ),
        ),
        // Name and basic info
        Positioned(
          left: 20,
          right: 20,
          bottom: 20,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Text(
                      '${profile.name}, ${profile.age}',
                      style: GoogleFonts.poppins(
                        fontSize: 32,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        shadows: [
                          Shadow(
                            color: Colors.black.withValues(alpha: 0.3),
                            blurRadius: 10,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              if (profile.university.isNotEmpty) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(
                      Icons.school_rounded,
                      color: Colors.white70,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        profile.university,
                        style: GoogleFonts.poppins(
                          fontSize: 15,
                          color: Colors.white70,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildInfoSection(UserProfile profile) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (profile.department.isNotEmpty) ...[
            _buildInfoRow(
              Icons.auto_stories_rounded,
              'Bolum',
              profile.department,
            ),
            const SizedBox(height: 16),
          ],
          if (profile.university.isNotEmpty)
            _buildInfoRow(
              Icons.location_city_rounded,
              'Universite',
              profile.university,
            ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: const Color(0xFF5C6BC0).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            icon,
            color: const Color(0xFF5C6BC0),
            size: 22,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: Colors.grey[500],
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                value,
                style: GoogleFonts.poppins(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey[800],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPhotoCard(String photoUrl, int index) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: AspectRatio(
          aspectRatio: 0.85,
          child: CachedNetworkImage(
            imageUrl: photoUrl,
            fit: BoxFit.cover,
            cacheManager: AppCacheManager.instance,
            placeholder: (context, url) => Shimmer.fromColors(
              baseColor: Colors.grey[300]!,
              highlightColor: Colors.grey[100]!,
              child: Container(
                color: Colors.grey[200],
                child: const Center(
                  child: Icon(Icons.image, size: 50, color: Colors.grey),
                ),
              ),
            ),
            errorWidget: (context, url, error) => Shimmer.fromColors(
              baseColor: Colors.grey[300]!,
              highlightColor: Colors.grey[100]!,
              child: Container(
                color: Colors.grey[200],
                child: const Center(
                  child: Icon(Icons.image, size: 50, color: Colors.grey),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInterestsSection(UserProfile profile) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 4,
                height: 24,
                decoration: BoxDecoration(
                  color: const Color(0xFF5C6BC0),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Ilgi Alanlari',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[800],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: profile.interests.map((interest) {
              return Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xFF5C6BC0).withValues(alpha: 0.1),
                      const Color(0xFF7986CB).withValues(alpha: 0.1),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(25),
                  border: Border.all(
                    color: const Color(0xFF5C6BC0).withValues(alpha: 0.3),
                  ),
                ),
                child: Text(
                  interest,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: const Color(0xFF5C6BC0),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildBioSection(UserProfile profile) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 4,
                height: 24,
                decoration: BoxDecoration(
                  color: const Color(0xFF5C6BC0),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Hakkinda',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[800],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            profile.bio,
            style: GoogleFonts.poppins(
              fontSize: 15,
              color: Colors.grey[700],
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    final isOnline = ref.watch(isOnlineProvider);

    return Container(
      padding: const EdgeInsets.fromLTRB(40, 40, 40, 20),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0x00FFFFFF), // Transparent white
            Color(0xCCFFFFFF), // 80% white
            Color(0xFFFFFFFF), // Solid white
            Color(0xFFFFFFFF), // Solid white
          ],
          stops: [0.0, 0.3, 0.6, 1.0],
        ),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Offline indicator
            if (!isOnline)
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.wifi_off_rounded, size: 16, color: Colors.red),
                    const SizedBox(width: 8),
                    Text(
                      'Çevrimdışı - Etkileşim kısıtlı',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: Colors.red,
                      ),
                    ),
                  ],
                ),
              ),
            // Action buttons - with opacity when offline
            AnimatedOpacity(
              opacity: isOnline ? 1.0 : 0.5,
              duration: const Duration(milliseconds: 300),
              child: StreamBuilder<DocumentSnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('users')
                    .doc(FirebaseAuth.instance.currentUser?.uid)
                    .snapshots(),
                builder: (context, snapshot) {
                  final isPremium = snapshot.hasData
                      ? ((snapshot.data!.data() as Map<String, dynamic>?)?['isPremium'] as bool? ?? false)
                      : false;
                  final rewindRights = snapshot.hasData
                      ? ((snapshot.data!.data() as Map<String, dynamic>?)?['monthlyRewindRights'] as int? ?? 5)
                      : 5;

                  return Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      // Dislike button
                      _buildActionButton(
                        icon: Icons.close_rounded,
                        color: const Color(0xFFFF4458),
                        size: 64,
                        iconSize: 32,
                        onTap: _onDislike,
                      ),
                      // Rewind button (Geri Al - Premium özelliği) + Badge
                      _buildRewindButtonWithBadge(
                        isPremium: isPremium,
                        rewindRights: rewindRights,
                      ),
                      // Like button (Badge kaldırıldı - daha gizemli UX)
                      _buildActionButton(
                        icon: Icons.waving_hand_rounded,
                        color: const Color(0xFF00E676),
                        size: 64,
                        iconSize: 32,
                        onTap: _onLike,
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required Color color,
    required double size,
    required double iconSize,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.3),
              blurRadius: 15,
              spreadRadius: 2,
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          shape: const CircleBorder(),
          child: InkWell(
            onTap: onTap,
            customBorder: const CircleBorder(),
            splashColor: color.withValues(alpha: 0.2),
            child: Center(
              child: Icon(icon, color: color, size: iconSize),
            ),
          ),
        ),
      ),
    );
  }

  /// Rewind button with Premium badge
  Widget _buildRewindButtonWithBadge({
    required bool isPremium,
    required int rewindRights,
  }) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        // Rewind button
        _buildActionButton(
          icon: Icons.replay_rounded,
          color: const Color(0xFFFFB300),
          size: 52,
          iconSize: 26,
          onTap: _onRewind,
        ),
        // Premium badge (sadece Premium kullanıcılara göster)
        if (isPremium)
          Positioned(
            top: -4,
            right: -4,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFFFB300), Color(0xFFFFA000)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.white, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFFFB300).withValues(alpha: 0.5),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Text(
                '$rewindRights',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  height: 1.0,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF5C6BC0).withValues(alpha: 0.2),
                  blurRadius: 20,
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
            'Profiller yukleniyor...',
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
              'Bir hata olustu',
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
    return Stack(
      children: [
        // Empty state content (center)
        Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(28),
                  decoration: BoxDecoration(
                    color: const Color(0xFF5C6BC0).withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.explore_off_rounded,
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
                  'Filtreleri değiştir veya daha sonra tekrar kontrol et',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
            const SizedBox(height: 32),
            // Admin için: Row içinde iki buton
            // Normal kullanıcı için: Ortalanmış tek Yenile butonu
            if (_isAdmin)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildRefreshButton(),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed: _seedTestProfiles,
                    icon: const Icon(Icons.people),
                    label: Text(
                      'Test Ekle',
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
              )
            else
              // Normal kullanıcı - ortalanmış Yenile butonu
              Center(child: _buildRefreshButton()),
              ],
            ),
          ),
        ),

        // Filtre butonu - HER ZAMAN GÖRÜNÜR (profil olsa da olmasa da)
        Positioned(
          top: MediaQuery.of(context).padding.top + 12,
          left: 16,
          child: _buildFilterButton(),
        ),
      ],
    );
  }

  /// Yenile butonu - loading indicator ile
  Widget _buildRefreshButton() {
    return ElevatedButton.icon(
      onPressed: _isRefreshing ? null : _refreshProfiles,
      icon: _isRefreshing
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            )
          : const Icon(Icons.refresh),
      label: Text(
        _isRefreshing ? 'Yenileniyor...' : 'Yenile',
        style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF5C6BC0),
        foregroundColor: Colors.white,
        disabledBackgroundColor: const Color(0xFF5C6BC0).withValues(alpha: 0.7),
        disabledForegroundColor: Colors.white70,
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(30),
        ),
      ),
    );
  }

  Future<void> _seedTestProfiles() async {
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

      // Yeni eklenen demo kullanıcıların mevcut kullanıcıyı beğenmesini sağla
      final likeCount = await seedService.seedDemoLikesToCurrentUser();

      if (mounted) {
        Navigator.pop(context);
        AppNotification.success(
          title: 'Test Profilleri Eklendi',
          subtitle: likeCount > 0
              ? '$likeCount kişi seninle tanışmak istiyor!'
              : 'Yeni profiller keşfetmeye hazır',
        );
        ref.read(swipeProvider.notifier).refresh();
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        AppNotification.error(
          title: 'Hata',
          subtitle: 'Profiller eklenemedi',
        );
      }
    }
  }

  /// Eşleşmede önce sohbeti Firestore'da oluşturur, sonra match popup gösterir.
  /// Böylece "Mesaj Gönder"e basıldığında sohbet hazır olur, yükleniyorda takılmaz.
  Future<void> _createChatAndShowMatch(UserProfile profile) async {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    if (currentUserId == null) return;
    final chatId = await _chatService.createMatchChat(currentUserId, profile.id);
    if (!mounted) return;
    if (chatId == null) {
      AppNotification.error(title: 'Sohbet oluşturulamadı');
      return;
    }
    _showMatchScreen(profile);
  }

  void _showMatchScreen(UserProfile profile) {
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => MatchPopup(
          matchedProfile: profile,
          onSendMessage: () {
            Navigator.pop(context);
            // Navigate to chat with the matched user
            _navigateToChat(profile);
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
  void _navigateToChat(UserProfile matchedProfile) {
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
}

/// Premium Haptic Button - Görsel ve fiziksel geri bildirim veren buton
/// Tıklandığında küçülme animasyonu ve haptic feedback sağlar
class _PremiumHapticButton extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;

  const _PremiumHapticButton({
    required this.child,
    required this.onTap,
  });

  @override
  State<_PremiumHapticButton> createState() => _PremiumHapticButtonState();
}

class _PremiumHapticButtonState extends State<_PremiumHapticButton> {
  bool _isPressed = false;

  void _onTapDown(TapDownDetails details) {
    setState(() => _isPressed = true);
    HapticFeedback.heavyImpact();
  }

  void _onTapUp(TapUpDetails details) {
    setState(() => _isPressed = false);
    widget.onTap();
  }

  void _onTapCancel() {
    setState(() => _isPressed = false);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      child: AnimatedScale(
        scale: _isPressed ? 0.85 : 1.0,
        duration: const Duration(milliseconds: 100),
        curve: Curves.easeInOut,
        child: widget.child,
      ),
    );
  }
}
