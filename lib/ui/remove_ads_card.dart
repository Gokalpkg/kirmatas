import 'package:flutter/material.dart';

import '../engine/i18n.dart';
import '../engine/remove_ads_billing.dart';
import '../storage/save_manager.dart';

class RemoveAdsCard extends StatelessWidget {
  final bool compact;

  const RemoveAdsCard({super.key, this.compact = false});

  @override
  Widget build(BuildContext context) {
    final billing = RemoveAdsBilling.instance;
    return ListenableBuilder(
      listenable: Listenable.merge([SaveManager.instance, billing]),
      builder: (context, _) {
        final owned = SaveManager.instance.adsRemoved;
        return Container(
          margin: EdgeInsets.fromLTRB(compact ? 12 : 0, compact ? 8 : 0, compact ? 12 : 0, compact ? 4 : 12),
          padding: EdgeInsets.all(compact ? 12 : 18),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0x3326C6DA), Color(0xFF141724)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(compact ? 16 : 22),
            border: Border.all(
              color: owned ? const Color(0xFF69F0AE) : const Color(0x6626C6DA),
              width: owned ? 1.6 : 1.2,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: compact ? 40 : 56,
                height: compact ? 40 : 56,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFF26C6DA), width: 1.4),
                  color: const Color(0x2226C6DA),
                ),
                child: Icon(Icons.block, color: const Color(0xFF26C6DA), size: compact ? 20 : 28),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      I18n.tr('remove_ads_title'),
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: compact ? 14 : 15),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      I18n.tr('remove_ads_body'),
                      style: const TextStyle(color: Colors.white70, fontSize: 12, height: 1.3),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      owned ? I18n.tr('remove_ads_owned') : billing.priceLabel,
                      style: TextStyle(
                        color: owned ? const Color(0xFF69F0AE) : const Color(0xFF26C6DA),
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              if (!owned) ...[
                const SizedBox(width: 10),
                ElevatedButton(
                  onPressed: () => _buy(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF26C6DA),
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                  child: Text(
                    I18n.tr('remove_ads_buy'),
                    style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Future<void> _buy(BuildContext context) async {
    final opened = await RemoveAdsBilling.instance.buy();
    if (opened || !context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(I18n.tr('remove_ads_unavailable'))),
    );
  }
}
