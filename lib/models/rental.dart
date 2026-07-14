import 'package:cloud_firestore/cloud_firestore.dart';

class RentalEntry {
  final String itemName;
  final String rentalItemId;
  final int quantity;
  final double rentPerDay;

  const RentalEntry({
    required this.itemName,
    required this.rentalItemId,
    required this.quantity,
    required this.rentPerDay,
  });

  factory RentalEntry.fromMap(Map<String, dynamic> m) => RentalEntry(
        itemName: m['item_name'] ?? '',
        rentalItemId: m['rental_item_id'] ?? '',
        quantity: (m['quantity'] ?? 1).toInt(),
        rentPerDay: (m['rent_per_day'] ?? 0).toDouble(),
      );

  Map<String, dynamic> toMap() => {
        'item_name': itemName,
        'rental_item_id': rentalItemId,
        'quantity': quantity,
        'rent_per_day': rentPerDay,
      };
}

class Rental {
  final String id;
  final String customerId;
  final String customerName;
  final String customerMobile;
  final List<RentalEntry> entries; // multi-item (empty for old records)

  // Legacy single-item fields (backward compat with old documents)
  final String itemName;
  final String rentalItemId;
  final double quantity;
  final double rentPerDay;

  final DateTime issueDate;
  final DateTime? returnDate;
  final String status; // 'active' | 'returned'
  final double totalRent;
  final String returnPaymentMethod;

  const Rental({
    required this.id,
    required this.customerId,
    required this.customerName,
    required this.customerMobile,
    this.entries = const [],
    this.itemName = '',
    this.rentalItemId = '',
    this.quantity = 1,
    this.rentPerDay = 0,
    required this.issueDate,
    this.returnDate,
    required this.status,
    this.totalRent = 0,
    this.returnPaymentMethod = '',
  });

  int get daysOut {
    final end = returnDate ?? DateTime.now();
    return end.difference(issueDate).inDays.clamp(1, 9999);
  }

  double get calculatedRent {
    if (entries.isNotEmpty) {
      return entries.fold(
          0.0, (sum, e) => sum + daysOut * e.quantity * e.rentPerDay);
    }
    return daysOut * quantity * rentPerDay;
  }

  String get itemsSummary {
    if (entries.isNotEmpty) {
      return entries.map((e) => '${e.quantity}× ${e.itemName}').join(', ');
    }
    return '${quantity.toStringAsFixed(0)} × $itemName';
  }

  factory Rental.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    final rawEntries = d['entries'] as List<dynamic>? ?? [];
    return Rental(
      id: doc.id,
      customerId: d['customer_id'] ?? '',
      customerName: d['customer_name'] ?? '',
      customerMobile: d['customer_mobile'] ?? '',
      entries: rawEntries
          .map((e) => RentalEntry.fromMap(e as Map<String, dynamic>))
          .toList(),
      itemName: d['item_name'] ?? '',
      rentalItemId: d['rental_item_id'] ?? '',
      quantity: (d['quantity'] ?? 1).toDouble(),
      rentPerDay: (d['rent_per_day'] ?? 0).toDouble(),
      issueDate:
          (d['issue_date'] as Timestamp?)?.toDate() ?? DateTime.now(),
      returnDate: (d['return_date'] as Timestamp?)?.toDate(),
      status: d['status'] ?? 'active',
      totalRent: (d['total_rent'] ?? 0).toDouble(),
      returnPaymentMethod: d['return_payment_method'] ?? '',
    );
  }

  Map<String, dynamic> toMap() => {
        'customer_id': customerId,
        'customer_name': customerName,
        'customer_mobile': customerMobile,
        'entries': entries.map((e) => e.toMap()).toList(),
        'item_name': itemName,
        'rental_item_id': rentalItemId,
        'quantity': quantity,
        'rent_per_day': rentPerDay,
        'issue_date': Timestamp.fromDate(issueDate),
        'return_date': returnDate != null ? Timestamp.fromDate(returnDate!) : null,
        'status': status,
        'total_rent': totalRent,
        'return_payment_method': returnPaymentMethod,
      };
}
