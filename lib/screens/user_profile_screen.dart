import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../widgets/app_notification.dart';
import '../services/chat_service.dart';
import '../services/user_service.dart';
import '../models/user_profile.dart';
import '../widgets/modern_animated_dialog.dart';
import '../providers/likes_provider.dart';

class UserProfileScreen extends ConsumerStatefulWidget {
  final String userId;

  /// Optional preview profile - if provided, skip Firestore fetch
  /// Used for real-time preview in ProfileEditScreen
  final UserProfile? previewProfile;

  /// Callback when user is blocked - used to update parent screen's state
  final void Function(String blockedUserId)? onUserBlocked;

  /// Optional like callback - if provided, shows like/dislike buttons
  /// Used when coming from Likes screen
  final VoidCallback? onLike;

  /// Optional dislike callback - if provided, shows like/dislike buttons
  /// Used when coming from Likes screen
  final VoidCallback? onDislike;

  const UserProfileScreen({
    super.key,
    required this.userId,
    this.previewProfile,
    this.onUserBlocked,
    this.onLike,
    this.onDislike,
  });

  @override
  ConsumerState<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends ConsumerState<UserProfileScreen> {
  final ChatService _chatService = ChatService();
  final UserService _userService = UserService();
  UserProfile? _profile;
  bool _isLoading = true;
  bool _isBlocked = false;        // Did I block them?
  bool _isBlockedByTarget = false; // Did they block me?
  String? _error;

  /// Check if viewing own profile (Preview Mode)
  bool get _isOwnProfile => _userService.currentUserId == widget.userId;

  /// Check if like/dislike buttons should be shown
  bool get _showLikeDislikeButtons => widget.onLike != null || widget.onDislike != null;

  /// Check if a photo path is a local file (not a network URL)
  bool _isLocalFile(String path) {
    return path.startsWith('/') || path.startsWith('file://');
  }

  /// Build image widget that handles both local files and network URLs
  Widget _buildPhotoWidget(String photoPath, {BoxFit fit = BoxFit.cover}) {
    if (_isLocalFile(photoPath)) {
      return Image.file(
        File(photoPath.replaceFirst('file://', '')),
        fit: fit,
        errorBuilder: (context, error, stackTrace) => Container(
          color: const Color(0xFF5C6BC0),
          child: const Icon(Icons.broken_image, size: 50, color: Colors.white),
        ),
      );
    } else {
      return CachedNetworkImage(
        imageUrl: photoPath,
        fit: fit,
        placeholder: (context, url) => Container(
          color: Colors.grey[300],
          child: const Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF5C6BC0)),
            ),
          ),
        ),
        errorWidget: (context, url, error) => Container(
          color: const Color(0xFF5C6BC0),
          child: const Icon(Icons.person, size: 100, color: Colors.white),
        ),
      );
    }
  }

  @override
  void initState() {
    super.initState();
    _loadProfileAndBlockStatus();
  }

  Future<void> _loadProfileAndBlockStatus() async {
    try {
      // If previewProfile is provided, use it directly (real-time preview mode)
      if (widget.previewProfile != null) {
        if (mounted) {
          setState(() {
            _profile = widget.previewProfile;
            _isLoading = false;
          });
        }
        return;
      }

      // If viewing own profile, skip block checks
      if (_isOwnProfile) {
        final profile = await _chatService.getUserProfile(widget.userId);
        if (mounted) {
          setState(() {
            _profile = profile;
            _isLoading = false;
            if (profile == null) {
              _error = 'Profil bulunamadi';
            }
          });
        }
        return;
      }

      // Load profile and BOTH block statuses in parallel
      final results = await Future.wait([
        _chatService.getUserProfile(widget.userId),
        _userService.isUserBlocked(widget.userId),
        _userService.isBlockedByUser(widget.userId),
      ]);

      final profile = results[0] as UserProfile?;
      final isBlocked = results[1] as bool;
      final isBlockedByTarget = results[2] as bool;

      if (mounted) {
        setState(() {
          _profile = profile;
          _isBlocked = isBlocked;
          _isBlockedByTarget = isBlockedByTarget;
          _isLoading = false;

          if (profile == null) {
            _error = 'Profil bulunamadi';
          } else if (isBlockedByTarget) {
            _error = 'Bu profile erisim yok';
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = 'Profil yuklenirken hata olustu';
        });
      }
    }
  }

  Future<void> _unblockUser() async {
    setState(() => _isLoading = true);

    final success = await _userService.unblockUser(widget.userId);

    if (mounted) {
      setState(() {
        _isLoading = false;
        if (success) {
          _isBlocked = false;
        }
      });

      if (success) {
        // Kullanıcıyı local state'den temizle (filtreye takılmasın)
        ref.read(likesUIProvider.notifier).restoreUser(widget.userId);

        // Provider'ları invalidate et - likes listesi yenilensin
        ref.invalidate(receivedLikesProvider);
      }

      if (success) {
        AppNotification.unblocked(
          title: 'Engel Kaldırıldı',
          subtitle: 'Bu kullanıcı artık size ulaşabilir',
        );
      } else {
        AppNotification.error(
          title: 'Engel kaldırılamadı',
          subtitle: 'Lütfen tekrar deneyin',
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Immersive mode for preview
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      statusBarBrightness: Brightness.dark,
    ));

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      extendBodyBehindAppBar: true,
      body: _isLoading
          ? _buildLoadingState()
          : _isBlockedByTarget
              ? _buildAccessDeniedState()
              : _error != null
                  ? _buildErrorState()
                  : _isBlocked
                      ? _buildBlockedState()
                      : _buildProfileContent(),
    );
  }

  Widget _buildAccessDeniedState() {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Color(0xFF5C6BC0)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Profil',
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Colors.grey[800],
          ),
        ),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.visibility_off_rounded,
                  size: 80,
                  color: Colors.grey[400],
                ),
              ),
              const SizedBox(height: 32),
              Text(
                'Profil Goruntulenemiyor',
                style: GoogleFonts.poppins(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[800],
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Bu kullanicinin profili su anda\ngoruntulenemiyor.',
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 15,
                  color: Colors.grey[600],
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 32),
              ElevatedButton.icon(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                label: Text(
                  'Geri Don',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF5C6BC0),
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBlockedState() {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Color(0xFF5C6BC0)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Engellenen Kullanici',
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Colors.grey[800],
          ),
        ),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: Colors.grey),
            onSelected: (value) {
              if (value == 'unblock') {
                _showUnblockDialog();
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'unblock',
                child: Row(
                  children: [
                    const Icon(Icons.lock_open, color: Colors.green, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Engeli Kaldir',
                      style: GoogleFonts.poppins(fontSize: 14),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.block_rounded,
                  size: 80,
                  color: Colors.red,
                ),
              ),
              const SizedBox(height: 32),
              Text(
                'Bu Kullanici Engellendi',
                style: GoogleFonts.poppins(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[800],
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Bu kullanicinin profilini goremez ve\nsize mesaj atamazsiniz.',
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 15,
                  color: Colors.grey[600],
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 32),
              ElevatedButton.icon(
                onPressed: _showUnblockDialog,
                icon: const Icon(Icons.lock_open, color: Colors.white),
                label: Text(
                  'Engeli Kaldir',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 2,
                ),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  'Geri Don',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showUnblockDialog() {
    showModernDialog(
      context: context,
      builder: (dialogContext) => ModernAnimatedDialog(
        type: DialogType.success,
        icon: Icons.lock_open_rounded,
        title: 'Engeli Kaldır',
        subtitle: 'Bu kullanıcının engelini kaldırmak istediğinize emin misiniz?\n\nEngel kaldırıldıktan sonra bu kişi size mesaj atabilir ve profilinizi görebilir.',
        cancelText: 'İptal',
        confirmText: 'Engeli Kaldır',
        confirmButtonColor: Colors.green,
        onConfirm: () async {
          HapticFeedback.mediumImpact();
          Navigator.pop(dialogContext);
          await _unblockUser();
        },
      ),
    );
  }

  /// Kullanıcıyı engelleme dialogu göster
  void _showBlockUserDialog() {
    HapticFeedback.mediumImpact();

    final userName = _profile?.name ?? 'Bu kullanıcı';

    showModernDialog(
      context: context,
      builder: (dialogContext) => ModernAnimatedDialog(
        type: DialogType.danger,
        icon: Icons.block_rounded,
        title: 'Kullanıcıyı Engelle',
        subtitle: '$userName adlı kullanıcıyı engellemek istediğine emin misin?',
        content: const DialogInfoBox(
          icon: Icons.warning_amber_rounded,
          text: 'Birbirinizi bir daha göremeyecek ve mesajlaşamayacaksınız.',
          color: Colors.orange,
        ),
        cancelText: 'İptal',
        confirmText: 'Engelle',
        onConfirm: () async {
          HapticFeedback.mediumImpact();
          Navigator.pop(dialogContext);
          await _blockUserFromProfile();
        },
      ),
    );
  }

  /// Kullanıcıyı engelle ve profil ekranını kapat
  Future<void> _blockUserFromProfile() async {
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

    final success = await _userService.blockUser(widget.userId);

    if (mounted) {
      // Loading'i kapat
      Navigator.pop(context);

      if (success) {
        // Callback varsa, navigasyonu callback'e bırak (ChatDetailScreen popUntil yapacak)
        // Callback yoksa sadece profil ekranını kapat
        if (widget.onUserBlocked != null) {
          widget.onUserBlocked!(widget.userId);
        } else {
          Navigator.pop(context);
        }

        // Başarı bildirimi göster
        AppNotification.blocked(
          title: 'Kullanıcı Engellendi',
          subtitle: '${_profile?.name ?? 'Kullanıcı'} artık seni göremez',
        );
      } else {
        // Hata bildirimi göster
        AppNotification.error(
          title: 'Engelleme başarısız oldu',
          subtitle: 'Lütfen tekrar deneyin',
        );
      }
    }
  }

  Widget _buildLoadingState() {
    return const Center(
      child: CircularProgressIndicator(
        valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF5C6BC0)),
      ),
    );
  }

  Widget _buildErrorState() {
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
            _error ?? 'Bir hata olustu',
            style: GoogleFonts.poppins(
              fontSize: 16,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF5C6BC0),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              'Geri Don',
              style: GoogleFonts.poppins(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  /// Build profile content - Kesfet ekrani ile birebir ayni arayuz
  Widget _buildProfileContent() {
    final profile = _profile!;

    return Stack(
      children: [
        CustomScrollView(
          slivers: [
            // Ana fotoğraf section
            SliverToBoxAdapter(
              child: _buildMainPhotoSection(profile),
            ),
            // Preview Mode Banner (when viewing own profile)
            if (_isOwnProfile)
              SliverToBoxAdapter(
                child: _buildPreviewBanner(),
              ),
            // Bilgi section
            SliverToBoxAdapter(
              child: _buildInfoSection(profile),
            ),
            // İkinci fotoğraf (varsa)
            if (profile.photos.length > 1)
              SliverToBoxAdapter(
                child: _buildPhotoCard(profile.photos[1]),
              ),
            // Sınıf ve Kulüpler section
            if (profile.grade.isNotEmpty || profile.clubs.isNotEmpty)
              SliverToBoxAdapter(
                child: _buildGradeAndClubsSection(profile),
              ),
            // İlgi alanları section
            if (profile.interests.isNotEmpty)
              SliverToBoxAdapter(
                child: _buildInterestsSection(profile),
              ),
            // Üçüncü fotoğraf (varsa)
            if (profile.photos.length > 2)
              SliverToBoxAdapter(
                child: _buildPhotoCard(profile.photos[2]),
              ),
            // Niyet section
            if (profile.intent.isNotEmpty)
              SliverToBoxAdapter(
                child: _buildIntentSection(profile),
              ),
            // Bio section
            if (profile.bio.isNotEmpty)
              SliverToBoxAdapter(
                child: _buildBioSection(profile),
              ),
            // Kalan fotoğraflar
            if (profile.photos.length > 3)
              ...profile.photos.skip(3).map(
                    (photo) => SliverToBoxAdapter(
                      child: _buildPhotoCard(photo),
                    ),
                  ),
            // Alt boşluk (like/dislike butonları varsa daha fazla boşluk)
            SliverToBoxAdapter(
              child: SizedBox(height: _showLikeDislikeButtons ? 180 : 100),
            ),
          ],
        ),
        // Geri butonu
        Positioned(
          top: MediaQuery.of(context).padding.top + 10,
          left: 16,
          child: GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.4),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.arrow_back_ios_new,
                color: Colors.white,
                size: 20,
              ),
            ),
          ),
        ),
        // Engelleme butonu (sadece başka birinin profiline bakılıyorsa) - Premium haptic
        if (!_isOwnProfile)
          Positioned(
            top: MediaQuery.of(context).padding.top + 10,
            right: 16,
            child: _PremiumHapticButton(
              onTap: _showBlockUserDialog,
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.4),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.block_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
            ),
          ),
        // Like/Dislike butonları (Likes ekranından gelindiyse)
        if (_showLikeDislikeButtons)
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: _buildLikeDislikeButtons(),
          ),
      ],
    );
  }

  /// Like/Dislike butonları widget'ı
  Widget _buildLikeDislikeButtons() {
    return Container(
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
          // Dislike butonu
          if (widget.onDislike != null)
            _buildActionButton(
              onTap: () {
                HapticFeedback.mediumImpact();
                Navigator.pop(context);
                widget.onDislike?.call();
              },
              icon: Icons.close_rounded,
              size: 60,
              iconSize: 28,
              colors: [Colors.grey[100]!, Colors.grey[200]!],
              iconColor: Colors.grey[600]!,
              shadowColor: Colors.grey.withValues(alpha: 0.3),
            ),
          // Like butonu (büyük)
          if (widget.onLike != null)
            _buildActionButton(
              onTap: () {
                HapticFeedback.mediumImpact();
                Navigator.pop(context);
                widget.onLike?.call();
              },
              icon: Icons.waving_hand_rounded,
              size: 72,
              iconSize: 34,
              colors: const [Color(0xFF5C6BC0), Color(0xFF7986CB)],
              iconColor: Colors.white,
              shadowColor: const Color(0xFF5C6BC0).withValues(alpha: 0.4),
              isGradient: true,
            ),
        ],
      ),
    );
  }

  /// Action button widget
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
      onTap: onTap,
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

  Widget _buildMainPhotoSection(UserProfile profile) {
    return Stack(
      children: [
        // Ana fotoğraf
        AspectRatio(
          aspectRatio: 0.75,
          child: profile.photos.isNotEmpty
              ? _buildPhotoWidget(profile.photos.first)
              : Container(
                  color: const Color(0xFF5C6BC0),
                  child: const Icon(Icons.person, size: 100, color: Colors.white),
                ),
        ),
        // Gradient overlay
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
        // İsim ve temel bilgiler
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

  Widget _buildPreviewBanner() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF5C6BC0).withValues(alpha: 0.1),
            const Color(0xFF7986CB).withValues(alpha: 0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF5C6BC0).withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFF5C6BC0).withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.visibility_rounded,
              color: Color(0xFF5C6BC0),
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Onizleme Modu',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF5C6BC0),
                  ),
                ),
                Text(
                  'Profiliniz baskalarinin gozunden boyle gorunuyor',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
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

  Widget _buildGradeAndClubsSection(UserProfile profile) {
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
          // Sınıf Seviyesi
          if (profile.grade.isNotEmpty) ...[
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
                  'Sinif Seviyesi',
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[800],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
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
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.school_outlined,
                    size: 18,
                    color: Color(0xFF5C6BC0),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    profile.grade,
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: const Color(0xFF5C6BC0),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
          // Kulüpler
          if (profile.clubs.isNotEmpty) ...[
            if (profile.grade.isNotEmpty) const SizedBox(height: 20),
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
                  'Topluluklar',
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[800],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: profile.clubs.map((club) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
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
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.groups_outlined,
                        size: 16,
                        color: Color(0xFF5C6BC0),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        club,
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          color: const Color(0xFF5C6BC0),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildIntentSection(UserProfile profile) {
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
                  color: Colors.deepPurple,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Ne Icin Buradayim',
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
            children: profile.intent.map((intent) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.deepPurple.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(25),
                  border: Border.all(
                    color: Colors.deepPurple.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _getIntentIcon(intent),
                      size: 16,
                      color: Colors.deepPurple,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      intent,
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        color: Colors.deepPurple,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  IconData _getIntentIcon(String intent) {
    switch (intent) {
      case 'Kahve içmek':
      case 'Kahve icmek':
        return Icons.coffee_outlined;
      case 'Ders çalışmak':
      case 'Ders calismak':
        return Icons.menu_book_outlined;
      case 'Spor yapmak':
        return Icons.fitness_center_outlined;
      case 'Proje ortağı bulmak':
      case 'Proje ortagi bulmak':
        return Icons.handshake_outlined;
      case 'Etkinliklere katılmak':
      case 'Etkinliklere katilmak':
        return Icons.event_outlined;
      case 'Sohbet etmek':
        return Icons.chat_bubble_outline;
      case 'Yeni arkadaşlar edinmek':
      case 'Yeni arkadaslar edinmek':
        return Icons.people_outline;
      case 'Networking':
        return Icons.hub_outlined;
      default:
        return Icons.star_outline;
    }
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

  Widget _buildPhotoCard(String photoPath) {
    return GestureDetector(
      onTap: () => _showFullScreenPhoto(photoPath),
      child: Container(
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
            child: _buildPhotoWidget(photoPath),
          ),
        ),
      ),
    );
  }

  void _showFullScreenPhoto(String photoPath) {
    final isLocal = _isLocalFile(photoPath);

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            leading: IconButton(
              icon: const Icon(Icons.close, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
          ),
          body: Center(
            child: InteractiveViewer(
              child: isLocal
                  ? Image.file(
                      File(photoPath.replaceFirst('file://', '')),
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) => const Icon(
                        Icons.broken_image,
                        size: 100,
                        color: Colors.white,
                      ),
                    )
                  : CachedNetworkImage(
                      imageUrl: photoPath,
                      fit: BoxFit.contain,
                    ),
            ),
          ),
        ),
      ),
    );
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
