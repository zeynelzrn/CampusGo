import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/connectivity_provider.dart';

/// Modern floating connectivity banner with glassmorphism effect
/// Shows a beautiful floating card when internet connection changes
///
/// Features:
/// - Manual dismiss via swipe up or close button
/// - Offline banner stays until dismissed or status changes
/// - Online banner auto-hides after 2.5 seconds
/// - Smart re-show logic (won't re-show if manually dismissed until status changes)
class ConnectivityBanner extends ConsumerStatefulWidget {
  final Widget child;

  const ConnectivityBanner({
    super.key,
    required this.child,
  });

  @override
  ConsumerState<ConnectivityBanner> createState() => _ConnectivityBannerState();
}

class _ConnectivityBannerState extends ConsumerState<ConnectivityBanner>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _slideAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;

  bool _showBanner = false;
  bool _isOnline = true;
  bool _showingBackOnline = false;

  /// Kullanıcı banner'ı manuel olarak kapattı mı?
  /// Bu flag, durum değişene kadar banner'ın tekrar gösterilmesini engeller
  bool _userDismissed = false;

  /// Son bilinen bağlantı durumu (dismiss tracking için)
  ConnectivityStatus? _lastKnownStatus;

  // DEBUG MODE
  bool _debugMode = false;
  int _debugTapCount = 0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 600),
      reverseDuration: const Duration(milliseconds: 400),
      vsync: this,
    );

    // Elastic slide animation (from top)
    _slideAnimation = Tween<double>(
      begin: -100,
      end: 0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.elasticOut,
      reverseCurve: Curves.easeInBack,
    ));

    // Scale animation for bounce effect
    _scaleAnimation = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.elasticOut,
      reverseCurve: Curves.easeIn,
    ));

    // Opacity animation
    _opacityAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.3, curve: Curves.easeOut),
      reverseCurve: Curves.easeIn,
    ));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Banner'ı manuel olarak kapat (swipe veya X butonu ile)
  void _dismissBanner() {
    HapticFeedback.lightImpact();
    _userDismissed = true;

    _controller.reverse().then((_) {
      if (mounted) {
        setState(() {
          _showBanner = false;
          _showingBackOnline = false;
        });
      }
    });

    debugPrint('ConnectivityBanner: Manually dismissed by user');
  }

  void _handleConnectivityChange(ConnectivityState state) {
    if (state.isChecking) return;

    final wasOnline = _isOnline;
    _isOnline = state.isConnected;

    // Durum değişti mi kontrol et (dismiss flag'ini sıfırlamak için)
    final statusChanged = _lastKnownStatus != state.status;
    if (statusChanged) {
      _userDismissed = false; // Durum değişti, dismiss flag'ini sıfırla
      _lastKnownStatus = state.status;
      debugPrint('ConnectivityBanner: Status changed, reset userDismissed flag');
    }

    debugPrint('ConnectivityBanner: isOnline=$_isOnline, wasOnline=$wasOnline, userDismissed=$_userDismissed');

    if (!_isOnline) {
      // Offline durumu - Indigo banner göster
      // Kullanıcı kapatmışsa tekrar gösterme
      if (_userDismissed) {
        debugPrint('ConnectivityBanner: Skipping offline banner (user dismissed)');
        return;
      }

      _showingBackOnline = false;
      if (!_showBanner) {
        setState(() => _showBanner = true);
      }
      _controller.forward();
      HapticFeedback.heavyImpact();

      // NOT: Offline banner asla otomatik kapanmaz!
      // Kullanıcı manuel olarak kapatmalı veya internet geri gelmeli

    } else if (!wasOnline && _isOnline) {
      // Online'a geri döndü - Yeşil banner göster
      _showingBackOnline = true;
      _userDismissed = false; // Online olunca dismiss flag'ini sıfırla

      if (!_showBanner) {
        setState(() => _showBanner = true);
      }
      _controller.forward();
      HapticFeedback.mediumImpact();

      // Online banner 2.5 saniye sonra otomatik kapanır (başarı mesajı)
      Future.delayed(const Duration(milliseconds: 2500), () {
        if (mounted && _showingBackOnline && _isOnline) {
          _controller.reverse().then((_) {
            if (mounted) {
              setState(() {
                _showBanner = false;
                _showingBackOnline = false;
              });
            }
          });
        }
      });
    }
  }

  void _onDebugLongPress() {
    if (!_debugMode) return;
    final notifier = ref.read(connectivityProvider.notifier);
    final currentState = ref.read(connectivityProvider);
    notifier.setDebugOffline(currentState.isConnected);
    HapticFeedback.heavyImpact();
  }

  void _onDebugTap() {
    _debugTapCount++;
    Future.delayed(const Duration(seconds: 2), () => _debugTapCount = 0);

    if (_debugTapCount >= 5) {
      setState(() => _debugMode = !_debugMode);
      _debugTapCount = 0;
      HapticFeedback.heavyImpact();
      debugPrint('ConnectivityBanner: Debug mode ${_debugMode ? "ON" : "OFF"}');
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<ConnectivityState>(connectivityProvider, (_, next) {
      _handleConnectivityChange(next);
    });

    final currentState = ref.watch(connectivityProvider);
    if (!_showBanner && currentState.isDisconnected && !_userDismissed) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !_showBanner && !_userDismissed) {
          _handleConnectivityChange(currentState);
        }
      });
    }

    return Stack(
      alignment: Alignment.topCenter,
      children: [
        widget.child,

        // Debug tap area
        if (!_showBanner)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 50,
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: _onDebugTap,
              child: const SizedBox(),
            ),
          ),

        // Floating banner with Dismissible
        if (_showBanner)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              bottom: false,
              child: AnimatedBuilder(
                animation: _controller,
                builder: (context, child) {
                  return Transform.translate(
                    offset: Offset(0, _slideAnimation.value),
                    child: Opacity(
                      opacity: _opacityAnimation.value.clamp(0.0, 1.0),
                      child: Transform.scale(
                        scale: _scaleAnimation.value,
                        child: child,
                      ),
                    ),
                  );
                },
                child: Dismissible(
                  key: ValueKey('connectivity_banner_${_isOnline ? 'online' : 'offline'}'),
                  direction: DismissDirection.up,
                  onDismissed: (_) => _dismissBanner(),
                  child: GestureDetector(
                    onLongPress: _onDebugLongPress,
                    child: _buildFloatingBanner(),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildFloatingBanner() {
    final isBackOnline = _showingBackOnline;

    // Color scheme - Indigo themed for consistency
    final primaryColor = isBackOnline
        ? const Color(0xFF10B981) // Mint green
        : const Color(0xFF5C6BC0); // Indigo

    final secondaryColor = isBackOnline
        ? const Color(0xFF34D399)
        : const Color(0xFF7986CB); // Indigo light

    return Material(
      type: MaterialType.transparency,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              padding: const EdgeInsets.only(left: 20, top: 14, bottom: 14, right: 12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    primaryColor.withValues(alpha: 0.92),
                    secondaryColor.withValues(alpha: 0.88),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.25),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: primaryColor.withValues(alpha: 0.35),
                    blurRadius: 20,
                    spreadRadius: -5,
                    offset: const Offset(0, 8),
                  ),
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: DefaultTextStyle.merge(
                style: const TextStyle(decoration: TextDecoration.none),
                child: Row(
                  children: [
                    // Debug indicator
                    if (_debugMode)
                      Container(
                        margin: const EdgeInsets.only(right: 10),
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.25),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'DEBUG',
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            decoration: TextDecoration.none,
                          ),
                        ),
                      ),

                    // Animated icon container
                    TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0.0, end: 1.0),
                      duration: const Duration(milliseconds: 400),
                      curve: Curves.elasticOut,
                      builder: (context, value, child) {
                        return Transform.scale(
                          scale: value,
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.2),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              isBackOnline ? Icons.wifi_rounded : Icons.wifi_off_rounded,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(width: 14),

                    // Text content
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            isBackOnline ? 'Bağlantı Sağlandı' : 'Bağlantı Kesildi',
                            style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.3,
                              decoration: TextDecoration.none,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            isBackOnline
                                ? 'Veriler yenileniyor...'
                                : 'Yukarı kaydırın veya × ile kapatın',
                            style: GoogleFonts.poppins(
                              color: Colors.white.withValues(alpha: 0.85),
                              fontSize: 12,
                              fontWeight: FontWeight.w400,
                              decoration: TextDecoration.none,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(width: 8),

                    // Status indicator or close button
                    if (isBackOnline)
                      _buildCheckmark()
                    else
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _buildPulsingDot(),
                          const SizedBox(width: 8),
                          // Close button (X)
                          _buildCloseButton(),
                        ],
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Kapatma butonu (X)
  Widget _buildCloseButton() {
    return GestureDetector(
      onTap: _dismissBanner,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.0, end: 1.0),
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
        builder: (context, value, child) {
          return Transform.scale(
            scale: value,
            child: Opacity(
              opacity: value,
              child: child,
            ),
          );
        },
        child: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.15),
              width: 1,
            ),
          ),
          child: const Icon(
            Icons.close_rounded,
            color: Colors.white,
            size: 18,
          ),
        ),
      ),
    );
  }

  Widget _buildPulsingDot() {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.5, end: 1.0),
      duration: const Duration(milliseconds: 800),
      curve: Curves.easeInOut,
      builder: (context, value, child) {
        return Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Color.fromRGBO(255, 255, 255, value),
            boxShadow: [
              BoxShadow(
                color: Color.fromRGBO(255, 255, 255, 0.5 * value),
                blurRadius: 8,
                spreadRadius: 2,
              ),
            ],
          ),
        );
      },
      onEnd: () {
        if (mounted && _showBanner && !_showingBackOnline) {
          setState(() {}); // Trigger rebuild to loop animation
        }
      },
    );
  }

  Widget _buildCheckmark() {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 500),
      curve: Curves.elasticOut,
      builder: (context, value, child) {
        return Transform.scale(
          scale: value,
          child: Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.3),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.check_rounded,
              color: Colors.white,
              size: 16,
            ),
          ),
        );
      },
    );
  }
}

