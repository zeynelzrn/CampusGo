import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:internet_connection_checker_plus/internet_connection_checker_plus.dart';

/// Connectivity status for the app
enum ConnectivityStatus {
  connected,
  disconnected,
  checking,
}

/// Connectivity state with metadata
class ConnectivityState {
  final ConnectivityStatus status;
  final DateTime? lastChanged;
  final bool wasOffline; // For showing "back online" message

  const ConnectivityState({
    this.status = ConnectivityStatus.checking,
    this.lastChanged,
    this.wasOffline = false,
  });

  bool get isConnected => status == ConnectivityStatus.connected;
  bool get isDisconnected => status == ConnectivityStatus.disconnected;
  bool get isChecking => status == ConnectivityStatus.checking;

  ConnectivityState copyWith({
    ConnectivityStatus? status,
    DateTime? lastChanged,
    bool? wasOffline,
  }) {
    return ConnectivityState(
      status: status ?? this.status,
      lastChanged: lastChanged ?? this.lastChanged,
      wasOffline: wasOffline ?? this.wasOffline,
    );
  }

  @override
  String toString() => 'ConnectivityState(status: $status, wasOffline: $wasOffline)';
}

/// Connectivity notifier using REAL internet check (ping to Google)
class ConnectivityNotifier extends StateNotifier<ConnectivityState> {
  StreamSubscription<InternetStatus>? _subscription;
  final InternetConnection _checker;

  ConnectivityNotifier()
      : _checker = InternetConnection.createInstance(
          customCheckOptions: [
            InternetCheckOption(
              uri: Uri.parse('https://www.google.com'),
              timeout: const Duration(seconds: 5),
            ),
            InternetCheckOption(
              uri: Uri.parse('https://www.cloudflare.com'),
              timeout: const Duration(seconds: 5),
            ),
            InternetCheckOption(
              uri: Uri.parse('https://www.apple.com'),
              timeout: const Duration(seconds: 5),
            ),
          ],
          checkInterval: const Duration(seconds: 10),
        ),
        super(const ConnectivityState()) {
    _initialize();
  }

  /// Initialize with immediate check + stream listener
  Future<void> _initialize() async {
    debugPrint('ConnectivityProvider: Initializing with REAL internet check...');

    // Initial check
    try {
      final hasInternet = await _checker.hasInternetAccess;
      debugPrint('ConnectivityProvider: Initial check = $hasInternet');

      state = state.copyWith(
        status: hasInternet ? ConnectivityStatus.connected : ConnectivityStatus.disconnected,
        lastChanged: DateTime.now(),
      );
    } catch (e) {
      debugPrint('ConnectivityProvider: Initial check error: $e');
      state = state.copyWith(
        status: ConnectivityStatus.disconnected,
        lastChanged: DateTime.now(),
      );
    }

    // Listen to status changes
    _subscription = _checker.onStatusChange.listen(
      (InternetStatus status) {
        final isConnected = status == InternetStatus.connected;
        final wasOffline = state.isDisconnected;

        debugPrint('ConnectivityProvider: Status changed to $status (wasOffline: $wasOffline)');

        state = state.copyWith(
          status: isConnected ? ConnectivityStatus.connected : ConnectivityStatus.disconnected,
          lastChanged: DateTime.now(),
          wasOffline: isConnected && wasOffline, // True only when coming back online
        );

        // Clear wasOffline flag after delay
        if (state.wasOffline) {
          Future.delayed(const Duration(seconds: 3), () {
            if (mounted && state.wasOffline) {
              state = state.copyWith(wasOffline: false);
            }
          });
        }
      },
      onError: (error) {
        debugPrint('ConnectivityProvider: Stream error: $error');
      },
    );
  }

  /// Manually trigger a connectivity check
  Future<bool> checkNow() async {
    debugPrint('ConnectivityProvider: Manual check triggered');
    try {
      final hasInternet = await _checker.hasInternetAccess;
      final wasOffline = state.isDisconnected;

      state = state.copyWith(
        status: hasInternet ? ConnectivityStatus.connected : ConnectivityStatus.disconnected,
        lastChanged: DateTime.now(),
        wasOffline: hasInternet && wasOffline,
      );

      return hasInternet;
    } catch (e) {
      debugPrint('ConnectivityProvider: Manual check error: $e');
      return false;
    }
  }

  /// Force offline state (for debug/testing)
  void setDebugOffline(bool offline) {
    debugPrint('ConnectivityProvider: DEBUG - Setting offline = $offline');
    final wasOffline = state.isDisconnected;

    state = state.copyWith(
      status: offline ? ConnectivityStatus.disconnected : ConnectivityStatus.connected,
      lastChanged: DateTime.now(),
      wasOffline: !offline && wasOffline,
    );
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}

/// Global connectivity provider
final connectivityProvider = StateNotifierProvider<ConnectivityNotifier, ConnectivityState>((ref) {
  return ConnectivityNotifier();
});

/// Simple boolean provider for quick checks
final isOnlineProvider = Provider<bool>((ref) {
  return ref.watch(connectivityProvider).isConnected;
});

/// Provider that only triggers on status changes
final connectivityStatusProvider = Provider<ConnectivityStatus>((ref) {
  return ref.watch(connectivityProvider).status;
});
