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

/// State notifier for managing local UI state (eliminated, dismissing, removed)
class LikesUIState {
  final Set<String> eliminatedUserIds;
  final Set<String> dismissingUserIds;
  /// Kullanıcılar bu set'e eklendiğinde listeden tamamen çıkarılır (filtrelenir)
  final Set<String> removedUserIds;

  const LikesUIState({
    this.eliminatedUserIds = const {},
    this.dismissingUserIds = const {},
    this.removedUserIds = const {},
  });

  LikesUIState copyWith({
    Set<String>? eliminatedUserIds,
    Set<String>? dismissingUserIds,
    Set<String>? removedUserIds,
  }) {
    return LikesUIState(
      eliminatedUserIds: eliminatedUserIds ?? this.eliminatedUserIds,
      dismissingUserIds: dismissingUserIds ?? this.dismissingUserIds,
      removedUserIds: removedUserIds ?? this.removedUserIds,
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

  /// Mark user as blocked - removes from UI immediately
  /// Stream will also update from Firestore, but this provides instant feedback
  void markAsBlocked(String userId) {
    final eliminatedSet = {...state.eliminatedUserIds, userId};
    final dismissingSet = {...state.dismissingUserIds, userId};
    state = state.copyWith(
      eliminatedUserIds: eliminatedSet,
      dismissingUserIds: dismissingSet,
    );
  }

  /// Kullanıcıyı listeden tamamen kaldır (animasyon bittikten sonra çağrılır)
  /// Bu metot çağrıldığında kart Grid'den fiziksel olarak çıkar ve diğer kartlar kayar
  void removeUser(String userId) {
    final removedSet = {...state.removedUserIds, userId};
    // Ayrıca diğer set'lerden de temizle
    final eliminatedSet = {...state.eliminatedUserIds}..remove(userId);
    final dismissingSet = {...state.dismissingUserIds}..remove(userId);
    state = state.copyWith(
      removedUserIds: removedSet,
      eliminatedUserIds: eliminatedSet,
      dismissingUserIds: dismissingSet,
    );
  }

  /// Birden fazla kullanıcıyı aynı anda kaldır
  void removeUsers(Set<String> userIds) {
    final removedSet = {...state.removedUserIds, ...userIds};
    final eliminatedSet = {...state.eliminatedUserIds}..removeAll(userIds);
    final dismissingSet = {...state.dismissingUserIds}..removeAll(userIds);
    state = state.copyWith(
      removedUserIds: removedSet,
      eliminatedUserIds: eliminatedSet,
      dismissingUserIds: dismissingSet,
    );
  }

  /// Engeli kaldırılan kullanıcıyı tüm set'lerden çıkar
  /// Bu sayede kullanıcı tekrar listeye dahil edilebilir
  void restoreUser(String userId) {
    final removedSet = {...state.removedUserIds}..remove(userId);
    final eliminatedSet = {...state.eliminatedUserIds}..remove(userId);
    final dismissingSet = {...state.dismissingUserIds}..remove(userId);
    state = state.copyWith(
      removedUserIds: removedSet,
      eliminatedUserIds: eliminatedSet,
      dismissingUserIds: dismissingSet,
    );
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
