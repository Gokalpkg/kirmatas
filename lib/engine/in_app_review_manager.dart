import 'package:flutter/material.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:url_launcher/url_launcher.dart';
import '../storage/save_manager.dart';
import 'i18n.dart';

/// Manages Google Play store review and 5-star rating requests.
/// Prompts at the best gameplay moments (3-star level victories) every 2-3 days
/// until the player rates the game.
class InAppReviewManager {
  static final InAppReviewManager instance = InAppReviewManager._internal();
  InAppReviewManager._internal();

  final InAppReview _inAppReview = InAppReview.instance;

  static const String storeUrl =
      'https://play.google.com/store/apps/details?id=com.kaunos.kirmatas';
  static const String marketUrl =
      'market://details?id=com.kaunos.kirmatas';

  /// Checks eligibility and shows the 5-star rating dialog at the best gameplay moment.
  Future<void> checkAndRequestReview({
    required BuildContext context,
    required int level,
    required int stars,
  }) async {
    final save = SaveManager.instance;
    // Don't ask if user already gave a rating
    if (save.hasRatedGame) return;
    // Only prompt at high-satisfaction moments: 3-star level clears
    if (stars < 3) return;
    // Don't disrupt initial onboarding (wait until at least level 3)
    if (level < 3) return;
    // Enforce 2-3 days (48-hour) cooldown between prompts
    if (!save.canPromptForReview()) return;

    // Mark as requested immediately to prevent re-entrancy
    await save.markReviewRequested();
    // Record prompt display timestamp to enforce the 2-3 days interval
    await save.recordReviewPromptShown();

    if (context.mounted) {
      await showFiveStarRatingDialog(context, level: level);
    }
  }

  /// Opens the store listing page directly.
  Future<void> openStoreListing() async {
    try {
      final isAvailable = await _inAppReview.isAvailable();
      if (isAvailable) {
        await _inAppReview.openStoreListing();
        return;
      }
    } catch (_) {}

    try {
      final marketUri = Uri.parse(marketUrl);
      if (await canLaunchUrl(marketUri)) {
        await launchUrl(marketUri, mode: LaunchMode.externalApplication);
        return;
      }
    } catch (_) {}

    try {
      final webUri = Uri.parse(storeUrl);
      await launchUrl(webUri, mode: LaunchMode.externalApplication);
    } catch (_) {}
  }

  /// Interactive 5-star rating dialog designed specifically for high-satisfaction moments.
  Future<void> showFiveStarRatingDialog(BuildContext context, {int level = 3}) {
    return showDialog(
      context: context,
      barrierDismissible: true,
      builder: (dlgContext) => _FiveStarDialogContent(
        level: level,
        onRate5Stars: () async {
          Navigator.of(dlgContext).pop();
          await SaveManager.instance.markGameRated();
          await openStoreListing();
        },
        onLater: () {
          Navigator.of(dlgContext).pop();
        },
      ),
    );
  }

  /// Backward-compatible alias for existing tests and callers.
  Future<void> showFallbackRatingDialog(BuildContext context, {int level = 3}) {
    return showFiveStarRatingDialog(context, level: level);
  }
}

class _FiveStarDialogContent extends StatefulWidget {
  final int level;
  final VoidCallback onRate5Stars;
  final VoidCallback onLater;

  const _FiveStarDialogContent({
    required this.level,
    required this.onRate5Stars,
    required this.onLater,
  });

  @override
  State<_FiveStarDialogContent> createState() => _FiveStarDialogContentState();
}

class _FiveStarDialogContentState extends State<_FiveStarDialogContent> {
  int _selectedStars = 5;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF101422),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: const BorderSide(color: Color(0xFFFFD54F), width: 1.5),
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
              I18n.tr('rate_us_title'),
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 20,
                fontFamily: 'Rajdhani',
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              I18n.tr('rate_us_desc'),
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFFB0BEC5),
                fontSize: 13,
                fontWeight: FontWeight.w500,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 18),
            // Interactive 5 stars row
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(5, (index) {
                final starIndex = index + 1;
                final isFilled = starIndex <= _selectedStars;
                return GestureDetector(
                  onTap: () {
                    setState(() => _selectedStars = starIndex);
                    // Tapping 5th star directly triggers the store rating!
                    if (starIndex == 5) {
                      widget.onRate5Stars();
                    }
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Icon(
                      isFilled ? Icons.star_rounded : Icons.star_outline_rounded,
                      color: isFilled ? const Color(0xFFFFD54F) : Colors.white30,
                      size: 38,
                    ),
                  ),
                );
              }),
            ),
            const SizedBox(height: 22),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: widget.onLater,
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: Text(
                      I18n.tr('rate_us_later_btn'),
                      style: const TextStyle(
                        color: Colors.white54,
                        fontWeight: FontWeight.w700,
                        fontSize: 13.5,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFFD54F),
                      foregroundColor: const Color(0xFF0F141F),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      elevation: 4,
                    ),
                    onPressed: widget.onRate5Stars,
                    child: Text(
                      I18n.tr('rate_us_5_stars_btn'),
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 14.5,
                        letterSpacing: 0.4,
                      ),
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
}
