import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../providers/data_providers.dart';
import '../../models/purchase.dart';
import '../../models/supplier_payment.dart';

final _fmt = NumberFormat('#,##,##0', 'en_IN');
final _dateFmt = DateFormat('dd MMM yyyy');

class SupplierLedgerScreen extends ConsumerWidget {
  final String supplierName;

  const SupplierLedgerScreen({super.key, required this.supplierName});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final purchasesAsync =
        ref.watch(purchasesBySupplierProvider(supplierName));
    final paymentsAsync =
        ref.watch(supplierPaymentsProvider(supplierName));

    return Scaffold(
      appBar: AppBar(
        title: Text(supplierName),
        backgroundColor: const Color(0xFF1A237E),
        foregroundColor: Colors.white,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _recordPayment(context, ref),
        icon: const Icon(Icons.payment_outlined),
        label: const Text('Record Payment'),
        backgroundColor: const Color(0xFF1A237E),
        foregroundColor: Colors.white,
      ),
      body: purchasesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (purchases) => paymentsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Error: $e')),
          data: (payments) =>
              _LedgerBody(purchases: purchases, payments: payments),
        ),
      ),
    );
  }

  void _recordPayment(BuildContext context, WidgetRef ref) {
    final amtCtrl = TextEditingController();
    final notesCtrl = TextEditingController();
    String method = 'cash';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => Padding(
          padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom,
              left: 20,
              right: 20,
              top: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Record Payment to $supplierName',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 16),
              TextField(
                controller: amtCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Amount Paid (₹)',
                  border: OutlineInputBorder(),
                  prefixText: '₹ ',
                ),
              ),
              const SizedBox(height: 12),
              // Payment method
              Wrap(
                spacing: 8,
                children: [
                  for (final m in [
                    ('cash', 'Cash'),
                    ('upi', 'UPI'),
                    ('bank', 'Bank Transfer'),
                  ])
                    ChoiceChip(
                      label: Text(m.$2),
                      selected: method == m.$1,
                      onSelected: (_) => setS(() => method = m.$1),
                      selectedColor: const Color(0xFF1A237E),
                      labelStyle: TextStyle(
                          color: method == m.$1
                              ? Colors.white
                              : Colors.black87),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: notesCtrl,
                decoration: const InputDecoration(
                  labelText: 'Notes (optional)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1A237E),
                      foregroundColor: Colors.white,
                      padding:
                          const EdgeInsets.symmetric(vertical: 14)),
                  onPressed: () async {
                    final amt = double.tryParse(amtCtrl.text.trim());
                    if (amt == null || amt <= 0) return;
                    Navigator.pop(ctx);
                    // Get supplier mobile from purchases
                    final purchases = ref
                        .read(purchasesBySupplierProvider(supplierName))
                        .valueOrNull;
                    final mobile = purchases?.isNotEmpty == true
                        ? (purchases!.first.supplierMobile)
                        : '';
                    await ref.read(firestoreServiceProvider).addSupplierPayment(
                          SupplierPayment(
                            id: '',
                            supplierName: supplierName,
                            supplierMobile: mobile,
                            amount: amt,
                            date: DateTime.now(),
                            notes: '[$method] ${notesCtrl.text.trim()}',
                          ),
                        );
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                              'Payment of ₹${_fmt.format(amt)} recorded'),
                          backgroundColor: Colors.green,
                        ),
                      );
                    }
                  },
                  child: const Text('Save Payment',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}

class _LedgerBody extends StatelessWidget {
  final List<Purchase> purchases;
  final List<SupplierPayment> payments;

  const _LedgerBody(
      {required this.purchases, required this.payments});

  @override
  Widget build(BuildContext context) {
    final creditPurchases =
        purchases.where((p) => p.paymentMethod == 'credit').toList();
    final totalDue =
        creditPurchases.fold<double>(0, (s, p) => s + p.totalAmount);
    final totalPaid =
        payments.fold<double>(0, (s, p) => s + p.amount);
    final outstanding = totalDue - totalPaid;

    // Build combined timeline
    final List<_LedgerEntry> entries = [
      for (final p in creditPurchases)
        _LedgerEntry(
          date: p.date,
          label: p.supplierName,
          description: p.items.map((i) => i.productName).join(', '),
          debit: p.totalAmount,
          credit: 0,
          type: _EntryType.purchase,
        ),
      for (final pay in payments)
        _LedgerEntry(
          date: pay.date,
          label: 'Payment Made',
          description: pay.notes,
          debit: 0,
          credit: pay.amount,
          type: _EntryType.payment,
        ),
    ]..sort((a, b) => b.date.compareTo(a.date));

    return Column(
      children: [
        // Summary header
        Container(
          color: const Color(0xFF1A237E),
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _SummaryChip(
                  label: 'Total Due',
                  value: '₹${_fmt.format(totalDue)}',
                  color: Colors.red[200]!),
              _SummaryChip(
                  label: 'Paid',
                  value: '₹${_fmt.format(totalPaid)}',
                  color: Colors.green[200]!),
              _SummaryChip(
                  label: 'Balance',
                  value: '₹${_fmt.format(outstanding)}',
                  color: outstanding > 0
                      ? const Color(0xFFFFCC02)
                      : Colors.green[200]!),
            ],
          ),
        ),
        if (entries.isEmpty)
          const Expanded(
            child: Center(
              child: Text('No transactions found',
                  style: TextStyle(color: Colors.grey)),
            ),
          )
        else
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: entries.length,
              itemBuilder: (ctx, i) {
                final e = entries[i];
                final isPurchase = e.type == _EntryType.purchase;
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: isPurchase
                                ? Colors.red.withOpacity(0.1)
                                : Colors.green.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            isPurchase
                                ? Icons.shopping_bag_outlined
                                : Icons.payment_outlined,
                            size: 18,
                            color: isPurchase ? Colors.red : Colors.green,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                isPurchase ? 'Purchase (Due)' : 'Payment Made',
                                style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                    color: isPurchase
                                        ? Colors.red[700]
                                        : Colors.green[700]),
                              ),
                              if (e.description.isNotEmpty)
                                Text(e.description,
                                    style: const TextStyle(
                                        color: Colors.grey, fontSize: 12)),
                              Text(_dateFmt.format(e.date),
                                  style: const TextStyle(
                                      color: Colors.grey, fontSize: 11)),
                            ],
                          ),
                        ),
                        Text(
                          isPurchase
                              ? '−₹${_fmt.format(e.debit)}'
                              : '+₹${_fmt.format(e.credit)}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: isPurchase ? Colors.red : Colors.green,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }
}

class _SummaryChip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _SummaryChip(
      {required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(label,
            style:
                const TextStyle(color: Colors.white70, fontSize: 11)),
        const SizedBox(height: 2),
        Text(value,
            style: TextStyle(
                color: color,
                fontWeight: FontWeight.bold,
                fontSize: 14)),
      ],
    );
  }
}

enum _EntryType { purchase, payment }

class _LedgerEntry {
  final DateTime date;
  final String label;
  final String description;
  final double debit;
  final double credit;
  final _EntryType type;

  _LedgerEntry({
    required this.date,
    required this.label,
    required this.description,
    required this.debit,
    required this.credit,
    required this.type,
  });
}
