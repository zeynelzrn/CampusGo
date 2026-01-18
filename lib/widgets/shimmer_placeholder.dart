import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

/// CampusGo App Theme Colors
class AppColors {
  static const Color indigo = Color(0xFF5C6BC0);
  static const Color indigoLight = Color(0xFF7986CB);
  static const Color indigoDark = Color(0xFF3F51B5);
  static const Color mint = Color(0xFF10B981);
  static const Color coral = Color(0xFFF87171);
  static const Color amber = Color(0xFFF59E0B);
}

/// Modern shimmer placeholder with gradient effect
/// No X icons - always shows elegant loading state
class ShimmerPlaceholder extends StatelessWidget {
  final double? width;
  final double? height;
  final IconData icon;
  final double iconSize;
  final BorderRadius? borderRadius;
  final bool useIndigoGradient;

  const ShimmerPlaceholder({
    super.key,
    this.width,
    this.height,
    this.icon = Icons.person,
    this.iconSize = 60,
    this.borderRadius,
    this.useIndigoGradient = false,
  });

  /// Standard person placeholder for profile photos
  const ShimmerPlaceholder.person({
    super.key,
    this.width,
    this.height,
    this.borderRadius,
    this.useIndigoGradient = false,
  })  : icon = Icons.person,
        iconSize = 60;

  /// Smaller avatar placeholder
  const ShimmerPlaceholder.avatar({
    super.key,
    this.width,
    this.height,
    this.borderRadius,
    this.useIndigoGradient = false,
  })  : icon = Icons.person,
        iconSize = 40;

  /// Image placeholder (generic)
  const ShimmerPlaceholder.image({
    super.key,
    this.width,
    this.height,
    this.borderRadius,
    this.useIndigoGradient = false,
  })  : icon = Icons.image,
        iconSize = 50;

  /// Indigo themed placeholder (for profile/main screens)
  const ShimmerPlaceholder.indigo({
    super.key,
    this.width,
    this.height,
    this.borderRadius,
    this.icon = Icons.person,
    this.iconSize = 60,
  }) : useIndigoGradient = true;

  @override
  Widget build(BuildContext context) {
    if (useIndigoGradient) {
      return _buildIndigoGradientShimmer();
    }
    return _buildStandardShimmer();
  }

