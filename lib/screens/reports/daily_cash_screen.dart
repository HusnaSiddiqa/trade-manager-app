import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import '../../providers/data_providers.dart';

final _fmt = NumberFormat('#,##,##0', 'en_IN');

final _selectedDateProvider = StateProvider<DateTime>((ref) {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day);
});

final _dailyCashProvider =
    FutureProvider.autoDispose<Map<String, dynamic>>((ref) {
  final date = ref.watch(_selectedDateProvider);
  return ref.read(firestoreServiceProvider).dailyCashStats(date);
});

class DailyCashScreen extends ConsumerWidget {
  const DailyCashScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedDate = ref.watch(_selectedDateProvider);
    final statsAsync = ref.watch(_dailyCashProvider);
    final shopAsync = ref.watch(shopSettingsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Daily Cash Closing'),
        backgroundColor: const Color(0xFF1A237E),
        foregroundColor: Colors.white,
        actions: [
          statsAsync.whenOrNull(
                data: (stats) {
                  final shopName = shopAsync.valueOrNull?['shop_name'] ??
                      'Royal Building Materials';
                  return IconButton(
                    icon: const Icon(Icons.share_outlined),
                    tooltip: 'Share Report',
                    onPressed: () => _shareReport(
                        context, stats, selectedDate, shopName),
                  );
                },
              ) ??
              const SizedBox.shrink(),
        ],
      ),
      body: Column(
        children: [
          // Date picker bar
          Container(
            color: const Color(0xFF1A237E),
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left,
                      color: Colors.white),
                  onPressed: () => ref
                      .read(_selectedDateProvider.notifier)
                      .state = selectedDate
                      .subtract(const Duration(days: 1)),
                ),
                InkWell(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: selectedDate,
                      firstDate: DateTime(2024),
                      lastDate: DateTime.now(),
                    );
                    if (picked != null) {
                      ref.read(_selectedDateProvider.notifier).state =
                          picked;
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.calendar_today,
                            color: Colors.white, size: 16),
                        const SizedBox(width: 8),
                        Text(
                          DateFormat('EEE, dd MMM yyyy')
                              .format(selectedDate),
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right,
                      color: Colors.white),
                  onPressed: selectedDate.isBefore(
                          DateTime.now().subtract(const Duration(days: 1)))
                      ? () => ref
                          .read(_selectedDateProvider.notifier)
                          .state =
                          selectedDate.add(const Duration(days: 1))
                      : null,
                ),
              ],
            ),
          ),
          Expanded(
            child: statsAsync.when(
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
              data: (stats) => _CashReport(stats: stats),
            ),
          ),
        ],
      ),
    );
  }

  void _shareReport(BuildContext context, Map<String, dynamic> stats,
      DateTime date, String shopName) {
    String r(double v) => '₹${_fmt.format(v)}';
    final text = '''
━━━━━━━━━━━━━━━━━━━━━━━━━━━━
$shopName
Daily Cash Report — ${DateFormat('dd MMM yyyy').format(date)}
━━━━━━━━━━━━━━━━━━━━━━━━━━━━

💰 INCOME
  Cash Sales:   ${r(stats['cash_sales'])}
  UPI Sales:    ${r(stats['upi_sales'])}
  Rental Income:${r((stats['rental_income'] ?? 0).toDouble())}
  Credit Given: ${r(stats['credit_given'])} (${stats['credit_count']} orders)
  Total Sales:  ${r(stats['total_sales'])} (${stats['total_sales_count']} orders)

📦 EXPENSES
  Cash Purchases: ${r(stats['cash_purchases'])}
  UPI Purchases:  ${r(stats['upi_purchases'])}
  Credit Buys:    ${r(stats['credit_purchases'])}
  Other Expenses: ${r(stats['expenses'])}

━━━━━━━━━━━━━━━━━━━━━━━━━━━━
🏦 NET CASH IN HAND: ${r(stats['net_cash'])}
━━━━━━━━━━━━━━━━━━━━━━━━━━━━
''';
    Share.share(text, subject: 'Daily Cash Report — ${DateFormat('dd MMM yyyy').format(date)}');
  }
}

class _CashReport extends StatelessWidget {
  final Map<String, dynamic> stats;

  const _CashReport({required this.stats});

