import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_profile.dart';
import '../repositories/swipe_repository.dart';

/// Swipe state
class SwipeState {
  final List<UserProfile> profiles;
  final Set<String> excludedIds;
  final bool isLoading;
  final bool hasMore;
  final String? error;
  final DocumentSnapshot? lastDocument;
  final UserProfile? lastSwipedProfile; // For undo functionality
  final bool isMatch;
  final String? genderFilter;

  const SwipeState({
    this.profiles = const [],
    this.excludedIds = const {},
    this.isLoading = false,
    this.hasMore = true,
    this.error,
    this.lastDocument,
    this.lastSwipedProfile,
    this.isMatch = false,
    this.genderFilter,
  });

  SwipeState copyWith({
    List<UserProfile>? profiles,
    Set<String>? excludedIds,
    bool? isLoading,
    bool? hasMore,
    String? error,
    DocumentSnapshot? lastDocument,
    UserProfile? lastSwipedProfile,
    bool? isMatch,
    String? genderFilter,
    bool clearError = false,
    bool clearLastDocument = false,
    bool clearLastSwiped = false,
    bool clearMatch = false,
  }) {
    return SwipeState(
      profiles: profiles ?? this.profiles,
      excludedIds: excludedIds ?? this.excludedIds,
      isLoading: isLoading ?? this.isLoading,
      hasMore: hasMore ?? this.hasMore,
      error: clearError ? null : (error ?? this.error),
      lastDocument:
          clearLastDocument ? null : (lastDocument ?? this.lastDocument),
      lastSwipedProfile: clearLastSwiped
          ? null
          : (lastSwipedProfile ?? this.lastSwipedProfile),
      isMatch: clearMatch ? false : (isMatch ?? this.isMatch),
      genderFilter: genderFilter ?? this.genderFilter,
    );
  }

  /// Check if prefetch is needed (3 or fewer cards remaining)
  bool get shouldPrefetch => profiles.length <= 3 && hasMore && !isLoading;

  /// Check if there are no more profiles
  bool get isEmpty => profiles.isEmpty && !isLoading && !hasMore;
}

/// Swipe notifier for managing state
class SwipeNotifier extends StateNotifier<SwipeState> {
  final SwipeRepository _repository;

  // Prefetch threshold
  static const int prefetchThreshold = 3;
  // Minimum cards to show
  static const int minCardsInStack = 10;

  SwipeNotifier(this._repository) : super(const SwipeState()) {
    _initialize();
  }

