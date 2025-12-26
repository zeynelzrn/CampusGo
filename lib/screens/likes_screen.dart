import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/user_profile.dart';
import '../widgets/custom_notification.dart';
import '../services/seed_service.dart';

class LikesScreen extends ConsumerStatefulWidget {
  const LikesScreen({super.key});

  @override
  ConsumerState<LikesScreen> createState() => _LikesScreenState();
}

class _LikesScreenState extends ConsumerState<LikesScreen> {
  List<UserProfile> _likedByUsers = [];
  Set<String> _eliminatedUserIds = {}; // Dislike atılan kullanıcılar
  Set<String> _dismissingUserIds = {}; // Çıkış animasyonu oynayan kartlar
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadLikedByUsers();
  }

  Future<void> _loadLikedByUsers() async {
    setState(() => _isLoading = true);

    try {
      final currentUserId = FirebaseAuth.instance.currentUser?.uid;
      if (currentUserId == null) {
        setState(() => _isLoading = false);
        return;
      }

      debugPrint('Loading likes for user: $currentUserId');

      // Step 1: Query actions where toUserId == currentUserId (people who swiped on me)
      final actionsSnapshot = await FirebaseFirestore.instance
          .collection('actions')
          .where('toUserId', isEqualTo: currentUserId)
          .get();

      debugPrint(
          'Found ${actionsSnapshot.docs.length} actions targeting current user');

      // Step 2: Filter only likes and superLikes, collect fromUserIds
      List<String> likedByUserIds = [];
      for (var doc in actionsSnapshot.docs) {
        final data = doc.data();
        final type = data['type'] as String?;
        final fromUserId = data['fromUserId'] as String?;

        debugPrint('Action: fromUserId=$fromUserId, type=$type');

        if (fromUserId != null && (type == 'like' || type == 'superlike')) {
          likedByUserIds.add(fromUserId);
        }
      }

      debugPrint('Users who liked me: ${likedByUserIds.length}');

      if (likedByUserIds.isEmpty) {
        setState(() {
          _likedByUsers = [];
          _isLoading = false;
        });
        return;
      }

      // Step 3: Get users I've already swiped on (to mark as eliminated or filter out)
      final myActionsSnapshot = await FirebaseFirestore.instance
          .collection('actions')
          .where('fromUserId', isEqualTo: currentUserId)
          .get();

      Set<String> eliminatedIds = {};
      Set<String> dismissedIds = {}; // Tamamen silinen (X'e basılan)
      Set<String> likedBackIds = {}; // Like attıklarım (match olacaklar)

      for (var doc in myActionsSnapshot.docs) {
        final data = doc.data();
        final toUserId = data['toUserId'] as String?;
        final type = data['type'] as String?;

        if (toUserId != null) {
          if (type == 'dislike') {
            eliminatedIds.add(toUserId);
          } else if (type == 'dismissed') {
            dismissedIds.add(toUserId);
          } else if (type == 'like' || type == 'superlike') {
            likedBackIds.add(toUserId);
          }
        }
      }

      debugPrint('Eliminated users: ${eliminatedIds.length}');
      debugPrint('Dismissed users: ${dismissedIds.length}');
      debugPrint('Liked back users: ${likedBackIds.length}');

      // Like attıklarımı ve dismissed olanları listeden çıkar
      likedByUserIds = likedByUserIds
          .where(
              (id) => !likedBackIds.contains(id) && !dismissedIds.contains(id))
          .toList();

      debugPrint('After filtering: ${likedByUserIds.length} users remain');

      // Step 4: Filter out users we've already matched with
      final matchesSnapshot = await FirebaseFirestore.instance
          .collection('matches')
          .where('users', arrayContains: currentUserId)
          .get();

      Set<String> matchedUserIds = {};
      for (var doc in matchesSnapshot.docs) {
        final users = List<String>.from(doc.data()['users'] ?? []);
        matchedUserIds.addAll(users.where((id) => id != currentUserId));
      }

      debugPrint('Already matched with: ${matchedUserIds.length} users');

      likedByUserIds =
          likedByUserIds.where((id) => !matchedUserIds.contains(id)).toList();

      debugPrint(
          'After filtering matches: ${likedByUserIds.length} users remain');

      if (likedByUserIds.isEmpty) {
        setState(() {
          _likedByUsers = [];
          _isLoading = false;
        });
        return;
      }

      // Step 5: Fetch user profiles
      List<UserProfile> profiles = [];
      for (String userId in likedByUserIds) {
        try {
          final userDoc = await FirebaseFirestore.instance
              .collection('users')
              .doc(userId)
              .get();

          if (userDoc.exists && userDoc.data() != null) {
            final data = userDoc.data()!;
            profiles.add(UserProfile(
              id: userId,
              name: data['name'] ?? '',
              age: data['age'] ?? 0,
              bio: data['bio'] ?? '',
              photos: List<String>.from(data['photos'] ?? []),
              university: data['university'] ?? '',
              department: data['department'] ?? '',
              interests: List<String>.from(data['interests'] ?? []),
            ));
            debugPrint('Loaded profile for: ${data['name']}');
          } else {
            debugPrint('User $userId not found or has no data');
          }
        } catch (e) {
          debugPrint('Error loading profile for $userId: $e');
        }
      }

      debugPrint('Total profiles loaded: ${profiles.length}');

      setState(() {
        _likedByUsers = profiles;
        _eliminatedUserIds = eliminatedIds;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading liked by users: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _likeUser(UserProfile user) async {
    HapticFeedback.mediumImpact();

    try {
      final currentUserId = FirebaseAuth.instance.currentUser?.uid;
      if (currentUserId == null) return;

      // Generate action ID (same format as SwipeRepository)
      final actionId = '${currentUserId}_${user.id}';

      // Record the like action
      await FirebaseFirestore.instance.collection('actions').doc(actionId).set({
        'fromUserId': currentUserId,
        'toUserId': user.id,
        'type': 'like',
        'timestamp': FieldValue.serverTimestamp(),
      });

      // Since they already liked us (that's why they're in this list),
      // this is definitely a match - create match document
      final sortedIds = [currentUserId, user.id]..sort();
      final matchId = '${sortedIds[0]}_${sortedIds[1]}';

      // Check if match already exists
      final existingMatch = await FirebaseFirestore.instance
          .collection('matches')
          .doc(matchId)
          .get();

      if (!existingMatch.exists) {
        // Create match document
        await FirebaseFirestore.instance
            .collection('matches')
            .doc(matchId)
            .set({
          'users': sortedIds,
          'timestamp': FieldValue.serverTimestamp(),
        });

        // Add to each user's matches subcollection
        final batch = FirebaseFirestore.instance.batch();

        batch.set(
          FirebaseFirestore.instance
              .collection('users')
              .doc(currentUserId)
              .collection('matches')
              .doc(user.id),
          {'timestamp': FieldValue.serverTimestamp(), 'matchId': matchId},
        );

        batch.set(
          FirebaseFirestore.instance
              .collection('users')
              .doc(user.id)
              .collection('matches')
              .doc(currentUserId),
          {'timestamp': FieldValue.serverTimestamp(), 'matchId': matchId},
        );

        await batch.commit();
      }

      // Remove from list and show match notification
      setState(() {
        _likedByUsers.removeWhere((u) => u.id == user.id);
      });

      if (mounted) {
        CustomNotification.success(
          context,
          'Yeni Arkadas!',
          subtitle: '${user.name} ile eslestiniz!',
        );
      }
    } catch (e) {
      debugPrint('Error liking user: $e');
      if (mounted) {
        CustomNotification.error(context, 'Bir hata olustu');
      }
    }
  }

  Future<void> _dislikeUser(UserProfile user) async {
    HapticFeedback.mediumImpact();

    try {
      final currentUserId = FirebaseAuth.instance.currentUser?.uid;
      if (currentUserId == null) return;

      // Generate action ID (same format as SwipeRepository)
      final actionId = '${currentUserId}_${user.id}';

      // Record the dislike action
      await FirebaseFirestore.instance.collection('actions').doc(actionId).set({
        'fromUserId': currentUserId,
        'toUserId': user.id,
        'type': 'dislike',
        'timestamp': FieldValue.serverTimestamp(),
      });

      // Elendi olarak işaretle (listeden silme)
      setState(() {
        _eliminatedUserIds.add(user.id);
      });
    } catch (e) {
      debugPrint('Error disliking user: $e');
      if (mounted) {
        CustomNotification.error(context, 'Bir hata olustu');
      }
    }
  }

  /// Elenmiş kullanıcıyı tamamen listeden kaldır (X butonuna basıldığında)
  Future<void> _dismissUser(UserProfile user) async {
    // Zaten animasyon oynatılıyorsa tekrar başlatma
    if (_dismissingUserIds.contains(user.id)) return;

    HapticFeedback.mediumImpact();

    // Step 1: Çıkış animasyonunu başlat
    setState(() {
      _dismissingUserIds.add(user.id);
    });

    // Step 2: Animasyon süresince bekle
    await Future.delayed(_animationDuration);

    // Step 3: Animasyon bittikten sonra veritabanını güncelle ve listeden kaldır
    try {
      final currentUserId = FirebaseAuth.instance.currentUser?.uid;
      if (currentUserId == null) return;

      // Generate action ID
      final actionId = '${currentUserId}_${user.id}';

      // Update action type to "dismissed"
      await FirebaseFirestore.instance
          .collection('actions')
          .doc(actionId)
          .update({'type': 'dismissed'});

      // Listeden tamamen kaldır
      if (mounted) {
        setState(() {
          _likedByUsers.removeWhere((u) => u.id == user.id);
          _eliminatedUserIds.remove(user.id);
          _dismissingUserIds.remove(user.id);
        });
      }
    } catch (e) {
      debugPrint('Error dismissing user: $e');
      if (mounted) {
        // Hata durumunda animasyonu geri al
        setState(() {
          _dismissingUserIds.remove(user.id);
        });
        CustomNotification.error(context, 'Bir hata olustu');
      }
    }
  }

  void _showProfileDetail(UserProfile user) {
    // Hero Animation + iOS Swipe-Back ile detay sayfasına git
    Navigator.of(context).push(
      CupertinoPageRoute(
        builder: (context) => _ProfileDetailPage(
          user: user,
          onLike: () {
            Navigator.pop(context);
            _likeUser(user);
          },
          onDislike: () {
            Navigator.pop(context);
            _dislikeUser(user);
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: _isLoading
                  ? _buildLoadingState()
                  : _likedByUsers.isEmpty
                      ? _buildEmptyState()
                      : _buildLikesList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFFF2C60), Color(0xFFFF6B9D)],
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.favorite_rounded,
              color: Colors.white,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Begeniler',
                  style: GoogleFonts.poppins(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[800],
                  ),
                ),
                Text(
                  '${_likedByUsers.length} kisi seni begendi',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: _loadLikedByUsers,
            icon: Icon(
              Icons.refresh_rounded,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFF2C60)),
          ),
          const SizedBox(height: 16),
          Text(
            'Begeniler yukleniyor...',
            style: GoogleFonts.poppins(
              fontSize: 16,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _seedDemoLikes() async {
    setState(() => _isLoading = true);

    try {
      final seedService = SeedService();
      final count = await seedService.seedDemoLikesToCurrentUser();

      if (count > 0) {
        await _loadLikedByUsers();
        if (mounted) {
          CustomNotification.success(
            context,
            'Demo veriler eklendi',
            subtitle: '$count kisi seni begendi!',
          );
        }
      } else {
        setState(() => _isLoading = false);
        if (mounted) {
          CustomNotification.error(context, 'Demo veri eklenemedi');
        }
      }
    } catch (e) {
      debugPrint('Error seeding demo likes: $e');
      setState(() => _isLoading = false);
      if (mounted) {
        CustomNotification.error(context, 'Bir hata olustu');
      }
    }
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: const Color(0xFFFF2C60).withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.favorite_border_rounded,
                size: 80,
                color: Color(0xFFFF2C60),
              ),
            ),
            const SizedBox(height: 32),
            Text(
              'Henuz begeni yok',
              style: GoogleFonts.poppins(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Profilini guncelle ve daha fazla kisi\ntarafindan kesfedil!',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 16,
                color: Colors.grey[600],
                height: 1.5,
              ),
            ),
            const SizedBox(height: 32),
            // Demo veri ekleme butonu (test icin)
            GestureDetector(
              onTap: _seedDemoLikes,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFF2C60), Color(0xFFFF6B9D)],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFFF2C60).withValues(alpha: 0.3),
                      blurRadius: 15,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.auto_awesome,
                      color: Colors.white,
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Demo Begeni Ekle',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              decoration: BoxDecoration(
                color: Colors.amber.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Colors.amber.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.lightbulb_outline_rounded,
                    color: Colors.amber,
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Ipucu: Daha fazla fotograf ekle!',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Colors.amber[800],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLikesList() {
    return RefreshIndicator(
      onRefresh: _loadLikedByUsers,
      color: const Color(0xFFFF2C60),
      child: GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: 0.75,
        ),
        itemCount: _likedByUsers.length,
        itemBuilder: (context, index) {
          final user = _likedByUsers[index];
          final isEliminated = _eliminatedUserIds.contains(user.id);
          final isDismissing = _dismissingUserIds.contains(user.id);
          return _buildLikeCard(
            user,
            isEliminated: isEliminated,
            isDismissing: isDismissing,
          );
        },
      ),
    );
  }

  // Animasyon sabitleri
  static const Duration _animationDuration = Duration(milliseconds: 400);
  static const Curve _animationCurve = Curves.easeInOut;

  Widget _buildLikeCard(
    UserProfile user, {
    bool isEliminated = false,
    bool isDismissing = false,
  }) {
    // Exit animation wrapper - fade out and scale down when dismissing
    return AnimatedOpacity(
      duration: _animationDuration,
      curve: _animationCurve,
      opacity: isDismissing ? 0.0 : 1.0,
      child: AnimatedScale(
        duration: _animationDuration,
        curve: _animationCurve,
        scale: isDismissing ? 0.8 : 1.0,
        child: Stack(
          children: [
            // Ana kart - Bounce efekti ile
            _BounceCard(
              isEliminated: isEliminated,
              onTap: isEliminated ? null : () => _showProfileDetail(user),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: isEliminated ? 0.05 : 0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      // Photo with animated grayscale transition (Hero kaldırıldı)
                      TweenAnimationBuilder<double>(
                        duration: _animationDuration,
                        curve: _animationCurve,
                        tween: Tween<double>(
                          begin: isEliminated ? 0.0 : 1.0,
                          end: isEliminated ? 1.0 : 0.0,
                        ),
                        builder: (context, grayscaleAmount, child) {
                          final colorMatrix = <double>[
                            1.0 - 0.7874 * grayscaleAmount,
                            0.7152 * grayscaleAmount,
                            0.0722 * grayscaleAmount,
                            0,
                            0,
                            0.2126 * grayscaleAmount,
                            1.0 - 0.2848 * grayscaleAmount,
                            0.0722 * grayscaleAmount,
                            0,
                            0,
                            0.2126 * grayscaleAmount,
                            0.7152 * grayscaleAmount,
                            1.0 - 0.9278 * grayscaleAmount,
                            0,
                            0,
                            0,
                            0,
                            0,
                            1,
                            0,
                          ];
                          return ColorFiltered(
                            colorFilter: ColorFilter.matrix(colorMatrix),
                            child: child,
                          );
                        },
                        child: user.photos.isNotEmpty
                            ? CachedNetworkImage(
                                imageUrl: user.photos.first,
                                fit: BoxFit.cover,
                                placeholder: (context, url) => Container(
                                  color: Colors.grey[200],
                                  child: const Center(
                                    child: CircularProgressIndicator(
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        Color(0xFFFF2C60),
                                      ),
                                    ),
                                  ),
                                ),
                                errorWidget: (context, url, error) => Container(
                                  color: Colors.grey[200],
                                  child: Icon(Icons.person, size: 60, color: Colors.grey[400]),
                                ),
                              )
                            : Container(
                                color: Colors.grey[200],
                                child: Icon(Icons.person, size: 60, color: Colors.grey[400]),
                              ),
                      ),

                      // Gradient overlay
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              Colors.black.withValues(alpha: 0.7),
                            ],
                            stops: const [0.5, 1.0],
                          ),
                        ),
                      ),

                      // User info
                      Positioned(
                        bottom: 12,
                        left: 12,
                        right: 12,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${user.name}, ${user.age}',
                              style: GoogleFonts.poppins(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            if (user.university.isNotEmpty)
                              Text(
                                user.university,
                                style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  color: Colors.white70,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                          ],
                        ),
                      ),

                      // Tap hint
                      Positioned(
                        top: 12,
                        left: 12,
                        child: AnimatedOpacity(
                          duration: _animationDuration,
                          curve: _animationCurve,
                          opacity: isEliminated ? 0.0 : 1.0,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.5),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              'Dokun',
                              style: GoogleFonts.poppins(
                                fontSize: 10,
                                color: Colors.white,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ),
                      ),

                      // Like indicator
                      Positioned(
                        top: 12,
                        right: 12,
                        child: AnimatedOpacity(
                          duration: _animationDuration,
                          curve: _animationCurve,
                          opacity: isEliminated ? 0.0 : 1.0,
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFF2C60),
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFFFF2C60).withValues(alpha: 0.4),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.favorite_rounded,
                              color: Colors.white,
                              size: 16,
                            ),
                          ),
                        ),
                      ),

                      // Eliminated overlay
                      Positioned.fill(
                        child: IgnorePointer(
                          child: AnimatedOpacity(
                            duration: _animationDuration,
                            curve: _animationCurve,
                            opacity: isEliminated ? 1.0 : 0.0,
                            child: Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(20),
                                color: Colors.black.withValues(alpha: 0.3),
                              ),
                              child: Center(
                                child: AnimatedScale(
                                  duration: _animationDuration,
                                  curve: _animationCurve,
                                  scale: isEliminated ? 1.0 : 0.5,
                                  child: Container(
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: Colors.black.withValues(alpha: 0.5),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.close_rounded,
                                      color: Colors.white,
                                      size: 40,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Dismiss button (X) - dışarıda, her zaman görünür
            Positioned(
              top: 8,
              right: 8,
              child: AnimatedOpacity(
                duration: _animationDuration,
                curve: _animationCurve,
                opacity: isEliminated ? 1.0 : 0.0,
                child: AnimatedScale(
                  duration: _animationDuration,
                  curve: _animationCurve,
                  scale: isEliminated ? 1.0 : 0.0,
                  child: GestureDetector(
                    onTap: isEliminated ? () => _dismissUser(user) : null,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFFF2C60), Color(0xFFFF6B9D)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFFF2C60).withValues(alpha: 0.5),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.close_rounded,
                        color: Colors.white,
                        size: 18,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Bounce animasyonlu kart widget'ı
class _BounceCard extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final bool isEliminated;

  const _BounceCard({
    required this.child,
    this.onTap,
    this.isEliminated = false,
  });

  @override
  State<_BounceCard> createState() => _BounceCardState();
}

class _BounceCardState extends State<_BounceCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 100),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.95,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _handleTap() async {
    if (widget.onTap == null) return;

    // Haptic feedback
    HapticFeedback.lightImpact();

    // Bounce animasyonu: küçül
    await _controller.forward();

    // Bounce animasyonu: büyü
    await _controller.reverse();

    // Callback'i çağır
    widget.onTap?.call();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: widget.onTap != null ? (_) => _controller.forward() : null,
      onTapUp: widget.onTap != null ? (_) => _handleTap() : null,
      onTapCancel: widget.onTap != null ? () => _controller.reverse() : null,
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: child,
          );
        },
        child: widget.child,
      ),
    );
  }
}

