import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import '../storage/save_manager.dart';

class RemoveAdsBilling extends ChangeNotifier {
  static final RemoveAdsBilling instance = RemoveAdsBilling._();
  RemoveAdsBilling._();

  static const productId = 'remove_ads';

  final InAppPurchase _iap = InAppPurchase.instance;
  StreamSubscription<List<PurchaseDetails>>? _sub;
  ProductDetails? product;
  bool available = false;

  String get priceLabel => product?.price ?? r'$1.99';

  Future<void> init() async {
    _sub ??= _iap.purchaseStream.listen(_onPurchases, onError: (Object err) {
      debugPrint('[Billing] purchaseStream error: $err');
    });
    try {
      available = await _iap.isAvailable();
      if (!available) {
        debugPrint('[Billing] InAppPurchase is NOT available on this device');
        notifyListeners();
        return;
      }
      final response = await _iap.queryProductDetails({productId});
      if (response.error != null) {
        debugPrint('[Billing] queryProductDetails error: ${response.error}');
      }
      if (response.notFoundIDs.isNotEmpty) {
        debugPrint('[Billing] Products not found: ${response.notFoundIDs}');
      }
      if (response.productDetails.isNotEmpty) {
        product = response.productDetails.first;
        debugPrint('[Billing] Found product: ${product?.id}, price: ${product?.price}');
      }
      notifyListeners();
      await _iap.restorePurchases();
    } catch (e, st) {
      debugPrint('[Billing] Error during billing init: $e\n$st');
    }
  }

  Future<bool> buy() async {
    if (SaveManager.instance.adsRemoved) return true;

    try {
      if (!available) {
        available = await _iap.isAvailable();
      }
      if (!available) {
        debugPrint('[Billing] Cannot buy: billing service not available');
        return false;
      }

      // If product details wasn't fetched during startup, try re-querying once
      if (product == null) {
        final response = await _iap.queryProductDetails({productId});
        if (response.productDetails.isNotEmpty) {
          product = response.productDetails.first;
          notifyListeners();
        } else {
          debugPrint('[Billing] Cannot buy: product $productId not found in store (notFound: ${response.notFoundIDs}, error: ${response.error})');
        }
      }

      final details = product;
      if (details == null) return false;

      debugPrint('[Billing] Launching purchase for: ${details.id}');
      return await _iap.buyNonConsumable(purchaseParam: PurchaseParam(productDetails: details));
    } catch (e, st) {
      debugPrint('[Billing] Error launching purchase: $e\n$st');
      return false;
    }
  }

  Future<void> _onPurchases(List<PurchaseDetails> purchases) async {
    for (final purchase in purchases) {
      if (purchase.productID != productId) continue;
      debugPrint('[Billing] Purchase update for $productId: status=${purchase.status}');
      if (purchase.status == PurchaseStatus.purchased || purchase.status == PurchaseStatus.restored) {
        await SaveManager.instance.grantRemoveAds();
        debugPrint('[Billing] Ads successfully removed for user!');
      } else if (purchase.status == PurchaseStatus.error) {
        debugPrint('[Billing] Purchase error: ${purchase.error}');
      }
      if (purchase.pendingCompletePurchase) {
        await _iap.completePurchase(purchase);
      }
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
