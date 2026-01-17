import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../repositories/profile_repository.dart';
import '../models/user_profile.dart';

/// App startup state
enum AppStartupState {
  loading,
  unauthenticated,
  needsProfile,
  authenticated,
}

/// State for app startup/auth check
class AppState {
  final AppStartupState status;
  final String? error;

  const AppState({
    this.status = AppStartupState.loading,
    this.error,
  });

  AppState copyWith({
    AppStartupState? status,
    String? error,
    bool clearError = false,
  }) {
    return AppState(
      status: status ?? this.status,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

/// App state notifier - handles auth + profile check
class AppStateNotifier extends StateNotifier<AppState> {
  final ProfileRepository _profileRepository;

  AppStateNotifier(this._profileRepository) : super(const AppState()) {
    _initialize();
  }

  Future<void> _initialize() async {
    await checkAuthAndProfile();
  }

  Future<void> checkAuthAndProfile() async {
    state = state.copyWith(status: AppStartupState.loading, clearError: true);

    try {
      final user = FirebaseAuth.instance.currentUser;

      if (user == null) {
        state = state.copyWith(status: AppStartupState.unauthenticated);
        return;
      }

      // User is logged in, check if they have a profile
      final hasProfile = await _profileRepository.hasProfile();

      if (hasProfile) {
        state = state.copyWith(status: AppStartupState.authenticated);
      } else {
        state = state.copyWith(status: AppStartupState.needsProfile);
      }
    } catch (e) {
      state = state.copyWith(
        status: AppStartupState.unauthenticated,
        error: e.toString(),
      );
    }
  }

  void setAuthenticated() {
    state = state.copyWith(status: AppStartupState.authenticated);
  }

  void setNeedsProfile() {
    state = state.copyWith(status: AppStartupState.needsProfile);
  }

  void setUnauthenticated() {
    state = state.copyWith(status: AppStartupState.unauthenticated);
  }
}

/// Profile creation state
enum ProfileCreationStatus {
  idle,
  uploadingImage,
  savingProfile,
  success,
  error,
}

class ProfileCreationState {
  final ProfileCreationStatus status;
  final String? error;
  final double uploadProgress;

  const ProfileCreationState({
    this.status = ProfileCreationStatus.idle,
    this.error,
    this.uploadProgress = 0.0,
  });

  bool get isLoading =>
      status == ProfileCreationStatus.uploadingImage ||
      status == ProfileCreationStatus.savingProfile;

  ProfileCreationState copyWith({
    ProfileCreationStatus? status,
    String? error,
    double? uploadProgress,
    bool clearError = false,
  }) {
    return ProfileCreationState(
      status: status ?? this.status,
      error: clearError ? null : (error ?? this.error),
      uploadProgress: uploadProgress ?? this.uploadProgress,
    );
  }
}

/// Profile creation notifier
class ProfileCreationNotifier extends StateNotifier<ProfileCreationState> {
  final ProfileRepository _repository;

  ProfileCreationNotifier(this._repository)
      : super(const ProfileCreationState());

  Future<bool> createProfile({
    required ProfileData profileData,
    required File imageFile,
  }) async {
    state = state.copyWith(
      status: ProfileCreationStatus.uploadingImage,
      clearError: true,
    );

    try {
      // Step 1: Upload image
      final imageUrl = await _repository.uploadProfileImage(imageFile);

      state = state.copyWith(status: ProfileCreationStatus.savingProfile);

      // Step 2: Save profile
      await _repository.saveProfile(
        profileData: profileData,
        imageUrl: imageUrl,
      );

      state = state.copyWith(status: ProfileCreationStatus.success);
      return true;
    } catch (e) {
      state = state.copyWith(
        status: ProfileCreationStatus.error,
        error: e.toString(),
      );
      return false;
    }
  }

  void reset() {
    state = const ProfileCreationState();
  }
}

// ============ PROVIDERS ============

/// Profile repository provider
final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  return ProfileRepository();
});

/// App state provider - manages auth + profile state
final appStateProvider =
    StateNotifierProvider<AppStateNotifier, AppState>((ref) {
  final repository = ref.watch(profileRepositoryProvider);
  return AppStateNotifier(repository);
});

/// Profile creation provider
final profileCreationProvider =
    StateNotifierProvider<ProfileCreationNotifier, ProfileCreationState>((ref) {
  final repository = ref.watch(profileRepositoryProvider);
  return ProfileCreationNotifier(repository);
});

/// Has profile provider - simple check
final hasProfileProvider = FutureProvider<bool>((ref) async {
  final repository = ref.watch(profileRepositoryProvider);
  return repository.hasProfile();
});

/// Current user profile provider (Map format - legacy)
final currentProfileProvider =
    FutureProvider<Map<String, dynamic>?>((ref) async {
  final repository = ref.watch(profileRepositoryProvider);
  return repository.getProfile();
});

/// Current user profile provider with Cache-First strategy
/// Returns UserProfile object, loads from cache first then refreshes
final currentUserProfileProvider = FutureProvider<UserProfile?>((ref) async {
  final repository = ref.watch(profileRepositoryProvider);
  return repository.getUserProfile();
});

/// Cached profile provider - returns immediately from cache (no network)
/// Use this for instant UI display, then use currentUserProfileProvider for fresh data
final cachedUserProfileProvider = FutureProvider<UserProfile?>((ref) async {
  final repository = ref.watch(profileRepositoryProvider);
  return repository.getCachedUserProfile();
});

/// Stream provider for Cache-First profile loading
/// Emits cached profile first, then fresh profile from Firestore
/// Perfect for screens that need instant display + background refresh
final userProfileStreamProvider = StreamProvider<UserProfile?>((ref) {
  final repository = ref.watch(profileRepositoryProvider);
  return repository.watchCurrentUserProfile();
});

/// Force refresh current user profile (invalidates cache)
final refreshUserProfileProvider = FutureProvider.family<UserProfile?, bool>(
  (ref, forceRefresh) async {
    final repository = ref.watch(profileRepositoryProvider);
    return repository.getUserProfile(forceRefresh: forceRefresh);
  },
);
