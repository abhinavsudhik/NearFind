import 'package:flutter/foundation.dart';
import '../models/product.dart';

class CartItem {
  final Product product;
  final RetailerStock retailer;
  int quantity;

  CartItem({
    required this.product,
    required this.retailer,
    required this.quantity,
  });

  int get totalPrice => retailer.price * quantity;
}

class CartProvider extends ChangeNotifier {
  final Map<String, CartItem> _items = {};

  Map<String, CartItem> get items => {..._items};

  int get itemCount => _items.values.fold(0, (sum, item) => sum + item.quantity);

  int get totalAmount => _items.values.fold(0, (sum, item) => sum + item.totalPrice);

  bool isInCart(String productId, String retailerId) {
    return _items.containsKey('${productId}_$retailerId');
  }

  int getItemQuantity(String productId, String retailerId) {
    return _items['${productId}_$retailerId']?.quantity ?? 0;
  }

  void addItem(Product product, RetailerStock retailer) {
    final key = '${product.id}_${retailer.retailerId}';
    if (_items.containsKey(key)) {
      if (_items[key]!.quantity < retailer.stock) {
        _items[key]!.quantity++;
      }
    } else {
      if (retailer.stock > 0) {
        _items[key] = CartItem(
          product: product,
          retailer: retailer,
          quantity: 1,
        );
      }
    }
    notifyListeners();
  }

  void decrementItem(Product product, RetailerStock retailer) {
    final key = '${product.id}_${retailer.retailerId}';
    if (!_items.containsKey(key)) return;

    if (_items[key]!.quantity <= 1) {
      _items.remove(key);
    } else {
      _items[key]!.quantity--;
    }
    notifyListeners();
  }

  void updateQuantity(String key, int quantity) {
    if (!_items.containsKey(key)) return;
    if (quantity <= 0) {
      _items.remove(key);
    } else {
      final stock = _items[key]!.retailer.stock;
      _items[key]!.quantity = quantity.clamp(1, stock);
    }
    notifyListeners();
  }

  void removeItem(String key) {
    _items.remove(key);
    notifyListeners();
  }

  void clearCart() {
    _items.clear();
    notifyListeners();
  }
}
