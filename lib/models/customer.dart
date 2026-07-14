import 'package:cloud_firestore/cloud_firestore.dart';

class Customer {
  final String id;
  final String name;
  final String mobile;
  final String village;
  final double dueAmount;
  final DateTime createdAt;
  final String notes;

  const Customer({
    required this.id,
    required this.name,
    required this.mobile,
    this.village = '',
    this.dueAmount = 0.0,
    required this.createdAt,
    this.notes = '',
  });

  factory Customer.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return Customer(
      id: doc.id,
      name: d['name'] ?? '',
      mobile: d['mobile'] ?? '',
      village: d['village'] ?? '',
      dueAmount: (d['due_amount'] ?? 0).toDouble(),
      createdAt: (d['created_at'] as Timestamp?)?.toDate() ?? DateTime.now(),
      notes: d['notes'] ?? '',
    );
  }

  Map<String, dynamic> toMap() => {
        'name': name,
        'mobile': mobile,
        'village': village,
        'due_amount': dueAmount,
        'created_at': FieldValue.serverTimestamp(),
        'notes': notes,
      };

  Customer copyWith({String? name, String? mobile, String? village, double? dueAmount, String? notes}) =>
      Customer(
        id: id,
        name: name ?? this.name,
        mobile: mobile ?? this.mobile,
        village: village ?? this.village,
        dueAmount: dueAmount ?? this.dueAmount,
        createdAt: createdAt,
        notes: notes ?? this.notes,
      );
}
