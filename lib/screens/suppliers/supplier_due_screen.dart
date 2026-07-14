import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../providers/data_providers.dart';
import '../../models/purchase.dart';
import '../../models/supplier_payment.dart';
import 'supplier_ledger_screen.dart';

final _fmt = NumberFormat('#,##,##0', 'en_IN');

class SupplierDueScreen extends ConsumerWidget {
  const SupplierDueScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final purchasesAsync = ref.watch(purchasesProvider);
    final paymentsAsync = ref.watch(allSupplierPaymentsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Supplier Due'),
        backgroundColor: const Color(0xFF1A237E),
        foregroundColor: Colors.white,
      ),
      body: purchasesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (purchases) => paymentsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Error: $e')),
          data: (payments) => _SupplierDueList(
            purchases: purchases,
            payments: payments,
          ),
        ),
      ),
    );
  }
}

class _SupplierDueList extends StatelessWidget {
  final List<Purchase> purchases;
  final List<SupplierPayment> payments;

  const _SupplierDueList({
    required this.purchases,
    required this.payments,
  });

  @override
  Widget build(BuildContext context) {
    // Aggregate due per supplier
    final Map<String, _SupplierSummary> summaries = {};

    for (final p in purchases) {
      if (p.paymentMethod == 'credit') {
        final name = p.supplierName;
        summaries.putIfAbsent(
            name,
            () => _SupplierSummary(
                name: name,
                mobile: p.supplierMobile));
        summaries[name]!.totalDue += p.totalAmount;
        summaries[name]!.mobile = p.supplierMobile;
      }
    }

    for (final pay in payments) {
      final name = pay.supplierName;
      if (summaries.containsKey(name)) {
        summaries[name]!.totalPaid += pay.amount;
      }
    }

    final list = summaries.values
        .where((s) => s.outstanding > 0)
        .toList()
      ..sort((a, b) => b.outstanding.compareTo(a.outstanding));

    final totalOutstanding = list.fold<double>(
        0, (sum, s) => sum + s.outstanding);

    if (list.isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle_outline,
                size: 72, color: Colors.green),
            SizedBox(height: 16),
            Text('No pending supplier dues!',
                style: TextStyle(fontSize: 16, color: Colors.grey)),
          ],
        ),
      );
    }

    return Column(
      children: [
        // Total banner
        Container(
          width: double.infinity,
          color: const Color(0xFF1A237E),
          padding:
              const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Total Pending',
                      style: TextStyle(
                          color: Colors.white70, fontSize: 12)),
                  Text(
                    '${list.length} supplier${list.length == 1 ? '' : 's'}',
                    style: const TextStyle(
                        color: Colors.white, fontSize: 13),
                  ),
                ],
              ),
              Text(
                '₹${_fmt.format(totalOutstanding)}',
                style: const TextStyle(
                    color: Color(0xFFD4A017),
                    fontSize: 22,
                    fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: list.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (ctx, i) {
              final s = list[i];
              return Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => Navigator.push(
                    ctx,
                    MaterialPageRoute(
                      builder: (_) =>
                          SupplierLedgerScreen(supplierName: s.name),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const CircleAvatar(
                              backgroundColor: Color(0xFF1A237E),
                              radius: 20,
                              child: Icon(Icons.store_outlined,
                                  color: Colors.white, size: 20),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Text(s.name,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 15)),
                                  if (s.mobile.isNotEmpty)
                                    Text(s.mobile,
                                        style: const TextStyle(
                                            color: Colors.grey,
                                            fontSize: 12)),
                                ],
                              ),
                            ),
                            Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.end,
                              children: [
                                Text('₹${_fmt.format(s.outstanding)}',
                                    style: const TextStyle(
                                        color: Colors.red,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16)),
                                const Text('outstanding',
                                    style: TextStyle(
                                        color: Colors.grey,
                                        fontSize: 11)),
                              ],
                            ),
                          ],
                        ),
                        if (s.totalPaid > 0) ...[
                          const SizedBox(height: 8),
                          const Divider(height: 1),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment:
                                MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                  'Total: ₹${_fmt.format(s.totalDue)}  |  Paid: ₹${_fmt.format(s.totalPaid)}',
                                  style: const TextStyle(
                                      fontSize: 11,
                                      color: Colors.grey)),
                              const Icon(Icons.chevron_right,
                                  color: Colors.grey, size: 18),
                            ],
                          ),
                        ],
                        if (s.mobile.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              _ActionBtn(
                                icon: Icons.call_outlined,
                                label: 'Call',
                                color: Colors.green,
                                onTap: () =>
                                    launchUrl(Uri.parse('tel:${s.mobile}')),
                              ),
                              const SizedBox(width: 8),
                              _ActionBtn(
                                icon: Icons.chat_outlined,
                                label: 'WhatsApp',
                                color: const Color(0xFF25D366),
                                onTap: () {
                                  final digits = s.mobile
                                      .replaceAll(RegExp(r'[^0-9]'), '');
                                  final num = digits.length == 10
                                      ? '91$digits'
                                      : digits;
                                  launchUrl(Uri.parse(
                                      'https://wa.me/$num?text=${Uri.encodeComponent('Hello ${s.name}, you have a pending due of ₹${_fmt.format(s.outstanding)}. Please settle at your earliest convenience.')}'));
                                },
                              ),
                            ],
                          ),
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
  }
}

class _SupplierSummary {
  final String name;
  String mobile;
  double totalDue = 0;
  double totalPaid = 0;

  _SupplierSummary({required this.name, required this.mobile});

  double get outstanding => totalDue - totalPaid;
}

class _ActionBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ActionBtn({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 4),
            Text(label,
                style: TextStyle(
                    fontSize: 11,
                    color: color,
                    fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}
