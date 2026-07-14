import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/theme.dart';
import '../../models/customer.dart';
import '../../models/product.dart';
import '../../models/sale.dart';
import '../../models/sale_item.dart';
import '../../providers/data_providers.dart';
import '../../services/firestore_service.dart';

final _fmt = NumberFormat('#,##,##0', 'en_IN');

class AddSaleScreen extends ConsumerStatefulWidget {
  final Sale? sale; // non-null = edit mode
  const AddSaleScreen({super.key, this.sale});

  @override
  ConsumerState<AddSaleScreen> createState() => _AddSaleScreenState();
}

class _AddSaleScreenState extends ConsumerState<AddSaleScreen> {
  Customer? _selectedCustomer;
  final List<SaleItem> _items = [];
  double _transport = 0;
  String _paymentMethod = 'cash';
  double _paidAmount = 0;
  bool _saving = false;
  DateTime _saleDate = DateTime.now();

  final _transportCtrl = TextEditingController();
  final _paidCtrl = TextEditingController();

  bool get _isEditing => widget.sale != null;
  double get _subtotal => _items.fold(0, (s, e) => s + e.total);
  double get _total => _subtotal + _transport;
  double get _profit => _items.fold(0, (s, e) => s + e.profit);
  double get _due => _total - _paidAmount;

  @override
  void initState() {
    super.initState();
    final s = widget.sale;
    if (s != null) {
      _saleDate = s.date;
      _selectedCustomer = Customer(
        id: s.customerId,
        name: s.customerName,
        mobile: s.customerMobile,
        village: s.customerVillage,
        createdAt: DateTime.now(),
      );
      _items.addAll(List.from(s.items));
      _transport = s.transportCharge;
      _paymentMethod = s.paymentMethod;
      _paidAmount = s.paidAmount;
      if (s.transportCharge > 0) {
        _transportCtrl.text = s.transportCharge.toStringAsFixed(0);
      }
      if (s.paymentMethod == 'credit' && s.paidAmount > 0) {
        _paidCtrl.text = s.paidAmount.toStringAsFixed(0);
      }
    }
  }

