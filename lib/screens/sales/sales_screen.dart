import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/theme.dart';
import '../../providers/data_providers.dart';
import '../../models/sale.dart';
import '../../services/bill_service.dart';
import 'add_sale_screen.dart';

final _fmt = NumberFormat('#,##,##0', 'en_IN');

class SalesScreen extends ConsumerWidget {
  const SalesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final salesAsync = ref.watch(salesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sales'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline),
            onPressed: () => Navigator.push(
                context, MaterialPageRoute(builder: (_) => const AddSaleScreen())),
          ),
        ],
      ),
      body: salesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (sales) {
          if (sales.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.receipt_long_outlined, size: 72, color: Colors.grey[300]),
                  const SizedBox(height: 16),
                  Text('No sales recorded yet',
                      style: TextStyle(color: Colors.grey[500], fontSize: 16)),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: () => Navigator.push(context,
                        MaterialPageRoute(builder: (_) => const AddSaleScreen())),
                    icon: const Icon(Icons.add),
                    label: const Text('Record First Sale'),
                  ),
                ],
              ),
            );
          }

          // Group by date
          final grouped = <String, List<Sale>>{};
          for (final sale in sales) {
            final key = DateFormat('dd MMM yyyy').format(sale.date);
            grouped.putIfAbsent(key, () => []).add(sale);
          }

          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: grouped.length,
            itemBuilder: (_, i) {
              final date = grouped.keys.elementAt(i);
              final daySales = grouped[date]!;
              final dayTotal = daySales.fold(0.0, (s, e) => s + e.totalAmount);

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(date,
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 13)),
                        Text('₹${_fmt.format(dayTotal)}',
                            style: const TextStyle(
                                color: AppTheme.primary,
                                fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                  ...daySales.map((sale) => _SaleTile(sale: sale)),
                  const SizedBox(height: 8),
                ],
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.push(
            context, MaterialPageRoute(builder: (_) => const AddSaleScreen())),
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _SaleTile extends ConsumerWidget {
  final Sale sale;
  const _SaleTile({required this.sale});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final payColor = sale.paymentMethod == 'cash'
        ? Colors.green[700]!
        : sale.paymentMethod == 'credit'
            ? Colors.red[700]!
            : Colors.blue[700]!;

    final hasDue = sale.dueAmount > 0;

    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(sale.customerName,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 15)),
                ),
                Text(
                  '₹${_fmt.format(sale.totalAmount)}',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: AppTheme.primary),
                ),
                const SizedBox(width: 8),
                _BillButton(sale: sale),
                const SizedBox(width: 4),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, size: 18, color: Colors.grey),
                  onSelected: (v) {
                    if (v == 'edit') {
                      Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => AddSaleScreen(sale: sale)));
                    } else if (v == 'delete') {
                      _confirmDelete(context, ref, sale);
                    }
                  },
                  itemBuilder: (_) => [
                    const PopupMenuItem(
                      value: 'edit',
                      child: Row(children: [
                        Icon(Icons.edit_outlined, size: 18),
                        SizedBox(width: 8),
                        Text('Edit Sale'),
                      ]),
                    ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(children: [
                        Icon(Icons.delete_outline, color: Colors.red, size: 18),
                        SizedBox(width: 8),
                        Text('Delete Sale', style: TextStyle(color: Colors.red)),
                      ]),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 6),

            // Time + items + payment badge
            Row(
              children: [
                Icon(Icons.access_time, size: 12, color: Colors.grey[400]),
                const SizedBox(width: 4),
                Text(DateFormat('hh:mm a').format(sale.date),
                    style: TextStyle(fontSize: 12, color: Colors.grey[500])),
                const SizedBox(width: 12),
                Text(
                    '${sale.items.length} item${sale.items.length > 1 ? 's' : ''}',
                    style: TextStyle(fontSize: 12, color: Colors.grey[500])),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: payColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    sale.paymentMethod.toUpperCase(),
                    style: TextStyle(
                        fontSize: 10,
                        color: payColor,
                        fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),

            // Due amount + action buttons
            if (hasDue) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.orange[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange[200]!),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.warning_amber_rounded,
                            size: 14, color: Colors.orange[700]),
                        const SizedBox(width: 6),
                        Text(
                          'Due: ₹${_fmt.format(sale.dueAmount)}',
                          style: TextStyle(
                              fontSize: 13,
                              color: Colors.orange[800],
                              fontWeight: FontWeight.bold),
                        ),
                        if (sale.paidAmount > 0) ...[
                          const SizedBox(width: 8),
                          Text(
                            '(Paid: ₹${_fmt.format(sale.paidAmount)})',
                            style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () => _showCollectDialog(context, ref, sale),
                        icon: const Icon(Icons.payments_outlined, size: 16),
                        label: const Text('Collect Payment',
                            style: TextStyle(fontSize: 13)),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.green[700],
                          side: BorderSide(color: Colors.green[300]!),
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ] else ...[
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(Icons.check_circle, size: 14, color: Colors.green[600]),
                      const SizedBox(width: 4),
                      Text('Fully Paid',
                          style: TextStyle(
                              fontSize: 12,
                              color: Colors.green[700],
                              fontWeight: FontWeight.w500)),
                    ],
                  ),
                  // Edit button — allows correcting a mistaken payment
                  InkWell(
                    onTap: () => _showEditPaymentDialog(context, ref, sale),
                    borderRadius: BorderRadius.circular(6),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey[300]!),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.edit_outlined, size: 13, color: Colors.grey[600]),
                          const SizedBox(width: 4),
                          Text('Edit Payment',
                              style: TextStyle(fontSize: 11, color: Colors.grey[600])),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref, Sale sale) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Sale?'),
        content: Text(
          'This will delete the sale of ₹${_fmt.format(sale.totalAmount)} '
          'for ${sale.customerName} and reverse the stock. This cannot be undone.',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await ref.read(firestoreServiceProvider).deleteSale(sale);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('Sale deleted'),
                        backgroundColor: Colors.red),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: $e')),
                  );
                }
              }
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _showCollectDialog(BuildContext context, WidgetRef ref, Sale sale) {
    final ctrl = TextEditingController(
        text: sale.dueAmount.toStringAsFixed(0));
    String selectedMethod = 'cash';

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: const Text('Collect Payment'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Customer: ${sale.customerName}',
                  style: const TextStyle(fontWeight: FontWeight.w500)),
              Text('Total Due: ₹${_fmt.format(sale.dueAmount)}',
                  style: TextStyle(color: Colors.orange[700])),
              const SizedBox(height: 16),
              TextField(
                controller: ctrl,
                decoration: const InputDecoration(
                  labelText: 'Amount Collected',
                  prefixText: '₹ ',
                ),
                keyboardType: TextInputType.number,
                autofocus: true,
              ),
              const SizedBox(height: 12),
              const Text('Payment via:',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
              const SizedBox(height: 8),
              Row(
                children: ['cash', 'upi', 'borrow'].map((m) {
                  final labels = {'cash': 'Cash', 'upi': 'UPI', 'borrow': 'Borrow'};
                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: ChoiceChip(
                        label: Text(labels[m]!,
                            style: const TextStyle(fontSize: 11)),
                        selected: selectedMethod == m,
                        onSelected: (_) => setS(() => selectedMethod = m),
                        selectedColor: AppTheme.primary.withValues(alpha: 0.2),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                final amount = double.tryParse(ctrl.text) ?? 0;
                if (amount <= 0 || amount > sale.dueAmount) return;
                Navigator.pop(ctx);
                await ref
                    .read(firestoreServiceProvider)
                    .recordPayment(sale.id, sale.customerId, amount);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                          '₹${_fmt.format(amount)} collected from ${sale.customerName}'),
                      backgroundColor: Colors.green[700],
                    ),
                  );
                }
              },
              child: const Text('Confirm'),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditPaymentDialog(BuildContext context, WidgetRef ref, Sale sale) {
    final ctrl = TextEditingController(text: sale.paidAmount.toStringAsFixed(0));

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Edit Payment'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.orange[50],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, size: 16, color: Colors.orange[700]),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Use this to correct a mistaken payment entry.',
                      style: TextStyle(fontSize: 12, color: Colors.orange[800]),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text('Sale Total: ₹${_fmt.format(sale.totalAmount)}',
                style: const TextStyle(fontWeight: FontWeight.w500)),
            Text('Currently Paid: ₹${_fmt.format(sale.paidAmount)}',
                style: TextStyle(color: Colors.grey[600], fontSize: 13)),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              decoration: const InputDecoration(
                labelText: 'Correct Paid Amount',
                prefixText: '₹ ',
                helperText: 'Set to 0 to mark as fully unpaid',
              ),
              keyboardType: TextInputType.number,
              autofocus: true,
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange[700]),
            onPressed: () async {
              final newPaid = double.tryParse(ctrl.text) ?? 0;
              if (newPaid < 0 || newPaid > sale.totalAmount) return;
              Navigator.pop(context);
              await ref.read(firestoreServiceProvider).editPayment(
                    sale.id,
                    sale.customerId,
                    sale.paidAmount,
                    newPaid,
                  );
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Payment updated successfully'),
                    backgroundColor: AppTheme.success,
                  ),
                );
              }
            },
            child: const Text('Update'),
          ),
        ],
      ),
    );
  }

}

// ── Bill button ───────────────────────────────────────────────────────────────

class _BillButton extends ConsumerStatefulWidget {
  final Sale sale;
  const _BillButton({required this.sale});

  @override
  ConsumerState<_BillButton> createState() => _BillButtonState();
}

class _BillButtonState extends ConsumerState<_BillButton> {
  bool _generating = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _generating ? null : _generate,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.indigo.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: Colors.indigo.withValues(alpha: 0.3)),
        ),
        child: _generating
            ? const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Icon(Icons.receipt_long_outlined, size: 14, color: Colors.indigo),
                  SizedBox(width: 4),
                  Text('Bill',
                      style: TextStyle(
                          fontSize: 11,
                          color: Colors.indigo,
                          fontWeight: FontWeight.w600)),
                ],
              ),
      ),
    );
  }

  Future<void> _generate() async {
    setState(() => _generating = true);
    try {
      final settings =
          await ref.read(firestoreServiceProvider).getShopSettings();
      await BillService.generateAndShare(widget.sale, settings);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Error generating bill: $e'),
              backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }
}

