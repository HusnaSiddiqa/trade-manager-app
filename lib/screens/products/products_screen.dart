import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme.dart';
import '../../providers/data_providers.dart';
import '../../models/product.dart';
import 'add_product_screen.dart';
import 'product_analytics_screen.dart';

class ProductsScreen extends ConsumerStatefulWidget {
  const ProductsScreen({super.key});

  @override
  ConsumerState<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends ConsumerState<ProductsScreen> {
  String _search = '';
  String _filterCategory = 'All';

  @override
  Widget build(BuildContext context) {
    final productsAsync = ref.watch(productsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Products / Stock'),
        actions: [
          IconButton(
            icon: const Icon(Icons.bar_chart_outlined),
            tooltip: 'Analytics',
            onPressed: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const ProductAnalyticsScreen())),
          ),
          IconButton(
            icon: const Icon(Icons.add_box_outlined),
            onPressed: () => Navigator.push(
                context, MaterialPageRoute(builder: (_) => const AddProductScreen())),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
            child: TextField(
              onChanged: (v) => setState(() => _search = v.toLowerCase()),
              decoration: const InputDecoration(
                hintText: 'Search products...',
                prefixIcon: Icon(Icons.search),
                contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            ),
          ),
          // Category filter chips
          productsAsync.when(
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
            data: (products) {
              final categories = ['All', ...{...products.map((p) => p.category)}];
              return SizedBox(
                height: 48,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  itemCount: categories.length,
                  itemBuilder: (_, i) => Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      label: Text(categories[i]),
                      selected: _filterCategory == categories[i],
                      onSelected: (_) =>
                          setState(() => _filterCategory = categories[i]),
                      selectedColor: AppTheme.primary.withValues(alpha: 0.2),
                      checkmarkColor: AppTheme.primary,
                    ),
                  ),
                ),
              );
            },
          ),
          Expanded(
            child: productsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
              data: (products) {
                var filtered = products.where((p) {
                  final matchSearch = _search.isEmpty ||
                      p.name.toLowerCase().contains(_search) ||
                      p.category.toLowerCase().contains(_search);
                  final matchCategory =
                      _filterCategory == 'All' || p.category == _filterCategory;
                  return matchSearch && matchCategory;
                }).toList();

                if (filtered.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.inventory_2_outlined, size: 64, color: Colors.grey[300]),
                        const SizedBox(height: 16),
                        Text(
                          _search.isEmpty ? 'No products yet' : 'No results found',
                          style: TextStyle(color: Colors.grey[500]),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.all(12),
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 4),
                  itemBuilder: (_, i) => _ProductTile(
                    product: filtered[i],
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => AddProductScreen(product: filtered[i]),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.push(
            context, MaterialPageRoute(builder: (_) => const AddProductScreen())),
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _ProductTile extends StatelessWidget {
  final Product product;
  final VoidCallback onTap;

  const _ProductTile({required this.product, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isLowStock = product.stock < 10;
    return Card(
      child: ListTile(
        onTap: onTap,
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppTheme.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(Icons.inventory_2_outlined, color: AppTheme.primary, size: 20),
        ),
        title: Text(
          product.name,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          '${product.category} • Sell: ₹${product.sellingPrice}/${product.unit}',
          style: const TextStyle(fontSize: 12),
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '${product.stock} ${product.unit}',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: isLowStock ? Colors.red[700] : Colors.grey[700],
              ),
            ),
            if (isLowStock)
              Text(
                'Low Stock',
                style: TextStyle(fontSize: 10, color: Colors.red[600]),
              ),
          ],
        ),
      ),
    );
  }
}
