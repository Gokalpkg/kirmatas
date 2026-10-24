import 'package:flutter/material.dart';

import '../engine/play_games_manager.dart';
import '../models/game_state.dart';
import '../storage/save_manager.dart';
import 'kaunos_ui.dart';

/// Personal stats sheet: lifetime counters, hardest levels, chaos rank
/// and the Google Play Games sign-in / cloud-save controls.
class StatsDialog extends StatefulWidget {
  final SaveManager save;

  const StatsDialog({super.key, required this.save});

  static Future<void> show(BuildContext context, {SaveManager? save}) {
    return showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Stats',
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 150),
      pageBuilder: (dialogContext, animation, secondaryAnimation) =>
          StatsDialog(save: save ?? SaveManager.instance),
      transitionBuilder: (ctx, anim, _, child) =>
          FadeTransition(opacity: anim, child: child),
    );
  }

  @override
  State<StatsDialog> createState() => _StatsDialogState();
}

class _StatsDialogState extends State<StatsDialog> {
  final PlayGamesManager _games = PlayGamesManager.instance;
  bool _busy = false;
  String? _feedback;

  SaveManager get save => widget.save;

  static String _fmt(int v) {
    final s = v.toString();
    final buf = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write('.');
      buf.write(s[i]);
    }
    return buf.toString();
  }

  static String _fmtDuration(int seconds) {
    if (seconds < 60) return '$seconds sn';
    final m = seconds ~/ 60;
    if (m < 60) return '$m dk';
    final h = m ~/ 60;
    final rem = m % 60;
    return rem == 0 ? '$h sa' : '$h sa $rem dk';
  }

  Future<void> _run(Future<String> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    final result = await action();
    if (!mounted) return;
    setState(() {
      _busy = false;
      _feedback = result;
    });
  }

  Future<void> _confirmLoad() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xF2101320),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Buluttan Yükle?',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900)),
        content: const Text(
          'Bu cihazdaki ilerlemen buluttaki kayıtla değişecek. Emin misin?',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('VAZGEÇ', style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('YÜKLE',
                style: TextStyle(
                    color: KaunosPalette.goldHighlight,
                    fontWeight: FontWeight.w900)),
          ),
        ],
      ),
    );
    if (ok == true) {
      await _run(() => _games.loadFromCloud(save));
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([save, _games]),
      builder: (context, _) {
        final hardest = save.statDeathsByLevel.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));
        final topHard = hardest.take(5).toList();

        return AlertDialog(
          backgroundColor: const Color(0xF2101320),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: const BorderSide(color: KaunosPalette.crystalBorderStarlight),
          ),
          contentPadding: const EdgeInsets.fromLTRB(20, 16, 20, 14),
          title: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Expanded(
                child: Row(
                  children: [
                    Icon(Icons.bar_chart_rounded,
                        color: KaunosPalette.goldHighlight, size: 22),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'İSTATİSTİKLERİM',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 16,
                          letterSpacing: 1.0,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 4),
              KaunosPressGlow(
                isCircle: true,
                child: IconButton(
                  icon: const Icon(Icons.close_rounded, color: Colors.white70),
                  onPressed: () => Navigator.of(context).pop(),
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ],
          ),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _rankCard(),
                  const SizedBox(height: 14),
                  GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                    childAspectRatio: 2.25,
                    children: [
                      _statCard(Icons.flag_rounded, 'En Yüksek Bölüm', _fmt(save.highestLevel), accentColor: const Color(0xFF00E5FF)),
                      _statCard(Icons.cyclone_rounded, 'Kaos Zirvesi', 'Dalga ${_fmt(save.bestChaosWave)}', accentColor: const Color(0xFFE040FB)),
                      _statCard(Icons.grid_view_rounded, 'Kırılan Tuğla', _fmt(save.statBricksBrokenTotal), accentColor: const Color(0xFFFFD54F)),
                      _statCard(Icons.monetization_on_rounded, 'Kazanılan Altın', _fmt(save.statGoldEarnedTotal), accentColor: const Color(0xFFFFB300)),
                      _statCard(Icons.emoji_events_rounded, 'Bölüm Zaferi', _fmt(save.statTotalClears), accentColor: const Color(0xFF69F0AE)),
                      _statCard(Icons.heart_broken_rounded, 'Toplam Ölüm', _fmt(save.statTotalDeaths), accentColor: const Color(0xFFFF5252)),
                      _statCard(Icons.sports_esports_rounded, 'Toplam Oyun', _fmt(save.statTotalRuns), accentColor: const Color(0xFF81D4FA)),
                      _statCard(Icons.timer_rounded, 'Oyun Süresi', _fmtDuration(save.statPlaySeconds), accentColor: const Color(0xFFB388FF)),
                    ],
                  ),
                  if (topHard.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    const Text(
                      'EN ZORLANDIĞIN BÖLÜMLER',
                      style: TextStyle(
                        color: Color(0xFFFFD54F),
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: 8),
                    for (final e in topHard)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: const Color(0x33FF5252),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                    color: const Color(0x66FF5252)),
                              ),
                              child: Text(
                                'Bölüm ${e.key}',
                                style: const TextStyle(
                                  color: Color(0xFFFF8A80),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                '${e.value} ölüm • '
                                '${save.statClearsByLevel[e.key] ?? 0} zafer',
                                style: const TextStyle(
                                    color: Colors.white70, fontSize: 12),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                  const SizedBox(height: 18),
                  _playGamesCard(),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _rankCard() {
    final tier = save.chaosRankTier;
    const thresholds = [5, 10, 15, 20, 30, 45];
    final isMax = tier >= SaveManager.chaosRankTitles.length - 1;
    final String progressText;
    final double progress;
    if (isMax) {
      progressText = 'En yüksek rütbedesin!';
      progress = 1.0;
    } else {
      final next = thresholds[tier];
      final prev = tier == 0 ? 0 : thresholds[tier - 1];
      progressText =
          'Sonraki rütbe: ${SaveManager.chaosRankTitles[tier + 1]} '
          '(Dalga $next)';
      progress = ((save.bestChaosWave - prev) / (next - prev)).clamp(0.0, 1.0);
    }
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF2A1A3E), Color(0xFF140D24)],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF7E57C2), width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.military_tech_rounded, color: Color(0xFFFFD54F), size: 22),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  save.chaosRankTitle,
                  style: const TextStyle(
                    color: Color(0xFFCE93D8),
                    fontFamily: 'Rajdhani',
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              Text(
                'Dalga ${save.bestChaosWave}',
                style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 7,
              backgroundColor: const Color(0x33FFFFFF),
              valueColor:
                  const AlwaysStoppedAnimation<Color>(Color(0xFFAB47BC)),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            progressText,
            style: const TextStyle(color: Colors.white54, fontSize: 11),
          ),
        ],
      ),
    );
  }

  Widget _statCard(IconData icon, String label, String value, {Color? accentColor}) {
    final col = accentColor ?? const Color(0xFF00E5FF);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [col.withValues(alpha: 0.14), const Color(0x110F172A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: col.withValues(alpha: 0.35), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: col.withValues(alpha: 0.08),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Icon(icon, color: col, size: 15),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label.toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: col.withValues(alpha: 0.9),
                    fontSize: 10.0,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontFamily: 'Rajdhani',
              fontWeight: FontWeight.w900,
              fontSize: 19,
              letterSpacing: 0.5,
              shadows: [
                Shadow(color: Colors.black87, blurRadius: 4, offset: Offset(0, 1)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _playGamesCard() {
    final signedIn = _games.signedIn;
    final last = _games.lastSync;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0D2B1A), Color(0xFF07170E)],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF43A047), width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('🎮', style: TextStyle(fontSize: 18)),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'GOOGLE PLAY GAMES',
                  style: TextStyle(
                    color: Color(0xFFA5D6A7),
                    fontFamily: 'Rajdhani',
                    fontWeight: FontWeight.w900,
                    fontSize: 14,
                    letterSpacing: 0.6,
                  ),
                ),
              ),
              Container(
                width: 9,
                height: 9,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: signedIn
                      ? const Color(0xFF69F0AE)
                      : const Color(0xFF757575),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            signedIn
                ? (_games.playerName ?? 'Oyuncu bağlı')
                : _games.statusText,
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
          if (last != null)
            Text(
              'Son senkron: ${last.day}.${last.month}.${last.year} '
              '${last.hour.toString().padLeft(2, '0')}:'
              '${last.minute.toString().padLeft(2, '0')}',
              style: const TextStyle(color: Colors.white38, fontSize: 11),
            ),
          if (_feedback != null) ...[
            const SizedBox(height: 6),
            Text(
              _feedback!,
              style: const TextStyle(
                color: KaunosPalette.goldHighlight,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
          const SizedBox(height: 10),
          if (!signedIn)
            _gamesButton(
              label: _busy ? 'BAĞLANIYOR...' : 'GOOGLE İLE BAĞLAN',
              icon: Icons.login_rounded,
              onTap: _busy ? null : () => _run(() => _games.signIn()),
            )
          else
            Row(
              children: [
                Expanded(
                  child: _gamesButton(
                    label: 'BULUTA KAYDET',
                    icon: Icons.cloud_upload_rounded,
                    onTap: _busy
                        ? null
                        : () => _run(() => _games.saveToCloud(save)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _gamesButton(
                    label: 'BULUTTAN YÜKLE',
                    icon: Icons.cloud_download_rounded,
                    onTap: _busy ? null : _confirmLoad,
                  ),
                ),
              ],
            ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _gamesButton(
                  label: '🏆 EN YÜKSEK SKOR',
                  icon: Icons.leaderboard_rounded,
                  onTap: _busy ? null : () => _run(() => _games.showLeaderboard(mode: GameMode.classic)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _gamesButton(
                  label: '🌀 KAOS SKOR',
                  icon: Icons.military_tech_rounded,
                  onTap: _busy ? null : () => _run(() => _games.showLeaderboard(mode: GameMode.chaos)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _gamesButton({
    required String label,
    required IconData icon,
    required VoidCallback? onTap,
  }) {
    return KaunosPressGlow(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
          decoration: BoxDecoration(
            color: const Color(0xFF1B5E20),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF66BB6A)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: const Color(0xFFA5D6A7), size: 16),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontFamily: 'Rajdhani',
                    fontWeight: FontWeight.w900,
                    fontSize: 12,
                    letterSpacing: 0.4,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
