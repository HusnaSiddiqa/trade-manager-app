import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/theme.dart';
import '../../models/sale.dart';
import '../../models/customer.dart';
import '../../models/rental.dart';
import '../../providers/auth_provider.dart';
import '../../providers/data_providers.dart';
import '../../widgets/stat_card.dart';
import '../sales/add_sale_screen.dart';
import '../customers/add_customer_screen.dart';
import '../products/add_product_screen.dart';
import '../purchases/add_purchase_screen.dart';
import '../rentals/add_rental_screen.dart';
import '../expenses/add_expense_screen.dart';
import '../profile/profile_screen.dart';

final _fmt = NumberFormat('#,##,##0', 'en_IN');
String _rupee(double v) => '₹${_fmt.format(v)}';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authStateProvider).value;
    final selectedPeriod = ref.watch(dashboardPeriodProvider);
    final stats = ref.watch(periodStatsProvider);
    final recentSales = ref.watch(salesProvider);

    // Filter sales for bottom sheets based on selected period
    final allSales = recentSales.valueOrNull ?? [];
    final now = DateTime.now();
    final periodSales = allSales.where((s) {
      switch (selectedPeriod) {
        case 'today':
          return s.date.year == now.year &&
              s.date.month == now.month &&
              s.date.day == now.day;
        case 'week':
          final startOfWeek =
              now.subtract(Duration(days: now.weekday - 1));
          final weekStart = DateTime(
              startOfWeek.year, startOfWeek.month, startOfWeek.day);
          return s.date.isAfter(weekStart.subtract(const Duration(seconds: 1)));
        case 'month':
          return s.date.year == now.year && s.date.month == now.month;
        default:
          return true;
      }
    }).toList();

    final customers = ref.watch(customersProvider).valueOrNull ?? [];
    final dueCusts = customers.where((c) => c.dueAmount > 0).toList();

    final rentals = ref.watch(rentalsProvider).valueOrNull ?? [];
    final activeRentals = rentals.where((r) => r.status == 'active').toList();

    final greeting = _greeting();

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Royal Building Materials'),
            Text(
              greeting,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.normal),
            ),
          ],
        ),
        actions: [
          Tooltip(
            message: 'Account & Shop',
            child: Padding(
              padding: const EdgeInsets.only(right: 8),
              child: GestureDetector(
                onTap: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const ProfileScreen())),
                child: CircleAvatar(
                  radius: 17,
                  backgroundColor: Colors.white24,
                  backgroundImage: user?.photoURL != null
                      ? NetworkImage(user!.photoURL!)
                      : null,
                  child: user?.photoURL == null
                      ? const Icon(Icons.person,
                          size: 18, color: Colors.white)
                      : null,
                ),
              ),
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(periodStatsProvider),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Period selector
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _PeriodChip(label: 'Today', value: 'today', selected: selectedPeriod, ref: ref),
                  const SizedBox(width: 8),
                  _PeriodChip(label: 'This Week', value: 'week', selected: selectedPeriod, ref: ref),
                  const SizedBox(width: 8),
                  _PeriodChip(label: 'This Month', value: 'month', selected: selectedPeriod, ref: ref),
                  const SizedBox(width: 8),
                  _PeriodChip(label: 'All Time', value: 'all', selected: selectedPeriod, ref: ref),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Stats grid
            stats.when(
              loading: () => const SizedBox(
                height: 180,
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (_, __) => const SizedBox.shrink(),
              data: (data) {
                final periodLabel = {
                  'today': "Today's",
                  'week': "This Week's",
                  'month': "This Month's",
                  'all': 'All Time',
                }[selectedPeriod] ?? "Today's";
                return Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: StatCard(
                          title: "$periodLabel Sales",
                          value: _rupee(data['sales'] ?? 0),
                          subtitle: '${data['sales_count'] ?? 0} transactions',
                          icon: Icons.trending_up,
                          color: AppTheme.primary,
                          onTap: () => _showSalesSheet(context, periodSales),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: StatCard(
                          title: "$periodLabel Profit",
                          value: _rupee(data['profit'] ?? 0),
                          subtitle: (data['rental_income'] ?? 0) > 0
                              ? 'Sales + ₹${_fmt.format(data['rental_income'])} rent'
                              : 'Net earnings',
                          icon: Icons.account_balance_wallet,
                          color: AppTheme.success,
                          onTap: () => _showProfitSheet(
                              context, periodSales, data),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: StatCard(
                          title: 'Total Dues',
                          value: _rupee(data['dues'] ?? 0),
                          subtitle: 'Outstanding balance',
                          icon: Icons.warning_amber_rounded,
                          color: AppTheme.warning,
                          onTap: () => _showDuesSheet(context, dueCusts),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: StatCard(
                          title: 'Active Rentals',
                          value: '${data['active_rentals'] ?? 0}',
                          subtitle: 'Items out',
                          icon: Icons.handshake_outlined,
                          color: Colors.indigo,
                          onTap: () => _showRentalsSheet(context, activeRentals),
                        ),
                      ),
                    ],
                  ),
                ],
              );
              },
            ),
            const SizedBox(height: 24),

            // Quick actions
            const Text(
              'Quick Actions',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            GridView.count(
              crossAxisCount: 3,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.1,
              children: [
                _QuickAction(
                  icon: Icons.add_shopping_cart,
                  label: 'New Sale',
                  color: AppTheme.primary,
                  onTap: () => Navigator.push(context,
                      MaterialPageRoute(builder: (_) => const AddSaleScreen())),
                ),
                _QuickAction(
                  icon: Icons.person_add,
                  label: 'Add Customer',
                  color: Colors.blue[700]!,
                  onTap: () => Navigator.push(context,
                      MaterialPageRoute(builder: (_) => const AddCustomerScreen())),
                ),
                _QuickAction(
                  icon: Icons.add_box_outlined,
                  label: 'Purchase',
                  color: Colors.green[700]!,
                  onTap: () => Navigator.push(context,
                      MaterialPageRoute(builder: (_) => const AddPurchaseScreen())),
                ),
                _QuickAction(
                  icon: Icons.handshake_outlined,
                  label: 'Rental',
                  color: Colors.indigo,
                  onTap: () => Navigator.push(context,
                      MaterialPageRoute(builder: (_) => const AddRentalScreen())),
                ),
                _QuickAction(
                  icon: Icons.account_balance_wallet_outlined,
                  label: 'Expense',
                  color: Colors.red[700]!,
                  onTap: () => Navigator.push(context,
                      MaterialPageRoute(builder: (_) => const AddExpenseScreen())),
                ),
                _QuickAction(
                  icon: Icons.inventory_2_outlined,
                  label: 'Add Product',
                  color: Colors.orange[800]!,
                  onTap: () => Navigator.push(context,
                      MaterialPageRoute(builder: (_) => const AddProductScreen())),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Recent sales
            const Text(
              'Recent Sales',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            recentSales.when(
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (_, __) =>
                  const Text('Could not load sales'),
              data: (sales) {
                if (sales.isEmpty) {
                  return _emptyState(
                    Icons.receipt_long_outlined,
                    'No sales yet',
                    'Tap "New Sale" to record your first sale',
                  );
                }
                final recent = sales.take(5).toList();
                return Card(
                  child: Column(
                    children: recent.map((sale) {
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: AppTheme.primary.withValues(alpha: 0.1),
                          child: const Icon(Icons.receipt,
                              color: AppTheme.primary, size: 18),
                        ),
                        title: Text(
                          sale.customerName,
                          style: const TextStyle(fontWeight: FontWeight.w500),
                        ),
                        subtitle: Text(
                          DateFormat('dd MMM, hh:mm a').format(sale.date),
                          style: const TextStyle(fontSize: 12),
                        ),
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              _rupee(sale.totalAmount),
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: AppTheme.primary,
                              ),
                            ),
                            Text(
                              sale.paymentMethod.toUpperCase(),
                              style: TextStyle(
                                fontSize: 10,
                                color: sale.paymentMethod == 'cash'
                                    ? AppTheme.success
                                    : sale.paymentMethod == 'credit'
                                        ? Colors.red
                                        : Colors.blue,
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                );
              },
            ),
            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }

  // ── Bottom sheets ────────────────────────────────────────────────────────────

  void _showSalesSheet(BuildContext context, List<Sale> sales) {
    // Group totals by payment mode
    final totals = <String, double>{};
    for (final s in sales) {
      totals[s.paymentMethod] = (totals[s.paymentMethod] ?? 0) + s.totalAmount;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.95,
        minChildSize: 0.4,
        expand: false,
        builder: (_, ctrl) => Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _sheetHandle(),
              const Text("Today's Transactions",
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),

              // Mode breakdown chips
              if (totals.isNotEmpty) ...[
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: totals.entries.map((e) {
                    final color = _modeColor(e.key);
                    return Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: color.withValues(alpha: 0.3)),
                      ),
                      child: Column(
                        children: [
                          Text(e.key.toUpperCase(),
                              style: TextStyle(
                                  fontSize: 11,
                                  color: color,
                                  fontWeight: FontWeight.bold)),
                          Text(_rupee(e.value),
                              style: TextStyle(
                                  fontSize: 15,
                                  color: color,
                                  fontWeight: FontWeight.bold)),
                        ],
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
                const Divider(),
              ],

              // Transaction list
              Expanded(
                child: sales.isEmpty
                    ? const Center(
                        child: Text('No sales today',
                            style: TextStyle(color: Colors.grey)))
                    : ListView.builder(
                        controller: ctrl,
                        itemCount: sales.length,
                        itemBuilder: (_, i) =>
                            _saleTile(sales[i]),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showProfitSheet(BuildContext context, List<Sale> sales,
      Map<String, dynamic> data) {
    final salesProfit = (data['sales_profit'] ?? 0).toDouble();
    final rentalIncome = (data['rental_income'] ?? 0).toDouble();
    final totalProfit = salesProfit + rentalIncome;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.95,
        minChildSize: 0.4,
        expand: false,
        builder: (_, ctrl) => Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _sheetHandle(),
              Row(
                children: [
                  const Text('Profit Breakdown',
                      style: TextStyle(
                          fontSize: 17, fontWeight: FontWeight.bold)),
                  const Spacer(),
                  Text(_rupee(totalProfit),
                      style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.success)),
                ],
              ),
              const SizedBox(height: 10),
              // Breakdown summary row
              if (rentalIncome > 0)
                Container(
                  padding: const EdgeInsets.all(10),
                  margin: const EdgeInsets.only(bottom: 10),
                  decoration: BoxDecoration(
                    color: Colors.green[50],
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.green[200]!),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Sales Profit',
                                style: TextStyle(
                                    fontSize: 11, color: Colors.grey)),
                            Text(_rupee(salesProfit),
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.success)),
                          ],
                        ),
                      ),
                      const Text('+', style: TextStyle(
                          fontSize: 18, color: Colors.grey)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            const Text('Rental Income',
                                style: TextStyle(
                                    fontSize: 11, color: Colors.grey)),
                            Text(_rupee(rentalIncome),
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.indigo)),
                          ],
                        ),
                      ),
                      const Text('=', style: TextStyle(
                          fontSize: 18, color: Colors.grey)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            const Text('Total Profit',
                                style: TextStyle(
                                    fontSize: 11, color: Colors.grey)),
                            Text(_rupee(totalProfit),
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.success)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              const Divider(height: 1),
              const SizedBox(height: 6),
              const Text('Sales',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey)),
              const SizedBox(height: 4),
              Expanded(
                child: sales.isEmpty
                    ? const Center(
                        child: Text('No sales',
                            style: TextStyle(color: Colors.grey)))
                    : ListView.builder(
                        controller: ctrl,
                        itemCount: sales.length,
                        itemBuilder: (_, i) {
                          final s = sales[i];
                          return ListTile(
                            dense: true,
                            title: Text(s.customerName,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w500)),
                            subtitle: Text(
                                '${s.items.length} item${s.items.length > 1 ? 's' : ''} • ${DateFormat('hh:mm a').format(s.date)}'),
                            trailing: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(_rupee(s.totalAmount),
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: AppTheme.primary,
                                        fontSize: 13)),
                                Text('+${_rupee(s.profit)}',
                                    style: const TextStyle(
                                        fontSize: 11,
                                        color: AppTheme.success,
                                        fontWeight: FontWeight.w600)),
                              ],
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showDuesSheet(BuildContext context, List<Customer> dueCusts) {
    final total = dueCusts.fold(0.0, (s, e) => s + e.dueAmount);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.95,
        minChildSize: 0.4,
        expand: false,
        builder: (_, ctrl) => Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _sheetHandle(),
              Row(
                children: [
                  const Text('Outstanding Dues',
                      style: TextStyle(
                          fontSize: 17, fontWeight: FontWeight.bold)),
                  const Spacer(),
                  Text(_rupee(total),
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.orange[700])),
                ],
              ),
              const SizedBox(height: 12),
              const Divider(),
              Expanded(
                child: dueCusts.isEmpty
                    ? const Center(
                        child: Text('No outstanding dues',
                            style: TextStyle(color: Colors.grey)))
                    : ListView.builder(
                        controller: ctrl,
                        itemCount: dueCusts.length,
                        itemBuilder: (_, i) {
                          final c = dueCusts[i];
                          return ListTile(
                            leading: CircleAvatar(
                              backgroundColor:
                                  Colors.orange.withValues(alpha: 0.15),
                              child: Text(c.name[0].toUpperCase(),
                                  style: TextStyle(
                                      color: Colors.orange[700],
                                      fontWeight: FontWeight.bold)),
                            ),
                            title: Text(c.name,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600)),
                            subtitle: Text(c.mobile.isNotEmpty
                                ? c.mobile
                                : c.village),
                            trailing: Text(
                              _rupee(c.dueAmount),
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.orange[700],
                                  fontSize: 14),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showRentalsSheet(BuildContext context, List<Rental> rentals) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.95,
        minChildSize: 0.4,
        expand: false,
        builder: (_, ctrl) => Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _sheetHandle(),
              Text('Active Rentals (${rentals.length})',
                  style: const TextStyle(
                      fontSize: 17, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              const Divider(),
              Expanded(
                child: rentals.isEmpty
                    ? const Center(
                        child: Text('No active rentals',
                            style: TextStyle(color: Colors.grey)))
                    : ListView.builder(
                        controller: ctrl,
                        itemCount: rentals.length,
                        itemBuilder: (_, i) {
                          final r = rentals[i];
                          return ListTile(
                            leading: CircleAvatar(
                              backgroundColor:
                                  Colors.indigo.withValues(alpha: 0.12),
                              child: const Icon(Icons.handshake_outlined,
                                  color: Colors.indigo, size: 18),
                            ),
                            title: Text(r.customerName,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600)),
                            subtitle: Text(
                                '${r.itemName} • ${r.daysOut} day${r.daysOut > 1 ? 's' : ''}'),
                            trailing: Text(
                              _rupee(r.calculatedRent),
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.indigo,
                                  fontSize: 13),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Helpers ──────────────────────────────────────────────────────────────────

  Widget _sheetHandle() => Center(
        child: Container(
          width: 36,
          height: 4,
          margin: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: Colors.grey[300],
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      );

  Widget _saleTile(Sale s) {
    final color = _modeColor(s.paymentMethod);
    return ListTile(
      dense: true,
      leading: CircleAvatar(
        radius: 16,
        backgroundColor: color.withValues(alpha: 0.12),
        child: Text(s.customerName[0].toUpperCase(),
            style: TextStyle(
                color: color, fontSize: 13, fontWeight: FontWeight.bold)),
      ),
      title: Text(s.customerName,
          style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13)),
      subtitle: Text(
          '${s.items.length} item${s.items.length > 1 ? 's' : ''} • ${DateFormat('hh:mm a').format(s.date)}',
          style: const TextStyle(fontSize: 11)),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(_rupee(s.totalAmount),
              style: TextStyle(
                  fontWeight: FontWeight.bold, color: color, fontSize: 13)),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(s.paymentMethod.toUpperCase(),
                style: TextStyle(
                    fontSize: 9, color: color, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Color _modeColor(String mode) {
    switch (mode) {
      case 'cash':
        return Colors.green[700]!;
      case 'upi':
        return Colors.blue[700]!;
      case 'borrow':
      case 'credit':
        return Colors.orange[700]!;
      default:
        return Colors.grey[700]!;
    }
  }

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning, Owner';
    if (hour < 17) return 'Good afternoon, Owner';
    return 'Good evening, Owner';
  }

  Widget _emptyState(IconData icon, String title, String subtitle) {
    return Container(
      padding: const EdgeInsets.all(32),
      alignment: Alignment.center,
      child: Column(
        children: [
          Icon(icon, size: 48, color: Colors.grey[300]),
          const SizedBox(height: 12),
          Text(title,
              style: TextStyle(
                  color: Colors.grey[500], fontWeight: FontWeight.w500)),
          const SizedBox(height: 4),
          Text(subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: Colors.grey[400])),
        ],
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _QuickAction({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
    );
  }
}

class _PeriodChip extends StatelessWidget {
  final String label;
  final String value;
  final String selected;
  final WidgetRef ref;

  const _PeriodChip({
    required this.label,
    required this.value,
    required this.selected,
    required this.ref,
  });

  @override
  Widget build(BuildContext context) {
    final isSelected = selected == value;
    return GestureDetector(
      onTap: () {
        ref.read(dashboardPeriodProvider.notifier).state = value;
        ref.invalidate(periodStatsProvider);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primary : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppTheme.primary : Colors.grey[300]!,
          ),
          boxShadow: isSelected
              ? [BoxShadow(color: AppTheme.primary.withValues(alpha: 0.3), blurRadius: 6)]
              : [],
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: isSelected ? Colors.white : Colors.grey[700],
          ),
        ),
      ),
    );
  }
}
