import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shimmer/shimmer.dart';
import '../widgets/app_notification.dart';
import '../services/user_service.dart';
import '../services/chat_service.dart';
import '../models/user_profile.dart';
import '../widgets/modern_animated_dialog.dart';
import '../providers/likes_provider.dart';
import '../providers/connectivity_provider.dart';
import '../utils/image_helper.dart';

/// Screen to manage blocked users
/// Accessible from Settings
class BlockedUsersScreen extends ConsumerStatefulWidget {
  const BlockedUsersScreen({super.key});

  @override
  ConsumerState<BlockedUsersScreen> createState() => _BlockedUsersScreenState();
}

class _BlockedUsersScreenState extends ConsumerState<BlockedUsersScreen> {
  final UserService _userService = UserService();
  final ChatService _chatService = ChatService();

  List<UserProfile> _blockedUsers = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadBlockedUsers();
  }

  Future<void> _loadBlockedUsers() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // Get blocked user IDs
      final blockedIds = await _userService.getBlockedUserIds();
      debugPrint('Found ${blockedIds.length} blocked users');

      if (blockedIds.isEmpty) {
        setState(() {
          _blockedUsers = [];
          _isLoading = false;
        });
        return;
      }

      // Fetch profiles for each blocked user
      final profiles = <UserProfile>[];
      for (final userId in blockedIds) {
        try {
          final profile = await _chatService.getUserProfile(userId);
          if (profile != null) {
            profiles.add(profile);
          }
        } catch (e) {
          debugPrint('Error fetching profile for $userId: $e');
        }
      }

      setState(() {
        _blockedUsers = profiles;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading blocked users: $e');
      setState(() {
        _isLoading = false;
        _error = 'Engellenen kullanicilar yuklenemedi';
      });
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

  Future<void> _showUnblockDialog(UserProfile user) async {
    // İnternet kontrolü - dialog açmadan önce
    if (!_checkConnectivity()) return;

    final confirmed = await showModernDialog<bool>(
      context: context,
      builder: (dialogContext) => ModernAnimatedDialog(
        type: DialogType.success,
        icon: Icons.lock_open_rounded,
        title: 'Engeli Kaldır',
        subtitle: '${user.name} adlı kullanıcının engelini kaldırmak istiyor musunuz?',
        content: const DialogInfoBox(
          icon: Icons.info_outline,
          text: 'Bu kişi size mesaj atabilir ve profilinizi görebilir.',
          color: Colors.blue,
        ),
        cancelText: 'İptal',
        confirmText: 'Engeli Kaldır',
        confirmButtonColor: Colors.green,
        onConfirm: () {
          HapticFeedback.mediumImpact();
          Navigator.pop(dialogContext, true);
        },
        onCancel: () => Navigator.pop(dialogContext, false),
      ),
    );

    if (confirmed == true) {
      await _unblockUser(user);
    }
  }

  Future<void> _unblockUser(UserProfile user) async {
    // Show loading
    showModernDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const PopScope(
        canPop: false,
        child: ModernLoadingDialog(
          message: 'Engel kaldırılıyor...',
          color: Colors.green,
        ),
      ),
    );

    final success = await _userService.unblockUser(user.id);

    if (mounted) {
      // Close loading dialog
      Navigator.pop(context);

      if (success) {
        // Remove from local list
        setState(() {
          _blockedUsers.removeWhere((u) => u.id == user.id);
        });

        // Kullanıcıyı local state'den temizle (filtreye takılmasın)
        ref.read(likesUIProvider.notifier).restoreUser(user.id);

        // Provider'ları invalidate et - likes listesi yenilensin
        ref.invalidate(receivedLikesProvider);

        AppNotification.unblocked(
          title: 'Engel Kaldırıldı',
          subtitle: '${user.name} artık size ulaşabilir',
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
    // Global ConnectivityBanner handles offline state - no need for per-screen banner

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
          'Engellenen Kullanicilar',
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Colors.grey[800],
          ),
        ),
      ),
      body: _isLoading
          ? _buildLoadingState()
          : _error != null
              ? _buildErrorState()
              : _blockedUsers.isEmpty
                  ? _buildEmptyState()
                  : _buildBlockedUsersList(),
    );
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
      child: Padding(
        padding: const EdgeInsets.all(32),
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
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _loadBlockedUsers,
              icon: const Icon(Icons.refresh, color: Colors.white),
              label: Text(
                'Tekrar Dene',
                style: GoogleFonts.poppins(color: Colors.white),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF5C6BC0),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
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
                color: Colors.green.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_circle_outline_rounded,
                size: 64,
                color: Colors.green,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Engellenen Kullanici Yok',
              style: GoogleFonts.poppins(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Hic kimseyi engellemediniz.\nHerkes profilinizi gorebilir.',
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
    );
  }

  Widget _buildBlockedUsersList() {
    return RefreshIndicator(
      onRefresh: _loadBlockedUsers,
      color: const Color(0xFF5C6BC0),
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: _blockedUsers.length,
        itemBuilder: (context, index) {
          final user = _blockedUsers[index];
          return _buildBlockedUserCard(user);
        },
      ),
    );
  }

  Widget _buildBlockedUserCard(UserProfile user) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
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
          // Avatar
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.red.withValues(alpha: 0.3),
                width: 2,
              ),
            ),
            child: ClipOval(
              child: user.photos.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: user.photos.first,
                      fit: BoxFit.cover,
                      cacheManager: AppCacheManager.instance,
                      placeholder: (context, url) => _buildDefaultAvatar(),
                      errorWidget: (context, url, error) => _buildDefaultAvatar(),
                    )
                  : _buildDefaultAvatar(),
            ),
          ),
          const SizedBox(width: 12),

          // Name and info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user.name,
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[800],
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Icon(Icons.block, size: 14, color: Colors.red[300]),
                    const SizedBox(width: 4),
                    Text(
                      'Engellendi',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: Colors.red[400],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Unblock button
          IconButton(
            onPressed: () {
              HapticFeedback.lightImpact();
              _showUnblockDialog(user);
            },
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.lock_open,
                color: Colors.green,
                size: 20,
              ),
            ),
            tooltip: 'Engeli Kaldir',
          ),
        ],
      ),
    );
  }

  Widget _buildDefaultAvatar() {
    return Shimmer.fromColors(
      baseColor: Colors.grey[300]!,
      highlightColor: Colors.grey[100]!,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.grey[400]!, Colors.grey[500]!],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Center(
          child: Icon(
            Icons.person_rounded,
            color: Colors.grey[400],
            size: 28,
          ),
        ),
      ),
    );
  }
}