  @override
  Widget build(BuildContext context) {
    final cashSales = (stats['cash_sales'] as num).toDouble();
    final upiSales = (stats['upi_sales'] as num).toDouble();
    final creditGiven = (stats['credit_given'] as num).toDouble();
    final creditCount = stats['credit_count'] as int;
    final cashPurchases = (stats['cash_purchases'] as num).toDouble();
    final upiPurchases = (stats['upi_purchases'] as num).toDouble();
    final creditPurchases = (stats['credit_purchases'] as num).toDouble();
    final expenses = (stats['expenses'] as num).toDouble();
    final rentalIncome = ((stats['rental_income'] ?? 0) as num).toDouble();
    final netCash = (stats['net_cash'] as num).toDouble();
    final totalSales = (stats['total_sales'] as num).toDouble();
    final totalCount = stats['total_sales_count'] as int;

    final totalIn = cashSales + upiSales + rentalIncome;
    final totalOut = cashPurchases + upiPurchases + expenses;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Net Cash hero card
        Card(
          color: netCash >= 0
              ? const Color(0xFF1A237E)
              : const Color(0xFFB71C1C),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                const Text('Net Cash in Hand',
                    style: TextStyle(color: Colors.white70, fontSize: 13)),
                const SizedBox(height: 6),
                Text(
                  '₹${_fmt.format(netCash.abs())}',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 32,
                      fontWeight: FontWeight.bold),
                ),
                if (netCash < 0)
                  const Text('⚠️ More spent than received',
                      style: TextStyle(color: Colors.orange, fontSize: 12)),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Sales section
        _SectionHeader(
          title: 'Sales Income',
          total: '₹${_fmt.format(totalSales)}',
          subtitle: '$totalCount orders',
          color: Colors.green,
        ),
        _StatRow(
          label: 'Cash Sales',
          value: '₹${_fmt.format(cashSales)}',
          icon: Icons.payments_outlined,
          color: Colors.green,
        ),
        _StatRow(
          label: 'UPI Sales',
          value: '₹${_fmt.format(upiSales)}',
          icon: Icons.qr_code_outlined,
          color: Colors.purple,
        ),
        if (rentalIncome > 0)
          _StatRow(
            label: 'Rental Income',
            value: '₹${_fmt.format(rentalIncome)}',
            icon: Icons.handshake_outlined,
            color: Colors.indigo,
          ),
        _StatRow(
          label: 'Credit Given',
          value: '₹${_fmt.format(creditGiven)}',
          subtitle: '$creditCount orders',
          icon: Icons.credit_card_outlined,
          color: Colors.orange,
        ),
        const SizedBox(height: 4),
        _TotalRow(
          label: 'Cash + UPI + Rent Received',
          value: '₹${_fmt.format(totalIn)}',
          color: Colors.green,
        ),
        const SizedBox(height: 16),

        // Expenses section
        _SectionHeader(
          title: 'Expenses / Outgoing',
          total: '₹${_fmt.format(totalOut)}',
          color: Colors.red,
        ),
        _StatRow(
          label: 'Cash Purchases',
          value: '₹${_fmt.format(cashPurchases)}',
          icon: Icons.shopping_bag_outlined,
          color: Colors.red,
        ),
        _StatRow(
          label: 'UPI Purchases',
          value: '₹${_fmt.format(upiPurchases)}',
          icon: Icons.qr_code_outlined,
          color: Colors.deepPurple,
        ),
        _StatRow(
          label: 'Credit Purchases (Due)',
          value: '₹${_fmt.format(creditPurchases)}',
          icon: Icons.pending_outlined,
          color: Colors.grey,
        ),
        _StatRow(
          label: 'Other Expenses',
          value: '₹${_fmt.format(expenses)}',
          icon: Icons.receipt_long_outlined,
          color: Colors.red,
        ),
        const SizedBox(height: 4),
        _TotalRow(
          label: 'Total Cash Out',
          value: '₹${_fmt.format(totalOut)}',
          color: Colors.red,
        ),
        const SizedBox(height: 16),

        // Net summary
        Card(
          color: const Color(0xFFF8F9FF),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _CalcRow(
                    label: rentalIncome > 0
                        ? 'Sales + Rental In'
                        : 'Cash + UPI In',
                    value: '₹${_fmt.format(totalIn)}',
                    positive: true),
                _CalcRow(
                    label: 'Cash + UPI Out',
                    value: '−₹${_fmt.format(totalOut)}',
                    positive: false),
                const Divider(),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Net Cash',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 15)),
                    Text(
                      '₹${_fmt.format(netCash)}',
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: netCash >= 0
                              ? Colors.green[700]
                              : Colors.red[700]),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 80),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final String total;
  final String? subtitle;
  final Color color;

  const _SectionHeader(
      {required this.title,
      required this.total,
      this.subtitle,
      required this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: color)),
              if (subtitle != null)
                Text(subtitle!,
                    style:
                        const TextStyle(color: Colors.grey, fontSize: 11)),
            ],
          ),
          Text(total,
              style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: color)),
        ],
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  final String label;
  final String value;
  final String? subtitle;
  final IconData icon;
  final Color color;

  const _StatRow(
      {required this.label,
      required this.value,
      this.subtitle,
      required this.icon,
      required this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color.withOpacity(0.7)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(fontSize: 13)),
                if (subtitle != null)
                  Text(subtitle!,
                      style: const TextStyle(
                          fontSize: 11, color: Colors.grey)),
              ],
            ),
          ),
          Text(value,
              style: const TextStyle(
                  fontWeight: FontWeight.w600, fontSize: 13)),
        ],
      ),
    );
  }
}

class _TotalRow extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _TotalRow(
      {required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: color)),
          Text(value,
              style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: color)),
        ],
      ),
    );
  }
}

class _CalcRow extends StatelessWidget {
  final String label;
  final String value;
  final bool positive;

  const _CalcRow(
      {required this.label, required this.value, required this.positive});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey, fontSize: 13)),
          Text(value,
              style: TextStyle(
                  fontSize: 13,
                  color: positive ? Colors.green[700] : Colors.red[700])),
        ],
      ),
    );
  }
}
