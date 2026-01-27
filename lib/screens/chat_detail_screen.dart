import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shimmer/shimmer.dart';
import '../widgets/app_notification.dart';
import '../widgets/report_sheet.dart';
import '../models/chat.dart';
import '../services/chat_service.dart';
import '../services/user_service.dart';
import '../services/message_cache_service.dart';
import '../providers/connectivity_provider.dart';
import '../widgets/modern_animated_dialog.dart';
import '../utils/image_helper.dart';
import 'user_profile_screen.dart';

/// ============================================================================
/// WhatsApp Mimarisi: Reverse ListView + Lazy Loading + Stable Bubble
/// ============================================================================
///
/// TEMEL PRENSİPLER:
/// 1. reverse: true - En son mesaj index 0'da, en altta görünür
/// 2. Lazy Loading - Kullanıcı yukarı kaydırdıkça (geçmişe) eski mesajlar yüklenir
/// 3. Wrap tabanlı balon - IntrinsicWidth YASAK, boyut anında hesaplanır
/// 4. Akıllı scroll - Yeni mesaj gelince otomatik scroll yok (reverse halleder)
///
/// ANTİ-FLİCKER KURALLARI:
/// - IntrinsicWidth kullanma (layout shift yaratır)
/// - Manuel scroll komutları minimum düzeyde (reverse ListView otomatik halleder)
/// - setState sadece gerçekten gerektiğinde çağrılır
/// - RepaintBoundary + AutomaticKeepAlive ile widget reuse
/// ============================================================================

class ChatDetailScreen extends ConsumerStatefulWidget {
  final String chatId;
  final String peerName;
  final String? peerImage;
  final String peerId;

  const ChatDetailScreen({
    super.key,
    required this.chatId,
    required this.peerName,
    this.peerImage,
    required this.peerId,
  });

  @override
  ConsumerState<ChatDetailScreen> createState() => _ChatDetailScreenState();
}

