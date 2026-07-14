class SaleItem {
  final String productId;
  final String productName;
  final String unit;
  final double quantity;
  final double rate;
  final double purchaseRate;

  const SaleItem({
    required this.productId,
    required this.productName,
    required this.unit,
    required this.quantity,
    required this.rate,
    required this.purchaseRate,
  });

  double get total => quantity * rate;
  double get cost => quantity * purchaseRate;
  double get profit => total - cost;

  Map<String, dynamic> toMap() => {
        'product_id': productId,
        'product_name': productName,
        'unit': unit,
        'quantity': quantity,
        'rate': rate,
        'purchase_rate': purchaseRate,
      };

  factory SaleItem.fromMap(Map<String, dynamic> m) => SaleItem(
        productId: m['product_id'] ?? '',
        productName: m['product_name'] ?? '',
        unit: m['unit'] ?? '',
        quantity: (m['quantity'] ?? 0).toDouble(),
        rate: (m['rate'] ?? 0).toDouble(),
        purchaseRate: (m['purchase_rate'] ?? 0).toDouble(),
      );
}
