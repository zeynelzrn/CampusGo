import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shimmer/shimmer.dart';
import '../widgets/app_notification.dart';
import '../models/chat.dart';
import '../services/chat_service.dart';
import '../services/user_service.dart';
import '../widgets/modern_animated_dialog.dart';
import 'chat_detail_screen.dart';
import 'main_screen.dart';

class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen>
    with RouteAware, AutomaticKeepAliveClientMixin<ChatListScreen> {
  final ChatService _chatService = ChatService();
  final UserService _userService = UserService();

  // Swipe action için açık olan chat id'si - ValueNotifier ile rebuild önlenir
  final ValueNotifier<String?> _openSwipeActionChatId = ValueNotifier(null);

  // Animasyon sadece ilk yüklemede çalışsın
  bool _initialLoadComplete = false;

  // Chat tab index'i (MainScreen'deki sıralama)
  static const int _chatTabIndex = 3;

  // OPTIMIZATION: Stream'leri initState'de oluştur, rebuild'de yeniden oluşturma
  late final Stream<Set<String>> _restrictedUsersStream;
  late final Stream<List<Chat>> _chatsStream;
  late final Stream<int> _unreadCountStream;

  @override
  bool get wantKeepAlive => true; // Tab değişiminde state'i koru

  @override
  void initState() {
    super.initState();

    // OPTIMIZATION: Stream'leri bir kez oluştur ve cache'le
    _restrictedUsersStream = _userService.watchAllRestrictedUserIds();
    _chatsStream = _chatService.watchChats();
    _unreadCountStream = _chatService.watchUnreadCount();

    // Tab değişikliğini dinle - başka tab'a geçildiğinde swipe'ı kapat
    MainScreen.currentTabNotifier.addListener(_onTabChanged);
  }

  void _onTabChanged() {
    // Chat tab'ından ayrıldığında tüm swipe action'ları kapat
    if (MainScreen.currentTabNotifier.value != _chatTabIndex) {
      _openSwipeActionChatId.value = null;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Route observer'a kayıt ol
    final route = ModalRoute.of(context);
    if (route is PageRoute) {
      RouteObserver<PageRoute>? observer;
      try {
        observer = Navigator.of(context).widget.observers
            .whereType<RouteObserver<PageRoute>>()
            .firstOrNull;
        observer?.subscribe(this, route);
      } catch (_) {}
    }
  }

  @override
  void didPopNext() {
    // Başka sayfadan geri dönüldüğünde sil butonunu kapat
    _openSwipeActionChatId.value = null;
  }

  @override
  void dispose() {
    MainScreen.currentTabNotifier.removeListener(_onTabChanged);
    _openSwipeActionChatId.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // CRITICAL: AutomaticKeepAliveClientMixin için super.build çağrılmalı
    super.build(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              // OPTIMIZATION: RepaintBoundary ile liste güncellemelerini izole et
              child: RepaintBoundary(
                child: StreamBuilder<Set<String>>(
                  // OPTIMIZATION: Cached stream kullan - her build'de yeniden oluşturma
                  stream: _restrictedUsersStream,
                  builder: (context, restrictedSnapshot) {
                    final restrictedIds = restrictedSnapshot.data ?? <String>{};

                    return StreamBuilder<List<Chat>>(
                      // OPTIMIZATION: Cached stream kullan
                      stream: _chatsStream,
                      builder: (context, chatSnapshot) {
                        if (chatSnapshot.connectionState == ConnectionState.waiting &&
                            !chatSnapshot.hasData) {
                          return _buildLoadingState();
                        }

                        if (chatSnapshot.hasError) {
                          final error = chatSnapshot.error;
                          debugPrint('========== CHAT ERROR ==========');
                          debugPrint('Error Type: ${error.runtimeType}');
                          debugPrint('Error Message: $error');
                          debugPrint('Stack Trace: ${chatSnapshot.stackTrace}');
                          debugPrint('=================================');

                          final errorStr = error.toString();
                          if (errorStr.contains('index') || errorStr.contains('Index')) {
                            debugPrint('>>> COMPOSITE INDEX GEREKIYOR! <<<');
                            debugPrint('Firebase Console\'da index olusturun veya asagidaki linke tiklayin.');
                          }
                          if (errorStr.contains('permission') || errorStr.contains('Permission')) {
                            debugPrint('>>> PERMISSION DENIED! Firestore Rules kontrol edin. <<<');
                          }

                          return _buildErrorState(errorStr);
                        }

                        final allChats = chatSnapshot.data ?? [];

                        // Filter out ALL restricted users (BLACKLIST)
                        final chats = allChats.where((chat) {
                          final isRestricted = restrictedIds.contains(chat.peerId);
                          return !isRestricted;
                        }).toList();

                        if (chats.isEmpty) {
                          return _buildEmptyState();
                        }

                        // İlk yükleme tamamlandı
                        if (!_initialLoadComplete) {
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            if (mounted) {
                              setState(() {
                                _initialLoadComplete = true;
                              });
                            }
                          });
                        }

                        return _buildChatList(chats);
                      },
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return RepaintBoundary(
      child: Container(
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
                Icons.chat_bubble_rounded,
                color: Colors.white,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Sohbetler',
                    style: GoogleFonts.poppins(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[800],
                    ),
                  ),
                  StreamBuilder<int>(
                    // OPTIMIZATION: Cached stream kullan
                    stream: _unreadCountStream,
                    builder: (context, snapshot) {
                      final unreadCount = snapshot.data ?? 0;
                      return Text(
                        unreadCount > 0
                            ? '$unreadCount okunmamis mesaj'
                            : 'Tum mesajlar okundu',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          color: unreadCount > 0
                              ? const Color(0xFF5C6BC0)
                              : Colors.grey[600],
                          fontWeight:
                              unreadCount > 0 ? FontWeight.w600 : FontWeight.normal,
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: 5,
      itemBuilder: (context, index) => _buildShimmerCard(),
    );
  }

  Widget _buildShimmerCard() {
    return Shimmer.fromColors(
      baseColor: Colors.grey[300]!,
      highlightColor: Colors.grey[100]!,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 120,
                    height: 16,
                    color: Colors.white,
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: 200,
                    height: 12,
                    color: Colors.white,
                  ),
                ],
              ),
            ),
          ],
        ),
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
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.error_outline_rounded,
                size: 64,
                color: Colors.red,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Bir hata olustu',
              style: GoogleFonts.poppins(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Sohbetler yuklenirken bir sorun olustu.\nLutfen tekrar deneyin.',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: Colors.grey[600],
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
            // Animated empty state icon
            TweenAnimationBuilder<double>(
              duration: const Duration(milliseconds: 800),
              tween: Tween(begin: 0.8, end: 1.0),
              builder: (context, scale, child) {
                return Transform.scale(
                  scale: scale,
                  child: Container(
                    padding: const EdgeInsets.all(32),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          const Color(0xFF5C6BC0).withValues(alpha: 0.15),
                          const Color(0xFF7986CB).withValues(alpha: 0.1),
                        ],
                      ),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.chat_bubble_outline_rounded,
                      size: 80,
                      color: Color(0xFF5C6BC0),
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 32),
            Text(
              'Henuz sohbetin yok',
              style: GoogleFonts.poppins(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Kesif sayfasindan yeni kisilerle\ntanismaya basla!',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 16,
                color: Colors.grey[600],
                height: 1.5,
              ),
            ),
            const SizedBox(height: 32),
            _buildHowItWorksCard(),
          ],
        ),
      ),
    );
  }

  Widget _buildHowItWorksCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF5C6BC0).withValues(alpha: 0.1),
            const Color(0xFF7986CB).withValues(alpha: 0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.handshake_rounded,
              color: Color(0xFF5C6BC0),
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Nasil calisir?',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[800],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Iki kisi birbirine selam verdikten sonra baglanti kurulur ve sohbet edebilirsiniz!',
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    color: Colors.grey[600],
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChatList(List<Chat> chats) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: chats.length,
      // OPTIMIZATION: Önceden render et ve cache'le
      addAutomaticKeepAlives: true,
      cacheExtent: 500, // Görünür alanın dışında 500px cache'le
      itemBuilder: (context, index) {
        final chat = chats[index];
        return _buildChatCard(chat, index);
      },
    );
  }

  Widget _buildChatCard(Chat chat, int index) {
    final currentUserId = _chatService.currentUserId ?? '';
    final hasUnread = chat.hasUnreadFor(currentUserId);

    final cardWidget = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: _SwipeableChatCard(
        chat: chat,
        hasUnread: hasUnread,
        openChatIdNotifier: _openSwipeActionChatId,
        onTap: () => _openChatDetail(chat),
        onDelete: () => _showDeleteConfirmDialog(chat),
        buildAvatar: () => _buildAvatar(chat),
      ),
    );

    // Animasyon sadece ilk yüklemede çalışsın
    if (_initialLoadComplete) {
      return cardWidget;
    }

    return TweenAnimationBuilder<double>(
      duration: Duration(milliseconds: 300 + (index * 50)),
      tween: Tween(begin: 0.0, end: 1.0),
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 20 * (1 - value)),
            child: child,
          ),
        );
      },
      child: cardWidget,
    );
  }

  void _showDeleteConfirmDialog(Chat chat) {
    // Önce swipe action'ı kapat
    _openSwipeActionChatId.value = null;

    showModernDialog(
      context: context,
      builder: (dialogContext) => ModernAnimatedDialog(
        type: DialogType.danger,
        icon: Icons.delete_outline_rounded,
        title: 'Sohbeti Sil',
        subtitle: '${chat.peerName} ile olan sohbeti silmek istediğinize emin misiniz?',
        content: const DialogInfoBox(
          icon: Icons.info_outline_rounded,
          text: 'Bu kişi size tekrar mesaj atarsa yeni bir sohbet oluşacaktır.',
          color: Colors.orange,
        ),
        cancelText: 'İptal',
        confirmText: 'Sil',
        onConfirm: () async {
          HapticFeedback.mediumImpact();
          Navigator.pop(dialogContext);
          await _deleteChat(chat);
        },
      ),
    );
  }

  Future<void> _deleteChat(Chat chat) async {
    final success = await _chatService.deleteChat(chat.id);

    if (success) {
      AppNotification.success(
        title: 'Sohbet Silindi',
        subtitle: '${chat.peerName} ile sohbet kaldırıldı',
      );
    } else {
      AppNotification.error(
        title: 'Hata Oluştu',
        subtitle: 'Sohbet silinemedi. Lütfen tekrar deneyin.',
      );
    }
  }

  Widget _buildAvatar(Chat chat) {
    return Container(
      width: 60,
      height: 60,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: chat.hasUnreadFor(_chatService.currentUserId ?? '')
              ? const Color(0xFF5C6BC0)
              : Colors.grey[200]!,
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF5C6BC0).withValues(alpha: 0.2),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipOval(
        child: chat.peerImage != null && chat.peerImage!.isNotEmpty
            ? CachedNetworkImage(
                imageUrl: chat.peerImage!,
                fit: BoxFit.cover,
                placeholder: (context, url) => Container(
                  color: Colors.grey[200],
                  child: const Center(
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor:
                          AlwaysStoppedAnimation<Color>(Color(0xFF5C6BC0)),
                    ),
                  ),
                ),
                errorWidget: (context, url, error) => _buildDefaultAvatar(),
              )
            : _buildDefaultAvatar(),
      ),
    );
  }

  Widget _buildDefaultAvatar() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF5C6BC0), Color(0xFF7986CB)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: const Icon(
        Icons.person_rounded,
        color: Colors.white,
        size: 32,
      ),
    );
  }

  void _openChatDetail(Chat chat) {
    // Swipe action'ı kapat (setState yok, sadece ValueNotifier)
    _openSwipeActionChatId.value = null;

    // Context kontrolü
    if (!mounted) return;

    // Mark as read - fire and forget (await yok, UI bloklama yok)
    _chatService.markChatAsRead(chat.id);

    // DÜZELTME: rootNavigator kullan (Tab yapısı içinde olduğumuz için)
    // addPostFrameCallback kaldırıldı - navigasyonu geciktirip kilitlemeye neden oluyordu
    Navigator.of(context, rootNavigator: true).push(
      CupertinoPageRoute(
        builder: (_) => ChatDetailScreen(
          chatId: chat.id,
          peerName: chat.peerName,
          peerImage: chat.peerImage,
          peerId: chat.peerId,
        ),
      ),
    );
  }
}

