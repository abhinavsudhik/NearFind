import 'package:flutter/material.dart';

import '../../models/order.dart';
import '../../services/firestore_service.dart';
import '../../widgets/cancellation_banner.dart';

/// Real-time order tracking screen with a vertical stepper/timeline.
class OrderStatusScreen extends StatefulWidget {
  final String orderId;

  const OrderStatusScreen({super.key, required this.orderId});

  @override
  State<OrderStatusScreen> createState() => _OrderStatusScreenState();
}

class _OrderStatusScreenState extends State<OrderStatusScreen> {
  final _firestoreService = FirestoreService();

  /// The canonical left-to-right order of statuses shown in the stepper.
  static const _stepStatuses = [
    OrderStatus.placed,
    OrderStatus.accepted,
    OrderStatus.packed,
    OrderStatus.readyForPickup,
    OrderStatus.pickedUp,
    OrderStatus.delivered,
  ];

  // ── Build ──────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Order Status')),
      body: StreamBuilder<NearFindOrder>(
        stream: _firestoreService.watchOrder(widget.orderId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          if (!snapshot.hasData) {
            return const Center(child: Text('Order not found'));
          }

          final order = snapshot.data!;
          final isCancelled = order.status == OrderStatus.cancelled;
          final currentStepIndex = isCancelled
              ? -1
              : _stepStatuses.indexOf(order.status);

          String? cancellationReason = order.cancellationReason;
          if (cancellationReason == null || cancellationReason.isEmpty) {
            for (final history in order.statusHistory) {
              if (history.status == OrderStatus.cancelled &&
                  history.comment != null &&
                  history.comment!.isNotEmpty) {
                cancellationReason = history.comment;
                break;
              }
            }
          }

          final displayReason = cancellationReason ?? 'Retailer did not respond in time';
          final isRejection = cancellationReason != null &&
              !cancellationReason.toLowerCase().contains('time') &&
              !cancellationReason.toLowerCase().contains('no delivery partner');
          final displayStatus = isRejection ? 'rejected' : 'cancelled';

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // ── Cancellation banner (shows when status is 'placed') ─
              if (order.status == OrderStatus.placed)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: CancellationBanner(
                    orderId: widget.orderId,
                    firestoreService: _firestoreService,
                  ),
                ),

              // ── Cancelled banner ─────────────────────────────────────
              if (isCancelled)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.red.shade700,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.cancel_rounded,
                            color: Colors.white, size: 22),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Your order was $displayStatus: $displayReason',
                            style: textTheme.bodyMedium?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              // ── Timeline stepper ─────────────────────────────────────
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      vertical: 24, horizontal: 20),
                  child: Column(
                    children: List.generate(_stepStatuses.length, (i) {
                      final stepStatus = _stepStatuses[i];
                      final isCompleted =
                          !isCancelled && i <= currentStepIndex;
                      final isCurrent =
                          !isCancelled && i == currentStepIndex;
                      final isLast = i == _stepStatuses.length - 1;

                      return _TimelineStep(
                        label: NearFindOrder.statusLabel(stepStatus),
                        isCompleted: isCompleted,
                        isCurrent: isCurrent,
                        isCancelled: isCancelled,
                        isLast: isLast,
                        colorScheme: colorScheme,
                        textTheme: textTheme,
                      );
                    }),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // ── Order details ────────────────────────────────────────
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Order Details',
                        style: textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const Divider(height: 24),
                      _DetailRow(
                        label: 'Retailer',
                        value: order.retailerName,
                        textTheme: textTheme,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Items',
                        style: textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ...order.items.map((item) => Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    '${item.quantity}x ${item.productName}',
                                    style: textTheme.bodyMedium,
                                  ),
                                ),
                                Text(
                                  '₹${item.totalPrice}',
                                  style: textTheme.bodyMedium?.copyWith(
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          )),
                      const Divider(height: 24),
                      _DetailRow(
                        label: 'Total',
                        value: '₹${order.totalPrice}',
                        textTheme: textTheme,
                        bold: true,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ── Timeline step widget ──────────────────────────────────────────────────────

class _TimelineStep extends StatelessWidget {
  final String label;
  final bool isCompleted;
  final bool isCurrent;
  final bool isCancelled;
  final bool isLast;
  final ColorScheme colorScheme;
  final TextTheme textTheme;

  const _TimelineStep({
    required this.label,
    required this.isCompleted,
    required this.isCurrent,
    required this.isCancelled,
    required this.isLast,
    required this.colorScheme,
    required this.textTheme,
  });

  @override
  Widget build(BuildContext context) {
    // Determine dot colour.
    Color dotColor;
    Color dotBorderColor;
    Widget? dotChild;

    if (isCompleted && !isCurrent) {
      dotColor = Colors.green;
      dotBorderColor = Colors.green;
      dotChild = const Icon(Icons.check, size: 14, color: Colors.white);
    } else if (isCurrent) {
      dotColor = colorScheme.primary;
      dotBorderColor = colorScheme.primary;
      dotChild = null; // solid filled dot
    } else {
      dotColor = isCancelled
          ? Colors.grey.shade400
          : colorScheme.surfaceContainerHighest;
      dotBorderColor = isCancelled
          ? Colors.grey.shade400
          : colorScheme.outline.withValues(alpha: 0.4);
      dotChild = null;
    }

    // Text style.
    final labelStyle = textTheme.bodyMedium?.copyWith(
      fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
      color: isCompleted || isCurrent
          ? colorScheme.onSurface
          : colorScheme.onSurface.withValues(alpha: 0.4),
    );

    // Line colour (connecting to next step).
    final lineColor = isCompleted && !isCurrent
        ? Colors.green
        : colorScheme.outline.withValues(alpha: 0.2);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Dot + vertical line ─────────────────────────────────────
        SizedBox(
          width: 28,
          child: Column(
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: dotColor,
                  shape: BoxShape.circle,
                  border: Border.all(color: dotBorderColor, width: 2),
                ),
                child: dotChild != null
                    ? Center(child: dotChild)
                    : null,
              ),
              if (!isLast)
                Container(
                  width: 2,
                  height: 32,
                  color: lineColor,
                ),
            ],
          ),
        ),
        const SizedBox(width: 12),

        // ── Label ───────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Text(label, style: labelStyle),
        ),
      ],
    );
  }
}

// ── Detail row widget ─────────────────────────────────────────────────────────

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  final TextTheme textTheme;
  final bool bold;

  const _DetailRow({
    required this.label,
    required this.value,
    required this.textTheme,
    this.bold = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: textTheme.bodyMedium?.copyWith(
              color: Theme.of(context)
                  .colorScheme
                  .onSurface
                  .withValues(alpha: 0.6),
            ),
          ),
          Text(
            value,
            style: textTheme.bodyMedium?.copyWith(
              fontWeight: bold ? FontWeight.bold : FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