class _ChatDetailScreenState extends ConsumerState<ChatDetailScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  final ChatService _chatService = ChatService();
  final UserService _userService = UserService();
  final MessageCacheService _cacheService = MessageCacheService();
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();

  bool _isSending = false;
  bool _isMuted = false;
  late AnimationController _sendButtonController;
  late Animation<double> _sendButtonAnimation;

  /// Ekran aktif mi? (arka planda değilse)
  bool _isScreenActive = true;

  /// Son işlenen mesaj sayısı (yeni mesaj algılama için)
  int _lastMessageCount = 0;

  /// Önbellekten yüklenen mesajlar (anında gösterim için)
  List<Message>? _cachedMessages;

  /// Önbellek yüklendi mi?
  bool _cacheLoaded = false;

  /// Kullanıcı en altta mı? (reverse ListView için offset ~0)
  bool _isAtBottom = true;

  /// "Yeni Mesaj" butonu gösterilsin mi?
  bool _showNewMessageButton = false;

  /// Okunmamış yeni mesaj sayısı
  int _unreadNewMessageCount = 0;

  /// "Alt" sayılması için maksimum offset toleransı (px)
  static const double _bottomThreshold = 100.0;

  // =====================================================
  // LAZY LOADING (PAGİNATİON) DEĞİŞKENLERİ
  // =====================================================

  /// Pagination: Sayfa başına mesaj sayısı
  static const int _pageSize = 20;

  /// Eski mesajlar yükleniyor mu?
  bool _isLoadingMore = false;

  /// Daha fazla eski mesaj var mı?
  bool _hasMoreMessages = true;

  /// Pagination tetikleme mesafesi (maxScrollExtent'e yaklaşma)
  static const double _loadMoreThreshold = 200.0;

  // =====================================================
  // STREAM SUBSCRIPTION + GÖRSEL DONDURMA
  // =====================================================

  /// Firebase'den gelen GÜNCEL mesajlar (her zaman en son veri)
  List<Message> _firestoreMessages = [];

  /// GÖRÜNTÜLENEN mesajlar (kullanıcı yukarıdayken DONUK kalır!)
  /// Bu liste sadece şu durumlarda güncellenir:
  /// 1. Kullanıcı en alttaysa (_isAtBottom == true)
  /// 2. Kullanıcı kendi mesajını gönderdiyse
  /// 3. Kullanıcı "Yeni Mesaj" butonuna bastıysa
  /// 4. Kullanıcı manuel olarak en alta indiyse
  List<Message> _displayedMessages = [];

  /// Firebase stream subscription
  StreamSubscription<List<Message>>? _messagesSubscription;

  /// İlk veri yüklendi mi?
  bool _initialDataLoaded = false;

  /// Kullanıcı kendi mesajını mı gönderdi? (senkronizasyon için flag)
  bool _userJustSentMessage = false;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addObserver(this);

    _sendButtonController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );

    _sendButtonAnimation = Tween<double>(begin: 1.0, end: 0.9).animate(
      CurvedAnimation(parent: _sendButtonController, curve: Curves.easeInOut),
    );

    // Scroll listener: pozisyon takibi + lazy loading
    _scrollController.addListener(_onScrollPositionChanged);

    // Klavye focus listener
    _focusNode.addListener(_onFocusChanged);

    // Önbellekten yükle
    _loadCachedMessages();

    // Firebase stream'i dinle (StreamSubscription ile - rebuild önleme)
    _startListeningToMessages();

    // Mesajları okundu işaretle
    _markAllAsRead();
  }

  /// =========================================================
  /// FIREBASE STREAM DİNLEME (StreamSubscription)
  /// =========================================================
  /// StreamBuilder yerine StreamSubscription kullanarak
  /// gereksiz rebuild'leri önlüyoruz. Sadece gerçek veri
  /// değişikliğinde setState çağrılır.
  void _startListeningToMessages() {
    _messagesSubscription = _chatService.watchMessages(widget.chatId).listen(
      (messages) {
        if (!mounted) return;

        // Firebase'den veri geldi
        _initialDataLoaded = true;

        // Hive ile senkronize et (arka planda)
        if (messages.isNotEmpty) {
          _cacheService.syncMessagesFromFirestore(widget.chatId, messages);
        }

        // Yeni mesaj kontrolü ve işleme
        _processNewMessages(messages);
      },
      onError: (error) {
        debugPrint('ChatDetailScreen: Stream error: $error');
      },
    );
  }

  /// =========================================================
  /// YENİ MESAJ İŞLEME + GÖRSEL DONDURMA (V2)
  /// =========================================================
  ///
  /// GÖRSEL DONDURMA MANTIĞI:
  /// - _firestoreMessages: Her zaman Firebase'den gelen GÜNCEL veri
  /// - _displayedMessages: ListView'a verilen veri (kullanıcı yukarıdayken DONUK!)
  ///
  /// YENİ KURAL: Kullanıcı yukarıdayken (_isAtBottom == false),
  /// mesaj kimden gelirse gelsin (ben veya karşı taraf),
  /// _displayedMessages ASLA güncellenmez. Ekran kilitli kalır.
  ///
  /// Senkronizasyon SADECE şu durumlarda yapılır:
  /// 1. Kullanıcı en alttaysa (_isAtBottom == true)
  /// 2. Kullanıcı scroll ile en alta indiğinde
  /// 3. "Yeni Mesaj" butonuna basıldığında
  /// =========================================================
  void _processNewMessages(List<Message> messages) {
    // Her zaman güncel veriyi kaydet (arka plan)
    _firestoreMessages = messages;

    // İlk yükleme - her iki listeyi de doldur
    if (_displayedMessages.isEmpty && messages.isNotEmpty) {
      _lastMessageCount = messages.length;
      setState(() {
        _displayedMessages = List.from(messages);
      });
      debugPrint('ChatDetailScreen: Initial load - ${messages.length} messages');
      return;
    }

    // Mesaj yoksa
    if (messages.isEmpty) {
      if (_displayedMessages.isNotEmpty) {
        setState(() {
          _displayedMessages = [];
        });
      }
      return;
    }

    // Ekran pasifse sadece arka planda güncelle
    if (!_isScreenActive) {
      debugPrint('ChatDetailScreen: Screen inactive - background update only');
      return;
    }

    // Yeni mesaj var mı kontrol et
    final hadNewMessages = messages.length > _lastMessageCount;

    if (hadNewMessages) {
      // Yeni mesajları analiz et
      final newMessages = messages.skip(_lastMessageCount).toList();
      final newPeerMessages = newMessages
          .where((m) => m.senderId != _chatService.currentUserId)
          .toList();
      final newOwnMessages = newMessages
          .where((m) => m.senderId == _chatService.currentUserId)
          .toList();

      final hasNewPeerMessages = newPeerMessages.isNotEmpty;
      final hasNewOwnMessages = newOwnMessages.isNotEmpty;

      // ===== DURUM A: Kullanıcı en altta - normal güncelleme =====
      if (_isAtBottom) {
        debugPrint('ChatDetailScreen: User at bottom - normal update');
        _lastMessageCount = messages.length;
        _userJustSentMessage = false;

        if (hasNewPeerMessages) {
          _markAllAsRead();
        }

        setState(() {
          _displayedMessages = List.from(messages);
          _showNewMessageButton = false;
          _unreadNewMessageCount = 0;
        });
        return;
      }

      // ===== DURUM B: Kullanıcı yukarıda - GÖRSEL DONDURMA! =====
      // Mesaj kimden gelirse gelsin (ben veya karşı taraf) ekran KİLİTLİ!
      _lastMessageCount = messages.length;

      if (hasNewOwnMessages && _userJustSentMessage) {
        // Kendi mesajımız - "Yeni Mesaj" butonu gösterme, sadece scroll yap
        debugPrint('ChatDetailScreen: Own message sent while scrolled up - FREEZING (scroll will sync)');
        _userJustSentMessage = false;
        // _displayedMessages GÜNCELLENMEZ! Scroll bitince senkronize olacak
        // Buton gösterme - zaten scroll ediyoruz
        return;
      }

      if (hasNewPeerMessages) {
        // Karşı taraftan mesaj - "Yeni Mesaj" butonu göster
        debugPrint('ChatDetailScreen: Peer message while scrolled up - FREEZING + showing button');
        // _displayedMessages GÜNCELLENMEZ!
        setState(() {
          _showNewMessageButton = true;
          _unreadNewMessageCount += newPeerMessages.length;
        });
        return;
      }

      // Sadece kendi mesajımız ve _userJustSentMessage false ise
      // (Bu durum nadir - kullanıcı başka cihazdan mesaj attıysa)
      if (hasNewOwnMessages) {
        debugPrint('ChatDetailScreen: Own message from another device - FREEZING');
        // _displayedMessages GÜNCELLENMEZ!
        return;
      }
    }

    // ===== DURUM C: Mesaj sayısı aynı ama içerik değişmiş olabilir =====
    // Örn: isRead durumu değişti (gri tik -> mavi tik)
    // Kullanıcı en alttaysa içerik değişikliklerini de yansıt
    if (_isAtBottom && _displayedMessages.length == messages.length) {
      // İçerik değişikliği kontrolü (isRead durumu)
      bool hasContentChanged = false;

      if (messages.isNotEmpty && _displayedMessages.isNotEmpty) {
        // Son mesajların isRead durumunu karşılaştır
        final lastFirestore = messages.last;
        final lastDisplayed = _displayedMessages.last;

        if (lastFirestore.isRead != lastDisplayed.isRead) {
          hasContentChanged = true;
          debugPrint('ChatDetailScreen: Read status changed - ${lastDisplayed.isRead} -> ${lastFirestore.isRead}');
        }

        // Daha kapsamlı kontrol: Tüm mesajların isRead durumunu kontrol et
        // (Birden fazla mesaj aynı anda okunmuş olabilir)
        if (!hasContentChanged) {
          for (int i = 0; i < messages.length; i++) {
            if (i < _displayedMessages.length) {
              if (messages[i].isRead != _displayedMessages[i].isRead) {
                hasContentChanged = true;
                debugPrint('ChatDetailScreen: Read status changed for message at index $i');
                break;
              }
            }
          }
        }
      }

      // İçerik değiştiyse setState ile güncelle (mavi tikler görünsün)
      if (hasContentChanged) {
        setState(() {
          _displayedMessages = List.from(messages);
        });
        debugPrint('ChatDetailScreen: Content changed - UI updated (read receipts)');
      } else {
        // İçerik değişmediyse sessiz güncelleme (gereksiz rebuild önle)
        _displayedMessages = List.from(messages);
      }
    }
  }

  /// =========================================================
  /// GÖRSEL SENKRONİZASYON
  /// =========================================================
  /// "Yeni Mesaj" butonuna basınca veya kullanıcı en alta inince çağrılır.
  /// _displayedMessages'ı _firestoreMessages ile eşitler.
  void _syncDisplayedMessages() {
    if (_firestoreMessages.isEmpty) return;

    debugPrint('ChatDetailScreen: Syncing displayed messages (${_firestoreMessages.length} messages)');

    setState(() {
      _displayedMessages = List.from(_firestoreMessages);
      _showNewMessageButton = false;
      _unreadNewMessageCount = 0;
    });

    _lastMessageCount = _firestoreMessages.length;
    _markAllAsRead();
  }

  /// =========================================================
  /// SCROLL POZİSYON TAKİBİ + LAZY LOADING TETİKLEME
  /// =========================================================
  void _onScrollPositionChanged() {
    if (!_scrollController.hasClients) return;

    final offset = _scrollController.offset;
    final maxScroll = _scrollController.position.maxScrollExtent;
    final wasAtBottom = _isAtBottom;

    // Reverse ListView'da offset 0 = en alt (güncel mesajlar)
    _isAtBottom = offset <= _bottomThreshold;

    // ===== LAZY LOADING: Yukarı kaydırıldığında eski mesajları yükle =====
    // maxScrollExtent'e yaklaşınca (geçmişe doğru) pagination tetikle
    if (offset >= maxScroll - _loadMoreThreshold && !_isLoadingMore && _hasMoreMessages) {
      _loadMoreMessages();
    }

    // ===== GÖRSEL SENKRONİZASYON: Kullanıcı en alta indi =====
    // Yukarıdan aşağı indiğinde _displayedMessages'ı güncel veriyle senkronize et
    if (!wasAtBottom && _isAtBottom) {
      // Bekleyen yeni mesajlar varsa senkronize et
      if (_showNewMessageButton || _unreadNewMessageCount > 0 ||
          _displayedMessages.length != _firestoreMessages.length) {
        debugPrint('ChatDetailScreen: User scrolled to bottom - SYNCING displayed messages');
        _syncDisplayedMessages();
      }
    }
  }

  /// =========================================================
  /// LAZY LOADING: Eski mesajları yükle (Pagination)
  /// =========================================================
  ///
  /// OFFLINE-FIRST STRATEJİSİ:
  /// 1. Önce Hive cache'e bak
  /// 2. Hive'da veri biterse Firestore'dan çek (maliyet optimizasyonu)
  /// 3. Firestore'dan gelen veriyi Hive'a kaydet (gelecek için)
  ///
  /// Bu sayede kullanıcı yukarı kaydırmazsa Firestore faturalanmaz!
  /// =========================================================
  Future<void> _loadMoreMessages() async {
    if (_isLoadingMore || !_hasMoreMessages) return;

    setState(() => _isLoadingMore = true);
    debugPrint('ChatDetailScreen: Loading more messages (pagination)...');

    try {
      // Görüntülenen mesajlardan en eskisinin timestamp'ini bul
      DateTime? oldestTimestamp;
      if (_displayedMessages.isNotEmpty) {
        oldestTimestamp = _displayedMessages.first.timestamp;
      } else if (_cachedMessages != null && _cachedMessages!.isNotEmpty) {
        oldestTimestamp = _cachedMessages!.first.timestamp;
      }

      if (oldestTimestamp == null) {
        debugPrint('ChatDetailScreen: No timestamp reference - cannot load more');
        setState(() {
          _hasMoreMessages = false;
          _isLoadingMore = false;
        });
        return;
      }

      // ===== ADIM 1: Önce Hive cache'e bak =====
      final olderFromCache = await _cacheService.getCachedMessages(
        widget.chatId,
        limit: _pageSize,
        beforeTimestamp: oldestTimestamp,
      );

      if (olderFromCache != null && olderFromCache.isNotEmpty) {
        // Hive'da veri var - kullan
        debugPrint('ChatDetailScreen: Loaded ${olderFromCache.length} messages from Hive cache');

        if (mounted) {
          setState(() {
            // _displayedMessages'ın başına ekle
            _displayedMessages = [...olderFromCache, ..._displayedMessages];
            _isLoadingMore = false;

            // Hive'dan tam sayfa gelmediyse, Firestore'a düşmemiz gerekebilir
            if (olderFromCache.length < _pageSize) {
              // Bir sonraki "Load More"da Firestore'a düşecek
              debugPrint('ChatDetailScreen: Hive cache exhausted - next load will hit Firestore');
            }
          });
        }
        return;
      }

      // ===== ADIM 2: Hive boş - Firestore'dan çek =====
      debugPrint('ChatDetailScreen: Hive cache empty - fetching from Firestore...');

      final olderFromFirestore = await _chatService.loadOlderMessages(
        widget.chatId,
        beforeTimestamp: oldestTimestamp,
        limit: _pageSize,
      );

      if (mounted) {
        if (olderFromFirestore.isEmpty) {
          // Firestore'da da veri yok - gerçekten bitti
          setState(() {
            _hasMoreMessages = false;
            _isLoadingMore = false;
          });
          debugPrint('ChatDetailScreen: No more messages in Firestore - reached beginning');
        } else {
          // Firestore'dan gelen veriyi Hive'a kaydet (gelecek için)
          for (final message in olderFromFirestore) {
            await _cacheService.addOrUpdateMessage(widget.chatId, message);
          }
          debugPrint('ChatDetailScreen: Cached ${olderFromFirestore.length} messages to Hive');

          // Listeye ekle
          setState(() {
            _displayedMessages = [...olderFromFirestore, ..._displayedMessages];
            _isLoadingMore = false;

            // Tam sayfa gelmediyse daha fazla veri yok
            if (olderFromFirestore.length < _pageSize) {
              _hasMoreMessages = false;
            }
          });
          debugPrint('ChatDetailScreen: Loaded ${olderFromFirestore.length} older messages from Firestore');
        }
      }
    } catch (e) {
      debugPrint('ChatDetailScreen: Error loading more messages: $e');
      if (mounted) {
        setState(() => _isLoadingMore = false);
      }
    }
  }

  /// En alta (güncel mesajlara) kaydır
  void _scrollToBottom({bool animate = true}) {
    if (!_scrollController.hasClients) return;
    if (_scrollController.offset < 5) return;

    if (animate) {
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 150),
        curve: Curves.fastOutSlowIn,
      );
    } else {
      _scrollController.jumpTo(0);
    }
  }

  void _onFocusChanged() {
    if (_focusNode.hasFocus && !_isAtBottom && _scrollController.hasClients) {
      debugPrint('ChatDetailScreen: Focus gained while scrolled up - not forcing scroll');
    }
  }

  /// Önbellekten mesajları yükle
  Future<void> _loadCachedMessages() async {
    final cached = await _cacheService.getCachedMessages(widget.chatId, limit: _pageSize);
    if (cached != null && cached.isNotEmpty && mounted) {
      setState(() {
        _cachedMessages = cached;
        _cacheLoaded = true;
        // Eğer cache'den gelen mesaj sayısı pageSize'dan azsa, daha fazla mesaj yoktur
        if (cached.length < _pageSize) {
          _hasMoreMessages = false;
        }
      });
      debugPrint('ChatDetailScreen: Loaded ${cached.length} messages from cache');
    } else {
      setState(() => _cacheLoaded = true);
    }
  }

  @override
  void dispose() {
    // Firebase stream subscription'ı iptal et
    _messagesSubscription?.cancel();
    _messagesSubscription = null;

    WidgetsBinding.instance.removeObserver(this);
    _scrollController.removeListener(_onScrollPositionChanged);
    _focusNode.removeListener(_onFocusChanged);
    _messageController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    _sendButtonController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    if (state == AppLifecycleState.resumed) {
      debugPrint('ChatDetailScreen: App resumed - marking messages as read');
      _isScreenActive = true;
      _markAllAsRead();
    } else if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      _isScreenActive = false;
    }
  }

  Future<void> _markAllAsRead() async {
    final currentUserId = _chatService.currentUserId;
    if (currentUserId == null) return;

    await _chatService.markChatAsRead(widget.chatId);
    await _cacheService.markChatMessagesAsRead(widget.chatId, currentUserId);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      resizeToAvoidBottomInset: true,
      appBar: _buildAppBar(),
      body: MediaQuery.removeViewPadding(
        context: context,
        removeTop: false,
        removeBottom: false,
        child: Column(
          children: [
            Expanded(
              child: Stack(
                children: [
                  // ===== STATE-BASED MESAJ LİSTESİ =====
                  // StreamBuilder KALDIRILDI - Gereksiz rebuild önlendi!
                  // Mesajlar _firestoreMessages state'inden okunur
                  _buildMessageContent(),
                  _buildScrollToBottomButton(),
                ],
              ),
            ),
            _buildInputArea(),
          ],
        ),
      ),
    );
  }

  /// =========================================================
  /// MESAJ İÇERİĞİ (STATE-BASED - GEREKSİZ REBUİLD YOK)
  /// =========================================================
  Widget _buildMessageContent() {
    // Henüz veri yüklenmediyse
    if (!_initialDataLoaded) {
      // Önbellek varsa göster
      if (_cacheLoaded && _cachedMessages != null && _cachedMessages!.isNotEmpty) {
        // İlk yüklemede _displayedMessages'ı da doldur
        if (_displayedMessages.isEmpty) {
          _displayedMessages = List.from(_cachedMessages!);
        }
        return _buildMessageList(_cachedMessages!);
      }
      return _buildLoadingState();
    }

    // ===== GÖRSEL DONDURMA: _displayedMessages kullan! =====
    // _firestoreMessages yerine _displayedMessages kullanarak
    // kullanıcı yukarıdayken ekranın kaymasını önlüyoruz.
    final messages = _displayedMessages;

    // Mesaj yoksa
    if (messages.isEmpty) {
      // Ama Firebase'de mesaj varsa (henüz senkronize edilmedi)
      if (_firestoreMessages.isNotEmpty) {
        // İlk senkronizasyon
        _displayedMessages = List.from(_firestoreMessages);
        return _buildMessageList(_displayedMessages);
      }

      if (_cachedMessages != null && _cachedMessages!.isNotEmpty) {
        _cacheService.clearChatCache(widget.chatId);
        _cachedMessages = null;
      }
      return _buildEmptyMessages();
    }

    return _buildMessageList(messages);
  }

  /// =========================================================
  /// MESAJ LİSTESİ - REVERSE LISTVIEW + LAZY LOADING
  /// =========================================================
  Widget _buildMessageList(List<Message> messages) {
    // Mesajları ters çevir - en yeni mesaj index 0'da (reverse ListView için)
    final reversedMessages = messages.reversed.toList();

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: reversedMessages.length + (_isLoadingMore ? 1 : 0), // Loading indicator için +1
      reverse: true, // En alttan başla (güncel mesajlar)
      // AlwaysScrollable: Clamping bazen takılma hissi verir, bu daha akıcı
      physics: const AlwaysScrollableScrollPhysics(),
      cacheExtent: 3000.0,
      addAutomaticKeepAlives: true,
      findChildIndexCallback: (key) {
        if (key is ValueKey<String>) {
          final id = key.value;
          if (id == 'loading_indicator') return reversedMessages.length;
          final index = reversedMessages.indexWhere((m) => m.id == id);
          return index >= 0 ? index : null;
        }
        return null;
      },
      itemBuilder: (context, index) {
        // ===== LAZY LOADING INDICATOR =====
        // En üstte (index = reversedMessages.length) loading göster
        if (index == reversedMessages.length) {
          return _buildLoadingMoreIndicator();
        }

        final message = reversedMessages[index];
        final isMe = message.isFromMe(_chatService.currentUserId ?? '');

        // Tarih ayırıcı kontrolü
        bool showDateSeparator = false;
        if (index == reversedMessages.length - 1) {
          showDateSeparator = true;
        } else {
          final nextMessage = reversedMessages[index + 1];
          if (!_isSameDay(message.timestamp, nextMessage.timestamp)) {
            showDateSeparator = true;
          }
        }

        return RepaintBoundary(
          child: _ChatMessageItem(
            key: ValueKey<String>(message.id),
            message: message,
            isMe: isMe,
            showDateSeparator: showDateSeparator,
            dateSeparator: showDateSeparator ? _buildDateSeparator(message.timestamp) : null,
            bubble: _buildStableBubble(message, isMe),
          ),
        );
      },
    );
  }

  /// =========================================================
  /// LAZY LOADING INDICATOR (Yukarı kaydırırken görünür)
  /// =========================================================
  Widget _buildLoadingMoreIndicator() {
    return Container(
      key: const ValueKey<String>('loading_indicator'),
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Center(
        child: _hasMoreMessages
            ? Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF5C6BC0)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Eski mesajlar yükleniyor...',
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              )
            : Text(
                'Tüm mesajlar yüklendi',
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  color: Colors.grey[500],
                  fontStyle: FontStyle.italic,
                ),
              ),
      ),
    );
  }

  /// =========================================================
  /// STABİL MESAJ BALONU - STACK YAPISI (TİTREME %100 YOK!)
  /// =========================================================
  ///
  /// NEDEN STACK?
  /// - Stack boyutu içindeki en büyük child'a göre TEK SEFERDE hesaplanır
  /// - Render sonrası boyut değişmez = FLICKER YOK
  /// - Positioned ile saat sabit konumda "çivilenir"
  /// - IntrinsicWidth veya Wrap'ın dinamik hesaplaması YOK
  /// =========================================================
  Widget _buildStableBubble(Message message, bool isMe) {
    // Renk tanımları (Accessibility: min 4.5:1 kontrast)
    const Color readTickColor = Color(0xFF34B7F1); // WhatsApp mavi tik
    const Color unreadTickColorSent = Color(0xB3FFFFFF);
    const Color unreadTickColorReceived = Color(0xFFBDBDBD);
    const Color timestampColorSent = Color(0xB3FFFFFF);
    const Color timestampColorReceived = Color(0xFF9E9E9E);

    final Color timestampColor = isMe ? timestampColorSent : timestampColorReceived;
    final Color statusIconColor = message.isRead
        ? readTickColor
        : (isMe ? unreadTickColorSent : unreadTickColorReceived);
    final IconData statusIcon = message.isRead
        ? Icons.done_all_rounded
        : Icons.done_rounded;

    final double maxBubbleWidth = MediaQuery.of(context).size.width * 0.75;

    // Saat + tick için gereken genişlik (sabit değer)
    final double timestampWidth = isMe ? 65.0 : 50.0;

    // ===== STACK YAPISI: Boyut tek seferde hesaplanır, FLICKER YOK =====
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxBubbleWidth),
            child: Stack(
              children: [
                // ===== ZEMIN: Container + Metin =====
                // Sağ alt köşede saat için padding bırakır
                Container(
                  padding: const EdgeInsets.only(
                    left: 14,
                    right: 14,
                    top: 10,
                    bottom: 22, // Saat yüksekliği için alt boşluk
                  ),
                  decoration: BoxDecoration(
                    gradient: isMe
                        ? const LinearGradient(
                            colors: [Color(0xFF5C6BC0), Color(0xFF7986CB)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          )
                        : null,
                    color: isMe ? null : Colors.white,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(isMe ? 20 : 4),
                      topRight: Radius.circular(isMe ? 4 : 20),
                      bottomLeft: const Radius.circular(20),
                      bottomRight: const Radius.circular(20),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: isMe
                            ? const Color(0xFF5C6BC0).withValues(alpha: 0.2)
                            : Colors.black.withValues(alpha: 0.05),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: ConstrainedBox(
                    // Minimum genişlik: en az saat kadar yer kaplasın
                    constraints: BoxConstraints(minWidth: timestampWidth + 20),
                    child: Text(
                      message.text,
                      textHeightBehavior: const TextHeightBehavior(
                        applyHeightToFirstAscent: false,
                        applyHeightToLastDescent: false,
                      ),
                      style: GoogleFonts.poppins(
                        fontSize: 15,
                        color: isMe ? Colors.white : Colors.grey[850],
                        height: 1.3,
                      ),
                    ),
                  ),
                ),
                // ===== SAAT + TİCK: Positioned ile "çivilenmiş" =====
                Positioned(
                  right: 10,
                  bottom: 6,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        message.formattedTime,
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          fontWeight: FontWeight.w400,
                          color: timestampColor,
                          letterSpacing: 0.1,
                        ),
                      ),
                      if (isMe) ...[
                        const SizedBox(width: 3),
                        Icon(
                          statusIcon,
                          size: 15,
                          color: statusIconColor,
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// "Alta Dön" / "Yeni Mesaj" butonu
  Widget _buildScrollToBottomButton() {
    return AnimatedBuilder(
      animation: _scrollController,
      builder: (context, child) {
        final showButton = _scrollController.hasClients &&
            _scrollController.offset > _bottomThreshold;

        final hasNewMessages = _showNewMessageButton && _unreadNewMessageCount > 0;

        return Positioned(
          right: 16,
          bottom: 16,
          child: AnimatedScale(
            scale: showButton ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutBack,
            child: AnimatedOpacity(
              opacity: showButton ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 150),
              child: GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();

                  // ===== GÖRSEL SENKRONİZASYON: Butona basınca =====
                  // _displayedMessages'ı güncel veriyle senkronize et
                  _syncDisplayedMessages();

                  // Pürüzsüz scroll ile en alta in
                  _scrollToBottom(animate: true);
                },
                child: hasNewMessages
                    ? Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF5C6BC0), Color(0xFF7986CB)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF5C6BC0).withValues(alpha: 0.45),
                              blurRadius: 16,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.25),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                _unreadNewMessageCount > 99 ? '99+' : '$_unreadNewMessageCount',
                                style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Yeni Mesaj',
                              style: GoogleFonts.poppins(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(width: 4),
                            const Icon(
                              Icons.keyboard_arrow_down_rounded,
                              color: Colors.white,
                              size: 20,
                            ),
                          ],
                        ),
                      )
                    : Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.95),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF5C6BC0).withValues(alpha: 0.35),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.keyboard_arrow_down_rounded,
                          color: Color(0xFF5C6BC0),
                          size: 28,
                        ),
                      ),
              ),
            ),
          ),
        );
      },
    );
  }

  bool _isSameDay(DateTime date1, DateTime date2) {
    return date1.year == date2.year &&
        date1.month == date2.month &&
        date1.day == date2.day;
  }

  Widget _buildDateSeparator(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final messageDate = DateTime(date.year, date.month, date.day);
    final yesterday = today.subtract(const Duration(days: 1));

    String dateText;

    if (messageDate == today) {
      dateText = 'Bugün';
    } else if (messageDate == yesterday) {
      dateText = 'Dün';
    } else {
      final weekdays = ['Pazartesi', 'Salı', 'Çarşamba', 'Perşembe', 'Cuma', 'Cumartesi', 'Pazar'];
      final months = ['Oca', 'Şub', 'Mar', 'Nis', 'May', 'Haz', 'Tem', 'Ağu', 'Eyl', 'Eki', 'Kas', 'Ara'];

      if (today.difference(messageDate).inDays < 7) {
        dateText = weekdays[date.weekday - 1];
      } else {
        dateText = '${date.day} ${months[date.month - 1]} ${date.year}';
      }
    }

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 16),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.grey[300],
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            dateText,
            style: GoogleFonts.poppins(
              fontSize: 12,
              color: Colors.grey[700],
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 1,
      shadowColor: Colors.black.withValues(alpha: 0.1),
      leading: IconButton(
        icon: const Icon(
          Icons.arrow_back_ios_rounded,
          color: Color(0xFF5C6BC0),
        ),
        onPressed: () => Navigator.pop(context),
      ),
      titleSpacing: 0,
      title: GestureDetector(
        onTap: _viewProfile,
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: const Color(0xFF5C6BC0).withValues(alpha: 0.3),
                  width: 2,
                ),
              ),
              child: widget.peerImage != null && widget.peerImage!.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: widget.peerImage!,
                      width: 40,
                      height: 40,
                      cacheManager: AppCacheManager.instance,
                      imageBuilder: (context, imageProvider) => Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          image: DecorationImage(
                            image: imageProvider,
                            fit: BoxFit.cover, // Oranı bozmadan kırpar
                          ),
                        ),
                      ),
                      placeholder: (context, url) => _buildDefaultAvatar(),
                      errorWidget: (context, url, error) => _buildDefaultAvatar(),
                    )
                  : _buildDefaultAvatar(),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.peerName,
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[800],
                      letterSpacing: 0.2,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        IconButton(
          icon: const Icon(
            Icons.more_vert_rounded,
            color: Colors.grey,
          ),
          onPressed: _showOptionsMenu,
        ),
      ],
    );
  }

  Widget _buildDefaultAvatar() {
    return Shimmer.fromColors(
      baseColor: const Color(0xFF5C6BC0),
      highlightColor: const Color(0xFF7986CB),
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF5C6BC0), Color(0xFF7986CB)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: const Center(
          child: Icon(
            Icons.person_rounded,
            color: Colors.white70,
            size: 24,
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return const Center(
      child: CircularProgressIndicator(
        valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF5C6BC0)),
      ),
    );
  }

  Widget _buildEmptyMessages() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
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
                Icons.waving_hand_rounded,
                size: 64,
                color: Color(0xFF5C6BC0),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Yeni Baglanti!',
              style: GoogleFonts.poppins(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${widget.peerName} ile baglanti kurdunuz!\nIlk mesaji gonder ve sohbete basla.',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 15,
                color: Colors.grey[600],
                height: 1.5,
              ),
            ),
            const SizedBox(height: 24),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [
                _buildSuggestionChip('Merhaba!'),
                _buildSuggestionChip('Nasilsin?'),
                _buildSuggestionChip('Tanisalim mi?'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSuggestionChip(String text) {
    return GestureDetector(
      onTap: () {
        _messageController.text = text;
        _sendMessage();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF5C6BC0), Color(0xFF7986CB)],
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF5C6BC0).withValues(alpha: 0.3),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Text(
          text,
          style: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  Widget _buildInputArea() {
    final isOnline = ref.watch(isOnlineProvider);

    return Container(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 12,
        bottom: MediaQuery.of(context).padding.bottom + 12,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!isOnline)
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.wifi_off_rounded, size: 14, color: Colors.red),
                  const SizedBox(width: 6),
                  Text(
                    'Çevrimdışı - Mesaj gönderilemez',
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: Colors.red,
                    ),
                  ),
                ],
              ),
            ),
          Row(
            children: [
              Expanded(
                child: AnimatedOpacity(
                  opacity: isOnline ? 1.0 : 0.6,
                  duration: const Duration(milliseconds: 300),
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFFF5F5F5),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: !isOnline
                            ? Colors.red.withValues(alpha: 0.3)
                            : _focusNode.hasFocus
                                ? const Color(0xFF5C6BC0).withValues(alpha: 0.5)
                                : Colors.transparent,
                        width: 2,
                      ),
                    ),
                    child: Row(
                      children: [
                        IconButton(
                          icon: const Icon(
                            Icons.emoji_emotions_outlined,
                            color: Colors.grey,
                            size: 24,
                          ),
                          onPressed: () {
                            // TODO: Emoji picker
                          },
                        ),
                        Expanded(
                          child: TextField(
                            controller: _messageController,
                            focusNode: _focusNode,
                            textCapitalization: TextCapitalization.sentences,
                            maxLines: 4,
                            minLines: 1,
                            enabled: isOnline,
                            style: GoogleFonts.poppins(
                              fontSize: 15,
                              color: Colors.grey[800],
                            ),
                            decoration: InputDecoration(
                              hintText: isOnline ? 'Mesaj yaz...' : 'Bağlantı bekleniyor...',
                              hintStyle: GoogleFonts.poppins(
                                fontSize: 15,
                                color: Colors.grey[400],
                              ),
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(
                                vertical: 10,
                              ),
                            ),
                            onSubmitted: (_) => _sendMessage(),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.attach_file_rounded,
                            color: Colors.grey,
                            size: 24,
                          ),
                          onPressed: () {
                            // TODO: Attachment picker
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              ScaleTransition(
                scale: _sendButtonAnimation,
                child: GestureDetector(
                  onTapDown: (_) => _sendButtonController.forward(),
                  onTapUp: (_) {
                    _sendButtonController.reverse();
                    _sendMessage();
                  },
                  onTapCancel: () => _sendButtonController.reverse(),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: isOnline
                            ? [const Color(0xFF5C6BC0), const Color(0xFF7986CB)]
                            : [Colors.grey[400]!, Colors.grey[500]!],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: isOnline
                              ? const Color(0xFF5C6BC0).withValues(alpha: 0.4)
                              : Colors.grey.withValues(alpha: 0.3),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: _isSending
                        ? const Padding(
                            padding: EdgeInsets.all(12),
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : Icon(
                            isOnline ? Icons.send_rounded : Icons.wifi_off_rounded,
                            color: Colors.white,
                            size: 22,
                          ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _isSending) return;

    final isOnline = ref.read(isOnlineProvider);
    if (!isOnline) {
      HapticFeedback.heavyImpact();
      _showOfflineWarning();
      return;
    }

    setState(() => _isSending = true);
    HapticFeedback.lightImpact();

    _messageController.clear();

    // ===== GÖRSEL SENKRONİZASYON: Kendi mesajımız için flag =====
    // Bu flag, _processNewMessages'ta listeyi güncellemesini sağlar
    _userJustSentMessage = true;
    _showNewMessageButton = false;
    _unreadNewMessageCount = 0;

    final success = await _chatService.sendMessage(
      chatId: widget.chatId,
      text: text,
    );

    if (success) {
      debugPrint('ChatDetailScreen: Message sent successfully');

      // ===== GÖRSEL DONDURMA: Önce scroll, sonra senkronizasyon =====
      // Ekran milim oynamadan önce mevcut listenin en altına kaydır,
      // scroll bittiğinde senkronize et ve yeni mesaj görünsün.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients && mounted) {
          _scrollController.animateTo(
            0, // En alt (reverse list olduğu için 0)
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          ).then((_) {
            // Scroll animasyonu bitti - şimdi senkronize et
            if (mounted) {
              debugPrint('ChatDetailScreen: Scroll complete - syncing displayed messages');
              _syncDisplayedMessages();
            }
          });
        }
      });
    } else {
      _messageController.text = text;
      if (mounted) {
        AppNotification.error(
          title: 'Mesaj gönderilemedi',
          subtitle: 'Lütfen tekrar deneyin',
        );
      }
    }

    setState(() => _isSending = false);
  }

  void _showOfflineWarning() {
    showModernDialog(
      context: context,
      builder: (dialogContext) => ModernAnimatedDialog(
        type: DialogType.warning,
        icon: Icons.wifi_off_rounded,
        title: 'Bağlantı Yok',
        subtitle: 'İnternet bağlantınız olmadan mesaj gönderemezsiniz.\n\nLütfen bağlantınızı kontrol edip tekrar deneyin.',
        confirmText: 'Tamam',
        confirmButtonColor: const Color(0xFF5C6BC0),
        onConfirm: () => Navigator.pop(dialogContext),
      ),
    );
  }

  void _showOptionsMenu() {
    HapticFeedback.mediumImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 20,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
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
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
              child: Text(
                widget.peerName,
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[800],
                ),
              ),
            ),

            // Notification option
            _buildModernOptionItem(
              icon: _isMuted
                  ? Icons.notifications_active_outlined
                  : Icons.notifications_off_outlined,
              label: _isMuted ? 'Bildirimleri Ac' : 'Bildirimleri Sessize Al',
              subtitle: _isMuted ? 'Bildirimler kapalı' : 'Bildirimler acik',
              color: const Color(0xFF5C6BC0),
              onTap: () {
                Navigator.pop(context);
                _toggleMuteNotifications();
              },
            ),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Divider(color: Colors.grey[200], height: 1),
            ),

            // Clear chat option
            _buildModernOptionItem(
              icon: Icons.cleaning_services_rounded,
              label: 'Sohbeti Temizle',
              subtitle: 'Tum mesajlari sil',
              color: Colors.orange,
              onTap: () {
                Navigator.pop(context);
                _showClearChatDialog();
              },
            ),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Divider(color: Colors.grey[200], height: 1),
            ),

            // Report option
            _buildModernOptionItem(
              icon: Icons.flag_rounded,
              label: 'Sikayet Et',
              subtitle: 'Uygunsuz davranis bildir',
              color: Colors.orange,
              onTap: () {
                Navigator.pop(context);
                _showModernReportSheet();
              },
            ),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Divider(color: Colors.grey[200], height: 1),
            ),

            // Block option
            _buildModernOptionItem(
              icon: Icons.block_rounded,
              label: 'Engelle',
              subtitle: 'Bu kisiyi bir daha gorme',
              color: Colors.red,
              onTap: () {
                Navigator.pop(context);
                _showBlockDialog();
              },
            ),

            const SizedBox(height: 12),

            // Cancel button
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    Navigator.pop(context);
                  },
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    backgroundColor: Colors.grey[100],
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: Text(
                    'Iptal',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey[700],
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

  /// Modern option item for the options menu
  Widget _buildModernOptionItem({
    required IconData icon,
    required String label,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          HapticFeedback.mediumImpact();
          onTap();
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Row(
            children: [
              // Icon
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(width: 16),
              // Text
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: color,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        color: Colors.grey[500],
                      ),
                    ),
                  ],
                ),
              ),
              // Arrow
              Icon(
                Icons.chevron_right_rounded,
                color: Colors.grey[400],
                size: 24,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Modern raporlama bottom sheet göster
  void _showModernReportSheet() {
    ReportBottomSheet.show(
      context: context,
      userName: widget.peerName,
      onSubmit: (reason, description) => _submitReport(reason, description),
    );
  }

  /// Raporu gönder (eski _reportUser fonksiyonunun yerine)
  Future<void> _submitReport(String reason, String description) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF5C6BC0)),
        ),
      ),
    );

    // Apple UGC compliance: Report + otomatik engelleme
    final result = await _userService.reportAndBlockUser(
      targetUserId: widget.peerId,
      reason: reason,
      description: description.isNotEmpty ? description : null,
      chatId: widget.chatId,
    );

    if (mounted) {
      Navigator.pop(context);

      if (result.success) {
        // Apple UGC mesajı: 24 saat içinde incelenecek + otomatik engelleme bildirimi
        AppNotification.success(
          title: 'Sikayetiniz Alindi',
          subtitle: '24 saat icinde incelenecektir. Guvenliginiz icin bu kullanici engellendi.',
          duration: const Duration(seconds: 5),
        );

        // Sohbet ekranından çık (kullanıcı engellendi)
        if (mounted) {
          Navigator.of(context).popUntil((route) => route.isFirst);
        }
      } else {
        AppNotification.error(
          title: 'Hata Olustu',
          subtitle: 'Sikayet gonderilemedi. Lutfen tekrar deneyin.',
          duration: const Duration(seconds: 4),
        );
      }
    }
  }

  void _viewProfile() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => UserProfileScreen(
          userId: widget.peerId,
          onUserBlocked: (blockedUserId) {
            Navigator.of(context).popUntil((route) => route.isFirst);
          },
        ),
      ),
    );
  }

  void _toggleMuteNotifications() {
    setState(() {
      _isMuted = !_isMuted;
    });

    AppNotification.info(
      title: _isMuted ? 'Sohbet sessize alındı' : 'Bildirimler açıldı',
      subtitle: _isMuted ? 'Bu sohbetten bildirim almayacaksınız' : 'Bu sohbetin bildirimleri açık',
    );
  }

  void _showClearChatDialog() {
    showModernDialog(
      context: context,
      builder: (dialogContext) => ModernAnimatedDialog(
        type: DialogType.warning,
        icon: Icons.cleaning_services_rounded,
        title: 'Sohbeti Temizle',
        subtitle: 'Bu sohbet geçmişi kalıcı olarak silinecek. Bu işlem geri alınamaz.',
        cancelText: 'İptal',
        confirmText: 'Temizle',
        confirmButtonColor: Colors.orange,
        onConfirm: () async {
          HapticFeedback.mediumImpact();
          Navigator.pop(dialogContext);
          await _clearChat();
        },
      ),
    );
  }

  Future<void> _clearChat() async {
    try {
      await _chatService.clearChat(widget.chatId);
      if (mounted) {
        Navigator.pop(context);
        AppNotification.success(
          title: 'Sohbet Temizlendi',
          subtitle: '${widget.peerName} ile sohbet geçmişi silindi',
        );
      }
    } catch (e) {
      if (mounted) {
        AppNotification.error(
          title: 'Hata Oluştu',
          subtitle: 'Sohbet temizlenemedi. Lütfen tekrar deneyin.',
        );
      }
    }
  }

  void _showBlockDialog() {
    showModernDialog(
      context: context,
      builder: (dialogContext) => ModernAnimatedDialog(
        type: DialogType.danger,
        icon: Icons.block_rounded,
        title: 'Kullanıcıyı Engelle',
        subtitle: '${widget.peerName} adlı kullanıcıyı engellemek istediğinize emin misiniz?',
        content: const DialogInfoBox(
          icon: Icons.warning_amber_rounded,
          text: 'Bu kişi size mesaj atamaz ve profilinizi göremez.',
          color: Colors.orange,
        ),
        cancelText: 'İptal',
        confirmText: 'Engelle',
        onConfirm: () async {
          HapticFeedback.mediumImpact();
          Navigator.pop(dialogContext);
          await _blockUser();
        },
      ),
    );
  }

  Future<void> _blockUser() async {
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

    final success = await _userService.blockUser(widget.peerId);

    if (mounted) {
      Navigator.pop(context);

      if (success) {
        AppNotification.blocked(
          title: 'Kullanıcı Engellendi',
          subtitle: '${widget.peerName} artık size ulaşamaz',
        );
        Navigator.pop(context);
      } else {
        AppNotification.error(
          title: 'Engelleme başarısız oldu',
          subtitle: 'Lütfen tekrar deneyin',
        );
      }
    }
  }

}

/// ============================================================================
/// STABLE MESSAGE ITEM - AutomaticKeepAlive ile Flicker Önleme
/// ============================================================================
class _ChatMessageItem extends StatefulWidget {
  final Message message;
  final bool isMe;
  final bool showDateSeparator;
  final Widget? dateSeparator;
  final Widget bubble;

  const _ChatMessageItem({
    super.key,
    required this.message,
    required this.isMe,
    required this.showDateSeparator,
    this.dateSeparator,
    required this.bubble,
  });

  @override
  State<_ChatMessageItem> createState() => _ChatMessageItemState();
}

class _ChatMessageItemState extends State<_ChatMessageItem>
    with AutomaticKeepAliveClientMixin {

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return Column(
      children: [
        if (widget.showDateSeparator && widget.dateSeparator != null)
          widget.dateSeparator!,
        widget.bubble,
      ],
    );
  }
}
