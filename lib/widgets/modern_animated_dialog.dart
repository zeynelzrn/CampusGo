import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

/// Dialog türleri için preset renkler ve ikonlar
enum DialogType {
  danger,   // Silme, hesap kapatma - Kırmızı
  warning,  // Engelleme, uyarı - Turuncu
  info,     // Bilgilendirme - Mavi
  success,  // Başarı, onay - Yeşil
  primary,  // Genel amaçlı - Mor/Ana tema
}

/// Dialog türüne göre konfigürasyon
class _DialogTypeConfig {
  final Color primaryColor;
  final Color lightColor;
  final IconData defaultIcon;

  const _DialogTypeConfig({
    required this.primaryColor,
    required this.lightColor,
    required this.defaultIcon,
  });

  static _DialogTypeConfig fromType(DialogType type) {
    switch (type) {
      case DialogType.danger:
        return _DialogTypeConfig(
          primaryColor: Colors.red,
          lightColor: Colors.red.withValues(alpha: 0.1),
          defaultIcon: Icons.delete_forever_rounded,
        );
      case DialogType.warning:
        return _DialogTypeConfig(
          primaryColor: Colors.orange,
          lightColor: Colors.orange.withValues(alpha: 0.1),
          defaultIcon: Icons.warning_amber_rounded,
        );
      case DialogType.info:
        return _DialogTypeConfig(
          primaryColor: Colors.blue,
          lightColor: Colors.blue.withValues(alpha: 0.1),
          defaultIcon: Icons.info_outline_rounded,
        );
      case DialogType.success:
        return _DialogTypeConfig(
          primaryColor: Colors.green,
          lightColor: Colors.green.withValues(alpha: 0.1),
          defaultIcon: Icons.check_circle_outline_rounded,
        );
      case DialogType.primary:
        return _DialogTypeConfig(
          primaryColor: const Color(0xFF5C6BC0),
          lightColor: const Color(0xFF5C6BC0).withValues(alpha: 0.1),
          defaultIcon: Icons.help_outline_rounded,
        );
    }
  }
}

/// Modern, animasyonlu ve özelleştirilebilir dialog widget'ı
class ModernAnimatedDialog extends StatelessWidget {
  final DialogType type;
  final IconData? icon;
  final String title;
  final String? subtitle;
  final Widget? content;
  final String cancelText;
  final String? confirmText;
  final VoidCallback? onConfirm;
  final VoidCallback? onCancel;
  final bool showCancelButton;
  final Color? confirmButtonColor;
  final bool isLoading;

  const ModernAnimatedDialog({
    super.key,
    this.type = DialogType.primary,
    this.icon,
    required this.title,
    this.subtitle,
    this.content,
    this.cancelText = 'İptal',
    this.confirmText,
    this.onConfirm,
    this.onCancel,
    this.showCancelButton = true,
    this.confirmButtonColor,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    final config = _DialogTypeConfig.fromType(type);
    final effectiveIcon = icon ?? config.defaultIcon;
    final effectiveConfirmColor = confirmButtonColor ?? config.primaryColor;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 340),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // İkon başlık alanı
            Container(
              width: double.infinity,
              padding: const EdgeInsets.only(top: 28, bottom: 20),
              child: Column(
                children: [
                  // Büyük dairesel ikon
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: config.lightColor,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: config.primaryColor.withValues(alpha: 0.2),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Icon(
                      effectiveIcon,
                      color: config.primaryColor,
                      size: 36,
                    ),
                  ),
                  const SizedBox(height: 20),
                  // Başlık
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Text(
                      title,
                      style: GoogleFonts.poppins(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[900],
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            ),

            // Alt başlık veya içerik
            if (subtitle != null || content != null)
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (subtitle != null)
                        Text(
                          subtitle!,
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            color: Colors.grey[600],
                            height: 1.5,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      if (content != null) ...[
                        if (subtitle != null) const SizedBox(height: 16),
                        content!,
                      ],
                    ],
                  ),
                ),
              ),

            // Butonlar
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
              child: Row(
                children: [
                  // İptal butonu
                  if (showCancelButton)
                    Expanded(
                      child: OutlinedButton(
                        onPressed: isLoading ? null : () {
                          HapticFeedback.lightImpact();
                          if (onCancel != null) {
                            onCancel!();
                          } else {
                            Navigator.of(context).pop(false);
                          }
                        },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.grey[700],
                          side: BorderSide(color: Colors.grey[300]!),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: Text(
                          cancelText,
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w500,
                            fontSize: 15,
                          ),
                        ),
                      ),
                    ),

                  // Onay butonu
                  if (confirmText != null) ...[
                    if (showCancelButton) const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: isLoading ? null : () {
                          HapticFeedback.mediumImpact();
                          if (onConfirm != null) {
                            onConfirm!();
                          } else {
                            Navigator.of(context).pop(true);
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: effectiveConfirmColor,
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: effectiveConfirmColor.withValues(alpha: 0.5),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: isLoading
                            ? SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.white.withValues(alpha: 0.8),
                                  ),
                                ),
                              )
                            : Text(
                                confirmText!,
                                style: GoogleFonts.poppins(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 15,
                                ),
                              ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Bilgi kutusu widget'ı - dialog içeriğinde kullanılabilir
class DialogInfoBox extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color;

  const DialogInfoBox({
    super.key,
    required this.icon,
    required this.text,
    this.color = Colors.orange,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.poppins(
                fontSize: 13,
                color: color.withValues(alpha: 0.9),
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Silinecek öğeler listesi widget'ı
class DialogDeleteList extends StatelessWidget {
  final List<String> items;
  final Color color;

  const DialogDeleteList({
    super.key,
    required this.items,
    this.color = Colors.red,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: items.map((item) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Row(
            children: [
              Icon(Icons.remove_circle_outline, color: color, size: 16),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  item,
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    color: color.withValues(alpha: 0.85),
                  ),
                ),
              ),
            ],
          ),
        )).toList(),
      ),
    );
  }
}

/// Modern dialog gösterme fonksiyonu - Scale + Fade animasyonlu
Future<T?> showModernDialog<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool barrierDismissible = true,
  Duration transitionDuration = const Duration(milliseconds: 280),
}) {
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: barrierDismissible,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    barrierColor: Colors.black.withValues(alpha: 0.5),
    transitionDuration: transitionDuration,
    pageBuilder: (context, animation, secondaryAnimation) {
      return builder(context);
    },
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      final curvedAnimation = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutBack,
        reverseCurve: Curves.easeInQuart,
      );

      return FadeTransition(
        opacity: CurvedAnimation(
          parent: animation,
          curve: Curves.easeOut,
        ),
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.85, end: 1.0).animate(curvedAnimation),
          child: child,
        ),
      );
    },
  );
}

