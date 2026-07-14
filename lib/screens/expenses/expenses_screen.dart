import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../models/expense.dart';
import '../../providers/data_providers.dart';
import 'add_expense_screen.dart';

final _fmt = NumberFormat('#,##,##0', 'en_IN');

class ExpensesScreen extends ConsumerWidget {
  const ExpensesScreen({super.key});

  void _confirmDelete(BuildContext context, WidgetRef ref, Expense expense) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Expense?'),
        content: Text(
            'Delete "${expense.category}" expense of ₹${_fmt.format(expense.amount)}?'),
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
                  .deleteExpense(expense.id);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Expense deleted')),
                );
              }
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final expensesAsync = ref.watch(expensesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Expenses'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline),
            onPressed: () => Navigator.push(
                context, MaterialPageRoute(builder: (_) => const AddExpenseScreen())),
          ),
        ],
      ),
      body: expensesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (expenses) {
          if (expenses.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.account_balance_wallet_outlined,
                      size: 72, color: Colors.grey[300]),
                  const SizedBox(height: 16),
                  Text('No expenses recorded',
                      style: TextStyle(color: Colors.grey[500])),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: () => Navigator.push(context,
                        MaterialPageRoute(builder: (_) => const AddExpenseScreen())),
                    icon: const Icon(Icons.add),
                    label: const Text('Add Expense'),
                  ),
                ],
              ),
            );
          }

          final total = expenses.fold(0.0, (s, e) => s + e.amount);

          // Group by category
          final byCategory = <String, double>{};
          for (final e in expenses) {
            byCategory[e.category] = (byCategory[e.category] ?? 0) + e.amount;
          }

          return Column(
            children: [
              // Summary bar
              Container(
                padding: const EdgeInsets.all(16),
                color: Colors.white,
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Total Expenses',
                              style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                          Text(
                            '₹${_fmt.format(total)}',
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Colors.red,
                            ),
                          ),
                        ],
                      ),
                    ),
                    ...byCategory.entries.take(3).map((e) => Padding(
                          padding: const EdgeInsets.only(left: 12),
                          child: Column(
                            children: [
                              Text(
                                '₹${_fmt.format(e.value)}',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                              ),
                              Text(e.key,
                                  style: TextStyle(fontSize: 10, color: Colors.grey[500])),
                            ],
                          ),
                        )),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: expenses.length,
                  itemBuilder: (_, i) {
                    final e = expenses[i];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 6),
                      child: ListTile(
                        leading: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.red.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.account_balance_wallet_outlined,
                              color: Colors.red, size: 20),
                        ),
                        title: Text(e.category,
                            style: const TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (e.description.isNotEmpty) Text(e.description),
                            Text(
                              DateFormat('dd MMM yyyy').format(e.date),
                              style: const TextStyle(fontSize: 11),
                            ),
                          ],
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '₹${_fmt.format(e.amount)}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.red,
                                fontSize: 15,
                              ),
                            ),
                            PopupMenuButton<String>(
                              icon: const Icon(Icons.more_vert, size: 18,
                                  color: Colors.grey),
                              onSelected: (v) {
                                if (v == 'edit') {
                                  Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                          builder: (_) =>
                                              AddExpenseScreen(expense: e)));
                                } else if (v == 'delete') {
                                  _confirmDelete(context, ref, e);
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
                                    Icon(Icons.delete_outline,
                                        color: Colors.red, size: 18),
                                    SizedBox(width: 8),
                                    Text('Delete',
                                        style: TextStyle(color: Colors.red)),
                                  ]),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.push(
            context, MaterialPageRoute(builder: (_) => const AddExpenseScreen())),
        child: const Icon(Icons.add),
      ),
    );
  }
}
