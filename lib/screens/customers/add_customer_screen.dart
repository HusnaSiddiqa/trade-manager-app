import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/customer.dart';
import '../../providers/data_providers.dart';

class AddCustomerScreen extends ConsumerStatefulWidget {
  final Customer? customer;
  const AddCustomerScreen({super.key, this.customer});

  @override
  ConsumerState<AddCustomerScreen> createState() => _AddCustomerScreenState();
}

class _AddCustomerScreenState extends ConsumerState<AddCustomerScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _mobile;
  late final TextEditingController _village;
  bool _saving = false;

  bool get _isEditing => widget.customer != null;

  @override
  void initState() {
    super.initState();
    final c = widget.customer;
    _name = TextEditingController(text: c?.name ?? '');
    _mobile = TextEditingController(text: c?.mobile ?? '');
    _village = TextEditingController(text: c?.village ?? '');
  }

  @override
  void dispose() {
    _name.dispose();
    _mobile.dispose();
    _village.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final service = ref.read(firestoreServiceProvider);
    try {
      if (_isEditing) {
        await service.updateCustomer(widget.customer!.copyWith(
          name: _name.text.trim(),
          mobile: _mobile.text.trim(),
          village: _village.text.trim(),
        ));
      } else {
        await service.addCustomer(Customer(
          id: '',
          name: _name.text.trim(),
          mobile: _mobile.text.trim(),
          village: _village.text.trim(),
          createdAt: DateTime.now(),
        ));
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
        title: Text(_isEditing ? 'Edit Customer' : 'Add Customer'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _name,
              decoration: const InputDecoration(
                labelText: 'Customer Name *',
                prefixIcon: Icon(Icons.person_outline),
              ),
              textCapitalization: TextCapitalization.words,
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Name is required' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _mobile,
              decoration: const InputDecoration(
                labelText: 'Mobile Number *',
                prefixIcon: Icon(Icons.phone_outlined),
              ),
              keyboardType: TextInputType.phone,
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Mobile is required';
                if (v.trim().length < 10) return 'Enter valid mobile number';
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _village,
              decoration: const InputDecoration(
                labelText: 'Village / Area',
                prefixIcon: Icon(Icons.location_on_outlined),
              ),
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(_isEditing ? 'Update Customer' : 'Save Customer'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
