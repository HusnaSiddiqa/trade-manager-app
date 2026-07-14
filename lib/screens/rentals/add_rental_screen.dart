import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/theme.dart';
import '../../models/customer.dart';
import '../../models/rental.dart';
import '../../models/rental_item.dart';
import '../../providers/data_providers.dart';
import '../../services/firestore_service.dart';
import 'rental_items_screen.dart';

// Holds one row of rental items in the form
class _EntryRow {
  RentalItem item;
  final TextEditingController qtyCtrl;
  final TextEditingController rentCtrl;
  final int originalQty; // non-zero when pre-filled from an existing rental entry

  _EntryRow({required this.item, int prefillQty = 1, double? prefillRent, this.originalQty = 0})
      : qtyCtrl = TextEditingController(text: prefillQty.toString()),
        rentCtrl = TextEditingController(
            text: prefillRent != null
                ? prefillRent.toStringAsFixed(0)
                : item.defaultRentPerDay > 0
                    ? item.defaultRentPerDay.toStringAsFixed(0)
                    : '');

  void dispose() {
    qtyCtrl.dispose();
    rentCtrl.dispose();
  }

  int get qty => int.tryParse(qtyCtrl.text) ?? 0;
  double get rent => double.tryParse(rentCtrl.text) ?? 0;
}

class AddRentalScreen extends ConsumerStatefulWidget {
  final Rental? rental;
  const AddRentalScreen({super.key, this.rental});

  @override
  ConsumerState<AddRentalScreen> createState() => _AddRentalScreenState();
}

class _AddRentalScreenState extends ConsumerState<AddRentalScreen> {
  final _nameCtrl = TextEditingController();
  final _mobileCtrl = TextEditingController();
  DateTime _issueDate = DateTime.now();
  DateTime? _returnDate;
  bool _saving = false;
  bool _entriesInitialized = false;

  final List<_EntryRow> _entries = [];

  bool get _isEditing => widget.rental != null;

  @override
  void initState() {
    super.initState();
    if (widget.rental != null) {
      _nameCtrl.text = widget.rental!.customerName;
      _mobileCtrl.text = widget.rental!.customerMobile;
      _issueDate = widget.rental!.issueDate;
      _returnDate = widget.rental!.returnDate;
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _mobileCtrl.dispose();
    for (final e in _entries) {
      e.dispose();
    }
    super.dispose();
  }

  Future<void> _pickCustomer(List<Customer> customers) async {
    final result = await showModalBottomSheet<Customer>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _RentalCustomerPickerSheet(
        customers: customers,
        firestoreService: ref.read(firestoreServiceProvider),
      ),
    );
    if (result != null) {
      setState(() {
        _nameCtrl.text = result.name;
        _mobileCtrl.text = result.mobile;
      });
    }
  }

  Future<void> _addItem(List<RentalItem> items) async {
    if (items.isEmpty) {
      Navigator.push(context,
          MaterialPageRoute(builder: (_) => const RentalItemsScreen()));
      return;
    }
    // Multi-select: returns a list of selected items
    final selected = await showModalBottomSheet<List<RentalItem>>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _ItemPickerSheet(items: items),
    );
    if (selected != null && selected.isNotEmpty) {
      setState(() {
        for (final item in selected) {
          _entries.add(_EntryRow(item: item));
        }
      });
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _issueDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (picked != null) setState(() => _issueDate = picked);
  }

