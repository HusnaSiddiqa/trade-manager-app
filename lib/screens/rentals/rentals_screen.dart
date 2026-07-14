import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/theme.dart';
import '../../models/rental.dart';
import '../../providers/data_providers.dart';
import '../../services/bill_service.dart';
import 'add_rental_screen.dart';
import 'manage_rental_items_screen.dart';

final _fmt = NumberFormat('#,##,##0', 'en_IN');

class RentalsScreen extends ConsumerStatefulWidget {
  const RentalsScreen({super.key});

  @override
  ConsumerState<RentalsScreen> createState() => _RentalsScreenState();
}

class _RentalsScreenState extends ConsumerState<RentalsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final rentalsAsync = ref.watch(rentalsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Rentals'),
        actions: [
          IconButton(
            icon: const Icon(Icons.inventory_2_outlined),
            tooltip: 'Manage Items',
            onPressed: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const ManageRentalItemsScreen())),
          ),
          IconButton(
            icon: const Icon(Icons.add_circle_outline),
            onPressed: () => Navigator.push(
                context, MaterialPageRoute(builder: (_) => const AddRentalScreen())),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(text: 'Active'),
            Tab(text: 'Returned'),
          ],
        ),
      ),
      body: rentalsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (rentals) {
          final active = rentals.where((r) => r.status == 'active').toList()
            ..sort((a, b) {
              // overdue (>7 days) first, then by days descending
              final aOver = a.daysOut > 7;
              final bOver = b.daysOut > 7;
              if (aOver != bOver) return aOver ? -1 : 1;
              return b.daysOut.compareTo(a.daysOut);
            });
          final returned = rentals.where((r) => r.status == 'returned').toList();

          return TabBarView(
            controller: _tabController,
            children: [
              _RentalList(rentals: active, showReturn: true),
              _RentalList(rentals: returned, showReturn: false),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.push(
            context, MaterialPageRoute(builder: (_) => const AddRentalScreen())),
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _RentalList extends ConsumerWidget {
  final List<Rental> rentals;
  final bool showReturn;

  const _RentalList({required this.rentals, required this.showReturn});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (rentals.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.handshake_outlined, size: 64, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text(
              showReturn ? 'No active rentals' : 'No returned rentals',
              style: TextStyle(color: Colors.grey[500]),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: rentals.length,
      itemBuilder: (_, i) => _RentalCard(rental: rentals[i], showReturn: showReturn),
    );
  }
}

class _RentalCard extends ConsumerWidget {
  final Rental rental;
  final bool showReturn;

  const _RentalCard({required this.rental, required this.showReturn});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final days = rental.daysOut;
    final rent = rental.calculatedRent;
    final isOverdue = showReturn && days > 7;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: isOverdue
            ? const BorderSide(color: Colors.red, width: 1.5)
            : BorderSide.none,
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        rental.customerName,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                      Text(rental.customerMobile,
                          style: TextStyle(fontSize: 12, color: Colors.grey[500])),
                    ],
                  ),
                ),
                Row(
                  children: [
                    if (isOverdue) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '$days days overdue',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(width: 6),
                    ],
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: showReturn
                            ? Colors.indigo.withValues(alpha: 0.1)
                            : Colors.green.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        showReturn ? 'Active' : 'Returned',
                        style: TextStyle(
                          color: showReturn ? Colors.indigo : Colors.green[700],
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const Divider(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.handshake_outlined, size: 16, color: Colors.grey),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    rental.itemsSummary,
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                _InfoChip(
                  Icons.calendar_today_outlined,
                  'Issued: ${DateFormat('dd MMM').format(rental.issueDate)}',
                ),
                const SizedBox(width: 8),
                _InfoChip(
                  isOverdue ? Icons.warning_amber_rounded : Icons.timer_outlined,
                  '$days day${days > 1 ? 's' : ''}',
                  color: isOverdue ? Colors.red : null,
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Rent: ₹${_fmt.format(rent)}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primary,
                    fontSize: 15,
                  ),
                ),
                if (!showReturn && rental.returnPaymentMethod.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      rental.returnPaymentMethod == 'borrow'
                          ? 'BORROW'
                          : rental.returnPaymentMethod.toUpperCase(),
                      style: TextStyle(
                          fontSize: 11,
                          color: rental.returnPaymentMethod == 'borrow'
                              ? Colors.orange[700]
                              : Colors.green[700],
                          fontWeight: FontWeight.bold),
                    ),
                  ),
                if (showReturn)
                  Row(
                    children: [
                      if (rental.customerMobile.isNotEmpty)
                        IconButton(
                          onPressed: () => _sendWhatsAppReminder(),
                          icon: const Icon(Icons.chat_outlined,
                              color: Color(0xFF25D366), size: 20),
                          tooltip: 'WhatsApp Reminder',
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(
                              minWidth: 36, minHeight: 36),
                        ),
                      const SizedBox(width: 4),
                      ElevatedButton.icon(
                        onPressed: () => _confirmReturn(context, ref),
                        icon: const Icon(Icons.check_circle_outline, size: 16),
                        label: const Text('Return'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green[700],
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                          textStyle: const TextStyle(fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                // 3-dot menu: Edit + Delete
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, size: 18, color: Colors.grey),
                  onSelected: (v) {
                    if (v == 'edit') {
                      Navigator.push(context, MaterialPageRoute(
                        builder: (_) => AddRentalScreen(rental: rental),
                      ));
                    } else if (v == 'delete') {
                      _confirmDelete(context, ref);
                    }
                  },
                  itemBuilder: (_) => [
                    const PopupMenuItem(
                      value: 'edit',
                      child: Row(children: [
                        Icon(Icons.edit_outlined, color: Colors.indigo, size: 18),
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
          ],
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Rental?'),
        content: Text(
            'Delete rental for ${rental.customerName} — ${rental.itemsSummary}?'
            '${rental.status == 'active' ? '\n\nThis will restore the item stock.' : ''}'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () async {
              Navigator.pop(ctx);
              await ref
                  .read(firestoreServiceProvider)
                  .deleteRental(rental);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Rental deleted')),
                );
              }
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _sendWhatsAppReminder() {
    final days = rental.daysOut;
    final rent = rental.calculatedRent;
    final fmt = NumberFormat('#,##,##0', 'en_IN');
    final msg = 'Hello ${rental.customerName},\n\n'
        'This is a reminder regarding your rental from Royal Building Materials.\n\n'
        'Items: ${rental.itemsSummary}\n'
        'Issued: ${DateFormat('dd MMM yyyy').format(rental.issueDate)}\n'
        'Days out: $days days\n'
        'Accrued rent: ₹${fmt.format(rent)}\n\n'
        'Please arrange to return the items at your earliest convenience.\n\n'
        'Thank you!';
    final digits = rental.customerMobile.replaceAll(RegExp(r'[^0-9]'), '');
    final num = digits.length == 10 ? '91$digits' : digits;
    launchUrl(Uri.parse(
        'https://wa.me/$num?text=${Uri.encodeComponent(msg)}'));
  }

  void _confirmReturn(BuildContext context, WidgetRef ref) {
    final rent = rental.calculatedRent;
    String selectedMethod = 'cash';

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: const Text('Confirm Return'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Customer: ${rental.customerName}'),
              Text('Items: ${rental.itemsSummary}'),
              Text('Days: ${rental.daysOut}'),
              Text(
                'Total Rent: ₹${_fmt.format(rent)}',
                style: const TextStyle(
                    fontWeight: FontWeight.bold, color: AppTheme.primary),
              ),
              const SizedBox(height: 16),
              const Text('Payment Mode:',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
              const SizedBox(height: 8),
              Row(
                children: ['cash', 'upi', 'borrow'].map((m) {
                  final labels = {'cash': 'Cash', 'upi': 'UPI', 'borrow': 'Borrow'};
                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: ChoiceChip(
                        label: Text(labels[m]!,
                            style: const TextStyle(fontSize: 12)),
                        selected: selectedMethod == m,
                        onSelected: (_) => setS(() => selectedMethod = m),
                        selectedColor: Colors.indigo.withValues(alpha: 0.2),
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
                final method = selectedMethod;
                Navigator.pop(ctx);
                await ref
                    .read(firestoreServiceProvider)
                    .returnRental(
                      rental.id,
                      rent,
                      method,
                      entries: rental.entries,
                      rentalItemId: rental.rentalItemId,
                      rentedQuantity: rental.quantity.toInt(),
                    );
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Rental returned — generating receipt...'),
                      backgroundColor: AppTheme.success,
                    ),
                  );
                }
                try {
                  final shopSettings = await ref
                      .read(firestoreServiceProvider)
                      .getShopSettings();
                  await BillService.generateRentalReceipt(
                    rental, shopSettings, method);
                } catch (_) {}
              },
              child: const Text('Confirm Return'),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? color;
  const _InfoChip(this.icon, this.label, {this.color});

  @override
  Widget build(BuildContext context) {
    final c = color ?? Colors.grey[700]!;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color != null
            ? color!.withValues(alpha: 0.1)
            : Colors.grey[100],
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: c),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(fontSize: 11, color: c, fontWeight: color != null ? FontWeight.bold : null)),
        ],
      ),
    );
  }
}
