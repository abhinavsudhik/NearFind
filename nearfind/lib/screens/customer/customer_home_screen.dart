import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/order.dart';
import '../../models/product.dart';
import '../../providers/cart_provider.dart';
import '../../providers/role_provider.dart';
import '../../services/firestore_service.dart';
import '../../services/order_timer_service.dart';
import 'order_status_screen.dart';

/// The main customer portal screen featuring a bottom navigation bar:
/// 1. Shop Tab: Browse all available products in real-time with inline search.
/// 2. Orders Tab: Track placed orders and their live status histories.
class CustomerHomeScreen extends StatefulWidget {
  const CustomerHomeScreen({super.key});

  @override
  State<CustomerHomeScreen> createState() => _CustomerHomeScreenState();
}

class _CustomerHomeScreenState extends State<CustomerHomeScreen> {
  final _firestoreService = FirestoreService();
  final _searchController = TextEditingController();
  int _currentIndex = 0;
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // ── Place order & Cart flows ───────────────────────────────────────────

  Future<void> _handleCheckout(BuildContext context, CartProvider cart) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(
        child: CircularProgressIndicator(),
      ),
    );

    final uid = context.read<RoleProvider>().uid ?? '';
    final items = cart.items.values.toList();
    int placedCount = 0;
    List<String> failedItems = [];

    for (final item in items) {
      try {
        final orderId = await _firestoreService.placeOrder(
          customerId: uid,
          productId: item.product.id,
          productName: item.product.name,
          retailerId: item.retailer.retailerId,
          retailerName: item.retailer.retailerName,
          quantity: item.quantity,
          pricePerUnit: item.retailer.price,
        );

        OrderTimerService.instance.startTimer(orderId, _firestoreService);
        placedCount++;
      } catch (e) {
        failedItems.add(item.product.name);
      }
    }

    if (context.mounted) {
      Navigator.pop(context); // Pop loading dialog
      Navigator.pop(context); // Close cart sheet
    }

    if (placedCount > 0) {
      cart.clearCart();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Successfully placed $placedCount order(s)!'),
            backgroundColor: Colors.green.shade700,
          ),
        );
        setState(() {
          _currentIndex = 1;
        });
      }
    }

    if (failedItems.isNotEmpty && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to place order for: ${failedItems.join(', ')}'),
          backgroundColor: Colors.red.shade700,
        ),
      );
    }
  }

  void _showCartSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return DraggableScrollableSheet(
          initialChildSize: 0.6,
          minChildSize: 0.4,
          maxChildSize: 0.9,
          expand: false,
          builder: (scrollContext, scrollController) {
            return Consumer<CartProvider>(
              builder: (ctx, cart, child) {
                final items = cart.items.values.toList();
                final keys = cart.items.keys.toList();

                if (items.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.shopping_cart_outlined,
                          size: 64,
                          color: Theme.of(ctx).colorScheme.onSurface.withValues(alpha: 0.3),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Your cart is empty',
                          style: Theme.of(ctx).textTheme.bodyLarge?.copyWith(
                                color: Theme.of(ctx).colorScheme.onSurface.withValues(alpha: 0.5),
                              ),
                        ),
                      ],
                    ),
                  );
                }

                return Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Shopping Cart',
                            style: Theme.of(ctx).textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                          TextButton.icon(
                            onPressed: () => cart.clearCart(),
                            icon: const Icon(Icons.delete_outline_rounded, size: 18),
                            label: const Text('Clear All'),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1),
                    Expanded(
                      child: ListView.separated(
                        controller: scrollController,
                        padding: const EdgeInsets.all(16),
                        itemCount: items.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (itemCtx, index) {
                          final item = items[index];
                          final itemKey = keys[index];
                          final colorScheme = Theme.of(itemCtx).colorScheme;
                          final textTheme = Theme.of(itemCtx).textTheme;

                          return Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      item.product.name,
                                      style: textTheme.titleMedium?.copyWith(
                                            fontWeight: FontWeight.bold,
                                          ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'From ${item.retailer.retailerName}  •  ₹${item.retailer.price} each',
                                      style: textTheme.bodySmall?.copyWith(
                                            color: colorScheme.onSurface.withValues(alpha: 0.6),
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                decoration: BoxDecoration(
                                  color: colorScheme.secondaryContainer,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      onPressed: () => cart.decrementItem(item.product, item.retailer),
                                      icon: const Icon(Icons.remove, size: 16),
                                      constraints: const BoxConstraints(),
                                      padding: const EdgeInsets.all(8),
                                      style: IconButton.styleFrom(
                                        visualDensity: VisualDensity.compact,
                                      ),
                                    ),
                                    Text(
                                      '${item.quantity}',
                                      style: textTheme.bodyMedium?.copyWith(
                                            fontWeight: FontWeight.bold,
                                            color: colorScheme.onSecondaryContainer,
                                          ),
                                    ),
                                    IconButton(
                                      onPressed: () => cart.addItem(item.product, item.retailer),
                                      icon: const Icon(Icons.add, size: 16),
                                      constraints: const BoxConstraints(),
                                      padding: const EdgeInsets.all(8),
                                      style: IconButton.styleFrom(
                                        visualDensity: VisualDensity.compact,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 16),
                              SizedBox(
                                width: 60,
                                child: Align(
                                  alignment: Alignment.centerRight,
                                  child: Text(
                                    '₹${item.totalPrice}',
                                    style: textTheme.titleMedium?.copyWith(
                                          fontWeight: FontWeight.bold,
                                        ),
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                    const Divider(height: 1),
                    SafeArea(
                      top: false,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Total amount:',
                                  style: Theme.of(ctx).textTheme.titleMedium,
                                ),
                                Text(
                                  '₹${cart.totalAmount}',
                                  style: Theme.of(ctx).textTheme.headlineSmall?.copyWith(
                                        fontWeight: FontWeight.bold,
                                        color: Theme.of(ctx).colorScheme.primary,
                                      ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            FilledButton.icon(
                              onPressed: () => _handleCheckout(ctx, cart),
                              icon: const Icon(Icons.shopping_bag_rounded),
                              label: const Text('Place Order'),
                              style: FilledButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }

  // ── Status badge helpers ───────────────────────────────────────────────

  Color _statusColor(OrderStatus status) {
    switch (status) {
      case OrderStatus.placed:
        return Colors.orange;
      case OrderStatus.accepted:
        return Colors.blue;
      case OrderStatus.packed:
        return Colors.indigo;
      case OrderStatus.readyForPickup:
        return Colors.teal;
      case OrderStatus.pickedUp:
        return Colors.cyan;
      case OrderStatus.delivered:
        return Colors.green;
      case OrderStatus.cancelled:
        return Colors.red;
    }
  }

  // ── Shop tab view ──────────────────────────────────────────────────────

  Widget _buildShopTab(ColorScheme colorScheme, TextTheme textTheme) {
    return Column(
      children: [
        // Search bar
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: TextField(
            controller: _searchController,
            textInputAction: TextInputAction.search,
            onChanged: (val) {
              setState(() {
                _searchQuery = val;
              });
            },
            decoration: InputDecoration(
              hintText: 'Search for products…',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear_rounded),
                      onPressed: () {
                        _searchController.clear();
                        setState(() {
                          _searchQuery = '';
                        });
                      },
                    )
                  : null,
              filled: true,
              fillColor: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),

        // Product list stream
        Expanded(
          child: StreamBuilder<List<Product>>(
            stream: _firestoreService.searchProducts(_searchQuery),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (snapshot.hasError) {
                return Center(child: Text('Error: ${snapshot.error}'));
              }

              final products = snapshot.data ?? [];

              if (products.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.search_off_rounded,
                        size: 64,
                        color: colorScheme.onSurface.withValues(alpha: 0.3),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'No products found',
                        style: textTheme.bodyLarge?.copyWith(
                          color: colorScheme.onSurface.withValues(alpha: 0.5),
                        ),
                      ),
                    ],
                  ),
                );
              }

              return ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: products.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final product = products[index];
                  return _ProductCard(
                    product: product,
                    colorScheme: colorScheme,
                    textTheme: textTheme,
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  // ── Orders tab view ────────────────────────────────────────────────────

  Widget _buildOrdersTab(String uid, ColorScheme colorScheme, TextTheme textTheme) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Your Orders',
              style: textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        Expanded(
          child: StreamBuilder<List<NearFindOrder>>(
            stream: _firestoreService.getCustomerOrders(uid),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (snapshot.hasError) {
                return Center(
                  child: Text('Error: ${snapshot.error}'),
                );
              }

              final orders = snapshot.data ?? [];

              if (orders.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.shopping_bag_outlined,
                        size: 64,
                        color: colorScheme.onSurface.withValues(alpha: 0.3),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'No orders yet',
                        style: textTheme.bodyLarge?.copyWith(
                          color: colorScheme.onSurface.withValues(alpha: 0.5),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Browse products and place your first order!',
                        style: textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurface.withValues(alpha: 0.4),
                        ),
                      ),
                    ],
                  ),
                );
              }

              return ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                itemCount: orders.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final order = orders[index];
                  return _OrderCard(
                    order: order,
                    statusColor: _statusColor(order.status),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => OrderStatusScreen(orderId: order.id),
                        ),
                      );
                    },
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final uid = context.read<RoleProvider>().uid ?? '';
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(_currentIndex == 0 ? 'NearFind Shop' : 'Order History'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          tooltip: 'Logout / Change Role',
          onPressed: () {
            context.read<RoleProvider>().clearRole();
            Navigator.pushReplacementNamed(context, '/role-select');
          },
        ),
        actions: [
          if (_currentIndex == 0)
            Builder(
              builder: (context) {
                final cart = context.watch<CartProvider>();
                final count = cart.itemCount;
                return IconButton(
                  icon: Badge(
                    label: count > 0 ? Text('$count') : null,
                    isLabelVisible: count > 0,
                    child: const Icon(Icons.shopping_cart_rounded),
                  ),
                  tooltip: 'View Cart',
                  onPressed: count > 0 ? () => _showCartSheet(context) : null,
                );
              },
            ),
        ],
      ),
      body: IndexedStack(
        index: _currentIndex,
        children: [
          _buildShopTab(colorScheme, textTheme),
          _buildOrdersTab(uid, colorScheme, textTheme),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.storefront_rounded),
            selectedIcon: Icon(Icons.storefront_rounded),
            label: 'Shop',
          ),
          NavigationDestination(
            icon: Icon(Icons.receipt_long_rounded),
            selectedIcon: Icon(Icons.receipt_long_rounded),
            label: 'Orders',
          ),
        ],
      ),
    );
  }
}

// ── Product card ──────────────────────────────────────────────────────────────

class _ProductCard extends StatelessWidget {
  final Product product;
  final ColorScheme colorScheme;
  final TextTheme textTheme;

  const _ProductCard({
    required this.product,
    required this.colorScheme,
    required this.textTheme,
  });

  @override
  Widget build(BuildContext context) {
    final allOutOfStock = !product.isAvailableAnywhere;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Product name
            Text(
              product.name,
              style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),

            // Retailer rows
            ...product.retailers.map((retailer) {
              final inStock = retailer.stock > 0;
              return _RetailerRow(
                product: product,
                retailer: retailer,
                inStock: inStock,
                colorScheme: colorScheme,
                textTheme: textTheme,
              );
            }),

            if (allOutOfStock) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.warning_amber_rounded,
                      size: 16,
                      color: Colors.amber.shade800,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Currently unavailable from all nearby retailers',
                        style: textTheme.bodySmall?.copyWith(
                          color: Colors.amber.shade900,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Retailer row ──────────────────────────────────────────────────────────────

class _RetailerRow extends StatelessWidget {
  final Product product;
  final RetailerStock retailer;
  final bool inStock;
  final ColorScheme colorScheme;
  final TextTheme textTheme;

  const _RetailerRow({
    required this.product,
    required this.retailer,
    required this.inStock,
    required this.colorScheme,
    required this.textTheme,
  });

  @override
  Widget build(BuildContext context) {
    final rowOpacity = inStock ? 1.0 : 0.4;
    final cart = context.watch<CartProvider>();
    final cartQty = cart.getItemQuantity(product.id, retailer.retailerId);
    final inCart = cartQty > 0;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Opacity(
        opacity: rowOpacity,
        child: Row(
          children: [
            // Retailer name
            Expanded(
              flex: 3,
              child: Text(
                retailer.retailerName,
                style: textTheme.bodyMedium,
                overflow: TextOverflow.ellipsis,
              ),
            ),

            // Price
            SizedBox(
              width: 55,
              child: Text(
                '₹${retailer.price}',
                style: textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
            ),

            // Stock badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: inStock
                    ? Colors.green.withValues(alpha: 0.12)
                    : Colors.red.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                inStock ? 'Stock: ${retailer.stock}' : 'Out of Stock',
                style: textTheme.labelSmall?.copyWith(
                  color: inStock ? Colors.green.shade700 : Colors.red.shade700,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(width: 8),

            // Cart Controls (only when in stock)
            if (inStock)
              SizedBox(
                width: 96,
                child: inCart
                    ? Container(
                        decoration: BoxDecoration(
                          color: colorScheme.secondaryContainer,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            GestureDetector(
                              onTap: () => cart.decrementItem(product, retailer),
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                child: Icon(
                                  Icons.remove_rounded,
                                  size: 16,
                                  color: colorScheme.onSecondaryContainer,
                                ),
                              ),
                            ),
                            Text(
                              '$cartQty',
                              style: textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: colorScheme.onSecondaryContainer,
                              ),
                            ),
                            GestureDetector(
                              onTap: () => cart.addItem(product, retailer),
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                child: Icon(
                                  Icons.add_rounded,
                                  size: 16,
                                  color: colorScheme.onSecondaryContainer,
                                ),
                              ),
                            ),
                          ],
                        ),
                      )
                    : OutlinedButton(
                        onPressed: () => cart.addItem(product, retailer),
                        style: OutlinedButton.styleFrom(
                          padding: EdgeInsets.zero,
                          minimumSize: const Size(0, 32),
                          visualDensity: VisualDensity.compact,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          side: BorderSide(color: colorScheme.primary),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.add_rounded, size: 14),
                            SizedBox(width: 2),
                            Text('Add', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
              )
            else
              const SizedBox(width: 96),
          ],
        ),
      ),
    );
  }
}

// ── Order card widget ─────────────────────────────────────────────────────────

class _OrderCard extends StatelessWidget {
  final NearFindOrder order;
  final Color statusColor;
  final VoidCallback onTap;

  const _OrderCard({
    required this.order,
    required this.statusColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Product & retailer info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      order.productName,
                      style: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      order.retailerName,
                      style: textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
              ),

              // Status chip
              Chip(
                label: Text(
                  NearFindOrder.statusLabel(order.status),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                backgroundColor: statusColor,
                padding: EdgeInsets.zero,
                visualDensity: VisualDensity.compact,
                side: BorderSide.none,
              ),
              const SizedBox(width: 8),

              // Total price
              Text(
                '₹${order.totalPrice}',
                style: textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
