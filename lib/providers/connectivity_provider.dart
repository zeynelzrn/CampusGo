import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:internet_connection_checker_plus/internet_connection_checker_plus.dart';

/// Callback type for when internet is restored
typedef OnInternetRestoredCallback = void Function();

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

  /// Callbacks to trigger when internet is restored
  final List<OnInternetRestoredCallback> _onRestoredCallbacks = [];

  /// Stream controller for internet restored events
  final _restoredController = StreamController<void>.broadcast();

  /// Stream that emits when internet is restored (for auto-refresh)
  Stream<void> get onInternetRestored => _restoredController.stream;

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

  /// Register a callback to be called when internet is restored
  void addOnRestoredCallback(OnInternetRestoredCallback callback) {
    _onRestoredCallbacks.add(callback);
  }

  /// Remove a registered callback
  void removeOnRestoredCallback(OnInternetRestoredCallback callback) {
    _onRestoredCallbacks.remove(callback);
  }

  /// Notify all registered callbacks that internet is restored
  void _notifyInternetRestored() {
    debugPrint('ConnectivityProvider: Internet restored - triggering ${_onRestoredCallbacks.length} callbacks');
    _restoredController.add(null);
    for (final callback in _onRestoredCallbacks) {
      try {
        callback();
      } catch (e) {
        debugPrint('ConnectivityProvider: Callback error: $e');
      }
    }
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

        // Trigger auto-refresh callbacks when internet is restored
        if (isConnected && wasOffline) {
          _notifyInternetRestored();
        }

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
    _restoredController.close();
    _onRestoredCallbacks.clear();
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

/// Stream provider for internet restored events
/// Use this to trigger auto-refresh when internet comes back
final internetRestoredProvider = StreamProvider<void>((ref) {
  final notifier = ref.watch(connectivityProvider.notifier);
  return notifier.onInternetRestored;
});

/// Provider to access the connectivity notifier for registering callbacks
final connectivityNotifierProvider = Provider<ConnectivityNotifier>((ref) {
  return ref.watch(connectivityProvider.notifier);
});

// =============================================================================
// GLOBAL IMAGE REFRESH SYSTEM
// =============================================================================

/// Global image refresh key - increments when internet is restored
/// All CachedNetworkImage widgets should watch this to force refresh
class ImageRefreshNotifier extends StateNotifier<int> {
  StreamSubscription<void>? _subscription;

  ImageRefreshNotifier(Ref ref) : super(0) {
    // Listen to internet restored events
    final notifier = ref.read(connectivityProvider.notifier);
    _subscription = notifier.onInternetRestored.listen((_) {
      _incrementKey();
    });
  }

  /// Increment the refresh key to force all images to reload
  void _incrementKey() {
    state = state + 1;
    debugPrint('ImageRefreshNotifier: Key incremented to $state - all images will refresh');
  }

  /// Manually trigger a refresh (for pull-to-refresh, etc.)
  void forceRefresh() {
    _incrementKey();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}

/// Global image refresh key provider
/// Watch this in CachedNetworkImage widgets to auto-refresh when internet returns
final imageRefreshKeyProvider = StateNotifierProvider<ImageRefreshNotifier, int>((ref) {
  return ImageRefreshNotifier(ref);
});

/// Helper provider that combines online status + refresh key
/// Use this for widgets that need both connectivity awareness and auto-refresh
final imageLoadingStateProvider = Provider<ImageLoadingState>((ref) {
  final isOnline = ref.watch(isOnlineProvider);
  final refreshKey = ref.watch(imageRefreshKeyProvider);
  return ImageLoadingState(isOnline: isOnline, refreshKey: refreshKey);
});

/// State class for image loading
class ImageLoadingState {
  final bool isOnline;
  final int refreshKey;

  const ImageLoadingState({
    required this.isOnline,
    required this.refreshKey,
  });

  /// Unique key for CachedNetworkImage to force rebuild
  String get cacheKey => 'v$refreshKey';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ImageLoadingState &&
          isOnline == other.isOnline &&
          refreshKey == other.refreshKey;

  @override
  int get hashCode => isOnline.hashCode ^ refreshKey.hashCode;
}

// =============================================================================
// AUTO DATA REFRESH SYSTEM
// =============================================================================

/// Mixin for widgets that need to auto-refresh data when internet is restored
/// Usage:
/// ```dart
/// class MyScreen extends ConsumerStatefulWidget { ... }
/// class _MyScreenState extends ConsumerState<MyScreen> with AutoRefreshMixin {
///   @override
///   List<ProviderOrFamily> get providersToRefresh => [myDataProvider];
/// }
/// ```
mixin AutoRefreshMixin<T extends ConsumerStatefulWidget> on ConsumerState<T> {
  StreamSubscription<void>? _autoRefreshSub;

  /// Override this to specify which providers should be refreshed
  List<ProviderOrFamily> get providersToRefresh => [];

  /// Override this to add custom refresh logic
  void onInternetRestored() {}

  @override
  void initState() {
    super.initState();
    _setupAutoRefresh();
  }

  @override
  void dispose() {
    _autoRefreshSub?.cancel();
    super.dispose();
  }

  void _setupAutoRefresh() {
    final notifier = ref.read(connectivityProvider.notifier);
    _autoRefreshSub = notifier.onInternetRestored.listen((_) {
      debugPrint('AutoRefreshMixin: Internet restored, refreshing ${providersToRefresh.length} providers');

      // Invalidate all specified providers
      for (final provider in providersToRefresh) {
        ref.invalidate(provider);
      }

      // Call custom refresh logic
      onInternetRestored();
    });
  }
}

/// Helper class for global provider invalidation
/// Call this from anywhere to refresh data when internet is restored
class DataRefreshHelper {
  static final List<ProviderOrFamily> _globalProviders = [];

  /// Register a provider for global auto-refresh
  static void registerProvider(ProviderOrFamily provider) {
    if (!_globalProviders.contains(provider)) {
      _globalProviders.add(provider);
      debugPrint('DataRefreshHelper: Registered ${provider.runtimeType}');
    }
  }

  /// Unregister a provider
  static void unregisterProvider(ProviderOrFamily provider) {
    _globalProviders.remove(provider);
  }

  /// Invalidate all registered providers
  static void refreshAll(WidgetRef ref) {
    debugPrint('DataRefreshHelper: Refreshing ${_globalProviders.length} global providers');
    for (final provider in _globalProviders) {
      ref.invalidate(provider);
    }
  }

  /// Get registered provider count
  static int get registeredCount => _globalProviders.length;
}