  Future<void> _pickReturnDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _returnDate ?? DateTime.now(),
      firstDate: _issueDate,
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (picked != null) setState(() => _returnDate = picked);
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) { _err('Enter customer name'); return; }
    if (_entries.isEmpty) { _err('Add at least one rental item'); return; }

    for (final e in _entries) {
      if (e.qty <= 0) { _err('Enter valid quantity for ${e.item.displayName}'); return; }
      // For active rental editing: item.available already excludes what this rental
      // has reserved, so add back originalQty to get the true upper bound.
      final maxQty = (_isEditing && widget.rental!.status == 'active')
          ? e.item.available + e.originalQty
          : e.item.available;
      if (e.qty > maxQty) {
        _err('Only $maxQty available for ${e.item.displayName}'); return;
      }
      if (e.rent <= 0) { _err('Enter rent per day for ${e.item.displayName}'); return; }
    }

    FocusScope.of(context).unfocus();
    setState(() => _saving = true);
    try {
      final rentalEntries = _entries.map((e) => RentalEntry(
        itemName: e.item.displayName,
        rentalItemId: e.item.id,
        quantity: e.qty,
        rentPerDay: e.rent,
      )).toList();

      if (_isEditing) {
        final updatedRental = Rental(
          id: widget.rental!.id,
          customerId: widget.rental!.customerId,
          customerName: name,
          customerMobile: _mobileCtrl.text.trim(),
          entries: rentalEntries,
          issueDate: _issueDate,
          status: widget.rental!.status,
          totalRent: widget.rental!.totalRent,
          returnDate: _returnDate,
          returnPaymentMethod: widget.rental!.returnPaymentMethod,
        );
        await ref.read(firestoreServiceProvider).updateRental(widget.rental!, updatedRental);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Rental updated!'), backgroundColor: AppTheme.success),
          );
          Navigator.pop(context);
        }
      } else {
        final rental = Rental(
          id: '',
          customerId: '',
          customerName: name,
          customerMobile: _mobileCtrl.text.trim(),
          entries: rentalEntries,
          issueDate: _issueDate,
          status: 'active',
        );
        await ref.read(firestoreServiceProvider).addRental(rental);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Rental recorded!'), backgroundColor: AppTheme.success),
          );
          Navigator.pop(context);
        }
      }
    } catch (e) {
      _err('Error: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _err(String msg) {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Error'),
        content: Text(msg),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  double get _dailyTotal => _entries.fold(
      0.0, (sum, e) => sum + (e.qty * e.rent));

  @override
  Widget build(BuildContext context) {
    final items = ref.watch(rentalItemsProvider).maybeWhen(
        data: (v) => v, orElse: () => <RentalItem>[]);
    final customers = ref.watch(customersProvider).maybeWhen(
        data: (v) => v, orElse: () => <Customer>[]);

    // Pre-fill entries from existing rental once the catalog is loaded
    if (_isEditing && !_entriesInitialized && items.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _entriesInitialized) return;
        final rental = widget.rental!;
        final entriesToProcess = rental.entries.isNotEmpty
            ? rental.entries
            : rental.rentalItemId.isNotEmpty
                ? [RentalEntry(
                    itemName: rental.itemName,
                    rentalItemId: rental.rentalItemId,
                    quantity: rental.quantity.toInt(),
                    rentPerDay: rental.rentPerDay,
                  )]
                : <RentalEntry>[];
        final newEntries = <_EntryRow>[];
        for (final entry in entriesToProcess) {
          try {
            final catalogItem = items.firstWhere((i) => i.id == entry.rentalItemId);
            newEntries.add(_EntryRow(
              item: catalogItem,
              prefillQty: entry.quantity,
              prefillRent: entry.rentPerDay,
              originalQty: entry.quantity,
            ));
          } catch (_) {
            // Item removed from catalog; skip
          }
        }
        setState(() {
          _entries.addAll(newEntries);
          _entriesInitialized = true;
        });
      });
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Rental' : 'New Rental'),
        actions: [
          TextButton.icon(
            onPressed: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const RentalItemsScreen())),
            icon: const Icon(Icons.inventory_2_outlined, size: 18),
            label: const Text('Manage Items'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Customer
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _nameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Customer Name *',
                    prefixIcon: Icon(Icons.person_outline),
                  ),
                  textCapitalization: TextCapitalization.words,
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: customers.isEmpty
                    ? null
                    : () => _pickCustomer(customers),
                icon: const Icon(Icons.people_outline, size: 16),
                label: const Text('Pick', style: TextStyle(fontSize: 13)),
                style: OutlinedButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _mobileCtrl,
            decoration: const InputDecoration(
              labelText: 'Mobile Number',
              prefixIcon: Icon(Icons.phone_outlined),
            ),
            keyboardType: TextInputType.phone,
          ),
          const SizedBox(height: 16),

          // Issue date
          InkWell(
            onTap: _pickDate,
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey[300]!),
                borderRadius: BorderRadius.circular(10),
                color: Colors.white,
              ),
              child: Row(
                children: [
                  const Icon(Icons.calendar_today_outlined,
                      color: Colors.grey),
                  const SizedBox(width: 12),
                  Text(
                      'Issue Date: ${DateFormat('dd MMM yyyy').format(_issueDate)}'),
                  const Spacer(),
                  Text('Change',
                      style: TextStyle(
                          color: AppTheme.primary, fontSize: 13)),
                ],
              ),
            ),
          ),

          // Return date — only shown in edit mode for returned rentals
          if (_isEditing && widget.rental!.status == 'returned') ...[
            const SizedBox(height: 10),
            InkWell(
              onTap: _pickReturnDate,
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.green[300]!),
                  borderRadius: BorderRadius.circular(10),
                  color: Colors.green[50],
                ),
                child: Row(
                  children: [
                    Icon(Icons.event_available_outlined,
                        color: Colors.green[700]),
                    const SizedBox(width: 12),
                    Text(
                      _returnDate != null
                          ? 'Return Date: ${DateFormat('dd MMM yyyy').format(_returnDate!)}'
                          : 'Return Date: not set',
                      style: TextStyle(color: Colors.green[800]),
                    ),
                    const Spacer(),
                    Text('Change',
                        style: TextStyle(
                            color: Colors.green[700], fontSize: 13)),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 20),

          // Items header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Rental Items *',
                  style: TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 13)),
              TextButton.icon(
                onPressed: () => _addItem(items),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add Item'),
              ),
            ],
          ),

          if (_entries.isEmpty)
            Container(
              padding: const EdgeInsets.all(20),
              margin: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey[200]!),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(
                child: Text(
                  items.isEmpty
                      ? 'No items in catalog — tap "Manage Items" to add'
                      : 'Tap "Add Item" to add rental items',
                  style: TextStyle(color: Colors.grey[500]),
                  textAlign: TextAlign.center,
                ),
              ),
            )
          else
            ..._entries.asMap().entries.map((e) {
              final idx = e.key;
              final row = e.value;
              final maxQty = (_isEditing && widget.rental!.status == 'active')
                  ? row.item.available + row.originalQty
                  : null;
              return _EntryCard(
                row: row,
                onRemove: () => setState(() {
                  row.dispose();
                  _entries.removeAt(idx);
                }),
                onChanged: () => setState(() {}),
                maxQty: maxQty,
              );
            }),

          if (_entries.isNotEmpty && _dailyTotal > 0) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.indigo.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                'Total Daily Rent: ₹${_dailyTotal.toStringAsFixed(0)} / day',
                style: const TextStyle(
                    fontWeight: FontWeight.w600, color: Colors.indigo),
              ),
            ),
          ],

          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _saving ? null : _save,
              icon: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.save_outlined),
              label: Text(_isEditing ? 'Update Rental' : 'Save Rental'),
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }
}

