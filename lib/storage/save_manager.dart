import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/game_state.dart';

class SaveManager extends ChangeNotifier {
  static final SaveManager instance = SaveManager._internal();
  SaveManager._internal();

  late SharedPreferences _prefs;
  bool _initialized = false;

  int gold = 300;
  Map<String, int> highScores = {
    'classic': 0,
    'zen': 0,
    'descend': 0,
    'daily': 0,
    'tuft': 0,
  };

  Set<String> unlockedBalls = {'classic'};
  Set<String> unlockedPaddles = {'pclassic'};
  Set<String> unlockedTrails = {'t1'};

  String activeBall = 'classic';
  String activePaddle = 'pclassic';
  String activeTrail = 't1';

  Map<String, int> upgrades = {'battery': 0, 'magnet': 0, 'luck': 0};
  Map<String, int> boostStocks = {'life': 0, 'wide': 0, 'multi': 0};

  List<String> unlockedFish = ['guppy', 'tetra'];
  int aquariumSand = 1;
  int aquariumMoss = 2;
  int aquariumKelp = 1;
  int aquariumAnubias = 1;

  String? lastDailyClaimDate;
  int dailyStreak = 1;

  SpeedSetting speed = SpeedSetting.medium;
  bool sfxEnabled = true;
  bool hapticsEnabled = true;

  String language = 'en';
  Set<String> unlockedBackgrounds = {'bg_default'};
  String activeBackground = 'bg_default';

  Future<void> init() async {
    if (_initialized) return;
    _prefs = await SharedPreferences.getInstance();

    gold = _prefs.getInt('gold') ?? 300;

    final hsStr = _prefs.getString('highScores');
    if (hsStr != null) {
      try {
        final Map<String, dynamic> decoded = jsonDecode(hsStr);
        highScores = decoded.map((k, v) => MapEntry(k, v as int));
      } catch (_) {}
    }

    unlockedBalls = (_prefs.getStringList('unlockedBalls') ?? ['classic']).toSet();
    unlockedPaddles = (_prefs.getStringList('unlockedPaddles') ?? ['pclassic']).toSet();
    unlockedTrails = (_prefs.getStringList('unlockedTrails') ?? ['t1']).toSet();

    activeBall = _prefs.getString('activeBall') ?? 'classic';
    activePaddle = _prefs.getString('activePaddle') ?? 'pclassic';
    activeTrail = _prefs.getString('activeTrail') ?? 't1';

    final upStr = _prefs.getString('upgrades');
    if (upStr != null) {
      try {
        final Map<String, dynamic> decoded = jsonDecode(upStr);
        upgrades = decoded.map((k, v) => MapEntry(k, v as int));
      } catch (_) {}
    }

    final boostStr = _prefs.getString('boostStocks');
    if (boostStr != null) {
      try {
        final Map<String, dynamic> decoded = jsonDecode(boostStr);
        boostStocks = decoded.map((k, v) => MapEntry(k, v as int));
      } catch (_) {}
    }

    unlockedFish = _prefs.getStringList('unlockedFish') ?? ['guppy', 'tetra'];
    aquariumSand = _prefs.getInt('aquariumSand') ?? 1;
    aquariumMoss = _prefs.getInt('aquariumMoss') ?? 2;
    aquariumKelp = _prefs.getInt('aquariumKelp') ?? 1;
    aquariumAnubias = _prefs.getInt('aquariumAnubias') ?? 1;

    lastDailyClaimDate = _prefs.getString('lastDailyClaimDate');
    dailyStreak = _prefs.getInt('dailyStreak') ?? 1;

    final speedIndex = _prefs.getInt('speedSetting') ?? 1;
    speed = SpeedSetting.values[speedIndex.clamp(0, SpeedSetting.values.length - 1)];

    sfxEnabled = _prefs.getBool('sfxEnabled') ?? true;
    hapticsEnabled = _prefs.getBool('hapticsEnabled') ?? true;

    language = _prefs.getString('language') ?? 'en';
    unlockedBackgrounds = (_prefs.getStringList('unlockedBackgrounds') ?? ['bg_default']).toSet();
    activeBackground = _prefs.getString('activeBackground') ?? 'bg_default';

    _initialized = true;
    notifyListeners();
  }

  Future<void> addGold(int amount) async {
    gold += amount;
    await _prefs.setInt('gold', gold);
    notifyListeners();
  }

