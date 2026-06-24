import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/order.dart';
import '../models/product.dart';
import 'order_timer_service.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ── PRODUCTS ──────────────────────────────────────────────────────────

  /// Streams all products and filters client-side by [query] (case-insensitive).
  Stream<List<Product>> searchProducts(String query) {
    return _db.collection('products').snapshots().map((snapshot) {
      final lowerQuery = query.toLowerCase();
      return snapshot.docs
          .map((doc) => Product.fromFirestore(doc))
          .where((product) => product.name.toLowerCase().contains(lowerQuery))
          .toList();
    });
  }

  // ── ORDERS — Customer ────────────────────────────────────────────────

  /// Places a new order and decrements the retailer's stock atomically.
  ///
  /// Returns the newly created order document ID.
  Future<String> placeOrder({
    required String customerId,
    required String retailerId,
    required String retailerName,
    required List<OrderItem> items,
  }) async {
    final orderRef = _db.collection('orders').doc();
    final now = Timestamp.now();
    final orderId = orderRef.id;

    await _db.runTransaction((txn) async {
      // 1. Fetch all product documents first
      final productDocs = <String, DocumentSnapshot<Map<String, dynamic>>>{};
      for (final item in items) {
        if (!productDocs.containsKey(item.productId)) {
          final doc = await txn.get(_db.collection('products').doc(item.productId));
          if (!doc.exists) {
            throw Exception('Product ${item.productId} not found');
          }
          productDocs[item.productId] = doc;
        }
      }

      // 2. Perform validations and update stocks
      for (final item in items) {
        final productDoc = productDocs[item.productId]!;
        final data = productDoc.data()!;
        final retailers = List<Map<String, dynamic>>.from(
          data['retailers'] as List<dynamic>,
        );

        final idx = retailers.indexWhere((r) => r['retailerId'] == retailerId);
        if (idx == -1) {
          throw Exception('Retailer $retailerId not found on product ${item.productId}');
        }

        final currentStock = (retailers[idx]['stock'] as num).toInt();
        if (currentStock < item.quantity) {
          throw Exception('Insufficient stock for ${item.productName} (available: $currentStock)');
        }

        retailers[idx] = {
          ...retailers[idx],
          'stock': currentStock - item.quantity,
        };

        // Update stock inside transaction.
        txn.update(
          _db.collection('products').doc(item.productId),
          {'retailers': retailers},
        );
      }

      // 3. Create consolidated order inside transaction.
      txn.set(orderRef, {
        'customerId': customerId,
        'retailerId': retailerId,
        'retailerName': retailerName,
        'deliveryPartnerId': null,
        'items': items.map((e) => e.toMap()).toList(),
        'status': OrderStatus.placed.name,
        'placedAt': now,
        'statusHistory': [
          {
            'status': OrderStatus.placed.name,
            'timestamp': now,
          },
        ],
      });
    });

    return orderId;
  }

  /// Streams a single order document for real-time status tracking.
  Stream<NearFindOrder> watchOrder(String orderId) {
    return _db
        .collection('orders')
        .doc(orderId)
        .snapshots()
        .map((doc) => NearFindOrder.fromFirestore(doc));
  }

  /// Streams all orders belonging to [customerId], newest first.
  Stream<List<NearFindOrder>> getCustomerOrders(String customerId) {
    return _db
        .collection('orders')
        .where('customerId', isEqualTo: customerId)
        .snapshots()
        .map((snapshot) {
      final orders = snapshot.docs
          .map((doc) => NearFindOrder.fromFirestore(doc))
          .toList();
      orders.sort((a, b) => b.placedAt.compareTo(a.placedAt));
      return orders;
    });
  }

  // ── ORDERS — Retailer ────────────────────────────────────────────────

  /// Streams orders for [retailerId] that are newly placed (status == placed).
  Stream<List<NearFindOrder>> getPendingOrdersForRetailer(String retailerId) {
    return _db
        .collection('orders')
        .where('retailerId', isEqualTo: retailerId)
        .where('status', isEqualTo: OrderStatus.placed.name)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => NearFindOrder.fromFirestore(doc))
            .toList());
  }

  /// Streams orders for [retailerId] that are actively being processed
  /// (status in [accepted, packed]).
  Stream<List<NearFindOrder>> getActiveOrdersForRetailer(String retailerId) {
    return _db
        .collection('orders')
        .where('retailerId', isEqualTo: retailerId)
        .where('status',
            whereIn: [OrderStatus.accepted.name, OrderStatus.packed.name])
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => NearFindOrder.fromFirestore(doc))
            .toList());
  }

  /// Updates the order's status and appends the transition to statusHistory.
  Future<void> updateOrderStatus(String orderId, OrderStatus newStatus) async {
    await _db.collection('orders').doc(orderId).update({
      'status': newStatus.name,
      'statusHistory': FieldValue.arrayUnion([
        {
          'status': newStatus.name,
          'timestamp': Timestamp.now(),
        },
      ]),
    });

    if (newStatus == OrderStatus.readyForPickup) {
      OrderTimerService.instance.startDeliveryTimer(orderId, this);
    } else {
      OrderTimerService.instance.cancelTimer(orderId);
    }
  }

  /// Cancels an order with a [reason], setting status to cancelled.
  /// Also replenishes the retailer's stock for all items.
  Future<void> cancelOrder(String orderId, String reason) async {
    await _db.runTransaction((txn) async {
      final orderRef = _db.collection('orders').doc(orderId);
      final orderDoc = await txn.get(orderRef);

      if (!orderDoc.exists) {
        throw Exception('Order $orderId not found');
      }

      final orderData = orderDoc.data()!;
      final currentStatus = orderData['status'] as String;

      // If already cancelled, do not replenish stock again.
      if (currentStatus == OrderStatus.cancelled.name) {
        return;
      }

      final retailerId = orderData['retailerId'] as String;
      final rawItems = orderData['items'] as List<dynamic>? ?? [];
      final items = rawItems.map((e) => OrderItem.fromMap(e as Map<String, dynamic>)).toList();

      // Replenish the retailer's stock in the product document for each item.
      for (final item in items) {
        final productRef = _db.collection('products').doc(item.productId);
        final productDoc = await txn.get(productRef);

        if (productDoc.exists) {
          final productData = productDoc.data()!;
          final retailers = List<Map<String, dynamic>>.from(
            productData['retailers'] as List<dynamic>,
          );

          final idx = retailers.indexWhere((r) => r['retailerId'] == retailerId);
          if (idx != -1) {
            final currentStock = (retailers[idx]['stock'] as num).toInt();
            retailers[idx] = {
              ...retailers[idx],
              'stock': currentStock + item.quantity,
            };

            txn.update(productRef, {'retailers': retailers});
          }
        }
      }

      // Update order document.
      txn.update(orderRef, {
        'status': OrderStatus.cancelled.name,
        'cancellationReason': reason,
        'statusHistory': FieldValue.arrayUnion([
          {
            'status': OrderStatus.cancelled.name,
            'timestamp': Timestamp.now(),
            'comment': reason,
          },
        ]),
      });
    });

    OrderTimerService.instance.cancelTimer(orderId);
  }

  // ── ORDERS — Delivery Partner ────────────────────────────────────────

  /// Streams orders that are ready for pickup and not yet claimed by a
  /// delivery partner.
  Stream<List<NearFindOrder>> getAvailableDeliveries() {
    return _db
        .collection('orders')
        .where('status', isEqualTo: OrderStatus.readyForPickup.name)
        .where('deliveryPartnerId', isNull: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => NearFindOrder.fromFirestore(doc))
            .toList());
  }

  /// Assigns a delivery partner to an order. Status remains readyForPickup
  /// until the partner picks it up.
  Future<void> acceptDelivery(String orderId, String deliveryPartnerId) async {
    await _db.collection('orders').doc(orderId).update({
      'deliveryPartnerId': deliveryPartnerId,
    });
    OrderTimerService.instance.cancelTimer(orderId);
  }

  // ── ORDERS — Admin ───────────────────────────────────────────────────

  /// Streams every order in the system, newest first.
  Stream<List<NearFindOrder>> getAllOrders() {
    return _db
        .collection('orders')
        .orderBy('placedAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => NearFindOrder.fromFirestore(doc))
            .toList());
  }
}