/// Loading dialog için özel widget
class ModernLoadingDialog extends StatelessWidget {
  final String message;
  final String? subtitle;
  final Color color;

  const ModernLoadingDialog({
    super.key,
    required this.message,
    this.subtitle,
    this.color = Colors.red,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 50,
              height: 50,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                valueColor: AlwaysStoppedAnimation<Color>(color),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              message,
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.grey[800],
              ),
              textAlign: TextAlign.center,
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 8),
              Text(
                subtitle!,
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  color: Colors.grey[600],
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Hızlı modern dialog gösterme yardımcı sınıfı
class ModernDialogs {
  /// Onay dialogu göster
  static Future<bool?> showConfirm({
    required BuildContext context,
    required String title,
    String? subtitle,
    Widget? content,
    String cancelText = 'İptal',
    String confirmText = 'Onayla',
    DialogType type = DialogType.primary,
    IconData? icon,
    Color? confirmButtonColor,
  }) {
    return showModernDialog<bool>(
      context: context,
      builder: (context) => ModernAnimatedDialog(
        type: type,
        icon: icon,
        title: title,
        subtitle: subtitle,
        content: content,
        cancelText: cancelText,
        confirmText: confirmText,
        confirmButtonColor: confirmButtonColor,
      ),
    );
  }

  /// Tehlikeli işlem dialogu göster (silme, engelleme vs.)
  static Future<bool?> showDanger({
    required BuildContext context,
    required String title,
    String? subtitle,
    Widget? content,
    String cancelText = 'Vazgeç',
    String confirmText = 'Sil',
    IconData? icon,
  }) {
    return showModernDialog<bool>(
      context: context,
      builder: (context) => ModernAnimatedDialog(
        type: DialogType.danger,
        icon: icon ?? Icons.delete_forever_rounded,
        title: title,
        subtitle: subtitle,
        content: content,
        cancelText: cancelText,
        confirmText: confirmText,
      ),
    );
  }

  /// Uyarı dialogu göster
  static Future<bool?> showWarning({
    required BuildContext context,
    required String title,
    String? subtitle,
    Widget? content,
    String cancelText = 'İptal',
    String confirmText = 'Devam Et',
    IconData? icon,
  }) {
    return showModernDialog<bool>(
      context: context,
      builder: (context) => ModernAnimatedDialog(
        type: DialogType.warning,
        icon: icon ?? Icons.warning_amber_rounded,
        title: title,
        subtitle: subtitle,
        content: content,
        cancelText: cancelText,
        confirmText: confirmText,
      ),
    );
  }

  /// Loading dialogu göster
  static Future<void> showLoading({
    required BuildContext context,
    required String message,
    String? subtitle,
    Color color = Colors.red,
  }) {
    return showModernDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => PopScope(
        canPop: false,
        child: ModernLoadingDialog(
          message: message,
          subtitle: subtitle,
          color: color,
        ),
      ),
    );
  }

  /// Bilgi dialogu göster (sadece OK butonu)
  static Future<void> showInfo({
    required BuildContext context,
    required String title,
    String? subtitle,
    Widget? content,
    String buttonText = 'Tamam',
    IconData? icon,
  }) {
    return showModernDialog(
      context: context,
      builder: (context) => ModernAnimatedDialog(
        type: DialogType.info,
        icon: icon,
        title: title,
        subtitle: subtitle,
        content: content,
        showCancelButton: false,
        confirmText: buttonText,
      ),
    );
  }
}
