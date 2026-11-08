import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import '../storage/save_manager.dart';
import 'i18n.dart';

/// Manages version verification against remote configuration and prompts the
/// player to update their game when a newer release is published.
class AppUpdateManager {
  static final AppUpdateManager instance = AppUpdateManager._internal();
  AppUpdateManager._internal();

  /// Current build version code (pubspec: 1.0.118+119)
  static const int currentVersionCode = 119;
  static const String currentVersionName = '1.0.118';
  static const String defaultStoreUrl =
      'https://play.google.com/store/apps/details?id=com.kaunos.kirmatas';
  static const String marketUrl =
      'market://details?id=com.kaunos.kirmatas';

  bool _checkedThisSession = false;
  bool isPostponedThisSession = false;

  /// Checks Firestore for remote version config and prompts if a newer version exists.
  /// Returns true if an update dialog was presented.
  Future<bool> checkAndPromptUpdate(BuildContext context) async {
    if (_checkedThisSession || isPostponedThisSession) return false;
    final save = SaveManager.instance;
    if (save.isUpdatePostponedRecently()) return false;

    _checkedThisSession = true;

    try {
      final doc = await FirebaseFirestore.instance
          .collection('app_config')
          .doc('version')
          .get()
          .timeout(const Duration(milliseconds: 2500));

      if (!doc.exists || doc.data() == null) return false;
      final data = doc.data()!;
      final latestCode = (data['latest_version_code'] as num?)?.toInt() ?? currentVersionCode;
      final remoteStoreUrl = (data['update_url'] as String?) ?? defaultStoreUrl;

      if (latestCode > currentVersionCode && context.mounted) {
        await showUpdateDialog(context, storeUrl: remoteStoreUrl);
        return true;
      }
    } catch (_) {
      // Defensive fallback: runs smoothly offline or if Firestore is unprovisioned
    }
    return false;
  }

  /// Opens the store page via native market intent or web URL.
  Future<void> openStorePage({String? url}) async {
    final targetUrl = url ?? defaultStoreUrl;
    try {
      final marketUri = Uri.parse(marketUrl);
      if (await canLaunchUrl(marketUri)) {
        await launchUrl(marketUri, mode: LaunchMode.externalApplication);
        return;
      }
    } catch (_) {}

    try {
      final webUri = Uri.parse(targetUrl);
      await launchUrl(webUri, mode: LaunchMode.externalApplication);
    } catch (_) {}
  }

  /// Shows the update modal with "Güncelle" (Update) and "Ertele" (Postpone) buttons.
  Future<void> showUpdateDialog(BuildContext context, {String? storeUrl}) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dlgContext) => Dialog(
        backgroundColor: const Color(0xFF101422),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: const BorderSide(color: Color(0xFF00E5FF), width: 1.5),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 68,
                height: 68,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [Color(0xFF00E5FF), Color(0xFF0D47A1)],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Color(0x6600E5FF),
                      blurRadius: 18,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.system_update_alt_rounded,
                  color: Colors.white,
                  size: 38,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                I18n.tr('update_available_title'),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 20,
                  fontFamily: 'Rajdhani',
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                I18n.tr('update_available_desc'),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFFB0BEC5),
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                          side: const BorderSide(color: Colors.white24),
                        ),
                      ),
                      onPressed: () async {
                        isPostponedThisSession = true;
                        await SaveManager.instance.postponeUpdate();
                        if (dlgContext.mounted) {
                          Navigator.of(dlgContext).pop();
                        }
                      },
                      child: Text(
                        I18n.tr('update_postpone_btn'),
                        style: const TextStyle(
                          color: Colors.white70,
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF00E5FF),
                        foregroundColor: const Color(0xFF050B14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        elevation: 4,
                      ),
                      onPressed: () async {
                        await openStorePage(url: storeUrl);
                      },
                      child: Text(
                        I18n.tr('update_btn'),
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 15,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
