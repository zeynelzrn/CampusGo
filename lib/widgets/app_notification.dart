import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:overlay_support/overlay_support.dart';

/// Merkezi bildirim helper sınıfı
/// Tüm in-app bildirimleri bu sınıf üzerinden gösterilmeli
/// Özellikler:
/// - X ikonu ile kapatma
/// - Yukarı kaydırarak kapatma
/// - Physics-based spring efekti (titremesiz)
/// - Stretch efekti (aşağı çekince uzama)
class AppNotification {
  /// Başarı bildirimi (yeşil - pastel)
  static void success({
    required String title,
    String? subtitle,
    Duration duration = const Duration(seconds: 3),
    VoidCallback? onTap,
  }) {
    _show(
      title: title,
      subtitle: subtitle,
      icon: Icons.check_circle_rounded,
      gradientColors: [const Color(0xFF66BB6A), const Color(0xFF81C784)],
      shadowColor: const Color(0xFF66BB6A),
      duration: duration,
      onTap: onTap,
    );
  }

  /// Hata bildirimi (kırmızı - pastel)
  static void error({
    required String title,
    String? subtitle,
    Duration duration = const Duration(seconds: 3),
    VoidCallback? onTap,
  }) {
    _show(
      title: title,
      subtitle: subtitle,
      icon: Icons.error_rounded,
      gradientColors: [const Color(0xFFEF5350), const Color(0xFFE57373)],
      shadowColor: const Color(0xFFEF5350),
      duration: duration,
      onTap: onTap,
    );
  }

  /// Uyarı bildirimi (turuncu - pastel)
  static void warning({
    required String title,
    String? subtitle,
    Duration duration = const Duration(seconds: 3),
    VoidCallback? onTap,
  }) {
    _show(
      title: title,
      subtitle: subtitle,
      icon: Icons.warning_rounded,
      gradientColors: [const Color(0xFFFFB74D), const Color(0xFFFFCC80)],
      shadowColor: const Color(0xFFFFB74D),
      duration: duration,
      onTap: onTap,
    );
  }

  /// Bilgi bildirimi (mavi - pastel)
  static void info({
    required String title,
    String? subtitle,
    Duration duration = const Duration(seconds: 3),
    VoidCallback? onTap,
  }) {
    _show(
      title: title,
      subtitle: subtitle,
      icon: Icons.info_rounded,
      gradientColors: [const Color(0xFF64B5F6), const Color(0xFF90CAF9)],
      shadowColor: const Color(0xFF64B5F6),
      duration: duration,
      onTap: onTap,
    );
  }

  /// Beğeni/İstek bildirimi (indigo - pastel)
  static void like({
    required String title,
    String? subtitle,
    Duration duration = const Duration(seconds: 3),
    VoidCallback? onTap,
  }) {
    _show(
      title: title,
      subtitle: subtitle,
      icon: Icons.waving_hand_rounded,
      gradientColors: [const Color(0xFF7986CB), const Color(0xFF9FA8DA)],
      shadowColor: const Color(0xFF7986CB),
      duration: duration,
      onTap: onTap,
    );
  }

  /// Mesaj bildirimi (mor - pastel)
  static void message({
    required String title,
    String? subtitle,
    Duration duration = const Duration(seconds: 3),
    VoidCallback? onTap,
  }) {
    _show(
      title: title,
      subtitle: subtitle,
      icon: Icons.chat_bubble_rounded,
      gradientColors: [const Color(0xFF9575CD), const Color(0xFFB39DDB)],
      shadowColor: const Color(0xFF9575CD),
      duration: duration,
      onTap: onTap,
    );
  }

  /// Engelleme bildirimi (yeşil - pastel, block ikonu)
  static void blocked({
    required String title,
    String? subtitle,
    Duration duration = const Duration(seconds: 3),
    VoidCallback? onTap,
  }) {
    _show(
      title: title,
      subtitle: subtitle,
      icon: Icons.block_rounded,
      gradientColors: [const Color(0xFF66BB6A), const Color(0xFF81C784)],
      shadowColor: const Color(0xFF66BB6A),
      duration: duration,
      onTap: onTap,
    );
  }

  /// Engel kaldırma bildirimi (mavi - pastel, check ikonu)
  static void unblocked({
    required String title,
    String? subtitle,
    Duration duration = const Duration(seconds: 3),
    VoidCallback? onTap,
  }) {
    _show(
      title: title,
      subtitle: subtitle,
      icon: Icons.check_circle_rounded,
      gradientColors: [const Color(0xFF64B5F6), const Color(0xFF90CAF9)],
      shadowColor: const Color(0xFF64B5F6),
      duration: duration,
      onTap: onTap,
    );
  }

