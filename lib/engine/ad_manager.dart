import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../storage/save_manager.dart';
import 'audio_manager.dart';
import 'analytics_manager.dart';

class AdManager extends ChangeNotifier {
  static final AdManager instance = AdManager._internal();
  AdManager._internal();

  // REWARDED ADS WATERFALL (Canlanma, Çarkıfelek, 3X Zafer, Akvaryum Yem, Menü Altını)
  // Tier 1: Highest Yield / eCPM Floor Ad Unit ID (Odullu_Yuksek)
  static const String tier1RewardedAdUnitId = 'ca-app-pub-9694275729123906/6981270843';

  // Tier 2: Medium Yield / Balanced Floor Ad Unit ID (Odullu_Orta)
  static const String tier2RewardedAdUnitId = 'ca-app-pub-9694275729123906/8357756685';

  // Tier 3: Standard / Guaranteed Fill Ad Unit ID (Odullu_Standart - Tüm fiyatlar)
  static const String tier3RewardedAdUnitId = 'ca-app-pub-9694275729123906/8685059744';

  // INTERSTITIAL ADS WATERFALL (3-5 bölümde bir, bölüm geçişinde)
  // Tier 1: Yüksek Taban Geçiş Reklamı (Gecis_Yuksek)
  static const String tier1InterstitialAdUnitId = 'ca-app-pub-9694275729123906/5731593340';

  // Tier 2: Orta Taban Geçiş Reklamı (Gecis_Orta)
  static const String tier2InterstitialAdUnitId = 'ca-app-pub-9694275729123906/4368294806';

  // Tier 3: Düşük Taban / Standart Geçiş Reklamı (Gecis_Standart)
  static const String tier3InterstitialAdUnitId = 'ca-app-pub-9694275729123906/4863118828';

  // iOS REWARDED ADS WATERFALL (Can be customized via AdMob iOS console)
  static const String iosTier1RewardedAdUnitId = 'ca-app-pub-9694275729123906/6981270843';
  static const String iosTier2RewardedAdUnitId = 'ca-app-pub-9694275729123906/8357756685';
  static const String iosTier3RewardedAdUnitId = 'ca-app-pub-9694275729123906/8685059744';

  // iOS INTERSTITIAL ADS WATERFALL
  static const String iosTier1InterstitialAdUnitId = 'ca-app-pub-9694275729123906/5731593340';
  static const String iosTier2InterstitialAdUnitId = 'ca-app-pub-9694275729123906/4368294806';
  static const String iosTier3InterstitialAdUnitId = 'ca-app-pub-9694275729123906/4863118828';

  // Backward-compatibility aliases
  static const String tier1HighYieldAdUnitId = tier1RewardedAdUnitId;
  static const String tier2MediumYieldAdUnitId = tier2RewardedAdUnitId;
  static const String tier3StandardAdUnitId = tier3RewardedAdUnitId;
  static const String highYieldAdUnitId = tier1RewardedAdUnitId;
  static const String rewardedAdUnitId = tier3RewardedAdUnitId;

  // Google Test Interstitial Fallback (Kesin doluluk & güvenlik)
  static const String testInterstitialAdUnitId = 'ca-app-pub-3940256099942544/1033173712';
  static const String iosTestInterstitialAdUnitId = 'ca-app-pub-3940256099942544/4411468910';

  // Standard Google AdMob test rewarded ad unit ID (used as reliable fallback in development/zero-inventory)
  static const String testRewardedAdUnitId = 'ca-app-pub-3940256099942544/5224354917';
  static const String iosTestRewardedAdUnitId = 'ca-app-pub-3940256099942544/1712485313';

  // Platform-Aware Active Ad Unit Getters for Waterfall Cascade
  static String get activeRewardedTier1Id => (!kIsWeb && Platform.isIOS) ? iosTier1RewardedAdUnitId : tier1RewardedAdUnitId;
  static String get activeRewardedTier2Id => (!kIsWeb && Platform.isIOS) ? iosTier2RewardedAdUnitId : tier2RewardedAdUnitId;
  static String get activeRewardedTier3Id => (!kIsWeb && Platform.isIOS) ? iosTier3RewardedAdUnitId : tier3RewardedAdUnitId;
  static String get activeRewardedTestId => (!kIsWeb && Platform.isIOS) ? iosTestRewardedAdUnitId : testRewardedAdUnitId;

