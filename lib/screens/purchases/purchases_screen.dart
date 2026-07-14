import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/theme.dart';
import '../../models/purchase.dart';
import '../../providers/data_providers.dart';
import '../../services/bill_service.dart';
import 'add_purchase_screen.dart';

final _fmt = NumberFormat('#,##,##0', 'en_IN');

class PurchasesScreen extends ConsumerWidget {
  const PurchasesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final purchasesAsync = ref.watch(purchasesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Purchases'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline),
            onPressed: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const AddPurchaseScreen())),
          ),
        ],
      ),
      body: purchasesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (purchases) {
          if (purchases.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.shopping_cart_outlined,
                      size: 72, color: Colors.grey[300]),
                  const SizedBox(height: 16),
                  Text('No purchases recorded',
                      style: TextStyle(color: Colors.grey[500])),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const AddPurchaseScreen())),
                    icon: const Icon(Icons.add),
                    label: const Text('Record Purchase'),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: purchases.length,
            itemBuilder: (_, i) =>
                _PurchaseCard(purchase: purchases[i]),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => const AddPurchaseScreen())),
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _PurchaseCard extends ConsumerWidget {
  final Purchase purchase;
  const _PurchaseCard({required this.purchase});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(purchase.supplierName,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 15)),
                      if (purchase.supplierMobile.isNotEmpty)
                        Text(purchase.supplierMobile,
                            style: TextStyle(
                                fontSize: 12, color: Colors.grey[500])),
                    ],
                  ),
                ),
                Text(
                  '₹${_fmt.format(purchase.totalAmount)}',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: AppTheme.primary),
                ),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, size: 20),
                  onSelected: (v) => _onAction(context, ref, v),
                  itemBuilder: (_) => [
                    const PopupMenuItem(
                      value: 'invoice',
                      child: Row(children: [
                        Icon(Icons.receipt_long_outlined, size: 18),
                        SizedBox(width: 8),
                        Text('View Invoice'),
                      ]),
                    ),
                    const PopupMenuItem(
                      value: 'edit',
                      child: Row(children: [
                        Icon(Icons.edit_outlined, size: 18),
                        SizedBox(width: 8),
                        Text('Edit'),
                      ]),
                    ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(children: [
                        Icon(Icons.delete_outline,
                            color: Colors.red, size: 18),
                        SizedBox(width: 8),
                        Text('Delete',
                            style: TextStyle(color: Colors.red)),
                      ]),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Text(
                  DateFormat('dd MMM yyyy').format(purchase.date),
                  style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                ),
                const SizedBox(width: 8),
                _PaymentBadge(purchase.paymentMethod),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: purchase.items
                  .map((item) => Chip(
                        label: Text(
                          '${item.productName} (${item.quantity} ${item.unit})',
                          style: const TextStyle(fontSize: 11),
                        ),
                        visualDensity: VisualDensity.compact,
                        backgroundColor: Colors.grey[100],
                      ))
                  .toList(),
            ),
            if (purchase.notes.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text('Note: ${purchase.notes}',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600])),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _onAction(
      BuildContext context, WidgetRef ref, String action) async {
    switch (action) {
      case 'invoice':
        try {
          final settings =
              await ref.read(firestoreServiceProvider).getShopSettings();
          await BillService.generatePurchaseInvoice(purchase, settings);
        } catch (e) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                  content: Text('Error: $e'),
                  backgroundColor: Colors.red),
            );
          }
        }
        break;

      case 'edit':
        if (context.mounted) {
          Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => AddPurchaseScreen(purchase: purchase)));
        }
        break;

      case 'delete':
        if (context.mounted) await _confirmDelete(context, ref);
        break;
    }
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Purchase?'),
        content: Text(
            'Delete purchase from "${purchase.supplierName}"?\n\n'
            'Stock will be reversed for all items.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(firestoreServiceProvider).deletePurchase(purchase);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Purchase deleted'),
              backgroundColor: AppTheme.success),
        );
      }
    }
  }
}

class _PaymentBadge extends StatelessWidget {
  final String method;
  const _PaymentBadge(this.method);

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (method) {
      'upi' => ('UPI', Colors.purple),
      'credit' => ('Due', Colors.orange[700]!),
      _ => ('Cash', Colors.green[700]!),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(label,
          style: TextStyle(
              fontSize: 11, color: color, fontWeight: FontWeight.w600)),
    );
  }
}
