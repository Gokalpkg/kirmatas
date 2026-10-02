import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'engine/asset_cache.dart';
import 'engine/audio_manager.dart';
import 'storage/save_manager.dart';
import 'ui/splash_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Set system UI to immersive sticky mode
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  // Initialize offline storage, audio and image assets
  await SaveManager.instance.init();
  await AudioManager.instance.init();
  await AssetCache.instance.init();

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
    final buried = state == AppLifecycleState.paused ||
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
        scaffoldBackgroundColor: const Color(0xFF07080C),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFFFFD54F),
          secondary: Color(0xFF00E5FF),
          surface: Color(0xFF101320),
        ),
        textTheme: GoogleFonts.rajdhaniTextTheme(ThemeData.dark().textTheme),
      ),
      home: const SplashScreen(),
    );
  }
}
