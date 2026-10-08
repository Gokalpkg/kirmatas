import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../storage/save_manager.dart';
import 'audio_manager.dart';

class AdManager extends ChangeNotifier {
  static final AdManager instance = AdManager._internal();
  AdManager._internal();

  // User's provided AdMob Rewarded Ad Unit ID
  static const String rewardedAdUnitId = 'ca-app-pub-9505724609102225/1791945382';
  
  // User's provided High-Yield (Yüksek Gelirli) AdMob Ad Unit ID for Fortune Wheel & Victory 3X
  static const String highYieldAdUnitId = 'ca-app-pub-9505724609102225/2723019148';

  // Standard Google AdMob test rewarded ad unit ID (used as reliable fallback in development/zero-inventory)
  static const String testRewardedAdUnitId = 'ca-app-pub-3940256099942544/5224354917';

  // 90 seconds (1.5 minutes) anti-spam cooldown between rewarded ad watches
  static const int cooldownSeconds = 90;

  // Balanced reward amount for standard rewarded ad watch (+100 gold)
  static const int goldRewardAmount = 100;

  RewardedAd? _rewardedAd;
  RewardedAd? _highYieldAd;
  bool _isLoading = false;
  bool _isLoadingHighYield = false;
  bool _isShowing = false;
  bool _initialized = false;

  bool get isLoading => _isLoading;
  bool get isLoadingHighYield => _isLoadingHighYield;
  bool get isShowing => _isShowing;
  bool get isAdReady => _rewardedAd != null;
  bool get isHighYieldAdReady => _highYieldAd != null;

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
    preloadHighYieldAd();
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

  /// Shows the high-yield rewarded ad to earn free gold reward.
  /// (Same high-yield ad unit as Fortune Wheel: 2723019148).
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

