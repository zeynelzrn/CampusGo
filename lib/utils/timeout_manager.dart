import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/connectivity_provider.dart';

/// Timeout yönetimi için kullanılan widget
///
/// Uzun süren yükleme işlemlerini takip eder ve:
/// 1. Belirtilen süre sonunda timeout mesajı gösterir
/// 2. Manuel yeniden deneme butonu sunar
/// 3. İnternet geldiğinde otomatik yeniden dener (opsiyonel)
class TimeoutWrapper extends ConsumerStatefulWidget {
  /// Yükleniyor mu?
  final bool isLoading;

  /// Yükleme başarılı mı?
  final bool hasData;

  /// Hata var mı?
  final bool hasError;

  /// Hata mesajı
  final String? errorMessage;

  /// Normal içerik (yükleme tamamlandığında)
  final Widget child;

  /// Yükleme widget'ı
  final Widget? loadingWidget;

  /// Timeout süresi (varsayılan: 15 saniye)
  final Duration timeout;

  /// Yeniden deneme callback'i
  final VoidCallback? onRetry;

  /// İnternet geldiğinde otomatik yeniden dene
  final bool autoRetryOnInternet;

  /// Timeout sonrası gösterilecek mesaj
  final String? timeoutMessage;

  /// Hata sonrası gösterilecek custom widget
  final Widget? errorWidget;

  const TimeoutWrapper({
    super.key,
    required this.isLoading,
    required this.hasData,
    required this.child,
    this.hasError = false,
    this.errorMessage,
    this.loadingWidget,
    this.timeout = const Duration(seconds: 15),
    this.onRetry,
    this.autoRetryOnInternet = true,
    this.timeoutMessage,
    this.errorWidget,
  });

  @override
  ConsumerState<TimeoutWrapper> createState() => _TimeoutWrapperState();
}

class _TimeoutWrapperState extends ConsumerState<TimeoutWrapper> {
  Timer? _timeoutTimer;
  bool _isTimedOut = false;
  StreamSubscription<void>? _internetRestoredSub;

  @override
  void initState() {
    super.initState();
    _setupTimeout();
    if (widget.autoRetryOnInternet) {
      _listenToInternetRestored();
    }
  }

  @override
  void didUpdateWidget(TimeoutWrapper oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Yükleme durumu değiştiyse timer'ı sıfırla
    if (widget.isLoading != oldWidget.isLoading) {
      if (widget.isLoading) {
        _setupTimeout();
      } else {
        _cancelTimeout();
      }
    }

    // Timeout süresi değiştiyse yeniden başlat
    if (widget.timeout != oldWidget.timeout && widget.isLoading) {
      _setupTimeout();
    }
  }

  @override
  void dispose() {
    _timeoutTimer?.cancel();
    _internetRestoredSub?.cancel();
    super.dispose();
  }

  void _setupTimeout() {
    _timeoutTimer?.cancel();
    _isTimedOut = false;

    if (widget.isLoading) {
      _timeoutTimer = Timer(widget.timeout, () {
        if (mounted && widget.isLoading) {
          setState(() => _isTimedOut = true);
        }
      });
    }
  }

  void _cancelTimeout() {
    _timeoutTimer?.cancel();
    if (_isTimedOut && mounted) {
      setState(() => _isTimedOut = false);
    }
  }

  void _listenToInternetRestored() {
    final notifier = ref.read(connectivityProvider.notifier);
    _internetRestoredSub = notifier.onInternetRestored.listen((_) {
      if ((_isTimedOut || widget.hasError) && widget.onRetry != null && mounted) {
        debugPrint('TimeoutWrapper: Internet restored, auto-retrying...');
        _handleRetry();
      }
    });
  }

  void _handleRetry() {
    setState(() => _isTimedOut = false);
    _setupTimeout();
    widget.onRetry?.call();
  }

  @override
  Widget build(BuildContext context) {
    final isOnline = ref.watch(isOnlineProvider);

    // Veri varsa normal içeriği göster
    if (widget.hasData && !widget.isLoading) {
      return widget.child;
    }

    // Hata varsa hata widget'ını göster
    if (widget.hasError) {
      return widget.errorWidget ?? _buildErrorWidget(isOnline);
    }

    // Timeout olduysa timeout widget'ını göster
    if (_isTimedOut) {
      return _buildTimeoutWidget(isOnline);
    }

    // Yükleniyor
    if (widget.isLoading) {
      return widget.loadingWidget ?? _buildDefaultLoading();
    }

    // Varsayılan: child'ı göster
    return widget.child;
  }

