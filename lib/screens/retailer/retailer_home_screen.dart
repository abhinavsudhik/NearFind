import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/order.dart';
import '../../providers/role_provider.dart';
import '../../services/firestore_service.dart';

/// Hardcoded retailer identity for the 48-hour prototype.
const _kRetailerId = 'sharma_kirana';
const _kRetailerName = 'Sharma Kirana Store';

/// The retailer's main dashboard.
///
/// Two tabs — **New Orders** (pending / placed) and **Active Orders**
/// (accepted / packed) — each backed by a Firestore real-time stream.
class RetailerHomeScreen extends StatefulWidget {
  const RetailerHomeScreen({super.key});

  @override
  State<RetailerHomeScreen> createState() => _RetailerHomeScreenState();
}

class _RetailerHomeScreenState extends State<RetailerHomeScreen>
    with SingleTickerProviderStateMixin {
  final _firestoreService = FirestoreService();
  late final TabController _tabController;

  /// Live count of pending orders, shown as a badge on the "New Orders" tab.
  int _pendingCount = 0;
  StreamSubscription<List<NearFindOrder>>? _pendingCountSub;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);

    // Listen to the pending-orders stream just for the badge count.
    _pendingCountSub = _firestoreService
        .getPendingOrdersForRetailer(_kRetailerId)
        .listen((orders) {
      if (mounted) setState(() => _pendingCount = orders.length);
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _pendingCountSub?.cancel();
    super.dispose();
  }

  // ── Build ──────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {

    return Scaffold(
      appBar: AppBar(
        title: const Text(_kRetailerName),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () {
            context.read<RoleProvider>().clearRole();
            Navigator.pushReplacementNamed(context, '/role-select');
          },
        ),
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('New Orders'),
                  if (_pendingCount > 0) ...[
                    const SizedBox(width: 8),
                    _Badge(count: _pendingCount),
                  ],
                ],
              ),
            ),
            const Tab(text: 'Active Orders'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _NewOrdersTab(firestoreService: _firestoreService),
          _ActiveOrdersTab(firestoreService: _firestoreService),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// TAB 1 — New Orders (status == placed)
// ═══════════════════════════════════════════════════════════════════════════════

class _NewOrdersTab extends StatelessWidget {
  final FirestoreService firestoreService;

  const _NewOrdersTab({required this.firestoreService});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<NearFindOrder>>(
      stream: firestoreService.getPendingOrdersForRetailer(_kRetailerId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        final orders = snapshot.data ?? [];

        if (orders.isEmpty) {
          return _EmptyState(
            icon: Icons.inbox_rounded,
            title: 'No new orders',
            subtitle: 'New customer orders will appear here.',
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: orders.length,
          separatorBuilder: (_, _) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final order = orders[index];
            return _PendingOrderCard(
              order: order,
              firestoreService: firestoreService,
            );
          },
        );
      },
    );
  }
}

// ── Pending order card ────────────────────────────────────────────────────────

class _PendingOrderCard extends StatelessWidget {
  final NearFindOrder order;
  final FirestoreService firestoreService;

  const _PendingOrderCard({
    required this.order,
    required this.firestoreService,
  });

  /// Returns a human-friendly "time ago" string from [dateTime].
  String _timeAgo(DateTime dateTime) {
    final diff = DateTime.now().difference(dateTime);
    if (diff.inSeconds < 60) return '${diff.inSeconds}s ago';
    if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  Future<void> _handleAccept(BuildContext context) async {
    try {
      await firestoreService.updateOrderStatus(
          order.id, OrderStatus.accepted);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Order accepted ✓')),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to accept: $e')),
      );
    }
  }

  Future<void> _handleReject(BuildContext context) async {
    final reason = await showDialog<String>(
      context: context,
      builder: (ctx) => _RejectReasonDialog(),
    );

    if (reason == null || reason.trim().isEmpty) return;

    try {
      await firestoreService.cancelOrder(order.id, reason.trim());
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Order rejected')),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to reject: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final truncatedId = order.id.length > 8 ? order.id.substring(0, 8) : order.id;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header: Order ID + time ago ──────────────────────
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Order #$truncatedId',
                    style: textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
                Icon(
                  Icons.access_time_rounded,
                  size: 14,
                  color: colorScheme.onSurface.withValues(alpha: 0.5),
                ),
                const SizedBox(width: 4),
                Text(
                  _timeAgo(order.placedAt),
                  style: textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurface.withValues(alpha: 0.5),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // ── Items List ──────────────────────────────────────────
            ...order.items.map((item) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${item.quantity}x ${item.productName}',
                          style: textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      Text(
                        '₹${item.totalPrice}',
                        style: textTheme.bodyMedium,
                      ),
                    ],
                  ),
                )),
            const Divider(height: 20),

            // ── Total row ──────────────────────────────────────────
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Total Amount:',
                  style: textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
                Text(
                  '₹${order.totalPrice}',
                  style: textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // ── Action buttons ───────────────────────────────────────
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () => _handleAccept(context),
                    icon: const Icon(Icons.check_rounded, size: 18),
                    label: const Text('Accept'),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF43A047),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () => _handleReject(context),
                    icon: const Icon(Icons.close_rounded, size: 18),
                    label: const Text('Reject'),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFFE53935),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Reject reason dialog ──────────────────────────────────────────────────────

