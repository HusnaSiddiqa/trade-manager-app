import 'package:cloud_firestore/cloud_firestore.dart';

class Expense {
  final String id;
  final String category;
  final double amount;
  final String description;
  final DateTime date;

  const Expense({
    required this.id,
    required this.category,
    required this.amount,
    this.description = '',
    required this.date,
  });

  factory Expense.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return Expense(
      id: doc.id,
      category: d['category'] ?? '',
      amount: (d['amount'] ?? 0).toDouble(),
      description: d['description'] ?? '',
      date: (d['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() => {
        'category': category,
        'amount': amount,
        'description': description,
        'date': FieldValue.serverTimestamp(),
      };
}

const List<String> expenseCategories = [
  'Transport',
  'Labour',
  'Electricity',
  'Rent',
  'Staff Salary',
  'Maintenance',
  'Stationary',
  'Other',
];