  Widget _buildDefaultLoading() {
    return const Center(
      child: CircularProgressIndicator(
        valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF5C6BC0)),
      ),
    );
  }

  Widget _buildTimeoutWidget(bool isOnline) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // İkon
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: (isOnline ? Colors.orange : Colors.grey).withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isOnline ? Icons.hourglass_empty_rounded : Icons.wifi_off_rounded,
                size: 48,
                color: isOnline ? Colors.orange : Colors.grey,
              ),
            ),
            const SizedBox(height: 24),

            // Başlık
            Text(
              isOnline ? 'Yükleme Zaman Aşımı' : 'Bağlantı Yok',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
              ),
            ),
            const SizedBox(height: 8),

            // Açıklama
            Text(
              widget.timeoutMessage ??
                  (isOnline
                      ? 'Yükleme beklenenden uzun sürüyor.\nLütfen tekrar deneyin.'
                      : 'İnternet bağlantınızı kontrol edin.\nBağlantı sağlandığında otomatik yüklenecek.'),
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: Colors.grey[600],
                height: 1.5,
              ),
            ),
            const SizedBox(height: 24),

            // Yeniden dene butonu
            if (widget.onRetry != null && isOnline)
              ElevatedButton.icon(
                onPressed: _handleRetry,
                icon: const Icon(Icons.refresh, color: Colors.white),
                label: Text(
                  'Tekrar Dene',
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF5C6BC0),
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),

            // Offline ise bekleme animasyonu
            if (!isOnline) ...[
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.grey[400]!),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Bağlantı bekleniyor...',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: Colors.grey[500],
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildErrorWidget(bool isOnline) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // İkon
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.error_outline_rounded,
                size: 48,
                color: Colors.red,
              ),
            ),
            const SizedBox(height: 24),

            // Başlık
            Text(
              'Bir Hata Oluştu',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
              ),
            ),
            const SizedBox(height: 8),

            // Hata mesajı
            Text(
              widget.errorMessage ?? 'Veriler yüklenirken bir sorun oluştu.',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: Colors.grey[600],
                height: 1.5,
              ),
            ),
            const SizedBox(height: 24),

            // Yeniden dene butonu
            if (widget.onRetry != null)
              ElevatedButton.icon(
                onPressed: _handleRetry,
                icon: const Icon(Icons.refresh, color: Colors.white),
                label: Text(
                  'Tekrar Dene',
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF5C6BC0),
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
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
}

/// AsyncValue için timeout extension
extension AsyncValueTimeout<T> on AsyncValue<T> {
  /// AsyncValue'yu TimeoutWrapper ile sar
  Widget whenWithTimeout({
    required Widget Function(T data) data,
    required Widget Function() loading,
    required Widget Function(Object error, StackTrace stack) error,
    Duration timeout = const Duration(seconds: 15),
    VoidCallback? onRetry,
    bool autoRetryOnInternet = true,
  }) {
    return TimeoutWrapper(
      isLoading: isLoading,
      hasData: hasValue && !isLoading,
      hasError: hasError,
      errorMessage: this.error?.toString(),
      timeout: timeout,
      onRetry: onRetry,
      autoRetryOnInternet: autoRetryOnInternet,
      child: when(
        data: data,
        loading: loading,
        error: error,
      ),
    );
  }
}

/// Future için timeout helper
class TimeoutFuture {
  /// Future'ı timeout ile çalıştır
  static Future<T> run<T>(
    Future<T> future, {
    Duration timeout = const Duration(seconds: 30),
    T? fallbackValue,
    String? timeoutMessage,
  }) async {
    try {
      return await future.timeout(
        timeout,
        onTimeout: () {
          debugPrint('TimeoutFuture: Operation timed out after ${timeout.inSeconds}s');
          if (fallbackValue != null) {
            return fallbackValue;
          }
          throw TimeoutException(
            timeoutMessage ?? 'İşlem zaman aşımına uğradı',
            timeout,
          );
        },
      );
    } catch (e) {
      debugPrint('TimeoutFuture: Error: $e');
      rethrow;
    }
  }

  /// Retry mekanizmalı future
  static Future<T> withRetry<T>(
    Future<T> Function() futureBuilder, {
    int maxRetries = 3,
    Duration retryDelay = const Duration(seconds: 2),
    Duration timeout = const Duration(seconds: 30),
    bool Function(Object error)? shouldRetry,
  }) async {
    int attempt = 0;
    Object? lastError;
    StackTrace? lastStack;

    while (attempt < maxRetries) {
      try {
        return await futureBuilder().timeout(timeout);
      } catch (e, stack) {
        lastError = e;
        lastStack = stack;
        attempt++;

        // Retry gerekli mi kontrol et
        final shouldRetryError = shouldRetry?.call(e) ?? true;
        if (!shouldRetryError || attempt >= maxRetries) {
          break;
        }

        debugPrint('TimeoutFuture: Attempt $attempt failed, retrying in ${retryDelay.inSeconds}s...');
        await Future.delayed(retryDelay);
      }
    }

    debugPrint('TimeoutFuture: All $maxRetries attempts failed');
    Error.throwWithStackTrace(lastError!, lastStack!);
  }
}

/// Exponential backoff ile retry
class ExponentialBackoff {
  final int maxRetries;
  final Duration initialDelay;
  final double multiplier;
  final Duration maxDelay;

  const ExponentialBackoff({
    this.maxRetries = 5,
    this.initialDelay = const Duration(seconds: 1),
    this.multiplier = 2.0,
    this.maxDelay = const Duration(seconds: 30),
  });

  /// Retry mekanizmalı future çalıştır
  Future<T> run<T>(Future<T> Function() operation) async {
    Duration delay = initialDelay;
    Object? lastError;
    StackTrace? lastStack;

    for (int attempt = 0; attempt < maxRetries; attempt++) {
      try {
        return await operation();
      } catch (e, stack) {
        lastError = e;
        lastStack = stack;

        if (attempt < maxRetries - 1) {
          debugPrint('ExponentialBackoff: Attempt ${attempt + 1} failed, waiting ${delay.inMilliseconds}ms...');
          await Future.delayed(delay);

          // Delay'i artır
          delay = Duration(
            milliseconds: (delay.inMilliseconds * multiplier).toInt(),
          );
          if (delay > maxDelay) delay = maxDelay;
        }
      }
    }

    debugPrint('ExponentialBackoff: All $maxRetries attempts failed');
    Error.throwWithStackTrace(lastError!, lastStack!);
  }
}
