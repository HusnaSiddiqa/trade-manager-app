import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../dashboard/dashboard_screen.dart';
import '../sales/sales_screen.dart';
import '../customers/customers_screen.dart';
import '../products/products_screen.dart';
import '../purchases/purchases_screen.dart';
import '../rentals/rentals_screen.dart';
import '../expenses/expenses_screen.dart';
import '../reports/reports_screen.dart';
import '../settings/settings_screen.dart';
import '../customers/due_analysis_screen.dart';
import '../suppliers/supplier_due_screen.dart';
import '../reports/daily_cash_screen.dart';
import '../products/product_analytics_screen.dart';
import '../profile/profile_screen.dart';
import '../../providers/auth_provider.dart';
import '../../core/theme.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  int _currentIndex = 0;

  final List<Widget> _pages = const [
    DashboardScreen(),
    SalesScreen(),
    CustomersScreen(),
    ProductsScreen(),
  ];

  void _openMore(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _MoreSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: _pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (i) {
          if (i == 4) {
            _openMore(context);
          } else {
            setState(() => _currentIndex = i);
          }
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long),
            label: 'Sales',
          ),
          NavigationDestination(
            icon: Icon(Icons.people_outline),
            selectedIcon: Icon(Icons.people),
            label: 'Customers',
          ),
          NavigationDestination(
            icon: Icon(Icons.inventory_2_outlined),
            selectedIcon: Icon(Icons.inventory_2),
            label: 'Products',
          ),
          NavigationDestination(
            icon: Icon(Icons.more_horiz),
            selectedIcon: Icon(Icons.more_horiz),
            label: 'More',
          ),
        ],
      ),
    );
  }
}

class _MoreSheet extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = [
      _MoreItem(Icons.warning_amber_outlined, 'Customer Dues', Colors.red[700]!,
          () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DueAnalysisScreen()))),
      _MoreItem(Icons.store_outlined, 'Supplier Dues', Colors.deepOrange,
          () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SupplierDueScreen()))),
      _MoreItem(Icons.today_outlined, 'Daily Cash Report', Colors.teal,
          () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DailyCashScreen()))),
      _MoreItem(Icons.shopping_cart_outlined, 'Purchases', AppTheme.primary,
          () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PurchasesScreen()))),
      _MoreItem(Icons.handshake_outlined, 'Rentals', Colors.indigo,
          () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RentalsScreen()))),
      _MoreItem(Icons.account_balance_wallet_outlined, 'Expenses', Colors.red[700]!,
          () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ExpensesScreen()))),
      _MoreItem(Icons.bar_chart_outlined, 'Reports', Colors.green[700]!,
          () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ReportsScreen()))),
      _MoreItem(Icons.trending_up_outlined, 'Product Analytics', Colors.blue[700]!,
          () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ProductAnalyticsScreen()))),
      _MoreItem(Icons.settings_outlined, 'Settings', Colors.grey[700]!,
          () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen()))),
      _MoreItem(Icons.account_circle_outlined, 'Account & Shop',
          const Color(0xFF1A237E),
          () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfileScreen()))),
    ];

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          const Text('More Options',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          ...items.map((item) => ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: item.color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(item.icon, color: item.color, size: 22),
                ),
                title: Text(item.label,
                    style: const TextStyle(fontWeight: FontWeight.w500)),
                trailing: const Icon(Icons.chevron_right, color: Colors.grey),
                onTap: () {
                  Navigator.pop(context);
                  item.onTap();
                },
              )),
          const Divider(height: 1),
          // ── Sign Out — prominent separate row ──
          ListTile(
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.logout, color: Colors.red, size: 22),
            ),
            title: const Text('Sign Out',
                style: TextStyle(
                    fontWeight: FontWeight.bold, color: Colors.red)),
            onTap: () async {
              Navigator.pop(context);
              await ref.read(authServiceProvider).signOut();
            },
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _MoreItem {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _MoreItem(this.icon, this.label, this.color, this.onTap);
}
