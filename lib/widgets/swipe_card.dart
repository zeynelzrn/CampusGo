import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shimmer/shimmer.dart';
import '../models/user_profile.dart';
import '../utils/image_helper.dart';

/// Beautiful Tinder-style swipe card widget
class SwipeCard extends StatefulWidget {
  final UserProfile profile;
  final VoidCallback? onTap;
  final bool showFullInfo;
  final double? horizontalOffset;
  final double? verticalOffset;

  const SwipeCard({
    super.key,
    required this.profile,
    this.onTap,
    this.showFullInfo = false,
    this.horizontalOffset,
    this.verticalOffset,
  });

  @override
  State<SwipeCard> createState() => _SwipeCardState();
}

class _SwipeCardState extends State<SwipeCard> {
  int _currentPhotoIndex = 0;
  bool _showDetails = false;

  void _goToNextPhoto() {
    if (_currentPhotoIndex < widget.profile.photos.length - 1) {
      HapticFeedback.lightImpact();
      setState(() => _currentPhotoIndex++);
    }
  }

  void _goToPreviousPhoto() {
    if (_currentPhotoIndex > 0) {
      HapticFeedback.lightImpact();
      setState(() => _currentPhotoIndex--);
    }
  }

  void _handleTap(TapUpDetails details, BoxConstraints constraints) {
    final tapX = details.localPosition.dx;
    final centerX = constraints.maxWidth / 2;

    if (tapX > centerX) {
      _goToNextPhoto();
    } else {
      _goToPreviousPhoto();
    }
  }

