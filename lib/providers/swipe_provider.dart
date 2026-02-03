import 'dart:io';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_profile.dart';
import '../repositories/swipe_repository.dart';
import '../utils/network_utils.dart';

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
  
  // Gelişmiş Filtreler (Premium özelliği)
  final String? filterCity;
  final String? filterUniversity;
  final String? filterDepartment;
  final String? filterGrade;

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
    this.filterCity,
    this.filterUniversity,
    this.filterDepartment,
    this.filterGrade,
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
    String? filterCity,
    String? filterUniversity,
    String? filterDepartment,
    String? filterGrade,
    bool clearError = false,
    bool clearLastDocument = false,
    bool clearLastSwiped = false,
    bool clearMatch = false,
    bool clearFilters = false,
    bool clearGenderFilter = false,
    bool clearFilterCity = false,
    bool clearFilterUniversity = false,
    bool clearFilterDepartment = false,
    bool clearFilterGrade = false,
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
      genderFilter: clearFilters || clearGenderFilter ? null : (genderFilter ?? this.genderFilter),
      filterCity: clearFilters || clearFilterCity ? null : (filterCity ?? this.filterCity),
      filterUniversity: clearFilters || clearFilterUniversity ? null : (filterUniversity ?? this.filterUniversity),
      filterDepartment: clearFilters || clearFilterDepartment ? null : (filterDepartment ?? this.filterDepartment),
      filterGrade: clearFilters || clearFilterGrade ? null : (filterGrade ?? this.filterGrade),
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
  /// preserveFilters: Eğer true ise, mevcut filtreleri korur (refresh için)
  Future<void> _initialize({bool preserveFilters = false}) async {
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      // 1. Fetch all action IDs for client-side filtering
      final excludedIds = await _repository.fetchAllActionIds();

      // 2. Get user's preference for gender filter (SADECE İLK AÇILIŞTA!)
      String? genderFilter;
      String? filterCity;
      String? filterUniversity;
      String? filterDepartment;
      String? filterGrade;
      
      if (preserveFilters) {
        // Refresh sırasında mevcut filtreyi koru (arka plandan dönünce aynı kalır)
        genderFilter = state.genderFilter;
        filterCity = state.filterCity;
        filterUniversity = state.filterUniversity;
        filterDepartment = state.filterDepartment;
        filterGrade = state.filterGrade;
        debugPrint('🔒 [Initialize] Mevcut filtreler korunuyor (Gender: $genderFilter, City: $filterCity)');
      } else {
        // Uygulama tamamen kapatılıp açıldığında: sadece "Kiminle tanışmak istiyorsun?" kalıcı, diğerleri sıfırlanır
        filterCity = null;
        filterUniversity = null;
        filterDepartment = null;
        filterGrade = null;
        // Cinsiyet filtresi: önce kayıtlı tercihten yükle (SharedPreferences)
        final prefs = await SharedPreferences.getInstance();
        genderFilter = prefs.getString('filter_gender');
        if (genderFilter == null || genderFilter.isEmpty) {
          genderFilter = await _repository.getUserLookingForPreference();
          if (genderFilter == null || genderFilter.isEmpty) {
            genderFilter = 'Herkes';
          }
        }
        debugPrint('🔄 [Initialize] Cold start - Gender kalıcı: $genderFilter, diğer filtreler sıfırlandı');
      }

      state = state.copyWith(
        excludedIds: excludedIds,
        genderFilter: genderFilter,
        filterCity: filterCity,
        filterUniversity: filterUniversity,
        filterDepartment: filterDepartment,
        filterGrade: filterGrade,
        isLoading: false,
      );

      // 3. Fetch initial batch of profiles
      await _fetchNextBatch();
    } on SocketException {
      state = state.copyWith(
        isLoading: false,
        error: 'İnternet bağlantınızı kontrol edin',
      );
    } on TimeoutException {
      state = state.copyWith(
        isLoading: false,
        error: 'Bağlantı zaman aşımına uğradı',
      );
    } catch (e) {
      final errorMsg = NetworkUtils.isNetworkError(e)
          ? 'İnternet bağlantınızı kontrol edin'
          : 'Profiller yüklenirken bir hata oluştu';
      state = state.copyWith(
        isLoading: false,
        error: errorMsg,
      );
    }
  }

  /// Fetch next batch of profiles with filtering
  Future<void> _fetchNextBatch() async {
    if (!state.hasMore || state.isLoading) return;

    state = state.copyWith(isLoading: true);

    try {
      int attempts = 0;
      const maxAttempts = 3; // Reduced - proper pagination means fewer attempts needed
      List<UserProfile> filteredProfiles = [];
      DocumentSnapshot? currentLastDoc = state.lastDocument;

      // Keep fetching until we have enough profiles or no more data
      while (
          filteredProfiles.length < minCardsInStack && attempts < maxAttempts) {
        final batch = await _repository.fetchUserBatch(
          lastDocument: currentLastDoc,
          genderFilter: state.genderFilter,
          filterCity: state.filterCity,
          filterUniversity: state.filterUniversity,
          filterDepartment: state.filterDepartment,
          filterGrade: state.filterGrade,
          excludedIds: state.excludedIds,  // ← excludedIds eklendi! ✅
        );

        // No more data available
        if (batch.profiles.isEmpty) {
          state = state.copyWith(
            profiles: [...state.profiles, ...filteredProfiles],
            lastDocument: currentLastDoc,
            hasMore: false,
            isLoading: false,
          );
          return;
        }

        // CRITICAL: Update cursor for next iteration
        currentLastDoc = batch.lastDoc;

        // Apply client-side filtering
        final newProfiles = batch.profiles
            .where((profile) =>
                !state.excludedIds.contains(profile.id) &&
                !state.profiles.any((p) => p.id == profile.id) &&
                !filteredProfiles.any((p) => p.id == profile.id))
            .toList();

        filteredProfiles.addAll(newProfiles);
        attempts++;
      }

      // Add filtered profiles to state with updated pagination cursor
      state = state.copyWith(
        profiles: [...state.profiles, ...filteredProfiles],
        lastDocument: currentLastDoc,
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
    debugPrint('🔵 DEBUG: onSwipe başladı - Index: $index, Type: $actionType');
    
    if (index < 0 || index >= state.profiles.length) {
      debugPrint('⚠️ DEBUG: Geçersiz index - Index: $index, Profil sayısı: ${state.profiles.length}');
      return;
    }

    final swipedProfile = state.profiles[index];
    debugPrint('🔵 DEBUG: Swiped Profile - ID: ${swipedProfile.id}, Name: ${swipedProfile.name}');

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
    debugPrint('✅ DEBUG: UI güncellendi - Kalan profil: ${updatedProfiles.length}');

    // 3. Record action in Firestore (async, don't wait)
    _recordSwipeAction(swipedProfile.id, actionType);

    // 4. Check if prefetch is needed
    if (state.shouldPrefetch) {
      debugPrint('🔵 DEBUG: Prefetch tetiklendi');
      _fetchNextBatch();
    }
  }

  /// Record swipe action and check for MUTUAL match
  Future<void> _recordSwipeAction(
      String targetUserId, SwipeActionType actionType) async {
    try {
      final result = await _repository.recordSwipeAction(
        targetUserId: targetUserId,
        actionType: actionType,
      );

      final success = result['success'] as bool? ?? false;
      final isMatch = result['isMatch'] as bool? ?? false;

      // Only show match animation if MUTUAL like (both users liked each other)
      if (success && isMatch &&
          (actionType == SwipeActionType.like ||
              actionType == SwipeActionType.superlike)) {
        state = state.copyWith(isMatch: true);
      }
    } catch (e) {
      // Silent fail for background operation
    }
  }

  /// Swipe left (dislike)
  Future<void> swipeLeft(int index) async {
    await onSwipe(index, SwipeActionType.dislike);
  }

  /// Swipe right (like)
  Future<void> swipeRight(int index) async {
    debugPrint('🔵 DEBUG: Swipe Right tetiklendi - Index: $index');
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
      return false;
    }
  }

  /// Rewind last swipe (Premium özelliği - sadece kartı geri getirir, Firestore'dan silmez)
  void rewindLastSwipe(UserProfile profile) {
    // Kartı başa ekle
    final updatedProfiles = [profile, ...state.profiles];
    
    state = state.copyWith(
      profiles: updatedProfiles,
    );
  }

  /// Refresh profiles
  Future<void> refresh() async {
    debugPrint('🔄 [SwipeProvider] refresh() başladı - Filtreleri koruyarak...');
    
    // Mevcut filtreleri kaydet
    final currentGenderFilter = state.genderFilter;
    final currentFilterCity = state.filterCity;
    final currentFilterUniversity = state.filterUniversity;
    final currentFilterDepartment = state.filterDepartment;
    final currentFilterGrade = state.filterGrade;
    
    debugPrint('   - Korunacak filtreler:');
    debugPrint('     * genderFilter: $currentGenderFilter');
    debugPrint('     * filterCity: $currentFilterCity');
    debugPrint('     * filterUniversity: $currentFilterUniversity');
    debugPrint('     * filterDepartment: $currentFilterDepartment');
    debugPrint('     * filterGrade: $currentFilterGrade');
    
    // State'i sıfırla AMA FİLTRELERİ KORU!
    state = SwipeState(
      genderFilter: currentGenderFilter,
      filterCity: currentFilterCity,
      filterUniversity: currentFilterUniversity,
      filterDepartment: currentFilterDepartment,
      filterGrade: currentFilterGrade,
    );
    
    // Initialize'i FİLTRELERİ KORUYARAK çağır!
    await _initialize(preserveFilters: true);
    debugPrint('✅ [SwipeProvider] refresh() tamamlandı - Filtreler korundu!');
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

  /// Remove blocked user from profiles list
  /// Called when user blocks someone from profile screen
  void removeBlockedUser(String userId) {
    // Remove from profiles list
    final updatedProfiles = state.profiles.where((p) => p.id != userId).toList();

    // Add to excluded IDs so they don't appear again
    final updatedExcludedIds = Set<String>.from(state.excludedIds)..add(userId);

    state = state.copyWith(
      profiles: updatedProfiles,
      excludedIds: updatedExcludedIds,
    );

    // Prefetch if needed
    if (state.shouldPrefetch) {
      _fetchNextBatch();
    }
  }

  /// Gelişmiş Filtreleri Ayarla
  /// gender filtresi FREE, diğerleri Premium özelliği
  Future<void> setFilters({
    String? gender,
    String? city,
    String? university,
    String? department,
    String? grade,
  }) async {
    debugPrint('🔧 [SwipeProvider] setFilters çağrıldı');
    debugPrint('   - gender: $gender');
    debugPrint('   - city: $city');
    debugPrint('   - university: $university');
    debugPrint('   - department: $department');
    debugPrint('   - grade: $grade');

    // Sadece cinsiyet filtresi kalıcı (SharedPreferences); diğerleri sadece bellekte
    final prefs = await SharedPreferences.getInstance();
    if (gender != null && gender.isNotEmpty) {
      await prefs.setString('filter_gender', gender);
    } else {
      await prefs.remove('filter_gender');
    }
    state = state.copyWith(
      genderFilter: gender,
      clearGenderFilter: gender == null,
      filterCity: city,
      clearFilterCity: city == null,
      filterUniversity: university,
      clearFilterUniversity: university == null,
      filterDepartment: department,
      clearFilterDepartment: department == null,
      filterGrade: grade,
      clearFilterGrade: grade == null,
    );

    debugPrint('✅ [SwipeProvider] State güncellendi:');
    debugPrint('   - genderFilter: ${state.genderFilter}');
    debugPrint('   - filterCity: ${state.filterCity}');
    debugPrint('   - filterUniversity: ${state.filterUniversity}');
    debugPrint('   - filterDepartment: ${state.filterDepartment}');
    debugPrint('   - filterGrade: ${state.filterGrade}');

    // Filtreleri uygula - profilleri yeniden yükle
    await refresh();
    debugPrint('✅ [SwipeProvider] refresh() tamamlandı');
  }

  /// Tüm Filtreleri Temizle
  Future<void> clearFilters() async {
    debugPrint('🗑️ [SwipeProvider] Filtreler temizlendi (Gender: Herkes)');
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('filter_gender', 'Herkes');

    state = state.copyWith(
      genderFilter: 'Herkes',         // ✅ Gender "Herkes"e dönüyor
      clearFilterCity: true,          // ✅ City null yapılıyor
      clearFilterUniversity: true,    // ✅ University null yapılıyor
      clearFilterDepartment: true,    // ✅ Department null yapılıyor
      clearFilterGrade: true,         // ✅ Grade null yapılıyor
    );

    // Filtreleri temizle - profilleri yeniden yükle
    await refresh();
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
