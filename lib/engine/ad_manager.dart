import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../storage/save_manager.dart';
import 'audio_manager.dart';

class AdManager extends ChangeNotifier {
  static final AdManager instance = AdManager._internal();
  AdManager._internal();

  // User's provided AdMob Rewarded Ad Unit ID
  static const String rewardedAdUnitId = 'ca-app-pub-9505724609102225/1791945382';
  
  // Standard Google AdMob test rewarded ad unit ID (used as reliable fallback in development/zero-inventory)
  static const String testRewardedAdUnitId = 'ca-app-pub-3940256099942544/5224354917';

  // 90 seconds (1.5 minutes) anti-spam cooldown between rewarded ad watches
  static const int cooldownSeconds = 90;

  RewardedAd? _rewardedAd;
  bool _isLoading = false;
  bool _isShowing = false;
  bool _initialized = false;

  bool get isLoading => _isLoading;
  bool get isShowing => _isShowing;
  bool get isAdReady => _rewardedAd != null;

  int get remainingCooldownSeconds {
    final lastTime = SaveManager.instance.lastAdWatchTime;
    if (lastTime == 0) return 0;
    final elapsedSec = (DateTime.now().millisecondsSinceEpoch - lastTime) ~/ 1000;
    final remaining = cooldownSeconds - elapsedSec;
    return remaining > 0 ? remaining : 0;
  }

  bool get canWatchAd => remainingCooldownSeconds == 0 && !_isLoading && !_isShowing;

  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;
    try {
      await MobileAds.instance.initialize();
    } catch (e) {
      debugPrint('MobileAds initialization error: $e');
    }
    preloadRewardedAd();
  }

  /// Preloads a rewarded ad in the background so it is instantly ready when clicked.
  void preloadRewardedAd() {
    if (_rewardedAd != null || _isLoading) return;
    _isLoading = true;
    notifyListeners();

    // First attempt to load with the user's production Ad Unit ID.
    // If it fails (e.g. no fill or unverified ID), fallback to Google's test ad unit ID.
    RewardedAd.load(
      adUnitId: rewardedAdUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _rewardedAd = ad;
          _isLoading = false;
          notifyListeners();
        },
        onAdFailedToLoad: (LoadAdError error) {
          debugPrint('Production rewarded ad failed: $error. Falling back to test Ad Unit ID...');
          // Fallback to test ID
          RewardedAd.load(
            adUnitId: testRewardedAdUnitId,
            request: const AdRequest(),
            rewardedAdLoadCallback: RewardedAdLoadCallback(
              onAdLoaded: (testAd) {
                _rewardedAd = testAd;
                _isLoading = false;
                notifyListeners();
              },
              onAdFailedToLoad: (LoadAdError testError) {
                debugPrint('Test rewarded ad also failed: $testError');
                _rewardedAd = null;
                _isLoading = false;
                notifyListeners();
              },
            ),
          );
        },
      ),
    );
  }

  /// Shows the rewarded ad to earn 50 gold.
  /// Prevents spamming and double clicks.
  Future<void> watchAdForGold(
    BuildContext context, {
    required void Function(int goldReward) onSuccess,
    required void Function() onDismissedEarly,
  }) async {
    if (_isShowing) return;

    if (remainingCooldownSeconds > 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Lütfen bekleyin: $remainingCooldownSeconds saniye sonra tekrar reklam izleyebilirsiniz.'),
          backgroundColor: const Color(0xFF1E2438),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
      return;
    }

    if (_rewardedAd == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Reklam yükleniyor, lütfen birkaç saniye sonra tekrar deneyin...'),
          backgroundColor: const Color(0xFF1E2438),
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 2),
        ),
      );
      preloadRewardedAd();
      return;
    }

    _isShowing = true;
    notifyListeners();

    bool userEarnedReward = false;
    final currentAd = _rewardedAd!;

    currentAd.fullScreenContentCallback = FullScreenContentCallback(
      onAdShowedFullScreenContent: (ad) {
        debugPrint('Rewarded ad showed');
      },
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _rewardedAd = null;
        _isShowing = false;
        notifyListeners();

        // Immediately preload the next rewarded ad in the background
        preloadRewardedAd();

        if (userEarnedReward) {
          // Add 50 gold to the player and save immediately
          SaveManager.instance.addGold(50);
          SaveManager.instance.setLastAdWatchTime(DateTime.now().millisecondsSinceEpoch);
          AudioManager.instance.playSfx(GameSfx.powerupBuff);
          onSuccess(50);
        } else {
          onDismissedEarly();
        }
      },
      onAdFailedToShowFullScreenContent: (ad, AdError error) {
        debugPrint('Rewarded ad failed to show: $error');
        ad.dispose();
        _rewardedAd = null;
        _isShowing = false;
        notifyListeners();
        preloadRewardedAd();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Reklam gösterilemedi. Lütfen bağlantınızı kontrol edin.'),
            backgroundColor: Color(0xFFC62828),
            behavior: SnackBarBehavior.floating,
          ),
        );
      },
    );

    await currentAd.show(
      onUserEarnedReward: (AdWithoutView ad, RewardItem reward) {
        userEarnedReward = true;
      },
    );
  }
}