  Future<void> _pickSaleDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _saleDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (picked != null) setState(() => _saleDate = picked);
  }

  @override
  void dispose() {
    _transportCtrl.dispose();
    _paidCtrl.dispose();
    super.dispose();
  }

  void _pickCustomer(BuildContext context, List<Customer> customers) async {
    final result = await showModalBottomSheet<Customer>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _CustomerPickerSheet(
        customers: customers,
        firestoreService: ref.read(firestoreServiceProvider),
      ),
    );
    if (result == null) return;
    setState(() => _selectedCustomer = result);

    // If customer has an outstanding due, ask to include it in this bill
    if (result.dueAmount > 0.01 && mounted) {
      final fmt = NumberFormat('#,##,##0', 'en_IN');
      final addDue = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Outstanding Due'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${result.name} has a pending due of ₹${fmt.format(result.dueAmount)}.',
                style: const TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 10),
              const Text(
                'Add the previous balance as the first item in this new bill?',
                style: TextStyle(fontSize: 13, color: Colors.grey),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('No, skip'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Yes, add it'),
            ),
          ],
        ),
      );

      if (addDue == true) {
        setState(() {
          // Remove any existing previous-balance item first (avoid duplicates)
          _items.removeWhere((i) => i.productId == '__prev_balance__');
          // Insert at position 0 so it appears first
          _items.insert(
            0,
            SaleItem(
              productId: '__prev_balance__',
              productName: 'Previous Balance',
              unit: 'Old Due',
              quantity: 1,
              rate: result.dueAmount,
              purchaseRate: 0,
            ),
          );
        });
      }
    }
  }

  void _addItem(BuildContext context, List<Product> products) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _AddItemSheet(
        products: products,
        onAdd: (item) => setState(() => _items.add(item)),
      ),
    );
  }

  Future<void> _save() async {
    if (_selectedCustomer == null) {
      _showError('Please select a customer');
      return;
    }
    if (_items.isEmpty) {
      _showError('Please add at least one item');
      return;
    }
    setState(() => _saving = true);
    try {
      final paid = _paymentMethod == 'cash' ? _total : _paidAmount;
      final newSale = Sale(
        id: _isEditing ? widget.sale!.id : '',
        customerId: _selectedCustomer!.id,
        customerName: _selectedCustomer!.name,
        customerMobile: _selectedCustomer!.mobile,
        customerVillage: _selectedCustomer!.village,
        items: _items,
        transportCharge: _transport,
        totalAmount: _total,
        paidAmount: paid,
        profit: _profit,
        paymentMethod: _paymentMethod,
        date: _saleDate,
      );
      final service = ref.read(firestoreServiceProvider);
      if (_isEditing) {
        await service.updateSale(widget.sale!, newSale);
      } else {
        await service.addSale(newSale);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_isEditing
                ? 'Sale updated successfully!'
                : 'Sale saved successfully!'),
            backgroundColor: AppTheme.success,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      _showError('Error: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.red),
    );
  }

  @override
  Widget build(BuildContext context) {
    final customersAsync = ref.watch(customersProvider);
    final productsAsync = ref.watch(productsProvider);

    return Scaffold(
      appBar: AppBar(title: Text(_isEditing ? 'Edit Sale' : 'New Sale')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Customer selector
          const Text('Customer *',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          const SizedBox(height: 8),
          customersAsync.when(
            loading: () => const LinearProgressIndicator(),
            error: (_, __) => const Text('Could not load customers'),
            data: (customers) => InkWell(
              onTap: _isEditing ? null : () => _pickCustomer(context, customers),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  border: Border.all(
                    color: _selectedCustomer != null
                        ? AppTheme.primary
                        : Colors.grey[300]!,
                  ),
                  borderRadius: BorderRadius.circular(10),
                  color: Colors.white,
                ),
                child: Row(
                  children: [
                    Icon(Icons.person_outline,
                        color: _selectedCustomer != null
                            ? AppTheme.primary
                            : Colors.grey),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _selectedCustomer == null
                          ? Text('Select or Add Customer *',
                              style: TextStyle(color: Colors.grey[500]))
                          : Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(_selectedCustomer!.name,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w600)),
                                if (_selectedCustomer!.mobile.isNotEmpty)
                                  Text(_selectedCustomer!.mobile,
                                      style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey[600])),
                              ],
                            ),
                    ),
                    const Icon(Icons.arrow_drop_down,
                        color: Colors.grey),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Sale date
          InkWell(
            onTap: _pickSaleDate,
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey[300]!),
                borderRadius: BorderRadius.circular(10),
                color: Colors.white,
              ),
              child: Row(
                children: [
                  const Icon(Icons.calendar_today_outlined, color: Colors.grey),
                  const SizedBox(width: 12),
                  Text(
                    'Date: ${DateFormat('dd MMM yyyy').format(_saleDate)}',
                    style: const TextStyle(fontSize: 14),
                  ),
                  const Spacer(),
                  Text('Change',
                      style: TextStyle(color: AppTheme.primary, fontSize: 13)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Items
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Items *',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              productsAsync.when(
                loading: () => const SizedBox.shrink(),
                error: (_, __) => const SizedBox.shrink(),
                data: (products) => TextButton.icon(
                  onPressed: () => _addItem(context, products),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Add Item'),
                ),
              ),
            ],
          ),
          if (_items.isEmpty)
            Container(
              padding: const EdgeInsets.all(24),
              margin: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey[200]!),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Center(
                child: Text('No items added yet',
                    style: TextStyle(color: Colors.grey)),
              ),
            )
          else
            ...List.generate(_items.length, (i) => _ItemRow(
                  item: _items[i],
                  onRemove: () => setState(() => _items.removeAt(i)),
                )),
          const SizedBox(height: 16),

          // Transport charge
          TextField(
            controller: _transportCtrl,
            onChanged: (v) => setState(() => _transport = double.tryParse(v) ?? 0),
            decoration: const InputDecoration(
              labelText: 'Transport Charge',
              prefixText: '₹ ',
              prefixIcon: Icon(Icons.local_shipping_outlined),
            ),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
          ),
          const SizedBox(height: 16),

          // Payment method
          const Text('Payment Method',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          const SizedBox(height: 8),
          Row(
            children: ['cash', 'credit', 'upi'].map((method) {
              final selected = _paymentMethod == method;
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(method.toUpperCase()),
                    selected: selected,
                    onSelected: (_) {
                      setState(() {
                        _paymentMethod = method;
                        if (method == 'cash') {
                          _paidAmount = _total;
                          _paidCtrl.text = _total.toStringAsFixed(0);
                        }
                      });
                    },
                    selectedColor: AppTheme.primary.withValues(alpha: 0.2),
                    checkmarkColor: AppTheme.primary,
                  ),
                ),
              );
            }).toList(),
          ),

          if (_paymentMethod == 'credit') ...[
            const SizedBox(height: 12),
            TextField(
              controller: _paidCtrl,
              onChanged: (v) => setState(() => _paidAmount = double.tryParse(v) ?? 0),
              decoration: const InputDecoration(
                labelText: 'Amount Paid (partial)',
                prefixText: '₹ ',
                prefixIcon: Icon(Icons.payments_outlined),
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
            ),
          ],
          const SizedBox(height: 24),

          // Bill summary
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey[200]!),
            ),
            child: Column(
              children: [
                _SummaryRow('Subtotal', '₹${_fmt.format(_subtotal)}'),
                if (_transport > 0)
                  _SummaryRow('Transport', '₹${_fmt.format(_transport)}'),
                const Divider(),
                _SummaryRow('Total', '₹${_fmt.format(_total)}',
                    bold: true, color: AppTheme.primary),
                _SummaryRow('Profit', '₹${_fmt.format(_profit)}',
                    color: AppTheme.success),
                if (_paymentMethod == 'credit' && _due > 0)
                  _SummaryRow('Due', '₹${_fmt.format(_due)}', color: Colors.red[700]!),
              ],
            ),
          ),
          const SizedBox(height: 24),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _saving ? null : _save,
              icon: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.save_outlined),
              label: Text(_isEditing ? 'Update Sale' : 'Save Sale'),
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }
}

