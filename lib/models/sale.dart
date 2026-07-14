import 'package:cloud_firestore/cloud_firestore.dart';
import 'sale_item.dart';

class Sale {
  final String id;
  final String customerId;
  final String customerName;
  final String customerMobile;
  final String customerVillage;
  final List<SaleItem> items;
  final double transportCharge;
  final double totalAmount;
  final double paidAmount;
  final double profit;
  final String paymentMethod;
  final DateTime date;

  const Sale({
    required this.id,
    required this.customerId,
    required this.customerName,
    this.customerMobile = '',
    this.customerVillage = '',
    required this.items,
    this.transportCharge = 0,
    required this.totalAmount,
    required this.paidAmount,
    required this.profit,
    required this.paymentMethod,
    required this.date,
  });

  double get dueAmount => totalAmount - paidAmount;

  factory Sale.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    final rawItems = (d['items'] as List<dynamic>? ?? []);
    return Sale(
      id: doc.id,
      customerId: d['customer_id'] ?? '',
      customerName: d['customer_name'] ?? '',
      customerMobile: d['customer_mobile'] ?? '',
      customerVillage: d['customer_village'] ?? '',
      items: rawItems.map((e) => SaleItem.fromMap(e as Map<String, dynamic>)).toList(),
      transportCharge: (d['transport_charge'] ?? 0).toDouble(),
      totalAmount: (d['total_amount'] ?? 0).toDouble(),
      paidAmount: (d['paid_amount'] ?? 0).toDouble(),
      profit: (d['profit'] ?? 0).toDouble(),
      paymentMethod: d['payment_method'] ?? 'cash',
      date: (d['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() => {
        'customer_id': customerId,
        'customer_name': customerName,
        'customer_mobile': customerMobile,
        'customer_village': customerVillage,
        'items': items.map((e) => e.toMap()).toList(),
        'transport_charge': transportCharge,
        'total_amount': totalAmount,
        'paid_amount': paidAmount,
        'profit': profit,
        'payment_method': paymentMethod,
        'date': FieldValue.serverTimestamp(),
      };
}
