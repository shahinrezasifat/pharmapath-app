import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

/// Advanced image loading utility with caching, placeholder support,
/// and error handling for pharmaceutical images and company logos.
class ImageLoader {
  /// Loads a medicine image with progressive loading and fallback support
  static Widget medicineImage({
    required String? imageUrl,
    required String medicineName,
    String? genericName,
    double width = double.infinity,
    double height = 200,
    BoxFit fit = BoxFit.cover,
    BorderRadius borderRadius = BorderRadius.zero,
    bool showPlaceholder = true,
    VoidCallback? onTap,
  }) {
    if (imageUrl == null || imageUrl.isEmpty) {
      return _buildPlaceholder(
        medicineName: medicineName,
        genericName: genericName,
        width: width,
        height: height,
        borderRadius: borderRadius,
        onTap: onTap,
      );
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          borderRadius: borderRadius,
          color: Colors.grey.shade100,
        ),
        child: ClipRRect(
          borderRadius: borderRadius,
          child: CachedNetworkImage(
            imageUrl: imageUrl,
            fit: fit,
            width: width,
            height: height,
            placeholder: (context, url) => showPlaceholder
                ? _buildShimmerPlaceholder(width: width, height: height)
                : const SizedBox(),
            errorWidget: (context, url, error) => _buildPlaceholder(
              medicineName: medicineName,
              genericName: genericName,
              width: width,
              height: height,
              borderRadius: borderRadius,
              showError: true,
            ),
            fadeInDuration: const Duration(milliseconds: 300),
            fadeOutDuration: const Duration(milliseconds: 200),
          ),
        ),
      ),
    );
  }

  /// Loads a company logo with fallback to initials
  static Widget companyLogo({
    required String? logoUrl,
    required String companyName,
    double size = 48,
    Color backgroundColor = Colors.blueGrey,
    VoidCallback? onTap,
  }) {
    if (logoUrl == null || logoUrl.isEmpty) {
      return _buildLogoPlaceholder(
        companyName: companyName,
        size: size,
        backgroundColor: backgroundColor,
        onTap: onTap,
      );
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(size * 0.2),
          color: Colors.grey.shade100,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(size * 0.2),
          child: CachedNetworkImage(
            imageUrl: logoUrl,
            width: size,
            height: size,
            fit: BoxFit.contain,
            placeholder: (context, url) => Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(size * 0.2),
                color: Colors.grey.shade200,
              ),
              child: Center(
                child: SizedBox(
                  width: size * 0.5,
                  height: size * 0.5,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.grey.shade400,
                  ),
                ),
              ),
            ),
            errorWidget: (context, url, error) => _buildLogoPlaceholder(
              companyName: companyName,
              size: size,
              backgroundColor: backgroundColor,
              showError: true,
            ),
          ),
        ),
      ),
    );
  }

  /// Creates a medicine placeholder with initials or generic name
  static Widget _buildPlaceholder({
    required String medicineName,
    String? genericName,
    required double width,
    required double height,
    BorderRadius? borderRadius,
    bool showError = false,
    VoidCallback? onTap,
  }) {
    final displayText =
        genericName?.split(' ').first ?? medicineName.split(' ').first;
    final initials = displayText.length >= 2
        ? displayText.substring(0, 2).toUpperCase()
        : displayText.toUpperCase();

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          borderRadius: borderRadius ?? BorderRadius.zero,
          color: showError ? Colors.red.shade50 : Colors.blueGrey.shade50,
          border: Border.all(
            color: showError ? Colors.red.shade200 : Colors.blueGrey.shade200,
            width: 1,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              initials,
              style: TextStyle(
                fontSize: height * 0.15,
                fontWeight: FontWeight.bold,
                color: showError
                    ? Colors.red.shade400
                    : Colors.blueGrey.shade400,
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                showError ? 'ছবি লোড হতে ব্যর্থ' : 'ছবি অনুপলব্ধ',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  color: showError
                      ? Colors.red.shade400
                      : Colors.blueGrey.shade400,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Creates a company logo placeholder with initials
  static Widget _buildLogoPlaceholder({
    required String companyName,
    required double size,
    Color backgroundColor = Colors.blueGrey,
    bool showError = false,
    VoidCallback? onTap,
  }) {
    final words = companyName
        .trim()
        .split(RegExp(r'\s+'))
        .where((word) => word.isNotEmpty)
        .toList();
    final initials = words.length >= 2
        ? '${words[0][0]}${words[1][0]}'.toUpperCase()
        : words.length == 1 && words.first.length >= 2
        ? words.first.substring(0, 2).toUpperCase()
        : (words.isEmpty ? '?' : words.first.toUpperCase());

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(size * 0.2),
          color: showError ? Colors.red.shade50 : backgroundColor.withAlpha(25),
          border: Border.all(
            color: showError
                ? Colors.red.shade200
                : backgroundColor.withAlpha(76),
            width: 1,
          ),
        ),
        child: Center(
          child: Text(
            initials,
            style: TextStyle(
              fontSize: size * 0.3,
              fontWeight: FontWeight.bold,
              color: showError ? Colors.red.shade400 : backgroundColor,
            ),
          ),
        ),
      ),
    );
  }

  /// Creates a shimmer effect placeholder
  static Widget _buildShimmerPlaceholder({
    required double width,
    required double height,
  }) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            Colors.grey.shade200,
            Colors.grey.shade300,
            Colors.grey.shade200,
          ],
          stops: const [0.0, 0.5, 1.0],
        ),
      ),
      child: const SizedBox(),
    );
  }

  /// Pre-fetches images for faster loading
  static Future<void> preloadImages(List<String> imageUrls) async {
    for (final url in imageUrls) {
      if (url.isNotEmpty) {
        try {
          // In a real app, you would use a caching library here
          await Future.delayed(const Duration(milliseconds: 100));
        } catch (e) {
          // Silently ignore preload errors
        }
      }
    }
  }

  /// Clears the image cache
  static Future<void> clearCache() async {
    // In a real implementation, you would clear cached_network_image cache
    // For now, just return a completed future
    return Future.value();
  }

  /// Gets cached file for a URL
  static Future<String?> getCachedFile(String url) {
    return Future.value(null);
  }

  /// Gets file size of cached image
  static Future<int?> getCachedFileSize(String url) async {
    return null;
  }
}
