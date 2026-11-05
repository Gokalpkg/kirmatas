import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'i18n.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    await Firebase.initializeApp();
  } catch (_) {}
}

/// Unified notification manager implementing Supercell/King industry standards:
/// 1. Automated Local Retention Loops (Chest full, Free Spin, Lucky Fish)
/// 2. Remote Broadcast Push via Firebase Cloud Messaging (FCM topic: 'all_players')
class NotificationService {
  static final NotificationService instance = NotificationService._internal();
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  static const String retentionChannelId = 'kirmatas_retention_channel';
  static const String retentionChannelName = 'Kırmataş Hatırlatıcıları';
  static const String eventsChannelId = 'kirmatas_events_channel';
  static const String eventsChannelName = 'Kırmataş Etkinlik ve Duyurular';

  /// Initializes both local notification engine and Firebase Cloud Messaging.
  Future<void> initialize() async {
    if (_initialized) return;

    // 1. Initialize timezone database for precise scheduling
    try {
      tz.initializeTimeZones();
    } catch (e) {
      debugPrint('[NotificationService] Timezone init warning: $e');
    }

    // 2. Local notifications setup for Android & iOS
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const darwinSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: darwinSettings,
      macOS: darwinSettings,
    );

    try {
      await _localNotifications.initialize(
        settings: initSettings,
        onDidReceiveNotificationResponse: (response) {
          debugPrint('[NotificationService] Notification tapped: ${response.payload}');
        },
      );
    } catch (e) {
      debugPrint('[NotificationService] Local notifications init error: $e');
    }

    // 3. Android notification channel creation
    final androidPlugin = _localNotifications.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (androidPlugin != null) {
      try {
        await androidPlugin.createNotificationChannel(
          const AndroidNotificationChannel(
            retentionChannelId,
            retentionChannelName,
            description: 'Akvaryum, sandık ve şans çarkı döngü bildirimleri',
            importance: Importance.high,
          ),
        );
        await androidPlugin.createNotificationChannel(
          const AndroidNotificationChannel(
            eventsChannelId,
            eventsChannelName,
            description: 'Canlı etkinlikler, güncellemeler ve ödül duyuruları',
            importance: Importance.max,
          ),
        );
        // Request Android 13+ POST_NOTIFICATIONS permission
        await androidPlugin.requestNotificationsPermission();
      } catch (e) {
        debugPrint('[NotificationService] Android channel error: $e');
      }
    }

    // 4. Firebase Cloud Messaging setup (Remote pushes)
    try {
      FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
      final messaging = FirebaseMessaging.instance;

      // Request iOS / Web notification permissions
      await messaging.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );

      // Subscribe to topic: 'all_players' (Allows 1-click broadcast from Firebase Console!)
      await messaging.subscribeToTopic('all_players');

      // In-app foreground push handler: display a native banner when notification arrives while app is open
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        final notification = message.notification;
        if (notification != null) {
          showInstantNotification(
            title: notification.title ?? I18n.tr('app_title'),
            body: notification.body ?? '',
            channelId: eventsChannelId,
            channelName: eventsChannelName,
          );
        }
      });
    } catch (e) {
      debugPrint('[NotificationService] FCM init warning: $e');
    }

    _initialized = true;
    scheduleSmartRetentionLoops();
  }

  /// Shows an immediate notification (used for FCM foreground messages or reward drops).
  Future<void> showInstantNotification({
    required String title,
    required String body,
    String channelId = eventsChannelId,
    String channelName = eventsChannelName,
    String? payload,
  }) async {
    final androidDetails = AndroidNotificationDetails(
      channelId,
      channelName,
      importance: Importance.max,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    );
    const darwinDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );
    final details = NotificationDetails(android: androidDetails, iOS: darwinDetails);

    try {
      await _localNotifications.show(
        id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
        title: title,
        body: body,
        notificationDetails: details,
        payload: payload,
      );
    } catch (e) {
      debugPrint('[NotificationService] Show instant error: $e');
    }
  }

  /// Schedules the Supercell-style retention cycle when the player leaves the game:
  /// - Loop 1 (4 hours): Aquarium AFK gold chest filled
  /// - Loop 2 (24 hours): Free Daily Fortune Wheel spin ready
  /// - Loop 3 (48 hours): Lucky Fish of the Day & Win Streak reminder
  Future<void> scheduleSmartRetentionLoops() async {
    if (!_initialized) return;

    try {
      // Cancel previous retention reminders to avoid clutter
      await _localNotifications.cancel(id: 101);
      await _localNotifications.cancel(id: 102);
      await _localNotifications.cancel(id: 103);

      final isTr = I18n.currentLang == 'tr';
      final now = tz.TZDateTime.now(tz.local);

      final androidDetails = const AndroidNotificationDetails(
        retentionChannelId,
        retentionChannelName,
        importance: Importance.high,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
      );
      const darwinDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );
      final details = NotificationDetails(android: androidDetails, iOS: darwinDetails);

      // Loop 1: 4 Hours - Offline Vault Full
      final time4h = now.add(const Duration(hours: 4));
      await _localNotifications.zonedSchedule(
        id: 101,
        title: isTr ? 'Akvaryum Kasası Doldu! 🐟' : 'Aquarium Vault is Full! 🐟',
        body: isTr
            ? 'Balıkların hazine sandığını altınla doldurdu! Toplamak için hemen dokun.'
            : 'Your fish have filled the chest with gold! Tap to collect.',
        scheduledDate: time4h,
        notificationDetails: details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      );

      // Loop 2: 24 Hours - Daily Fortune Wheel Free Spin
      final time24h = now.add(const Duration(hours: 24));
      await _localNotifications.zonedSchedule(
        id: 102,
        title: isTr ? 'Ücretsiz Şans Çarkı Hazır! 🎡' : 'Free Fortune Wheel Spin! 🎡',
        body: isTr
            ? 'Bugünkü bedava çarkıfelek hakkın seni bekliyor, hemen çevir ve incileri kap!'
            : 'Your free daily wheel spin is ready. Tap to spin & win pearls!',
        scheduledDate: time24h,
        notificationDetails: details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      );

      // Loop 3: 48 Hours - Comeback & Lucky Fish Bonus
      final time48h = now.add(const Duration(hours: 48));
      await _localNotifications.zonedSchedule(
        id: 103,
        title: isTr ? 'Günün Şanslı Balığı Seni Bekliyor! ⭐' : 'Lucky Fish of the Day! ⭐',
        body: isTr
            ? 'Akvaryumunu ziyaret et, 3 kat altın bonusunu kaçırma!'
            : 'Visit your aquarium now for 3x gold production!',
        scheduledDate: time48h,
        notificationDetails: details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      );

      debugPrint('[NotificationService] Supercell retention loops scheduled cleanly (+4h, +24h, +48h).');
    } catch (e) {
      debugPrint('[NotificationService] Retention scheduling warning: $e');
    }
  }
}
