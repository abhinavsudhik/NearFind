import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/role_provider.dart';

/// Data class that describes how each role card looks and where it navigates.
class _RoleOption {
  final UserRole role;
  final String label;
  final IconData icon;
  final Color color;
  final String route;

  const _RoleOption({
    required this.role,
    required this.label,
    required this.icon,
    required this.color,
    required this.route,
  });
}

const _roles = [
  _RoleOption(
    role: UserRole.customer,
    label: 'Customer',
    icon: Icons.shopping_bag_rounded,
    color: Color(0xFF4CAF50), // green
    route: '/customer',
  ),
  _RoleOption(
    role: UserRole.retailer,
    label: 'Retailer',
    icon: Icons.storefront_rounded,
    color: Color(0xFF2196F3), // blue
    route: '/retailer',
  ),
  _RoleOption(
    role: UserRole.delivery,
    label: 'Delivery Partner',
    icon: Icons.delivery_dining_rounded,
    color: Color(0xFFFF9800), // orange
    route: '/delivery',
  ),
  _RoleOption(
    role: UserRole.admin,
    label: 'Admin',
    icon: Icons.admin_panel_settings_rounded,
    color: Color(0xFF9C27B0), // purple
    route: '/admin',
  ),
];

class RoleSelectScreen extends StatelessWidget {
  const RoleSelectScreen({super.key});

  Future<void> _onRoleTapped(
    BuildContext context,
    _RoleOption option,
  ) async {
    final provider = context.read<RoleProvider>();

    try {
      await provider.selectRole(option.role);

      if (!context.mounted) return;
      Navigator.pushReplacementNamed(context, option.route);
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sign-in failed. Please try again.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = context.watch<RoleProvider>().isLoading;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header ──────────────────────────────────────────────
              Text(
                'NearFind',
                style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                    ),
              ),
              const SizedBox(height: 4),
              Text(
                'Hyperlocal delivery, made simple.',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.6),
                    ),
              ),
              const SizedBox(height: 12),
              Text(
                'Choose your role to get started',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 24),

              // ── Role cards ──────────────────────────────────────────
              Expanded(
                child: isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : GridView.count(
                        crossAxisCount: 2,
                        mainAxisSpacing: 16,
                        crossAxisSpacing: 16,
                        childAspectRatio: 1,
                        children: _roles
                            .map((opt) => _RoleCard(
                                  option: opt,
                                  onTap: () => _onRoleTapped(context, opt),
                                ))
                            .toList(),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Single role card widget ────────────────────────────────────────────────────

class _RoleCard extends StatelessWidget {
  final _RoleOption option;
  final VoidCallback onTap;

  const _RoleCard({required this.option, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      color: option.color.withValues(alpha: 0.10),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(option.icon, size: 48, color: option.color),
              const SizedBox(height: 12),
              Text(
                option.label,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: option.color,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
