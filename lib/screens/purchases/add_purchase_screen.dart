import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/theme.dart';
import '../../models/product.dart';
import '../../models/purchase.dart';
import '../../providers/data_providers.dart';

final _fmt = NumberFormat('#,##,##0', 'en_IN');

class AddPurchaseScreen extends ConsumerStatefulWidget {
  final Purchase? purchase; // non-null when editing
  const AddPurchaseScreen({super.key, this.purchase});

  @override
  ConsumerState<AddPurchaseScreen> createState() => _AddPurchaseScreenState();
}

class _AddPurchaseScreenState extends ConsumerState<AddPurchaseScreen> {
  final _supplierCtrl = TextEditingController();
  final _mobileCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  final List<PurchaseItem> _items = [];
  String _paymentMethod = 'cash';
  bool _saving = false;

  bool get _isEditing => widget.purchase != null;
  double get _total => _items.fold(0, (s, e) => s + e.total);

  @override
  void initState() {
    super.initState();
    final p = widget.purchase;
    if (p != null) {
      _supplierCtrl.text = p.supplierName;
      _mobileCtrl.text = p.supplierMobile;
      _notesCtrl.text = p.notes;
      _items.addAll(p.items);
      _paymentMethod = p.paymentMethod;
    }
  }

  @override
  void dispose() {
    _supplierCtrl.dispose();
    _mobileCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickSupplier(List<String> suppliers) async {
    final result = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _SupplierPickerSheet(suppliers: suppliers),
    );
    if (result != null) setState(() => _supplierCtrl.text = result);
  }

  void _addItem(BuildContext context, List<Product> products) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _PurchaseItemSheet(
        products: products,
        onAdd: (item) => setState(() => _items.add(item)),
      ),
    );
  }

  Future<void> _save() async {
    if (_supplierCtrl.text.trim().isEmpty) {
      _err('Enter supplier name');
      return;
    }
    if (_items.isEmpty) {
      _err('Add at least one item');
      return;
    }
    setState(() => _saving = true);
    try {
      final newPurchase = Purchase(
        id: widget.purchase?.id ?? '',
        supplierName: _supplierCtrl.text.trim(),
        supplierMobile: _mobileCtrl.text.trim(),
        items: _items,
        totalAmount: _total,
        notes: _notesCtrl.text.trim(),
        date: widget.purchase?.date ?? DateTime.now(),
        paymentMethod: _paymentMethod,
      );
      final svc = ref.read(firestoreServiceProvider);
      if (_isEditing) {
        await svc.updatePurchase(widget.purchase!, newPurchase);
      } else {
        await svc.addPurchase(newPurchase);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(_isEditing ? 'Purchase updated!' : 'Purchase saved!'),
            backgroundColor: AppTheme.success));
        Navigator.pop(context);
      }
    } catch (e) {
      _err('Error: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _err(String msg) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.red));

  @override
  Widget build(BuildContext context) {
    final productsAsync = ref.watch(productsProvider);
    final suppliers =
        ref.watch(suppliersProvider).maybeWhen(data: (v) => v, orElse: () => <String>[]);

    return Scaffold(
      appBar: AppBar(
          title: Text(_isEditing ? 'Edit Purchase' : 'Record Purchase')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Supplier
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _supplierCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Supplier Name *',
                    prefixIcon: Icon(Icons.business_outlined),
                  ),
                  textCapitalization: TextCapitalization.words,
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: suppliers.isEmpty
                    ? null
                    : () => _pickSupplier(suppliers),
                icon: const Icon(Icons.search, size: 16),
                label: const Text('Search', style: TextStyle(fontSize: 13)),
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
              labelText: 'Supplier Mobile',
              prefixIcon: Icon(Icons.phone_outlined),
            ),
            keyboardType: TextInputType.phone,
          ),
          const SizedBox(height: 16),

          // Payment Method
          const Text('Payment Method',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          const SizedBox(height: 8),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(
                value: 'cash',
                label: Text('Cash'),
                icon: Icon(Icons.payments_outlined, size: 16),
              ),
              ButtonSegment(
                value: 'upi',
                label: Text('UPI'),
                icon: Icon(Icons.qr_code_scanner_outlined, size: 16),
              ),
              ButtonSegment(
                value: 'credit',
                label: Text('Due'),
                icon: Icon(Icons.credit_card_outlined, size: 16),
              ),
            ],
            selected: {_paymentMethod},
            onSelectionChanged: (s) =>
                setState(() => _paymentMethod = s.first),
          ),
          const SizedBox(height: 16),

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
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey[200]!),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Center(
                  child: Text('No items added',
                      style: TextStyle(color: Colors.grey))),
            )
          else
            ...List.generate(
              _items.length,
              (i) => Card(
                margin: const EdgeInsets.only(bottom: 6),
                child: ListTile(
                  title: Text(_items[i].productName,
                      style: const TextStyle(fontWeight: FontWeight.w500)),
                  subtitle: Text(
                      '${_items[i].quantity} ${_items[i].unit} × ₹${_fmt.format(_items[i].rate)}'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('₹${_fmt.format(_items[i].total)}',
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(width: 4),
                      GestureDetector(
                        onTap: () => setState(() => _items.removeAt(i)),
                        child: const Icon(Icons.close, size: 18, color: Colors.red),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          const SizedBox(height: 12),
          TextField(
            controller: _notesCtrl,
            decoration: const InputDecoration(
              labelText: 'Notes (optional)',
              prefixIcon: Icon(Icons.notes_outlined),
            ),
          ),
          if (_items.isNotEmpty) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey[200]!),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Total Amount',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  Text('₹${_fmt.format(_total)}',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                          color: AppTheme.primary)),
                ],
              ),
            ),
          ],
          const SizedBox(height: 24),
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
              label: Text(_isEditing ? 'Update Purchase' : 'Save Purchase'),
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }
}

