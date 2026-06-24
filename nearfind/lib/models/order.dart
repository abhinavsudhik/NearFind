import 'package:cloud_firestore/cloud_firestore.dart';

enum OrderStatus {
  placed,
  accepted,
  packed,
  readyForPickup,
  pickedUp,
  delivered,
  cancelled,
}

class OrderStatusHistory {
  final OrderStatus status;
  final DateTime timestamp;
  final String? comment;

  const OrderStatusHistory({
    required this.status,
    required this.timestamp,
    this.comment,
  });

  factory OrderStatusHistory.fromMap(Map<String, dynamic> map) {
    return OrderStatusHistory(
      status: OrderStatus.values.byName(map['status'] as String),
      timestamp: (map['timestamp'] as Timestamp).toDate(),
      comment: map['comment'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'status': status.name,
      'timestamp': Timestamp.fromDate(timestamp),
      if (comment != null) 'comment': comment,
    };
  }
}

class OrderItem {
  final String productId;
  final String productName;
  final int quantity;
  final int pricePerUnit;

  const OrderItem({
    required this.productId,
    required this.productName,
    required this.quantity,
    required this.pricePerUnit,
  });

  int get totalPrice => quantity * pricePerUnit;

  factory OrderItem.fromMap(Map<String, dynamic> map) {
    return OrderItem(
      productId: map['productId'] as String,
      productName: map['productName'] as String,
      quantity: (map['quantity'] as num).toInt(),
      pricePerUnit: (map['pricePerUnit'] as num).toInt(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'productId': productId,
      'productName': productName,
      'quantity': quantity,
      'pricePerUnit': pricePerUnit,
    };
  }
}

class NearFindOrder {
  final String id;
  final String customerId;
  final String retailerId;
  final String retailerName;
  final String? deliveryPartnerId;
  final List<OrderItem> items;
  final OrderStatus status;
  final DateTime placedAt;
  final List<OrderStatusHistory> statusHistory;
  final String? cancellationReason;

  const NearFindOrder({
    required this.id,
    required this.customerId,
    required this.retailerId,
    required this.retailerName,
    this.deliveryPartnerId,
    required this.items,
    required this.status,
    required this.placedAt,
    required this.statusHistory,
    this.cancellationReason,
  });

  int get totalPrice => items.fold(0, (total, item) => total + item.totalPrice);

  static String statusLabel(OrderStatus s) {
    switch (s) {
      case OrderStatus.placed:
        return 'Placed';
      case OrderStatus.accepted:
        return 'Accepted';
      case OrderStatus.packed:
        return 'Packed';
      case OrderStatus.readyForPickup:
        return 'Ready for Pickup';
      case OrderStatus.pickedUp:
        return 'Picked Up';
      case OrderStatus.delivered:
        return 'Delivered';
      case OrderStatus.cancelled:
        return 'Cancelled';
    }
  }

  factory NearFindOrder.fromFirestore(
      DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    final historyList = (data['statusHistory'] as List<dynamic>?)
            ?.map(
                (e) => OrderStatusHistory.fromMap(e as Map<String, dynamic>))
            .toList() ??
        [];
    var itemsList = (data['items'] as List<dynamic>?)
            ?.map((e) => OrderItem.fromMap(e as Map<String, dynamic>))
            .toList() ??
        [];

    // Backward compatibility: migrate legacy single-item orders
    if (itemsList.isEmpty && data['productId'] != null) {
      itemsList = [
        OrderItem(
          productId: data['productId'] as String,
          productName: data['productName'] as String? ?? 'Unknown Product',
          quantity: (data['quantity'] as num?)?.toInt() ?? 1,
          pricePerUnit: (data['pricePerUnit'] as num?)?.toInt() ?? 0,
        ),
      ];
    }

    return NearFindOrder(
      id: doc.id,
      customerId: data['customerId'] as String,
      retailerId: data['retailerId'] as String,
      retailerName: data['retailerName'] as String,
      deliveryPartnerId: data['deliveryPartnerId'] as String?,
      items: itemsList,
      status: OrderStatus.values.byName(data['status'] as String),
      placedAt: (data['placedAt'] as Timestamp).toDate(),
      statusHistory: historyList,
      cancellationReason: data['cancellationReason'] as String?,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'customerId': customerId,
      'retailerId': retailerId,
      'retailerName': retailerName,
      'deliveryPartnerId': deliveryPartnerId,
      'items': items.map((e) => e.toMap()).toList(),
      'status': status.name,
      'placedAt': Timestamp.fromDate(placedAt),
      'statusHistory': statusHistory.map((e) => e.toMap()).toList(),
      if (cancellationReason != null) 'cancellationReason': cancellationReason,
    };
  }
}
