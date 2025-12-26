import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../providers/swipe_provider.dart';
import '../models/user_profile.dart';
import '../widgets/swipe_card.dart';
import '../services/seed_service.dart';
import '../widgets/custom_notification.dart';

class DiscoverScreen extends ConsumerStatefulWidget {
  const DiscoverScreen({super.key});

  @override
  ConsumerState<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends ConsumerState<DiscoverScreen> {
  final PageController _pageController = PageController();

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onLike() {
    HapticFeedback.mediumImpact();
    final notifier = ref.read(swipeProvider.notifier);
    notifier.swipeRight(0);
  }

  void _onDislike() {
    HapticFeedback.mediumImpact();
    final notifier = ref.read(swipeProvider.notifier);
    notifier.swipeLeft(0);
  }

  void _onSuperLike() {
    HapticFeedback.heavyImpact();
    final notifier = ref.read(swipeProvider.notifier);
    notifier.superLike(0);
  }

  @override
  Widget build(BuildContext context) {
    final swipeState = ref.watch(swipeProvider);

    // Listen for match notification
    ref.listen<SwipeState>(swipeProvider, (previous, current) {
      if (current.isMatch && current.lastSwipedProfile != null) {
        _showMatchScreen(current.lastSwipedProfile!);
        ref.read(swipeProvider.notifier).clearMatchNotification();
      }
    });

    // Immersive mode - transparent status bar with light icons
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light, // White icons for dark photos
      statusBarBrightness: Brightness.dark, // iOS
    ));

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      extendBodyBehindAppBar: true,
      extendBody: true,
      body: _buildBody(swipeState),
    );
  }

  Widget _buildBody(SwipeState state) {
    // Full immersive view - no header, content extends to top
    return _buildContent(state);
  }

  Widget _buildContent(SwipeState state) {
    if (state.isLoading && state.profiles.isEmpty) {
      return _buildLoadingState();
    }

    if (state.error != null && state.profiles.isEmpty) {
      return _buildErrorState(state.error!);
    }

    if (state.profiles.isEmpty) {
      return _buildEmptyState();
    }

    final profile = state.profiles.first;
    return _buildProfileView(profile);
  }

  Widget _buildProfileView(UserProfile profile) {
    // Full immersive view - no top padding, photo starts from edge-to-edge
    return Stack(
      children: [
        // Scrollable profile content - starts from very top
        CustomScrollView(
          slivers: [
            // Main photo with action buttons - no top spacing
            SliverToBoxAdapter(
              child: _buildMainPhotoSection(profile),
            ),
            // Profile info
            SliverToBoxAdapter(
              child: _buildInfoSection(profile),
            ),
            // Second photo (if exists)
            if (profile.photos.length > 1)
              SliverToBoxAdapter(
                child: _buildPhotoCard(profile.photos[1], 1),
              ),
            // Interests section
            if (profile.interests.isNotEmpty)
              SliverToBoxAdapter(
                child: _buildInterestsSection(profile),
              ),
            // Third photo (if exists)
            if (profile.photos.length > 2)
              SliverToBoxAdapter(
                child: _buildPhotoCard(profile.photos[2], 2),
              ),
            // Bio section
            if (profile.bio.isNotEmpty)
              SliverToBoxAdapter(
                child: _buildBioSection(profile),
              ),
            // Remaining photos
            if (profile.photos.length > 3)
              ...profile.photos.skip(3).toList().asMap().entries.map(
                    (entry) => SliverToBoxAdapter(
                      child: _buildPhotoCard(entry.value, entry.key + 3),
                    ),
                  ),
            // Bottom padding
            const SliverToBoxAdapter(
              child: SizedBox(height: 120),
            ),
          ],
        ),
        // Fixed action buttons at bottom
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: _buildActionButtons(),
        ),
      ],
    );
  }

  Widget _buildMainPhotoSection(UserProfile profile) {
    return Stack(
      children: [
        // Main photo
        AspectRatio(
          aspectRatio: 0.75,
          child: CachedNetworkImage(
            imageUrl: profile.primaryPhoto,
            fit: BoxFit.cover,
            placeholder: (context, url) => Container(
              color: Colors.grey[200],
              child: const Center(
                child: CircularProgressIndicator(
                  color: Color(0xFFFF2C60),
                ),
              ),
            ),
            errorWidget: (context, url, error) => Container(
              color: Colors.grey[200],
              child: const Icon(Icons.person, size: 80, color: Colors.grey),
            ),
          ),
        ),
        // Gradient overlay at bottom
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          height: 200,
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  Colors.black.withValues(alpha: 0.7),
                ],
              ),
            ),
          ),
        ),
        // Name and basic info
        Positioned(
          left: 20,
          right: 20,
          bottom: 20,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Text(
                      '${profile.name}, ${profile.age}',
                      style: GoogleFonts.poppins(
                        fontSize: 32,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        shadows: [
                          Shadow(
                            color: Colors.black.withValues(alpha: 0.3),
                            blurRadius: 10,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              if (profile.university.isNotEmpty) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(
                      Icons.school_rounded,
                      color: Colors.white70,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        profile.university,
                        style: GoogleFonts.poppins(
                          fontSize: 15,
                          color: Colors.white70,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildInfoSection(UserProfile profile) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (profile.department.isNotEmpty) ...[
            _buildInfoRow(
              Icons.auto_stories_rounded,
              'Bolum',
              profile.department,
            ),
            const SizedBox(height: 16),
          ],
          if (profile.university.isNotEmpty)
            _buildInfoRow(
              Icons.location_city_rounded,
              'Universite',
              profile.university,
            ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: const Color(0xFFFF2C60).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            icon,
            color: const Color(0xFFFF2C60),
            size: 22,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: Colors.grey[500],
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                value,
                style: GoogleFonts.poppins(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey[800],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPhotoCard(String photoUrl, int index) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: AspectRatio(
          aspectRatio: 0.85,
          child: CachedNetworkImage(
            imageUrl: photoUrl,
            fit: BoxFit.cover,
            placeholder: (context, url) => Container(
              color: Colors.grey[200],
              child: const Center(
                child: CircularProgressIndicator(
                  color: Color(0xFFFF2C60),
                ),
              ),
            ),
            errorWidget: (context, url, error) => Container(
              color: Colors.grey[200],
              child: const Icon(Icons.image, size: 50, color: Colors.grey),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInterestsSection(UserProfile profile) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 4,
                height: 24,
                decoration: BoxDecoration(
                  color: const Color(0xFFFF2C60),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Ilgi Alanlari',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[800],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: profile.interests.map((interest) {
              return Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xFFFF2C60).withValues(alpha: 0.1),
                      const Color(0xFFFF6B9D).withValues(alpha: 0.1),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(25),
                  border: Border.all(
                    color: const Color(0xFFFF2C60).withValues(alpha: 0.3),
                  ),
                ),
                child: Text(
                  interest,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: const Color(0xFFFF2C60),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildBioSection(UserProfile profile) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 4,
                height: 24,
                decoration: BoxDecoration(
                  color: const Color(0xFFFF2C60),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Hakkinda',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[800],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            profile.bio,
            style: GoogleFonts.poppins(
              fontSize: 15,
              color: Colors.grey[700],
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Container(
      padding: const EdgeInsets.fromLTRB(40, 40, 40, 20),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0x00FFFFFF), // Transparent white
            Color(0xCCFFFFFF), // 80% white
            Color(0xFFFFFFFF), // Solid white
            Color(0xFFFFFFFF), // Solid white
          ],
          stops: [0.0, 0.3, 0.6, 1.0],
        ),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            // Dislike button
            _buildActionButton(
              icon: Icons.close_rounded,
              color: const Color(0xFFFF4458),
              size: 64,
              iconSize: 32,
              onTap: _onDislike,
            ),
            // Super like button
            _buildActionButton(
              icon: Icons.star_rounded,
              color: const Color(0xFF00D4FF),
              size: 52,
              iconSize: 26,
              onTap: _onSuperLike,
            ),
            // Like button
            _buildActionButton(
              icon: Icons.favorite_rounded,
              color: const Color(0xFF00E676),
              size: 64,
              iconSize: 32,
              onTap: _onLike,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required Color color,
    required double size,
    required double iconSize,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.3),
              blurRadius: 15,
              spreadRadius: 2,
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          shape: const CircleBorder(),
          child: InkWell(
            onTap: onTap,
            customBorder: const CircleBorder(),
            splashColor: color.withValues(alpha: 0.2),
            child: Center(
              child: Icon(icon, color: color, size: iconSize),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFFF2C60).withValues(alpha: 0.2),
                  blurRadius: 20,
                ),
              ],
            ),
            child: const CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFF2C60)),
              strokeWidth: 3,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Profiller yukleniyor...',
            style: GoogleFonts.poppins(
              fontSize: 16,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.error_outline,
                size: 48,
                color: Colors.red,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Bir hata olustu',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.grey[800],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              error,
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => ref.read(swipeProvider.notifier).refresh(),
              icon: const Icon(Icons.refresh),
              label: Text(
                'Tekrar Dene',
                style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF2C60),
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: const Color(0xFFFF2C60).withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.explore_off_rounded,
                size: 64,
                color: Color(0xFFFF2C60),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Su an icin profil kalmadi',
              style: GoogleFonts.poppins(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: Colors.grey[800],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Daha sonra tekrar kontrol et',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton.icon(
                  onPressed: () => ref.read(swipeProvider.notifier).refresh(),
                  icon: const Icon(Icons.refresh),
                  label: Text(
                    'Yenile',
                    style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF2C60),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  onPressed: _seedTestProfiles,
                  icon: const Icon(Icons.people),
                  label: Text(
                    'Test Ekle',
                    style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _seedTestProfiles() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Center(
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFF2C60)),
              ),
              const SizedBox(height: 16),
              Text(
                'Test profilleri ekleniyor...',
                style: GoogleFonts.poppins(fontSize: 14),
              ),
            ],
          ),
        ),
      ),
    );

    try {
      final seedService = SeedService();
      await seedService.seedTestProfiles();

      // Yeni eklenen demo kullanıcıların mevcut kullanıcıyı beğenmesini sağla
      final likeCount = await seedService.seedDemoLikesToCurrentUser();

      if (mounted) {
        Navigator.pop(context);
        CustomNotification.success(
          context,
          'Test Profilleri Eklendi',
          subtitle: likeCount > 0
              ? '$likeCount kisi seni begendi!'
              : 'Yeni profiller kesfetmeye hazir',
        );
        ref.read(swipeProvider.notifier).refresh();
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        CustomNotification.error(
          context,
          'Hata',
          subtitle: 'Profiller eklenemedi',
        );
      }
    }
  }

  void _showMatchScreen(UserProfile profile) {
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => MatchPopup(
          matchedProfile: profile,
          onSendMessage: () {
            Navigator.pop(context);
            // TODO: Navigate to chat
          },
          onKeepSwiping: () {
            Navigator.pop(context);
          },
        ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: animation,
            child: ScaleTransition(
              scale: Tween<double>(begin: 0.8, end: 1.0).animate(
                CurvedAnimation(parent: animation, curve: Curves.easeOutBack),
              ),
              child: child,
            ),
          );
        },
        transitionDuration: const Duration(milliseconds: 400),
      ),
    );
  }
}