// ── Supplier picker sheet ─────────────────────────────────────────────────────

class _SupplierPickerSheet extends StatefulWidget {
  final List<String> suppliers;
  const _SupplierPickerSheet({required this.suppliers});

  @override
  State<_SupplierPickerSheet> createState() => _SupplierPickerSheetState();
}

class _SupplierPickerSheetState extends State<_SupplierPickerSheet> {
  String _search = '';

  @override
  Widget build(BuildContext context) {
    final filtered = _search.isEmpty
        ? widget.suppliers
        : widget.suppliers
            .where((s) => s.toLowerCase().contains(_search.toLowerCase()))
            .toList();

    return DraggableScrollableSheet(
      initialChildSize: 0.55,
      maxChildSize: 0.85,
      minChildSize: 0.35,
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
            padding: const EdgeInsets.all(16),
            child: TextField(
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'Search existing suppliers...',
                prefixIcon: const Icon(Icons.search),
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
              onChanged: (v) => setState(() => _search = v),
            ),
          ),
          Expanded(
            child: filtered.isEmpty
                ? Center(
                    child: Text('No matching supplier',
                        style: TextStyle(color: Colors.grey[500])))
                : ListView.builder(
                    controller: scrollCtrl,
                    itemCount: filtered.length,
                    itemBuilder: (_, i) => ListTile(
                      leading: CircleAvatar(
                        backgroundColor: AppTheme.primary.withValues(alpha: 0.1),
                        child: Text(
                          filtered[i][0].toUpperCase(),
                          style: const TextStyle(
                              color: AppTheme.primary,
                              fontWeight: FontWeight.bold),
                        ),
                      ),
                      title: Text(filtered[i]),
                      onTap: () => Navigator.pop(context, filtered[i]),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

// ── Purchase item picker sheet ────────────────────────────────────────────────

class _PurchaseItemSheet extends StatefulWidget {
  final List<Product> products;
  final void Function(PurchaseItem) onAdd;
  const _PurchaseItemSheet({required this.products, required this.onAdd});

  @override
  State<_PurchaseItemSheet> createState() => _PurchaseItemSheetState();
}

class _PurchaseItemSheetState extends State<_PurchaseItemSheet> {
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
            const Text('Add Purchase Item',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            if (_product == null) ...[
              TextField(
                onChanged: (v) => setState(() => _search = v),
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: 'Search product...',
                  prefixIcon: Icon(Icons.search),
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 200,
                child: ListView.builder(
                  itemCount: filtered.length,
                  itemBuilder: (_, i) => ListTile(
                    title: Text(filtered[i].name),
                    subtitle: Text(
                        'Current stock: ${filtered[i].stock} ${filtered[i].unit}'),
                    onTap: () => setState(() {
                      _product = filtered[i];
                      _rateCtrl.text = filtered[i].purchasePrice.toString();
                    }),
                  ),
                ),
              ),
            ] else ...[
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(_product!.name,
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text('Current: ${_product!.stock} ${_product!.unit}'),
                trailing: TextButton(
                    onPressed: () => setState(() => _product = null),
                    child: const Text('Change')),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _qtyCtrl,
                      decoration:
                          InputDecoration(labelText: 'Qty (${_product!.unit})'),
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _rateCtrl,
                      decoration: const InputDecoration(
                          labelText: 'Rate ₹', prefixText: '₹ '),
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
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
                    widget.onAdd(PurchaseItem(
                      productId: _product!.id,
                      productName: _product!.name,
                      unit: _product!.unit,
                      quantity: qty,
                      rate: rate,
                    ));
                    Navigator.pop(context);
                  },
                  child: const Text('Add Item'),
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