/// Wrapper widget that provides connectivity banner
class ConnectivityWrapper extends StatelessWidget {
  final Widget child;

  const ConnectivityWrapper({
    super.key,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return ConnectivityBanner(child: child);
  }
}

// =============================================================================
// MODERN LOADING OVERLAY
// =============================================================================

/// Modern loading overlay with glassmorphism effect
/// Shows a beautiful modal barrier during async operations
class ModernLoadingOverlay extends StatelessWidget {
  final String message;
  final String? subtitle;
  final bool showCancel;
  final VoidCallback? onCancel;
  final Color accentColor;
  final bool isWaitingForConnection;

  const ModernLoadingOverlay({
    super.key,
    required this.message,
    this.subtitle,
    this.showCancel = false,
    this.onCancel,
    this.accentColor = const Color(0xFF5C6BC0),
    this.isWaitingForConnection = false,
  });

  /// Factory for connection waiting state
  factory ModernLoadingOverlay.waitingConnection({
    VoidCallback? onCancel,
  }) {
    return ModernLoadingOverlay(
      message: 'Bağlantı Bekleniyor',
      subtitle: 'İnternet bağlantınız yeniden sağlandığında\nişlem otomatik devam edecek',
      showCancel: true,
      onCancel: onCancel,
      isWaitingForConnection: true,
      accentColor: const Color(0xFFF59E0B), // Amber
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: showCancel,
      child: Material(
        type: MaterialType.transparency,
        child: Container(
          color: Colors.black.withValues(alpha: 0.5),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
            child: Center(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 40),
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: accentColor.withValues(alpha: 0.2),
                      blurRadius: 30,
                      spreadRadius: 0,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Loading indicator or connection icon
                    if (isWaitingForConnection)
                      _buildConnectionWaitingIcon()
                    else
                      _buildLoadingIndicator(),

                    const SizedBox(height: 20),

                    // Message
                    Text(
                      message,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[800],
                      ),
                    ),

                    if (subtitle != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        subtitle!,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          color: Colors.grey[600],
                          height: 1.4,
                        ),
                      ),
                    ],

                    // Cancel button
                    if (showCancel && onCancel != null) ...[
                      const SizedBox(height: 24),
                      TextButton(
                        onPressed: () {
                          HapticFeedback.lightImpact();
                          onCancel!();
                        },
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 12,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(color: Colors.grey[300]!),
                          ),
                        ),
                        child: Text(
                          'İptal Et',
                          style: GoogleFonts.poppins(
                            color: Colors.grey[700],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingIndicator() {
    return SizedBox(
      width: 56,
      height: 56,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Outer ring
          SizedBox(
            width: 56,
            height: 56,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              valueColor: AlwaysStoppedAnimation<Color>(
                accentColor.withValues(alpha: 0.3),
              ),
            ),
          ),
          // Inner ring
          SizedBox(
            width: 44,
            height: 44,
            child: CircularProgressIndicator(
              strokeWidth: 4,
              valueColor: AlwaysStoppedAnimation<Color>(accentColor),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConnectionWaitingIcon() {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.8, end: 1.0),
      duration: const Duration(milliseconds: 1000),
      curve: Curves.easeInOut,
      builder: (context, value, child) {
        return Transform.scale(
          scale: value,
          child: Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  accentColor.withValues(alpha: 0.2),
                  accentColor.withValues(alpha: 0.1),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.wifi_off_rounded,
              size: 36,
              color: accentColor,
            ),
          ),
        );
      },
      onEnd: () {},
    );
  }
}

/// Show modern loading overlay
void showModernLoadingOverlay(
  BuildContext context, {
  required String message,
  String? subtitle,
  bool showCancel = false,
  VoidCallback? onCancel,
  Color accentColor = const Color(0xFF5C6BC0),
  bool isWaitingForConnection = false,
}) {
  showDialog(
    context: context,
    barrierDismissible: false,
    barrierColor: Colors.transparent,
    builder: (context) => ModernLoadingOverlay(
      message: message,
      subtitle: subtitle,
      showCancel: showCancel,
      onCancel: onCancel != null
          ? () {
              Navigator.pop(context);
              onCancel();
            }
          : null,
      accentColor: accentColor,
      isWaitingForConnection: isWaitingForConnection,
    ),
  );
}

// =============================================================================
// EMPTY & ERROR STATE WIDGETS
// =============================================================================

/// Beautiful empty state widget with CampusGo theming
class EmptyStateWidget extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;
  final bool isOffline;

  const EmptyStateWidget({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.actionLabel,
    this.onAction,
    this.isOffline = false,
  });

  /// Factory for no internet state
  factory EmptyStateWidget.noInternet({
    VoidCallback? onRetry,
  }) {
    return EmptyStateWidget(
      icon: Icons.cloud_off_rounded,
      title: 'Bağlantı Yok',
      subtitle: 'İnternet bağlantınızı kontrol edip\ntekrar deneyin',
      actionLabel: 'Tekrar Dene',
      onAction: onRetry,
      isOffline: true,
    );
  }

  /// Factory for empty likes
  factory EmptyStateWidget.noLikes() {
    return const EmptyStateWidget(
      icon: Icons.favorite_border_rounded,
      title: 'Henüz Beğeni Yok',
      subtitle: 'Profilinizi beğenen kişiler\nburada görünecek',
    );
  }

  /// Factory for empty matches
  factory EmptyStateWidget.noMatches() {
    return const EmptyStateWidget(
      icon: Icons.people_outline_rounded,
      title: 'Henüz Eşleşme Yok',
      subtitle: 'Keşfet sayfasından yeni kişilerle\ntanışmaya başlayın',
    );
  }

  /// Factory for empty discover
  factory EmptyStateWidget.noProfiles() {
    return const EmptyStateWidget(
      icon: Icons.explore_off_rounded,
      title: 'Gösterilecek Profil Yok',
      subtitle: 'Şu an için yeni profil bulunamadı\nDaha sonra tekrar deneyin',
    );
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = isOffline
        ? const Color(0xFFF59E0B) // Amber for offline
        : const Color(0xFF5C6BC0); // Indigo for normal

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Animated icon container
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.8, end: 1.0),
              duration: const Duration(milliseconds: 600),
              curve: Curves.elasticOut,
              builder: (context, value, child) {
                return Transform.scale(
                  scale: value,
                  child: Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        colors: [
                          primaryColor.withValues(alpha: 0.15),
                          primaryColor.withValues(alpha: 0.05),
                        ],
                      ),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              primaryColor.withValues(alpha: 0.2),
                              primaryColor.withValues(alpha: 0.1),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          icon,
                          size: 40,
                          color: primaryColor,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),

            const SizedBox(height: 28),

            // Title
            Text(
              title,
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
              ),
            ),

