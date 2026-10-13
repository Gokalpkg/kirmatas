import 'package:flutter/material.dart';
import '../engine/i18n.dart';
import '../models/cosmetics.dart';
import '../storage/save_manager.dart';

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
                    Text( '${save.gold}',
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
              Text(
                I18n.tr('permanent_upgrades'),
                style: const TextStyle(
                  color: Color(0xFFFFD54F),
                  fontWeight: FontWeight.w900,
                  fontSize: 13,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0x33FFD54F), Color(0xFF141724)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(22),
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
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        gradient: const RadialGradient(
                          colors: [Color(0x66FFD54F), Color(0x11FFD54F)],
                        ),
                        shape: BoxShape.circle,
                        border: Border.all(color: const Color(0xFFFFD54F), width: 1.5),
                      ),
                      child: const Icon(Icons.auto_awesome_rounded, color: Color(0xFFFFD54F), size: 30),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Expanded(
                                child: Text(
                                  "Midas'ın Mikro Çekimi",
                                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 15),
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
                                  child: const Text( 'AKTİF',
                                    style: TextStyle(color: Color(0xFF69F0AE), fontSize: 10, fontWeight: FontWeight.w900),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          const Text( 'Kalıcı Lüks Yadigar: Raket yakınındaki kapsülleri çok hafif (mikro) çeker ve bölüm sonlarında +%5 altın bonusu verir. Oyunu çok az etkiler.',
                            style: TextStyle(color: Colors.white70, fontSize: 12, height: 1.3),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            save.hasPermanentRelic ? 'Kalıcı olarak açık • Tek seferlik' : '25.000 Altın • Çok pahalı & Kalıcı',
                            style: TextStyle(
                              color: save.hasPermanentRelic ? const Color(0xFF69F0AE) : const Color(0xFFFFD54F),
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
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
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        ),
                        child: const Text( '25.000 ',
                          style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Text(
                I18n.tr('pre_match_boosts'),
                style: const TextStyle(
                  color: Color(0xFF00E5FF),
                  fontWeight: FontWeight.w900,
                  fontSize: 13,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 12),
              ...BoostItem.allBoosts.map((b) {
                final stock = save.boostStocks[b.id] ?? 0;
                final cost = b.cost;
                final canAfford = save.gold >= cost;

                return Container(
                  margin: const EdgeInsets.only(bottom: 14),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF141724),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          color: b.color.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                          border: Border.all(color: b.color.withValues(alpha: 0.5)),
                        ),
                        child: Icon(b.icon, color: b.color, size: 28),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              b.name,
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 15),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              b.description,
                              style: const TextStyle(color: Colors.white60, fontSize: 12),
                            ),
                            const SizedBox(height: 6),
                            Text( '${I18n.tr('stock')}: $stock ${I18n.tr('pcs')}',
                              style: TextStyle(color: b.color, fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
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
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        child: Text( '${b.cost} ',
                          style: const TextStyle(fontWeight: FontWeight.w900),
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
