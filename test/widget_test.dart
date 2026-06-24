import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nearfind/models/order.dart';

// ignore: subtype_of_sealed_class
class MockDocumentSnapshot implements DocumentSnapshot<Map<String, dynamic>> {
  final String _id;
  final Map<String, dynamic>? _data;

  MockDocumentSnapshot(this._id, this._data);

  @override
  String get id => _id;

  @override
  Map<String, dynamic>? data() => _data;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  test('Smoke test', () {
    expect(true, true);
  });

  group('NearFindOrder and OrderStatusHistory parsing tests', () {
    test('Parses cancellationReason and statusHistory comment', () {
      final historyMap = [
        {
          'status': 'placed',
          'timestamp': Timestamp.fromDate(DateTime(2026, 6, 24, 12, 0)),
        },
        {
          'status': 'cancelled',
          'timestamp': Timestamp.fromDate(DateTime(2026, 6, 24, 12, 5)),
          'comment': 'No delivery partner available',
        }
      ];

      final history = historyMap.map((m) => OrderStatusHistory.fromMap(m)).toList();

      expect(history[1].comment, 'No delivery partner available');

      // Test serialization
      final serialized = history[1].toMap();
      expect(serialized['comment'], 'No delivery partner available');
    });

    test('Parses NearFindOrder with consolidated multiple items', () {
      final orderData = {
        'customerId': 'cust_123',
        'retailerId': 'retail_456',
        'retailerName': 'Sharma Kirana Store',
        'deliveryPartnerId': 'rider_789',
        'status': 'placed',
        'placedAt': Timestamp.fromDate(DateTime(2026, 6, 24, 12, 0)),
        'statusHistory': [
          {
            'status': 'placed',
            'timestamp': Timestamp.fromDate(DateTime(2026, 6, 24, 12, 0)),
          }
        ],
        'items': [
          {
            'productId': 'prod_maggi',
            'productName': 'Maggi Noodles',
            'quantity': 3,
            'pricePerUnit': 14,
          },
          {
            'productId': 'prod_salt',
            'productName': 'Tata Salt',
            'quantity': 1,
            'pricePerUnit': 25,
          }
        ],
      };

      final snapshot = MockDocumentSnapshot('order_id_abc', orderData);
      final order = NearFindOrder.fromFirestore(snapshot);

      expect(order.id, 'order_id_abc');
      expect(order.customerId, 'cust_123');
      expect(order.retailerName, 'Sharma Kirana Store');
      expect(order.items.length, 2);
      expect(order.items[0].productName, 'Maggi Noodles');
      expect(order.items[0].totalPrice, 42);
      expect(order.items[1].productName, 'Tata Salt');
      expect(order.items[1].totalPrice, 25);
      expect(order.totalPrice, 67); // 42 + 25

      // Test serialization
      final serialized = order.toFirestore();
      expect(serialized['customerId'], 'cust_123');
      expect((serialized['items'] as List).length, 2);
      expect((serialized['items'] as List)[0]['productName'], 'Maggi Noodles');
    });
  });
}
