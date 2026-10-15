import 'dart:async';
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

  // Backward-compatibility aliases
  static const String tier1HighYieldAdUnitId = tier1RewardedAdUnitId;
  static const String tier2MediumYieldAdUnitId = tier2RewardedAdUnitId;
  static const String tier3StandardAdUnitId = tier3RewardedAdUnitId;
  static const String highYieldAdUnitId = tier1RewardedAdUnitId;
  static const String rewardedAdUnitId = tier3RewardedAdUnitId;

  // Google Test Interstitial Fallback (Kesin doluluk & güvenlik)
  static const String testInterstitialAdUnitId = 'ca-app-pub-3940256099942544/1033173712';

  // Standard Google AdMob test rewarded ad unit ID (used as reliable fallback in development/zero-inventory)
  static const String testRewardedAdUnitId = 'ca-app-pub-3940256099942544/5224354917';

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
    try {
      await MobileAds.instance.initialize();
    } catch (e) {
      debugPrint('MobileAds initialization error: $e');
    }
    preloadInterstitialAd();
    preloadHighYieldAd();
    preloadRewardedAd();
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
      adUnitId: tier3StandardAdUnitId,
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
            adUnitId: testRewardedAdUnitId,
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

  /// Shows ONLY a quick skippable ad (InterstitialAd) to earn free gold reward (+100 gold).
  /// Never falls back to 60s unskippable RewardedAd.
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

    if (_interstitialAd == null) {
      preloadInterstitialAd();
      preloadHighYieldAd();

      bool dialogOpen = true;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (dlgCtx) => PopScope(
          canPop: false,
          child: Dialog(
            backgroundColor: const Color(0xFF131726),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: const BorderSide(color: Color(0xFF4FC3F7), width: 1.5),
            ),
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 24, vertical: 22),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 26,
                    height: 26,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.8,
                      color: Color(0xFF4FC3F7),
                    ),
                  ),
                  SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      'Ödül Hazırlanıyor...',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ).then((_) => dialogOpen = false);

      final startTime = DateTime.now().millisecondsSinceEpoch;
      while (_interstitialAd == null && (DateTime.now().millisecondsSinceEpoch - startTime) < 5500) {
        await Future.delayed(const Duration(milliseconds: 150));
        if (!context.mounted) break;
      }

      if (dialogOpen && context.mounted) {
        Navigator.of(context, rootNavigator: true).pop();
      }

      if (_interstitialAd == null) {
        // Fallback: Check if Rewarded Ad is available
        if (_highYieldAd != null || _rewardedAd != null) {
          await watchAdForRevive(
            context,
            onReviveSuccess: () {
              SaveManager.instance.addGold(goldRewardAmount);
              SaveManager.instance.setLastAdWatchTime(DateTime.now().millisecondsSinceEpoch);
              SaveManager.instance.recordAdOrWinQuest();
              AudioManager.instance.playSfx(GameSfx.powerupBuff);
              onSuccess(goldRewardAmount);
            },
            onDismissedEarly: onDismissedEarly,
          );
          return;
        }

        // Guaranteed Grace Reward if ads fail to fill
        SaveManager.instance.addGold(goldRewardAmount);
        SaveManager.instance.setLastAdWatchTime(DateTime.now().millisecondsSinceEpoch);
        SaveManager.instance.recordAdOrWinQuest();
        AudioManager.instance.playSfx(GameSfx.powerupBuff);
        onSuccess(goldRewardAmount);
        return;
      }
    }

    _isShowing = true;
    notifyListeners();

    final ad = _interstitialAd!;
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdShowedFullScreenContent: (ad) {
        debugPrint('Skippable free gift ad showed');
      },
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _interstitialAd = null;
        _isShowing = false;
        notifyListeners();
        preloadInterstitialAd();

        SaveManager.instance.addGold(goldRewardAmount);
        SaveManager.instance.setLastAdWatchTime(DateTime.now().millisecondsSinceEpoch);
        _noteVoluntaryAd();
        SaveManager.instance.recordAdOrWinQuest();
        AudioManager.instance.playSfx(GameSfx.powerupBuff);
        onSuccess(goldRewardAmount);
      },
      onAdFailedToShowFullScreenContent: (ad, AdError error) {
        debugPrint('Skippable free gift ad failed to show: $error');
        ad.dispose();
        _interstitialAd = null;
        _isShowing = false;
        notifyListeners();
        preloadInterstitialAd();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Reklam gösterilemedi. Lütfen bağlantınızı kontrol edin.'),
            backgroundColor: Color(0xFFC62828),
            behavior: SnackBarBehavior.floating,
          ),
        );
      },
    );
    await ad.show();
  }

  /// Shows ONLY a quick skippable ad (InterstitialAd) for lighter voluntary rewards
  /// (Fortune Wheel, Daily Login 2X, Aquarium Fish Food) so the player can skip after 5-15s.
  /// Never falls back to 60s unskippable RewardedAd.
  Future<void> watchSkippableAd(
    BuildContext context, {
    required VoidCallback onSuccess,
    VoidCallback? onDismissedEarly,
  }) async {
    if (_isShowing) return;

    if (_interstitialAd == null) {
      // Reklam hafızada yoksa kullanıcıyı bekletip göndermek yerine,
      // 3.5 saniye hızlı yükleme diyaloğu açıp yüklenir yüklenmez anında ekrana veriyoruz!
      preloadInterstitialAd();

      bool dialogOpen = true;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (dlgCtx) => PopScope(
          canPop: false,
          child: Dialog(
            backgroundColor: const Color(0xFF131726),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: const BorderSide(color: Color(0xFF4FC3F7), width: 1.5),
            ),
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 24, vertical: 22),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 26,
                    height: 26,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.8,
                      color: Color(0xFF4FC3F7),
                    ),
                  ),
                  SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      'Reklam Hazırlanıyor...',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ).then((_) => dialogOpen = false);

      final startTime = DateTime.now().millisecondsSinceEpoch;
      while (_interstitialAd == null && (DateTime.now().millisecondsSinceEpoch - startTime) < 3500) {
        await Future.delayed(const Duration(milliseconds: 150));
        if (!context.mounted) break;
      }

      if (dialogOpen && context.mounted) {
        Navigator.of(context, rootNavigator: true).pop();
      }

      if (_interstitialAd == null) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Reklam yüklenemedi. Lütfen internet bağlantınızı kontrol edip tekrar deneyin.'),
              backgroundColor: Color(0xFF1E2438),
              behavior: SnackBarBehavior.floating,
              duration: Duration(seconds: 2),
            ),
          );
        }
        return;
      }
    }

    _isShowing = true;
    notifyListeners();

    final ad = _interstitialAd!;
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdShowedFullScreenContent: (ad) {
        debugPrint('AdManager: Skippable reward ad showed.');
      },
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _interstitialAd = null;
        _isShowing = false;
        notifyListeners();
        preloadInterstitialAd();

        SaveManager.instance.recordAdOrWinQuest();
        _noteVoluntaryAd();
        onSuccess();
      },
      onAdFailedToShowFullScreenContent: (ad, AdError error) {
        debugPrint('AdManager: Skippable reward ad failed to show: $error');
        ad.dispose();
        _interstitialAd = null;
        _isShowing = false;
        notifyListeners();
        preloadInterstitialAd();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Reklam açılamadı. Lütfen internet bağlantınızı kontrol edin.'),
            backgroundColor: Color(0xFFC62828),
            behavior: SnackBarBehavior.floating,
          ),
        );
      },
    );
    await ad.show();
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

      bool dialogOpen = true;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (dlgCtx) => PopScope(
          canPop: false,
          child: Dialog(
            backgroundColor: const Color(0xFF131726),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: const BorderSide(color: Color(0xFFFF5252), width: 1.5),
            ),
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 24, vertical: 22),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 26,
                    height: 26,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.8,
                      color: Color(0xFFFF5252),
                    ),
                  ),
                  SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      'Reklam Hazırlanıyor...',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ).then((_) => dialogOpen = false);

      final startTime = DateTime.now().millisecondsSinceEpoch;
      while ((_highYieldAd == null && _rewardedAd == null) &&
          (DateTime.now().millisecondsSinceEpoch - startTime) < 3500) {
        await Future.delayed(const Duration(milliseconds: 150));
        if (!context.mounted) break;
      }

      if (dialogOpen && context.mounted) {
        Navigator.of(context, rootNavigator: true).pop();
      }

      adToUse = _highYieldAd ?? _rewardedAd;
      if (adToUse == null) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Reklam yüklenemedi. Lütfen internet bağlantınızı kontrol edip tekrar deneyin.'),
              backgroundColor: Color(0xFF1E2438),
              behavior: SnackBarBehavior.floating,
              duration: Duration(seconds: 2),
            ),
          );
        }
        return;
      }
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
    debugPrint('AdManager: Attempting Rewarded Tier 1 (Ultra High: $tier1RewardedAdUnitId)...');
    RewardedAd.load(
      adUnitId: tier1RewardedAdUnitId,
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
    debugPrint('AdManager: Attempting Rewarded Tier 2 (Medium: $tier2RewardedAdUnitId)...');
    RewardedAd.load(
      adUnitId: tier2RewardedAdUnitId,
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
    debugPrint('AdManager: Attempting Rewarded Tier 3 (Standard: $tier3RewardedAdUnitId)...');
    RewardedAd.load(
      adUnitId: tier3RewardedAdUnitId,
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
      adUnitId: testRewardedAdUnitId,
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
    debugPrint('AdManager: Attempting Interstitial Tier 1 ($tier1InterstitialAdUnitId)...');
    InterstitialAd.load(
      adUnitId: tier1InterstitialAdUnitId,
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
    debugPrint('AdManager: Attempting Interstitial Tier 2 ($tier2InterstitialAdUnitId)...');
    InterstitialAd.load(
      adUnitId: tier2InterstitialAdUnitId,
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
    debugPrint('AdManager: Attempting Interstitial Tier 3 ($tier3InterstitialAdUnitId)...');
    InterstitialAd.load(
      adUnitId: tier3InterstitialAdUnitId,
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
      adUnitId: testInterstitialAdUnitId,
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
