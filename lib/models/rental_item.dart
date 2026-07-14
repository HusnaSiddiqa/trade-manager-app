import 'package:cloud_firestore/cloud_firestore.dart';

class RentalItem {
  final String id;
  final String category;
  final String subCategory;
  final int totalQuantity;
  final int rentedOut;
  final double defaultRentPerDay;
  final bool isActive;

  const RentalItem({
    required this.id,
    required this.category,
    this.subCategory = '',
    required this.totalQuantity,
    this.rentedOut = 0,
    this.defaultRentPerDay = 0,
    this.isActive = true,
  });

  String get displayName =>
      subCategory.isEmpty ? category : '$category - $subCategory';

  int get available => (totalQuantity - rentedOut).clamp(0, totalQuantity);

  factory RentalItem.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return RentalItem(
      id: doc.id,
      category: d['category'] ?? '',
      subCategory: d['sub_category'] ?? '',
      totalQuantity: (d['total_quantity'] ?? 0).toInt(),
      rentedOut: (d['rented_out'] ?? 0).toInt(),
      defaultRentPerDay: (d['default_rent_per_day'] ?? 0).toDouble(),
      isActive: d['is_active'] ?? true,
    );
  }

  Map<String, dynamic> toMap() => {
        'category': category,
        'sub_category': subCategory,
        'total_quantity': totalQuantity,
        'rented_out': rentedOut,
        'default_rent_per_day': defaultRentPerDay,
        'is_active': isActive,
      };
}