  static String get activeInterstitialTier1Id => (!kIsWeb && Platform.isIOS) ? iosTier1InterstitialAdUnitId : tier1InterstitialAdUnitId;
  static String get activeInterstitialTier2Id => (!kIsWeb && Platform.isIOS) ? iosTier2InterstitialAdUnitId : tier2InterstitialAdUnitId;
  static String get activeInterstitialTier3Id => (!kIsWeb && Platform.isIOS) ? iosTier3InterstitialAdUnitId : tier3InterstitialAdUnitId;
  static String get activeInterstitialTestId => (!kIsWeb && Platform.isIOS) ? iosTestInterstitialAdUnitId : testInterstitialAdUnitId;

  // 90 seconds (1.5 minutes) anti-spam cooldown between rewarded ad watches
  static const int cooldownSeconds = 90;

  // Balanced reward amount for standard rewarded ad watch (+100 gold)
  static const int goldRewardAmount = 100;

  RewardedAd? _rewardedAd;
  RewardedAd? _highYieldAd;
  InterstitialAd? _interstitialAd;

  bool _isLoading = false;
  bool _isLoadingHighYield = false;
  bool _isLoadingInterstitial = false;
  bool _isShowing = false;
  bool _initialized = false;

  // Cleared boards since the last interstitial. Next ad after 3, 4, or 5.
  int _levelsSinceAd = 0;
  int _levelsUntilAd = 3 + (DateTime.now().microsecond % 3);
  int _clearsSinceVoluntaryAd = 99;
  int _quietClearsAfterAd = 0;

  bool get isLoading => _isLoading;
  bool get isLoadingHighYield => _isLoadingHighYield;
  bool get isLoadingInterstitial => _isLoadingInterstitial;
  bool get isShowing => _isShowing;
  bool get isAdReady => _rewardedAd != null;
  bool get isHighYieldAdReady => _highYieldAd != null;
  bool get isInterstitialReady => _interstitialAd != null;

  int get remainingCooldownSeconds {
    final lastTime = SaveManager.instance.lastAdWatchTime;
    if (lastTime == 0) return 0;
    final elapsedSec = (DateTime.now().millisecondsSinceEpoch - lastTime) ~/ 1000;
    final remaining = cooldownSeconds - elapsedSec;
    return remaining > 0 ? remaining : 0;
  }

  bool get canWatchAd => remainingCooldownSeconds == 0 && !_isLoadingInterstitial && !_isShowing;

  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    // Unit test bypass: Avoid calling native plugins during tests
    if (!kIsWeb && Platform.environment.containsKey('FLUTTER_TEST')) {
      return;
    }

    // Legal / GDPR / UMP Consent flow for EEA/UK & Apple ATT compliance
    if (!kIsWeb && (Platform.isIOS || Platform.isAndroid)) {
      final consentCompleter = Completer<void>();
      try {
        final params = ConsentRequestParameters();
        ConsentInformation.instance.requestConsentInfoUpdate(
          params,
          () async {
            ConsentForm.loadAndShowConsentFormIfRequired((formError) async {
              if (formError != null) {
                debugPrint('AdManager UMP ConsentForm warning: ${formError.errorCode} - ${formError.message}');
              }
              await _postConsentInit();
              if (!consentCompleter.isCompleted) consentCompleter.complete();
            });
          },
          (FormError error) async {
            debugPrint('AdManager UMP ConsentInfo warning: ${error.errorCode} - ${error.message}');
            await _postConsentInit();
            if (!consentCompleter.isCompleted) consentCompleter.complete();
          },
        );

        // Safeguard timeout (5s) so consent resolution does not block app indefinitely on spotty networks
        await consentCompleter.future.timeout(
          const Duration(seconds: 5),
          onTimeout: () async {
            debugPrint('AdManager UMP Consent timeout, proceeding with post-consent init');
            await _postConsentInit();
          },
        );
        return;
      } catch (e) {
        debugPrint('AdManager Consent initialization error: $e');
      }
    }

