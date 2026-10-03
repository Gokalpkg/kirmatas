import 'dart:async';
import 'package:flutter/material.dart';
import '../engine/ad_manager.dart';
import '../engine/audio_manager.dart';

class RewardedGoldAdButton extends StatefulWidget {
  final bool isCompact;
  const RewardedGoldAdButton({super.key, this.isCompact = false});

  @override
  State<RewardedGoldAdButton> createState() => _RewardedGoldAdButtonState();
}

class _RewardedGoldAdButtonState extends State<RewardedGoldAdButton> with SingleTickerProviderStateMixin {
  final AdManager _adManager = AdManager.instance;
  Timer? _countdownTimer;
  late final AnimationController _pulseController;
  late final Animation<double> _pulseScale;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);

    _pulseScale = Tween<double>(begin: 1.0, end: 1.04).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Refresh cooldown countdown every second
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  String _formatCooldown(int totalSeconds) {
    final m = totalSeconds ~/ 60;
    final s = totalSeconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  void _onWatchAdPressed() {
    _adManager.watchAdForGold(
      context,
      onSuccess: (reward) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.stars, color: Color(0xFFFFD54F), size: 24),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '🪙 +$reward Altın Hesabınıza Eklendi!',
                    style: const TextStyle(
                      color: Color(0xFFFFD54F),
                      fontWeight: FontWeight.w900,
                      fontSize: 15,
                    ),
                  ),
                ),
              ],
            ),
            backgroundColor: const Color(0xFF161A29),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: const BorderSide(color: Color(0xFFFFD54F), width: 1.5),
            ),
            duration: const Duration(seconds: 3),
          ),
        );
      },
      onDismissedEarly: () {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.info_outline, color: Color(0xFFFFB74D), size: 22),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Ödülü kazanmak için reklamı sonuna kadar izlemelisiniz.',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
            backgroundColor: const Color(0xFF1E2438),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: const BorderSide(color: Color(0xFFFFB74D), width: 1),
            ),
            duration: const Duration(seconds: 3),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _adManager,
      builder: (context, _) {
        final cooldown = _adManager.remainingCooldownSeconds;
        final isOnCooldown = cooldown > 0;
        final isLoading = _adManager.isLoading || _adManager.isShowing;
        final isEnabled = !isOnCooldown && !isLoading;

        if (widget.isCompact) {
          return _buildCompactButton(isEnabled, isOnCooldown, isLoading, cooldown);
        }

        return _buildFullButton(isEnabled, isOnCooldown, isLoading, cooldown);
      },
    );
  }

  Widget _buildCompactButton(bool isEnabled, bool isOnCooldown, bool isLoading, int cooldown) {
    final text = isOnCooldown
        ? '🪙 +50 (${_formatCooldown(cooldown)})'
        : (isLoading ? 'Yükleniyor...' : '🪙 +50 Altın');

    return Container(
      decoration: BoxDecoration(
        gradient: isEnabled
            ? const LinearGradient(
                colors: [Color(0xFFFFD54F), Color(0xFFFF9800)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : null,
        color: isEnabled ? null : const Color(0x33FFFFFF),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isEnabled ? const Color(0xFFFFE082) : Colors.white12,
          width: 1,
        ),
        boxShadow: isEnabled
            ? [
                BoxShadow(
                  color: const Color(0xFFFF9800).withValues(alpha: 0.35),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ]
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: isEnabled ? _onWatchAdPressed : null,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isLoading) ...[
                  const SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white70),
                  ),
                  const SizedBox(width: 6),
                ] else if (isOnCooldown) ...[
                  const Icon(Icons.timer_outlined, color: Colors.white54, size: 14),
                  const SizedBox(width: 4),
                ] else ...[
                  const Icon(Icons.play_circle_fill, color: Color(0xFF3E2723), size: 14),
                  const SizedBox(width: 4),
                ],
                Text(
                  text,
                  style: TextStyle(
                    color: isEnabled ? const Color(0xFF3E2723) : Colors.white54,
                    fontWeight: FontWeight.w900,
                    fontSize: 12,
                    letterSpacing: 0.2,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFullButton(bool isEnabled, bool isOnCooldown, bool isLoading, int cooldown) {
    Widget buttonContent = Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        gradient: isEnabled
            ? const LinearGradient(
                colors: [Color(0xFFFFE082), Color(0xFFFFB300), Color(0xFFFF8F00)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : LinearGradient(
                colors: [
                  const Color(0xFF262A3B).withValues(alpha: 0.9),
                  const Color(0xFF1E2230).withValues(alpha: 0.9),
                ],
              ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isEnabled ? const Color(0xFFFFF8E1) : Colors.white12,
          width: 1.5,
        ),
        boxShadow: isEnabled
            ? [
                BoxShadow(
                  color: const Color(0xFFFF8F00).withValues(alpha: 0.45),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (isLoading) ...[
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white70),
            ),
            const SizedBox(width: 10),
            const Text(
              'Reklam Yükleniyor...',
              style: TextStyle(
                color: Colors.white70,
                fontWeight: FontWeight.w800,
                fontSize: 14,
              ),
            ),
          ] else if (isOnCooldown) ...[
            const Icon(Icons.hourglass_top, color: Colors.white54, size: 20),
            const SizedBox(width: 8),
            Text(
              '🪙 +50 Altın (${_formatCooldown(cooldown)})',
              style: const TextStyle(
                color: Colors.white54,
                fontWeight: FontWeight.w800,
                fontSize: 14,
              ),
            ),
          ] else ...[
            Container(
              padding: const EdgeInsets.all(4),
              decoration: const BoxDecoration(
                color: Color(0xFF3E2723),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.play_arrow_rounded, color: Color(0xFFFFD54F), size: 16),
            ),
            const SizedBox(width: 10),
            const Text(
              '🪙 +50 Altın (Reklam İzle)',
              style: TextStyle(
                color: Color(0xFF2E1C00),
                fontWeight: FontWeight.w900,
                fontSize: 15,
                letterSpacing: 0.3,
              ),
            ),
          ],
        ],
      ),
    );

    if (isEnabled) {
      buttonContent = ScaleTransition(
        scale: _pulseScale,
        child: buttonContent,
      );
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: isEnabled ? _onWatchAdPressed : null,
        child: buttonContent,
      ),
    );
  }
}