// Profile Detail Page with CustomScrollView + iOS Swipe-Back
class _ProfileDetailPage extends StatelessWidget {
  final UserProfile user;
  final VoidCallback onLike;
  final VoidCallback onDislike;

  const _ProfileDetailPage({
    required this.user,
    required this.onLike,
    required this.onDislike,
  });

  /// X butonuna basıldığında özel tasarımlı onay dialog'u göster
  Future<void> _showDislikeConfirmation(BuildContext context) async {
    final confirmed = await showGeneralDialog<bool>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Dismiss',
      barrierColor: Colors.black.withValues(alpha: 0.5),
      transitionDuration: const Duration(milliseconds: 300),
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        return ScaleTransition(
          scale: CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutBack,
          ),
          child: FadeTransition(
            opacity: animation,
            child: child,
          ),
        );
      },
      pageBuilder: (context, animation, secondaryAnimation) {
        return Center(
          child: Material(
            color: Colors.transparent,
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 32),
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.15),
                    blurRadius: 30,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Üzgün yüz ikonu
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF2C60).withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.sentiment_dissatisfied_rounded,
                      color: Color(0xFFFF2C60),
                      size: 36,
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Başlık
                  Text(
                    'Emin misiniz?',
                    style: GoogleFonts.poppins(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[900],
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Açıklama
                  Text(
                    '${user.name} ile arkadas olmak istemediginize emin misiniz?',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                      fontSize: 15,
                      color: Colors.grey[600],
                      height: 1.5,
                    ),
                  ),

                  const SizedBox(height: 8),

                  // Uyarı
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.amber.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.info_outline_rounded,
                          size: 16,
                          color: Colors.amber[700],
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Bu islem geri alinamaz',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: Colors.amber[700],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Butonlar
                  Row(
                    children: [
                      // Vazgeç butonu
                      Expanded(
                        child: GestureDetector(
                          onTap: () => Navigator.of(context).pop(false),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            decoration: BoxDecoration(
                              color: Colors.grey[100],
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Center(
                              child: Text(
                                'Vazgec',
                                style: GoogleFonts.poppins(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey[700],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(width: 12),

                      // Evet butonu - Gradient
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            HapticFeedback.mediumImpact();
                            Navigator.of(context).pop(true);
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFFFF2C60), Color(0xFFFF6B9D)],
                                begin: Alignment.centerLeft,
                                end: Alignment.centerRight,
                              ),
                              borderRadius: BorderRadius.circular(14),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFFFF2C60).withValues(alpha: 0.4),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Center(
                              child: Text(
                                'Evet',
                                style: GoogleFonts.poppins(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );

    if (confirmed == true) {
      onDislike();
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final expandedHeight = screenHeight * 0.6; // Ekranın %60'ı fotoğraf

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // Ana içerik - CustomScrollView ile tek scroll
          CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              // SliverAppBar - Collapsing fotoğraf
              SliverAppBar(
                expandedHeight: expandedHeight,
                pinned: false,
                floating: false,
                stretch: true,
                backgroundColor: Colors.white,
                elevation: 0,
                automaticallyImplyLeading: false,
                flexibleSpace: FlexibleSpaceBar(
                  stretchModes: const [
                    StretchMode.zoomBackground,
                    StretchMode.blurBackground,
                  ],
                  background: Stack(
                    fit: StackFit.expand,
                    children: [
                      // Fotoğraf (Hero kaldırıldı)
                      user.photos.isNotEmpty
                          ? CachedNetworkImage(
                              imageUrl: user.photos.first,
                              fit: BoxFit.cover,
                            )
                          : Container(
                              color: Colors.grey[300],
                              child: const Icon(Icons.person, size: 100),
                            ),

                      // Alt gradient (içerik okunabilirliği için)
                      Positioned(
                        bottom: 0,
                        left: 0,
                        right: 0,
                        height: 150,
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.bottomCenter,
                              end: Alignment.topCenter,
                              colors: [
                                Colors.black.withValues(alpha: 0.6),
                                Colors.transparent,
                              ],
                            ),
                          ),
                        ),
                      ),

                      // Üst gradient (status bar için)
                      Positioned(
                        top: 0,
                        left: 0,
                        right: 0,
                        height: 100,
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.black.withValues(alpha: 0.4),
                                Colors.transparent,
                              ],
                            ),
                          ),
                        ),
                      ),

                      // İsim ve yaş (fotoğraf üzerinde)
                      Positioned(
                        bottom: 20,
                        left: 20,
                        right: 20,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${user.name}, ${user.age}',
                              style: GoogleFonts.poppins(
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                shadows: [
                                  Shadow(
                                    color: Colors.black.withValues(alpha: 0.5),
                                    blurRadius: 10,
                                  ),
                                ],
                              ),
                            ),
                            if (user.university.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Icon(
                                    Icons.school_rounded,
                                    color: Colors.white.withValues(alpha: 0.9),
                                    size: 18,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    user.university,
                                    style: GoogleFonts.poppins(
                                      fontSize: 16,
                                      color: Colors.white.withValues(alpha: 0.9),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // İçerik
              SliverToBoxAdapter(
                child: Container(
                  color: Colors.white,
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Bölüm
                      if (user.department.isNotEmpty) ...[
                        _buildInfoRow(
                          Icons.menu_book_rounded,
                          user.department,
                        ),
                        const SizedBox(height: 20),
                      ],

                      // Biyografi
                      if (user.bio.isNotEmpty) ...[
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.grey[50],
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Hakkinda',
                                style: GoogleFonts.poppins(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey[700],
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                user.bio,
                                style: GoogleFonts.poppins(
                                  fontSize: 15,
                                  color: Colors.grey[800],
                                  height: 1.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],

                      // İlgi alanları
                      if (user.interests.isNotEmpty) ...[
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.grey[50],
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Ilgi Alanlari',
                                style: GoogleFonts.poppins(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey[700],
                                ),
                              ),
                              const SizedBox(height: 12),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: user.interests.map((interest) {
                                  return Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 8,
                                    ),
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [
                                          const Color(0xFFFF2C60).withValues(alpha: 0.1),
                                          const Color(0xFFFF6B9D).withValues(alpha: 0.1),
                                        ],
                                      ),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(
                                      interest,
                                      style: GoogleFonts.poppins(
                                        fontSize: 13,
                                        color: const Color(0xFFFF2C60),
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                      ],

                      // Diğer fotoğraflar
                      if (user.photos.length > 1) ...[
                        ...user.photos.skip(1).map((photo) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 16),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(20),
                              child: CachedNetworkImage(
                                imageUrl: photo,
                                fit: BoxFit.cover,
                                width: double.infinity,
                              ),
                            ),
                          );
                        }),
                      ],

                      // Alt butonlar için boşluk
                      SizedBox(height: MediaQuery.of(context).padding.bottom + 100),
                    ],
                  ),
                ),
              ),
            ],
          ),

          // Geri butonu (sabit üst sol)
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            left: 16,
            child: GestureDetector(
              onTap: () => Navigator.of(context).pop(),
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.3),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.arrow_back_ios_new_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
            ),
          ),

          // Aksiyon butonları (sabit alt kısım)
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: EdgeInsets.fromLTRB(
                32,
                16,
                32,
                MediaQuery.of(context).padding.bottom + 16,
              ),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 20,
                    offset: const Offset(0, -5),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // Dislike butonu - Onay dialog'u ile
                  _buildActionButton(
                    onTap: () => _showDislikeConfirmation(context),
                    icon: Icons.close_rounded,
                    size: 60,
                    iconSize: 28,
                    colors: [Colors.grey[100]!, Colors.grey[200]!],
                    iconColor: Colors.grey[600]!,
                    shadowColor: Colors.grey.withValues(alpha: 0.3),
                  ),

                  // Like butonu (büyük)
                  _buildActionButton(
                    onTap: onLike,
                    icon: Icons.favorite_rounded,
                    size: 72,
                    iconSize: 34,
                    colors: const [Color(0xFFFF2C60), Color(0xFFFF6B9D)],
                    iconColor: Colors.white,
                    shadowColor: const Color(0xFFFF2C60).withValues(alpha: 0.4),
                    isGradient: true,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String text) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xFFFF2C60).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            icon,
            color: const Color(0xFFFF2C60),
            size: 18,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: GoogleFonts.poppins(
              fontSize: 15,
              color: Colors.grey[700],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActionButton({
    required VoidCallback onTap,
    required IconData icon,
    required double size,
    required double iconSize,
    required List<Color> colors,
    required Color iconColor,
    required Color shadowColor,
    bool isGradient = false,
  }) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.mediumImpact();
        onTap();
      },
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          gradient: isGradient
              ? LinearGradient(
                  colors: colors,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
          color: isGradient ? null : colors.first,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: shadowColor,
              blurRadius: 16,
              spreadRadius: 2,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Icon(
          icon,
          color: iconColor,
          size: iconSize,
        ),
      ),
    );
  }
}
