import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/product.dart';
import '../../providers/data_providers.dart';

class AddProductScreen extends ConsumerStatefulWidget {
  final Product? product;
  const AddProductScreen({super.key, this.product});

  @override
  ConsumerState<AddProductScreen> createState() => _AddProductScreenState();
}

class _AddProductScreenState extends ConsumerState<AddProductScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _stock;
  late final TextEditingController _buyPrice;
  late final TextEditingController _sellPrice;
  late String _category;
  late String _unit;
  bool _saving = false;

  bool get _isEditing => widget.product != null;

  final _units = [
    'Bag', 'Kg', 'Ton', 'Piece', 'Feet', 'Meter', 'Bundle', 'Box', 'Litre',
    'Tatta', 'Tractor', 'Auto', '½ Auto', 'Old Due',
  ];

  @override
  void initState() {
    super.initState();
    final p = widget.product;
    _name = TextEditingController(text: p?.name ?? '');
    _stock = TextEditingController(text: p?.stock.toString() ?? '0');
    _buyPrice = TextEditingController(text: p?.purchasePrice.toString() ?? '');
    _sellPrice = TextEditingController(text: p?.sellingPrice.toString() ?? '');
    _category = p?.category ?? productCategories.first;
    _unit = p?.unit ?? _units.first;
  }

  @override
  void dispose() {
    _name.dispose();
    _stock.dispose();
    _buyPrice.dispose();
    _sellPrice.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final service = ref.read(firestoreServiceProvider);
    try {
      final product = Product(
        id: widget.product?.id ?? '',
        name: _name.text.trim(),
        category: _category,
        unit: _unit,
        stock: double.tryParse(_stock.text) ?? 0,
        purchasePrice: double.tryParse(_buyPrice.text) ?? 0,
        sellingPrice: double.tryParse(_sellPrice.text) ?? 0,
      );
      if (_isEditing) {
        await service.updateProduct(product);
      } else {
        await service.addProduct(product);
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Product' : 'Add Product'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _name,
              decoration: const InputDecoration(
                labelText: 'Product Name *',
                prefixIcon: Icon(Icons.inventory_2_outlined),
              ),
              textCapitalization: TextCapitalization.words,
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Name is required' : null,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: _category,
              decoration: const InputDecoration(
                labelText: 'Category *',
                prefixIcon: Icon(Icons.category_outlined),
              ),
              items: productCategories
                  .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                  .toList(),
              onChanged: (v) => setState(() => _category = v!),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: _unit,
              decoration: const InputDecoration(
                labelText: 'Unit *',
                prefixIcon: Icon(Icons.straighten_outlined),
              ),
              items: _units
                  .map((u) => DropdownMenuItem(value: u, child: Text(u)))
                  .toList(),
              onChanged: (v) => setState(() => _unit = v!),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _stock,
              decoration: const InputDecoration(
                labelText: 'Opening Stock',
                prefixIcon: Icon(Icons.warehouse_outlined),
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _buyPrice,
                    decoration: const InputDecoration(
                      labelText: 'Purchase Price *',
                      prefixIcon: Icon(Icons.arrow_downward),
                      prefixText: '₹ ',
                    ),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    validator: (v) =>
                        v == null || v.trim().isEmpty ? 'Required' : null,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _sellPrice,
                    decoration: const InputDecoration(
                      labelText: 'Selling Price *',
                      prefixIcon: Icon(Icons.arrow_upward),
                      prefixText: '₹ ',
                    ),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    validator: (v) =>
                        v == null || v.trim().isEmpty ? 'Required' : null,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Margin preview
            Builder(builder: (_) {
              final buy = double.tryParse(_buyPrice.text) ?? 0;
              final sell = double.tryParse(_sellPrice.text) ?? 0;
              if (buy > 0 && sell > 0) {
                final margin = sell - buy;
                final pct = (margin / buy * 100).toStringAsFixed(1);
                return Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    'Margin: ₹$margin per $_unit ($pct%)',
                    style: TextStyle(
                      color: margin >= 0 ? Colors.green[700] : Colors.red,
                      fontSize: 13,
                    ),
                  ),
                );
              }
              return const SizedBox.shrink();
            }),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : Text(_isEditing ? 'Update Product' : 'Save Product'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