// ── Single entry card ─────────────────────────────────────────────────────────

class _EntryCard extends StatelessWidget {
  final _EntryRow row;
  final VoidCallback onRemove;
  final VoidCallback onChanged;
  final int? maxQty;

  const _EntryCard(
      {required this.row, required this.onRemove, required this.onChanged, this.maxQty});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    row.item.displayName,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, color: Colors.indigo),
                  ),
                ),
                Text(
                  '${row.item.available} avail',
                  style: TextStyle(
                      fontSize: 12,
                      color: row.item.available > 0
                          ? Colors.green[700]
                          : Colors.red[700]),
                ),
                const SizedBox(width: 4),
                IconButton(
                  icon: const Icon(Icons.close, size: 18, color: Colors.red),
                  onPressed: onRemove,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: row.qtyCtrl,
                    onChanged: (_) => onChanged(),
                    decoration: InputDecoration(
                      labelText: 'Qty',
                      prefixIcon: const Icon(Icons.numbers_outlined),
                      helperText: 'Max: ${maxQty ?? row.item.available}',
                      isDense: true,
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: row.rentCtrl,
                    onChanged: (_) => onChanged(),
                    decoration: const InputDecoration(
                      labelText: 'Rent/Day',
                      prefixText: '₹ ',
                      prefixIcon: Icon(Icons.currency_rupee),
                      isDense: true,
                    ),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Customer picker sheet ─────────────────────────────────────────────────────

class _RentalCustomerPickerSheet extends StatefulWidget {
  final List<Customer> customers;
  final FirestoreService firestoreService;
  const _RentalCustomerPickerSheet(
      {required this.customers, required this.firestoreService});

  @override
  State<_RentalCustomerPickerSheet> createState() =>
      _RentalCustomerPickerSheetState();
}

class _RentalCustomerPickerSheetState
    extends State<_RentalCustomerPickerSheet> {
  String _search = '';

  @override
  Widget build(BuildContext context) {
    final filtered = _search.isEmpty
        ? widget.customers
        : widget.customers
            .where((c) =>
                c.name.toLowerCase().contains(_search.toLowerCase()) ||
                c.mobile.contains(_search))
            .toList();

    return DraggableScrollableSheet(
      initialChildSize: 0.65,
      maxChildSize: 0.92,
      minChildSize: 0.4,
      expand: false,
      builder: (_, scrollCtrl) => Column(
        children: [
          Container(
            margin: const EdgeInsets.only(top: 10),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2)),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    autofocus: true,
                    decoration: InputDecoration(
                      hintText: 'Search customers...',
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10)),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                    ),
                    onChanged: (v) => setState(() => _search = v),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: () => _showQuickAdd(context),
                  icon: const Icon(Icons.person_add_outlined, size: 18),
                  label: const Text('New'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 14),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: filtered.isEmpty
                ? Center(
                    child: Text('No customers found',
                        style: TextStyle(color: Colors.grey[500])))
                : ListView.builder(
                    controller: scrollCtrl,
                    itemCount: filtered.length,
                    itemBuilder: (_, i) {
                      final c = filtered[i];
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor:
                              Colors.indigo.withValues(alpha: 0.1),
                          child: Text(c.name[0].toUpperCase(),
                              style: const TextStyle(
                                  color: Colors.indigo,
                                  fontWeight: FontWeight.bold)),
                        ),
                        title: Text(c.name,
                            style:
                                const TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: Text(
                            [c.mobile, c.village]
                                .where((s) => s.isNotEmpty)
                                .join(' • '),
                            style: const TextStyle(fontSize: 12)),
                        onTap: () => Navigator.pop(context, c),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  void _showQuickAdd(BuildContext context) {
    final nameCtrl = TextEditingController(text: _search);
    final mobileCtrl = TextEditingController();
    final villageCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add New Customer'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(
                  labelText: 'Name *',
                  prefixIcon: Icon(Icons.person_outline)),
              textCapitalization: TextCapitalization.words,
              autofocus: true,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: mobileCtrl,
              decoration: const InputDecoration(
                  labelText: 'Mobile',
                  prefixIcon: Icon(Icons.phone_outlined)),
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: villageCtrl,
              decoration: const InputDecoration(
                  labelText: 'Village / Area',
                  prefixIcon: Icon(Icons.location_on_outlined)),
              textCapitalization: TextCapitalization.words,
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final name = nameCtrl.text.trim();
              if (name.isEmpty) return;
              final customer = Customer(
                id: '',
                name: name,
                mobile: mobileCtrl.text.trim(),
                village: villageCtrl.text.trim(),
                dueAmount: 0,
                createdAt: DateTime.now(),
              );
              final docRef =
                  await widget.firestoreService.addCustomerAndReturn(customer);
              final saved = Customer(
                id: docRef.id,
                name: name,
                mobile: mobileCtrl.text.trim(),
                village: villageCtrl.text.trim(),
                createdAt: DateTime.now(),
                dueAmount: 0,
              );
              if (ctx.mounted) Navigator.pop(ctx);
              if (context.mounted) Navigator.pop(context, saved);
            },
            child: const Text('Save & Select'),
          ),
        ],
      ),
    );
  }
}