  @override
  Widget build(BuildContext context) {
    // Calculate swipe overlay opacity based on horizontal offset
    final horizontalOffset = widget.horizontalOffset ?? 0;
    final verticalOffset = widget.verticalOffset ?? 0;
    final likeOpacity = (horizontalOffset / 100).clamp(0.0, 1.0);
    final nopeOpacity = (-horizontalOffset / 100).clamp(0.0, 1.0);
    final superLikeOpacity = (-verticalOffset / 100).clamp(0.0, 1.0);

    return LayoutBuilder(
      builder: (context, constraints) {
        return GestureDetector(
          onTapUp: (details) => _handleTap(details, constraints),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.25),
                  blurRadius: 25,
                  offset: const Offset(0, 15),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // Profile Photo with animation
                  _buildProfilePhoto(),

                  // Photo navigation indicators
                  if (widget.profile.photos.length > 1) _buildPhotoIndicators(),

                  // Tap zones indicator (subtle)
                  _buildTapZones(),

                  // Gradient overlay
                  _buildGradientOverlay(),

                  // Swipe action overlays
                  _buildLikeOverlay(likeOpacity),
                  _buildNopeOverlay(nopeOpacity),
                  _buildSuperLikeOverlay(superLikeOpacity),

                  // Profile info
                  _buildProfileInfo(),

                  // Detailed info sheet (expandable)
                  if (_showDetails || widget.showFullInfo) _buildDetailSheet(),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildTapZones() {
    return Positioned.fill(
      child: Row(
        children: [
          // Left tap zone
          Expanded(
            child: Container(color: Colors.transparent),
          ),
          // Right tap zone
          Expanded(
            child: Container(color: Colors.transparent),
          ),
        ],
      ),
    );
  }

  Widget _buildLikeOverlay(double opacity) {
    if (opacity <= 0) return const SizedBox.shrink();

    return Positioned(
      top: 50,
      left: 20,
      child: Transform.rotate(
        angle: -math.pi / 12,
        child: Opacity(
          opacity: opacity,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              border: Border.all(color: const Color(0xFF4CD964), width: 4),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              'SELAM',
              style: GoogleFonts.poppins(
                fontSize: 32,
                fontWeight: FontWeight.w900,
                color: const Color(0xFF4CD964),
                letterSpacing: 2,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNopeOverlay(double opacity) {
    if (opacity <= 0) return const SizedBox.shrink();

    return Positioned(
      top: 50,
      right: 20,
      child: Transform.rotate(
        angle: math.pi / 12,
        child: Opacity(
          opacity: opacity,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              border: Border.all(color: const Color(0xFFFF3B30), width: 4),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              'NOPE',
              style: GoogleFonts.poppins(
                fontSize: 32,
                fontWeight: FontWeight.w900,
                color: const Color(0xFFFF3B30),
                letterSpacing: 2,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSuperLikeOverlay(double opacity) {
    if (opacity <= 0) return const SizedBox.shrink();

    return Positioned(
      bottom: 150,
      left: 0,
      right: 0,
      child: Center(
        child: Opacity(
          opacity: opacity,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            decoration: BoxDecoration(
              border: Border.all(color: const Color(0xFF007AFF), width: 4),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              'SÜPER',
              style: GoogleFonts.poppins(
                fontSize: 28,
                fontWeight: FontWeight.w900,
                color: const Color(0xFF007AFF),
                letterSpacing: 2,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProfilePhoto() {
    final photoUrl = widget.profile.photos.isNotEmpty
        ? widget.profile.photos[_currentPhotoIndex]
        : widget.profile.primaryPhoto;

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child: CachedNetworkImage(
        key: ValueKey(photoUrl),
        imageUrl: photoUrl,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        cacheManager: AppCacheManager.instance,
        placeholder: (context, url) => _buildShimmerPlaceholder(),
        errorWidget: (context, url, error) => _buildErrorWidget(),
      ),
    );
  }

  Widget _buildShimmerPlaceholder() {
    return Shimmer.fromColors(
      baseColor: Colors.grey[300]!,
      highlightColor: Colors.grey[100]!,
      child: Container(
        color: Colors.white,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.person,
                size: 80,
                color: Colors.grey[400],
              ),
              const SizedBox(height: 16),
              Container(
                width: 120,
                height: 20,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildErrorWidget() {
    // İnternet yokken veya hata durumunda shimmer efekti göster (yükleniyor gibi)
    return Shimmer.fromColors(
      baseColor: Colors.grey[300]!,
      highlightColor: Colors.grey[100]!,
      child: Container(
        color: Colors.white,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.person,
                  size: 60,
                  color: Colors.grey[400],
                ),
              ),
              const SizedBox(height: 16),
              Container(
                width: 140,
                height: 16,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPhotoIndicators() {
    return Positioned(
      top: 12,
      left: 12,
      right: 12,
      child: Row(
        children: List.generate(
          widget.profile.photos.length,
          (index) => Expanded(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              height: 4,
              margin: const EdgeInsets.symmetric(horizontal: 2),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(2),
                color: index == _currentPhotoIndex
                    ? Colors.white
                    : Colors.white.withValues(alpha: 0.4),
                boxShadow: index == _currentPhotoIndex
                    ? [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.3),
                          blurRadius: 4,
                        ),
                      ]
                    : null,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGradientOverlay() {
    return Positioned.fill(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.black.withValues(alpha: 0.1),
              Colors.transparent,
              Colors.transparent,
              Colors.black.withValues(alpha: 0.4),
              Colors.black.withValues(alpha: 0.85),
            ],
            stops: const [0.0, 0.15, 0.5, 0.75, 1.0],
          ),
        ),
      ),
    );
  }

  Widget _buildProfileInfo() {
    return Positioned(
      left: 20,
      right: 20,
      bottom: 24,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Name and age
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Flexible(
                      child: Text(
                        widget.profile.name,
                        style: GoogleFonts.poppins(
                          fontSize: 30,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          shadows: [
                            Shadow(
                              color: Colors.black.withValues(alpha: 0.4),
                              blurRadius: 10,
                            ),
                          ],
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      '${widget.profile.age}',
                      style: GoogleFonts.poppins(
                        fontSize: 26,
                        fontWeight: FontWeight.w400,
                        color: Colors.white,
                        shadows: [
                          Shadow(
                            color: Colors.black.withValues(alpha: 0.4),
                            blurRadius: 10,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              // Info button
              GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  setState(() => _showDetails = !_showDetails);
                },
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.3),
                      width: 1.5,
                    ),
                  ),
                  child: Icon(
                    _showDetails ? Icons.expand_more : Icons.info_outline,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          // University
          if (widget.profile.university.isNotEmpty)
            _buildInfoRow(
              Icons.school_outlined,
              widget.profile.university,
            ),

          // Department
          if (widget.profile.department.isNotEmpty)
            _buildInfoRow(
              Icons.auto_stories_outlined,
              widget.profile.department,
            ),

          // Bio preview
          if (widget.profile.bio.isNotEmpty && !_showDetails)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text(
                widget.profile.bio,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: Colors.white.withValues(alpha: 0.9),
                  height: 1.4,
                ),
              ),
            ),

          // Interests
          if (widget.profile.interests.isNotEmpty && !_showDetails)
            Padding(
              padding: const EdgeInsets.only(top: 14),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: widget.profile.interests.take(4).map((interest) {
                  return Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.25),
                        width: 1,
                      ),
                    ),
                    child: Text(
                      interest,
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: Colors.white,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        children: [
          Icon(
            icon,
            size: 16,
            color: Colors.white.withValues(alpha: 0.85),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: Colors.white.withValues(alpha: 0.9),
                fontWeight: FontWeight.w400,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailSheet() {
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: GestureDetector(
        onTap: () {}, // Prevent tap from propagating
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 25,
                offset: const Offset(0, -8),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle
              Center(
                child: Container(
                  width: 48,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Name and age
              Text(
                '${widget.profile.name}, ${widget.profile.age}',
                style: GoogleFonts.poppins(
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                  color: Colors.grey[850],
                ),
              ),

              const SizedBox(height: 20),

              // Bio
              if (widget.profile.bio.isNotEmpty) ...[
                Row(
                  children: [
                    Container(
                      width: 4,
                      height: 20,
                      decoration: BoxDecoration(
                        color: const Color(0xFF5C6BC0),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'Hakkında',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[800],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  widget.profile.bio,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: Colors.grey[700],
                    height: 1.6,
                  ),
                ),
                const SizedBox(height: 20),
              ],

              // Education
              if (widget.profile.university.isNotEmpty) ...[
                _buildDetailRow(
                  Icons.school_rounded,
                  'Üniversite',
                  widget.profile.university,
                ),
              ],

              if (widget.profile.department.isNotEmpty) ...[
                _buildDetailRow(
                  Icons.auto_stories_rounded,
                  'Bölüm',
                  widget.profile.department,
                ),
              ],

              // Interests
              if (widget.profile.interests.isNotEmpty) ...[
                const SizedBox(height: 20),
                Row(
                  children: [
                    Container(
                      width: 4,
                      height: 20,
                      decoration: BoxDecoration(
                        color: const Color(0xFF5C6BC0),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'İlgi Alanları',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[800],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: widget.profile.interests.map((interest) {
                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            const Color(0xFF5C6BC0).withValues(alpha: 0.08),
                            const Color(0xFF7986CB).withValues(alpha: 0.08),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(25),
                        border: Border.all(
                          color: const Color(0xFF5C6BC0).withValues(alpha: 0.2),
                        ),
                      ),
                      child: Text(
                        interest,
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          color: const Color(0xFF5C6BC0),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFF5C6BC0).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              size: 22,
              color: const Color(0xFF5C6BC0),
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
                const SizedBox(height: 2),
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
      ),
    );
  }
}

/// Action buttons for swipe card
class SwipeActionButtons extends StatelessWidget {
  final VoidCallback onDislike;
  final VoidCallback onSuperLike;
  final VoidCallback onLike;
  final VoidCallback? onUndo;
  final bool canUndo;

  const SwipeActionButtons({
    super.key,
    required this.onDislike,
    required this.onSuperLike,
    required this.onLike,
    this.onUndo,
    this.canUndo = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // Undo button
          if (canUndo && onUndo != null)
            _buildActionButton(
              icon: Icons.replay_rounded,
              color: const Color(0xFFFFB800),
              size: 52,
              iconSize: 24,
              onTap: () {
                HapticFeedback.mediumImpact();
                onUndo!();
              },
            ),

          // Dislike button
          _buildActionButton(
            icon: Icons.close_rounded,
            color: const Color(0xFFFF4458),
            size: 64,
            iconSize: 32,
            onTap: () {
              HapticFeedback.mediumImpact();
              onDislike();
            },
            showGlow: true,
          ),

          // Super like button
          _buildActionButton(
            icon: Icons.star_rounded,
            color: const Color(0xFF00D4FF),
            size: 52,
            iconSize: 26,
            onTap: () {
              HapticFeedback.mediumImpact();
              onSuperLike();
            },
          ),

          // Like button
          _buildActionButton(
            icon: Icons.waving_hand_rounded,
            color: const Color(0xFF00E676),
            size: 64,
            iconSize: 32,
            onTap: () {
              HapticFeedback.mediumImpact();
              onLike();
            },
            showGlow: true,
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required Color color,
    required double size,
    required double iconSize,
    required VoidCallback onTap,
    bool showGlow = false,
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
            if (showGlow)
              BoxShadow(
                color: color.withValues(alpha: 0.35),
                blurRadius: 20,
                spreadRadius: 2,
              ),
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 15,
              offset: const Offset(0, 5),
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
            highlightColor: color.withValues(alpha: 0.1),
            child: Center(
              child: Icon(
                icon,
                color: color,
                size: iconSize,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Empty state widget when no more profiles
class NoMoreProfilesWidget extends StatelessWidget {
  final VoidCallback onRefresh;

  const NoMoreProfilesWidget({
    super.key,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Animated icon container
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.8, end: 1.0),
              duration: const Duration(milliseconds: 600),
              curve: Curves.easeInOut,
              builder: (context, value, child) {
                return Transform.scale(
                  scale: value,
                  child: Container(
                    padding: const EdgeInsets.all(32),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          const Color(0xFF5C6BC0).withValues(alpha: 0.15),
                          const Color(0xFF7986CB).withValues(alpha: 0.1),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.explore_off_rounded,
                      size: 72,
                      color: Color(0xFF5C6BC0),
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 32),
            Text(
              'Şu an için profil kalmadı',
              style: GoogleFonts.poppins(
                fontSize: 22,
                fontWeight: FontWeight.w600,
                color: Colors.grey[800],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Daha sonra tekrar kontrol et\nveya filtrelerini değiştir',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 15,
                color: Colors.grey[600],
                height: 1.5,
              ),
            ),
            const SizedBox(height: 40),
            Container(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF5C6BC0), Color(0xFF7986CB)],
                ),
                borderRadius: BorderRadius.circular(30),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF5C6BC0).withValues(alpha: 0.4),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: ElevatedButton.icon(
                onPressed: onRefresh,
                icon: const Icon(Icons.refresh_rounded, size: 22),
                label: Text(
                  'Yenile',
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  foregroundColor: Colors.white,
                  shadowColor: Colors.transparent,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 36,
                    vertical: 16,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
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

/// Beautiful full-screen Match popup widget - Friendship themed
class MatchPopup extends StatefulWidget {
  final UserProfile matchedProfile;
  final UserProfile? currentUserProfile;
  final VoidCallback onSendMessage;
  final VoidCallback onKeepSwiping;

  const MatchPopup({
    super.key,
    required this.matchedProfile,
    this.currentUserProfile,
    required this.onSendMessage,
    required this.onKeepSwiping,
  });

  @override
  State<MatchPopup> createState() => _MatchPopupState();
}

class _MatchPopupState extends State<MatchPopup> with TickerProviderStateMixin {
  late AnimationController _celebrationController;
  late AnimationController _scaleController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _celebrationController = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    )..repeat();

    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _scaleController, curve: Curves.elasticOut),
    );
    _scaleController.forward();

    // Haptic feedback on match
    HapticFeedback.heavyImpact();
  }

  @override
  void dispose() {
    _celebrationController.dispose();
    _scaleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF5C6BC0), // Ana pembe/kırmızı
              Color(0xFF7986CB), // Açık pembe
              Color(0xFFFF7043), // Turuncu
            ],
          ),
        ),
        child: Stack(
          children: [
            // Floating stars/sparkles background
            ..._buildFloatingSparkles(),

            // Main content
            SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(height: 40),

                      // Celebration icon
                      ScaleTransition(
                        scale: _scaleAnimation,
                        child: Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.celebration_rounded,
                            size: 60,
                            color: Colors.white,
                          ),
                        ),
                      ),

                      const SizedBox(height: 24),

                      // "Yeni Arkadaş!" text
                      ScaleTransition(
                        scale: _scaleAnimation,
                        child: Column(
                          children: [
                            Text(
                              "Yeni",
                              style: GoogleFonts.poppins(
                                fontSize: 32,
                                fontWeight: FontWeight.w300,
                                color: Colors.white,
                                letterSpacing: 4,
                              ),
                            ),
                            ShaderMask(
                              shaderCallback: (bounds) => const LinearGradient(
                                colors: [
                                  Colors.white,
                                  Color(0xFFFFE57F),
                                ],
                              ).createShader(bounds),
                              child: Text(
                                'ARKADAŞ!',
                                style: GoogleFonts.poppins(
                                  fontSize: 48,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                  letterSpacing: 4,
                                  shadows: [
                                    Shadow(
                                      color:
                                          Colors.black.withValues(alpha: 0.3),
                                      blurRadius: 20,
                                      offset: const Offset(0, 5),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 20),

                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 32),
                        child: Text(
                          'Sen ve ${widget.matchedProfile.name} artık arkadaşsınız!',
                          style: GoogleFonts.poppins(
                            fontSize: 17,
                            color: Colors.white.withValues(alpha: 0.95),
                            fontWeight: FontWeight.w400,
                            height: 1.4,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),

                      const SizedBox(height: 50),

                      // Profile photos
                      ScaleTransition(
                        scale: _scaleAnimation,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            // Current user photo (if available)
                            _buildProfileCircle(
                              widget.currentUserProfile?.primaryPhoto,
                              isCurrentUser: true,
                            ),
                            // Handshake/connection icon in the middle
                            Container(
                              margin:
                                  const EdgeInsets.symmetric(horizontal: 12),
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.2),
                                    blurRadius: 20,
                                    spreadRadius: 2,
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.handshake_rounded,
                                color: Color(0xFF667eea),
                                size: 32,
                              ),
                            ),
                            // Matched profile photo
                            _buildProfileCircle(
                              widget.matchedProfile.primaryPhoto,
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 60),

                      // Action buttons
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 32),
                        child: Column(
                          children: [
                            // Send message button
                            Container(
                              width: double.infinity,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.15),
                                    blurRadius: 20,
                                    offset: const Offset(0, 8),
                                  ),
                                ],
                              ),
                              child: ElevatedButton.icon(
                                onPressed: widget.onSendMessage,
                                icon: const Icon(Icons.chat_bubble_rounded),
                                label: Text(
                                  'Mesaj Gönder',
                                  style: GoogleFonts.poppins(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.white,
                                  foregroundColor: const Color(0xFF667eea),
                                  shadowColor: Colors.transparent,
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 18),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                ),
                              ),
                            ),

                            const SizedBox(height: 16),

                            // Keep swiping button
                            Container(
                              width: double.infinity,
                              decoration: BoxDecoration(
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.5),
                                  width: 2,
                                ),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: TextButton(
                                onPressed: widget.onKeepSwiping,
                                style: TextButton.styleFrom(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 16),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                ),
                                child: Text(
                                  'Keşfetmeye Devam Et',
                                  style: GoogleFonts.poppins(
                                    fontSize: 16,
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileCircle(String? photoUrl, {bool isCurrentUser = false}) {
    return Container(
      width: 130,
      height: 130,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: Colors.white,
          width: 4,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 25,
            spreadRadius: 3,
          ),
        ],
      ),
      child: ClipOval(
        child: photoUrl != null
            ? CachedNetworkImage(
                imageUrl: photoUrl,
                fit: BoxFit.cover,
                cacheManager: AppCacheManager.instance,
                placeholder: (context, url) => Shimmer.fromColors(
                  baseColor: Colors.grey[300]!,
                  highlightColor: Colors.grey[100]!,
                  child: Container(
                    color: Colors.grey[200],
                    child: const Icon(Icons.person, size: 50, color: Colors.grey),
                  ),
                ),
                errorWidget: (context, url, error) => Shimmer.fromColors(
                  baseColor: Colors.grey[300]!,
                  highlightColor: Colors.grey[100]!,
                  child: Container(
                    color: Colors.grey[200],
                    child: Icon(
                      Icons.person,
                      size: 50,
                      color: isCurrentUser ? const Color(0xFF667eea) : Colors.grey,
                    ),
                  ),
                ),
              )
            : Container(
                color: Colors.white.withValues(alpha: 0.3),
                child: Icon(
                  Icons.person,
                  size: 50,
                  color: isCurrentUser ? Colors.white : Colors.grey[300],
                ),
              ),
      ),
    );
  }

  List<Widget> _buildFloatingSparkles() {
    return List.generate(12, (index) {
      final random = index * 0.15;
      final isLeft = index % 2 == 0;
      return Positioned(
        left: isLeft ? (index * 30.0) : null,
        right: !isLeft ? ((index - 1) * 25.0) : null,
        top: 80.0 + (index * 50.0),
        child: AnimatedBuilder(
          animation: _celebrationController,
          builder: (context, child) {
            return Transform.translate(
              offset: Offset(
                15 *
                    math.sin(
                        _celebrationController.value * 2 * math.pi + random),
                20 *
                    math.cos(
                        _celebrationController.value * 2 * math.pi + random),
              ),
              child: Transform.rotate(
                angle: _celebrationController.value * 2 * math.pi,
                child: Icon(
                  index % 3 == 0
                      ? Icons.star_rounded
                      : index % 3 == 1
                          ? Icons.auto_awesome
                          : Icons.flare_rounded,
                  color: Colors.white.withValues(alpha: 0.25),
                  size: 20 + (index * 2).toDouble(),
                ),
              ),
            );
          },
        ),
      );
    });
  }
}
