import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../engine/audio_manager.dart';
import '../engine/i18n.dart';
import '../models/cosmetics.dart';
import '../models/fish_synergy.dart';
import '../storage/save_manager.dart';
import 'kaunos_ui.dart';

class UpgradesView extends StatefulWidget {
  final VoidCallback? onBackToMenu;
  const UpgradesView({super.key, this.onBackToMenu});

  @override
  State<UpgradesView> createState() => _UpgradesViewState();
}

class _UpgradesViewState extends State<UpgradesView> {
  String? _justUpgradedId;
  int _upgradeSeq = 0;

  @override
  Widget build(BuildContext context) {
    final save = SaveManager.instance;

    return ListenableBuilder(
      listenable: save,
      builder: (context, _) {
        return Scaffold(
          backgroundColor: const Color(0xFF0A0C14),
          appBar: AppBar(
            backgroundColor: const Color(0xFF0F121E),
            elevation: 0,
            leading: IconButton(
              icon: Icon(Icons.arrow_back_ios_new, color: Colors.white70, size: 20),
              onPressed: () {
                if (widget.onBackToMenu != null) {
                  widget.onBackToMenu!();
                } else if (Navigator.of(context).canPop()) {
                  Navigator.of(context).pop();
                }
              },
            ),
            title: Text(
              I18n.tr('upgrades_title'),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.0,
              ),
            ),
            actions: [
              Container(
                margin: const EdgeInsets.only(right: 6, top: 10, bottom: 10),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF22162B),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0x66E040FB)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.lens_blur_rounded, color: Color(0xFFE040FB), size: 15),
                    const SizedBox(width: 4),
                    Text(
                      '${save.pearls}',
                      style: const TextStyle(
                        color: Color(0xFFE040FB),
                        fontWeight: FontWeight.w900,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                margin: const EdgeInsets.only(right: 8, top: 10, bottom: 10),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF1C2234),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0x33FFD54F)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.monetization_on, color: Color(0xFFFFD54F), size: 15),
                    const SizedBox(width: 4),
                    RollingNumberText(
                      value: save.gold,
                      style: const TextStyle(
                        color: Color(0xFFFFD54F),
                        fontWeight: FontWeight.w900,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // --- SECTION 0: ECO-TANK FISH SYNERGIES ---
              Builder(
                builder: (_) {
                  final buffs = FishSynergyBuffs.calculate(save);
                  if (buffs.activeBuffDescriptions.isEmpty) return const SizedBox.shrink();
                  return Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          const Color(0xFF00E5FF).withValues(alpha: 0.15),
                          const Color(0xFF161A28),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: const Color(0xFF00E5FF).withValues(alpha: 0.4),
                        width: 1.2,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.water_drop_rounded, color: Color(0xFF00E5FF), size: 18),
                            const SizedBox(width: 8),
                            const Expanded(
                              child: Text(
                                'Akvaryum Sinerjileri',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: Color(0xFF00E5FF),
                                  fontWeight: FontWeight.w900,
                                  fontSize: 13,
                                  letterSpacing: 0.8,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: const Color(0xFF00E5FF).withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                '${save.unlockedFish.length} Balık',
                                style: const TextStyle(
                                  color: Color(0xFF00E5FF),
                                  fontWeight: FontWeight.w900,
                                  fontSize: 10,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          children: buffs.activeBuffDescriptions.map((desc) {
                            return Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: Colors.black38,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.white12),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.check_circle_rounded, color: Color(0xFF69F0AE), size: 12),
                                  const SizedBox(width: 5),
                                  Text(
                                    desc,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                  );
                },
              ),

              // --- SECTION 1: ATTRIBUTE MASTERY (Yetenek Ağacı) ---
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.bolt_rounded, color: Color(0xFF00E5FF), size: 18),
                      const SizedBox(width: 6),
                      Text(
                        I18n.tr('stat_tree'),
                        style: const TextStyle(
                          color: Color(0xFF00E5FF),
                          fontWeight: FontWeight.w900,
                          fontSize: 13,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ],
                  ),
                  if (save.calculateTotalSpentOnUpgrades() > 0)
                    InkWell(
                      borderRadius: BorderRadius.circular(10),
                      onTap: () => _confirmResetUpgrades(context, save),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: const Color(0x33FF5252),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFFF5252)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.restart_alt_rounded, color: Color(0xFFFF5252), size: 14),
                            const SizedBox(width: 4),
                            Text(
                              'SIFIRLA (+${save.calculateTotalSpentOnUpgrades()})',
                              style: const TextStyle(
                                color: Color(0xFFFF8A80),
                                fontSize: 11,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              ...StatUpgrade.all.map((stat) {
                final currentLvl = save.getUpgradeLevel(stat.id);
                final isMax = currentLvl >= stat.maxLevel;
                final cost = stat.getCostForLevel(currentLvl);
                final canAfford = !isMax && save.gold >= cost;

                final justUpgraded = _justUpgradedId == stat.id;
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        justUpgraded ? const Color(0xFFFFD54F).withValues(alpha: 0.28) : stat.color.withValues(alpha: 0.12),
                        const Color(0xFF121522),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: justUpgraded
                        ? [
                            BoxShadow(
                              color: const Color(0xFFFFB300).withValues(alpha: 0.35),
                              blurRadius: 16,
                              spreadRadius: 1,
                            ),
                          ]
                        : null,
                    border: Border.all(
                      color: isMax
                          ? const Color(0xFF69F0AE).withValues(alpha: 0.6)
                          : stat.color.withValues(alpha: 0.35),
                      width: 1.2,
                    ),
                  ),
                  child: Row(
                    children: [
                      // Icon badge
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: stat.color.withValues(alpha: 0.18),
                          shape: BoxShape.circle,
                          border: Border.all(color: stat.color.withValues(alpha: 0.5)),
                        ),
                        child: Icon(stat.icon, color: stat.color, size: 26),
                      ),
                      const SizedBox(width: 12),
                      // Details
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    I18n.tr(stat.nameKey),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w900,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                                TweenAnimationBuilder<double>(
                                  key: ValueKey('${stat.id}-$currentLvl'),
                                  tween: Tween<double>(begin: 1.45, end: 1.0),
                                  duration: const Duration(milliseconds: 380),
                                  curve: Curves.elasticOut,
                                  builder: (context, scale, child) {
                                    return Transform.scale(scale: scale, child: child);
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: justUpgraded
                                          ? const Color(0x66FFD54F)
                                          : (isMax
                                              ? const Color(0x3369F0AE)
                                              : stat.color.withValues(alpha: 0.2)),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: justUpgraded
                                            ? const Color(0xFFFFD54F)
                                            : (isMax
                                                ? const Color(0xFF69F0AE)
                                                : stat.color.withValues(alpha: 0.5)),
                                      ),
                                    ),
                                    child: Text(
                                      isMax ? I18n.tr('max_level') : '${I18n.tr('lvl')} $currentLvl/${stat.maxLevel}',
                                      style: TextStyle(
                                        color: justUpgraded
                                            ? const Color(0xFFFFD54F)
                                            : (isMax ? const Color(0xFF69F0AE) : stat.color),
                                        fontWeight: FontWeight.w900,
                                        fontSize: 10,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              I18n.tr(stat.descKey),
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 11,
                                height: 1.25,
                              ),
                            ),
                            const SizedBox(height: 8),
                            // 5-segment pip gauge
                            Row(
                              children: List.generate(stat.maxLevel, (index) {
                                final isFilled = index < currentLvl;
                                return Expanded(
                                  child: Container(
                                    height: 5,
                                    margin: EdgeInsets.only(right: index < stat.maxLevel - 1 ? 4 : 0),
                                    decoration: BoxDecoration(
                                      color: isFilled ? stat.color : const Color(0xFF262C3D),
                                      borderRadius: BorderRadius.circular(3),
                                      boxShadow: isFilled
                                          ? [
                                              BoxShadow(
                                                color: stat.color.withValues(alpha: 0.6),
                                                blurRadius: 4,
                                              ),
                                            ]
                                          : null,
                                    ),
                                  ),
                                );
                              }),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Action button
                      if (isMax)
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: const BoxDecoration(
                            color: Color(0x2269F0AE),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(Icons.check_rounded, color: Color(0xFF69F0AE), size: 22),
                        )
                      else
                        _JuiceBuyButton(
                          cost: cost,
                          canAfford: canAfford,
                          onBuy: () async {
                            final before = save.getUpgradeLevel(stat.id);
                            await save.buyStatUpgrade(stat.id, cost);
                            if (!mounted) return;
                            if (save.getUpgradeLevel(stat.id) > before) {
                              setState(() {
                                _justUpgradedId = stat.id;
                                _upgradeSeq++;
                              });
                              final seq = _upgradeSeq;
                              Future.delayed(const Duration(milliseconds: 1500), () {
                                if (mounted && seq == _upgradeSeq) {
                                  setState(() => _justUpgradedId = null);
                                }
                              });
                            }
                          },
                        ),
                    ],
                  ),
                );
              }),

              const SizedBox(height: 20),

              // --- SECTION 2: PERMANENT RELICS ---
              Row(
                children: [
                  Icon(Icons.auto_awesome_rounded, color: Color(0xFFFFD54F), size: 18),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      I18n.tr('permanent_upgrades'),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                      style: const TextStyle(
                        color: Color(0xFFFFD54F),
                        fontWeight: FontWeight.w900,
                        fontSize: 13,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0x33FFD54F), Color(0xFF141724)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: save.hasPermanentRelic ? const Color(0xFFFFD54F) : const Color(0x66FFD54F),
                    width: save.hasPermanentRelic ? 1.8 : 1.2,
                  ),
                  boxShadow: [
                    if (save.hasPermanentRelic)
                      const BoxShadow(color: Color(0x33FFD54F), blurRadius: 14, offset: Offset(0, 4)),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            gradient: const RadialGradient(
                              colors: [Color(0x66FFD54F), Color(0x11FFD54F)],
                            ),
                            shape: BoxShape.circle,
                            border: Border.all(color: const Color(0xFFFFD54F), width: 1.5),
                          ),
                          child: Icon(Icons.auto_awesome_rounded, color: Color(0xFFFFD54F), size: 26),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      I18n.tr('relic_title'),
                                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 14),
                                    ),
                                  ),
                                  if (save.hasPermanentRelic)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: const Color(0x3369F0AE),
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(color: const Color(0xFF69F0AE)),
                                      ),
                                      child: Text(
                                        I18n.tr('relic_owned'),
                                        style: const TextStyle(color: Color(0xFF69F0AE), fontSize: 10, fontWeight: FontWeight.w900),
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                I18n.tr('relic_body'),
                                style: const TextStyle(color: Colors.white70, fontSize: 11, height: 1.3),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        if (!save.hasPermanentRelic)
                          ElevatedButton(
                            onPressed: save.gold >= 25000
                                ? () async {
                                    await save.buyPermanentRelic(cost: 25000);
                                  }
                                : null,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFFFD54F),
                              foregroundColor: Colors.black,
                              disabledBackgroundColor: Colors.white12,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.monetization_on, size: 14, color: Colors.black87),
                                SizedBox(width: 4),
                                Text(
                                  '25.000',
                                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                    if (save.hasPermanentRelic) ...[
                      const SizedBox(height: 12),
                      const Divider(color: Colors.white12, height: 1),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Icon(Icons.stars_rounded, color: Color(0xFFFFD54F), size: 15),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              I18n.tr('relic_loadout_title'),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Color(0xFFFFD54F),
                                fontWeight: FontWeight.w900,
                                fontSize: 11,
                                letterSpacing: 0.6,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          _buildRelicStylePill(
                            context,
                            save: save,
                            id: 'aegis',
                            title: 'Muhafız',
                            desc: '+%8 Raket • %35 Kısa Tuzak',
                            icon: Icons.shield_rounded,
                            color: const Color(0xFF00E5FF),
                          ),
                          _buildRelicStylePill(
                            context,
                            save: save,
                            id: 'overdrive',
                            title: 'Aşırı Yük',
                            desc: '+%6 Hız • +%20 Kombo',
                            icon: Icons.bolt_rounded,
                            color: const Color(0xFFFF9100),
                          ),
                          _buildRelicStylePill(
                            context,
                            save: save,
                            id: 'alchemist',
                            title: 'Simyacı',
                            desc: '+%15 Altın Şansı',
                            icon: Icons.monetization_on_rounded,
                            color: const Color(0xFFFFD700),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // --- SECTION 3: PRE-MATCH BOOSTS ---
              Row(
                children: [
                  Icon(Icons.flash_on_rounded, color: Color(0xFFFF4081), size: 18),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      I18n.tr('pre_match_boosts'),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                      style: const TextStyle(
                        color: Color(0xFFFF4081),
                        fontWeight: FontWeight.w900,
                        fontSize: 13,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ...BoostItem.allBoosts.map((b) {
                final stock = save.boostStocks[b.id] ?? 0;
                final cost = b.cost;
                final canAfford = save.gold >= cost;

                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFF141724),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(
                          color: b.color.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                          border: Border.all(color: b.color.withValues(alpha: 0.5)),
                        ),
                        child: Icon(b.icon, color: b.color, size: 24),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              b.name,
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 14),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              b.description,
                              style: const TextStyle(color: Colors.white60, fontSize: 11),
                            ),
                            const SizedBox(height: 5),
                            Text(
                              '${I18n.tr('stock')}: $stock ${I18n.tr('pcs')}',
                              style: TextStyle(color: b.color, fontSize: 11, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ElevatedButton(
                            onPressed: canAfford
                                ? () async {
                                    final ok = await save.spendGold(cost);
                                    if (ok) {
                                      save.addBoostStock(b.id, 1);
                                    }
                                  }
                                : null,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFFFD54F),
                              foregroundColor: Colors.black,
                              disabledBackgroundColor: Colors.white12,
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.monetization_on, size: 14, color: Colors.black87),
                                const SizedBox(width: 4),
                                Text(
                                  '${b.cost}',
                                  style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                          if (save.gold >= cost * 5) ...[
                            const SizedBox(height: 4),
                            GestureDetector(
                              onTap: () async {
                                final ok = await save.spendGold(cost * 5);
                                if (ok) {
                                  AudioManager.instance.playSfx(GameSfx.powerupBuff);
                                  save.addBoostStock(b.id, 5);
                                }
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: const Color(0x33FFD54F),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: const Color(0x88FFD54F)),
                                ),
                                child: const Text(
                                  'x5 AL',
                                  style: TextStyle(
                                    color: Color(0xFFFFD54F),
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                );
              }),

              const SizedBox(height: 24),
              // --- SECTION 4: COSMIC MASTERY (Sonsuz Seviye) ---
              Row(
                children: const [
                  Icon(Icons.auto_awesome_rounded, color: Color(0xFFE040FB), size: 18),
                  SizedBox(width: 6),
                  Flexible(
                    child: Stack(
                      children: [
                        Opacity(
                          opacity: 0.0,
                          child: Text(
                            'KOZMİK USTALIK (SONSUZ SEVİYE)',
                            style: TextStyle(fontSize: 1),
                          ),
                        ),
                        Text(
                          '🌌 KOZMİK USTALIK (SONSUZ SEVİYE)',
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                          style: TextStyle(
                            color: Color(0xFFE040FB),
                            fontWeight: FontWeight.w900,
                            fontSize: 13,
                            letterSpacing: 1.0,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Card 1: Cosmic Gold Mastery
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xFFFFD54F).withValues(alpha: 0.12),
                      const Color(0xFF141724),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: const Color(0xFFFFD54F).withValues(alpha: 0.35)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFD54F).withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                        border: Border.all(color: const Color(0xFFFFD54F).withValues(alpha: 0.5)),
                      ),
                      child: Icon(Icons.stars_rounded, color: Color(0xFFFFD54F), size: 24),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Flexible(
                                child: Text(
                                  'Kozmik Altın Ustalığı',
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1,
                                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 14),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFFD54F).withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  'Sv. ${save.cosmicGoldMasteryLevel}',
                                  style: const TextStyle(color: Color(0xFFFFD54F), fontSize: 10, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 3),
                          Text(
                            '+${save.cosmicGoldMasteryLevel * 2}% Tuğla/Kritik Hasar & +${save.cosmicGoldMasteryLevel * 2}% Altın Kazancı',
                            style: const TextStyle(color: Colors.white70, fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ElevatedButton(
                          onPressed: save.gold >= save.cosmicGoldMasteryCost
                              ? () {
                                  save.upgradeCosmicGoldMastery();
                                }
                              : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFFFD54F),
                            foregroundColor: Colors.black,
                            disabledBackgroundColor: Colors.white12,
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.monetization_on, size: 14, color: Colors.black87),
                              const SizedBox(width: 3),
                              Text(
                                '${save.cosmicGoldMasteryCost}',
                                style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 11),
                              ),
                            ],
                          ),
                        ),
                        if (save.gold >= save.cosmicGoldMasteryCost * 2) ...[
                          const SizedBox(height: 4),
                          GestureDetector(
                            onTap: () {
                              final n = save.upgradeCosmicGoldMasteryBulk(5);
                              if (n > 0) {
                                AudioManager.instance.playSfx(GameSfx.powerupBuff);
                              }
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: const Color(0x33FFD54F),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: const Color(0x88FFD54F)),
                              ),
                              child: const Text(
                                'x5 BAS',
                                style: TextStyle(
                                  color: Color(0xFFFFD54F),
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),

              // Card 2: Cosmic Pearl Mastery
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xFFE040FB).withValues(alpha: 0.12),
                      const Color(0xFF141724),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: const Color(0xFFE040FB).withValues(alpha: 0.35)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        color: const Color(0xFFE040FB).withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                        border: Border.all(color: const Color(0xFFE040FB).withValues(alpha: 0.5)),
                      ),
                      child: Icon(Icons.all_inclusive_rounded, color: Color(0xFFE040FB), size: 24),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Flexible(
                                child: Text(
                                  'Kozmik İnci Ustalığı',
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1,
                                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 14),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFE040FB).withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  'Sv. ${save.cosmicPearlMasteryLevel}',
                                  style: const TextStyle(color: Color(0xFFE040FB), fontSize: 10, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 3),
                          Text(
                            '+${save.cosmicPearlMasteryLevel * 2}% Ulti Dolum Hızı & +${save.cosmicPearlMasteryLevel}% Şans Bonusu',
                            style: const TextStyle(color: Colors.white70, fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ElevatedButton(
                          onPressed: save.pearls >= save.cosmicPearlMasteryCost
                              ? () {
                                  save.upgradeCosmicPearlMastery();
                                }
                              : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFE040FB),
                            foregroundColor: Colors.white,
                            disabledBackgroundColor: Colors.white12,
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.lens_blur_rounded, size: 14, color: Colors.white),
                              const SizedBox(width: 3),
                              Text(
                                '${save.cosmicPearlMasteryCost}',
                                style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 11),
                              ),
                            ],
                          ),
                        ),
                        if (save.pearls >= save.cosmicPearlMasteryCost * 2) ...[
                          const SizedBox(height: 4),
                          GestureDetector(
                            onTap: () {
                              final n = save.upgradeCosmicPearlMasteryBulk(5);
                              if (n > 0) {
                                AudioManager.instance.playSfx(GameSfx.powerupBuff);
                              }
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: const Color(0x33E040FB),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: const Color(0x88E040FB)),
                              ),
                              child: const Text(
                                'x5 BAS',
                                style: TextStyle(
                                  color: Color(0xFFE040FB),
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildRelicStylePill(
    BuildContext context, {
    required SaveManager save,
    required String id,
    required String title,
    required String desc,
    required IconData icon,
    required Color color,
  }) {
    final isSelected = save.activeRelicStyle == id;
    return InkWell(
      onTap: () => save.setActiveRelicStyle(id),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.16) : const Color(0x22FFFFFF),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? color : Colors.white24,
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: isSelected ? color : Colors.white70),
            const SizedBox(width: 6),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: isSelected ? color : Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 11,
                  ),
                ),
                Text(
                  desc,
                  style: const TextStyle(
                    color: Colors.white60,
                    fontWeight: FontWeight.w500,
                    fontSize: 9.5,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _confirmResetUpgrades(BuildContext context, SaveManager save) {
    final refund = save.calculateTotalSpentOnUpgrades();
    if (refund <= 0) return;
    HapticFeedback.mediumImpact();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF161A28),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: Color(0xFFFF5252), width: 1.5),
        ),
        title: const Row(
          children: [
            Icon(Icons.restart_alt_rounded, color: Color(0xFFFF5252), size: 24),
            SizedBox(width: 8),
            Text(
              'YETENEKLERİ SIFIRLA',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 16,
                letterSpacing: 0.8,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Tüm yetenek ağacı seviyelerin sıfırlanacak ve harcadığın altınların %100\'ü eksiksiz cüzdanına iade edilecek.',
              style: TextStyle(color: Colors.white70, fontSize: 13),
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0x22FFD54F),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFFFD54F)),
              ),
              child: Row(
                children: [
                  Icon(Icons.monetization_on_rounded, color: Color(0xFFFFD54F), size: 22),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('İade Edilecek Altın', style: TextStyle(color: Colors.white60, fontSize: 11)),
                        Text(
                          '+$refund Altın',
                          style: const TextStyle(
                            color: Color(0xFFFFD54F),
                            fontWeight: FontWeight.w900,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('İPTAL', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF5252),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () async {
              Navigator.of(ctx).pop();
              final refunded = await save.resetAllUpgrades();
              AudioManager.instance.playSfx(GameSfx.powerupBuff);
              HapticFeedback.heavyImpact();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    backgroundColor: const Color(0xFF1E2838),
                    content: Text(
                      'Yetenekler sıfırlandı! +$refunded Altın iade edildi.',
                      style: const TextStyle(color: Color(0xFFFFD54F), fontWeight: FontWeight.bold),
                    ),
                  ),
                );
              }
            },
            child: const Text('SIFIRLA VE İADE AL', style: TextStyle(fontWeight: FontWeight.w900)),
          ),
        ],
      ),
    );
  }
}

/// Buy button with a charging-vortex press: the coin icon spins and
/// compresses, the button flashes white on the anvil strike, then the
/// frame keeps a warm breathing aura for a moment.
class _JuiceBuyButton extends StatefulWidget {
  final int cost;
  final bool canAfford;
  final Future<void> Function() onBuy;