    await _postConsentInit();
  }

  Future<void> _postConsentInit() async {
    try {
      if (!kIsWeb && (Platform.isIOS || Platform.isAndroid)) {
        final canRequest = await ConsentInformation.instance.canRequestAds();
        if (!canRequest) {
          debugPrint('AdManager: Ads cannot be requested yet per user consent status.');
          return;
        }
      }
      await MobileAds.instance.initialize();
    } catch (e) {
      debugPrint('MobileAds initialization error: $e');
    }
    preloadInterstitialAd();
    preloadHighYieldAd();
    preloadRewardedAd();
  }

  /// Displays the UMP Privacy Options / Cookie Settings form if available (EU / AdMob requirement)
  Future<void> showPrivacyOptionsForm(BuildContext context) async {
    try {
      ConsentForm.showPrivacyOptionsForm((formError) {
        if (formError != null) {
          debugPrint('Error showing privacy options form: ${formError.message}');
        }
      });
    } catch (e) {
      debugPrint('AdManager showPrivacyOptionsForm error: $e');
    }
  }

  void _setupPaidEventListener(dynamic ad, String format) {
    try {
      ad.onPaidEvent = (dynamic loadedAd, double valueMicros, PrecisionType precision, String currencyCode) {
        final revenue = valueMicros / 1000000.0;
        AnalyticsManager.instance.logAdImpressionRevenue(
          value: revenue,
          currency: currencyCode,
          adUnitId: (loadedAd.adUnitId as String?) ?? '',
          adFormat: format,
        );
      };
    } catch (e) {
      debugPrint('AdManager onPaidEvent setup error: $e');
    }
  }

  /// Preloads a standard rewarded ad (Tier 3 with test fallback).
  void preloadRewardedAd() {
    if (_rewardedAd != null || _isLoading) return;
    _isLoading = true;
    notifyListeners();

    RewardedAd.load(
      adUnitId: activeRewardedTier3Id,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _setupPaidEventListener(ad, 'rewarded');
          _rewardedAd = ad;
          _isLoading = false;
          notifyListeners();
        },
        onAdFailedToLoad: (LoadAdError error) {
          debugPrint('Tier 3 standard ad failed: $error');
          if (kReleaseMode) {
            _rewardedAd = null;
            _isLoading = false;
            notifyListeners();
            return;
          }
          debugPrint('Falling back to test Ad Unit ID...');
          RewardedAd.load(
            adUnitId: activeRewardedTestId,
            request: const AdRequest(),
            rewardedAdLoadCallback: RewardedAdLoadCallback(
              onAdLoaded: (testAd) {
                _setupPaidEventListener(testAd, 'rewarded');
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

  /// Whether test environments can simulate instant ad completion.
  /// Strictly FALSE in real app execution to close the airplane mode exploit.
  static bool enableTestBypass = !kIsWeb && Platform.environment.containsKey('FLUTTER_TEST');

  /// Displays a RewardedAd (+100 gold) for the main menu gold gift.
  /// Strictly uses RewardedAd to comply with AdMob policy.
  Future<void> watchAdForGold(
    BuildContext context, {
    required void Function(int goldReward) onSuccess,
    required void Function() onDismissedEarly,
  }) async {
    if (_isShowing) return;

    // 1. VIP No-Ads Pass: Claim reward instantly without ad
    if (SaveManager.instance.adsRemoved) {
      SaveManager.instance.addGold(goldRewardAmount);
      SaveManager.instance.setLastAdWatchTime(DateTime.now().millisecondsSinceEpoch);
      SaveManager.instance.recordAdOrWinQuest();
      AudioManager.instance.playSfx(GameSfx.powerupBuff);
      onSuccess(goldRewardAmount);
      return;
    }

    if (remainingCooldownSeconds > 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Lütfen bekleyin: $remainingCooldownSeconds saniye sonra tekrar ödül alabilirsiniz.'),
          backgroundColor: const Color(0xFF1E2438),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
      return;
    }

    final adToUse = _highYieldAd ?? _rewardedAd;
    if (adToUse == null) {
      preloadHighYieldAd();
      preloadRewardedAd();

      if (!kIsWeb && Platform.environment.containsKey('FLUTTER_TEST') && enableTestBypass) {
        SaveManager.instance.addGold(goldRewardAmount);
        SaveManager.instance.setLastAdWatchTime(DateTime.now().millisecondsSinceEpoch);
        SaveManager.instance.recordAdOrWinQuest();
        AudioManager.instance.playSfx(GameSfx.powerupBuff);
        onSuccess(goldRewardAmount);
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ödüllü reklam yükleniyor veya internet bağlantısı yok. Lütfen birazdan tekrar deneyin.'),
          backgroundColor: Color(0xFF1E2438),
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 2),
        ),
      );
      onDismissedEarly();
      return;
    }

    _isShowing = true;
    notifyListeners();

    bool userEarnedReward = false;
    final currentAd = adToUse;

    currentAd.fullScreenContentCallback = FullScreenContentCallback(
      onAdShowedFullScreenContent: (ad) {
        debugPrint('Rewarded gold ad showed ($tier1RewardedAdUnitId)');
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

        preloadHighYieldAd();
        preloadRewardedAd();

        if (userEarnedReward) {
          SaveManager.instance.addGold(goldRewardAmount);
          SaveManager.instance.setLastAdWatchTime(DateTime.now().millisecondsSinceEpoch);
          _noteVoluntaryAd();
          SaveManager.instance.recordAdOrWinQuest();
          AudioManager.instance.playSfx(GameSfx.powerupBuff);
          onSuccess(goldRewardAmount);
        } else {
          onDismissedEarly();
        }
      },
      onAdFailedToShowFullScreenContent: (ad, AdError error) {
        debugPrint('Rewarded gold ad failed to show: $error');
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
            content: Text('Reklam açılamadı. Lütfen internet bağlantınızı kontrol edin.'),
            backgroundColor: Color(0xFFC62828),
            behavior: SnackBarBehavior.floating,
          ),
        );
        onDismissedEarly();
      },
    );

    await currentAd.show(
      onUserEarnedReward: (AdWithoutView ad, RewardItem reward) {
        userEarnedReward = true;
      },
    );
  }

  /// Compliant RewardedAd viewer for all voluntary in-game incentives
  /// (Fish food, Fortune wheel extra spin, Daily login 2X, Offline 2X, etc.).
  /// Strictly uses RewardedAd. Never binds incentives to InterstitialAd.
  Future<void> watchRewardedAd(
    BuildContext context, {
    required VoidCallback onSuccess,
    VoidCallback? onDismissedEarly,
  }) async {
    if (_isShowing) return;

    // 1. VIP No-Ads Pass: Claim reward instantly without ad
    if (SaveManager.instance.adsRemoved) {
      SaveManager.instance.recordAdOrWinQuest();
      _noteVoluntaryAd();
      AudioManager.instance.playSfx(GameSfx.powerupBuff);
      onSuccess();
      return;
    }

    final adToUse = _highYieldAd ?? _rewardedAd;
    if (adToUse == null) {
      preloadHighYieldAd();
      preloadRewardedAd();

      if (!kIsWeb && Platform.environment.containsKey('FLUTTER_TEST') && enableTestBypass) {
        SaveManager.instance.recordAdOrWinQuest();
        _noteVoluntaryAd();
        AudioManager.instance.playSfx(GameSfx.powerupBuff);
        onSuccess();
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ödüllü reklam henüz hazır değil veya internet bağlantısı yok. Lütfen birazdan tekrar deneyin.'),
          backgroundColor: Color(0xFFC62828),
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 2),
        ),
      );
      onDismissedEarly?.call();
      return;
    }

    _isShowing = true;
    notifyListeners();

    bool userEarnedReward = false;
    final currentAd = adToUse;

    currentAd.fullScreenContentCallback = FullScreenContentCallback(
      onAdShowedFullScreenContent: (ad) {
        debugPrint('AdManager: Rewarded ad showed for reward.');
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

        preloadHighYieldAd();
        preloadRewardedAd();

        if (userEarnedReward) {
          SaveManager.instance.recordAdOrWinQuest();
          _noteVoluntaryAd();
          AudioManager.instance.playSfx(GameSfx.powerupBuff);
          onSuccess();
        } else {
          onDismissedEarly?.call();
        }
      },
      onAdFailedToShowFullScreenContent: (ad, AdError error) {
        debugPrint('AdManager: Rewarded ad failed to show: $error');
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
            content: Text('Reklam açılamadı. Lütfen internet bağlantınızı kontrol edin.'),
            backgroundColor: Color(0xFFC62828),
            behavior: SnackBarBehavior.floating,
          ),
        );
        onDismissedEarly?.call();
      },
    );

    await currentAd.show(
      onUserEarnedReward: (AdWithoutView ad, RewardItem reward) {
        userEarnedReward = true;
      },
    );
  }

  /// Rewarded ad handler for voluntary rewards (formerly skippable interstitial).
  /// Strictly delegates to watchRewardedAd for 100% AdMob policy compliance.
  Future<void> watchSkippableAd(
    BuildContext context, {
    required VoidCallback onSuccess,
    VoidCallback? onDismissedEarly,
  }) async {
    await watchRewardedAd(
      context,
      onSuccess: onSuccess,
      onDismissedEarly: onDismissedEarly,
    );
  }

  /// Shows the high-yield long rewarded ad to revive with 1 extra life.
  Future<void> watchAdForRevive(
    BuildContext context, {
    required VoidCallback onReviveSuccess,
    required VoidCallback onDismissedEarly,
  }) async {
    if (_isShowing) return;

    // VIP No-Ads Pass: Instant revive without ad
    if (SaveManager.instance.adsRemoved) {
      SaveManager.instance.recordAdOrWinQuest();
      _noteVoluntaryAd();
      onReviveSuccess();
      return;
    }

    var adToUse = _highYieldAd ?? _rewardedAd;
    if (adToUse == null) {
      preloadHighYieldAd();
      preloadRewardedAd();

      if (!kIsWeb && Platform.environment.containsKey('FLUTTER_TEST') && enableTestBypass) {
        SaveManager.instance.recordAdOrWinQuest();
        _noteVoluntaryAd();
        onReviveSuccess();
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Yeniden canlanma reklamı henüz hazır değil. Lütfen bağlantınızı kontrol edin.'),
          backgroundColor: Color(0xFFC62828),
          behavior: SnackBarBehavior.floating,
        ),
      );
      onDismissedEarly();
      return;
    }

    _isShowing = true;
    notifyListeners();

    bool userEarnedReward = false;
    final currentAd = adToUse;

    currentAd.fullScreenContentCallback = FullScreenContentCallback(
      onAdShowedFullScreenContent: (ad) {
        debugPrint('Revive rewarded ad showed (High-Yield Long Ad: $highYieldAdUnitId)');
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

        // Immediately preload next high-yield ad in the background
        preloadHighYieldAd();
        preloadRewardedAd();

        if (userEarnedReward) {
          SaveManager.instance.recordAdOrWinQuest();
          _noteVoluntaryAd();
          onReviveSuccess();
        } else {
          onDismissedEarly();
        }
      },
      onAdFailedToShowFullScreenContent: (ad, AdError error) {
        debugPrint('Revive high-yield ad failed to show: $error');
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
            content: Text('Reklam açılamadı. Lütfen internet bağlantınızı kontrol edin.'),
            backgroundColor: Color(0xFFC62828),
            behavior: SnackBarBehavior.floating,
          ),
        );
        onDismissedEarly();
      },
    );

    await currentAd.show(
      onUserEarnedReward: (AdWithoutView ad, RewardItem reward) {
        userEarnedReward = true;
      },
    );
  }

  Future<void> watchAdForStreakProtection(
    BuildContext context, {
    required VoidCallback onSuccess,
    required VoidCallback onDismissedEarly,
  }) async {
    if (_isShowing) return;

    var adToUse = _highYieldAd ?? _rewardedAd;
    if (adToUse == null) {
      preloadHighYieldAd();
      preloadRewardedAd();

      if (!kIsWeb && Platform.environment.containsKey('FLUTTER_TEST') && enableTestBypass) {
        SaveManager.instance.recordAdOrWinQuest();
        _noteVoluntaryAd();
        onSuccess();
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Reklam açılamadı. Lütfen internet bağlantınızı kontrol edin.'),
          backgroundColor: Color(0xFFC62828),
          behavior: SnackBarBehavior.floating,
        ),
      );
      onDismissedEarly();
      return;
    }

    _isShowing = true;
    notifyListeners();

    bool userEarnedReward = false;
    final currentAd = adToUse;

    currentAd.fullScreenContentCallback = FullScreenContentCallback(
      onAdShowedFullScreenContent: (ad) {
        debugPrint('Streak protection rewarded ad showed');
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

        preloadHighYieldAd();
        preloadRewardedAd();

        if (userEarnedReward) {
          SaveManager.instance.recordAdOrWinQuest();
          _noteVoluntaryAd();
          onSuccess();
        } else {
          onDismissedEarly();
        }
      },
      onAdFailedToShowFullScreenContent: (ad, AdError error) {
        debugPrint('Streak protection ad failed to show: $error');
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
            content: Text('Reklam açılamadı. Lütfen internet bağlantınızı kontrol edin.'),
            backgroundColor: Color(0xFFC62828),
            behavior: SnackBarBehavior.floating,
          ),
        );
        onDismissedEarly();
      },
    );

    await currentAd.show(
      onUserEarnedReward: (AdWithoutView ad, RewardItem reward) {
        userEarnedReward = true;
      },
    );
  }

  /// Preloads the high-yield rewarded ad using a 3-tier waterfall cascade:
  /// Tier 1 (Ultra High Yield - 7282413936)
  ///   -> Tier 2 (Medium Yield - 7585576971)
  ///     -> Tier 3 (Standard Yield - 2723019148)
  ///       -> Test Ad (Development & zero-inventory guarantee)
  void preloadHighYieldAd() {
    if (_highYieldAd != null || _isLoadingHighYield) return;
    _isLoadingHighYield = true;
    notifyListeners();

    _loadRewardedTier1();
  }

  void _loadRewardedTier1() {
    debugPrint('AdManager: Attempting Rewarded Tier 1 (Ultra High: $activeRewardedTier1Id)...');
    RewardedAd.load(
      adUnitId: activeRewardedTier1Id,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          debugPrint('AdManager: Rewarded Tier 1 loaded successfully! ');
          _setupPaidEventListener(ad, 'rewarded');
          _highYieldAd = ad;
          _isLoadingHighYield = false;
          notifyListeners();
        },
        onAdFailedToLoad: (LoadAdError error) {
          debugPrint('AdManager: Rewarded Tier 1 failed ($error). Cascading down to Tier 2...');
          _loadRewardedTier2();
        },
      ),
    );
  }

  void _loadRewardedTier2() {
    debugPrint('AdManager: Attempting Rewarded Tier 2 (Medium: $activeRewardedTier2Id)...');
    RewardedAd.load(
      adUnitId: activeRewardedTier2Id,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          debugPrint('AdManager: Rewarded Tier 2 loaded successfully! ');
          _setupPaidEventListener(ad, 'rewarded');
          _highYieldAd = ad;
          _isLoadingHighYield = false;
          notifyListeners();
        },
        onAdFailedToLoad: (LoadAdError error) {
          debugPrint('AdManager: Rewarded Tier 2 failed ($error). Cascading down to Tier 3...');
          _loadRewardedTier3();
        },
      ),
    );
  }

  void _loadRewardedTier3() {
    debugPrint('AdManager: Attempting Rewarded Tier 3 (Standard: $activeRewardedTier3Id)...');
    RewardedAd.load(
      adUnitId: activeRewardedTier3Id,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          debugPrint('AdManager: Rewarded Tier 3 loaded successfully! ');
          _setupPaidEventListener(ad, 'rewarded');
          _highYieldAd = ad;
          _isLoadingHighYield = false;
          notifyListeners();
        },
        onAdFailedToLoad: (LoadAdError error) {
          debugPrint('AdManager: Rewarded Tier 3 failed ($error)');
          if (kReleaseMode) {
            _highYieldAd = null;
            _isLoadingHighYield = false;
            notifyListeners();
            return;
          }
          _loadRewardedTestFallback();
        },
      ),
    );
  }

  void _loadRewardedTestFallback() {
    RewardedAd.load(
      adUnitId: activeRewardedTestId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (testAd) {
          debugPrint('AdManager: Rewarded Test fallback ad loaded.');
          _setupPaidEventListener(testAd, 'rewarded');
          _highYieldAd = testAd;
          _isLoadingHighYield = false;
          notifyListeners();
        },
        onAdFailedToLoad: (LoadAdError testError) {
          debugPrint('AdManager: Rewarded Test fallback ad also failed: $testError');
          _highYieldAd = null;
          _isLoadingHighYield = false;
          notifyListeners();
        },
      ),
    );
  }

  // =========================================================================
  // INTERSTITIAL ADS WATERFALL (GEÇİLEBİLİR GEÇİŞ & KISA ÖDÜL REKLAMLARI)
  // =========================================================================

  /// Preloads an interstitial ad using a 3-tier cascade:
  /// Tier 1 (2542891443) -> Tier 2 (5776304305) -> Tier 3 (4463222631) -> Test Fallback
  void preloadInterstitialAd() {
    if (_interstitialAd != null || _isLoadingInterstitial) return;
    _isLoadingInterstitial = true;
    notifyListeners();

    _loadInterstitialTier1();
  }

  void _loadInterstitialTier1() {
    debugPrint('AdManager: Attempting Interstitial Tier 1 ($activeInterstitialTier1Id)...');
    InterstitialAd.load(
      adUnitId: activeInterstitialTier1Id,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          debugPrint('AdManager: Interstitial Tier 1 loaded successfully! ');
          _setupPaidEventListener(ad, 'interstitial');
          _interstitialAd = ad;
          _isLoadingInterstitial = false;
          notifyListeners();
        },
        onAdFailedToLoad: (LoadAdError error) {
          debugPrint('AdManager: Interstitial Tier 1 failed ($error). Cascading to Tier 2...');
          _loadInterstitialTier2();
        },
      ),
    );
  }

  void _loadInterstitialTier2() {
    debugPrint('AdManager: Attempting Interstitial Tier 2 ($activeInterstitialTier2Id)...');
    InterstitialAd.load(
      adUnitId: activeInterstitialTier2Id,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          debugPrint('AdManager: Interstitial Tier 2 loaded successfully! ');
          _setupPaidEventListener(ad, 'interstitial');
          _interstitialAd = ad;
          _isLoadingInterstitial = false;
          notifyListeners();
        },
        onAdFailedToLoad: (LoadAdError error) {
          debugPrint('AdManager: Interstitial Tier 2 failed ($error). Cascading to Tier 3...');
          _loadInterstitialTier3();
        },
      ),
    );
  }

  void _loadInterstitialTier3() {
    debugPrint('AdManager: Attempting Interstitial Tier 3 ($activeInterstitialTier3Id)...');
    InterstitialAd.load(
      adUnitId: activeInterstitialTier3Id,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          debugPrint('AdManager: Interstitial Tier 3 loaded successfully! ');
          _setupPaidEventListener(ad, 'interstitial');
          _interstitialAd = ad;
          _isLoadingInterstitial = false;
          notifyListeners();
        },
        onAdFailedToLoad: (LoadAdError error) {
          debugPrint('AdManager: Interstitial Tier 3 failed ($error)');
          if (kReleaseMode) {
            _interstitialAd = null;
            _isLoadingInterstitial = false;
            notifyListeners();
            return;
          }
          _loadInterstitialTestFallback();
        },
      ),
    );
  }

  void _loadInterstitialTestFallback() {
    InterstitialAd.load(
      adUnitId: activeInterstitialTestId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          debugPrint('AdManager: Interstitial Test Fallback loaded.');
          _setupPaidEventListener(ad, 'interstitial');
          _interstitialAd = ad;
          _isLoadingInterstitial = false;
          notifyListeners();
        },
        onAdFailedToLoad: (LoadAdError error) {
          debugPrint('AdManager: Interstitial Test Fallback also failed: $error');
          _interstitialAd = null;
          _isLoadingInterstitial = false;
          notifyListeners();
        },
      ),
    );
  }

  void _noteVoluntaryAd() {
    _clearsSinceVoluntaryAd = 0;
    _quietClearsAfterAd = 2 + (DateTime.now().microsecond % 3);
  }

  /// One cleared board counts toward the next interstitial.
  /// A completed voluntary ad quiets the next 2, 3, or 4 clears.
  /// Otherwise the interstitial still opens every 3, 4, or 5 boards.
  bool registerLevelClear() {
    if (SaveManager.instance.adsRemoved) return false;
    if (SaveManager.instance.metricHighestClassicLevel < 5) return false;
    final watchedRecently = _clearsSinceVoluntaryAd < _quietClearsAfterAd;
    if (_clearsSinceVoluntaryAd < 99) _clearsSinceVoluntaryAd++;
    if (watchedRecently) return false;
    if (_levelsSinceAd < _levelsUntilAd) _levelsSinceAd++;
    if (_levelsSinceAd < _levelsUntilAd) return false;
    if (_interstitialAd == null || _isShowing) return false;
    _levelsSinceAd = 0;
    _levelsUntilAd = 3 + (DateTime.now().microsecond % 3);
    return true;
  }

  /// Level-transition interstitial. Menu and restart no longer force one.
  void checkAndShowInterstitial(BuildContext context, {VoidCallback? onComplete}) {
    if (!context.mounted) return;
    onComplete?.call();
  }

  void showLevelInterstitial(BuildContext context, {VoidCallback? onComplete}) {
    if (SaveManager.instance.adsRemoved) {
      onComplete?.call();
      return;
    }
    if (!context.mounted || _interstitialAd == null || _isShowing) {
      preloadInterstitialAd();
      onComplete?.call();
      return;
    }
    _isShowing = true;
    final ad = _interstitialAd!;
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdShowedFullScreenContent: (ad) {
        debugPrint('AdManager: Level interstitial showed.');
      },
      onAdDismissedFullScreenContent: (ad) {
        SaveManager.instance.noteAdClosed();
        ad.dispose();
        _interstitialAd = null;
        _isShowing = false;
        preloadInterstitialAd();
        onComplete?.call();
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        debugPrint('AdManager: Level interstitial failed: $error');
        ad.dispose();
        _interstitialAd = null;
        _isShowing = false;
        preloadInterstitialAd();
        onComplete?.call();
      },
    );
    ad.show();
  }

  /// Shows the high-yield long rewarded ad for End-of-Game 2X-3X Dice Gold Multiplier.
  Future<void> watchHighYieldAd(
    BuildContext context, {
    required VoidCallback onSuccess,
    required VoidCallback onDismissedEarly,
  }) async {
    if (_isShowing) return;

    final adToUse = _highYieldAd ?? _rewardedAd;
    if (adToUse == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ödüllü reklam yükleniyor, lütfen birkaç saniye sonra tekrar deneyin...'),
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
        debugPrint('High-yield rewarded ad showed');
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

        // Preload next high-yield ad in the background
        preloadHighYieldAd();
        preloadRewardedAd();

        if (userEarnedReward) {
          SaveManager.instance.recordAdOrWinQuest();
          _noteVoluntaryAd();
          onSuccess();
        } else {
          onDismissedEarly();
        }
      },
      onAdFailedToShowFullScreenContent: (ad, AdError error) {
        debugPrint('High-yield rewarded ad failed to show: $error');
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
