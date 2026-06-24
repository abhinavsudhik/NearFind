import 'dart:async';

import '../models/order.dart';
import 'firestore_service.dart';

/// Manages auto-cancellation timers for orders.
///
/// When a customer places an order the caller invokes [startTimer] which waits
/// [timerDuration] (default 2 minutes). If the retailer has not acted on the
/// order by then (status still [OrderStatus.placed]), the service automatically
/// cancels it via [FirestoreService.cancelOrder].
class OrderTimerService {
  // ── Singleton ────────────────────────────────────────────────────────
  OrderTimerService._internal();
  static final OrderTimerService instance = OrderTimerService._internal();

  /// How long to wait before auto-cancelling an order.
  static const Duration timerDuration = Duration(minutes: 2);

  /// Active timers keyed by order ID.
  final Map<String, Timer> _timers = {};

  /// Starts a countdown for [orderId].
  ///
  /// After [timerDuration] the service fetches the current order status from
  /// Firestore. If the status is still [OrderStatus.placed] the order is
  /// cancelled with an appropriate reason. If the retailer has already acted
  /// (accepted, packed, etc.) the timer is a no-op.
  ///
  /// Calling this again for the same [orderId] replaces the previous timer.
  void startTimer(String orderId, FirestoreService firestoreService) {
    // Cancel any existing timer for this order before starting a new one.
    cancelTimer(orderId);

    _timers[orderId] = Timer(timerDuration, () async {
      try {
        // Fetch the latest order snapshot to check the current status.
        final orderSnapshot = await firestoreService.watchOrder(orderId).first;

        if (orderSnapshot.status == OrderStatus.placed) {
          await firestoreService.cancelOrder(
            orderId,
            'Retailer did not respond in time',
          );
        }
      } catch (_) {
        // Order may have been deleted or is unreachable – silently ignore.
      } finally {
        _timers.remove(orderId);
      }
    });
  }

  /// Cancels a running timer for [orderId], if one exists.
  void cancelTimer(String orderId) {
    _timers[orderId]?.cancel();
    _timers.remove(orderId);
  }

  /// Starts a countdown of 3 minutes for [orderId] after it becomes ready for pickup.
  ///
  /// After 3 minutes, if no delivery partner has accepted the order
  /// (i.e. [deliveryPartnerId] is still null) and status is still
  /// [OrderStatus.readyForPickup], the order is automatically cancelled.
  void startDeliveryTimer(String orderId, FirestoreService firestoreService) {
    cancelTimer(orderId);

    _timers[orderId] = Timer(const Duration(minutes: 3), () async {
      try {
        final orderSnapshot = await firestoreService.watchOrder(orderId).first;

        if (orderSnapshot.deliveryPartnerId == null &&
            orderSnapshot.status == OrderStatus.readyForPickup) {
          await firestoreService.cancelOrder(
            orderId,
            'No delivery partner available',
          );
        }
      } catch (_) {
        // Silently ignore.
      } finally {
        _timers.remove(orderId);
      }
    });
  }

  /// Whether a timer is currently active for [orderId].
  bool isTimerActive(String orderId) => _timers.containsKey(orderId);

  /// Cancels **all** active timers (e.g. on logout or app dispose).
  void cancelAll() {
    for (final timer in _timers.values) {
      timer.cancel();
    }
    _timers.clear();
  }
}
