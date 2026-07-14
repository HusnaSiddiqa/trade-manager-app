import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/rental_item.dart';
import '../../providers/data_providers.dart';
import 'add_rental_item_screen.dart';

class RentalItemsScreen extends ConsumerWidget {
  const RentalItemsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final itemsAsync = ref.watch(rentalItemsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Rental Item Catalog'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline),
            onPressed: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const AddRentalItemScreen())),
          ),
        ],
      ),
      body: itemsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (items) {
          if (items.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.inventory_2_outlined, size: 72, color: Colors.grey[300]),
                  const SizedBox(height: 16),
                  Text('No rental items added yet',
                      style: TextStyle(color: Colors.grey[500], fontSize: 16)),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: () => Navigator.push(context,
                        MaterialPageRoute(
                            builder: (_) => const AddRentalItemScreen())),
                    icon: const Icon(Icons.add),
                    label: const Text('Add First Item'),
                  ),
                ],
              ),
            );
          }

          // Group by category
          final grouped = <String, List<RentalItem>>{};
          for (final item in items) {
            grouped.putIfAbsent(item.category, () => []).add(item);
          }

          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: grouped.length,
            itemBuilder: (_, i) {
              final category = grouped.keys.elementAt(i);
              final categoryItems = grouped[category]!;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      category,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: Colors.indigo),
                    ),
                  ),
                  ...categoryItems.map((item) => _RentalItemTile(item: item)),
                  const SizedBox(height: 8),
                ],
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AddRentalItemScreen())),
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _RentalItemTile extends ConsumerWidget {
  final RentalItem item;
  const _RentalItemTile({required this.item});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final availColor = item.available > 0 ? Colors.green[700]! : Colors.red[700]!;

    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        title: Text(
          item.subCategory.isEmpty ? item.category : '${item.category} — ${item.subCategory}',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: item.defaultRentPerDay > 0
            ? Text('₹${item.defaultRentPerDay.toStringAsFixed(0)}/day',
                style: TextStyle(color: Colors.grey[600], fontSize: 12))
            : null,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Available badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: availColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${item.available}',
                    style: TextStyle(
                        color: availColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 16),
                  ),
                  Text('avail',
                      style: TextStyle(color: availColor, fontSize: 9)),
                ],
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${item.totalQuantity}',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  Text('total',
                      style: TextStyle(color: Colors.grey[600], fontSize: 9)),
                ],
              ),
            ),
            const SizedBox(width: 4),
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, size: 18),
              onSelected: (v) {
                if (v == 'edit') {
                  Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => AddRentalItemScreen(item: item)));
                } else if (v == 'delete') {
                  _confirmDelete(context, ref);
                }
              },
              itemBuilder: (_) => [
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
                    Icon(Icons.delete_outline, color: Colors.red, size: 18),
                    SizedBox(width: 8),
                    Text('Delete', style: TextStyle(color: Colors.red)),
                  ]),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Item?'),
        content: Text('Delete "${item.displayName}" from the catalog?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(ctx);
              await ref.read(firestoreServiceProvider).deleteRentalItem(item.id);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
