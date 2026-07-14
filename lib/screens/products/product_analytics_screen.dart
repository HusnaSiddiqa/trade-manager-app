import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../models/product.dart';
import '../../models/sale.dart';
import '../../providers/data_providers.dart';

final _fmt = NumberFormat('#,##,##0', 'en_IN');
final _fmtDec = NumberFormat('#,##,##0.0', 'en_IN');

class ProductAnalyticsScreen extends ConsumerWidget {
  const ProductAnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final productsAsync = ref.watch(productsProvider);
    final salesAsync = ref.watch(salesProvider);

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Product Analytics'),
          backgroundColor: const Color(0xFF1A237E),
          foregroundColor: Colors.white,
          bottom: const TabBar(
            indicatorColor: Color(0xFFD4A017),
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            tabs: [
              Tab(text: 'Slow Stock'),
              Tab(text: 'Best Sellers'),
              Tab(text: 'Margins'),
            ],
          ),
        ),
        body: productsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Error: $e')),
          data: (products) => salesAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Error: $e')),
            data: (sales) => _AnalyticsTabs(
                products: products, sales: sales),
          ),
        ),
      ),
    );
  }
}

class _AnalyticsTabs extends StatelessWidget {
  final List<Product> products;
  final List<Sale> sales;

  const _AnalyticsTabs({required this.products, required this.sales});

  @override
  Widget build(BuildContext context) {
    // Build per-product sale stats
    final cutoff30 =
        DateTime.now().subtract(const Duration(days: 30));
    final cutoff7 =
        DateTime.now().subtract(const Duration(days: 7));

    final Map<String, _ProductStats> stats = {};
    for (final p in products) {
      stats[p.name] = _ProductStats(product: p);
    }

    for (final sale in sales) {
      for (final item in sale.items) {
        stats.putIfAbsent(item.productName,
            () => _ProductStats(product: null, name: item.productName));
        final s = stats[item.productName]!;
        s.totalQty += item.quantity;
        s.totalRevenue += item.quantity * item.rate;
        s.orderCount++;
        if (sale.date.isAfter(cutoff30)) {
          s.qty30Days += item.quantity;
        }
        if (sale.date.isAfter(cutoff7)) {
          s.qty7Days += item.quantity;
        }
        if (s.lastSaleDate == null ||
            sale.date.isAfter(s.lastSaleDate!)) {
          s.lastSaleDate = sale.date;
        }
      }
    }

    // Slow movers: products with stock > 0 that haven't sold in 30 days
    final slowMovers = stats.values
        .where((s) =>
            s.product != null &&
            s.product!.stock > 0 &&
            (s.lastSaleDate == null || s.lastSaleDate!.isBefore(cutoff30)))
        .toList()
      ..sort((a, b) {
        if (a.lastSaleDate == null && b.lastSaleDate == null) return 0;
        if (a.lastSaleDate == null) return -1;
        if (b.lastSaleDate == null) return 1;
        return a.lastSaleDate!.compareTo(b.lastSaleDate!);
      });

    // Best sellers: sorted by quantity sold
    final bestSellers = stats.values
        .where((s) => s.totalQty > 0)
        .toList()
      ..sort((a, b) => b.totalQty.compareTo(a.totalQty));

    // Margin analysis: products with both purchase and selling price
    final marginItems = products
        .where((p) => p.purchasePrice > 0 && p.sellingPrice > 0)
        .toList()
      ..sort((a, b) => b.marginPercent.compareTo(a.marginPercent));

    return TabBarView(
      children: [
        _SlowStockTab(items: slowMovers),
        _BestSellersTab(items: bestSellers),
        _MarginsTab(products: marginItems, stats: stats),
      ],
    );
  }
}

// ─── Slow Stock Tab ──────────────────────────────────────────────────────────
class _SlowStockTab extends StatelessWidget {
  final List<_ProductStats> items;
  const _SlowStockTab({required this.items});

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.inventory_2_outlined,
                size: 60, color: Colors.green),
            SizedBox(height: 16),
            Text('All stocked products sold in last 30 days!',
                style: TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          color: Colors.orange[50],
          child: Row(
            children: [
              Icon(Icons.warning_amber_rounded,
                  color: Colors.orange[700], size: 18),
              const SizedBox(width: 8),
              Text(
                '${items.length} product${items.length == 1 ? '' : 's'} not sold in 30+ days',
                style: TextStyle(
                    color: Colors.orange[800],
                    fontWeight: FontWeight.w600,
                    fontSize: 13),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: items.length,
            itemBuilder: (_, i) {
              final s = items[i];
              final daysSince = s.lastSaleDate == null
                  ? null
                  : DateTime.now()
                      .difference(s.lastSaleDate!)
                      .inDays;
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                  side: BorderSide(color: Colors.orange[200]!),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Colors.orange.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.trending_down,
                            color: Colors.orange, size: 22),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(s.name,
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14)),
                            Text(
                                s.product != null
                                    ? '${s.product!.category} • Stock: ${_fmtDec.format(s.product!.stock)} ${s.product!.unit}'
                                    : '',
                                style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[600])),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: Colors.orange[100],
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              daysSince == null
                                  ? 'Never sold'
                                  : '$daysSince days ago',
                              style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.orange[800],
                                  fontWeight: FontWeight.bold),
                            ),
                          ),
                          if (s.totalQty > 0) ...[
                            const SizedBox(height: 2),
                            Text(
                              'Total sold: ${_fmtDec.format(s.totalQty)}',
                              style: const TextStyle(
                                  fontSize: 11, color: Colors.grey),
                            ),
                          ],
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
  }
}