  /// Özel ikon ve renklerle bildirim
  static void custom({
    required String title,
    String? subtitle,
    required IconData icon,
    required List<Color> gradientColors,
    required Color shadowColor,
    Duration duration = const Duration(seconds: 3),
    VoidCallback? onTap,
  }) {
    _show(
      title: title,
      subtitle: subtitle,
      icon: icon,
      gradientColors: gradientColors,
      shadowColor: shadowColor,
      duration: duration,
      onTap: onTap,
    );
  }

  /// Ana bildirim gösterme metodu
  static void _show({
    required String title,
    String? subtitle,
    required IconData icon,
    required List<Color> gradientColors,
    required Color shadowColor,
    required Duration duration,
    VoidCallback? onTap,
  }) {
    showOverlayNotification(
      (context) {
        return _SpringNotificationCard(
          title: title,
          subtitle: subtitle,
          icon: icon,
          gradientColors: gradientColors,
          shadowColor: shadowColor,
          onTap: onTap,
          onDismiss: () {
            OverlaySupportEntry.of(context)?.dismiss();
          },
          dismissDuration: duration,
        );
      },
      // Duration.zero: Harici zamanlayıcı devre dışı
      // Zamanlama artık widget içinde Timer ile yönetiliyor
      duration: Duration.zero,
      position: NotificationPosition.top,
    );
  }
}

/// Physics-based spring animasyonlu bildirim kartı
/// - Titremesiz GPU-hızlandırmalı Transform
/// - SpringSimulation ile gerçek fizik
/// - Stretch efekti
/// - Hold-to-Pause: Dokunma süresince zamanlayıcı durur
class _SpringNotificationCard extends StatefulWidget {
  final String title;
  final String? subtitle;
  final IconData icon;
  final List<Color> gradientColors;
  final Color shadowColor;
  final VoidCallback? onTap;
  final VoidCallback onDismiss;
  final Duration dismissDuration;

  const _SpringNotificationCard({
    required this.title,
    this.subtitle,
    required this.icon,
    required this.gradientColors,
    required this.shadowColor,
    this.onTap,
    required this.onDismiss,
    required this.dismissDuration,
  });

  @override
  State<_SpringNotificationCard> createState() => _SpringNotificationCardState();
}

