import 'package:flutter/material.dart';
import '../engine/i18n.dart';
import '../models/cosmetics.dart';
import '../storage/save_manager.dart';
import 'eco_tank_background.dart';

class AquariumView extends StatelessWidget {
  const AquariumView({super.key});

  @override
  Widget build(BuildContext context) {
    final save = SaveManager.instance;

    return ListenableBuilder(
      listenable: save,
      builder: (context, _) {
        return Scaffold(
          body: EcoTankBackground(
            interactive: true,
            child: SafeArea(
              child: Stack(
                children: [
                  // Top Bar
                  Positioned(
                    top: 10,
                    left: 14,
                    right: 14,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
                          style: IconButton.styleFrom(backgroundColor: const Color(0x66000000)),
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: const Color(0x80000000),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: const Color(0x334FC3F7)),
                          ),
                          child: Text(
                            I18n.tr('aquarium_title'),
                            style: const TextStyle(
                              color: Color(0xFF4FC3F7),
                              fontWeight: FontWeight.w900,
                              fontSize: 14,
                              letterSpacing: 1.0,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: const Color(0x80000000),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0x33FFD54F)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.monetization_on, color: Color(0xFFFFD54F), size: 16),
                              const SizedBox(width: 4),
                              Text(
                                '${save.gold}',
                                style: const TextStyle(color: Color(0xFFFFD54F), fontWeight: FontWeight.w900),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Feeding prompt
                  Positioned(
                    top: 70,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: Text(
                        I18n.tr('feed_hint'),
                        style: const TextStyle(color: Colors.white60, fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),

                  // Bottom Fish Collection Drawer Button
                  Positioned(
                    bottom: 20,
                    left: 20,
                    right: 20,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        showModalBottomSheet(
                          context: context,
                          isScrollControlled: true,
                          backgroundColor: const Color(0xF00D0F18),
                          shape: const RoundedRectangleBorder(
                            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                          ),
                          builder: (_) => _buildFishSheet(context, save),
                        );
                      },
                      icon: const Icon(Icons.collections_bookmark, size: 18),
                      label: Text(
                        I18n.tr('fish_collection'),
                        style: const TextStyle(fontWeight: FontWeight.w900, letterSpacing: 0.8),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF00ACC1),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                      ),
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

  Widget _buildFishSheet(BuildContext context, SaveManager save) {
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.72,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  I18n.tr('collected_species'),
                  style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900),
                ),
                Text(
                  '${save.unlockedFish.length} / ${FishItem.allFish.length}',
                  style: const TextStyle(color: Color(0xFF4FC3F7), fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: GridView.builder(
                physics: const BouncingScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  childAspectRatio: 0.92,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                ),
                itemCount: FishItem.allFish.length,
            itemBuilder: (context, index) {
              final fish = FishItem.allFish[index];
              final owned = save.unlockedFish.contains(fish.id);

              return Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: owned ? const Color(0xFF161A28) : const Color(0x66161A28),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: owned ? fish.rarity.primaryColor : Colors.white10,
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      height: 38,
                      child: owned
                          ? Image.asset(fish.assetPath, fit: BoxFit.contain)
                          : ColorFiltered(
                              colorFilter: const ColorFilter.mode(Colors.black54, BlendMode.srcATop),
                              child: Opacity(
                                opacity: 0.25,
                                child: Image.asset(fish.assetPath, fit: BoxFit.contain),
                              ),
                            ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      fish.name,
                      style: TextStyle(
                        color: owned ? Colors.white : Colors.white38,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      fish.rarity.label,
                      style: TextStyle(
                        color: owned ? fish.rarity.primaryColor : Colors.white24,
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    ),
  ),
);
}
}
