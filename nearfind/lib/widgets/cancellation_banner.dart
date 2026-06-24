import 'dart:async';

import 'package:flutter/material.dart';

import '../models/order.dart';
import '../services/firestore_service.dart';

/// A banner that displays a live countdown while an order awaits retailer
/// acceptance, shows a cancellation notice if the order is auto-cancelled,
/// and disappears once the retailer has acted.
class CancellationBanner extends StatefulWidget {
  /// The Firestore order document ID to observe.
  final String orderId;

  /// The [FirestoreService] instance used to stream order updates.
  final FirestoreService firestoreService;

  const CancellationBanner({
    super.key,
    required this.orderId,
    required this.firestoreService,
  });

  @override
  State<CancellationBanner> createState() => _CancellationBannerState();
}

class _CancellationBannerState extends State<CancellationBanner> {
  /// Tick timer that drives the countdown display.
  Timer? _tickTimer;

  /// The wall-clock time at which the order will be auto-cancelled.
  DateTime? _deadline;

  /// Remaining seconds on the countdown (updated every second).
  int _remainingSeconds = 120; // 2 minutes

  @override
  void dispose() {
    _tickTimer?.cancel();
    super.dispose();
  }

  // ── Helpers ──────────────────────────────────────────────────────────

  /// Formats total [seconds] into "M:SS".
  String _formatCountdown(int seconds) {
    if (seconds <= 0) return '0:00';
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  /// Starts (or restarts) the per-second tick timer that updates the
  /// displayed countdown.
  void _ensureTickTimer(DateTime placedAt) {
    // Compute the deadline once based on when the order was placed.
    _deadline ??= placedAt.add(const Duration(minutes: 2));

    _tickTimer ??= Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      final now = DateTime.now();
      final diff = _deadline!.difference(now).inSeconds;
      setState(() {
        _remainingSeconds = diff > 0 ? diff : 0;
      });
    });

    // Also compute the initial value immediately so the first frame is
    // accurate rather than showing a stale "2:00".
    final now = DateTime.now();
    final diff = _deadline!.difference(now).inSeconds;
    _remainingSeconds = diff > 0 ? diff : 0;
  }

  // ── Build ────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<NearFindOrder>(
      stream: widget.firestoreService.watchOrder(widget.orderId),
      builder: (context, snapshot) {
        // While loading, show nothing.
        if (!snapshot.hasData) return const SizedBox.shrink();

        final order = snapshot.data!;

        // ── Cancelled ─────────────────────────────────────────────────
        if (order.status == OrderStatus.cancelled) {
          _tickTimer?.cancel();
          _tickTimer = null;
          return Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.red.shade700,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Row(
              children: [
                Icon(Icons.cancel, color: Colors.white, size: 20),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Order auto-cancelled — retailer did not respond',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          );
        }

        // ── Retailer acted (accepted or beyond) ──────────────────────
        if (order.status != OrderStatus.placed) {
          _tickTimer?.cancel();
          _tickTimer = null;
          return const SizedBox.shrink();
        }

        // ── Still placed — show countdown ────────────────────────────
        _ensureTickTimer(order.placedAt);

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.orange.shade800,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              const Icon(Icons.timer, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '⏱ Retailer has ${_formatCountdown(_remainingSeconds)} to accept',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