/// Swipeable Chat Card - Kendi animasyon state'ini yöneten widget
class _SwipeableChatCard extends StatefulWidget {
  final Chat chat;
  final bool hasUnread;
  final ValueNotifier<String?> openChatIdNotifier;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final Widget Function() buildAvatar;

  const _SwipeableChatCard({
    required this.chat,
    required this.hasUnread,
    required this.openChatIdNotifier,
    required this.onTap,
    required this.onDelete,
    required this.buildAvatar,
  });

  @override
  State<_SwipeableChatCard> createState() => _SwipeableChatCardState();
}

class _SwipeableChatCardState extends State<_SwipeableChatCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  static const double _maxSlide = 80;

  bool get _isOpen => widget.openChatIdNotifier.value == widget.chat.id;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );

    // Başlangıçta açık mı kontrol et
    if (_isOpen) {
      _controller.value = 1.0;
    }

    // ValueNotifier'ı dinle
    widget.openChatIdNotifier.addListener(_onOpenChatIdChanged);
  }

  void _onOpenChatIdChanged() {
    if (_isOpen && _controller.value < 1.0) {
      _controller.forward();
    } else if (!_isOpen && _controller.value > 0.0) {
      _controller.reverse();
    }
  }

  @override
  void dispose() {
    widget.openChatIdNotifier.removeListener(_onOpenChatIdChanged);
    _controller.dispose();
    super.dispose();
  }

  void _onHorizontalDragEnd(DragEndDetails details) {
    final velocity = details.primaryVelocity ?? 0;

    // Hızlı sola kaydırma
    if (velocity < -300) {
      _controller.forward();
      widget.openChatIdNotifier.value = widget.chat.id;
      return;
    }

    // Hızlı sağa kaydırma
    if (velocity > 300) {
      _controller.reverse();
      if (_isOpen) widget.openChatIdNotifier.value = null;
      return;
    }

    // Yavaş kaydırma - yarıdan fazlaysa aç
    if (_controller.value > 0.5) {
      _controller.forward();
      widget.openChatIdNotifier.value = widget.chat.id;
    } else {
      _controller.reverse();
      if (_isOpen) widget.openChatIdNotifier.value = null;
    }
  }

  void _onHorizontalDragUpdate(DragUpdateDetails details) {
    final delta = details.primaryDelta ?? 0;
    _controller.value -= delta / _maxSlide;
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: SizedBox(
        height: 84,
        child: Stack(
          children: [
            // Delete button (arkada, sabit)
            Positioned(
              right: 0,
              top: 0,
              bottom: 0,
              width: _maxSlide,
              child: GestureDetector(
                onTap: () {
                  HapticFeedback.mediumImpact();
                  widget.onDelete();
                },
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.red.shade300,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.delete_outline_rounded,
                        color: Colors.white,
                        size: 26,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Sil',
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            // Chat card (önde, kaydırılabilir)
            RepaintBoundary(
              child: ListenableBuilder(
                listenable: _controller,
                builder: (context, child) {
                  return Transform.translate(
                    offset: Offset(-_maxSlide * _controller.value, 0),
                    child: child,
                  );
                },
                child: GestureDetector(
                  onHorizontalDragUpdate: _onHorizontalDragUpdate,
                  onHorizontalDragEnd: _onHorizontalDragEnd,
                  onTap: () {
                    if (_controller.value > 0) {
                      _controller.reverse();
                      widget.openChatIdNotifier.value = null;
                    } else {
                      widget.onTap();
                    }
                  },
                  child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: widget.hasUnread
                        ? const Color(0xFFFFF0F3)
                        : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: widget.hasUnread
                        ? Border.all(
                            color:
                                const Color(0xFF5C6BC0).withValues(alpha: 0.3),
                            width: 1,
                          )
                        : null,
                    boxShadow: [
                      BoxShadow(
                        color: widget.hasUnread
                            ? const Color(0xFF5C6BC0).withValues(alpha: 0.1)
                            : Colors.black.withValues(alpha: 0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      // Profile photo
                      widget.buildAvatar(),
                      const SizedBox(width: 12),

                      // Name and last message
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    widget.chat.peerName,
                                    style: GoogleFonts.poppins(
                                      fontSize: 16,
                                      fontWeight: widget.hasUnread
                                          ? FontWeight.bold
                                          : FontWeight.w600,
                                      color: Colors.grey[800],
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (widget.hasUnread)
                                  Container(
                                    margin: const EdgeInsets.only(left: 8),
                                    width: 10,
                                    height: 10,
                                    decoration: const BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [
                                          Color(0xFF5C6BC0),
                                          Color(0xFF7986CB)
                                        ],
                                      ),
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              widget.chat.lastMessage ??
                                  'Yeni esleme! Merhaba de!',
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                color: widget.hasUnread
                                    ? Colors.grey[800]
                                    : Colors.grey[500],
                                fontWeight: widget.hasUnread
                                    ? FontWeight.w500
                                    : FontWeight.normal,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),

                      // Time and arrow
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            widget.chat.formattedTime,
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              color: widget.hasUnread
                                  ? const Color(0xFF5C6BC0)
                                  : Colors.grey[400],
                              fontWeight: widget.hasUnread
                                  ? FontWeight.w600
                                  : FontWeight.normal,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Icon(
                            Icons.chevron_right_rounded,
                            color: widget.hasUnread
                                ? const Color(0xFF5C6BC0)
                                : Colors.grey[400],
                            size: 24,
                          ),
                        ],
                      ),
                    ],
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