class _ItemRow extends StatelessWidget {
  final SaleItem item;
  final VoidCallback onRemove;

  const _ItemRow({required this.item, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat('#,##,##0', 'en_IN');
    final isPrevBalance = item.productId == '__prev_balance__';

    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      color: isPrevBalance ? Colors.orange[50] : null,
      shape: isPrevBalance
          ? RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
              side: BorderSide(color: Colors.orange[300]!))
          : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            if (isPrevBalance)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Icon(Icons.history, size: 16, color: Colors.orange[700]),
              ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.productName,
                      style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: isPrevBalance ? Colors.orange[800] : null)),
                  if (!isPrevBalance)
                    Text(
                      '${item.quantity} ${item.unit} × ₹${fmt.format(item.rate)}',
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  if (isPrevBalance)
                    Text('Previous outstanding balance',
                        style: TextStyle(
                            fontSize: 11, color: Colors.orange[600])),
                ],
              ),
            ),
            Text('₹${fmt.format(item.total)}',
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: isPrevBalance
                        ? Colors.orange[800]
                        : AppTheme.primary)),
            IconButton(
              icon: const Icon(Icons.close, size: 18, color: Colors.red),
              onPressed: onRemove,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;
  final bool bold;
  final Color? color;

  const _SummaryRow(this.label, this.value,
      {this.bold = false, this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 13)),
          Text(
            value,
            style: TextStyle(
              fontWeight: bold ? FontWeight.bold : FontWeight.w500,
              color: color ?? Colors.black87,
              fontSize: bold ? 16 : 14,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Customer picker sheet (search + quick add) ───────────────────────────────

class _CustomerPickerSheet extends StatefulWidget {
  final List<Customer> customers;
  final FirestoreService firestoreService;
  const _CustomerPickerSheet(
      {required this.customers, required this.firestoreService});

  @override
  State<_CustomerPickerSheet> createState() => _CustomerPickerSheetState();
}

class _CustomerPickerSheetState extends State<_CustomerPickerSheet> {
  String _search = '';

  @override
  Widget build(BuildContext context) {
    final filtered = _search.isEmpty
        ? widget.customers
        : widget.customers
            .where((c) =>
                c.name.toLowerCase().contains(_search.toLowerCase()) ||
                c.mobile.contains(_search) ||
                c.village.toLowerCase().contains(_search.toLowerCase()))
            .toList();

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      maxChildSize: 0.95,
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
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.person_search,
                            size: 48, color: Colors.grey[300]),
                        const SizedBox(height: 12),
                        Text(
                          _search.isEmpty
                              ? 'No customers yet'
                              : 'No match — tap New to add',
                          style: TextStyle(color: Colors.grey[500]),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    controller: scrollCtrl,
                    itemCount: filtered.length,
                    itemBuilder: (_, i) {
                      final c = filtered[i];
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor:
                              AppTheme.primary.withValues(alpha: 0.1),
                          child: Text(
                            c.name[0].toUpperCase(),
                            style: const TextStyle(
                                color: AppTheme.primary,
                                fontWeight: FontWeight.bold),
                          ),
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
              final docRef = await widget.firestoreService.addCustomerAndReturn(customer);
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

// ─── Add item bottom sheet ────────────────────────────────────────────────────

class _AddItemSheet extends StatefulWidget {
  final List<Product> products;
  final void Function(SaleItem) onAdd;

  const _AddItemSheet({required this.products, required this.onAdd});

  @override
  State<_AddItemSheet> createState() => _AddItemSheetState();
}

class _AddItemSheetState extends State<_AddItemSheet> {
  Product? _product;
  final _qtyCtrl = TextEditingController(text: '1');
  final _rateCtrl = TextEditingController();
  String _search = '';

  @override
  void dispose() {
    _qtyCtrl.dispose();
    _rateCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _search.isEmpty
        ? widget.products
        : widget.products
            .where((p) => p.name.toLowerCase().contains(_search.toLowerCase()))
            .toList();

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Add Item',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            if (_product == null) ...[
              TextField(
                onChanged: (v) => setState(() => _search = v),
                decoration: const InputDecoration(
                  hintText: 'Search product...',
                  prefixIcon: Icon(Icons.search),
                  contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                ),
                autofocus: true,
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 200,
                child: ListView.builder(
                  itemCount: filtered.length,
                  itemBuilder: (_, i) => ListTile(
                    title: Text(filtered[i].name),
                    subtitle: Text(
                        '${filtered[i].stock} ${filtered[i].unit} • ₹${filtered[i].sellingPrice}'),
                    onTap: () => setState(() {
                      _product = filtered[i];
                      _rateCtrl.text = filtered[i].sellingPrice.toString();
                    }),
                  ),
                ),
              ),
            ] else ...[
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.inventory_2_outlined, color: AppTheme.primary),
                ),
                title: Text(_product!.name,
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text(
                    'Stock: ${_product!.stock} ${_product!.unit}'),
                trailing: TextButton(
                  onPressed: () => setState(() => _product = null),
                  child: const Text('Change'),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _qtyCtrl,
                      decoration: InputDecoration(
                        labelText: 'Qty (${_product!.unit})',
                        prefixIcon: const Icon(Icons.numbers_outlined),
                      ),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _rateCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Rate ₹',
                        prefixText: '₹ ',
                        prefixIcon: Icon(Icons.currency_rupee),
                      ),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    final qty = double.tryParse(_qtyCtrl.text) ?? 0;
                    final rate = double.tryParse(_rateCtrl.text) ?? 0;
                    if (qty <= 0 || rate <= 0) return;
                    widget.onAdd(SaleItem(
                      productId: _product!.id,
                      productName: _product!.name,
                      unit: _product!.unit,
                      quantity: qty,
                      rate: rate,
                      purchaseRate: _product!.purchasePrice,
                    ));
                    Navigator.pop(context);
                  },
                  child: const Text('Add to Sale'),
                ),
              ),
            ],
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
