import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/theme.dart';
import '../../providers/data_providers.dart';
import '../../models/customer.dart';
import 'add_customer_screen.dart';
import 'customer_ledger_screen.dart';
import 'due_analysis_screen.dart';

final _fmt = NumberFormat('#,##,##0', 'en_IN');

// Filter and sort state
enum _Filter { all, hasDues, activeRental, inactive30 }

enum _Sort { nameAZ, highestDue, recentFirst }

class CustomersScreen extends ConsumerStatefulWidget {
  const CustomersScreen({super.key});

  @override
  ConsumerState<CustomersScreen> createState() => _CustomersScreenState();
}

class _CustomersScreenState extends ConsumerState<CustomersScreen> {
  String _search = '';
  _Filter _filter = _Filter.all;
  _Sort _sort = _Sort.nameAZ;

  @override
  Widget build(BuildContext context) {
    final customersAsync = ref.watch(customersProvider);
    final rentalsAsync = ref.watch(rentalsProvider);
    final salesAsync = ref.watch(salesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Customers'),
        actions: [
          IconButton(
            icon: const Icon(Icons.sort_outlined),
            tooltip: 'Sort',
            onPressed: () => _showSortSheet(context),
          ),
          IconButton(
            icon: const Icon(Icons.warning_amber_outlined),
            tooltip: 'Due Analysis',
            onPressed: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const DueAnalysisScreen())),
          ),
          IconButton(
            icon: const Icon(Icons.person_add_outlined),
            onPressed: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const AddCustomerScreen())),
          ),
        ],
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
            child: TextField(
              onChanged: (v) => setState(() => _search = v.toLowerCase()),
              decoration: const InputDecoration(
                hintText: 'Search by name, village or mobile...',
                prefixIcon: Icon(Icons.search),
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            ),
          ),
          // Filter chips
          SizedBox(
            height: 44,
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              scrollDirection: Axis.horizontal,
              children: [
                _FilterChip(
                  label: 'All',
                  selected: _filter == _Filter.all,
                  onTap: () => setState(() => _filter = _Filter.all),
                ),
                const SizedBox(width: 8),
                _FilterChip(
                  label: 'Has Dues',
                  selected: _filter == _Filter.hasDues,
                  color: Colors.red,
                  onTap: () => setState(() => _filter = _Filter.hasDues),
                ),
                const SizedBox(width: 8),
                _FilterChip(
                  label: 'Active Rental',
                  selected: _filter == _Filter.activeRental,
                  color: Colors.indigo,
                  onTap: () => setState(() => _filter = _Filter.activeRental),
                ),
                const SizedBox(width: 8),
                _FilterChip(
                  label: 'Inactive 30+ days',
                  selected: _filter == _Filter.inactive30,
                  color: Colors.grey,
                  onTap: () => setState(() => _filter = _Filter.inactive30),
                ),
              ],
            ),
          ),
          Expanded(
            child: customersAsync.when(
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
              data: (customers) {
                // Build lookup structures
                final activeRentalNames = (rentalsAsync.valueOrNull ?? [])
                    .where((r) => r.status == 'active')
                    .map((r) => r.customerName.toLowerCase())
                    .toSet();

                // Last sale date per customer
                final lastSale = <String, DateTime>{};
                for (final s in (salesAsync.valueOrNull ?? [])) {
                  final prev = lastSale[s.customerId];
                  if (prev == null || s.date.isAfter(prev)) {
                    lastSale[s.customerId] = s.date;
                  }
                }

                // Apply search
                var filtered = _search.isEmpty
                    ? customers
                    : customers
                        .where((c) =>
                            c.name.toLowerCase().contains(_search) ||
                            c.village.toLowerCase().contains(_search) ||
                            c.mobile.contains(_search))
                        .toList();

                // Apply filter
                switch (_filter) {
                  case _Filter.hasDues:
                    filtered = filtered
                        .where((c) => c.dueAmount > 0)
                        .toList();
                  case _Filter.activeRental:
                    filtered = filtered
                        .where((c) => activeRentalNames
                            .contains(c.name.toLowerCase()))
                        .toList();
                  case _Filter.inactive30:
                    final cutoff = DateTime.now()
                        .subtract(const Duration(days: 30));
                    filtered = filtered.where((c) {
                      final last = lastSale[c.id];
                      return last == null || last.isBefore(cutoff);
                    }).toList();
                  case _Filter.all:
                    break;
                }

                // Apply sort
                switch (_sort) {
                  case _Sort.nameAZ:
                    filtered.sort((a, b) => a.name.compareTo(b.name));
                  case _Sort.highestDue:
                    filtered.sort(
                        (a, b) => b.dueAmount.compareTo(a.dueAmount));
                  case _Sort.recentFirst:
                    filtered.sort((a, b) {
                      final aLast = lastSale[a.id];
                      final bLast = lastSale[b.id];
                      if (aLast == null && bLast == null) return 0;
                      if (aLast == null) return 1;
                      if (bLast == null) return -1;
                      return bLast.compareTo(aLast);
                    });
                }

                if (filtered.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.people_outline,
                            size: 64, color: Colors.grey[300]),
                        const SizedBox(height: 16),
                        Text(
                          _search.isEmpty
                              ? _filter == _Filter.all
                                  ? 'No customers yet'
                                  : 'No customers match this filter'
                              : 'No results found',
                          style: TextStyle(color: Colors.grey[500]),
                        ),
                        if (_search.isEmpty && _filter == _Filter.all) ...[
                          const SizedBox(height: 8),
                          TextButton(
                            onPressed: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (_) =>
                                        const AddCustomerScreen())),
                            child: const Text('Add First Customer'),
                          ),
                        ],
                        if (_filter != _Filter.all) ...[
                          const SizedBox(height: 8),
                          TextButton(
                            onPressed: () =>
                                setState(() => _filter = _Filter.all),
                            child: const Text('Clear filter'),
                          ),
                        ],
                      ],
                    ),
                  );
                }

                // Sort label in header
                return Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 6, 16, 2),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '${filtered.length} customer${filtered.length == 1 ? '' : 's'}',
                            style: TextStyle(
                                color: Colors.grey[600], fontSize: 12),
                          ),
                          GestureDetector(
                            onTap: () => _showSortSheet(context),
                            child: Row(
                              children: [
                                const Icon(Icons.sort,
                                    size: 14, color: Colors.grey),
                                const SizedBox(width: 4),
                                Text(
                                  _sortLabel(_sort),
                                  style: const TextStyle(
                                      color: Colors.grey, fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: ListView.separated(
                        padding:
                            const EdgeInsets.symmetric(horizontal: 12),
                        itemCount: filtered.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(height: 2),
                        itemBuilder: (_, i) => _CustomerTile(
                          customer: filtered[i],
                          hasActiveRental: activeRentalNames.contains(
                              filtered[i].name.toLowerCase()),
                          lastSaleDate: lastSale[filtered[i].id],
                          onEdit: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => AddCustomerScreen(
                                  customer: filtered[i]),
                            ),
                          ),
                          onDelete: () => _confirmDelete(
                              context, ref, filtered[i]),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => const AddCustomerScreen())),
        child: const Icon(Icons.add),
      ),
    );
  }

  void _confirmDelete(
      BuildContext context, WidgetRef ref, Customer customer) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Customer?'),
        content: Text(
            'Delete "${customer.name}"? This will not delete their sales history.'),
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
                  .deleteCustomer(customer.id);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Customer deleted')),
                );
              }
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  String _sortLabel(_Sort s) => switch (s) {
        _Sort.nameAZ => 'Name A-Z',
        _Sort.highestDue => 'Highest Due',
        _Sort.recentFirst => 'Recent First',
      };

  void _showSortSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Sort By',
                style: TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 12),
            for (final s in _Sort.values)
              RadioListTile<_Sort>(
                title: Text(_sortLabel(s)),
                value: s,
                groupValue: _sort,
                onChanged: (v) {
                  setState(() => _sort = v!);
                  Navigator.pop(context);
                },
                activeColor: AppTheme.primary,
                contentPadding: EdgeInsets.zero,
              ),
          ],
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final Color? color;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.selected,
    this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppTheme.primary;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
        decoration: BoxDecoration(
          color: selected ? c : Colors.grey[100],
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: selected ? c : Colors.grey[300]!, width: 1),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: selected ? Colors.white : Colors.grey[700],
            fontWeight:
                selected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}