// ── Multi-select item picker bottom sheet ────────────────────────────────────

class _ItemPickerSheet extends StatefulWidget {
  final List<RentalItem> items;
  const _ItemPickerSheet({required this.items});

  @override
  State<_ItemPickerSheet> createState() => _ItemPickerSheetState();
}

class _ItemPickerSheetState extends State<_ItemPickerSheet> {
  String _search = '';
  final Set<String> _selected = {}; // rental item IDs

  @override
  Widget build(BuildContext context) {
    final filtered = widget.items
        .where((i) =>
            i.displayName.toLowerCase().contains(_search.toLowerCase()))
        .toList();

    final grouped = <String, List<RentalItem>>{};
    for (final item in filtered) {
      grouped.putIfAbsent(item.category, () => []).add(item);
    }

    final selectedCount = _selected.length;

    return DraggableScrollableSheet(
      initialChildSize: 0.72,
      maxChildSize: 0.95,
      minChildSize: 0.4,
      expand: false,
      builder: (_, scrollCtrl) => Column(
        children: [
          // Drag handle
          Container(
            margin: const EdgeInsets.only(top: 10),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2)),
          ),
          // Header row: title + Done button
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Row(
              children: [
                const Text('Select Items',
                    style: TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 16)),
                const Spacer(),
                ElevatedButton(
                  onPressed: selectedCount == 0
                      ? null
                      : () {
                          final picks = widget.items
                              .where((i) => _selected.contains(i.id))
                              .toList();
                          Navigator.pop(context, picks);
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.indigo,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 18, vertical: 10),
                  ),
                  child: Text(
                    selectedCount == 0
                        ? 'Done'
                        : 'Done ($selectedCount)',
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
          // Search
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              autofocus: false,
              decoration: InputDecoration(
                hintText: 'Search items...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10)),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                isDense: true,
              ),
              onChanged: (v) => setState(() => _search = v),
            ),
          ),
          // Item list with checkboxes
          Expanded(
            child: filtered.isEmpty
                ? Center(
                    child: Text('No items found',
                        style: TextStyle(color: Colors.grey[500])))
                : ListView.builder(
                    controller: scrollCtrl,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    itemCount: grouped.length,
                    itemBuilder: (_, i) {
                      final cat = grouped.keys.elementAt(i);
                      final catItems = grouped[cat]!;
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            child: Text(cat,
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.indigo,
                                    fontSize: 13)),
                          ),
                          ...catItems.map((item) {
                            final avail = item.available;
                            final availColor = avail > 0
                                ? Colors.green[700]!
                                : Colors.red[700]!;
                            final isSelected = _selected.contains(item.id);
                            return CheckboxListTile(
                              value: isSelected,
                              onChanged: avail == 0
                                  ? null
                                  : (v) => setState(() {
                                        if (v == true) {
                                          _selected.add(item.id);
                                        } else {
                                          _selected.remove(item.id);
                                        }
                                      }),
                              title: Text(
                                item.subCategory.isEmpty
                                    ? item.category
                                    : item.subCategory,
                                style: TextStyle(
                                    color: avail == 0
                                        ? Colors.grey[400]
                                        : null,
                                    fontWeight: isSelected
                                        ? FontWeight.w600
                                        : FontWeight.normal),
                              ),
                              secondary: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: availColor.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  '$avail avail',
                                  style: TextStyle(
                                      color: availColor,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600),
                                ),
                              ),
                              activeColor: Colors.indigo,
                              controlAffinity:
                                  ListTileControlAffinity.leading,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8)),
                              dense: true,
                            );
                          }),
                          const Divider(height: 8),
                        ],
                      );
                    },
                  ),
          ),
          // Bottom Done bar
          SafeArea(
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: selectedCount == 0
                      ? null
                      : () {
                          final picks = widget.items
                              .where((i) => _selected.contains(i.id))
                              .toList();
                          Navigator.pop(context, picks);
                        },
                  icon: const Icon(Icons.check_circle_outline),
                  label: Text(selectedCount == 0
                      ? 'Select items above'
                      : 'Add $selectedCount item${selectedCount == 1 ? '' : 's'}'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.indigo,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