// ─── Best Sellers Tab ────────────────────────────────────────────────────────
class _BestSellersTab extends StatelessWidget {
  final List<_ProductStats> items;
  const _BestSellersTab({required this.items});

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const Center(
          child: Text('No sales data yet', style: TextStyle(color: Colors.grey)));
    }

    final max = items.first.totalQty;

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: items.length,
      itemBuilder: (_, i) {
        final s = items[i];
        final pct = max > 0 ? s.totalQty / max : 0.0;
        final rank = i + 1;
        final rankColor = rank == 1
            ? Colors.amber[700]!
            : rank == 2
                ? Colors.grey[500]!
                : rank == 3
                    ? Colors.brown[400]!
                    : const Color(0xFF1A237E);

        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10)),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 14,
                      backgroundColor: rankColor,
                      child: Text(
                        '#$rank',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(s.name,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14)),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '${_fmtDec.format(s.totalQty)} units',
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF1A237E),
                              fontSize: 13),
                        ),
                        Text(
                          '₹${_fmt.format(s.totalRevenue)}',
                          style: TextStyle(
                              color: Colors.grey[600], fontSize: 11),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: pct,
                    backgroundColor: Colors.grey[200],
                    color: rankColor,
                    minHeight: 6,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${s.orderCount} orders',
                      style: const TextStyle(
                          fontSize: 11, color: Colors.grey),
                    ),
                    if (s.lastSaleDate != null)
                      Text(
                        'Last: ${DateFormat('dd MMM').format(s.lastSaleDate!)}',
                        style: const TextStyle(
                            fontSize: 11, color: Colors.grey),
                      ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ─── Margins Tab ─────────────────────────────────────────────────────────────
class _MarginsTab extends StatelessWidget {
  final List<Product> products;
  final Map<String, _ProductStats> stats;

  const _MarginsTab({required this.products, required this.stats});

  @override
  Widget build(BuildContext context) {
    if (products.isEmpty) {
      return const Center(
        child: Text(
          'Set purchase & selling prices\nfor products to see margins',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.grey),
        ),
      );
    }

    final totalRevenue = stats.values
        .fold(0.0, (s, p) => s + p.totalRevenue);

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: products.length + 1,
      itemBuilder: (_, i) {
        if (i == 0) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Card(
              color: const Color(0xFF1A237E),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _MarginStat(
                        label: 'Total Revenue',
                        value: '₹${_fmt.format(totalRevenue)}',
                        color: Colors.white),
                    _MarginStat(
                        label: 'Products',
                        value: '${products.length}',
                        color: Colors.white70),
                  ],
                ),
              ),
            ),
          );
        }

        final p = products[i - 1];
        final s = stats[p.name];
        final hasMargin = p.purchasePrice > 0;

        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10)),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(p.name,
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14)),
                          Text(p.category,
                              style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 12)),
                        ],
                      ),
                    ),
                    if (hasMargin)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: p.marginPercent > 10
                              ? Colors.green[50]
                              : Colors.orange[50],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                              color: p.marginPercent > 10
                                  ? Colors.green[200]!
                                  : Colors.orange[200]!),
                        ),
                        child: Text(
                          '${p.marginPercent.toStringAsFixed(1)}% margin',
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                              color: p.marginPercent > 10
                                  ? Colors.green[700]
                                  : Colors.orange[700]),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _PriceTag('Buy', p.purchasePrice, Colors.red[700]!),
                    const SizedBox(width: 8),
                    const Icon(Icons.arrow_forward,
                        size: 14, color: Colors.grey),
                    const SizedBox(width: 8),
                    _PriceTag('Sell', p.sellingPrice, Colors.green[700]!),
                    const SizedBox(width: 8),
                    if (hasMargin) ...[
                      const Icon(Icons.arrow_forward,
                          size: 14, color: Colors.grey),
                      const SizedBox(width: 8),
                      _PriceTag(
                          'Profit/unit', p.margin, Colors.blue[700]!),
                    ],
                    const Spacer(),
                    if (s != null && s.totalQty > 0)
                      Text(
                        '${_fmtDec.format(s.totalQty)} sold',
                        style: TextStyle(
                            color: Colors.grey[600], fontSize: 11),
                      ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _PriceTag extends StatelessWidget {
  final String label;
  final double value;
  final Color color;
  const _PriceTag(this.label, this.value, this.color);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(fontSize: 10, color: Colors.grey)),
        Text('₹${_fmt.format(value)}',
            style: TextStyle(
                fontSize: 12,
                color: color,
                fontWeight: FontWeight.w600)),
      ],
    );
  }
}

class _MarginStat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _MarginStat(
      {required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(label,
            style: TextStyle(color: color.withValues(alpha: 0.7), fontSize: 11)),
        const SizedBox(height: 4),
        Text(value,
            style: TextStyle(
                color: color,
                fontWeight: FontWeight.bold,
                fontSize: 16)),
      ],
    );
  }
}

// ─── Data model ─────────────────────────────────────────────────────────────
class _ProductStats {
  final Product? product;
  final String name;
  double totalQty = 0;
  double totalRevenue = 0;
  int orderCount = 0;
  double qty30Days = 0;
  double qty7Days = 0;
  DateTime? lastSaleDate;

  _ProductStats({this.product, String? name})
      : name = name ?? product?.name ?? '';
}
