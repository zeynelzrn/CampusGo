import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/user_profile.dart';
import '../repositories/likes_repository.dart';

/// Provider for LikesRepository instance
final likesRepositoryProvider = Provider<LikesRepository>((ref) {
  return LikesRepository();
});

/// Stream provider for received likes (real-time updates)
final receivedLikesProvider = StreamProvider<List<UserProfile>>((ref) {
  final repository = ref.watch(likesRepositoryProvider);
  return repository.watchReceivedLikes();
});

/// Provider for eliminated user IDs (disliked users)
final eliminatedUserIdsProvider = FutureProvider<Set<String>>((ref) async {
  final repository = ref.watch(likesRepositoryProvider);
  return repository.getEliminatedUserIds();
});

/// State notifier for managing local UI state (eliminated, dismissing)
class LikesUIState {
  final Set<String> eliminatedUserIds;
  final Set<String> dismissingUserIds;

  const LikesUIState({
    this.eliminatedUserIds = const {},
    this.dismissingUserIds = const {},
  });

  LikesUIState copyWith({
    Set<String>? eliminatedUserIds,
    Set<String>? dismissingUserIds,
  }) {
    return LikesUIState(
      eliminatedUserIds: eliminatedUserIds ?? this.eliminatedUserIds,
      dismissingUserIds: dismissingUserIds ?? this.dismissingUserIds,
    );
  }
}

class LikesUINotifier extends StateNotifier<LikesUIState> {
  LikesUINotifier() : super(const LikesUIState());

  void initializeEliminatedIds(Set<String> ids) {
    state = state.copyWith(eliminatedUserIds: ids);
  }

  void markAsEliminated(String userId) {
    final newSet = {...state.eliminatedUserIds, userId};
    state = state.copyWith(eliminatedUserIds: newSet);
  }

  void startDismissing(String userId) {
    final newSet = {...state.dismissingUserIds, userId};
    state = state.copyWith(dismissingUserIds: newSet);
  }

  void finishDismissing(String userId) {
    final eliminatedSet = {...state.eliminatedUserIds}..remove(userId);
    final dismissingSet = {...state.dismissingUserIds}..remove(userId);
    state = state.copyWith(
      eliminatedUserIds: eliminatedSet,
      dismissingUserIds: dismissingSet,
    );
  }

  void cancelDismissing(String userId) {
    final newSet = {...state.dismissingUserIds}..remove(userId);
    state = state.copyWith(dismissingUserIds: newSet);
  }

  void reset() {
    state = const LikesUIState();
  }
}

/// Provider for likes UI state notifier
final likesUIProvider =
    StateNotifierProvider<LikesUINotifier, LikesUIState>((ref) {
  return LikesUINotifier();
});