  Future<bool> spendGold(int amount) async {
    if (gold < amount) return false;
    gold -= amount;
    await _prefs.setInt('gold', gold);
    notifyListeners();
    return true;
  }

  Future<void> updateHighScore(GameMode mode, int score) async {
    final key = mode.name;
    final current = highScores[key] ?? 0;
    if (score > current) {
      highScores[key] = score;
      await _prefs.setString('highScores', jsonEncode(highScores));
      notifyListeners();
    }
  }

  int getHighScore(GameMode mode) => highScores[mode.name] ?? 0;

  Future<void> unlockBall(String id) async {
    unlockedBalls.add(id);
    await _prefs.setStringList('unlockedBalls', unlockedBalls.toList());
    notifyListeners();
  }

  Future<void> equipBall(String id) async {
    activeBall = id;
    await _prefs.setString('activeBall', id);
    notifyListeners();
  }

  Future<void> unlockPaddle(String id) async {
    unlockedPaddles.add(id);
    await _prefs.setStringList('unlockedPaddles', unlockedPaddles.toList());
    notifyListeners();
  }

  Future<void> equipPaddle(String id) async {
    activePaddle = id;
    await _prefs.setString('activePaddle', id);
    notifyListeners();
  }

  Future<void> unlockTrail(String id) async {
    unlockedTrails.add(id);
    await _prefs.setStringList('unlockedTrails', unlockedTrails.toList());
    notifyListeners();
  }

  Future<void> equipTrail(String id) async {
    activeTrail = id;
    await _prefs.setString('activeTrail', id);
    notifyListeners();
  }

  Future<void> upgradeSkill(String id) async {
    final cur = upgrades[id] ?? 0;
    upgrades[id] = cur + 1;
    await _prefs.setString('upgrades', jsonEncode(upgrades));
    notifyListeners();
  }

  Future<void> addBoostStock(String id, int count) async {
    final cur = boostStocks[id] ?? 0;
    boostStocks[id] = cur + count;
    await _prefs.setString('boostStocks', jsonEncode(boostStocks));
    notifyListeners();
  }

  Future<bool> consumeBoost(String id) async {
    final cur = boostStocks[id] ?? 0;
    if (cur <= 0) return false;
    boostStocks[id] = cur - 1;
    await _prefs.setString('boostStocks', jsonEncode(boostStocks));
    notifyListeners();
    return true;
  }

  Future<void> addFish(String fishId) async {
    unlockedFish.add(fishId);
    await _prefs.setStringList('unlockedFish', unlockedFish);
    notifyListeners();
  }

  bool canClaimDaily() {
    final today = DateTime.now().toIso8601String().substring(0, 10);
    return lastDailyClaimDate != today;
  }

  Future<int> claimDailyReward() async {
    if (!canClaimDaily()) return 0;
    final today = DateTime.now().toIso8601String().substring(0, 10);
    lastDailyClaimDate = today;
    await _prefs.setString('lastDailyClaimDate', today);
    dailyStreak++;
    await _prefs.setInt('dailyStreak', dailyStreak);

    final reward = 50 + (dailyStreak % 7) * 15;
    await addGold(reward);
    return reward;
  }

  Future<void> setSpeed(SpeedSetting s) async {
    speed = s;
    await _prefs.setInt('speedSetting', s.index);
    notifyListeners();
  }

  Future<void> setSfx(bool val) async {
    sfxEnabled = val;
    await _prefs.setBool('sfxEnabled', val);
    notifyListeners();
  }

  Future<void> setHaptics(bool val) async {
    hapticsEnabled = val;
    await _prefs.setBool('hapticsEnabled', val);
    notifyListeners();
  }

  Future<void> setLanguage(String lang) async {
    language = lang;
    await _prefs.setString('language', lang);
    notifyListeners();
  }

  Future<bool> unlockBackground(String id, int cost) async {
    if (unlockedBackgrounds.contains(id)) return true;
    if (gold < cost) return false;
    await spendGold(cost);
    unlockedBackgrounds.add(id);
    await _prefs.setStringList('unlockedBackgrounds', unlockedBackgrounds.toList());
    notifyListeners();
    return true;
  }

  Future<void> selectBackground(String id) async {
    if (unlockedBackgrounds.contains(id)) {
      activeBackground = id;
      await _prefs.setString('activeBackground', id);
      notifyListeners();
    }
  }
}
