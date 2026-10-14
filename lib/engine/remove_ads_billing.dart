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
    _sub ??= _iap.purchaseStream.listen(_onPurchases, onError: (Object _) {});
    available = await _iap.isAvailable();
    if (!available) {
      notifyListeners();
      return;
    }
    final response = await _iap.queryProductDetails({productId});
    if (response.productDetails.isNotEmpty) {
      product = response.productDetails.first;
    }
    notifyListeners();
    await _iap.restorePurchases();
  }

  Future<bool> buy() async {
    if (SaveManager.instance.adsRemoved) return true;
    final details = product;
    if (!available || details == null) return false;
    return _iap.buyNonConsumable(purchaseParam: PurchaseParam(productDetails: details));
  }

  Future<void> _onPurchases(List<PurchaseDetails> purchases) async {
    for (final purchase in purchases) {
      if (purchase.productID != productId) continue;
      if (purchase.status == PurchaseStatus.purchased || purchase.status == PurchaseStatus.restored) {
        await SaveManager.instance.grantRemoveAds();
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
