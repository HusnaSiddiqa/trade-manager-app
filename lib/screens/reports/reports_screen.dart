import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/theme.dart';
import '../../providers/data_providers.dart';

final _fmt = NumberFormat('#,##,##0', 'en_IN');

class ReportsScreen extends ConsumerStatefulWidget {
  const ReportsScreen({super.key});

  @override
  ConsumerState<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends ConsumerState<ReportsScreen> {
  DateTime _from = DateTime.now().subtract(const Duration(days: 30));
  DateTime _to = DateTime.now();

  Future<void> _pickRange() async {
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: DateTimeRange(start: _from, end: _to),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(primary: AppTheme.primary),
        ),
        child: child!,
      ),
    );
    if (range != null) setState(() { _from = range.start; _to = range.end; });
  }

  @override
  Widget build(BuildContext context) {
    final salesAsync = ref.watch(salesProvider);
    final expensesAsync = ref.watch(expensesProvider);
    final rentalsAsync = ref.watch(rentalsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Reports')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Date range selector
            InkWell(
              onTap: _pickRange,
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.primary),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.date_range, color: AppTheme.primary),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        '${DateFormat('dd MMM').format(_from)} → ${DateFormat('dd MMM yyyy').format(_to)}',
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                    ),
                    const Text('Change Range',
                        style: TextStyle(color: AppTheme.primary, fontSize: 13)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Sales summary
            salesAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Text('Error: $e'),
              data: (allSales) {
                final sales = allSales.where((s) =>
                    s.date.isAfter(_from.subtract(const Duration(days: 1))) &&
                    s.date.isBefore(_to.add(const Duration(days: 1)))).toList();

                final allRentals = rentalsAsync.valueOrNull ?? [];
                final returnedRentals = allRentals.where((r) =>
                    r.status == 'returned' &&
                    r.issueDate.isAfter(_from.subtract(const Duration(days: 1))) &&
                    r.issueDate.isBefore(_to.add(const Duration(days: 1)))).toList();
                final rentalIncome = returnedRentals.fold(0.0, (s, e) => s + e.totalRent);

                final totalSales = sales.fold(0.0, (s, e) => s + e.totalAmount);
                final salesProfit = sales.fold(0.0, (s, e) => s + e.profit);
                final totalProfit = salesProfit + rentalIncome;
                final totalDues = sales.fold(0.0, (s, e) => s + e.dueAmount);
                final cashSales = sales
                    .where((s) => s.paymentMethod == 'cash')
                    .fold(0.0, (s, e) => s + e.totalAmount);
                final creditSales = sales
                    .where((s) => s.paymentMethod == 'credit')
                    .fold(0.0, (s, e) => s + e.totalAmount);
                final upiSales = sales
                    .where((s) => s.paymentMethod == 'upi')
                    .fold(0.0, (s, e) => s + e.totalAmount);

                // Top products
                final productTotals = <String, double>{};
                for (final sale in sales) {
                  for (final item in sale.items) {
                    productTotals[item.productName] =
                        (productTotals[item.productName] ?? 0) + item.total;
                  }
                }
                final topProducts = productTotals.entries.toList()
                  ..sort((a, b) => b.value.compareTo(a.value));

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _SectionTitle('Sales Summary'),
                    const SizedBox(height: 8),
                    _ReportCard(children: [
                      _ReportRow('Total Sales', '₹${_fmt.format(totalSales)}', AppTheme.primary),
                      _ReportRow('Sales Profit', '₹${_fmt.format(salesProfit)}', AppTheme.success),
                      if (rentalIncome > 0)
                        _ReportRow('Rental Income', '₹${_fmt.format(rentalIncome)}', Colors.indigo),
                      _ReportRow('Total Profit', '₹${_fmt.format(totalProfit)}', AppTheme.success),
                      _ReportRow('Pending Dues', '₹${_fmt.format(totalDues)}', Colors.orange[700]!),
                      _ReportRow('Transactions', '${sales.length}', Colors.grey[700]!),
                    ]),
                    const SizedBox(height: 16),
                    _SectionTitle('Payment Breakdown'),
                    const SizedBox(height: 8),
                    _ReportCard(children: [
                      _ReportRow('Cash', '₹${_fmt.format(cashSales)}', Colors.green[700]!),
                      _ReportRow('Credit', '₹${_fmt.format(creditSales)}', Colors.red[700]!),
                      _ReportRow('UPI', '₹${_fmt.format(upiSales)}', Colors.blue[700]!),
                    ]),
                    if (topProducts.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      _SectionTitle('Top Products'),
                      const SizedBox(height: 8),
                      _ReportCard(
                        children: topProducts.take(5).map((e) =>
                          _ReportRow(e.key, '₹${_fmt.format(e.value)}', AppTheme.primary),
                        ).toList(),
                      ),
                    ],
                  ],
                );
              },
            ),

            const SizedBox(height: 16),

            // Expense summary
            expensesAsync.when(
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
              data: (allExpenses) {
                final expenses = allExpenses.where((e) =>
                    e.date.isAfter(_from.subtract(const Duration(days: 1))) &&
                    e.date.isBefore(_to.add(const Duration(days: 1)))).toList();

                if (expenses.isEmpty) return const SizedBox.shrink();

                final totalExp = expenses.fold(0.0, (s, e) => s + e.amount);
                final byCategory = <String, double>{};
                for (final e in expenses) {
                  byCategory[e.category] = (byCategory[e.category] ?? 0) + e.amount;
                }

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _SectionTitle('Expense Summary'),
                    const SizedBox(height: 8),
                    _ReportCard(children: [
                      _ReportRow('Total Expenses', '₹${_fmt.format(totalExp)}', Colors.red[700]!),
                      ...byCategory.entries.map((e) =>
                        _ReportRow(e.key, '₹${_fmt.format(e.value)}', Colors.grey[700]!),
                      ),
                    ]),
                  ],
                );
              },
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle(this.title);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(width: 4, height: 18, color: AppTheme.primary,
            decoration: const BoxDecoration(borderRadius: BorderRadius.all(Radius.circular(2)))),
        const SizedBox(width: 8),
        Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
      ],
    );
  }
}

class _ReportCard extends StatelessWidget {
  final List<Widget> children;
  const _ReportCard({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: children
            .expand((w) => [w, const Divider(height: 12)])
            .take(children.length * 2 - 1)
            .toList(),
      ),
    );
  }
}

class _ReportRow extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _ReportRow(this.label, this.value, this.color);

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(color: Colors.grey[700], fontSize: 13)),
        Text(value,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: color,
              fontSize: 14,
            )),
      ],
    );
  }
}
