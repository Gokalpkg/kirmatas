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

  /// Generates the payload / string content for daily notification (local notification or push)
  Map<String, String>? getDailyNotificationPayload() {
    final save = SaveManager.instance;
    final fishId = save.luckyFishId;
    if (fishId == null) return null;
    final fish = FishItem.getById(fishId);
    return {
      'title': I18n.tr('lucky_fish_reminder_title'),
      'body': I18n.tr('lucky_fish_reminder_msg').replaceAll('{fish}', fish.name),
      'fishId': fishId,
    };
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
}
