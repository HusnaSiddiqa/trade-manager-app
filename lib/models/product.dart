import 'package:cloud_firestore/cloud_firestore.dart';

class Product {
  final String id;
  final String name;
  final String category;
  final String unit;
  final double stock;
  final double purchasePrice;
  final double sellingPrice;

  const Product({
    required this.id,
    required this.name,
    required this.category,
    required this.unit,
    this.stock = 0.0,
    required this.purchasePrice,
    required this.sellingPrice,
  });

  factory Product.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return Product(
      id: doc.id,
      name: d['name'] ?? '',
      category: d['category'] ?? '',
      unit: d['unit'] ?? '',
      stock: (d['stock'] ?? 0).toDouble(),
      purchasePrice: (d['purchase_price'] ?? 0).toDouble(),
      sellingPrice: (d['selling_price'] ?? 0).toDouble(),
    );
  }

  Map<String, dynamic> toMap() => {
        'name': name,
        'category': category,
        'unit': unit,
        'stock': stock,
        'purchase_price': purchasePrice,
        'selling_price': sellingPrice,
      };

  double get margin => sellingPrice - purchasePrice;
  double get marginPercent =>
      purchasePrice > 0 ? (margin / purchasePrice) * 100 : 0;
}

const List<String> productCategories = [
  'Cement',
  'Steel',
  'Bricks',
  'Sand',
  'Gravel',
  'Paint',
  'Pipes',
  'Tiles',
  'Wood',
  'Hardware',
  'Other',
];
