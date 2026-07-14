import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/theme.dart';
import '../../models/expense.dart';
import '../../providers/data_providers.dart';

class AddExpenseScreen extends ConsumerStatefulWidget {
  final Expense? expense;
  const AddExpenseScreen({super.key, this.expense});

  @override
  ConsumerState<AddExpenseScreen> createState() => _AddExpenseScreenState();
}

class _AddExpenseScreenState extends ConsumerState<AddExpenseScreen> {
  late final TextEditingController _amountCtrl;
  late final TextEditingController _descCtrl;
  late String _category;
  late DateTime _date;
  bool _saving = false;

  bool get _isEditing => widget.expense != null;

  @override
  void initState() {
    super.initState();
    final e = widget.expense;
    _amountCtrl = TextEditingController(
        text: e != null ? e.amount.toStringAsFixed(0) : '');
    _descCtrl = TextEditingController(text: e?.description ?? '');
    _category = e?.category ?? expenseCategories.first;
    _date = e?.date ?? DateTime.now();
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _save() async {
    final amount = double.tryParse(_amountCtrl.text) ?? 0;
    if (amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid amount'), backgroundColor: Colors.red),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      final service = ref.read(firestoreServiceProvider);
      if (_isEditing) {
        await service.updateExpense(Expense(
          id: widget.expense!.id,
          category: _category,
          amount: amount,
          description: _descCtrl.text.trim(),
          date: _date,
        ));
      } else {
        await service.addExpense(Expense(
          id: '',
          category: _category,
          amount: amount,
          description: _descCtrl.text.trim(),
          date: _date,
        ));
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(_isEditing ? 'Expense updated!' : 'Expense saved!'),
              backgroundColor: AppTheme.success),
        );
        Navigator.pop(context);
      }
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
      appBar: AppBar(title: Text(_isEditing ? 'Edit Expense' : 'Add Expense')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          DropdownButtonFormField<String>(
            initialValue: _category,
            decoration: const InputDecoration(
              labelText: 'Category *',
              prefixIcon: Icon(Icons.category_outlined),
            ),
            items: expenseCategories
                .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                .toList(),
            onChanged: (v) => setState(() => _category = v!),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _amountCtrl,
            decoration: const InputDecoration(
              labelText: 'Amount *',
              prefixText: '₹ ',
              prefixIcon: Icon(Icons.currency_rupee),
            ),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            autofocus: true,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _descCtrl,
            decoration: const InputDecoration(
              labelText: 'Description (optional)',
              prefixIcon: Icon(Icons.notes_outlined),
            ),
            textCapitalization: TextCapitalization.sentences,
          ),
          const SizedBox(height: 16),
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
                  const Icon(Icons.calendar_today_outlined, color: Colors.grey),
                  const SizedBox(width: 12),
                  Text('Date: ${DateFormat('dd MMM yyyy').format(_date)}'),
                  const Spacer(),
                  Text('Change',
                      style: TextStyle(color: AppTheme.primary, fontSize: 13)),
                ],
              ),
            ),
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
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.save_outlined),
              label: Text(_isEditing ? 'Update Expense' : 'Save Expense'),
            ),
          ),
        ],
      ),
    );
  }
}
