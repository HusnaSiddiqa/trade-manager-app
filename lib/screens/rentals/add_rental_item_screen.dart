import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/rental_item.dart';
import '../../providers/data_providers.dart';

class AddRentalItemScreen extends ConsumerStatefulWidget {
  final RentalItem? item;
  const AddRentalItemScreen({super.key, this.item});

  @override
  ConsumerState<AddRentalItemScreen> createState() => _AddRentalItemScreenState();
}

class _AddRentalItemScreenState extends ConsumerState<AddRentalItemScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _subCtrl;
  late final TextEditingController _qtyCtrl;
  late final TextEditingController _rentCtrl;
  String _category = '';
  bool _saving = false;

  bool get _isEditing => widget.item != null;

  @override
  void initState() {
    super.initState();
    final i = widget.item;
    _category = i?.category ?? '';
    _subCtrl = TextEditingController(text: i?.subCategory ?? '');
    _qtyCtrl = TextEditingController(text: i != null ? i.totalQuantity.toString() : '1');
    _rentCtrl = TextEditingController(
        text: (i == null || i.defaultRentPerDay == 0)
            ? ''
            : i.defaultRentPerDay.toStringAsFixed(0));
  }

  @override
  void dispose() {
    _subCtrl.dispose();
    _qtyCtrl.dispose();
    _rentCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final svc = ref.read(firestoreServiceProvider);
      final item = RentalItem(
        id: widget.item?.id ?? '',
        category: _category.trim(),
        subCategory: _subCtrl.text.trim(),
        totalQuantity: int.tryParse(_qtyCtrl.text) ?? 1,
        rentedOut: widget.item?.rentedOut ?? 0,
        defaultRentPerDay: double.tryParse(_rentCtrl.text) ?? 0,
      );
      if (_isEditing) {
        await svc.updateRentalItem(item);
      } else {
        await svc.addRentalItem(item);
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
    // Collect existing categories for autocomplete
    final existingCategories = ref.watch(rentalItemsProvider).maybeWhen(
          data: (items) => items.map((e) => e.category).toSet().toList(),
          orElse: () => <String>[],
        );

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Rental Item' : 'Add Rental Item'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Category
            Autocomplete<String>(
              initialValue: TextEditingValue(text: _category),
              optionsBuilder: (v) {
                if (v.text.isEmpty) return existingCategories;
                return existingCategories.where(
                    (c) => c.toLowerCase().contains(v.text.toLowerCase()));
              },
              onSelected: (v) => setState(() => _category = v),
              fieldViewBuilder: (ctx, autoCtrl, focusNode, onSubmit) {
                return TextFormField(
                  controller: autoCtrl,
                  focusNode: focusNode,
                  onChanged: (v) => _category = v,
                  decoration: const InputDecoration(
                    labelText: 'Category *',
                    hintText: 'e.g. Stand, Centering Plate',
                    prefixIcon: Icon(Icons.category_outlined),
                  ),
                  textCapitalization: TextCapitalization.words,
                  validator: (_) =>
                      _category.trim().isEmpty ? 'Category is required' : null,
                );
              },
            ),
            const SizedBox(height: 16),

            // Subcategory
            TextFormField(
              controller: _subCtrl,
              decoration: const InputDecoration(
                labelText: 'Sub-category (optional)',
                hintText: 'e.g. 5 feet, 7 feet, Heavy Duty',
                prefixIcon: Icon(Icons.subdirectory_arrow_right),
              ),
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: 8),
            Text(
              'Leave blank if this is the main item itself',
              style: TextStyle(fontSize: 12, color: Colors.grey[500]),
            ),
            const SizedBox(height: 16),

            // Total quantity
            TextFormField(
              controller: _qtyCtrl,
              decoration: const InputDecoration(
                labelText: 'Total Quantity Owned *',
                prefixIcon: Icon(Icons.inventory_2_outlined),
                helperText: 'How many you own in total',
              ),
              keyboardType: TextInputType.number,
              validator: (v) {
                final n = int.tryParse(v ?? '');
                if (n == null || n < 1) return 'Enter a valid quantity';
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Default rent per day
            TextFormField(
              controller: _rentCtrl,
              decoration: const InputDecoration(
                labelText: 'Default Rent / Day',
                prefixText: '₹ ',
                prefixIcon: Icon(Icons.currency_rupee),
                helperText: 'Pre-fills when creating a rental (editable)',
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
            ),
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
                label: Text(_isEditing ? 'Update Item' : 'Add Item'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
