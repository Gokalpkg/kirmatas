import 'package:flutter/material.dart';
import '../engine/audio_manager.dart';
import 'kaunos_ui.dart';

class MainMenuTourOverlay extends StatefulWidget {
  final VoidCallback onFinish;
  final GlobalKey? playButtonKey;
  final GlobalKey? upgradesNavKey;
  final GlobalKey? aquariumNavKey;
  final GlobalKey? wheelNavKey;

  const MainMenuTourOverlay({
    super.key,
    required this.onFinish,
    this.playButtonKey,
    this.upgradesNavKey,
    this.aquariumNavKey,
    this.wheelNavKey,
  });

  @override
  State<MainMenuTourOverlay> createState() => _MainMenuTourOverlayState();
}

class _MainMenuTourOverlayState extends State<MainMenuTourOverlay>
    with SingleTickerProviderStateMixin {
  int _currentStep = 0; // 0 = Welcome, 1 = Play, 2 = Upgrades, 3 = Aquarium, 4 = Wheel
  late final AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Rect? _getTargetRect() {
    GlobalKey? key;
    switch (_currentStep) {
      case 1:
        key = widget.playButtonKey;
        break;
      case 2:
        key = widget.upgradesNavKey;
        break;
      case 3:
        key = widget.aquariumNavKey;
        break;
      case 4:
        key = widget.wheelNavKey;
        break;
      default:
        key = null;
    }
    if (key == null) return null;
    final renderBox = key.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null || !renderBox.hasSize) return null;
    final offset = renderBox.localToGlobal(Offset.zero);
    return offset & renderBox.size;
  }

  void _nextStep() {
    AudioManager.instance.playSfx(GameSfx.click);
    if (_currentStep < 4) {
      setState(() {
        _currentStep++;
      });
    } else {
      _finish();
    }
  }

  void _prevStep() {
    AudioManager.instance.playSfx(GameSfx.click);
    if (_currentStep > 1) {
      setState(() {
        _currentStep--;
      });
    } else if (_currentStep == 1) {
      setState(() {
        _currentStep = 0;
      });
    }
  }

  void _finish() {
    AudioManager.instance.playSfx(GameSfx.victory);
    widget.onFinish();
  }

  @override
  Widget build(BuildContext context) {
    final targetRect = _getTargetRect();
    final screenSize = MediaQuery.of(context).size;

    return Material(
      color: Colors.transparent,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Spotlight Background Layer
          if (_currentStep > 0 && targetRect != null)
            AnimatedBuilder(
              animation: _pulseController,
              builder: (context, _) {
                return CustomPaint(
                  size: screenSize,
                  painter: _SpotlightPainter(
                    targetRect: targetRect,
                    pulseValue: _pulseController.value,
                  ),
                );
              },
            )
          else
            Container(
              color: Colors.black.withValues(alpha: 0.88),
            ),

          // Content Layer
          SafeArea(
            child: _currentStep == 0
                ? _buildWelcomeModal()
                : _buildStepGuidance(targetRect, screenSize),
          ),
        ],
      ),
    );
  }

  Widget _buildWelcomeModal() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: KaunosPanel(
          backgroundColor: KaunosPalette.obsidianGlassElevated,
          borderColor: KaunosPalette.goldHighlight,
          showSpecularRim: true,
          borderRadius: 26,
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFFD54F), Color(0xFFFF8F00)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: KaunosPalette.goldHighlight.withValues(alpha: 0.4),
                      blurRadius: 20,
                    ),
                  ],
                ),
                child: const Center(
                  child: KaunosEmblem.astrolabe(
                    size: 38,
                    ringColor: Color(0xFF1B1605),
                    starColor: Color(0xFF1B1605),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                'KIRMATAS DÜNYASINA\nHOŞ GELDİN!',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontFamily: 'Rajdhani',
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.2,
                  height: 1.15,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Ekrandaki sekmeler kafanı karıştırmasın! 1 dakikalık hızlı tur ile oyunun 4 temel gücünü keşfedelim.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.78),
                  fontFamily: 'Rajdhani',
                  fontSize: 14.5,
                  fontWeight: FontWeight.w600,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 22),
              KaunosJuicyInteractive(
                borderRadius: 16,
                waveColor: KaunosPalette.goldHighlight,
                onTap: _nextStep,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFFFD54F), Color(0xFFFF9100)],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x66FF8F00),
                        blurRadius: 12,
                        offset: Offset(0, 3),
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.play_arrow_rounded, color: Color(0xFF1B1605), size: 22),
                        SizedBox(width: 6),
                        Text(
                          'HIZLI TURU BAŞLAT',
                          style: TextStyle(
                            color: Color(0xFF1B1605),
                            fontFamily: 'Rajdhani',
                            fontWeight: FontWeight.w900,
                            fontSize: 15,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              TextButton(
                onPressed: _finish,
                child: Text(
                  'ATLA (Biliyorum)',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.5),
                    fontFamily: 'Rajdhani',
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStepGuidance(Rect? targetRect, Size screenSize) {
    late final String stepBadge;
    late final String title;
    late final String desc;
    late final IconData icon;
    late final Color accentColor;

    switch (_currentStep) {
      case 1:
        stepBadge = 'ADIM 1 / 4';
        title = 'OYNA (Klasik Macera)';
        desc =
            'Tuğla kırma yolculuğun burada başlar! Bölümleri geçtikçe puan toplar, seviye atlar ve yeni özelliklerin kilidini açarsın.';
        icon = Icons.play_arrow_rounded;
        accentColor = const Color(0xFFFFD54F);
        break;
      case 2:
        stepBadge = 'ADIM 2 / 4';
        title = 'Atölye & Yükseltmeler';
        desc =
            'Bölüm 3 seviyesinde açılır! Kırdığın tuğlalardan kazandığın altınlarla palet genişliğini, top hızını ve vuruş gücünü kalıcı olarak artırabilirsin.';
        icon = Icons.auto_awesome_rounded;
        accentColor = const Color(0xFFFF9100);
        break;
      case 3:
        stepBadge = 'ADIM 3 / 4';
        title = 'Kaunos Akvaryumu (Bölüm 5)';
        desc =
            'Bölüm 5 seviyesinde açılır! Kendi su altı dünyanda balıklarını besleyebilir ve sana düzenli pasif altın ve inci üretmelerini sağlayabilirsin.';
        icon = Icons.water_drop_rounded;
        accentColor = const Color(0xFF00E5FF);
        break;
      case 4:
      default:
        stepBadge = 'ADIM 4 / 4';
        title = 'Şans Çarkı ve Görevler';
        desc =
            'Her gün ücretsiz çark çevirerek sürpriz sandıklar kazanabilir, günlük operasyon ve görevlerle devasa ödüller toplayabilirsin!';
        icon = Icons.star_rounded;
        accentColor = const Color(0xFFE040FB);
        break;
    }

    final bool isTargetBelowCenter =
        targetRect != null && targetRect.center.dy > (screenSize.height * 0.45);

    return Stack(
      children: [
        // Top Skip Button
        Positioned(
          top: 10,
          right: 18,
          child: GestureDetector(
            onTap: _finish,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white24),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Turu Geç',
                    style: TextStyle(
                      color: Colors.white70,
                      fontFamily: 'Rajdhani',
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(width: 4),
                  Icon(Icons.close_rounded, color: Colors.white70, size: 14),
                ],
              ),
            ),
          ),
        ),

        // Floating Guidance Card
        Positioned(
          left: 18,
          right: 18,
          top: isTargetBelowCenter ? null : ((targetRect?.bottom ?? 180) + 16),
          bottom: isTargetBelowCenter
              ? (screenSize.height - targetRect.top + 16)
              : null,
          child: KaunosPanel(
            backgroundColor: KaunosPalette.obsidianGlassElevated,
            borderColor: accentColor.withValues(alpha: 0.7),
            showSpecularRim: true,
            borderRadius: 22,
            padding: const EdgeInsets.all(18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                      decoration: BoxDecoration(
                        color: accentColor.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: accentColor.withValues(alpha: 0.6),
                          width: 1.0,
                        ),
                      ),
                      child: Text(
                        stepBadge,
                        style: TextStyle(
                          color: accentColor,
                          fontFamily: 'Rajdhani',
                          fontWeight: FontWeight.w900,
                          fontSize: 11,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),
                    Icon(icon, color: accentColor, size: 22),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontFamily: 'Rajdhani',
                    fontSize: 19,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  desc,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.82),
                    fontFamily: 'Rajdhani',
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton.icon(
                      onPressed: _prevStep,
                      icon: const Icon(Icons.arrow_back_rounded, color: Colors.white54, size: 16),
                      label: const Text(
                        'GERİ',
                        style: TextStyle(
                          color: Colors.white54,
                          fontFamily: 'Rajdhani',
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    KaunosJuicyInteractive(
                      borderRadius: 12,
                      waveColor: accentColor,
                      onTap: _nextStep,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [accentColor, accentColor.withValues(alpha: 0.8)],
                          ),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: accentColor.withValues(alpha: 0.35),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _currentStep == 4 ? 'MACERAYA BAŞLA! 🚀' : 'SONRAKİ',
                              style: TextStyle(
                                color: accentColor.computeLuminance() > 0.4
                                    ? const Color(0xFF070B18)
                                    : Colors.white,
                                fontFamily: 'Rajdhani',
                                fontWeight: FontWeight.w900,
                                fontSize: 13,
                                letterSpacing: 0.5,
                              ),
                            ),
                            if (_currentStep < 4) ...[
                              const SizedBox(width: 4),
                              Icon(
                                Icons.arrow_forward_rounded,
                                color: accentColor.computeLuminance() > 0.4
                                    ? const Color(0xFF070B18)
                                    : Colors.white,
                                size: 16,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _SpotlightPainter extends CustomPainter {
  final Rect targetRect;
  final double pulseValue;

  _SpotlightPainter({
    required this.targetRect,
    required this.pulseValue,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final inflateAmt = 8.0 + (pulseValue * 3.0);
    final inflatedRect = targetRect.inflate(inflateAmt);
    final rrect = RRect.fromRectAndRadius(inflatedRect, const Radius.circular(20));

    // Draw darkened screen with cut-out hole
    final backgroundPath = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height));
    final holePath = Path()..addRRect(rrect);
    final overlayPath = Path.combine(PathOperation.difference, backgroundPath, holePath);

    final bgPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.84)
      ..style = PaintingStyle.fill;
    canvas.drawPath(overlayPath, bgPaint);

    // Crisp Stepped Pixel Highlight Frame around hole (Zero Blur)
    final darkBorderPaint = Paint()
      ..isAntiAlias = false
      ..color = const Color(0xFF0B1021)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.5 + (pulseValue * 1.5);
    canvas.drawRRect(rrect, darkBorderPaint);

    final glowPaint = Paint()
      ..isAntiAlias = false
      ..color = const Color(0xFFFFD54F).withValues(alpha: 0.65 + (pulseValue * 0.35))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5 + (pulseValue * 1.0);

    canvas.drawRRect(rrect, glowPaint);
  }

  @override
  bool shouldRepaint(covariant _SpotlightPainter oldDelegate) {
    return oldDelegate.targetRect != targetRect || oldDelegate.pulseValue != pulseValue;
  }
}