class _RejectReasonDialog extends StatefulWidget {
  @override
  State<_RejectReasonDialog> createState() => _RejectReasonDialogState();
}

class _RejectReasonDialogState extends State<_RejectReasonDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Reject Order'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        maxLines: 3,
        decoration: const InputDecoration(
          hintText: 'Reason for rejection…',
          border: OutlineInputBorder(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            if (_controller.text.trim().isEmpty) return;
            Navigator.pop(context, _controller.text);
          },
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFFE53935),
          ),
          child: const Text('Reject'),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// TAB 2 — Active Orders (status in [accepted, packed])
// ═══════════════════════════════════════════════════════════════════════════════

class _ActiveOrdersTab extends StatelessWidget {
  final FirestoreService firestoreService;

  const _ActiveOrdersTab({required this.firestoreService});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<NearFindOrder>>(
      stream: firestoreService.getActiveOrdersForRetailer(_kRetailerId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        final orders = snapshot.data ?? [];

        if (orders.isEmpty) {
          return _EmptyState(
            icon: Icons.check_circle_outline_rounded,
            title: 'No active orders',
            subtitle: 'Accepted orders will appear here.',
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: orders.length,
          separatorBuilder: (_, _) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final order = orders[index];
            return _ActiveOrderCard(
              order: order,
              firestoreService: firestoreService,
            );
          },
        );
      },
    );
  }
}

// ── Active order card ─────────────────────────────────────────────────────────

class _ActiveOrderCard extends StatelessWidget {
  final NearFindOrder order;
  final FirestoreService firestoreService;

  const _ActiveOrderCard({
    required this.order,
    required this.firestoreService,
  });

  Color _statusColor(OrderStatus status) {
    switch (status) {
      case OrderStatus.accepted:
        return const Color(0xFF2196F3); // blue
      case OrderStatus.packed:
        return const Color(0xFF7B1FA2); // purple
      default:
        return Colors.grey;
    }
  }

  /// Returns the next status transition label and target, or `null` if the
  /// order has progressed past what this tab handles.
  ({String label, IconData icon, OrderStatus next})? _nextAction() {
    switch (order.status) {
      case OrderStatus.accepted:
        return (
          label: 'Mark Packed',
          icon: Icons.inventory_rounded,
          next: OrderStatus.packed,
        );
      case OrderStatus.packed:
        return (
          label: 'Mark Ready for Pickup',
          icon: Icons.local_shipping_rounded,
          next: OrderStatus.readyForPickup,
        );
      default:
        return null;
    }
  }

  Future<void> _advanceStatus(BuildContext context, OrderStatus next) async {
    try {
      await firestoreService.updateOrderStatus(order.id, next);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Updated to ${NearFindOrder.statusLabel(next)}')),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Update failed: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    final action = _nextAction();
    final truncatedId = order.id.length > 8 ? order.id.substring(0, 8) : order.id;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header: Order ID + status badge ──────────────────
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Order #$truncatedId',
                    style: textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
                Chip(
                  label: Text(
                    NearFindOrder.statusLabel(order.status),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  backgroundColor: _statusColor(order.status),
                  padding: EdgeInsets.zero,
                  visualDensity: VisualDensity.compact,
                  side: BorderSide.none,
                ),
              ],
            ),
            const SizedBox(height: 12),

            // ── Items List ──────────────────────────────────────────
            ...order.items.map((item) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${item.quantity}x ${item.productName}',
                          style: textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      Text(
                        '₹${item.totalPrice}',
                        style: textTheme.bodyMedium,
                      ),
                    ],
                  ),
                )),
            const Divider(height: 20),

            // ── Total row ──────────────────────────────────────────
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Total Amount:',
                  style: textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
                Text(
                  '₹${order.totalPrice}',
                  style: textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.primary,
                  ),
                ),
              ],
            ),

            // ── Action button (if applicable) ────────────────────────
            if (action != null) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () => _advanceStatus(context, action.next),
                  icon: Icon(action.icon, size: 18),
                  label: Text(action.label),
                  style: FilledButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Shared widgets
// ═══════════════════════════════════════════════════════════════════════════════

/// Small informational chip used inside order cards.
class _DetailChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _DetailChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: colorScheme.onSurface.withValues(alpha: 0.6)),
          const SizedBox(width: 4),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
          ),
        ],
      ),
    );
  }
}

/// Generic empty-state placeholder for both tabs.
class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _EmptyState({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 64,
            color: colorScheme.onSurface.withValues(alpha: 0.25),
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: textTheme.bodyLarge?.copyWith(
              color: colorScheme.onSurface.withValues(alpha: 0.5),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurface.withValues(alpha: 0.4),
            ),
          ),
        ],
      ),
    );
  }
}

/// Small circular badge showing the count of pending orders.
class _Badge extends StatelessWidget {
  final int count;

  const _Badge({required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xFFE53935),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        count > 99 ? '99+' : '$count',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
