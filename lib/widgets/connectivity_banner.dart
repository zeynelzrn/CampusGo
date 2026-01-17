import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/connectivity_provider.dart';

/// Animated connectivity banner that shows at the top of the screen
/// when internet connection is lost or restored
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
  late Animation<Offset> _slideAnimation;
  late Animation<double> _opacityAnimation;

  bool _showBanner = false;
  bool _isOnline = true;
  bool _showingBackOnline = false;

  // DEBUG MODE - Long press on banner to toggle
  bool _debugMode = false;
  int _debugTapCount = 0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 350),
      vsync: this,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, -1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    ));

    _opacityAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    ));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleConnectivityChange(ConnectivityState state) {
    if (state.isChecking) return; // Skip checking state

    final wasOnline = _isOnline;
    _isOnline = state.isConnected;

    debugPrint('ConnectivityBanner: State changed - isOnline=$_isOnline, wasOnline=$wasOnline');

    if (!_isOnline) {
      // Internet disconnected - show red banner
      _showingBackOnline = false;
      if (!_showBanner) {
        setState(() => _showBanner = true);
      }
      _controller.forward();
      HapticFeedback.heavyImpact();
    } else if (!wasOnline && _isOnline) {
      // Internet restored - show green banner briefly
      _showingBackOnline = true;
      if (!_showBanner) {
        setState(() => _showBanner = true);
      }
      _controller.forward();
      HapticFeedback.mediumImpact();

      // Hide banner after 2.5 seconds
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

  // DEBUG: Toggle offline mode
  void _onDebugLongPress() {
    if (!_debugMode) return;

    final notifier = ref.read(connectivityProvider.notifier);
    final currentState = ref.read(connectivityProvider);

    // Toggle offline
    notifier.setDebugOffline(currentState.isConnected);
    HapticFeedback.heavyImpact();
  }

  // DEBUG: Activate debug mode with 5 rapid taps
  void _onDebugTap() {
    _debugTapCount++;
    Future.delayed(const Duration(seconds: 2), () {
      _debugTapCount = 0;
    });

    if (_debugTapCount >= 5) {
      setState(() => _debugMode = !_debugMode);
      _debugTapCount = 0;
      HapticFeedback.heavyImpact();
      debugPrint('ConnectivityBanner: Debug mode ${_debugMode ? "ENABLED" : "DISABLED"}');
    }
  }

  @override
  Widget build(BuildContext context) {
    // Listen to connectivity changes
    ref.listen<ConnectivityState>(connectivityProvider, (previous, next) {
      _handleConnectivityChange(next);
    });

    // Also check initial state
    final currentState = ref.watch(connectivityProvider);
    if (!_showBanner && currentState.isDisconnected) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !_showBanner) {
          _handleConnectivityChange(currentState);
        }
      });
    }

    return Stack(
      alignment: Alignment.topCenter,
      children: [
        // Main content
        widget.child,

        // Debug tap detector (invisible, at top)
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

        // Connectivity banner overlay
        if (_showBanner)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SlideTransition(
              position: _slideAnimation,
              child: FadeTransition(
                opacity: _opacityAnimation,
                child: GestureDetector(
                  onLongPress: _onDebugLongPress,
                  child: _buildBanner(),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildBanner() {
    final isBackOnline = _showingBackOnline;

    return Directionality(
      textDirection: TextDirection.ltr,
      child: Material(
        type: MaterialType.transparency,
        child: Container(
          width: double.infinity,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: isBackOnline
                  ? [const Color(0xFF43A047), const Color(0xFF66BB6A)]
                  : [const Color(0xFFE53935), const Color(0xFFEF5350)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: (isBackOnline ? Colors.green : Colors.red).withValues(alpha: 0.3),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Debug indicator
                  if (_debugMode)
                    Container(
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'DEBUG',
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),

                  // Icon
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0.8, end: 1.0),
                    duration: const Duration(milliseconds: 300),
                    builder: (context, value, child) {
                      return Transform.scale(
                        scale: value,
                        child: Icon(
                          isBackOnline ? Icons.wifi_rounded : Icons.wifi_off_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                      );
                    },
                  ),
                  const SizedBox(width: 10),

                  // Text
                  Text(
                    isBackOnline ? 'Bağlantı sağlandı' : 'İnternet bağlantınız kesildi',
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.2,
                    ),
                  ),

                  // Loading indicator for offline state
                  if (!isBackOnline) ...[
                    const SizedBox(width: 12),
                    const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white70),
                      ),
                    ),
                  ],

                  // Checkmark for online state
                  if (isBackOnline) ...[
                    const SizedBox(width: 10),
                    TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0.0, end: 1.0),
                      duration: const Duration(milliseconds: 400),
                      curve: Curves.elasticOut,
                      builder: (context, value, child) {
                        return Transform.scale(
                          scale: value,
                          child: Container(
                            padding: const EdgeInsets.all(2),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.3),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.check_rounded,
                              color: Colors.white,
                              size: 14,
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Wrapper widget that provides connectivity banner to its child
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
