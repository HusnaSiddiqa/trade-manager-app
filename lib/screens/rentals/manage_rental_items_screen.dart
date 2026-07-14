import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../models/rental_item.dart';
import '../../providers/data_providers.dart';

final _fmt = NumberFormat('#,##,##0', 'en_IN');

class ManageRentalItemsScreen extends ConsumerWidget {
  const ManageRentalItemsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final itemsAsync = ref.watch(rentalItemsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Rental Items Catalog'),
        backgroundColor: const Color(0xFF1A237E),
        foregroundColor: Colors.white,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showItemForm(context, ref, null),
        icon: const Icon(Icons.add),
        label: const Text('Add Item'),
        backgroundColor: const Color(0xFF1A237E),
        foregroundColor: Colors.white,
      ),
      body: itemsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (items) {
          final active = items.where((i) => i.isActive).toList()
            ..sort((a, b) => a.displayName.compareTo(b.displayName));
          final inactive = items.where((i) => !i.isActive).toList();

          if (items.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.inventory_2_outlined,
                      size: 72, color: Colors.grey[300]),
                  const SizedBox(height: 16),
                  const Text('No rental items yet',
                      style: TextStyle(color: Colors.grey)),
                  const SizedBox(height: 8),
                  const Text('Tap + Add Item to get started',
                      style: TextStyle(color: Colors.grey, fontSize: 12)),
                ],
              ),
            );
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (active.isNotEmpty) ...[
                _SectionLabel('Active Items (${active.length})'),
                ...active.map((item) => _ItemCard(
                    item: item,
                    onEdit: () => _showItemForm(context, ref, item),
                    onToggle: () => _toggleActive(context, ref, item))),
              ],
              if (inactive.isNotEmpty) ...[
                const SizedBox(height: 8),
                _SectionLabel('Inactive (${inactive.length})'),
                ...inactive.map((item) => _ItemCard(
                    item: item,
                    onEdit: () => _showItemForm(context, ref, item),
                    onToggle: () => _toggleActive(context, ref, item))),
              ],
              const SizedBox(height: 80),
            ],
          );
        },
      ),
    );
  }

  Future<void> _toggleActive(
      BuildContext context, WidgetRef ref, RentalItem item) async {
    final updated = RentalItem(
      id: item.id,
      category: item.category,
      subCategory: item.subCategory,
      totalQuantity: item.totalQuantity,
      rentedOut: item.rentedOut,
      defaultRentPerDay: item.defaultRentPerDay,
      isActive: !item.isActive,
    );
    await ref.read(firestoreServiceProvider).updateRentalItem(updated);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(item.isActive
            ? '${item.displayName} deactivated'
            : '${item.displayName} reactivated'),
      ));
    }
  }

  void _showItemForm(
      BuildContext context, WidgetRef ref, RentalItem? existing) {
    final catCtrl =
        TextEditingController(text: existing?.category ?? '');
    final subCtrl =
        TextEditingController(text: existing?.subCategory ?? '');
    final rentCtrl = TextEditingController(
        text: existing?.defaultRentPerDay == null
            ? ''
            : existing!.defaultRentPerDay > 0
                ? existing.defaultRentPerDay.toStringAsFixed(0)
                : '');
    final stockCtrl = TextEditingController(
        text: existing?.totalQuantity.toString() ?? '');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
            left: 20,
            right: 20,
            top: 24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                existing == null ? 'Add Rental Item' : 'Edit Rental Item',
                style: const TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 18),
              ),
              const SizedBox(height: 4),
              const Text('e.g. Stand, category: Props, sub-type: 5ft / 7ft',
                  style: TextStyle(color: Colors.grey, fontSize: 12)),
              const SizedBox(height: 16),
              TextField(
                controller: catCtrl,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Category / Item Name *',
                  hintText: 'e.g. Stand, Prop, Plank',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: subCtrl,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Sub-type (optional)',
                  hintText: 'e.g. 5ft, 7ft, Small, Large',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: rentCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Rent per day (₹) *',
                        border: OutlineInputBorder(),
                        prefixText: '₹ ',
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: stockCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Total stock *',
                        hintText: 'e.g. 20',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1A237E),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onPressed: () async {
                    final cat = catCtrl.text.trim();
                    final rent =
                        double.tryParse(rentCtrl.text.trim()) ?? 0;
                    final stock =
                        int.tryParse(stockCtrl.text.trim()) ?? 0;
                    if (cat.isEmpty || rent <= 0 || stock <= 0) {
                      ScaffoldMessenger.of(ctx).showSnackBar(
                        const SnackBar(
                            content: Text(
                                'Fill category, rent/day and stock count')),
                      );
                      return;
                    }
                    Navigator.pop(ctx);
                    final item = RentalItem(
                      id: existing?.id ?? '',
                      category: cat,
                      subCategory: subCtrl.text.trim(),
                      totalQuantity: stock,
                      rentedOut: existing?.rentedOut ?? 0,
                      defaultRentPerDay: rent,
                      isActive: existing?.isActive ?? true,
                    );
                    if (existing == null) {
                      await ref
                          .read(firestoreServiceProvider)
                          .addRentalItem(item);
                    } else {
                      await ref
                          .read(firestoreServiceProvider)
                          .updateRentalItem(item);
                    }
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text(existing == null
                            ? '${item.displayName} added'
                            : '${item.displayName} updated'),
                        backgroundColor: Colors.green,
                      ));
                    }
                  },
                  child: Text(
                    existing == null ? 'Add Item' : 'Save Changes',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
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

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(text,
          style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 13,
              color: Colors.grey)),
    );
  }
}

