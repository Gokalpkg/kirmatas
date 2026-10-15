import 'package:flutter/material.dart';
import '../engine/i18n.dart';
import '../models/cosmetics.dart';
import '../storage/save_manager.dart';
import 'remove_ads_card.dart';

class UpgradesView extends StatelessWidget {
  const UpgradesView({super.key});

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
              icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white70, size: 20),
              onPressed: () => Navigator.of(context).pop(),
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
                margin: const EdgeInsets.only(right: 16, top: 10, bottom: 10),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF1C2234),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0x33FFD54F)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.monetization_on, color: Color(0xFFFFD54F), size: 16),
                    const SizedBox(width: 6),
                    Text(
                      '${save.gold}',
                      style: const TextStyle(
                        color: Color(0xFFFFD54F),
                        fontWeight: FontWeight.w900,
                        fontSize: 14,
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
              // --- SECTION 1: ATTRIBUTE MASTERY (Yetenek Ağacı) ---
              Row(
                children: [
                  const Icon(Icons.bolt_rounded, color: Color(0xFF00E5FF), size: 18),
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
              const SizedBox(height: 12),
              ...StatUpgrade.all.map((stat) {
                final currentLvl = save.getUpgradeLevel(stat.id);
                final isMax = currentLvl >= stat.maxLevel;
                final cost = stat.getCostForLevel(currentLvl);
                final canAfford = !isMax && save.gold >= cost;

                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        stat.color.withValues(alpha: 0.12),
                        const Color(0xFF121522),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(18),
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
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: isMax
                                        ? const Color(0x3369F0AE)
                                        : stat.color.withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: isMax
                                          ? const Color(0xFF69F0AE)
                                          : stat.color.withValues(alpha: 0.5),
                                    ),
                                  ),
                                  child: Text(
                                    isMax ? I18n.tr('max_level') : '${I18n.tr('lvl')} $currentLvl/${stat.maxLevel}',
                                    style: TextStyle(
                                      color: isMax ? const Color(0xFF69F0AE) : stat.color,
                                      fontWeight: FontWeight.w900,
                                      fontSize: 10,
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
                          child: const Icon(Icons.check_rounded, color: Color(0xFF69F0AE), size: 22),
                        )
                      else
                        ElevatedButton(
                          onPressed: canAfford
                              ? () async {
                                  await save.buyStatUpgrade(stat.id, cost);
                                }
                              : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFFFD54F),
                            foregroundColor: Colors.black,
                            disabledBackgroundColor: Colors.white12,
                            disabledForegroundColor: Colors.white30,
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: canAfford ? 3 : 0,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.monetization_on, size: 14, color: Colors.black87),
                              const SizedBox(width: 4),
                              Text(
                                '$cost',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                );
              }),

              const SizedBox(height: 20),

              // --- SECTION 2: PERMANENT RELICS ---
              Row(
                children: [
                  const Icon(Icons.auto_awesome_rounded, color: Color(0xFFFFD54F), size: 18),
                  const SizedBox(width: 6),
                  Text(
                    I18n.tr('permanent_upgrades'),
                    style: const TextStyle(
                      color: Color(0xFFFFD54F),
                      fontWeight: FontWeight.w900,
                      fontSize: 13,
                      letterSpacing: 1.2,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const RemoveAdsCard(),
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
                child: Row(
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
                      child: const Icon(Icons.auto_awesome_rounded, color: Color(0xFFFFD54F), size: 26),
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
              ),

              const SizedBox(height: 20),

              // --- SECTION 3: PRE-MATCH BOOSTS ---
              Row(
                children: [
                  const Icon(Icons.flash_on_rounded, color: Color(0xFFFF4081), size: 18),
                  const SizedBox(width: 6),
                  Text(
                    I18n.tr('pre_match_boosts'),
                    style: const TextStyle(
                      color: Color(0xFFFF4081),
                      fontWeight: FontWeight.w900,
                      fontSize: 13,
                      letterSpacing: 1.2,
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
                            const Icon(Icons.monetization_on, size: 14, color: Colors.black87),
                            const SizedBox(width: 4),
                            Text(
                              '${b.cost}',
                              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ),
        );
      },
    );
  }
}
