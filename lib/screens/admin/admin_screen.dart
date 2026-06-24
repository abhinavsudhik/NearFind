import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../../models/order.dart';
import '../../providers/role_provider.dart';
import '../../services/firestore_service.dart';

class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  final _firestoreService = FirestoreService();
  final Set<String> _expandedOrderIds = {};
  late final Timer _timer;

  @override
  void initState() {
    super.initState();
    // Update the elapsed times every 30 seconds
    _timer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  Color _getStatusColor(OrderStatus status) {
    switch (status) {
      case OrderStatus.placed:
        return const Color(0xFFF57C00); // Dark Orange
      case OrderStatus.accepted:
        return const Color(0xFF1976D2); // Dark Blue
      case OrderStatus.packed:
        return const Color(0xFF6A1B9A); // Dark Purple
      case OrderStatus.readyForPickup:
        return const Color(0xFF00796B); // Dark Teal
      case OrderStatus.pickedUp:
        return const Color(0xFFC2185B); // Dark Pink
      case OrderStatus.delivered:
        return const Color(0xFF388E3C); // Dark Green
      case OrderStatus.cancelled:
        return const Color(0xFFD32F2F); // Dark Red
    }
  }

  String _formatTimeSince(DateTime placedAt) {
    final diff = DateTime.now().difference(placedAt);
    if (diff.inSeconds < 60) {
      return 'just now';
    } else if (diff.inMinutes < 60) {
      return '${diff.inMinutes}m ago';
    } else if (diff.inHours < 24) {
      return '${diff.inHours}h ago';
    } else {
      return '${diff.inDays}d ago';
    }
  }

  bool _isDeliveredToday(NearFindOrder order) {
    if (order.status != OrderStatus.delivered) return false;
    // Find the timestamp when it was actually delivered in statusHistory
    final deliveryEvent = order.statusHistory.firstWhere(
      (e) => e.status == OrderStatus.delivered,
      orElse: () => OrderStatusHistory(status: OrderStatus.delivered, timestamp: order.placedAt),
    );
    final deliveryDate = deliveryEvent.timestamp;
    final now = DateTime.now();
    return deliveryDate.year == now.year &&
        deliveryDate.month == now.month &&
        deliveryDate.day == now.day;
  }

  Widget _buildSummaryCard(List<NearFindOrder> orders) {
    final total = orders.length;
    final active = orders.where((o) =>
        o.status != OrderStatus.delivered && o.status != OrderStatus.cancelled).length;
    final deliveredToday = orders.where(_isDeliveredToday).length;

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      elevation: 0,
      margin: const EdgeInsets.all(16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      color: colorScheme.surfaceContainerLow,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildStatItem('Total Orders', '$total', colorScheme.primary),
            _buildDivider(),
            _buildStatItem('Active', '$active', const Color(0xFF1976D2)),
            _buildDivider(),
            _buildStatItem('Delivered Today', '$deliveredToday', const Color(0xFF388E3C)),
          ],
        ),
      ),
    );
  }

  Widget _buildDivider() {
    return Container(
      height: 24,
      width: 1,
      color: Theme.of(context).colorScheme.outlineVariant,
    );
  }

  Widget _buildStatItem(String label, String value, Color color) {
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildTimeline(NearFindOrder order) {
    final List<Widget> children = [];
    final history = order.statusHistory;

    for (int i = 0; i < history.length; i++) {
      final item = history[i];
      final label = NearFindOrder.statusLabel(item.status);
      final timeStr = DateFormat('h:mm a').format(item.timestamp);
      final color = _getStatusColor(item.status);

      children.add(
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: color.withValues(alpha: 0.2), width: 1),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                  color: color,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                timeStr,
                style: TextStyle(
                  fontSize: 10,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      );

      if (i < history.length - 1) {
        children.add(
          Icon(
            Icons.arrow_forward_rounded,
            size: 16,
            color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
          ),
        );
      }
    }

    return Padding(
      padding: const EdgeInsets.only(top: 12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Divider(),
          const SizedBox(height: 4),
          Text(
            'Order Timeline',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.start,
              children: children.map((w) {
                return Padding(
                  padding: const EdgeInsets.only(right: 4.0),
                  child: w,
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () {
            context.read<RoleProvider>().clearRole();
            Navigator.pushReplacementNamed(context, '/role-select');
          },
        ),
      ),
      body: StreamBuilder<List<NearFindOrder>>(
        stream: _firestoreService.getAllOrders(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Text(
                  'Error loading orders: ${snapshot.error}',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: colorScheme.error),
                ),
              ),
            );
          }

          final orders = snapshot.data ?? [];

          if (orders.isEmpty) {
            return Column(
              children: [
                _buildSummaryCard(orders),
                Expanded(
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.receipt_long_rounded,
                          size: 64,
                          color: colorScheme.onSurface.withValues(alpha: 0.25),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'No orders in the system',
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: colorScheme.onSurface.withValues(alpha: 0.5),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          }

          return Column(
            children: [
              _buildSummaryCard(orders),
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  itemCount: orders.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final order = orders[index];
                    final truncatedId = order.id.length > 8 ? order.id.substring(0, 8) : order.id;
                    final isExpanded = _expandedOrderIds.contains(order.id);
                    final statusColor = _getStatusColor(order.status);

                    return Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(
                          color: isExpanded
                              ? colorScheme.primary.withValues(alpha: 0.5)
                              : colorScheme.outlineVariant.withValues(alpha: 0.4),
                          width: isExpanded ? 1.5 : 1,
                        ),
                      ),
                      color: isExpanded
                          ? colorScheme.surfaceContainerHigh
                          : colorScheme.surfaceContainer,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: () {
                          setState(() {
                            if (isExpanded) {
                              _expandedOrderIds.remove(order.id);
                            } else {
                              _expandedOrderIds.add(order.id);
                            }
                          });
                        },
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Top Row: Order ID & Time Elapsed
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Order #$truncatedId',
                                    style: theme.textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      fontFamily: 'monospace',
                                    ),
                                  ),
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.access_time_rounded,
                                        size: 14,
                                        color: colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        _formatTimeSince(order.placedAt),
                                        style: theme.textTheme.bodySmall?.copyWith(
                                          color: colorScheme.onSurfaceVariant.withValues(alpha: 0.8),
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),

                              // Product & Qty + Status Chip
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          order.items.isEmpty
                                              ? 'No items'
                                              : order.items.length == 1
                                                  ? '${order.items[0].productName} × ${order.items[0].quantity}'
                                                  : '${order.items[0].productName} & ${order.items.length - 1} more',
                                          style: theme.textTheme.bodyLarge?.copyWith(
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Row(
                                          children: [
                                            Icon(
                                              Icons.storefront_rounded,
                                              size: 14,
                                              color: colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                                            ),
                                            const SizedBox(width: 4),
                                            Expanded(
                                              child: Text(
                                                order.retailerName,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: theme.textTheme.bodySmall?.copyWith(
                                                  color: colorScheme.onSurfaceVariant,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: statusColor.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: statusColor.withValues(alpha: 0.3), width: 1),
                                    ),
                                    child: Text(
                                      NearFindOrder.statusLabel(order.status),
                                      style: TextStyle(
                                        color: statusColor,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                ],
                              ),

                              // Expanded Items list & Timeline
                              if (isExpanded) ...[
                                const Divider(height: 24),
                                Text(
                                  'Items',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                ...order.items.map((item) => Padding(
                                      padding: const EdgeInsets.symmetric(vertical: 2),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            '${item.quantity}x ${item.productName}',
                                            style: theme.textTheme.bodyMedium,
                                          ),
                                          Text(
                                            '₹${item.totalPrice}',
                                            style: theme.textTheme.bodyMedium?.copyWith(
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                      ),
                                    )),
                                _buildTimeline(order),
                              ],
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