class _CustomerTile extends StatelessWidget {
  final Customer customer;
  final bool hasActiveRental;
  final DateTime? lastSaleDate;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _CustomerTile({
    required this.customer,
    required this.hasActiveRental,
    required this.lastSaleDate,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final hasDue = customer.dueAmount > 0;
    String? lastSeen;
    if (lastSaleDate != null) {
      final diff = DateTime.now().difference(lastSaleDate!).inDays;
      if (diff == 0) {
        lastSeen = 'Today';
      } else if (diff == 1) {
        lastSeen = 'Yesterday';
      } else {
        lastSeen = '$diff days ago';
      }
    }

    return Card(
      child: ListTile(
        onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) =>
                    CustomerLedgerScreen(customer: customer))),
        leading: Stack(
          clipBehavior: Clip.none,
          children: [
            CircleAvatar(
              backgroundColor:
                  AppTheme.primary.withValues(alpha: 0.12),
              child: Text(
                customer.name.isNotEmpty
                    ? customer.name[0].toUpperCase()
                    : '?',
                style: const TextStyle(
                  color: AppTheme.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            if (hasActiveRental)
              Positioned(
                right: -2,
                bottom: -2,
                child: Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    color: Colors.indigo,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 1.5),
                  ),
                  child: const Icon(Icons.handshake,
                      size: 8, color: Colors.white),
                ),
              ),
          ],
        ),
        title: Text(
          customer.name,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${customer.mobile}${customer.village.isNotEmpty ? ' • ${customer.village}' : ''}',
              style: const TextStyle(fontSize: 12),
            ),
            if (lastSeen != null)
              Text(
                'Last seen: $lastSeen',
                style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey[500]),
              ),
          ],
        ),
        isThreeLine: lastSeen != null,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (hasDue)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.red[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red[200]!),
                    ),
                    child: Text(
                      '₹${_fmt.format(customer.dueAmount)}',
                      style: TextStyle(
                        color: Colors.red[700],
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  )
                else
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.green[50],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Cleared',
                      style: TextStyle(
                        color: Colors.green[700],
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
              ],
            ),
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, size: 18, color: Colors.grey),
              onSelected: (v) {
                if (v == 'edit') onEdit();
                if (v == 'delete') onDelete();
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
}

// ignore: unused_element
void _sendReminder(Customer c) {
  final digits = c.mobile.replaceAll(RegExp(r'[^0-9]'), '');
  final waNumber = digits.length == 10 ? '91$digits' : digits;
  final message = 'Dear ${c.name},\n\n'
      'You have an outstanding balance of ₹${_fmt.format(c.dueAmount)} '
      'with Royal Building Materials.\n\n'
      'Please make payment at your earliest convenience.\n'
      'PhonePe Sajeed Ali: 8688270190\n\n'
      'Thank you!';
  final uri = Uri.parse(
      'https://wa.me/$waNumber?text=${Uri.encodeComponent(message)}');
  launchUrl(uri, mode: LaunchMode.externalNonBrowserApplication)
      .catchError((_) => false);
}
