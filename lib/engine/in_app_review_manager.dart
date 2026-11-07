import 'package:flutter/material.dart';
import 'package:in_app_review/in_app_review.dart';
import '../storage/save_manager.dart';
import 'i18n.dart';

/// Manages Google Play native in-app review requests and store rating fallback.
/// Strictly rate-limited to once per installation when a player clears Level 6 or Level 10
/// with a 3-star rating.
class InAppReviewManager {
  static final InAppReviewManager instance = InAppReviewManager._internal();
  InAppReviewManager._internal();

  final InAppReview _inAppReview = InAppReview.instance;

  /// Checks eligibility and requests native in-app review or shows local dialog fallback.
  Future<void> checkAndRequestReview({
    required BuildContext context,
    required int level,
    required int stars,
  }) async {
    final save = SaveManager.instance;
    // Strictly rate-limited to once per install
    if (save.hasRequestedReview) return;
    if (stars < 3) return;
    if (level != 6 && level != 10) return;

    // Mark as requested immediately to prevent re-entrancy
    await save.markReviewRequested();

    try {
      final isAvailable = await _inAppReview.isAvailable();
      if (isAvailable) {
        await _inAppReview.requestReview();
      } else {
        if (context.mounted) {
          await showFallbackRatingDialog(context, level: level);
        }
      }
    } catch (e) {
      debugPrint('[InAppReviewManager] Error requesting review: $e');
      if (context.mounted) {
        await showFallbackRatingDialog(context, level: level);
      }
    }
  }

  /// Elegant in-theme fallback dialog if native in-app review sheet cannot be shown.
  Future<void> showFallbackRatingDialog(BuildContext context, {int level = 6}) {
    final isTr = I18n.currentLang == 'tr';
    return showDialog(
      context: context,
      barrierDismissible: true,
      builder: (dlgContext) => Dialog(
        backgroundColor: const Color(0xFF101422),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: const BorderSide(color: Color(0xFFFFD700), width: 1.5),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 68,
                height: 68,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [Color(0xFFFFD54F), Color(0xFFFF8F00)],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Color(0x66FFD54F),
                      blurRadius: 18,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.star_rounded,
                  color: Colors.white,
                  size: 44,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                isTr ? 'Kırmataş\'ı Sevdin mi?' : 'Enjoying Kirmatas?',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 20,
                  fontFamily: 'Rajdhani',
                ),
              ),
              const SizedBox(height: 8),
              Text(
                isTr
                    ? '$level. Seviyeyi kusursuz 3 yıldızla geçtin! Google Play\'de 5 yıldız vererek bize destek olmak ister misin?'
                    : 'You cleared Level $level with 3 stars! Would you like to leave a 5-star rating on Google Play?',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFFB0BEC5),
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 22),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.of(dlgContext).pop(),
                      child: Text(
                        isTr ? 'Daha Sonra' : 'Maybe Later',
                        style: const TextStyle(
                          color: Colors.white54,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFFD700),
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      onPressed: () async {
                        Navigator.of(dlgContext).pop();
                        try {
                          await _inAppReview.openStoreListing();
                        } catch (_) {}
                      },
                      child: Text(
                        isTr ? 'Puan Ver' : 'Rate App',
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 14,
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
  }
}