class _ItemCard extends StatelessWidget {
  final RentalItem item;
  final VoidCallback onEdit;
  final VoidCallback onToggle;

  const _ItemCard(
      {required this.item, required this.onEdit, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    final available = item.available;
    final isLow = available < 3 && item.isActive;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: item.isActive ? null : Colors.grey[50],
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            // Icon
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: item.isActive
                    ? const Color(0xFF1A237E).withValues(alpha: 0.1)
                    : Colors.grey.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Icons.construction_outlined,
                color: item.isActive
                    ? const Color(0xFF1A237E)
                    : Colors.grey,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            // Details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        item.displayName,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: item.isActive ? null : Colors.grey,
                        ),
                      ),
                      if (!item.isActive) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 1),
                          decoration: BoxDecoration(
                            color: Colors.grey[300],
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text('Inactive',
                              style: TextStyle(
                                  fontSize: 10, color: Colors.grey)),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Text(
                        '₹${_fmt.format(item.defaultRentPerDay)}/day',
                        style: TextStyle(
                            fontSize: 12,
                            color: item.isActive
                                ? const Color(0xFF1A237E)
                                : Colors.grey,
                            fontWeight: FontWeight.w600),
                      ),
                      const Text('  ·  ',
                          style: TextStyle(color: Colors.grey)),
                      Text(
                        'Stock: ${item.totalQuantity}',
                        style: const TextStyle(
                            fontSize: 12, color: Colors.grey),
                      ),
                      const Text('  ·  ',
                          style: TextStyle(color: Colors.grey)),
                      Text(
                        'Available: $available',
                        style: TextStyle(
                            fontSize: 12,
                            color: isLow ? Colors.red : Colors.green[700],
                            fontWeight: isLow ? FontWeight.bold : null),
                      ),
                    ],
                  ),
                  if (item.rentedOut > 0)
                    Text(
                      '${item.rentedOut} currently rented out',
                      style: TextStyle(
                          fontSize: 11,
                          color: Colors.orange[700]),
                    ),
                ],
              ),
            ),
            // Actions
            Column(
              children: [
                IconButton(
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit_outlined, size: 20),
                  tooltip: 'Edit',
                  color: const Color(0xFF1A237E),
                  padding: EdgeInsets.zero,
                  constraints:
                      const BoxConstraints(minWidth: 36, minHeight: 36),
                ),
                IconButton(
                  onPressed: onToggle,
                  icon: Icon(
                    item.isActive
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    size: 20,
                  ),
                  tooltip: item.isActive ? 'Deactivate' : 'Reactivate',
                  color: item.isActive ? Colors.red[400] : Colors.green,
                  padding: EdgeInsets.zero,
                  constraints:
                      const BoxConstraints(minWidth: 36, minHeight: 36),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