            const SizedBox(height: 12),

            // Subtitle
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 15,
                color: Colors.grey[600],
                height: 1.5,
              ),
            ),

            // Action button
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 28),
              _buildActionButton(primaryColor),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton(Color color) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOut,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 20 * (1 - value)),
            child: child,
          ),
        );
      },
      child: ElevatedButton.icon(
        onPressed: () {
          HapticFeedback.lightImpact();
          onAction?.call();
        },
        icon: Icon(
          isOffline ? Icons.refresh_rounded : Icons.arrow_forward_rounded,
          size: 20,
        ),
        label: Text(
          actionLabel!,
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          elevation: 4,
          shadowColor: color.withValues(alpha: 0.4),
        ),
      ),
    );
  }
}

// =============================================================================
// OFFLINE-AWARE BUTTON
// =============================================================================

/// Button that elegantly handles offline state
/// Shows tooltip and desaturates when offline
class OfflineAwareButton extends ConsumerWidget {
  final Widget child;
  final VoidCallback? onPressed;
  final String offlineMessage;
  final bool showTooltip;

  const OfflineAwareButton({
    super.key,
    required this.child,
    required this.onPressed,
    this.offlineMessage = 'Bağlantı yok',
    this.showTooltip = true,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isOnline = ref.watch(isOnlineProvider);

    return Tooltip(
      message: !isOnline && showTooltip ? offlineMessage : '',
      preferBelow: false,
      decoration: BoxDecoration(
        color: const Color(0xFFF59E0B),
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      textStyle: GoogleFonts.poppins(
        color: Colors.white,
        fontSize: 12,
        fontWeight: FontWeight.w500,
      ),
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 200),
        opacity: isOnline ? 1.0 : 0.5,
        child: ColorFiltered(
          colorFilter: ColorFilter.mode(
            isOnline ? Colors.transparent : Colors.grey,
            isOnline ? BlendMode.dst : BlendMode.saturation,
          ),
          child: IgnorePointer(
            ignoring: !isOnline,
            child: GestureDetector(
              onTap: isOnline
                  ? onPressed
                  : () {
                      HapticFeedback.heavyImpact();
                      _showOfflineSnackbar(context);
                    },
              child: child,
            ),
          ),
        ),
      ),
    );
  }

