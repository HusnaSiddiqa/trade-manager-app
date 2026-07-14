import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/firestore_service.dart';
import '../models/customer.dart';
import '../models/product.dart';
import '../models/sale.dart';
import '../models/purchase.dart';
import '../models/rental.dart';
import '../models/rental_item.dart';
import '../models/expense.dart';
import '../models/supplier_payment.dart';

final connectivityProvider = StreamProvider<bool>((ref) =>
    Connectivity().onConnectivityChanged.map(
        (results) => results.any((r) => r != ConnectivityResult.none)));

final firestoreServiceProvider =
    Provider<FirestoreService>((ref) => FirestoreService());

final customersProvider = StreamProvider<List<Customer>>((ref) =>
    ref.read(firestoreServiceProvider).customersStream());

final productsProvider = StreamProvider<List<Product>>((ref) =>
    ref.read(firestoreServiceProvider).productsStream());

final salesProvider = StreamProvider<List<Sale>>((ref) =>
    ref.read(firestoreServiceProvider).salesStream());

final purchasesProvider = StreamProvider<List<Purchase>>((ref) =>
    ref.read(firestoreServiceProvider).purchasesStream());

final suppliersProvider = StreamProvider<List<String>>((ref) =>
    ref.read(firestoreServiceProvider).suppliersStream());

final rentalsProvider = StreamProvider<List<Rental>>((ref) =>
    ref.read(firestoreServiceProvider).rentalsStream());

final rentalItemsProvider = StreamProvider<List<RentalItem>>((ref) =>
    ref.read(firestoreServiceProvider).rentalItemsStream());

final expensesProvider = StreamProvider<List<Expense>>((ref) =>
    ref.read(firestoreServiceProvider).expensesStream());

final todayStatsProvider = FutureProvider<Map<String, dynamic>>((ref) =>
    ref.read(firestoreServiceProvider).todayStats());

final shopSettingsProvider = FutureProvider<Map<String, dynamic>>((ref) =>
    ref.read(firestoreServiceProvider).getShopSettings());

final customerSalesProvider =
    StreamProvider.family<List<Sale>, String>((ref, customerId) =>
        ref.read(firestoreServiceProvider).salesByCustomerStream(customerId));

final allSupplierPaymentsProvider =
    StreamProvider<List<SupplierPayment>>((ref) =>
        ref.read(firestoreServiceProvider).allSupplierPaymentsStream());

final supplierPaymentsProvider =
    StreamProvider.family<List<SupplierPayment>, String>(
        (ref, supplierName) => ref
            .read(firestoreServiceProvider)
            .supplierPaymentsStream(supplierName));

final purchasesBySupplierProvider =
    StreamProvider.family<List<Purchase>, String>((ref, supplierName) =>
        ref
            .read(firestoreServiceProvider)
            .purchasesBySupplierStream(supplierName));

// 'today' | 'week' | 'month' | 'all'
final dashboardPeriodProvider = StateProvider<String>((ref) => 'today');

final periodStatsProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) {
  final period = ref.watch(dashboardPeriodProvider);
  final now = DateTime.now();
  DateTime? from;
  DateTime? to;
  switch (period) {
    case 'today':
      from = DateTime(now.year, now.month, now.day);
      to = from.add(const Duration(days: 1));
      break;
    case 'week':
      final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
      from = DateTime(startOfWeek.year, startOfWeek.month, startOfWeek.day);
      break;
    case 'month':
      from = DateTime(now.year, now.month, 1);
      break;
    case 'all':
    default:
      break;
  }
  return ref.read(firestoreServiceProvider).statsForPeriod(from: from, to: to);
});
