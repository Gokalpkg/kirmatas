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
import 'ui/splash_screen.dart';
import 'ui/main_menu.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase & Crashlytics crash handlers
  try {
    await Firebase.initializeApp();
    FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;
    PlatformDispatcher.instance.onError = (error, stack) {
      FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
      return true;
    };
    await AnalyticsManager.instance.init();
  } catch (_) {}

  // Set system UI to immersive sticky mode
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  // Initialize offline storage, audio, ads and image assets
  await SaveManager.instance.init();
  SaveManager.instance.noteAppOpen();
  await AudioManager.instance.init();
  await AssetCache.instance.init();
  await AdManager.instance.init();
  unawaited(RemoveAdsBilling.instance.init());
  unawaited(PlayGamesManager.instance.init());
  unawaited(CloudSocialManager.instance.syncProfileToCloud());
  unawaited(CloudSocialManager.instance.refreshFriendsFromCloud());

  MainMenuScreen.suppressBootPopups = false;

  runApp(const KirmatasApp());
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
    } else if (state == AppLifecycleState.resumed) {
      AudioManager.instance.resumeBgm();
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
      home: const SplashScreen(),
    );
  }
}
