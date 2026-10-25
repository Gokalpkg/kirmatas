import '../engine/analytics_manager.dart';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/game_state.dart';
import '../models/cosmetics.dart';
import '../models/sector_data.dart';

class LeagueRival {
  final String name;
  final int score;
  final bool isPlayer;
  int rank;

  LeagueRival({
    required this.name,
    required this.score,
    required this.isPlayer,
    this.rank = 0,
  });
}

/// A real player friend added via Friend Tag / Kaunos ID (#KRM-XXXX).
class RealFriend {
  final String tag;
  String name;
  int weeklyScore;
  int highScore;
  int leagueTier;
  DateTime lastSeen;

  RealFriend({
    required this.tag,
    required this.name,
    this.weeklyScore = 0,
    this.highScore = 0,
    this.leagueTier = 0,
    DateTime? lastSeen,
  }) : lastSeen = lastSeen ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'tag': tag,
        'name': name,
        'weeklyScore': weeklyScore,
        'highScore': highScore,
        'leagueTier': leagueTier,
        'lastSeen': lastSeen.millisecondsSinceEpoch,
      };

  factory RealFriend.fromJson(Map<String, dynamic> json) => RealFriend(
        tag: (json['tag'] as String?) ?? '',
        name: (json['name'] as String?) ?? 'Arkadaş',
        weeklyScore: (json['weeklyScore'] as num?)?.toInt() ?? 0,
        highScore: (json['highScore'] as num?)?.toInt() ?? 0,
        leagueTier: (json['leagueTier'] as num?)?.toInt() ?? 0,
        lastSeen: json['lastSeen'] != null
            ? DateTime.fromMillisecondsSinceEpoch(json['lastSeen'] as int)
            : DateTime.now(),
      );
}

/// One weekly-league bot: drifts from [startScore] on Monday to
/// [endScore] by week end so the table stays alive all week.
class _LeagueBot {
  final String name;
  final int startScore;
  final int endScore;

  const _LeagueBot({
    required this.name,
    required this.startScore,
    required this.endScore,
  });

  int scoreAt(double weekProgress) =>
      startScore + ((endScore - startScore) * weekProgress).round();

  Map<String, dynamic> toJson() => {
        'n': name,
        's': startScore,
        'e': endScore,
      };

  factory _LeagueBot.fromJson(Map<String, dynamic> json) => _LeagueBot(
        name: json['n'].toString(),
        startScore: (json['s'] as num?)?.toInt() ?? 0,
        endScore: (json['e'] as num?)?.toInt() ?? 0,
      );
}

class PendingCrate {
  final String crateType; // 'aquarium', 'category', 'guaranteed'
  final String? crateId;
  final String? category;
  final String rewardType; // 'fish', 'ball', 'paddle', 'trail', 'brick', 'gold'
  final String rewardId;
  final String rewardTitle;
  final String rewardSubtitle;
  final int rarityIndex;
  final bool isDuplicate;
  final bool isShardReward;
  final int shardCount;
  final bool isFoodBonus;
  final int bonusFoodCount;
  final int bonusGoldCount;

  PendingCrate({
    required this.crateType,
    this.crateId,
    this.category,
    required this.rewardType,
    required this.rewardId,
    required this.rewardTitle,
    required this.rewardSubtitle,
    required this.rarityIndex,
    this.isDuplicate = false,
    this.isShardReward = false,
    this.shardCount = 1,
    this.isFoodBonus = false,
    this.bonusFoodCount = 0,
    this.bonusGoldCount = 0,
  });

  Map<String, dynamic> toJson() => {
    'crateType': crateType,
    'crateId': crateId,
    'category': category,
    'rewardType': rewardType,
    'rewardId': rewardId,
    'rewardTitle': rewardTitle,
    'rewardSubtitle': rewardSubtitle,
    'rarityIndex': rarityIndex,
    'isDuplicate': isDuplicate,
    'isShardReward': isShardReward,
    'shardCount': shardCount,
    'isFoodBonus': isFoodBonus,
    'bonusFoodCount': bonusFoodCount,
    'bonusGoldCount': bonusGoldCount,
  };

  factory PendingCrate.fromJson(Map<String, dynamic> json) => PendingCrate(
    crateType: json['crateType'] as String? ?? 'aquarium',
    crateId: json['crateId'] as String?,
    category: json['category'] as String?,
    rewardType: json['rewardType'] as String? ?? 'fish',
    rewardId: json['rewardId'] as String? ?? '',
    rewardTitle: json['rewardTitle'] as String? ?? '',
    rewardSubtitle: json['rewardSubtitle'] as String? ?? '',
    rarityIndex: json['rarityIndex'] as int? ?? 0,
    isDuplicate: json['isDuplicate'] as bool? ?? false,
    isShardReward: json['isShardReward'] as bool? ?? false,
    shardCount: (json['shardCount'] as num?)?.toInt() ?? 1,
    isFoodBonus: json['isFoodBonus'] as bool? ?? false,
    bonusFoodCount: json['bonusFoodCount'] as int? ?? 0,
    bonusGoldCount: json['bonusGoldCount'] as int? ?? 0,
  );
}

/// Care state of a single fish, for aquarium UI:
/// - [ready]: its 6h cycle finished, gold waits in the hoard chest.
/// - [producing]: fed, 6h gold timer still running.
/// - [waiting]: not in a cycle; feeding it starts gold production.
enum FishCareState { ready, producing, waiting }

class SaveManager extends ChangeNotifier {
  static final SaveManager instance = SaveManager._internal();
  SaveManager._internal();

  SharedPreferences? _prefs;
  bool _initialized = false;
  static const String _kPendingCrate = 'pending_unopened_crate';

  PendingCrate? pendingCrate;

  int gold = 300;

  /// Player-chosen display name, shown on the menu badge and in the
  /// weekly league table. Defaults to 'SEN' until renamed.
  static const String defaultPlayerName = 'SEN';
  static const int maxPlayerNameLength = 14;
  String playerName = defaultPlayerName;

  Future<void> setPlayerName(String raw) async {
    var name = raw.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (name.length > maxPlayerNameLength) {
      name = name.substring(0, maxPlayerNameLength);
    }
    playerName = name.isEmpty ? defaultPlayerName : name;
    await _prefs?.setString('playerName', playerName);
    notifyListeners();
  }

  /// Unique Supercell-style Friend Tag / Kaunos ID (e.g. #KRM-7842).
  String playerTag = '';

  /// Locally cached real friends added by Friend Tag.
  List<RealFriend> realFriends = [];

  Future<void> addRealFriend(RealFriend friend) async {
    realFriends.removeWhere((f) => f.tag.toUpperCase() == friend.tag.toUpperCase());
    realFriends.add(friend);
    await persistRealFriends();
  }

  Future<void> removeRealFriend(String tag) async {
    realFriends.removeWhere((f) => f.tag.toUpperCase() == tag.toUpperCase());
    await persistRealFriends();
  }

  Future<void> persistRealFriends() async {
    await _prefs?.setString(
      'realFriendsJson',
      jsonEncode(realFriends.map((f) => f.toJson()).toList()),
    );
    notifyListeners();
  }

