import 'package:flutter/material.dart';

import '../engine/i18n.dart';
import '../engine/remove_ads_billing.dart';

class RemoveAdsCard extends StatelessWidget {
  final bool compact;

  const RemoveAdsCard({super.key, this.compact = false});

  @override
  Widget build(BuildContext context) {
    // 1.99$ IAP prompt temporarily hidden as requested
    return const SizedBox.shrink();
  }

  // Preserved for programmatic triggers if needed
  static Future<void> buy(BuildContext context) async {
    final opened = await RemoveAdsBilling.instance.buy();
    if (opened || !context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(I18n.tr('remove_ads_unavailable'))),
    );
  }
}
