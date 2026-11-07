import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'engine/ad_manager.dart';
import 'engine/remove_ads_billing.dart';
import 'engine/asset_cache.dart';
import 'engine/audio_manager.dart';
import 'storage/save_manager.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'engine/analytics_manager.dart';
import 'engine/play_games_manager.dart';
import 'engine/cloud_social_manager.dart';
import 'engine/notification_service.dart';
import 'ui/splash_screen.dart';
import 'ui/main_menu.dart';
import 'ui/achievement_toast_overlay.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Set system UI to immersive sticky mode immediately
  unawaited(SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky));
  unawaited(SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]));

  // Only await local fast preferences before rendering first frame
  await SaveManager.instance.init();
  SaveManager.instance.noteAppOpen();

  MainMenuScreen.suppressBootPopups = false;

  // Render app immediately so cold-boot never freezes on OS launch screen
  runApp(const KirmatasApp());

  // Initialize heavy subsystems asynchronously in background during Splash
  unawaited(_initBackgroundServices());
}

Future<void> _initBackgroundServices() async {
  try {
    await Firebase.initializeApp().timeout(const Duration(milliseconds: 2500));
    FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;
    PlatformDispatcher.instance.onError = (error, stack) {
      FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
      return true;
    };
    unawaited(AnalyticsManager.instance.init());
  } catch (_) {}

  unawaited(AssetCache.instance.init());
  unawaited(AudioManager.instance.init());
  unawaited(AdManager.instance.init());
  unawaited(RemoveAdsBilling.instance.init());
  unawaited(CloudSocialManager.instance.syncProfileToCloud());
  unawaited(CloudSocialManager.instance.refreshFriendsFromCloud());
  unawaited(CloudSocialManager.instance.fetchWeeklyLeagueRivals());

  // Defer intrusive system permission & sign-in prompts on first-ever launch
  // until the player has completed at least 1 game.
  if (SaveManager.instance.highestLevel > 1 || SaveManager.instance.totalGold > 300) {
    unawaited(PlayGamesManager.instance.init());
    unawaited(NotificationService.instance.initialize());
  }
}

class KirmatasApp extends StatefulWidget {
  const KirmatasApp({super.key});

  @override
  State<KirmatasApp> createState() => _KirmatasAppState();
}

class _KirmatasAppState extends State<KirmatasApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final buried = state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.detached;
    AudioManager.instance.appInForeground = !buried;
    if (buried) {
      AudioManager.instance.stopAll();
      unawaited(PlayGamesManager.instance.autoSaveToCloud());
      unawaited(NotificationService.instance.scheduleSmartRetentionLoops());
    } else if (state == AppLifecycleState.resumed) {
      if (AudioManager.instance.isBgmAllowed && SaveManager.instance.bgmVolume > 0) {
        AudioManager.instance.resumeBgm();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Kirmatas',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        fontFamily: 'Rajdhani',
        scaffoldBackgroundColor: const Color(0xFF07080C),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFFFFD54F),
          secondary: Color(0xFF00E5FF),
          surface: Color(0xFF101320),
        ),
        textTheme: ThemeData.dark().textTheme.apply(fontFamily: 'Rajdhani'),
      ),
      builder: (context, child) => AchievementToastOverlay(
        child: child ?? const SizedBox.shrink(),
      ),
      home: const SplashScreen(),
    );
  }
}