  int sfxVolume = 8;
  int bgmVolume = 3;
  int vibrationLevel = 8;
  int paddleVolume = 8;
  int ballVolume = 8;
  int brickVolume = 8;
  Map<String, int> highScores = {
    'classic': 0,
    'zen': 0,
    'descend': 0,
    'daily': 0,
    'chaos': 0,
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
  Map<String, int> categoryShards = {'balls': 0, 'paddles': 0, 'trails': 0, 'bricks': 0};

  // --- KALICI LÜKS YADİGAR (PERMANENT RELIC) & ANTİK MÜHÜR YUVASI ---
  bool hasPermanentRelic = false;
  String activeRelicStyle = 'aegis'; // 'aegis' (Muhafız), 'overdrive' (Hız), 'alchemist' (Simyacı)
  bool adsRemoved = false;
  bool removeAdsOfferSeen = false;

  // --- KAYITLI OYUN DEVAM ET (SAVE PROGRESSION - CLASSIC & CHAOS) ---
  int? classicSavedLevel;
  int? classicSavedScore;
  int? classicSavedLives;

  int? chaosSavedLevel;
  int? chaosSavedScore;
  int? chaosSavedStock;

  List<String> unlockedFish = ['guppy', 'tetra'];
  Map<String, int> ownedFishCounts = {'guppy': 1, 'tetra': 1};
  int fishShards = 0; // 0..8 (8 unlocks guaranteed unowned fish chest)

  // --- LOCAL LIFETIME STATS (balance insight, shown in the stats screen) ---
  int statTotalRuns = 0;
  int statTotalDeaths = 0;
  int statTotalClears = 0;
  int statBricksBrokenTotal = 0;
  int statGoldEarnedTotal = 0;
  int statPlaySeconds = 0;
  Map<int, int> statDeathsByLevel = {};
  Map<int, int> statClearsByLevel = {};

  /// Best chaos wave ever reached (drives the chaos rank title).
  int bestChaosWave = 0;

  static const List<String> chaosRankTitles = [
    'Dalga Çaylakı',
    'Kaos Acemisi',
    'Dalga Kırıcı',
    'Fırtına Ustası',
    'Kaos Lordu',
    'Uçurum Fatihi',
    'Kozmik Yıkıcı',
  ];

  String get chaosRankTitle {
    final w = bestChaosWave;
    if (w >= 45) return chaosRankTitles[6];
    if (w >= 30) return chaosRankTitles[5];
    if (w >= 20) return chaosRankTitles[4];
    if (w >= 15) return chaosRankTitles[3];
    if (w >= 10) return chaosRankTitles[2];
    if (w >= 5) return chaosRankTitles[1];
    return chaosRankTitles[0];
  }

  int get chaosRankTier {
    final w = bestChaosWave;
    if (w >= 45) return 6;
    if (w >= 30) return 5;
    if (w >= 20) return 4;
    if (w >= 15) return 3;
    if (w >= 10) return 2;
    if (w >= 5) return 1;
    return 0;
  }
  static const int maxFishShards = 8;
  int aquariumSand = 1;
  int aquariumMoss = 2;
  int aquariumKelp = 1;
  int aquariumAnubias = 1;

  // --- ECO-TANK PER-FISH FEEDING & 6-HOUR GOLD PAYOUT ---
  int fishFood = 5;
  int lastFishFedTimestamp = 0;
  String? lastFishFedDay;
  Map<String, int> fishFedTimestamps = {}; // fishId -> epoch ms when 6h cycle started
  static const int fishFedDurationHours = 6;
  static const int fishSatietyDurationHours = 3;
  static const int fishPayoutDurationMs = fishFedDurationHours * 3600 * 1000;
  static const int fishSatietyDurationMs = fishSatietyDurationHours * 3600 * 1000;
  String? lastDailyFishFoodAdDate;

  // --- 7-DAY LOGIN STREAK ---
  String? lastDailyClaimDate;
  int dailyStreak = 1;
  int dailyLoginStreak = 1; // 1 to 7
  String? lastDailyLoginClaimDate;
  String? lastDailyLoginAdClaimDate;
  int dailyLoginClaimedDay = 1;

  // --- FORTUNE WHEEL (5 SPINS PER DAY: 1 FREE + 4 AD-BACKED) ---
  static const int maxDailyWheelSpins = 5;
  String? lastFortuneWheelDate;
  int fortuneWheelSpinsToday = 0;

  // --- DAILY QUESTS ---
  String? currentQuestDate;
  int questBricksBroken = 0;
  bool questFishFed = false;
  bool questAdOrWinDone = false;
  int questZenSeconds = 0;
  int questShapesClears = 0;
  int questDescendRows = 0;
  Set<String> claimedQuests = {};

  int lastAdWatchTime = 0;

  bool seenFirstShot = false;
  bool seenFoodLink = false;
  int bricksUntilFood = 8;
  Set<String> seenTips = {};

  int metricSessions = 0;
  String? metricFirstDay;
  String? metricLastDay;
  bool metricDay2 = false;
  int metricLevel1Leaves = 0;
  int metricAdCloses = 0;
  int metricHighestClassicLevel = 1;

  int get highestLevel => metricHighestClassicLevel;
  set highestLevel(int val) {
    metricHighestClassicLevel = val;
    _prefs?.setInt('metricHighestClassicLevel', val);
    notifyListeners();
  }

  int get totalGold => gold;
  set totalGold(int val) {
    gold = val;
    _prefs?.setInt('gold', val);
    notifyListeners();
  }

  bool get isShopUnlocked => highestLevel >= 2 || totalGold >= 100;
  bool get isWorkshopUnlocked => highestLevel >= 3;
  bool get isAquariumUnlocked => highestLevel >= 5;
  bool get isChaosUnlocked => highestLevel >= 5;
  bool get isLeagueUnlocked => highestLevel >= 7;

  // --- R5: COSMIC MASTERY & PEARLS ---
  int _pearls = 0;
  int get pearls => _pearls;
  set pearls(int val) {
    _pearls = val;
    _prefs?.setInt('pearls', val);
    notifyListeners();
  }

  int cosmicGoldMasteryLevel = 0;
  int cosmicPearlMasteryLevel = 0;

  int get cosmicGoldMasteryCost => 1000 + cosmicGoldMasteryLevel * 500;
  int get cosmicPearlMasteryCost => 5 + cosmicPearlMasteryLevel * 3;

  void addPearls(int amount) {
    if (amount <= 0) return;
    pearls += amount;
  }

  bool spendPearls(int amount) {
    if (amount <= 0) return true;
    if (_pearls < amount) return false;
    pearls -= amount;
    return true;
  }

  bool upgradeCosmicGoldMastery() {
    final cost = cosmicGoldMasteryCost;
    if (gold < cost) return false;
    gold -= cost;
    _prefs?.setInt('gold', gold);
    cosmicGoldMasteryLevel++;
    _prefs?.setInt('cosmicGoldMasteryLevel', cosmicGoldMasteryLevel);
    notifyListeners();
    return true;
  }

  bool upgradeCosmicPearlMastery() {
    final cost = cosmicPearlMasteryCost;
    if (_pearls < cost) return false;
    _pearls -= cost;
    _prefs?.setInt('pearls', _pearls);
    cosmicPearlMasteryLevel++;
    _prefs?.setInt('cosmicPearlMasteryLevel', cosmicPearlMasteryLevel);
    notifyListeners();
    return true;
  }

  int upgradeCosmicGoldMasteryBulk([int maxSteps = 5]) {
    int upgraded = 0;
    for (int i = 0; i < maxSteps; i++) {
      final cost = cosmicGoldMasteryCost;
      if (gold < cost) break;
      gold -= cost;
      cosmicGoldMasteryLevel++;
      upgraded++;
    }
    if (upgraded > 0) {
      _prefs?.setInt('gold', gold);
      _prefs?.setInt('cosmicGoldMasteryLevel', cosmicGoldMasteryLevel);
      notifyListeners();
    }
    return upgraded;
  }

  int upgradeCosmicPearlMasteryBulk([int maxSteps = 5]) {
    int upgraded = 0;
    for (int i = 0; i < maxSteps; i++) {
      final cost = cosmicPearlMasteryCost;
      if (_pearls < cost) break;
      _pearls -= cost;
      cosmicPearlMasteryLevel++;
      upgraded++;
    }
    if (upgraded > 0) {
      _prefs?.setInt('pearls', _pearls);
      _prefs?.setInt('cosmicPearlMasteryLevel', cosmicPearlMasteryLevel);
      notifyListeners();
    }
    return upgraded;
  }

  // --- R6: DAILY BLITZ & PRESTIGE ---
  String? lastDailyBlitzDate;

  static String formatDailyDate(DateTime d) {
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '${d.year}-$m-$day';
  }

  bool get isDailyBlitzCompletedToday {
    final today = formatDailyDate(DateTime.now());
    return lastDailyBlitzDate == today;
  }

  bool claimDailyBlitzReward({DateTime? date}) {
    final d = date ?? DateTime.now();
    final today = formatDailyDate(d);
    if (lastDailyBlitzDate == today) return false;
    lastDailyBlitzDate = today;
    _prefs?.setString('lastDailyBlitzDate', today);
    addGold(250);
    addPearls(3);
    addShard('balls', 1);
    notifyListeners();
    return true;
  }

  int get prestigeTier {
    final lvl = (classicSavedLevel != null && classicSavedLevel! > metricHighestClassicLevel)
        ? classicSavedLevel!
        : metricHighestClassicLevel;
    return lvl > 238 ? ((lvl - 239) ~/ 17) + 1 : 0;
  }

  static int calculatePrestigeTier(int level) => level > 238 ? ((level - 239) ~/ 17) + 1 : 0;

  // --- R7: SEASONAL TITLES & DYNAMIC RIVALS ---
  int _leagueTier = 0;
  int get leagueTier => _leagueTier;
  set leagueTier(int val) {
    _leagueTier = val.clamp(0, 4);
    _prefs?.setInt('leagueTier', _leagueTier);
    notifyListeners();
  }

  void setLeagueTier(int tier) {
    leagueTier = tier;
  }

  int _weeklyTournamentScore = 0;
  int get weeklyTournamentScore => _weeklyTournamentScore;
  set weeklyTournamentScore(int val) {
    _weeklyTournamentScore = val;
    _prefs?.setInt('weeklyTournamentScore', _weeklyTournamentScore);
    notifyListeners();
  }

  void addTournamentScore(int points) {
    if (points <= 0) return;
    if (!isLeagueUnlocked) return;
    ensureLeagueWeek();
    weeklyTournamentScore += points;
  }

  void addTournamentPoints(int points) => addTournamentScore(points);

  static const List<String> seasonalTitles = [
    'Çaylak Kırıcı',
    'Neon Avcısı',
    'Plazma Lordu',
    'Elmas Hükümdarı',
    'Kozmik İmparator',
  ];

  String get seasonalTitle => seasonalTitles[leagueTier.clamp(0, seasonalTitles.length - 1)];

  Color get leagueTierColor => leagueColorForTier(leagueTier);

  static Color leagueColorForTier(int tier) {
    switch (tier) {
      case 1:
        return const Color(0xFF00E5FF);
      case 2:
        return const Color(0xFFE040FB);
      case 3:
        return const Color(0xFF80D8FF);
      case 4:
        return const Color(0xFFFFD700);
      default:
        return const Color(0xFFCD7F32);
    }
  }

  static String leagueTitleForTier(int tier) {
    if (tier < 0 || tier >= seasonalTitles.length) return seasonalTitles[0];
    return seasonalTitles[tier];
  }

  // --- WEEKLY LEAGUE CYCLE ---
  // One group of 14 bots is generated per calendar week (Mon 00:00 ->
  // next Mon 00:00) and persisted. Bot scores grow from their start
  // score to their end-of-week target as the week progresses, so the
  // table moves while you play. When a new week begins the previous
  // week is settled: final rank pays gold/pearls and the top 3 promote
  // while ranks 11-15 demote.

  static const int leagueGroupSize = 15;
  static const int leaguePromotionCutoff = 3;
  static const int leagueDemotionStart = 11;

  static const List<int> _leagueMinScores = [600, 2500, 8000, 20000, 50000];
  static const List<int> _leagueMaxScores = [2800, 9500, 24000, 55000, 130000];

  static const List<String> _leagueRivalNames = [
    'DemirBilek', 'PikselUsta', 'NeonFırtına', 'KozmikGezgin',
    'YıldızAvcısı', 'GlitchKing', 'AuraBreaker', 'GölgeSavaşçı',
    'NovaKıran', 'SiberPence', 'KuvarsGozu', 'EterYolcusu',
    'FotonUstası', 'ZirveBekçisi'
  ];

  String leagueWeekId = '';
  int leagueRivalsTier = -1;
  List<_LeagueBot> _leagueBots = [];

  int leagueLastRank = 0;
  int leagueLastTierPlayed = 0;
  int leagueLastRewardGold = 0;
  int leagueLastRewardPearls = 0;
  int leagueLastMovement = 0; // -1 demoted, 0 stayed, 1 promoted
  bool leagueLastResultSeen = true;

  bool get hasUnseenLeagueResult =>
      leagueLastRank > 0 && !leagueLastResultSeen;

  // --- PROGRESSIVE UNLOCK REVEAL ---
  // Features the player has already opened at least once. Anything
  // unlocked but not yet seen gets a quiet "YENİ!" badge in the menu,
  // so new systems announce themselves once instead of all shouting
  // for attention from day one.
  Set<String> seenUnlocks = {};

  bool isUnlockNew(String id, bool unlocked) =>
      unlocked && !seenUnlocks.contains(id);

  Future<void> markUnlockSeen(String id) async {
    if (seenUnlocks.add(id)) {
      await _prefs?.setStringList('seenUnlocks', seenUnlocks.toList());
      notifyListeners();
    }
  }

  static DateTime leagueWeekStartFor(DateTime now) {
    final d = DateTime(now.year, now.month, now.day);
    return d.subtract(Duration(days: d.weekday - 1));
  }

  static String leagueWeekIdFor(DateTime weekStart) =>
      '${weekStart.year}-${weekStart.month.toString().padLeft(2, '0')}-'
      '${weekStart.day.toString().padLeft(2, '0')}';

  DateTime leagueWeekEndFor({DateTime? now}) =>
      leagueWeekStartFor(now ?? DateTime.now()).add(const Duration(days: 7));

  Duration leagueTimeRemaining({DateTime? now}) {
    final n = now ?? DateTime.now();
    final r = leagueWeekEndFor(now: n).difference(n);
    return r.isNegative ? Duration.zero : r;
  }

  double leagueWeekProgress({DateTime? now}) {
    final n = now ?? DateTime.now();
    final start = leagueWeekStartFor(n);
    return (n.difference(start).inSeconds / (7 * 24 * 3600))
        .clamp(0.0, 1.0);
  }

  static int leagueBaseGoldForRank(int rank) {
    if (rank <= 1) return 400;
    if (rank == 2) return 300;
    if (rank == 3) return 220;
    if (rank <= 10) return 120;
    return 40;
  }

  static int leaguePearlsForRank(int rank) =>
      rank == 1 ? 2 : (rank <= 3 ? 1 : 0);

  /// Prospective reward at the tier you are currently playing in.
  int leagueRewardGoldForRank(int rank) =>
      leagueBaseGoldForRank(rank) * (leagueTier + 1);

  void _persistLeagueState() {
    _prefs?.setString('leagueWeekId', leagueWeekId);
    _prefs?.setInt('leagueRivalsTier', leagueRivalsTier);
    _prefs?.setString(
      'leagueRivalsJson',
      jsonEncode(_leagueBots.map((b) => b.toJson()).toList()),
    );
    _prefs?.setInt('leagueLastRank', leagueLastRank);
    _prefs?.setInt('leagueLastTierPlayed', leagueLastTierPlayed);
    _prefs?.setInt('leagueLastRewardGold', leagueLastRewardGold);
    _prefs?.setInt('leagueLastRewardPearls', leagueLastRewardPearls);
    _prefs?.setInt('leagueLastMovement', leagueLastMovement);
    _prefs?.setBool('leagueLastResultSeen', leagueLastResultSeen);
  }

  void _generateLeagueBots(String weekId) {
    final tierIdx = leagueTier.clamp(0, 4);
    final rng = math.Random(weekId.hashCode ^ (tierIdx * 7919));
    final names = List<String>.from(_leagueRivalNames)..shuffle(rng);
    final minS = _leagueMinScores[tierIdx];
    final maxS = _leagueMaxScores[tierIdx];
    _leagueBots = [];
    for (var i = 0; i < leagueGroupSize - 1; i++) {
      final end = minS + (maxS - minS) * (0.25 + rng.nextDouble() * 0.72);
      final start = minS + (end - minS) * (0.05 + rng.nextDouble() * 0.25);
      _leagueBots.add(_LeagueBot(
        name: names[i],
        startScore: start.round(),
        endScore: end.round(),
      ));
    }
    leagueRivalsTier = tierIdx;
    _persistLeagueState();
  }

  /// Settles the finished week: pays rewards and moves the player
  /// between tiers based on the final rank (bots at end-of-week form).
  void _settleLeagueWeek() {
    final playerScore = _weeklyTournamentScore;
    var rank = 1;
    final botSlots = (leagueGroupSize - 1 - realFriends.length).clamp(0, leagueGroupSize - 1);
    for (final friend in realFriends) {
      if (friend.weeklyScore > playerScore) rank++;
    }
    for (final bot in _leagueBots.take(botSlots)) {
      if (bot.endScore > playerScore) rank++;
    }
    final playedTier =
        (leagueRivalsTier >= 0 ? leagueRivalsTier : leagueTier).clamp(0, 4);
    final gold = leagueBaseGoldForRank(rank) * (playedTier + 1);
    final pearls = leaguePearlsForRank(rank);

    leagueLastRank = rank;
    leagueLastTierPlayed = playedTier;
    leagueLastRewardGold = gold;
    leagueLastRewardPearls = pearls;
    leagueLastMovement = 0;
    if (rank <= leaguePromotionCutoff && playedTier < 4) {
      leagueTier = playedTier + 1;
      leagueLastMovement = 1;
    } else if (rank >= leagueDemotionStart && playedTier > 0) {
      leagueTier = playedTier - 1;
      leagueLastMovement = -1;
    }
    leagueLastResultSeen = false;
    if (gold > 0) addGold(gold);
    if (pearls > 0) addPearls(pearls);
  }

  /// Adopts the current calendar week, settling the previous one first
  /// when the week has rolled over. Safe to call on every read.
  void ensureLeagueWeek({DateTime? now}) {
    final id = leagueWeekIdFor(leagueWeekStartFor(now ?? DateTime.now()));
    if (leagueWeekId == id) {
      if (_leagueBots.length != leagueGroupSize - 1 ||
          leagueRivalsTier != leagueTier) {
        _generateLeagueBots(id);
      }
      return;
    }
    final hadPreviousWeek =
        leagueWeekId.isNotEmpty && _leagueBots.length == leagueGroupSize - 1;
    if (hadPreviousWeek) {
      _settleLeagueWeek();
      _weeklyTournamentScore = 0;
      _prefs?.setInt('weeklyTournamentScore', 0);
    }
    leagueWeekId = id;
    _generateLeagueBots(id);
    _persistLeagueState();
    notifyListeners();
  }

  void markLeagueResultSeen() {
    if (leagueLastResultSeen) return;
    leagueLastResultSeen = true;
    _prefs?.setBool('leagueLastResultSeen', true);
    notifyListeners();
  }

  List<LeagueRival> getLeagueRivals({DateTime? now}) {
    ensureLeagueWeek(now: now);
    final progress = leagueWeekProgress(now: now);
    final botSlots = (leagueGroupSize - 1 - realFriends.length).clamp(0, leagueGroupSize - 1);
    final List<LeagueRival> list = [
      for (final f in realFriends)
        LeagueRival(name: '${f.name} (${f.tag})', score: f.weeklyScore, isPlayer: false),
      for (final b in _leagueBots.take(botSlots))
        LeagueRival(name: b.name, score: b.scoreAt(progress), isPlayer: false),
      LeagueRival(name: playerName, score: weeklyTournamentScore, isPlayer: true),
    ];
    list.sort((a, b) {
      final byScore = b.score.compareTo(a.score);
      return byScore != 0 ? byScore : a.name.compareTo(b.name);
    });
    for (int i = 0; i < list.length; i++) {
      list[i].rank = i + 1;
    }
    return list;
  }

  bool usedFreeContinue = false;
  String? dayBlessingDate;
  List<String> playEvents = [];

  SpeedSetting speed = SpeedSetting.medium;
  bool sfxEnabled = true;
  bool hapticsEnabled = true;
  HapticIntensity hapticIntensity = HapticIntensity.strong;

  String language = 'tr';
  Set<String> unlockedBackgrounds = {'bg_default'};
  String activeBackground = 'bg_default';
  Set<String> unlockedBrickStyles = {'brick_gloss'};
  String activeBrickStyle = 'brick_gloss';

  Future<void> init() async {
    if (_initialized) return;
    _prefs = await SharedPreferences.getInstance();

    gold = _prefs?.getInt('gold') ?? 300;
    playerName = _prefs?.getString('playerName') ?? defaultPlayerName;
    playerTag = _prefs?.getString('playerTag') ?? '';
    if (playerTag.isEmpty) {
      final rng = math.Random();
      final hexCode = (rng.nextInt(0xEFFF) + 0x1000).toRadixString(16).toUpperCase();
      playerTag = '#KRM-$hexCode';
      _prefs?.setString('playerTag', playerTag);
    }

    final rfJson = _prefs?.getString('realFriendsJson');
    if (rfJson != null) {
      try {
        final List decoded = jsonDecode(rfJson);
        realFriends = decoded
            .map((e) => RealFriend.fromJson(e as Map<String, dynamic>))
            .toList();
      } catch (_) {}
    }
    sfxVolume = _prefs?.getInt('sfxVolume') ?? 8;
    bgmVolume = _prefs?.getInt('bgmVolume') ?? 3;
    vibrationLevel = _prefs?.getInt('vibrationLevel') ?? 8;
    paddleVolume = _prefs?.getInt('paddleVolume') ?? 8;
    ballVolume = _prefs?.getInt('ballVolume') ?? 8;
    brickVolume = _prefs?.getInt('brickVolume') ?? 8;

    final hsStr = _prefs?.getString('highScores');
    if (hsStr != null) {
      try {
        final Map<String, dynamic> decoded = jsonDecode(hsStr);
        highScores = decoded.map((k, v) => MapEntry(k, v as int));
      } catch (_) {}
    }

    unlockedBalls = (_prefs?.getStringList('unlockedBalls') ?? ['classic']).toSet();
    unlockedPaddles = (_prefs?.getStringList('unlockedPaddles') ?? ['pclassic']).toSet();
    unlockedTrails = (_prefs?.getStringList('unlockedTrails') ?? ['t1']).toSet();

    activeBall = _prefs?.getString('activeBall') ?? 'classic';
    activePaddle = _prefs?.getString('activePaddle') ?? 'pclassic';
    activeTrail = _prefs?.getString('activeTrail') ?? 't1';

    final upStr = _prefs?.getString('upgrades');
    if (upStr != null) {
      try {
        final Map<String, dynamic> decoded = jsonDecode(upStr);
        upgrades = decoded.map((k, v) => MapEntry(k, v as int));
      } catch (_) {}
    }

    final boostStr = _prefs?.getString('boostStocks');
    if (boostStr != null) {
      try {
        final Map<String, dynamic> decoded = jsonDecode(boostStr);
        boostStocks = decoded.map((k, v) => MapEntry(k, v as int));
      } catch (_) {}
    }

    final shardsStr = _prefs?.getString('categoryShards');
    if (shardsStr != null) {
      try {
        final Map<String, dynamic> decoded = jsonDecode(shardsStr);
        categoryShards = decoded.map((k, v) => MapEntry(k, v as int));
      } catch (_) {}
    }

    unlockedFish = _prefs?.getStringList('unlockedFish') ?? ['guppy', 'tetra'];
    fishShards = _prefs?.getInt('fishShards') ?? 0;
    statTotalRuns = _prefs?.getInt('statTotalRuns') ?? 0;
    statTotalDeaths = _prefs?.getInt('statTotalDeaths') ?? 0;
    statTotalClears = _prefs?.getInt('statTotalClears') ?? 0;
    statBricksBrokenTotal = _prefs?.getInt('statBricksBrokenTotal') ?? 0;
    statGoldEarnedTotal = _prefs?.getInt('statGoldEarnedTotal') ?? 0;
    statPlaySeconds = _prefs?.getInt('statPlaySeconds') ?? 0;
    bestChaosWave = _prefs?.getInt('bestChaosWave') ?? 0;
    statDeathsByLevel = _loadIntMap('statDeathsByLevel');
    statClearsByLevel = _loadIntMap('statClearsByLevel');
    final fishCountsStr = _prefs?.getString('ownedFishCounts');
    if (fishCountsStr != null) {
      try {
        final Map<String, dynamic> decoded = jsonDecode(fishCountsStr);
        ownedFishCounts = decoded.map((k, v) => MapEntry(k, (v as num).toInt().clamp(1, 2)));
      } catch (_) {}
    } else {
      // Migrate from unlockedFish
      ownedFishCounts = {for (final id in unlockedFish) id: 1};
    }
    // Keep unlockedFish synced with ownedFishCounts
    for (final id in unlockedFish) {
      ownedFishCounts.putIfAbsent(id, () => 1);
    }
    unlockedFish = ownedFishCounts.keys.toList();
    aquariumSand = _prefs?.getInt('aquariumSand') ?? 1;
    aquariumMoss = _prefs?.getInt('aquariumMoss') ?? 2;
    aquariumKelp = _prefs?.getInt('aquariumKelp') ?? 1;
    aquariumAnubias = _prefs?.getInt('aquariumAnubias') ?? 1;

    fishFood = _prefs?.getInt('fishFood') ?? 5;
    seenFirstShot = _prefs?.getBool('seenFirstShot') ?? false;
    seenFoodLink = _prefs?.getBool('seenFoodLink') ?? false;
    seenTips = (_prefs?.getStringList('seenTips') ?? []).toSet();
    bricksUntilFood = _prefs?.getInt('bricksUntilFood') ?? 8;
    metricSessions = _prefs?.getInt('metricSessions') ?? 0;
    metricFirstDay = _prefs?.getString('metricFirstDay');
    metricLastDay = _prefs?.getString('metricLastDay');
    metricDay2 = _prefs?.getBool('metricDay2') ?? false;
    metricLevel1Leaves = _prefs?.getInt('metricLevel1Leaves') ?? 0;
    metricAdCloses = _prefs?.getInt('metricAdCloses') ?? 0;
    usedFreeContinue = _prefs?.getBool('usedFreeContinue') ?? false;
    dayBlessingDate = _prefs?.getString('dayBlessingDate');
    playEvents = _prefs?.getStringList('playEvents') ?? [];
    lastFishFedTimestamp = _prefs?.getInt('lastFishFedTimestamp') ?? 0;
    lastFishFedDay = _prefs?.getString('lastFishFedDay');
    final fedMapStr = _prefs?.getString('fishFedTimestamps');
    if (fedMapStr != null) {
      try {
        final Map<String, dynamic> decoded = jsonDecode(fedMapStr);
        fishFedTimestamps = decoded.map((k, v) => MapEntry(k, v as int));
      } catch (_) {}
    }

    lastDailyClaimDate = _prefs?.getString('lastDailyClaimDate');
    dailyStreak = _prefs?.getInt('dailyStreak') ?? 1;
    dailyLoginStreak = _prefs?.getInt('dailyLoginStreak') ?? 1;
    lastDailyLoginClaimDate = _prefs?.getString('lastDailyLoginClaimDate');
    lastDailyLoginAdClaimDate = _prefs?.getString('lastDailyLoginAdClaimDate');
    dailyLoginClaimedDay = _prefs?.getInt('dailyLoginClaimedDay') ?? 1;

    lastFortuneWheelDate = _prefs?.getString('lastFortuneWheelDate');
    fortuneWheelSpinsToday = _prefs?.getInt('fortuneWheelSpinsToday') ?? 0;
    final todayStr = DateTime.now().toIso8601String().substring(0, 10);
    if (lastFortuneWheelDate != todayStr) {
      fortuneWheelSpinsToday = 0;
    }

    currentQuestDate = _prefs?.getString('currentQuestDate');
    questBricksBroken = _prefs?.getInt('questBricksBroken') ?? 0;
    questFishFed = _prefs?.getBool('questFishFed') ?? false;
    questAdOrWinDone = _prefs?.getBool('questAdOrWinDone') ?? false;
    seenUnlocks = (_prefs?.getStringList('seenUnlocks') ?? []).toSet();
    questZenSeconds = _prefs?.getInt('questZenSeconds') ?? 0;
    questShapesClears = _prefs?.getInt('questShapesClears') ?? 0;
    questDescendRows = _prefs?.getInt('questDescendRows') ?? 0;
    claimedQuests = (_prefs?.getStringList('claimedQuests') ?? []).toSet();
    _checkAndResetQuests();

    final speedIndex = _prefs?.getInt('speedSetting') ?? 0;
    speed = SpeedSetting.values[speedIndex.clamp(0, SpeedSetting.values.length - 1)];

    sfxEnabled = _prefs?.getBool('sfxEnabled') ?? true;
    final hIndex = _prefs?.getInt('hapticIntensity') ?? HapticIntensity.strong.index;
    hapticIntensity = HapticIntensity.values[hIndex.clamp(0, HapticIntensity.values.length - 1)];
    hapticsEnabled = hapticIntensity != HapticIntensity.off;

    language = _prefs?.getString('language') ?? 'tr';
    unlockedBackgrounds = (_prefs?.getStringList('unlockedBackgrounds') ?? ['bg_default']).toSet();
    activeBackground = _prefs?.getString('activeBackground') ?? 'bg_default';
    unlockedBrickStyles = (_prefs?.getStringList('unlockedBrickStyles') ?? ['brick_gloss']).toSet();
    activeBrickStyle = _prefs?.getString('activeBrickStyle') ?? 'brick_gloss';
    lastAdWatchTime = _prefs?.getInt('lastAdWatchTime') ?? 0;
    hasPermanentRelic = _prefs?.getBool('hasPermanentRelic') ?? false;
    activeRelicStyle = _prefs?.getString('activeRelicStyle') ?? 'aegis';
    adsRemoved = _prefs?.getBool('adsRemoved') ?? false;
    removeAdsOfferSeen = _prefs?.getBool('removeAdsOfferSeen') ?? false;

    classicSavedLevel = _prefs?.getInt('classicSavedLevel');
    classicSavedScore = _prefs?.getInt('classicSavedScore');
    classicSavedLives = _prefs?.getInt('classicSavedLives');
    metricHighestClassicLevel = _prefs?.getInt('metricHighestClassicLevel') ?? classicSavedLevel ?? 1;

    chaosSavedLevel = _prefs?.getInt('chaosSavedLevel');
    chaosSavedScore = _prefs?.getInt('chaosSavedScore');
    chaosSavedStock = _prefs?.getInt('chaosSavedStock');
    lastDailyFishFoodAdDate = _prefs?.getString('lastDailyFishFoodAdDate');

    _pearls = _prefs?.getInt('pearls') ?? 0;
    cosmicGoldMasteryLevel = _prefs?.getInt('cosmicGoldMasteryLevel') ?? 0;
    cosmicPearlMasteryLevel = _prefs?.getInt('cosmicPearlMasteryLevel') ?? 0;
    lastDailyBlitzDate = _prefs?.getString('lastDailyBlitzDate');
    _leagueTier = (_prefs?.getInt('leagueTier') ?? 0).clamp(0, 4);
    _weeklyTournamentScore = _prefs?.getInt('weeklyTournamentScore') ?? 0;
    leagueWeekId = _prefs?.getString('leagueWeekId') ?? '';
    leagueRivalsTier = _prefs?.getInt('leagueRivalsTier') ?? -1;
    leagueLastRank = _prefs?.getInt('leagueLastRank') ?? 0;
    leagueLastTierPlayed = _prefs?.getInt('leagueLastTierPlayed') ?? 0;
    leagueLastRewardGold = _prefs?.getInt('leagueLastRewardGold') ?? 0;
    leagueLastRewardPearls = _prefs?.getInt('leagueLastRewardPearls') ?? 0;
    leagueLastMovement = _prefs?.getInt('leagueLastMovement') ?? 0;
    leagueLastResultSeen = _prefs?.getBool('leagueLastResultSeen') ?? true;
    _leagueBots = [];
    try {
      final rawBots = _prefs?.getString('leagueRivalsJson');
      if (rawBots != null && rawBots.isNotEmpty) {
        final decoded = jsonDecode(rawBots);
        if (decoded is List) {
          _leagueBots = decoded
              .whereType<Map>()
              .map((e) => _LeagueBot.fromJson(
                  e.map((k, v) => MapEntry(k.toString(), v))))
              .toList();
        }
      }
    } catch (_) {
      _leagueBots = [];
    }

    final pendingJson = _prefs?.getString(_kPendingCrate);
    if (pendingJson != null && pendingJson.isNotEmpty) {
      try {
        final Map<String, dynamic> decoded = jsonDecode(pendingJson);
        pendingCrate = PendingCrate.fromJson(decoded);
      } catch (e) {
        debugPrint('Error loading pending crate: $e');
        pendingCrate = null;
      }
    }

    _initialized = true;
    ensureLeagueWeek();
    notifyListeners();
  }

  void _safeNotifyListeners() {
    try {
      final binding = WidgetsBinding.instance;
      if (binding.schedulerPhase != SchedulerPhase.idle) {
        binding.addPostFrameCallback((_) {
          notifyListeners();
        });
        return;
      }
    } catch (_) {}
    notifyListeners();
  }

  Future<void> savePendingCrate(PendingCrate crate) async {
    pendingCrate = crate;
    await _prefs?.setString(_kPendingCrate, jsonEncode(crate.toJson()));
    _safeNotifyListeners();
  }

  Future<void> clearPendingCrate() async {
    pendingCrate = null;
    await _prefs?.remove(_kPendingCrate);
    _safeNotifyListeners();
  }

  Future<void> claimPendingCrate() async {
    final crate = pendingCrate;
    if (crate == null) return;

    switch (crate.rewardType) {
      case 'fish':
        if (crate.isShardReward) {
          await addFishShards(crate.shardCount > 0 ? crate.shardCount : 1);
        } else {
          await addFish(crate.rewardId);
          if (crate.isFoodBonus && crate.bonusFoodCount > 0) {
            await addFishFood(crate.bonusFoodCount);
          }
        }
        break;
      case 'ball':
        if (crate.isShardReward) {
          await addShard(crate.category ?? 'balls', 1);
        } else {
          await unlockBall(crate.rewardId);
        }
        break;
      case 'paddle':
        if (crate.isShardReward) {
          await addShard(crate.category ?? 'paddles', 1);
        } else {
          await unlockPaddle(crate.rewardId);
        }
        break;
      case 'trail':
        if (crate.isShardReward) {
          await addShard(crate.category ?? 'trails', 1);
        } else {
          await unlockTrail(crate.rewardId);
        }
        break;
      case 'brick':
        if (crate.isShardReward) {
          await addShard(crate.category ?? 'bricks', 1);
        } else {
          await unlockBrickStyle(crate.rewardId);
        }
        break;
      case 'gold':
        if (crate.bonusGoldCount > 0) {
          await addGold(crate.bonusGoldCount);
        }
        break;
    }

    await clearPendingCrate();
  }

  Future<void> setLastAdWatchTime(int time) async {
    lastAdWatchTime = time;
    await _prefs?.setInt('lastAdWatchTime', time);
    notifyListeners();
  }

  Future<void> addGold(int amount) async {
    gold += amount;
    if (amount > 0) {
      statGoldEarnedTotal += amount;
      await _prefs?.setInt('statGoldEarnedTotal', statGoldEarnedTotal);
    }
    await _prefs?.setInt('gold', gold);
    notifyListeners();
  }

  Map<int, int> _loadIntMap(String key) {
    final raw = _prefs?.getString(key);
    if (raw == null) return {};
    try {
      final Map<String, dynamic> decoded = jsonDecode(raw);
      return decoded.map((k, v) => MapEntry(int.tryParse(k) ?? 0, (v as num).toInt()));
    } catch (_) {
      return {};
    }
  }

  Future<void> _saveIntMap(String key, Map<int, int> map) async {
    await _prefs?.setString(key, jsonEncode(map.map((k, v) => MapEntry('$k', v))));
  }

  Future<void> recordRunStarted() async {
    statTotalRuns++;
    await _prefs?.setInt('statTotalRuns', statTotalRuns);
  }

  Future<void> recordClassicLevelFailed(int level) async {
    statTotalDeaths++;
    statDeathsByLevel[level] = (statDeathsByLevel[level] ?? 0) + 1;
    await _prefs?.setInt('statTotalDeaths', statTotalDeaths);
    await _saveIntMap('statDeathsByLevel', statDeathsByLevel);
  }

  Future<void> recordClassicLevelCleared(int level) async {
    statTotalClears++;
    statClearsByLevel[level] = (statClearsByLevel[level] ?? 0) + 1;
    await _prefs?.setInt('statTotalClears', statTotalClears);
    await _saveIntMap('statClearsByLevel', statClearsByLevel);
  }

  Future<void> addLifetimeRunStats({required int bricks, required int seconds}) async {
    if (bricks > 0) {
      statBricksBrokenTotal += bricks;
      await _prefs?.setInt('statBricksBrokenTotal', statBricksBrokenTotal);
    }
    if (seconds > 0) {
      statPlaySeconds += seconds;
      await _prefs?.setInt('statPlaySeconds', statPlaySeconds);
    }
  }

  Future<void> noteBestChaosWave(int wave) async {
    if (wave > bestChaosWave) {
      bestChaosWave = wave;
      await _prefs?.setInt('bestChaosWave', bestChaosWave);
      notifyListeners();
    }
  }

  // --- FULL SAVE EXPORT / IMPORT (Play Games cloud snapshots) ---

  /// Serializes every persisted key into one JSON envelope.
  Future<String> exportAllToJson() async {
    final data = <String, dynamic>{};
    final keys = _prefs?.getKeys() ?? const <String>{};
    for (final k in keys) {
      data[k] = _prefs?.get(k);
    }
    return jsonEncode({
      'app': 'kirmatas',
      'version': 1,
      'savedAtMs': DateTime.now().millisecondsSinceEpoch,
      'data': data,
    });
  }

  /// savedAtMs of a cloud envelope, or null if it is not one of ours.
  static int? cloudSavedAtMs(String raw) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map && decoded['app'] == 'kirmatas') {
        return (decoded['savedAtMs'] as num?)?.toInt();
      }
    } catch (_) {}
    return null;
  }

  int get localSavedAtMs => _prefs?.getInt('localSavedAtMs') ?? 0;

  Future<void> markLocalSavedNow() async {
    await _prefs?.setInt('localSavedAtMs', DateTime.now().millisecondsSinceEpoch);
  }

  /// Overwrites the whole local save from a cloud envelope and reloads.
  Future<bool> importAllFromJson(String raw) async {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map || decoded['app'] != 'kirmatas') return false;
      final data = decoded['data'];
      if (data is! Map) return false;
      final prefs = _prefs;
      if (prefs == null) return false;
      for (final entry in data.entries) {
        final key = entry.key.toString();
        final value = entry.value;
        if (value is int) {
          await prefs.setInt(key, value);
        } else if (value is double) {
          await prefs.setDouble(key, value);
        } else if (value is bool) {
          await prefs.setBool(key, value);
        } else if (value is String) {
          await prefs.setString(key, value);
        } else if (value is List) {
          await prefs.setStringList(key, value.map((e) => e.toString()).toList());
        }
      }
      final cloudMs = cloudSavedAtMs(raw);
      if (cloudMs != null) {
        await prefs.setInt('localSavedAtMs', cloudMs);
      }
      _initialized = false; // force a full reload from the new prefs
      await init();
      notifyListeners();
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> spendGold(int amount) async {
    if (gold < amount) return false;
    gold -= amount;
    await _prefs?.setInt('gold', gold);
    notifyListeners();
    return true;
  }

  Future<void> updateHighScore(GameMode mode, int score) async {
    final key = mode.name;
    final current = highScores[key] ?? 0;
    if (score > current) {
      highScores[key] = score;
      await _prefs?.setString('highScores', jsonEncode(highScores));
      notifyListeners();
    }
  }

  int getHighScore(GameMode mode) => highScores[mode.name] ?? 0;

  Future<void> unlockBall(String id) async {
    unlockedBalls.add(id);
    await _prefs?.setStringList('unlockedBalls', unlockedBalls.toList());
    notifyListeners();
  }

  Future<void> equipBall(String id) async {
    activeBall = id;
    await _prefs?.setString('activeBall', id);
    notifyListeners();
  }

  Future<void> unlockPaddle(String id) async {
    unlockedPaddles.add(id);
    await _prefs?.setStringList('unlockedPaddles', unlockedPaddles.toList());
    notifyListeners();
  }

  Future<void> equipPaddle(String id) async {
    activePaddle = id;
    await _prefs?.setString('activePaddle', id);
    notifyListeners();
  }

  Future<void> unlockTrail(String id) async {
    unlockedTrails.add(id);
    await _prefs?.setStringList('unlockedTrails', unlockedTrails.toList());
    notifyListeners();
  }

  Future<void> equipTrail(String id) async {
    activeTrail = id;
    await _prefs?.setString('activeTrail', id);
    notifyListeners();
  }

  int getUpgradeLevel(String id) {
    if (id == 'u_crit' || id == 'crit_damage') {
      return math.max(upgrades['u_crit'] ?? 0, upgrades['crit_damage'] ?? 0);
    }
    if (id == 'u_luck' || id == 'luck') {
      return math.max(upgrades['u_luck'] ?? 0, upgrades['luck'] ?? 0);
    }
    if (id == 'u_gold' || id == 'gold_multiplier') {
      return math.max(upgrades['u_gold'] ?? 0, upgrades['gold_multiplier'] ?? 0);
    }
    return upgrades[id] ?? 0;
  }

  Future<bool> buyStatUpgrade(String id, int cost) async {
    final cur = getUpgradeLevel(id);
    if (cur >= 5) return false;
    if (gold < cost) return false;
    final ok = await spendGold(cost);
    if (!ok) return false;
    upgrades[id] = cur + 1;
    await _prefs?.setString('upgrades', jsonEncode(upgrades));
    AnalyticsManager.instance.logStatUpgraded(id, cur + 1);
    notifyListeners();
    return true;
  }

  Future<void> upgradeSkill(String id) async {
    final cur = upgrades[id] ?? 0;
    upgrades[id] = cur + 1;
    await _prefs?.setString('upgrades', jsonEncode(upgrades));
    notifyListeners();
  }

  /// Calculates the exact total amount of gold spent on all attribute upgrades.
  int calculateTotalSpentOnUpgrades() {
    int total = 0;
    for (final stat in StatUpgrade.all) {
      final lvl = getUpgradeLevel(stat.id);
      for (int i = 0; i < lvl && i < stat.costs.length; i++) {
        total += stat.costs[i];
      }
    }
    return total;
  }

  /// Resets all attribute upgrades and refunds 100% of gold spent to the player.
  Future<int> resetAllUpgrades() async {
    final refund = calculateTotalSpentOnUpgrades();
    if (refund > 0) {
      await addGold(refund);
    }
    for (final stat in StatUpgrade.all) {
      upgrades[stat.id] = 0;
      if (stat.id == 'crit_damage') upgrades['u_crit'] = 0;
      if (stat.id == 'luck') upgrades['u_luck'] = 0;
    }
    upgrades['u_gold'] = 0;
    upgrades['gold_multiplier'] = 0;
    upgrades['paddle_width'] = 0;
    upgrades['magnet'] = 0;
    upgrades['battery'] = 0;
    await _prefs?.setString('upgrades', jsonEncode(upgrades));
    notifyListeners();
    return refund;
  }

  Future<void> addBoostStock(String id, int count) async {
    final cur = boostStocks[id] ?? 0;
    boostStocks[id] = cur + count;
    await _prefs?.setString('boostStocks', jsonEncode(boostStocks));
    notifyListeners();
  }

  Future<bool> consumeBoost(String id) async {
    final cur = boostStocks[id] ?? 0;
    if (cur <= 0) return false;
    boostStocks[id] = cur - 1;
    await _prefs?.setString('boostStocks', jsonEncode(boostStocks));
    notifyListeners();
    return true;
  }

  int getShards(String category) => categoryShards[category] ?? 0;

  Future<void> addShard(String category, [int count = 1]) async {
    final cur = categoryShards[category] ?? 0;
    categoryShards[category] = cur + count;
    await _prefs?.setString('categoryShards', jsonEncode(categoryShards));
    notifyListeners();
  }

  Future<bool> consumeShards(String category, [int count = 3]) async {
    final cur = categoryShards[category] ?? 0;
    if (cur < count) return false;
    categoryShards[category] = cur - count;
    await _prefs?.setString('categoryShards', jsonEncode(categoryShards));
    notifyListeners();
    return true;
  }

  /// Convert 3 category shards into 2 Pearls
  Future<bool> convertShardsToPearls(String category) async {
    if (getShards(category) < 3) return false;
    final success = await consumeShards(category, 3);
    if (!success) return false;
    addPearls(2);
    return true;
  }

  /// Fish shard count (0..8)
  int getFishShards() => fishShards;

  Future<void> addFishShards([int count = 1]) async {
    fishShards += count;
    await _prefs?.setInt('fishShards', fishShards);
    notifyListeners();
  }

  Future<bool> consumeFishShards([int count = 8]) async {
    if (fishShards < count) return false;
    fishShards -= count;
    await _prefs?.setInt('fishShards', fishShards);
    notifyListeners();
    return true;
  }

  /// Get how many copies of this exact fish color/variant the player owns (0, 1, or 2)
  int getFishCount(String fishId) {
    return ownedFishCounts[fishId] ?? (unlockedFish.contains(fishId) ? 1 : 0);
  }

  /// Returns whether a player can acquire another copy of this fish (< 2)
  bool canAcquireFish(String fishId) {
    return getFishCount(fishId) < 2;
  }

  /// List of all owned fish instances (a fish with count 2 appears twice)
  List<String> get allOwnedFishInstances {
    final list = <String>[];
    for (final entry in ownedFishCounts.entries) {
      for (int i = 0; i < entry.value; i++) {
        list.add(entry.key);
      }
    }
    if (list.isEmpty) {
      return List<String>.from(unlockedFish);
    }
    return list;
  }

  /// Adds a fish copy (max 2 per fish color/species).
  /// Returns true if a new copy was added, false if already at max (2).
  Future<bool> addFishInstance(String fishId) async {
    final currentCount = getFishCount(fishId);
    if (currentCount >= 2) {
      return false;
    }
    ownedFishCounts[fishId] = currentCount + 1;
    if (!unlockedFish.contains(fishId)) {
      unlockedFish.add(fishId);
    }
    await _prefs?.setStringList('unlockedFish', unlockedFish);
    await _prefs?.setString('ownedFishCounts', jsonEncode(ownedFishCounts));
    notifyListeners();
    return true;
  }

  Future<void> unlockFish(String fishId) async {
    await addFishInstance(fishId);
  }

  Future<void> addFish(String fishId) async {
    await addFishInstance(fishId);
  }

  /// Spend pearls to directly unlock a fish in Eco-Tank
  Future<bool> buyFishWithPearls(String fishId, int pearlCost) async {
    if (unlockedFish.contains(fishId)) return false;
    if (pearlCost > 0 && !spendPearls(pearlCost)) return false;
    await addFishInstance(fishId);
    return true;
  }

  // --- ECO-TANK PER-FISH FEEDING (3H SATIETY & 6H GOLD PAYOUT) ---

  /// Fixed gold reward for a specific fish after 6 hours
  int getFishGoldValue(String fishId) {
    return FishItem.getById(fishId).goldReward;
  }

  /// Total gold reward if all currently unlocked fish are fed
  double get totalFishGoldPerHour {
    double total = 0;
    for (final id in unlockedFish) {
      total += getFishGoldValue(id);
    }
    return total;
  }

  /// Whether this specific fish has an active 6-hour feeding cycle
  bool isFishProducing(String fishId) {
    return (fishFedTimestamps[fishId] ?? 0) > 0;
  }

  /// Whether this specific fish is in its 3-hour satiety cooldown (cannot eat)
  bool isFishInSatietyCooldown(String fishId) {
    final fedAt = fishFedTimestamps[fishId] ?? 0;
    if (fedAt <= 0) return false;
    final elapsed = DateTime.now().millisecondsSinceEpoch - fedAt;
    return elapsed >= 0 && elapsed < fishSatietyDurationMs;
  }

  /// Whether this specific fish has completed its 6-hour cycle and its gold is ready
  bool isFishGoldReady(String fishId) {
    final fedAt = fishFedTimestamps[fishId] ?? 0;
    if (fedAt <= 0) return false;
    final elapsed = DateTime.now().millisecondsSinceEpoch - fedAt;
    return elapsed >= fishPayoutDurationMs;
  }

  /// Milliseconds remaining until this specific fish's 6-hour gold is ready
  int remainingFishPayoutMs(String fishId) {
    final fedAt = fishFedTimestamps[fishId] ?? 0;
    if (fedAt <= 0) return 0;
    final elapsed = DateTime.now().millisecondsSinceEpoch - fedAt;
    final remaining = fishPayoutDurationMs - elapsed;
    return remaining > 0 ? remaining : 0;
  }

  /// Milliseconds remaining in this specific fish's 3-hour satiety cooldown
  int remainingFishSatietyMs(String fishId) {
    final fedAt = fishFedTimestamps[fishId] ?? 0;
    if (fedAt <= 0) return 0;
    final elapsed = DateTime.now().millisecondsSinceEpoch - fedAt;
    final remaining = fishSatietyDurationMs - elapsed;
    return remaining > 0 ? remaining : 0;
  }

  /// Care state of one fish (see [FishCareState]).
  FishCareState fishCareState(String fishId) {
    if (isFishGoldReady(fishId)) return FishCareState.ready;
    if (isFishProducing(fishId)) return FishCareState.producing;
    return FishCareState.waiting;
  }

  /// Fish whose gold is ready to collect from the hoard chest.
  int get readyFishCount =>
      unlockedFish.where((id) => fishCareState(id) == FishCareState.ready).length;

  /// Fish fed and still inside their 6-hour production cycle.
  int get producingFishCount =>
      unlockedFish.where((id) => fishCareState(id) == FishCareState.producing).length;

  /// Fish not in any cycle; feeding one of these starts its production.
  int get waitingFishCount =>
      unlockedFish.where((id) => fishCareState(id) == FishCareState.waiting).length;

  /// True while at least one fish would actually benefit from a pellet.
  bool get hasWaitingFish => waitingFishCount > 0;

  /// Number of fish currently fed (in 6-hour cycle or ready to claim)
  int get fedFishCount {
    int count = 0;
    for (final id in unlockedFish) {
      if (isFishProducing(id)) count++;
    }
    return count;
  }

  /// Total gold that will be earned by all currently fed fish once their 6 hours finish
  int get pendingFishGold {
    int total = 0;
    for (final id in unlockedFish) {
      if (isFishProducing(id)) {
        total += getFishGoldValue(id);
      }
    }
    return total;
  }

  /// Milliseconds remaining until the next fed fish finishes its 6-hour cycle
  int get remainingFedDurationMs {
    int? minRemaining;
    for (final id in unlockedFish) {
      if (isFishProducing(id) && !isFishGoldReady(id)) {
        final rem = remainingFishPayoutMs(id);
        if (rem > 0 && (minRemaining == null || rem < minRemaining)) {
          minRemaining = rem;
        }
      }
    }
    return minRemaining ?? 0;
  }

  bool get isFishFed => fedFishCount > 0;

  /// Never emit hunger warning signals ("Balıklar aç diye sinyal vermesin")
  bool get isFishHungry => false;

  /// Gold ready to be paid out (only from fish that were fed >= 6 hours ago)
  int get currentAvailableFishGold {
    int total = 0;
    for (final id in unlockedFish) {
      if (isFishGoldReady(id)) {
        total += getFishGoldValue(id);
      }
    }
    return total;
  }

  /// Called when a specific fish eats a food pellet.
  /// - If the fish ate within the last 3 hours, it cannot eat (returns false).
  /// - If the fish is not currently in a 6h cycle, starts its 6h gold timer and 3h satiety cooldown.
  /// - If the fish is between 3h and 6h, it eats freely without changing its 6h timer or payout!
  Future<bool> onFishAtePellet(String fishId) async {
    if (isFishInSatietyCooldown(fishId)) {
      return false;
    }

    final existingStart = fishFedTimestamps[fishId] ?? 0;
    if (existingStart <= 0) {
      final now = DateTime.now().millisecondsSinceEpoch;
      fishFedTimestamps[fishId] = now;
      lastFishFedTimestamp = now;
      await _prefs?.setString('fishFedTimestamps', jsonEncode(fishFedTimestamps));
      await _prefs?.setInt('lastFishFedTimestamp', lastFishFedTimestamp);
    }

    recordFishFedQuest();
    final fedDay = DateTime.now().toIso8601String().substring(0, 10);
    if (lastFishFedDay != fedDay) {
      lastFishFedDay = fedDay;
      _prefs?.setString('lastFishFedDay', fedDay);
    }
    notifyListeners();
    return true;
  }

  /// Feeds a single eligible fish (prioritizing unfed fish, then fish past 3h cooldown).
  /// Consumes 1 food pellet. Returns false if no food or all fish are in their 3h satiety window.
  Future<bool> feedFish([String? targetFishId]) async {
    if (fishFood <= 0) return false;

    String? chosenId = targetFishId;
    if (chosenId != null) {
      if (isFishInSatietyCooldown(chosenId)) return false;
    } else {
      // 1st priority: unfed fish
      for (final id in unlockedFish) {
        if (!isFishProducing(id)) {
          chosenId = id;
          break;
        }
      }
      // 2nd priority: fish whose 3-hour satiety cooldown has expired
      if (chosenId == null) {
        for (final id in unlockedFish) {
          if (!isFishInSatietyCooldown(id)) {
            chosenId = id;
            break;
          }
        }
      }
    }

    if (chosenId == null) return false;

    fishFood--;
    await _prefs?.setInt('fishFood', fishFood);
    await onFishAtePellet(chosenId);
    return true;
  }

  /// Feeds all currently waiting (unfed) fish in one batch, up to available fishFood.
  Future<int> feedAllWaitingFish() async {
    int fed = 0;
    for (final id in List<String>.from(unlockedFish)) {
      if (fishFood <= 0) break;
      if (!isFishProducing(id)) {
        final ok = await feedFish(id);
        if (ok) fed++;
      }
    }
    return fed;
  }

  /// Pays out all fish that have completed their 6-hour cycle and resets their timers
  Future<int> collectFishGold() async {
    int goldToCollect = 0;
    bool anyCollected = false;

    for (final id in unlockedFish) {
      if (isFishGoldReady(id)) {
        goldToCollect += getFishGoldValue(id);
        fishFedTimestamps.remove(id);
        anyCollected = true;
      }
    }

    if (!anyCollected || goldToCollect <= 0) return 0;

    await addGold(goldToCollect);
    await _prefs?.setString('fishFedTimestamps', jsonEncode(fishFedTimestamps));
    if (fishFedTimestamps.isEmpty) {
      lastFishFedTimestamp = 0;
      await _prefs?.setInt('lastFishFedTimestamp', 0);
    }
    notifyListeners();
    return goldToCollect;
  }

  Future<void> addFishFood(int count) async {
    fishFood += count;
    await _prefs?.setInt('fishFood', fishFood);
    notifyListeners();
  }

  /// First broken brick teaches the aquarium link. After that, every 8th brick drops one pellet.
  /// Drops pause once the pantry is full so the shop still matters.
  String? grantFoodFromBrick() {
    if (fishFood >= 24) return null;
    if (!seenFoodLink) {
      seenFoodLink = true;
      bricksUntilFood = 8;
      fishFood += 1;
      _prefs?.setBool('seenFoodLink', true);
      _prefs?.setInt('bricksUntilFood', bricksUntilFood);
      _prefs?.setInt('fishFood', fishFood);
      notifyListeners();
      return 'food_to_tank';
    }
    bricksUntilFood -= 1;
    if (bricksUntilFood > 0) {
      _prefs?.setInt('bricksUntilFood', bricksUntilFood);
      return null;
    }
    bricksUntilFood = 8;
    fishFood += 1;
    _prefs?.setInt('bricksUntilFood', bricksUntilFood);
    _prefs?.setInt('fishFood', fishFood);
    notifyListeners();
    return 'food_drop';
  }

  void noteAppOpen() {
    final today = DateTime.now().toIso8601String().substring(0, 10);
    metricSessions += 1;
    metricFirstDay ??= today;
    if (metricFirstDay != today) metricDay2 = true;
    metricLastDay = today;
    _prefs?.setInt('metricSessions', metricSessions);
    _prefs?.setString('metricFirstDay', metricFirstDay!);
    _prefs?.setString('metricLastDay', today);
    _prefs?.setBool('metricDay2', metricDay2);
  }

  void noteLevel1Left() {
    metricLevel1Leaves += 1;
    _prefs?.setInt('metricLevel1Leaves', metricLevel1Leaves);
    _notePlayEvent('leave', classicSavedLevel ?? 1);
  }

  void noteAdClosed() {
    metricAdCloses += 1;
    _prefs?.setInt('metricAdCloses', metricAdCloses);
    _notePlayEvent('ad', metricHighestClassicLevel);
  }

  void noteClassicProgress(int level) {
    final stored = _prefs?.getInt('metricHighestClassicLevel');
    if (stored == null) {
      metricHighestClassicLevel = level;
      _prefs?.setInt('metricHighestClassicLevel', level);
      _notePlayEvent('level', level);
      return;
    }
    if (level <= metricHighestClassicLevel) return;
    metricHighestClassicLevel = level;
    _prefs?.setInt('metricHighestClassicLevel', level);
    _notePlayEvent('level', level);
  }

  /// 14 Sektörden kilidi açılmış en yüksek sektör indeksi (1..14)
  int get highestUnlockedSector {
    return SectorData.getSectorForLevel(metricHighestClassicLevel).sectorIndex;
  }

  /// Belirli bir sektörün kilidi açılmış mı?
  bool isSectorUnlocked(int sectorIndex) {
    if (sectorIndex <= 1) return true;
    return sectorIndex <= highestUnlockedSector;
  }

  /// Sektörün başlangıç checkpoint seviyesini döner
  int getSectorCheckpoint(int sectorIndex) {
    if (sectorIndex <= 1) return 1;
    final idx = sectorIndex - 1;
    if (idx >= SectorData.allSectors.length) {
      return SectorData.allSectors.last.startLevel;
    }
    return SectorData.allSectors[idx].startLevel;
  }

  void markDayBlessed(String day) {
    dayBlessingDate = day;
    _prefs?.setString('dayBlessingDate', day);
  }

  void markFreeContinueUsed() {
    if (usedFreeContinue) return;
    usedFreeContinue = true;
    _prefs?.setBool('usedFreeContinue', true);
  }

  void _notePlayEvent(String kind, int level) {
    final day = DateTime.now().toIso8601String().substring(0, 10);
    playEvents.add('$day|$kind|$level');
    if (playEvents.length > 40) {
      playEvents = playEvents.sublist(playEvents.length - 40);
    }
    _prefs?.setStringList('playEvents', playEvents);
  }

  void markFirstShotSeen() {
    if (seenFirstShot) return;
    seenFirstShot = true;
    _prefs?.setBool('seenFirstShot', true);
  }

  bool hasSeenTip(String tipId) => seenTips.contains(tipId);

  void markTipSeen(String tipId) {
    if (seenTips.add(tipId)) {
      _prefs?.setStringList('seenTips', seenTips.toList());
      notifyListeners();
    }
  }

  bool get hasCompletedMainMenuTour => _prefs?.getBool('hasCompletedMainMenuTour') ?? false;
  set hasCompletedMainMenuTour(bool val) {
    _prefs?.setBool('hasCompletedMainMenuTour', val);
    notifyListeners();
  }

  bool get hasSeenAquariumCatalogTutorial => _prefs?.getBool('hasSeenAquariumCatalogTutorial') ?? false;
  set hasSeenAquariumCatalogTutorial(bool val) {
    _prefs?.setBool('hasSeenAquariumCatalogTutorial', val);
    notifyListeners();
  }

  void completeAquariumCatalogTutorial() {
    hasSeenAquariumCatalogTutorial = true;
  }

  /// Directly saves fishFood to persistent storage and notifies listeners
  void saveFishFoodDirectly() {
    _prefs?.setInt('fishFood', fishFood);
    notifyListeners();
  }

  /// Consumes 1 food pellet for tap feeding. Returns true if successful.
  bool consumeFishFoodOne() {
    if (fishFood <= 0) return false;
    fishFood--;
    saveFishFoodDirectly();
    return true;
  }

  Future<bool> buyFishFoodWithGold({int count = 2, int cost = 80}) async {
    if (gold < cost) return false;
    await spendGold(cost);
    await addFishFood(count);
    return true;
  }

  bool get canClaimDailyFishFoodAd {
    final today = DateTime.now().toIso8601String().substring(0, 10);
    return lastDailyFishFoodAdDate != today;
  }

  Future<bool> recordDailyFishFoodAdClaimed() async {
    final today = DateTime.now().toIso8601String().substring(0, 10);
    if (lastDailyFishFoodAdDate == today) return false;
    lastDailyFishFoodAdDate = today;
    await _prefs?.setString('lastDailyFishFoodAdDate', today);
    notifyListeners();
    return true;
  }

  // --- 7-DAY LOGIN STREAK REWARDS ---

  bool canClaimDaily() => canClaimDailyLogin();

  bool canClaimDailyLogin() {
    final today = DateTime.now().toIso8601String().substring(0, 10);
    return lastDailyLoginClaimDate != today;
  }

  bool canClaimDailyLoginAd() {
    final today = DateTime.now().toIso8601String().substring(0, 10);
    return lastDailyLoginAdClaimDate != today;
  }

  int get currentDailyLoginDay {
    if (canClaimDailyLogin()) {
      return dailyLoginStreak.clamp(1, 7);
    }
    return dailyLoginClaimedDay.clamp(1, 7);
  }

  int getBaseGoldForDailyDay(int day) {
    switch (day) {
      case 1:
        return 50;
      case 2:
        return 100;
      case 3:
        return 150;
      case 4:
        return 200;
      case 5:
        return 300;
      case 6:
        return 400;
      case 7:
        return 600;
      default:
        return 50;
    }
  }

  Future<int> claimDailyReward() async {
    final result = await claimDailyLoginReward();
    return result['gold'] as int? ?? 0;
  }

  /// Claims today's 7-Day login reward. Supports optional 2X reward on video ad.
  Future<Map<String, dynamic>> claimDailyLoginReward({bool doubleWithAd = false}) async {
    if (!canClaimDailyLogin()) return {'claimed': false};
    final today = DateTime.now().toIso8601String().substring(0, 10);
    lastDailyLoginClaimDate = today;
    lastDailyClaimDate = today;
    await _prefs?.setString('lastDailyLoginClaimDate', today);
    await _prefs?.setString('lastDailyClaimDate', today);

    int currentDay = dailyLoginStreak.clamp(1, 7);
    dailyLoginClaimedDay = currentDay;
    await _prefs?.setInt('dailyLoginClaimedDay', dailyLoginClaimedDay);

    if (doubleWithAd) {
      lastDailyLoginAdClaimDate = today;
      await _prefs?.setString('lastDailyLoginAdClaimDate', today);
    }

    int baseGold = getBaseGoldForDailyDay(currentDay);
    int foodReward = 0;
    String? bonusItem;

    switch (currentDay) {
      case 1:
        baseGold = 50;
        break;
      case 2:
        baseGold = 100;
        foodReward = 2;
        break;
      case 3:
        baseGold = 150;
        bonusItem = 'shard_balls';
        await addShard('balls', 1);
        break;
      case 4:
        baseGold = 200;
        bonusItem = 'boost_life';
        await addBoostStock('life', 1);
        break;
      case 5:
        baseGold = 300;
        bonusItem = 'shard_paddles';
        await addShard('paddles', 1);
        break;
      case 6:
        baseGold = 400;
        foodReward = 3;
        break;
      case 7:
        baseGold = 600;
        bonusItem = 'legendary_shard';
        await addShard('trails', 2);
        break;
    }

    if (foodReward > 0) {
      await addFishFood(foodReward);
    }

    final totalGold = doubleWithAd ? (baseGold * 2) : baseGold;
    await addGold(totalGold);

    dailyStreak++;
    dailyLoginStreak = (currentDay >= 7) ? 1 : (currentDay + 1);
    await _prefs?.setInt('dailyStreak', dailyStreak);
    await _prefs?.setInt('dailyLoginStreak', dailyLoginStreak);

    notifyListeners();
    return {
      'claimed': true,
      'day': currentDay,
      'gold': totalGold,
      'food': foodReward,
      'bonusItem': bonusItem,
      'isDoubled': doubleWithAd,
    };
  }

  /// Claims the 2X ad bonus for today after base reward has ALREADY been collected.
  /// Awards that day's base gold amount ("o gün kaçıncı gündeysek o kadar para versin 2 katını değil").
  Future<Map<String, dynamic>> claimDailyLoginAdBonus() async {
    if (!canClaimDailyLoginAd()) return {'claimed': false};
    final today = DateTime.now().toIso8601String().substring(0, 10);
    lastDailyLoginAdClaimDate = today;
    await _prefs?.setString('lastDailyLoginAdClaimDate', today);

    // If base hasn't been claimed today yet, claim both together
    if (canClaimDailyLogin()) {
      return claimDailyLoginReward(doubleWithAd: true);
    }

    final day = dailyLoginClaimedDay.clamp(1, 7);
    final bonusGold = getBaseGoldForDailyDay(day);
    await addGold(bonusGold);

    notifyListeners();
    return {
      'claimed': true,
      'day': day,
      'gold': bonusGold,
      'isDoubled': true,
    };
  }

  // --- FORTUNE WHEEL (5 SPINS PER DAY) ---

  int get remainingWheelSpins {
    final today = DateTime.now().toIso8601String().substring(0, 10);
    if (lastFortuneWheelDate != today) {
      return maxDailyWheelSpins;
    }
    return (maxDailyWheelSpins - fortuneWheelSpinsToday).clamp(0, maxDailyWheelSpins);
  }

  bool get canSpinFortuneWheel => remainingWheelSpins > 0;

  bool get isNextWheelSpinFree {
    if (!canSpinFortuneWheel) return false;
    final today = DateTime.now().toIso8601String().substring(0, 10);
    if (lastFortuneWheelDate != today) {
      return true;
    }
    return fortuneWheelSpinsToday == 0;
  }

  Future<bool> recordWheelSpin() async {
    final today = DateTime.now().toIso8601String().substring(0, 10);
    if (lastFortuneWheelDate != today) {
      lastFortuneWheelDate = today;
      fortuneWheelSpinsToday = 0;
    }
    if (fortuneWheelSpinsToday >= maxDailyWheelSpins) {
      return false;
    }
    fortuneWheelSpinsToday++;
    await _prefs?.setString('lastFortuneWheelDate', today);
    await _prefs?.setInt('fortuneWheelSpinsToday', fortuneWheelSpinsToday);
    notifyListeners();
    return true;
  }

  // --- DAILY QUESTS ---

  void _checkAndResetQuests() {
    final today = DateTime.now().toIso8601String().substring(0, 10);
    if (currentQuestDate != today) {
      currentQuestDate = today;
      questBricksBroken = 0;
      questFishFed = false;
      questAdOrWinDone = false;
      questZenSeconds = 0;
      questShapesClears = 0;
      questDescendRows = 0;
      claimedQuests = {};
      _prefs?.setString('currentQuestDate', today);
      _prefs?.setInt('questBricksBroken', 0);
      _prefs?.setBool('questFishFed', false);
      _prefs?.setBool('questAdOrWinDone', false);
      _prefs?.setInt('questZenSeconds', 0);
      _prefs?.setInt('questShapesClears', 0);
      _prefs?.setInt('questDescendRows', 0);
      _prefs?.setStringList('claimedQuests', []);
    }
  }

  void recordBrickBrokenQuest([int count = 1]) {
    _checkAndResetQuests();
    questBricksBroken += count;
    _prefs?.setInt('questBricksBroken', questBricksBroken);
    notifyListeners();
  }

  void recordFishFedQuest() {
    _checkAndResetQuests();
    questFishFed = true;
    _prefs?.setBool('questFishFed', true);
    notifyListeners();
  }

  void recordAdOrWinQuest() {
    _checkAndResetQuests();
    questAdOrWinDone = true;
    _prefs?.setBool('questAdOrWinDone', true);
    notifyListeners();
  }

  void addQuestZenSeconds(int seconds) {
    if (seconds <= 0) return;
    _checkAndResetQuests();
    questZenSeconds += seconds;
    _prefs?.setInt('questZenSeconds', questZenSeconds);
    notifyListeners();
  }

  void recordShapesClearQuest() {
    _checkAndResetQuests();
    questShapesClears++;
    _prefs?.setInt('questShapesClears', questShapesClears);
    notifyListeners();
  }

  void recordDescendRowQuest() {
    _checkAndResetQuests();
    questDescendRows++;
    _prefs?.setInt('questDescendRows', questDescendRows);
    notifyListeners();
  }

  Future<int> claimQuestReward(String questId) async {
    _checkAndResetQuests();
    if (claimedQuests.contains(questId)) return 0;
    int reward = 0;
    bool grantFood = false;
    if (questId == 'feed_fish' && questFishFed) {
      reward = 60;
      grantFood = true;
    } else if (questId == 'break_bricks' && questBricksBroken >= 100) {
      reward = 120;
    } else if (questId == 'ad_or_win' && questAdOrWinDone) {
      reward = 150;
    } else if (questId == 'zen_time' && questZenSeconds >= 600) {
      reward = 80;
    } else if (questId == 'shapes_clear' && questShapesClears >= 1) {
      reward = 100;
    } else if (questId == 'descend_rows' && questDescendRows >= 10) {
      reward = 90;
    }

    if (reward > 0) {
      // Synchronously register claim before any await to eliminate async gap race conditions
      if (!claimedQuests.add(questId)) return 0;
      if (grantFood) {
        await addFishFood(1);
      }
      await _prefs?.setStringList('claimedQuests', claimedQuests.toList());
      await addGold(reward);
      notifyListeners();
    }
    return reward;
  }

  int get claimableQuestsCount {
    _checkAndResetQuests();
    int count = 0;
    if (!claimedQuests.contains('feed_fish') && questFishFed) count++;
    if (!claimedQuests.contains('break_bricks') && questBricksBroken >= 100) count++;
    if (!claimedQuests.contains('ad_or_win') && questAdOrWinDone) count++;
    if (!claimedQuests.contains('zen_time') && questZenSeconds >= 600) count++;
    if (!claimedQuests.contains('shapes_clear') && questShapesClears >= 1) count++;
    if (!claimedQuests.contains('descend_rows') && questDescendRows >= 10) count++;
    return count;
  }

  bool get hasClaimableQuests => claimableQuestsCount > 0;

  Future<void> setSpeed(SpeedSetting s) async {
    speed = s;
    await _prefs?.setInt('speedSetting', s.index);
    notifyListeners();
  }

  Future<void> setSfx(bool val) async {
    sfxEnabled = val;
    await _prefs?.setBool('sfxEnabled', val);
    notifyListeners();
  }

  Future<void> setHapticIntensity(HapticIntensity val) async {
    hapticIntensity = val;
    hapticsEnabled = val != HapticIntensity.off;
    await _prefs?.setInt('hapticIntensity', val.index);
    await _prefs?.setBool('hapticsEnabled', hapticsEnabled);
    notifyListeners();
  }

  Future<void> setHaptics(bool val) async {
    hapticsEnabled = val;
    hapticIntensity = val ? HapticIntensity.strong : HapticIntensity.off;
    await _prefs?.setBool('hapticsEnabled', val);
    await _prefs?.setInt('hapticIntensity', hapticIntensity.index);
    notifyListeners();
  }

  Future<void> setLanguage(String lang) async {
    language = lang;
    await _prefs?.setString('language', lang);
    notifyListeners();
  }

  Future<bool> unlockBackground(String id, int cost) async {
    if (unlockedBackgrounds.contains(id)) return true;
    if (cost > 0 && gold < cost) return false;
    await spendGold(cost);
    unlockedBackgrounds.add(id);
    await _prefs?.setStringList('unlockedBackgrounds', unlockedBackgrounds.toList());
    notifyListeners();
    return true;
  }

  Future<void> selectBackground(String id) async {
    if (id == 'random' || unlockedBackgrounds.contains(id)) {
      activeBackground = id;
      await _prefs?.setString('activeBackground', id);
      notifyListeners();
    }
  }

  Future<void> unlockBrickStyle(String id) async {
    unlockedBrickStyles.add(id);
    await _prefs?.setStringList('unlockedBrickStyles', unlockedBrickStyles.toList());
    notifyListeners();
  }

  Future<void> equipBrickStyle(String id) async {
    activeBrickStyle = id;
    await _prefs?.setString('activeBrickStyle', id);
    notifyListeners();
  }

  Future<void> setBgmVolume(int level) async {
    bgmVolume = level.clamp(0, 8);
    await _prefs?.setInt('bgmVolume', bgmVolume);
    notifyListeners();
  }

  Future<void> setSfxVolume(int level) async {
    sfxVolume = level.clamp(0, 8);
    sfxEnabled = sfxVolume > 0;
    await _prefs?.setInt('sfxVolume', sfxVolume);
    await _prefs?.setBool('sfxEnabled', sfxEnabled);
    notifyListeners();
  }

  Future<void> setVibrationLevel(int level) async {
    vibrationLevel = level.clamp(0, 8);
    await _prefs?.setInt('vibrationLevel', vibrationLevel);
    notifyListeners();
  }

  Future<void> setPaddleVolume(int level) async {
    paddleVolume = level.clamp(0, 8);
    await _prefs?.setInt('paddleVolume', paddleVolume);
    notifyListeners();
  }

  Future<void> setBallVolume(int level) async {
    ballVolume = level.clamp(0, 8);
    await _prefs?.setInt('ballVolume', ballVolume);
    notifyListeners();
  }

  Future<void> setBrickVolume(int level) async {
    brickVolume = level.clamp(0, 8);
    await _prefs?.setInt('brickVolume', brickVolume);
    notifyListeners();
  }

  // --- PERMANENT RELIC (KALICI YADİGAR: MİDAS'IN MİKRO ÇEKİMİ) ---
  Future<bool> buyPermanentRelic({int cost = 25000}) async {
    if (hasPermanentRelic) return true;
    if (gold < cost) return false;
    final success = await spendGold(cost);
    if (!success) return false;
    hasPermanentRelic = true;
    await _prefs?.setBool('hasPermanentRelic', true);
    notifyListeners();
    return true;
  }

  Future<void> setActiveRelicStyle(String style) async {
    if (activeRelicStyle == style) return;
    activeRelicStyle = style;
    await _prefs?.setString('activeRelicStyle', style);
    notifyListeners();
  }

  bool get shouldOfferRemoveAds =>
      !adsRemoved && !removeAdsOfferSeen && metricHighestClassicLevel >= 100;

  Future<void> grantRemoveAds() async {
    if (adsRemoved) return;
    adsRemoved = true;
    await _prefs?.setBool('adsRemoved', true);
    notifyListeners();
  }

  Future<void> markRemoveAdsOfferSeen() async {
    if (removeAdsOfferSeen) return;
    removeAdsOfferSeen = true;
    await _prefs?.setBool('removeAdsOfferSeen', true);
  }

  // --- SAVED PROGRESSION (DEVAM ET - KLASİK & KAOS) ---
  bool hasSavedGame(GameMode mode) {
    if (mode == GameMode.classic) {
      return (classicSavedLevel != null && classicSavedLevel! > 1) ||
          (classicSavedLevel == 1 && (classicSavedScore ?? 0) > 0);
    } else if (mode == GameMode.chaos) {
      return (chaosSavedLevel != null && chaosSavedLevel! > 1) ||
          (chaosSavedLevel == 1 && (chaosSavedScore ?? 0) > 0);
    }
    return false;
  }

  String get progressCode {
    final level = classicSavedLevel ?? metricHighestClassicLevel;
    return 'KT1|$metricHighestClassicLevel|$level|$gold|$fishFood';
  }

  Future<bool> applyProgressCode(String raw) async {
    final parts = raw.trim().split('|');
    if (parts.length != 5 || parts[0] != 'KT1') return false;
    final highest = int.tryParse(parts[1]);
    final level = int.tryParse(parts[2]);
    final nextGold = int.tryParse(parts[3]);
    final food = int.tryParse(parts[4]);
    if (highest == null || level == null || nextGold == null || food == null) return false;
    if (highest < 1 || highest > 238 || level < 1 || level > 238) return false;
    if (nextGold < 0 || nextGold > 2000000 || food < 0 || food > 99) return false;
    metricHighestClassicLevel = highest;
    gold = nextGold;
    fishFood = food;
    await _prefs?.setInt('metricHighestClassicLevel', highest);
    await _prefs?.setInt('gold', gold);
    await _prefs?.setInt('fishFood', fishFood);
    await saveClassicSession(level: level, score: 0, lives: 3);
    return true;
  }

  Future<void> saveClassicSession({
    required int level,
    required int score,
    required int lives,
  }) async {
    classicSavedLevel = level;
    classicSavedScore = score;
    classicSavedLives = lives;
    await _prefs?.setInt('classicSavedLevel', level);
    await _prefs?.setInt('classicSavedScore', score);
    await _prefs?.setInt('classicSavedLives', lives);
    notifyListeners();
  }

  Future<void> clearClassicSession() async {
    classicSavedLevel = null;
    classicSavedScore = null;
    classicSavedLives = null;
    await _prefs?.remove('classicSavedLevel');
    await _prefs?.remove('classicSavedScore');
    await _prefs?.remove('classicSavedLives');
    notifyListeners();
  }

  Future<void> saveChaosSession({
    required int level,
    required int score,
    required int stock,
  }) async {
    chaosSavedLevel = level;
    chaosSavedScore = score;
    chaosSavedStock = stock;
    await _prefs?.setInt('chaosSavedLevel', level);
    await _prefs?.setInt('chaosSavedScore', score);
    await _prefs?.setInt('chaosSavedStock', stock);
    notifyListeners();
  }

  Future<void> clearChaosSession() async {
    chaosSavedLevel = null;
    chaosSavedScore = null;
    chaosSavedStock = null;
    await _prefs?.remove('chaosSavedLevel');
    await _prefs?.remove('chaosSavedScore');
    await _prefs?.remove('chaosSavedStock');
    notifyListeners();
  }
}