  Widget _buildStandardShimmer() {
    return ClipRRect(
      borderRadius: borderRadius ?? BorderRadius.zero,
      child: Shimmer.fromColors(
        baseColor: Colors.grey[300]!,
        highlightColor: Colors.grey[100]!,
        child: Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.grey[300]!, Colors.grey[200]!],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Center(
            child: Icon(
              icon,
              size: iconSize,
              color: Colors.grey[400],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildIndigoGradientShimmer() {
    return ClipRRect(
      borderRadius: borderRadius ?? BorderRadius.zero,
      child: Shimmer.fromColors(
        baseColor: AppColors.indigo.withValues(alpha: 0.6),
        highlightColor: AppColors.indigoLight.withValues(alpha: 0.8),
        child: Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppColors.indigo.withValues(alpha: 0.4),
                AppColors.indigoLight.withValues(alpha: 0.3),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Center(
            child: Icon(
              icon,
              size: iconSize,
              color: Colors.white.withValues(alpha: 0.5),
            ),
          ),
        ),
      ),
    );
  }
}

/// Shimmer placeholder specifically for swipe cards (larger)
class SwipeCardShimmer extends StatelessWidget {
  final bool useIndigoGradient;

  const SwipeCardShimmer({
    super.key,
    this.useIndigoGradient = true,
  });

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: useIndigoGradient
          ? AppColors.indigo.withValues(alpha: 0.5)
          : Colors.grey[300]!,
      highlightColor: useIndigoGradient
          ? AppColors.indigoLight.withValues(alpha: 0.7)
          : Colors.grey[100]!,
      child: Container(
        decoration: BoxDecoration(
          gradient: useIndigoGradient
              ? const LinearGradient(
                  colors: [
                    Color(0xFF5C6BC0),
                    Color(0xFF7986CB),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                )
              : null,
          color: useIndigoGradient ? null : Colors.white,
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Avatar circle
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: useIndigoGradient
                      ? Colors.white.withValues(alpha: 0.2)
                      : Colors.grey[300],
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.person_rounded,
                  size: 50,
                  color: useIndigoGradient
                      ? Colors.white.withValues(alpha: 0.5)
                      : Colors.grey[400],
                ),
              ),
              const SizedBox(height: 20),
              // Name placeholder
              Container(
                width: 160,
                height: 20,
                decoration: BoxDecoration(
                  color: useIndigoGradient
                      ? Colors.white.withValues(alpha: 0.2)
                      : Colors.grey[300],
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              const SizedBox(height: 12),
              // Subtitle placeholder
              Container(
                width: 120,
                height: 14,
                decoration: BoxDecoration(
                  color: useIndigoGradient
                      ? Colors.white.withValues(alpha: 0.15)
                      : Colors.grey[300],
                  borderRadius: BorderRadius.circular(7),
                ),
              ),
              const SizedBox(height: 8),
              // Third line placeholder
              Container(
                width: 80,
                height: 12,
                decoration: BoxDecoration(
                  color: useIndigoGradient
                      ? Colors.white.withValues(alpha: 0.1)
                      : Colors.grey[300],
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Shimmer placeholder with indigo theme (for profile screens)
class IndigoShimmerPlaceholder extends StatelessWidget {
  final double iconSize;
  final BorderRadius? borderRadius;

  const IndigoShimmerPlaceholder({
    super.key,
    this.iconSize = 100,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: borderRadius ?? BorderRadius.zero,
      child: Shimmer.fromColors(
        baseColor: AppColors.indigo,
        highlightColor: AppColors.indigoLight,
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Color(0xFF5C6BC0),
                Color(0xFF7986CB),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Center(
            child: Icon(
              Icons.person_rounded,
              size: iconSize,
              color: Colors.white.withValues(alpha: 0.4),
            ),
          ),
        ),
      ),
    );
  }
}

/// Profile image shimmer with elegant gradient
class ProfileImageShimmer extends StatelessWidget {
  final double size;
  final bool isCircle;

  const ProfileImageShimmer({
    super.key,
    this.size = 100,
    this.isCircle = true,
  });

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: AppColors.indigo.withValues(alpha: 0.5),
      highlightColor: AppColors.indigoLight.withValues(alpha: 0.7),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: isCircle ? BoxShape.circle : BoxShape.rectangle,
          borderRadius: isCircle ? null : BorderRadius.circular(16),
          gradient: LinearGradient(
            colors: [
              AppColors.indigo.withValues(alpha: 0.4),
              AppColors.indigoLight.withValues(alpha: 0.3),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Center(
          child: Icon(
            Icons.person_rounded,
            size: size * 0.5,
            color: Colors.white.withValues(alpha: 0.4),
          ),
        ),
      ),
    );
  }
}

/// Chat list item shimmer
class ChatItemShimmer extends StatelessWidget {
  const ChatItemShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: Colors.grey[300]!,
      highlightColor: Colors.grey[100]!,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            // Avatar
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 12),
            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 120,
                    height: 16,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: 200,
                    height: 12,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                ],
              ),
            ),
            // Time
            Container(
              width: 40,
              height: 12,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(6),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Grid item shimmer for profile cards
class ProfileCardShimmer extends StatelessWidget {
  const ProfileCardShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: AppColors.indigo.withValues(alpha: 0.4),
      highlightColor: AppColors.indigoLight.withValues(alpha: 0.6),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            colors: [
              AppColors.indigo.withValues(alpha: 0.3),
              AppColors.indigoLight.withValues(alpha: 0.2),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: double.infinity,
                    height: 16,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    width: 80,
                    height: 12,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(6),
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
}
