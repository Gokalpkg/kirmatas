import 'dart:async';
import 'package:flutter/material.dart';
import '../models/cosmetics.dart';
import '../storage/save_manager.dart';
import 'i18n.dart';

/// Manages daily reminder notifications for the Lucky Fish of the Day.
/// Provides both in-app reminder banners and structured payloads for native
/// scheduled notifications.
class LuckyFishNotificationManager {
  static final LuckyFishNotificationManager instance =
      LuckyFishNotificationManager._internal();
  LuckyFishNotificationManager._internal();

  String get todayDateKey {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  bool get shouldRemindToday {
    final save = SaveManager.instance;
    return save.luckyFishEnabled &&
        save.luckyFishId != null &&
        save.lastLuckyFishReminderDate != todayDateKey;
  }

  /// Whether aquarium feeding reminder is due (fish waiting to be fed).
  bool get shouldRemindAquariumFeeding {
    final save = SaveManager.instance;
    return save.isAquariumUnlocked && save.hasWaitingFish;
  }

  /// Whether the daily free fortune wheel spin reminder is due.
  bool get shouldRemindFortuneWheel {
    final save = SaveManager.instance;
    return save.isNextWheelSpinFree;
  }

  /// Generates the payload / string content for daily notification (local notification or push)
  Map<String, String>? getDailyNotificationPayload() {
    final save = SaveManager.instance;
    final fishId = save.luckyFishId;
    if (fishId == null) return null;
    final fish = FishItem.getById(fishId);
    return {
      'id': 'lucky_fish',
      'title': I18n.tr('lucky_fish_reminder_title'),
      'body': I18n.tr('lucky_fish_reminder_msg').replaceAll('{fish}', fish.name),
      'fishId': fishId,
      'type': 'lucky_fish',
    };
  }

  /// Generates notification payload for aquarium feeding reminder.
  Map<String, String>? getAquariumFeedingNotificationPayload() {
    if (!shouldRemindAquariumFeeding) return null;
    return {
      'id': 'aquarium_feed',
      'title': 'Akvaryum Yem Saati! 🐟',
      'body': 'Balıkların acıktı! Onları besleyerek %100 sinerji güçlerini aktif tut.',
      'type': 'aquarium_feed',
    };
  }

  /// Generates notification payload for daily free fortune wheel spin.
  Map<String, String>? getFortuneWheelNotificationPayload() {
    if (!shouldRemindFortuneWheel) return null;
    return {
      'id': 'fortune_wheel',
      'title': 'Ücretsiz Şans Çarkı! 🎡',
      'body': 'Bugünkü bedava çarkıfelek hakkın seni bekliyor, hemen çevir!',
      'type': 'fortune_wheel',
    };
  }

  /// Aggregates all currently active daily notification / reminder payloads.
  List<Map<String, String>> getAllPendingDailyNotificationPayloads() {
    final list = <Map<String, String>>[];
    final lucky = getDailyNotificationPayload();
    if (lucky != null && shouldRemindToday) list.add(lucky);

    final feeding = getAquariumFeedingNotificationPayload();
    if (feeding != null) list.add(feeding);

    final wheel = getFortuneWheelNotificationPayload();
    if (wheel != null) list.add(wheel);

    return list;
  }

  /// Checks and presents the lucky fish daily reminder if not yet seen today.
  Future<void> checkAndShowDailyReminder(BuildContext context) async {
    if (!shouldRemindToday) return;

    final save = SaveManager.instance;
    save.lastLuckyFishReminderDate = todayDateKey;

    final payload = getDailyNotificationPayload();
    if (payload == null) return;

    final fish = FishItem.getById(save.luckyFishId!);

    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 4),
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xF010172A),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFFFFD54F), width: 1.5),
        ),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        content: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: const BoxDecoration(
                color: Color(0x33FFD54F),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.military_tech_rounded,
                  color: Color(0xFFFFD54F), size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Text(
                          I18n.tr('lucky_fish_reminder_title').toUpperCase(),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                          style: const TextStyle(
                            color: Color(0xFFFFD54F),
                            fontWeight: FontWeight.w900,
                            fontSize: 11,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding:
                            const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE65100),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          '3x 🪙',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    I18n.tr('lucky_fish_reminder_msg')
                        .replaceAll('{fish}', fish.name),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
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

  /// Checks and presents all pending daily retention loops (lucky fish, feeding, wheel).
  Future<void> checkAndShowAllDailyReminders(BuildContext context) async {
    if (shouldRemindToday) {
      await checkAndShowDailyReminder(context);
    }
  }
}
