import 'package:cloud_firestore/cloud_firestore.dart';

class SupplierPayment {
  final String id;
  final String supplierName;
  final String supplierMobile;
  final double amount;
  final DateTime date;
  final String notes;

  const SupplierPayment({
    required this.id,
    required this.supplierName,
    this.supplierMobile = '',
    required this.amount,
    required this.date,
    this.notes = '',
  });

  factory SupplierPayment.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return SupplierPayment(
      id: doc.id,
      supplierName: d['supplier_name'] ?? '',
      supplierMobile: d['supplier_mobile'] ?? '',
      amount: (d['amount'] ?? 0).toDouble(),
      date: (d['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
      notes: d['notes'] ?? '',
    );
  }

  Map<String, dynamic> toMap() => {
        'supplier_name': supplierName,
        'supplier_mobile': supplierMobile,
        'amount': amount,
        'date': Timestamp.fromDate(date),
        'notes': notes,
      };
}