class _SpringNotificationCardState extends State<_SpringNotificationCard>
    with SingleTickerProviderStateMixin {

  // AnimationController - spring simulation için
  late AnimationController _controller;

  // Drag değeri - ValueNotifier ile optimize edilmiş (setState yok)
  final ValueNotifier<double> _dragNotifier = ValueNotifier<double>(0);

  // Dismiss durumu
  bool _isDismissed = false;

  // Hold-to-Pause: Akıllı zamanlayıcı
  Timer? _dismissTimer;

  // Spring physics sabitleri
  static const double _dismissThreshold = -80;
  static const double _maxDownDrag = 60;
  static const double _rubberBandFactor = 0.4;

  // Spring description - yumuşak ama hızlı
  final SpringDescription _spring = const SpringDescription(
    mass: 1.0,
    stiffness: 300.0,
    damping: 20.0,
  );

  @override
  void initState() {
    super.initState();
    _controller = AnimationController.unbounded(vsync: this);
    _controller.addListener(_onAnimationUpdate);
    // Bildirim geldiğinde zamanlayıcıyı başlat
    _startDismissTimer();
  }

  @override
  void dispose() {
    _cancelDismissTimer();
    _controller.removeListener(_onAnimationUpdate);
    _controller.dispose();
    _dragNotifier.dispose();
    super.dispose();
  }

  /// Zamanlayıcıyı başlat - varsa eskisini iptal et
  void _startDismissTimer() {
    _cancelDismissTimer();
    _dismissTimer = Timer(widget.dismissDuration, () {
      if (!_isDismissed) {
        _dismissWithSpring(0);
      }
    });
  }

  /// Zamanlayıcıyı iptal et (dokunma başladığında)
  void _cancelDismissTimer() {
    _dismissTimer?.cancel();
    _dismissTimer = null;
  }

  void _onAnimationUpdate() {
    _dragNotifier.value = _controller.value;
  }

  void _onPanStart(DragStartDetails details) {
    // Mevcut animasyonu durdur
    _controller.stop();
    // Zamanlayıcıyı duraklat - kullanıcı tuttuğu sürece kapanmasın
    _cancelDismissTimer();
  }

  void _onPanUpdate(DragUpdateDetails details) {
    if (_isDismissed) return;

    final delta = details.delta.dy;
    final currentDrag = _dragNotifier.value;

    if (currentDrag + delta < 0) {
      // Yukarı sürükleme - normal hareket
      _dragNotifier.value = currentDrag + delta;
    } else {
      // Aşağı sürükleme - rubber band efekti (dirençli)
      final newDrag = currentDrag + (delta * _rubberBandFactor);
      _dragNotifier.value = newDrag.clamp(-double.infinity, _maxDownDrag);
    }
  }

  void _onPanEnd(DragEndDetails details) {
    if (_isDismissed) return;

    final velocity = details.velocity.pixelsPerSecond.dy;
    final currentDrag = _dragNotifier.value;

    // Yukarı hızlı kaydırma veya eşiği geçme - dismiss
    if (currentDrag < _dismissThreshold || velocity < -800) {
      _dismissWithSpring(velocity);
    } else {
      // Spring ile geri dönüş
      _springBack(velocity);
      // Zamanlayıcıyı yeniden başlat - parmak çekilince sayaç baştan başlar
      _startDismissTimer();
    }
  }

  void _springBack(double velocity) {
    // Spring simulation ile yerine dön
    final simulation = SpringSimulation(
      _spring,
      _dragNotifier.value, // Başlangıç pozisyonu
      0, // Hedef pozisyon
      velocity / 1000, // Velocity (pixels/ms)
    );

    _controller.animateWith(simulation);
  }

  void _dismissWithSpring(double velocity) {
    if (_isDismissed) return;
    _isDismissed = true;

    HapticFeedback.lightImpact();

    // Yukarı fırlat
    final simulation = SpringSimulation(
      const SpringDescription(mass: 1, stiffness: 500, damping: 30),
      _dragNotifier.value,
      -300, // Ekran dışına
      velocity / 1000,
    );

    _controller.animateWith(simulation).then((_) {
      widget.onDismiss();
    });
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Material(
        color: Colors.transparent,
        child: GestureDetector(
          onPanStart: _onPanStart,
          onPanUpdate: _onPanUpdate,
          onPanEnd: _onPanEnd,
          // Hold-to-Pause: Dokunma olaylarını yakala
          onTapDown: (_) => _cancelDismissTimer(),
          onTapUp: (_) {
            if (!_isDismissed) _startDismissTimer();
          },
          onTapCancel: () {
            if (!_isDismissed) _startDismissTimer();
          },
          onTap: () {
            if (_isDismissed) return;
            HapticFeedback.lightImpact();
            widget.onTap?.call();
            widget.onDismiss();
          },
          // ValueListenableBuilder - setState olmadan rebuild
          child: ValueListenableBuilder<double>(
            valueListenable: _dragNotifier,
            builder: (context, drag, child) {
              // Opacity - yukarı sürükledikçe şeffaflaşsın
              final opacity = drag < 0
                  ? (1 + drag / 150).clamp(0.0, 1.0)
                  : 1.0;

              // Scale - aşağı çekince uzasın
              final scaleY = drag > 0
                  ? 1.0 + (drag * 0.003).clamp(0.0, 0.12)
                  : 1.0;

              // GPU-hızlandırmalı Transform
              return Transform(
                transform: Matrix4.diagonal3Values(1.0, scaleY, 1.0)
                  ..setTranslationRaw(0.0, drag, 0.0),
                alignment: Alignment.topCenter,
                child: Opacity(
                  opacity: opacity,
                  child: child,
                ),
              );
            },
            // Child sabit - her frame'de rebuild olmaz
            child: _buildCardContent(),
          ),
        ),
      ),
    );
  }

  Widget _buildCardContent() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: widget.gradientColors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: widget.shadowColor.withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          // Sol ikon
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.25),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(widget.icon, color: Colors.white, size: 24),
          ),
          const SizedBox(width: 12),
          // Metin alanı
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  widget.title,
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
                      color: Colors.white.withValues(alpha: 0.9),
                      fontSize: 12,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          // X Kapatma Butonu
          GestureDetector(
            onTap: () {
              if (_isDismissed) return;
              HapticFeedback.lightImpact();
              _dismissWithSpring(0);
            },
            behavior: HitTestBehavior.opaque,
            child: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.25),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.close_rounded,
                color: Colors.white,
                size: 18,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
