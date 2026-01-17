import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

/// Reusable shimmer placeholder for images
/// Used for both placeholder and errorWidget in CachedNetworkImage
/// This ensures images show "loading" state even when there's an error (no X icon)
class ShimmerPlaceholder extends StatelessWidget {
  final double? width;
  final double? height;
  final IconData icon;
  final double iconSize;
  final BorderRadius? borderRadius;
  final Color? baseColor;
  final Color? highlightColor;

  const ShimmerPlaceholder({
    super.key,
    this.width,
    this.height,
    this.icon = Icons.person,
    this.iconSize = 60,
    this.borderRadius,
    this.baseColor,
    this.highlightColor,
  });

  /// Standard person placeholder for profile photos
  const ShimmerPlaceholder.person({
    super.key,
    this.width,
    this.height,
    this.borderRadius,
    this.baseColor,
    this.highlightColor,
  })  : icon = Icons.person,
        iconSize = 60;

  /// Smaller avatar placeholder
  const ShimmerPlaceholder.avatar({
    super.key,
    this.width,
    this.height,
    this.borderRadius,
    this.baseColor,
    this.highlightColor,
  })  : icon = Icons.person,
        iconSize = 40;

  /// Image placeholder (generic)
  const ShimmerPlaceholder.image({
    super.key,
    this.width,
    this.height,
    this.borderRadius,
    this.baseColor,
    this.highlightColor,
  })  : icon = Icons.image,
        iconSize = 50;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: borderRadius ?? BorderRadius.zero,
      child: Shimmer.fromColors(
        baseColor: baseColor ?? Colors.grey[300]!,
        highlightColor: highlightColor ?? Colors.grey[100]!,
        child: Container(
          width: width,
          height: height,
          color: Colors.grey[200],
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
}

/// Shimmer placeholder specifically for swipe cards (larger)
class SwipeCardShimmer extends StatelessWidget {
  const SwipeCardShimmer({super.key});

  @override
  Widget build(BuildContext context) {
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
              const SizedBox(height: 8),
              Container(
                width: 100,
                height: 12,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
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

  const IndigoShimmerPlaceholder({
    super.key,
    this.iconSize = 100,
  });

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: const Color(0xFF5C6BC0),
      highlightColor: const Color(0xFF7986CB),
      child: Container(
        color: const Color(0xFF5C6BC0),
        child: Center(
          child: Icon(
            Icons.person,
            size: iconSize,
            color: Colors.white54,
          ),
        ),
      ),
    );
  }
}
