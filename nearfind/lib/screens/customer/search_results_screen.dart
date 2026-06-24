import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/product.dart';
import '../../providers/role_provider.dart';
import '../../services/firestore_service.dart';
import '../../services/order_timer_service.dart';
import 'order_status_screen.dart';

/// Displays products matching [query] and lets the customer place orders.
class SearchResultsScreen extends StatefulWidget {
  final String query;

  const SearchResultsScreen({super.key, required this.query});

  @override
  State<SearchResultsScreen> createState() => _SearchResultsScreenState();
}

class _SearchResultsScreenState extends State<SearchResultsScreen> {
  final _firestoreService = FirestoreService();

  // ── Place order flow ───────────────────────────────────────────────────

  Future<void> _showOrderSheet({
    required BuildContext context,
    required Product product,
    required RetailerStock retailer,
  }) async {
    int selectedQuantity = 1;
    final maxQty = retailer.stock.clamp(1, 5);

    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Drag handle
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Theme.of(ctx)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  Text(
                    'Order ${product.name}',
                    style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'From ${retailer.retailerName}  •  ₹${retailer.price} each',
                    style: Theme.of(ctx).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(ctx)
                              .colorScheme
                              .onSurface
                              .withValues(alpha: 0.6),
                        ),
                  ),
                  const SizedBox(height: 24),

                  // Quantity selector
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton.filledTonal(
                        onPressed: selectedQuantity > 1
                            ? () => setSheetState(
                                () => selectedQuantity--)
                            : null,
                        icon: const Icon(Icons.remove),
                      ),
                      Padding(
                        padding:
                            const EdgeInsets.symmetric(horizontal: 24),
                        child: Text(
                          '$selectedQuantity',
                          style: Theme.of(ctx)
                              .textTheme
                              .headlineSmall
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                      ),
                      IconButton.filledTonal(
                        onPressed: selectedQuantity < maxQty
                            ? () => setSheetState(
                                () => selectedQuantity++)
                            : null,
                        icon: const Icon(Icons.add),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Total
                  Center(
                    child: Text(
                      'Total: ₹${selectedQuantity * retailer.price}',
                      style: Theme.of(ctx).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  FilledButton.icon(
                    onPressed: () => Navigator.pop(ctx, true),
                    icon: const Icon(Icons.check_rounded),
                    label: const Text('Confirm Order'),
                  ),
                ],
              ),
            );
          },
        );
      },
    );

    if (confirmed != true || !mounted) return;

    final uid = context.read<RoleProvider>().uid ?? '';

    try {
      final orderId = await _firestoreService.placeOrder(
        customerId: uid,
        productId: product.id,
        productName: product.name,
        retailerId: retailer.retailerId,
        retailerName: retailer.retailerName,
        quantity: selectedQuantity,
        pricePerUnit: retailer.price,
      );

      OrderTimerService.instance.startTimer(orderId, _firestoreService);

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => OrderStatusScreen(orderId: orderId),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to place order: $e')),
      );
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: Text('Results for "${widget.query}"'),
      ),
      body: StreamBuilder<List<Product>>(
        stream: _firestoreService.searchProducts(widget.query),
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
                    color:
                        colorScheme.onSurface.withValues(alpha: 0.3),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'No products found',
                    style: textTheme.bodyLarge?.copyWith(
                      color: colorScheme.onSurface
                          .withValues(alpha: 0.5),
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
                onOrder: (retailer) => _showOrderSheet(
                  context: context,
                  product: product,
                  retailer: retailer,
                ),
              );
            },
          );
        },
      ),
    );
  }
}

// ── Product card ──────────────────────────────────────────────────────────────

class _ProductCard extends StatelessWidget {
  final Product product;
  final ColorScheme colorScheme;
  final TextTheme textTheme;
  final ValueChanged<RetailerStock> onOrder;

  const _ProductCard({
    required this.product,
    required this.colorScheme,
    required this.textTheme,
    required this.onOrder,
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
              style:
                  textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),

            // Retailer rows
            ...product.retailers.map((retailer) {
              final inStock = retailer.stock > 0;
              return _RetailerRow(
                retailer: retailer,
                inStock: inStock,
                colorScheme: colorScheme,
                textTheme: textTheme,
                onOrder: inStock ? () => onOrder(retailer) : null,
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
                        '⚠ Currently unavailable from all nearby retailers',
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
  final RetailerStock retailer;
  final bool inStock;
  final ColorScheme colorScheme;
  final TextTheme textTheme;
  final VoidCallback? onOrder;

  const _RetailerRow({
    required this.retailer,
    required this.inStock,
    required this.colorScheme,
    required this.textTheme,
    this.onOrder,
  });

  @override
  Widget build(BuildContext context) {
    final rowOpacity = inStock ? 1.0 : 0.4;

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
              width: 60,
              child: Text(
                '₹${retailer.price}',
                style: textTheme.bodyMedium
                    ?.copyWith(fontWeight: FontWeight.w600),
              ),
            ),

            // Stock badge
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: inStock
                    ? Colors.green.withValues(alpha: 0.12)
                    : Colors.red.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                inStock
                    ? 'In Stock: ${retailer.stock}'
                    : 'Out of Stock',
                style: textTheme.labelSmall?.copyWith(
                  color: inStock ? Colors.green.shade700 : Colors.red.shade700,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(width: 8),

            // Order button (only when in stock)
            SizedBox(
              width: 72,
              child: inStock
                  ? FilledButton(
                      onPressed: onOrder,
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        visualDensity: VisualDensity.compact,
                      ),
                      child: const Text('Order'),
                    )
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }
}