  const _JuiceBuyButton({
    required this.cost,
    required this.canAfford,
    required this.onBuy,
  });

  @override
  State<_JuiceBuyButton> createState() => _JuiceBuyButtonState();
}

class _JuiceBuyButtonState extends State<_JuiceBuyButton> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  bool _aura = false;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 480));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _press() async {
    AudioManager.instance.playSfx(GameSfx.steel);
    AudioManager.instance.triggerHaptic(() async => AudioManager.instance.playSfx(GameSfx.click));
    _ctrl.forward(from: 0.0);
    await widget.onBuy();
    if (!mounted) return;
    setState(() => _aura = true);
    Future.delayed(const Duration(milliseconds: 1400), () {
      if (mounted) setState(() => _aura = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, child) {
        final t = _ctrl.value;
        final compress = t < 0.35 ? 1.0 - t * 0.9 : 0.685 + (t - 0.35) * 0.49;
        final flash = t >= 0.35 && t < 0.55 ? 1.0 : 0.0;
        final pressOffset = (t > 0.05 && t < 0.45) ? 2.5 : 0.0;

        return Transform.translate(
          offset: Offset(0, pressOffset),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border(
                bottom: BorderSide(
                  color: widget.canAfford ? const Color(0xFF78350F) : Colors.black45,
                  width: pressOffset > 0 ? 1.0 : 3.5,
                ),
              ),
              boxShadow: _aura
                  ? [
                      BoxShadow(
                        color: const Color(0xFFFFB300).withValues(alpha: 0.45 + 0.2 * (0.5 + 0.5 * (1 - t))),
                        blurRadius: 14,
                        spreadRadius: 1,
                      ),
                    ]
                  : null,
            ),
            child: ElevatedButton(
              onPressed: widget.canAfford ? _press : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: flash > 0 ? Colors.white : const Color(0xFFFFD54F),
                foregroundColor: Colors.black,
                disabledBackgroundColor: Colors.white12,
                disabledForegroundColor: Colors.white30,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Transform.rotate(
                    angle: t * 6.28,
                    child: Transform.scale(
                      scale: compress,
                      child: Icon(Icons.monetization_on, size: 14, color: Colors.black87),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${widget.cost}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
