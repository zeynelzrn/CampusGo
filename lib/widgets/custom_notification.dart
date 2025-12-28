import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

enum NotificationType { success, error, warning, info, like, message }

class CustomNotification {
  static void show({
    required BuildContext context,
    required String message,
    String? subtitle,
    NotificationType type = NotificationType.info,
    Duration duration = const Duration(seconds: 3),
    VoidCallback? onTap,
  }) {
    final overlay = Overlay.of(context);
    late OverlayEntry overlayEntry;

    overlayEntry = OverlayEntry(
      builder: (context) => _NotificationWidget(
        message: message,
        subtitle: subtitle,
        type: type,
        duration: duration,
        onTap: onTap,
        onDismiss: () => overlayEntry.remove(),
      ),
    );

    overlay.insert(overlayEntry);
  }

  // Convenience methods
  static void success(BuildContext context, String message,
      {String? subtitle}) {
    show(
        context: context,
        message: message,
        subtitle: subtitle,
        type: NotificationType.success);
  }

  static void error(BuildContext context, String message, {String? subtitle}) {
    show(
        context: context,
        message: message,
        subtitle: subtitle,
        type: NotificationType.error);
  }

  static void warning(BuildContext context, String message,
      {String? subtitle}) {
    show(
        context: context,
        message: message,
        subtitle: subtitle,
        type: NotificationType.warning);
  }

  static void info(BuildContext context, String message, {String? subtitle}) {
    show(
        context: context,
        message: message,
        subtitle: subtitle,
        type: NotificationType.info);
  }

  /// Show a pink-themed notification for likes
  static void like(BuildContext context, String message,
      {String? subtitle, VoidCallback? onTap}) {
    show(
      context: context,
      message: message,
      subtitle: subtitle,
      type: NotificationType.like,
      onTap: onTap,
    );
  }

  /// Show a blue-purple themed notification for messages
  static void message(BuildContext context, String message,
      {String? subtitle, VoidCallback? onTap}) {
    show(
      context: context,
      message: message,
      subtitle: subtitle,
      type: NotificationType.message,
      onTap: onTap,
    );
  }
}

class _NotificationWidget extends StatefulWidget {
  final String message;
  final String? subtitle;
  final NotificationType type;
  final Duration duration;
  final VoidCallback? onTap;
  final VoidCallback onDismiss;

  const _NotificationWidget({
    required this.message,
    this.subtitle,
    required this.type,
    required this.duration,
    this.onTap,
    required this.onDismiss,
  });

  @override
  State<_NotificationWidget> createState() => _NotificationWidgetState();
}

class _NotificationWidgetState extends State<_NotificationWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, -1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutBack,
    ));

    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );

    _controller.forward();

    Future.delayed(widget.duration, () {
      if (mounted) {
        _dismiss();
      }
    });
  }

  void _dismiss() async {
    await _controller.reverse();
    widget.onDismiss();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 10,
      left: 16,
      right: 16,
      child: SlideTransition(
        position: _slideAnimation,
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: GestureDetector(
            onTap: () {
              widget.onTap?.call();
              _dismiss();
            },
            onHorizontalDragEnd: (details) {
              if (details.primaryVelocity != null &&
                  details.primaryVelocity!.abs() > 100) {
                _dismiss();
              }
            },
            child: Material(
              color: Colors.transparent,
              child: _buildNotificationCard(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNotificationCard() {
    final config = _getTypeConfig();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: config.gradientColors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: config.shadowColor.withValues(alpha: 0.4),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          // Icon with animated background
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.25),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              config.icon,
              color: Colors.white,
              size: 26,
            ),
          ),
          const SizedBox(width: 14),
          // Text content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  widget.message,
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (widget.subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    widget.subtitle!,
                    style: GoogleFonts.poppins(
                      color: Colors.white.withValues(alpha: 0.85),
                      fontSize: 12,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ],
            ),
          ),
          // Close button
          GestureDetector(
            onTap: _dismiss,
            child: Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.close_rounded,
                color: Colors.white,
                size: 16,
              ),
            ),
          ),
        ],
      ),
    );
  }

  _NotificationConfig _getTypeConfig() {
    switch (widget.type) {
      case NotificationType.success:
        return _NotificationConfig(
          icon: Icons.check_circle_rounded,
          gradientColors: [
            const Color(0xFF00C853),
            const Color(0xFF00E676),
          ],
          shadowColor: const Color(0xFF00C853),
        );
      case NotificationType.error:
        return _NotificationConfig(
          icon: Icons.error_rounded,
          gradientColors: [
            const Color(0xFFE53935),
            const Color(0xFFFF5252),
          ],
          shadowColor: const Color(0xFFE53935),
        );
      case NotificationType.warning:
        return _NotificationConfig(
          icon: Icons.warning_rounded,
          gradientColors: [
            const Color(0xFFFF9800),
            const Color(0xFFFFB74D),
          ],
          shadowColor: const Color(0xFFFF9800),
        );
      case NotificationType.info:
        return _NotificationConfig(
          icon: Icons.info_rounded,
          gradientColors: [
            const Color(0xFF2196F3),
            const Color(0xFF64B5F6),
          ],
          shadowColor: const Color(0xFF2196F3),
        );
      case NotificationType.like:
        return _NotificationConfig(
          icon: Icons.favorite_rounded,
          gradientColors: [
            const Color(0xFFFF2C60),
            const Color(0xFFFF6B9D),
          ],
          shadowColor: const Color(0xFFFF2C60),
        );
      case NotificationType.message:
        return _NotificationConfig(
          icon: Icons.chat_bubble_rounded,
          gradientColors: [
            const Color(0xFF7C4DFF),
            const Color(0xFFB388FF),
          ],
          shadowColor: const Color(0xFF7C4DFF),
        );
    }
  }
}

class _NotificationConfig {
  final IconData icon;
  final List<Color> gradientColors;
  final Color shadowColor;

  _NotificationConfig({
    required this.icon,
    required this.gradientColors,
    required this.shadowColor,
  });
}
