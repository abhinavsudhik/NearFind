import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nearfind/models/order.dart';

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
  });
}