  void _showOfflineSnackbar(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.wifi_off_rounded, color: Colors.white, size: 20),
            const SizedBox(width: 12),
            Text(
              offlineMessage,
              style: GoogleFonts.poppins(fontWeight: FontWeight.w500),
            ),
          ],
        ),
        backgroundColor: const Color(0xFFF59E0B),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 2),
      ),
    );
  }
}

/// Elevated button variant with offline awareness
class OfflineAwareElevatedButton extends ConsumerWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final String offlineMessage;

  const OfflineAwareElevatedButton({
    super.key,
    required this.label,
    this.icon,
    required this.onPressed,
    this.backgroundColor,
    this.foregroundColor,
    this.offlineMessage = 'İnternet bağlantısı gerekli',
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isOnline = ref.watch(isOnlineProvider);
    final bgColor = backgroundColor ?? const Color(0xFF5C6BC0);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        boxShadow: isOnline
            ? [
                BoxShadow(
                  color: bgColor.withValues(alpha: 0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ]
            : [],
      ),
      child: ElevatedButton(
        onPressed: isOnline
            ? () {
                HapticFeedback.lightImpact();
                onPressed?.call();
              }
            : () {
                HapticFeedback.heavyImpact();
                _showOfflineTooltip(context);
              },
        style: ElevatedButton.styleFrom(
          backgroundColor: isOnline ? bgColor : Colors.grey[400],
          foregroundColor: foregroundColor ?? Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          elevation: 0,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!isOnline) ...[
              const Icon(Icons.wifi_off_rounded, size: 18),
              const SizedBox(width: 8),
            ] else if (icon != null) ...[
              Icon(icon, size: 20),
              const SizedBox(width: 8),
            ],
            Text(
              isOnline ? label : 'Bağlantı Yok',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w600,
                fontSize: 15,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showOfflineTooltip(BuildContext context) {
    final overlay = Overlay.of(context);
    late OverlayEntry entry;

    entry = OverlayEntry(
      builder: (context) => Positioned(
        bottom: 100,
        left: 20,
        right: 20,
        child: Material(
          type: MaterialType.transparency,
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.0, end: 1.0),
            duration: const Duration(milliseconds: 200),
            builder: (context, value, child) {
              return Opacity(
                opacity: value,
                child: Transform.translate(
                  offset: Offset(0, 10 * (1 - value)),
                  child: child,
                ),
              );
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: BoxDecoration(
                color: const Color(0xFF1F2937),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF59E0B).withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.wifi_off_rounded,
                      color: Color(0xFFF59E0B),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      offlineMessage,
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    overlay.insert(entry);

    Future.delayed(const Duration(seconds: 2), () {
      entry.remove();
    });
  }
}
