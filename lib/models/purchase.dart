import 'package:cloud_firestore/cloud_firestore.dart';

class PurchaseItem {
  final String productId;
  final String productName;
  final String unit;
  final double quantity;
  final double rate;

  const PurchaseItem({
    required this.productId,
    required this.productName,
    required this.unit,
    required this.quantity,
    required this.rate,
  });

  double get total => quantity * rate;

  Map<String, dynamic> toMap() => {
        'product_id': productId,
        'product_name': productName,
        'unit': unit,
        'quantity': quantity,
        'rate': rate,
      };

  factory PurchaseItem.fromMap(Map<String, dynamic> m) => PurchaseItem(
        productId: m['product_id'] ?? '',
        productName: m['product_name'] ?? '',
        unit: m['unit'] ?? '',
        quantity: (m['quantity'] ?? 0).toDouble(),
        rate: (m['rate'] ?? 0).toDouble(),
      );
}

class Purchase {
  final String id;
  final String supplierName;
  final String supplierMobile;
  final List<PurchaseItem> items;
  final double totalAmount;
  final String notes;
  final DateTime date;
  final String paymentMethod; // 'cash' | 'upi' | 'credit'

  const Purchase({
    required this.id,
    required this.supplierName,
    this.supplierMobile = '',
    required this.items,
    required this.totalAmount,
    this.notes = '',
    required this.date,
    this.paymentMethod = 'cash',
  });

  factory Purchase.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    final rawItems = (d['items'] as List<dynamic>? ?? []);
    return Purchase(
      id: doc.id,
      supplierName: d['supplier_name'] ?? '',
      supplierMobile: d['supplier_mobile'] ?? '',
      items: rawItems
          .map((e) => PurchaseItem.fromMap(e as Map<String, dynamic>))
          .toList(),
      totalAmount: (d['total_amount'] ?? 0).toDouble(),
      notes: d['notes'] ?? '',
      date: (d['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
      paymentMethod: d['payment_method'] ?? 'cash',
    );
  }

  Map<String, dynamic> toMap() => {
        'supplier_name': supplierName,
        'supplier_mobile': supplierMobile,
        'items': items.map((e) => e.toMap()).toList(),
        'total_amount': totalAmount,
        'notes': notes,
        'date': FieldValue.serverTimestamp(),
        'payment_method': paymentMethod,
      };
}