    final adToUse = _highYieldAd ?? _rewardedAd;
    if (adToUse == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Reklam yükleniyor, lütfen birkaç saniye sonra tekrar deneyin...'),
          backgroundColor: Color(0xFF1E2438),
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 2),
        ),
      );
      preloadHighYieldAd();
      preloadRewardedAd();
      return;
    }

    _isShowing = true;
    notifyListeners();

    bool userEarnedReward = false;
    final currentAd = adToUse;

    currentAd.fullScreenContentCallback = FullScreenContentCallback(
      onAdShowedFullScreenContent: (ad) {
        debugPrint('Free gift rewarded ad showed (High Yield)');
      },
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        if (currentAd == _highYieldAd) {
          _highYieldAd = null;
        } else {
          _rewardedAd = null;
        }
        _isShowing = false;
        notifyListeners();

        // Immediately preload next ads in the background
        preloadHighYieldAd();
        preloadRewardedAd();

        if (userEarnedReward) {
          SaveManager.instance.addGold(goldRewardAmount);
          SaveManager.instance.setLastAdWatchTime(DateTime.now().millisecondsSinceEpoch);
          SaveManager.instance.recordAdOrWinQuest();
          AudioManager.instance.playSfx(GameSfx.powerupBuff);
          onSuccess(goldRewardAmount);
        } else {
          onDismissedEarly();
        }
      },
      onAdFailedToShowFullScreenContent: (ad, AdError error) {
        debugPrint('Free gift ad failed to show: $error');
        ad.dispose();
        if (currentAd == _highYieldAd) {
          _highYieldAd = null;
        } else {
          _rewardedAd = null;
        }
        _isShowing = false;
        notifyListeners();
        preloadHighYieldAd();
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

  /// Shows the high-yield long rewarded ad to revive with 1 extra life.
  Future<void> watchAdForRevive(
    BuildContext context, {
    required VoidCallback onReviveSuccess,
    required VoidCallback onDismissedEarly,
  }) async {
    if (_isShowing) return;

    if (_highYieldAd == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Uzun ödüllü reklam yükleniyor, lütfen birkaç saniye sonra tekrar deneyin...'),
          backgroundColor: Color(0xFF1E2438),
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 2),
        ),
      );
      preloadHighYieldAd();
      return;
    }

    _isShowing = true;
    notifyListeners();

    bool userEarnedReward = false;
    final currentAd = _highYieldAd!;

    currentAd.fullScreenContentCallback = FullScreenContentCallback(
      onAdShowedFullScreenContent: (ad) {
        debugPrint('Revive rewarded ad showed (High-Yield Long Ad: $highYieldAdUnitId)');
      },
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _highYieldAd = null;
        _isShowing = false;
        notifyListeners();

        // Immediately preload next high-yield ad in the background
        preloadHighYieldAd();

        if (userEarnedReward) {
          onReviveSuccess();
        } else {
          onDismissedEarly();
        }
      },
      onAdFailedToShowFullScreenContent: (ad, AdError error) {
        debugPrint('Revive high-yield ad failed to show: $error');
        ad.dispose();
        _highYieldAd = null;
        _isShowing = false;
        notifyListeners();
        preloadHighYieldAd();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Reklam açılamadı. Lütfen internet bağlantınızı kontrol edin.'),
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

  /// Preloads the high-yield rewarded ad in the background.
  void preloadHighYieldAd() {
    if (_highYieldAd != null || _isLoadingHighYield) return;
    _isLoadingHighYield = true;
    notifyListeners();

    // First attempt to load with the user's high-yield Ad Unit ID.
    // If it fails (e.g. initial zero-fill period on newly created IDs), fallback to test ID.
    RewardedAd.load(
      adUnitId: highYieldAdUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _highYieldAd = ad;
          _isLoadingHighYield = false;
          notifyListeners();
        },
        onAdFailedToLoad: (LoadAdError error) {
          debugPrint('High-yield ad failed: $error. Falling back to test Ad Unit ID...');
          RewardedAd.load(
            adUnitId: testRewardedAdUnitId,
            request: const AdRequest(),
            rewardedAdLoadCallback: RewardedAdLoadCallback(
              onAdLoaded: (testAd) {
                _highYieldAd = testAd;
                _isLoadingHighYield = false;
                notifyListeners();
              },
              onAdFailedToLoad: (LoadAdError testError) {
                debugPrint('High-yield test fallback failed: $testError');
                _highYieldAd = null;
                _isLoadingHighYield = false;
                notifyListeners();
              },
            ),
          );
        },
      ),
    );
  }

  /// Shows the high-yield rewarded ad for Fortune Wheel spins or 3X Victory gold multipliers.
  Future<void> watchHighYieldAd(
    BuildContext context, {
    required VoidCallback onSuccess,
    required VoidCallback onDismissedEarly,
  }) async {
    if (_isShowing) return;

    if (_highYieldAd == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ödüllü reklam yükleniyor, lütfen birkaç saniye sonra tekrar deneyin...'),
          backgroundColor: Color(0xFF1E2438),
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 2),
        ),
      );
      preloadHighYieldAd();
      return;
    }

    _isShowing = true;
    notifyListeners();

    bool userEarnedReward = false;
    final currentAd = _highYieldAd!;

    currentAd.fullScreenContentCallback = FullScreenContentCallback(
      onAdShowedFullScreenContent: (ad) {
        debugPrint('High-yield rewarded ad showed');
      },
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _highYieldAd = null;
        _isShowing = false;
        notifyListeners();

        // Preload next high-yield ad in the background
        preloadHighYieldAd();

        if (userEarnedReward) {
          onSuccess();
        } else {
          onDismissedEarly();
        }
      },
      onAdFailedToShowFullScreenContent: (ad, AdError error) {
        debugPrint('High-yield rewarded ad failed to show: $error');
        ad.dispose();
        _highYieldAd = null;
        _isShowing = false;
        notifyListeners();
        preloadHighYieldAd();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Reklam açılamadı. Lütfen internet bağlantınızı kontrol edin.'),
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
