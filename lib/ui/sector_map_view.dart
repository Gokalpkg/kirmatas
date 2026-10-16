import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../engine/audio_manager.dart';
import '../models/sector_data.dart';
import '../storage/save_manager.dart';

/// 238 bölümlük Klasik Mod için Görsel Sektör ve Checkpoint Haritası
class SectorMapView extends StatefulWidget {
  final SaveManager save;
  final Function(int startLevel)? onStartSectorLevel;

  const SectorMapView({
    super.key,
    required this.save,
    this.onStartSectorLevel,
  });

  @override
  State<SectorMapView> createState() => _SectorMapViewState();
}

class _SectorMapViewState extends State<SectorMapView> with SingleTickerProviderStateMixin {
  late final ScrollController _scrollController;
  late final AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);

    // Açıldığında oyuncunun bulunduğu sektöre otomatik kaydır
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToCurrentSector();
    });
  }

  void _scrollToCurrentSector() {
    final highest = widget.save.metricHighestClassicLevel;
    final currentSector = SectorData.getSectorForLevel(highest);
    final index = currentSector.sectorIndex - 1; // 0..13

    if (_scrollController.hasClients) {
      // Her sektör kartı yaklaşık 130 piksel
      final targetOffset = (index * 130.0 - 150.0).clamp(
        0.0,
        _scrollController.position.maxScrollExtent,
      );
      _scrollController.animateTo(
        targetOffset,
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeOutCubic,
      );
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  void _onSectorTap(SectorData sector) {
    HapticFeedback.selectionClick();
    AudioManager.instance.playSfx(GameSfx.click);

    final highest = widget.save.metricHighestClassicLevel;
    final isUnlocked = sector.isUnlocked(highest);

    if (!isUnlocked) {
      HapticFeedback.heavyImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.lock, color: Colors.orangeAccent, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${sector.getName(widget.save.language)} kilitli! Açmak için Bölüm ${sector.startLevel}\'e ulaşmalısın.',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          backgroundColor: const Color(0xFF161A28),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
      return;
    }

    _showSectorActionModal(sector);
  }

  void _showSectorActionModal(SectorData sector) {
    final lang = widget.save.language;
    final highest = widget.save.metricHighestClassicLevel;
    final savedLevel = widget.save.classicSavedLevel;
    final isCompleted = sector.isCompleted(highest);

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF101422),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (modalCtx) {
        return Container(
          padding: const EdgeInsets.fromLTRB(22, 16, 22, 28),
          decoration: BoxDecoration(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            gradient: LinearGradient(
              colors: [
                const Color(0xFF181F33),
                sector.primaryColor.withValues(alpha: 0.15),
                const Color(0xFF0D101C),
              ],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            border: Border.all(color: sector.primaryColor.withValues(alpha: 0.4), width: 1.5),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Üst çekme çubuğu
              Container(
                width: 44,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              // Sektör Rozeti ve Başlığı
              Row(
                children: [
                  Container(
                    width: 54,
                    height: 54,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: sector.gradientColors),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: sector.primaryColor.withValues(alpha: 0.5),
                          blurRadius: 14,
                        ),
                      ],
                    ),
                    child: Icon(sector.icon, color: Colors.white, size: 28),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'SEKTÖR ${sector.sectorIndex}',
                          style: TextStyle(
                            color: sector.accentColor,
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.2,
                          ),
                        ),
                        Text(
                          sector.getName(lang),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 19,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Bölüm ${sector.startLevel} - ${sector.endLevel}',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (isCompleted)
                    const Column(
                      children: [
                        Icon(Icons.verified_rounded, color: Color(0xFFFFD54F), size: 30),
                        SizedBox(height: 2),
                        Text(
                          'TAMAMLANDI',
                          style: TextStyle(
                            color: Color(0xFFFFD54F),
                            fontSize: 8.5,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                ],
              ),

              const SizedBox(height: 14),

              // Açıklama Kutusu
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.black38,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.white10),
                ),
                child: Text(
                  sector.getDescription(lang),
                  style: const TextStyle(color: Colors.white70, fontSize: 12, height: 1.35),
                ),
              ),

              const SizedBox(height: 18),

              // 1. Seçenek: Eğer kayıtlı seviye bu sektörün içindeyse "Kaldığın Yerden Devam Et"
              if (savedLevel != null && savedLevel >= sector.startLevel && savedLevel <= sector.endLevel) ...[
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF00E676),
                      foregroundColor: Colors.black,
                      elevation: 4,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    icon: const Icon(Icons.play_arrow_rounded, size: 28),
                    label: Text(
                      'Kaldığın Yerden Devam Et (Bölüm $savedLevel)',
                      style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14),
                    ),
                    onPressed: () {
                      Navigator.of(modalCtx).pop();
                      _launchGame(startLevel: savedLevel);
                    },
                  ),
                ),
                const SizedBox(height: 10),
              ],

              // 2. Seçenek: Checkpoint Başlangıç Seviyesi
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: sector.primaryColor,
                    foregroundColor: Colors.white,
                    elevation: 3,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  icon: const Icon(Icons.flag_rounded, size: 22),
                  label: Text(
                    'Checkpoint\'ten Başla (Bölüm ${sector.checkpointLevel})',
                    style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14),
                  ),
                  onPressed: () {
                    Navigator.of(modalCtx).pop();
                    _launchGame(startLevel: sector.checkpointLevel);
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _launchGame({required int startLevel}) {
    Navigator.of(context).pop(startLevel);
    widget.onStartSectorLevel?.call(startLevel);
  }

  @override
  Widget build(BuildContext context) {
    final highest = widget.save.metricHighestClassicLevel;
    final progress = (highest / 238.0).clamp(0.0, 1.0);
    final percent = (progress * 100).toInt();

    return Scaffold(
      backgroundColor: const Color(0xFF0A0D18),
      body: SafeArea(
        child: Column(
          children: [
            // Üst Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: const BoxDecoration(
                color: Color(0xFF101424),
                border: Border(bottom: BorderSide(color: Colors.white12)),
              ),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'KLASİK MOD SEKTÖRLERİ',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.8,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          highest > 238
                              ? 'Prestij ${widget.save.prestigeTier}  •  Bölüm $highest (Sonsuz Omega)'
                              : 'Bölüm $highest / 238  •  %$percent Tamamlandı',
                          style: const TextStyle(
                            color: Color(0xFFFFD54F),
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // İlerleme Rozeti
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1A2238),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0x66FFD54F)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.shield_rounded, color: Color(0xFFFFD54F), size: 16),
                        const SizedBox(width: 4),
                        Text(
                          highest > 238
                              ? 'P${widget.save.prestigeTier} • 14/14'
                              : '${widget.save.highestUnlockedSector}/14',
                          style: const TextStyle(
                            color: Color(0xFFFFD54F),
                            fontWeight: FontWeight.w900,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Sektör Yolu Listesi
            Expanded(
              child: AnimatedBuilder(
                animation: _pulseController,
                builder: (context, _) {
                  return ListView.builder(
                    controller: _scrollController,
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
                    itemCount: SectorData.allSectors.length + (highest > 238 ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index == SectorData.allSectors.length) {
                        return Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _buildPathConnector(isUnlocked: true),
                            _buildPrestigeOmegaCard(
                              prestigeTier: widget.save.prestigeTier,
                              highestLevel: highest,
                              pulse: _pulseController.value,
                            ),
                          ],
                        );
                      }

                      final sector = SectorData.allSectors[index];
                      final isUnlocked = sector.isUnlocked(highest);
                      final isCompleted = sector.isCompleted(highest);
                      final isCurrent = sector.isCurrent(highest);
                      final isLast = index == SectorData.allSectors.length - 1 && highest <= 238;

                      // Alternating left/center/right alignment to create a dynamic winding path
                      final alignment = (index % 3 == 0)
                          ? Alignment.centerLeft
                          : (index % 3 == 1)
                              ? Alignment.center
                              : Alignment.centerRight;

                      return Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Align(
                            alignment: alignment,
                            child: _buildSectorCard(
                              sector: sector,
                              isUnlocked: isUnlocked,
                              isCompleted: isCompleted,
                              isCurrent: isCurrent,
                              pulse: _pulseController.value,
                            ),
                          ),
                          if (!isLast) _buildPathConnector(isUnlocked: isUnlocked),
                        ],
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectorCard({
    required SectorData sector,
    required bool isUnlocked,
    required bool isCompleted,
    required bool isCurrent,
    required double pulse,
  }) {
    final lang = widget.save.language;

    return GestureDetector(
      onTap: () => _onSectorTap(sector),
      child: Container(
        width: 280,
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: isUnlocked
              ? LinearGradient(
                  colors: [
                    const Color(0xFF151B2E),
                    sector.primaryColor.withValues(alpha: isCurrent ? 0.25 : 0.12),
                    const Color(0xFF0F1322),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : const LinearGradient(
                  colors: [Color(0xFF131622), Color(0xFF0D0F18)],
                ),
          border: Border.all(
            color: isCurrent
                ? sector.primaryColor.withValues(alpha: 0.7 + 0.3 * pulse)
                : isCompleted
                    ? const Color(0xFFFFD54F).withValues(alpha: 0.6)
                    : isUnlocked
                        ? sector.primaryColor.withValues(alpha: 0.35)
                        : Colors.white12,
            width: isCurrent ? 2.0 : 1.2,
          ),
          boxShadow: [
            if (isCurrent)
              BoxShadow(
                color: sector.primaryColor.withValues(alpha: 0.35 * pulse),
                blurRadius: 16,
                spreadRadius: 1,
              ),
            if (isCompleted)
              BoxShadow(
                color: const Color(0xFFFFD54F).withValues(alpha: 0.15),
                blurRadius: 10,
              ),
          ],
        ),
        child: Row(
          children: [
            // İkon / Rozet
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: isUnlocked
                    ? LinearGradient(colors: sector.gradientColors)
                    : const LinearGradient(colors: [Colors.grey, Color(0xFF424242)]),
                boxShadow: isUnlocked
                    ? [
                        BoxShadow(
                          color: sector.primaryColor.withValues(alpha: 0.4),
                          blurRadius: 8,
                        ),
                      ]
                    : null,
              ),
              child: Icon(
                isUnlocked ? sector.icon : Icons.lock_rounded,
                color: isUnlocked ? Colors.white : Colors.white38,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),

            // Metinler
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Text(
                        'SEKTÖR ${sector.sectorIndex}',
                        style: TextStyle(
                          color: isUnlocked ? sector.accentColor : Colors.white38,
                          fontSize: 9.5,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.8,
                        ),
                      ),
                      const Spacer(),
                      if (isCurrent)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                          decoration: BoxDecoration(
                            color: sector.primaryColor,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            'BURADASIN',
                            style: TextStyle(
                              color: Colors.black,
                              fontSize: 8,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        )
                      else if (isCompleted)
                        const Icon(Icons.check_circle_rounded, color: Color(0xFFFFD54F), size: 16),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    sector.getName(lang),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: isUnlocked ? Colors.white : Colors.white38,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    'Bölüm ${sector.startLevel} - ${sector.endLevel}',
                    style: TextStyle(
                      color: isUnlocked ? Colors.white60 : Colors.white24,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPrestigeOmegaCard({
    required int prestigeTier,
    required int highestLevel,
    required double pulse,
  }) {
    return Container(
      width: 320,
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF6A1B9A).withValues(alpha: 0.85),
            const Color(0xFF1A237E).withValues(alpha: 0.95),
            const Color(0xFFD500F9).withValues(alpha: 0.6),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: Color.lerp(const Color(0xFFFFD700), const Color(0xFFE040FB), pulse)!,
          width: 2.0,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFE040FB).withValues(alpha: 0.35 + pulse * 0.25),
            blurRadius: 18 + pulse * 8,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () {
            HapticFeedback.heavyImpact();
            widget.onStartSectorLevel?.call(highestLevel);
          },
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        colors: [Color(0xFFFFD700), Color(0xFFE040FB)],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFFFD700).withValues(alpha: 0.5),
                          blurRadius: 10,
                        ),
                      ],
                    ),
                    child: const Icon(Icons.all_inclusive_rounded, color: Colors.white, size: 26),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'PRESTİJ SEKTÖR OMEGA 🌌',
                          style: TextStyle(
                            color: Color(0xFFFFD700),
                            fontWeight: FontWeight.w900,
                            fontSize: 14,
                            letterSpacing: 0.8,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Sonsuz Seviye • Prestij Kademesi $prestigeTier',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFD700),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'Bölüm $highestLevel',
                      style: const TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.w900,
                        fontSize: 11.5,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              const Text(
                '238. Bölüm sonrası sonsuz kozmik zorluk! Güçlendirilmiş tuğla dayanıklılığı ve prestij altın kazanç çarpanı aktif.',
                style: TextStyle(color: Colors.white60, fontSize: 11, height: 1.35),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPathConnector({required bool isUnlocked}) {
    return Container(
      width: 4,
      height: 24,
      margin: const EdgeInsets.symmetric(vertical: 2),
      decoration: BoxDecoration(
        color: isUnlocked ? const Color(0xFF00E5FF).withValues(alpha: 0.6) : Colors.white12,
        borderRadius: BorderRadius.circular(2),
        boxShadow: isUnlocked
            ? [
                BoxShadow(
                  color: const Color(0xFF00E5FF).withValues(alpha: 0.4),
                  blurRadius: 6,
                ),
              ]
            : null,
      ),
    );
  }
}