  /// Initialize the provider
  Future<void> _initialize() async {
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      // 1. Fetch all action IDs for client-side filtering
      final excludedIds = await _repository.fetchAllActionIds();

      // 2. Get user's preference for gender filter
      final genderFilter = await _repository.getUserLookingForPreference();

      state = state.copyWith(
        excludedIds: excludedIds,
        genderFilter: genderFilter,
        isLoading: false,
      );

      // 3. Fetch initial batch of profiles
      await _fetchNextBatch();
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Profiller yüklenirken bir hata oluştu',
      );
    }
  }

  /// Fetch next batch of profiles with filtering
  Future<void> _fetchNextBatch() async {
    if (!state.hasMore || state.isLoading) return;

    state = state.copyWith(isLoading: true);

    try {
      int attempts = 0;
      const maxAttempts = 5; // Prevent infinite loops
      List<UserProfile> filteredProfiles = [];

      // Keep fetching until we have enough profiles or no more data
      while (
          filteredProfiles.length < minCardsInStack && attempts < maxAttempts) {
        final batch = await _repository.fetchUserBatch(
          lastDocument: state.lastDocument,
          genderFilter: state.genderFilter,
        );

        if (batch.isEmpty) {
          // No more data available
          state = state.copyWith(
            hasMore: false,
            isLoading: false,
          );
          break;
        }

        // Apply client-side filtering
        final newProfiles = batch
            .where((profile) =>
                !state.excludedIds.contains(profile.id) &&
                !state.profiles.any((p) => p.id == profile.id) &&
                !filteredProfiles.any((p) => p.id == profile.id))
            .toList();

        filteredProfiles.addAll(newProfiles);

        // Update last document for pagination
        // Note: We need to track the actual Firestore document for pagination
        attempts++;
      }

      // Add filtered profiles to state
      state = state.copyWith(
        profiles: [...state.profiles, ...filteredProfiles],
        isLoading: false,
        hasMore: filteredProfiles.isNotEmpty,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Profiller yüklenirken bir hata oluştu: $e',
      );
    }
  }

  /// Handle swipe action
  Future<void> onSwipe(int index, SwipeActionType actionType) async {
    if (index < 0 || index >= state.profiles.length) return;

    final swipedProfile = state.profiles[index];

    // 1. Optimistically update UI
    final updatedProfiles = List<UserProfile>.from(state.profiles);
    updatedProfiles.removeAt(index);

    // 2. Add to excluded IDs
    final updatedExcludedIds = Set<String>.from(state.excludedIds)
      ..add(swipedProfile.id);

    state = state.copyWith(
      profiles: updatedProfiles,
      excludedIds: updatedExcludedIds,
      lastSwipedProfile: swipedProfile,
      clearMatch: true,
    );

    // 3. Record action in Firestore (async, don't wait)
    _recordSwipeAction(swipedProfile.id, actionType);

    // 4. Check if prefetch is needed
    if (state.shouldPrefetch) {
      _fetchNextBatch();
    }
  }

  /// Record swipe action and check for match
  Future<void> _recordSwipeAction(
      String targetUserId, SwipeActionType actionType) async {
    try {
      final isMatch = await _repository.recordSwipeAction(
        targetUserId: targetUserId,
        actionType: actionType,
      );

      // If it's a like and resulted in a match, notify
      if (isMatch &&
          (actionType == SwipeActionType.like ||
              actionType == SwipeActionType.superlike)) {
        state = state.copyWith(isMatch: true);
      }
    } catch (e) {
      // Silent fail for background operation
      print('Error recording swipe: $e');
    }
  }

  /// Swipe left (dislike)
  Future<void> swipeLeft(int index) async {
    await onSwipe(index, SwipeActionType.dislike);
  }

  /// Swipe right (like)
  Future<void> swipeRight(int index) async {
    await onSwipe(index, SwipeActionType.like);
  }

  /// Super like
  Future<void> superLike(int index) async {
    await onSwipe(index, SwipeActionType.superlike);
  }

  /// Undo last swipe
  Future<bool> undoLastSwipe() async {
    final lastSwiped = state.lastSwipedProfile;
    if (lastSwiped == null) return false;

    try {
      // Remove from excluded IDs
      final updatedExcludedIds = Set<String>.from(state.excludedIds)
        ..remove(lastSwiped.id);

      // Add back to profiles at the beginning
      final updatedProfiles = [lastSwiped, ...state.profiles];

      // Delete action from Firestore
      await _repository.undoLastSwipe(lastSwiped.id);

      state = state.copyWith(
        profiles: updatedProfiles,
        excludedIds: updatedExcludedIds,
        clearLastSwiped: true,
      );

      return true;
    } catch (e) {
      print('Error undoing swipe: $e');
      return false;
    }
  }

  /// Refresh profiles
  Future<void> refresh() async {
    state = const SwipeState();
    await _initialize();
  }

  /// Clear match notification
  void clearMatchNotification() {
    state = state.copyWith(clearMatch: true);
  }

  /// Update gender filter
  Future<void> updateGenderFilter(String? gender) async {
    state = state.copyWith(
      genderFilter: gender,
      profiles: [],
      hasMore: true,
      clearLastDocument: true,
    );
    await _fetchNextBatch();
  }
}

/// Repository provider
final swipeRepositoryProvider = Provider<SwipeRepository>((ref) {
  return SwipeRepository();
});

/// Swipe state provider
final swipeProvider = StateNotifierProvider<SwipeNotifier, SwipeState>((ref) {
  final repository = ref.watch(swipeRepositoryProvider);
  return SwipeNotifier(repository);
});

/// Matches stream provider
final matchesProvider = StreamProvider<List<Match>>((ref) {
  final repository = ref.watch(swipeRepositoryProvider);
  return repository.watchMatches();
});

/// Current profile at index provider
final profileAtIndexProvider = Provider.family<UserProfile?, int>((ref, index) {
  final state = ref.watch(swipeProvider);
  if (index < 0 || index >= state.profiles.length) return null;
  return state.profiles[index];
});
