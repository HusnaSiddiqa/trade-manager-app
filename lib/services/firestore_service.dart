import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/customer.dart';
import '../models/product.dart';
import '../models/sale.dart';
import '../models/purchase.dart';
import '../models/rental.dart';
import '../models/rental_item.dart';
import '../models/expense.dart';
import '../models/supplier_payment.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  String get _uid => FirebaseAuth.instance.currentUser!.uid;

  CollectionReference<Map<String, dynamic>> _col(String name) =>
      _db.collection('users').doc(_uid).collection(name);

  // ─── Customers ────────────────────────────────────────────
  Stream<List<Customer>> customersStream() => _col('customers')
      .orderBy('name')
      .snapshots()
      .map((s) => s.docs.map(Customer.fromFirestore).toList());

  Future<void> addCustomer(Customer c) => _col('customers').add(c.toMap());

  Future<DocumentReference<Map<String, dynamic>>> addCustomerAndReturn(Customer c) =>
      _col('customers').add(c.toMap());

  Future<void> updateCustomer(Customer c) =>
      _col('customers').doc(c.id).update(c.toMap());

  Future<void> updateCustomerDue(String id, double delta) =>
      _col('customers').doc(id).update({
        'due_amount': FieldValue.increment(delta),
      });

  Future<void> deleteCustomer(String id) =>
      _col('customers').doc(id).delete();

  // ─── Products ─────────────────────────────────────────────
  Stream<List<Product>> productsStream() => _col('products')
      .orderBy('name')
      .snapshots()
      .map((s) => s.docs.map(Product.fromFirestore).toList());

  Future<void> addProduct(Product p) => _col('products').add(p.toMap());

  Future<void> updateProduct(Product p) =>
      _col('products').doc(p.id).update(p.toMap());

  Future<void> adjustStock(String productId, double delta) =>
      _col('products').doc(productId).update({
        'stock': FieldValue.increment(delta),
      });

  // ─── Sales ────────────────────────────────────────────────
  Stream<List<Sale>> salesStream() => _col('sales')
      .orderBy('date', descending: true)
      .limit(100)
      .snapshots()
      .map((s) => s.docs.map(Sale.fromFirestore).toList());

  Future<void> addSale(Sale sale) async {
    final batch = _db.batch();
    final saleRef = _col('sales').doc();
    batch.set(saleRef, sale.toMap());
    for (final item in sale.items) {
      if (item.productId.isNotEmpty && item.productId != '__prev_balance__') {
        batch.update(_col('products').doc(item.productId),
            {'stock': FieldValue.increment(-item.quantity)});
      }
    }
    if (sale.dueAmount > 0 && sale.customerId.isNotEmpty) {
      final customerRef = _col('customers').doc(sale.customerId);
      batch.update(customerRef, {'due_amount': FieldValue.increment(sale.dueAmount)});
    }
    await batch.commit();
  }

  Future<void> deleteSale(Sale sale) async {
    final batch = _db.batch();
    // Reverse stock for all items
    for (final item in sale.items) {
      if (item.productId.isNotEmpty && item.productId != '__prev_balance__') {
        batch.update(_col('products').doc(item.productId),
            {'stock': FieldValue.increment(item.quantity)});
      }
    }
    // Reverse customer due if there was outstanding due
    if (sale.dueAmount > 0 && sale.customerId.isNotEmpty) {
      final customerRef = _col('customers').doc(sale.customerId);
      batch.update(customerRef, {'due_amount': FieldValue.increment(-sale.dueAmount)});
    }
    batch.delete(_col('sales').doc(sale.id));
    await batch.commit();
  }

  Future<void> updateSale(Sale oldSale, Sale newSale) async {
    final batch = _db.batch();

    // Restore old stock
    for (final item in oldSale.items) {
      if (item.productId.isNotEmpty && item.productId != '__prev_balance__') {
        batch.update(_col('products').doc(item.productId), {
          'stock': FieldValue.increment(item.quantity),
        });
      }
    }
    // Deduct new stock
    for (final item in newSale.items) {
      if (item.productId.isNotEmpty && item.productId != '__prev_balance__') {
        batch.update(_col('products').doc(item.productId), {
          'stock': FieldValue.increment(-item.quantity),
        });
      }
    }
    // Adjust customer due delta
    final dueDelta = newSale.dueAmount - oldSale.dueAmount;
    if (dueDelta.abs() > 0.01 && oldSale.customerId.isNotEmpty) {
      batch.update(_col('customers').doc(oldSale.customerId), {
        'due_amount': FieldValue.increment(dueDelta),
      });
    }
    // Update sale doc — date is now editable
    batch.update(_col('sales').doc(oldSale.id), {
      'items': newSale.items.map((e) => e.toMap()).toList(),
      'transport_charge': newSale.transportCharge,
      'total_amount': newSale.totalAmount,
      'paid_amount': newSale.paidAmount,
      'profit': newSale.profit,
      'payment_method': newSale.paymentMethod,
      'date': Timestamp.fromDate(newSale.date),
    });

    await batch.commit();
  }

  // ─── Purchases ────────────────────────────────────────────
  Stream<List<Purchase>> purchasesStream() => _col('purchases')
      .orderBy('date', descending: true)
      .limit(100)
      .snapshots()
      .map((s) => s.docs.map(Purchase.fromFirestore).toList());

  Future<void> addPurchase(Purchase purchase) async {
    final batch = _db.batch();
    final ref = _col('purchases').doc();
    batch.set(ref, purchase.toMap());
    for (final item in purchase.items) {
      final productRef = _col('products').doc(item.productId);
      batch.update(productRef, {'stock': FieldValue.increment(item.quantity)});
    }
    await batch.commit();
  }

  Future<void> updatePurchase(Purchase oldPurchase, Purchase newPurchase) async {
    final batch = _db.batch();
    // Calculate net stock delta per product
    final Map<String, double> deltas = {};
    for (final item in oldPurchase.items) {
      deltas[item.productId] = (deltas[item.productId] ?? 0) - item.quantity;
    }
    for (final item in newPurchase.items) {
      deltas[item.productId] = (deltas[item.productId] ?? 0) + item.quantity;
    }
    for (final entry in deltas.entries) {
      if (entry.value != 0) {
        batch.update(_col('products').doc(entry.key),
            {'stock': FieldValue.increment(entry.value)});
      }
    }
    // Update purchase doc (preserve original date)
    final data = newPurchase.toMap();
    data.remove('date'); // keep original date
    batch.update(_col('purchases').doc(oldPurchase.id), data);
    await batch.commit();
  }

  Future<void> deletePurchase(Purchase purchase) async {
    final batch = _db.batch();
    for (final item in purchase.items) {
      batch.update(_col('products').doc(item.productId),
          {'stock': FieldValue.increment(-item.quantity)});
    }
    batch.delete(_col('purchases').doc(purchase.id));
    await batch.commit();
  }

  Stream<List<String>> suppliersStream() => _col('purchases')
      .orderBy('supplier_name')
      .snapshots()
      .map((s) => s.docs
          .map((d) => (d.data()['supplier_name'] as String?) ?? '')
          .where((n) => n.isNotEmpty)
          .toSet()
          .toList());


  // ─── Rentals ──────────────────────────────────────────────
  Stream<List<Rental>> rentalsStream() => _col('rentals')
      .orderBy('issue_date', descending: true)
      .snapshots()
      .map((s) => s.docs.map(Rental.fromFirestore).toList());

  Future<void> addRental(Rental rental) async {
    final batch = _db.batch();
    final rentalRef = _col('rentals').doc();
    batch.set(rentalRef, rental.toMap());
    if (rental.entries.isNotEmpty) {
      for (final entry in rental.entries) {
        if (entry.rentalItemId.isNotEmpty) {
          batch.update(_col('rental_items').doc(entry.rentalItemId), {
            'rented_out': FieldValue.increment(entry.quantity),
          });
        }
      }
    } else if (rental.rentalItemId.isNotEmpty) {
      batch.update(_col('rental_items').doc(rental.rentalItemId), {
        'rented_out': FieldValue.increment(rental.quantity.toInt()),
      });
    }
    await batch.commit();
  }

  Future<void> returnRental(
    String rentalId,
    double totalRent,
    String paymentMethod, {
    List<RentalEntry> entries = const [],
    String rentalItemId = '',
    int rentedQuantity = 0,
  }) async {
    final batch = _db.batch();
    batch.update(_col('rentals').doc(rentalId), {
      'status': 'returned',
      'return_date': FieldValue.serverTimestamp(),
      'total_rent': totalRent,
      'return_payment_method': paymentMethod,
    });
    if (entries.isNotEmpty) {
      for (final entry in entries) {
        if (entry.rentalItemId.isNotEmpty && entry.quantity > 0) {
          batch.update(_col('rental_items').doc(entry.rentalItemId), {
            'rented_out': FieldValue.increment(-entry.quantity),
          });
        }
      }
    } else if (rentalItemId.isNotEmpty && rentedQuantity > 0) {
      batch.update(_col('rental_items').doc(rentalItemId), {
        'rented_out': FieldValue.increment(-rentedQuantity),
      });
    }
    await batch.commit();
  }

  // ─── Rental Items catalog ─────────────────────────────────
  Stream<List<RentalItem>> rentalItemsStream() => _col('rental_items')
      .orderBy('category')
      .snapshots()
      .map((s) => s.docs.map(RentalItem.fromFirestore).toList());

  Future<void> addRentalItem(RentalItem item) =>
      _col('rental_items').add(item.toMap());

  Future<void> updateRentalItem(RentalItem item) =>
      _col('rental_items').doc(item.id).update(item.toMap());

  Future<void> deleteRentalItem(String id) =>
      _col('rental_items').doc(id).delete();

  Future<void> deleteRental(Rental rental) async {
    final batch = _db.batch();
    // Restore stock only if still active (returned rentals already restored)
    if (rental.status == 'active') {
      if (rental.entries.isNotEmpty) {
        for (final entry in rental.entries) {
          if (entry.rentalItemId.isNotEmpty && entry.quantity > 0) {
            batch.update(_col('rental_items').doc(entry.rentalItemId), {
              'rented_out': FieldValue.increment(-entry.quantity),
            });
          }
        }
      } else if (rental.rentalItemId.isNotEmpty) {
        batch.update(_col('rental_items').doc(rental.rentalItemId), {
          'rented_out': FieldValue.increment(-rental.quantity.toInt()),
        });
      }
    }
    batch.delete(_col('rentals').doc(rental.id));
    await batch.commit();
  }

  Future<void> updateRental(Rental oldRental, Rental newRental) async {
    final batch = _db.batch();
    // Adjust rented_out only for active rentals
    if (oldRental.status == 'active') {
      // Restore old rented_out counts
      if (oldRental.entries.isNotEmpty) {
        for (final entry in oldRental.entries) {
          if (entry.rentalItemId.isNotEmpty && entry.quantity > 0) {
            batch.update(_col('rental_items').doc(entry.rentalItemId), {
              'rented_out': FieldValue.increment(-entry.quantity),
            });
          }
        }
      } else if (oldRental.rentalItemId.isNotEmpty) {
        batch.update(_col('rental_items').doc(oldRental.rentalItemId), {
          'rented_out': FieldValue.increment(-oldRental.quantity.toInt()),
        });
      }
      // Apply new rented_out counts
      for (final entry in newRental.entries) {
        if (entry.rentalItemId.isNotEmpty && entry.quantity > 0) {
          batch.update(_col('rental_items').doc(entry.rentalItemId), {
            'rented_out': FieldValue.increment(entry.quantity),
          });
        }
      }
    }
    // Update rental doc — preserve status, total_rent, payment method
    batch.update(_col('rentals').doc(oldRental.id), {
      'customer_name': newRental.customerName,
      'customer_mobile': newRental.customerMobile,
      'entries': newRental.entries.map((e) => e.toMap()).toList(),
      'issue_date': Timestamp.fromDate(newRental.issueDate),
      if (newRental.returnDate != null)
        'return_date': Timestamp.fromDate(newRental.returnDate!),
    });
    await batch.commit();
  }

  // ─── Expenses ─────────────────────────────────────────────
  Stream<List<Expense>> expensesStream() => _col('expenses')
      .orderBy('date', descending: true)
      .limit(100)
      .snapshots()
      .map((s) => s.docs.map(Expense.fromFirestore).toList());

  Future<void> addExpense(Expense expense) =>
      _col('expenses').add(expense.toMap());

  Future<void> updateExpense(Expense expense) =>
      _col('expenses').doc(expense.id).update({
        'category': expense.category,
        'amount': expense.amount,
        'description': expense.description,
      });

  Future<void> deleteExpense(String id) =>
      _col('expenses').doc(id).delete();

  // ─── Customer-specific sales (sorted in-memory, no composite index needed) ───
  Stream<List<Sale>> salesByCustomerStream(String customerId) =>
      _col('sales')
          .where('customer_id', isEqualTo: customerId)
          .snapshots()
          .map((s) {
        final list = s.docs.map(Sale.fromFirestore).toList()
          ..sort((a, b) => b.date.compareTo(a.date));
        return list;
      });

  // ─── Payment collection ───────────────────────────────────
  Future<void> recordPayment(String saleId, String customerId, double amount) async {
    final batch = _db.batch();
    batch.update(_col('sales').doc(saleId), {
      'paid_amount': FieldValue.increment(amount),
    });
    if (customerId.isNotEmpty) {
      batch.update(_col('customers').doc(customerId), {
        'due_amount': FieldValue.increment(-amount),
      });
    }
    await batch.commit();
  }

  Future<void> editPayment(
      String saleId, String customerId, double oldPaid, double newPaid) async {
    final diff = newPaid - oldPaid;
    final batch = _db.batch();
    batch.update(_col('sales').doc(saleId), {'paid_amount': newPaid});
    if (customerId.isNotEmpty) {
      batch.update(_col('customers').doc(customerId), {
        'due_amount': FieldValue.increment(-diff),
      });
    }
    await batch.commit();
  }

  // ─── Supplier payments ────────────────────────────────────
  Stream<List<SupplierPayment>> allSupplierPaymentsStream() =>
      _col('supplier_payments')
          .snapshots()
          .map((s) {
        final list = s.docs.map(SupplierPayment.fromFirestore).toList()
          ..sort((a, b) => b.date.compareTo(a.date));
        return list;
      });

  Stream<List<SupplierPayment>> supplierPaymentsStream(String supplierName) =>
      _col('supplier_payments')
          .where('supplier_name', isEqualTo: supplierName)
          .snapshots()
          .map((s) {
        final list = s.docs.map(SupplierPayment.fromFirestore).toList()
          ..sort((a, b) => b.date.compareTo(a.date));
        return list;
      });

  Stream<List<Purchase>> purchasesBySupplierStream(String supplierName) =>
      _col('purchases')
          .where('supplier_name', isEqualTo: supplierName)
          .snapshots()
          .map((s) {
        final list = s.docs.map(Purchase.fromFirestore).toList()
          ..sort((a, b) => b.date.compareTo(a.date));
        return list;
      });

  Future<void> addSupplierPayment(SupplierPayment payment) =>
      _col('supplier_payments').add(payment.toMap());

  // ─── Daily cash stats ─────────────────────────────────────
  Future<Map<String, dynamic>> dailyCashStats(DateTime date) async {
    final start = DateTime(date.year, date.month, date.day);
    final end = start.add(const Duration(days: 1));

    final salesSnap = await _col('sales')
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('date', isLessThan: Timestamp.fromDate(end))
        .get();

    double cashSales = 0, upiSales = 0, creditGiven = 0;
    int creditCount = 0;
    for (final doc in salesSnap.docs) {
      final d = doc.data();
      final amt = (d['total_amount'] ?? 0).toDouble();
      final method = d['payment_method'] ?? 'cash';
      if (method == 'cash') {
        cashSales += amt;
      } else if (method == 'upi') {
        upiSales += amt;
      } else {
        creditGiven += amt;
        creditCount++;
      }
    }

    final purchasesSnap = await _col('purchases')
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('date', isLessThan: Timestamp.fromDate(end))
        .get();

    double cashPurchases = 0, upiPurchases = 0, creditPurchases = 0;
    for (final doc in purchasesSnap.docs) {
      final d = doc.data();
      final amt = (d['total_amount'] ?? 0).toDouble();
      final method = d['payment_method'] ?? 'cash';
      if (method == 'cash') {
        cashPurchases += amt;
      } else if (method == 'upi') {
        upiPurchases += amt;
      } else {
        creditPurchases += amt;
      }
    }

    final expensesSnap = await _col('expenses')
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('date', isLessThan: Timestamp.fromDate(end))
        .get();

    double totalExpenses = 0;
    for (final doc in expensesSnap.docs) {
      totalExpenses += (doc.data()['amount'] ?? 0).toDouble();
    }

    final rentalIncome = await _rentalIncomeInRange(start, end);

    final netCash =
        (cashSales + upiSales + rentalIncome) - (cashPurchases + upiPurchases) - totalExpenses;

    return {
      'cash_sales': cashSales,
      'upi_sales': upiSales,
      'credit_given': creditGiven,
      'credit_count': creditCount,
      'cash_purchases': cashPurchases,
      'upi_purchases': upiPurchases,
      'credit_purchases': creditPurchases,
      'expenses': totalExpenses,
      'rental_income': rentalIncome,
      'net_cash': netCash,
      'total_sales': cashSales + upiSales + creditGiven,
      'total_sales_count': salesSnap.docs.length,
    };
  }

  // ─── Shop settings ────────────────────────────────────────
  Future<Map<String, dynamic>> getShopSettings() async {
    final doc = await _col('settings').doc('shop').get();
    return doc.exists ? (doc.data() ?? {}) : {};
  }

  Future<void> saveShopSettings(Map<String, dynamic> data) =>
      _col('settings').doc('shop').set(data, SetOptions(merge: true));

  // ─── Dashboard stats ──────────────────────────────────────
  Future<double> _rentalIncomeInRange(DateTime start, DateTime end) async {
    final snap = await _col('rentals')
        .where('return_date', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('return_date', isLessThan: Timestamp.fromDate(end))
        .get();
    double income = 0;
    for (final doc in snap.docs) {
      income += (doc.data()['total_rent'] ?? 0).toDouble();
    }
    return income;
  }

  Future<Map<String, dynamic>> statsForPeriod({DateTime? from, DateTime? to}) async {
    Query<Map<String, dynamic>> q = _col('sales');
    if (from != null) q = q.where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(from));
    if (to != null)   q = q.where('date', isLessThan: Timestamp.fromDate(to));

    final salesSnap = await q.get();
    double salesTotal = 0, salesProfit = 0;
    for (final doc in salesSnap.docs) {
      final d = doc.data();
      salesTotal += (d['total_amount'] ?? 0).toDouble();
      salesProfit += (d['profit'] ?? 0).toDouble();
    }

    final rentalIncome = (from != null && to != null)
        ? await _rentalIncomeInRange(from, to)
        : 0.0;

    final customersSnap = await _col('customers')
        .where('due_amount', isGreaterThan: 0)
        .get();
    double totalDues = 0;
    for (final doc in customersSnap.docs) {
      totalDues += (doc.data()['due_amount'] ?? 0).toDouble();
    }

    final activeRentals = await _col('rentals')
        .where('status', isEqualTo: 'active')
        .count()
        .get();

    return {
      'sales': salesTotal,
      'sales_profit': salesProfit,
      'rental_income': rentalIncome,
      'profit': salesProfit + rentalIncome,
      'dues': totalDues,
      'active_rentals': activeRentals.count ?? 0,
      'sales_count': salesSnap.docs.length,
    };
  }

  Future<Map<String, dynamic>> todayStats() async {
    final today = DateTime.now();
    final startOfDay = DateTime(today.year, today.month, today.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    final salesSnap = await _col('sales')
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
        .where('date', isLessThan: Timestamp.fromDate(endOfDay))
        .get();

    double salesTotal = 0, salesProfit = 0;
    for (final doc in salesSnap.docs) {
      final d = doc.data();
      salesTotal += (d['total_amount'] ?? 0).toDouble();
      salesProfit += (d['profit'] ?? 0).toDouble();
    }

    final rentalIncome = await _rentalIncomeInRange(startOfDay, endOfDay);

    final customersSnap = await _col('customers')
        .where('due_amount', isGreaterThan: 0)
        .get();
    double totalDues = 0;
    for (final doc in customersSnap.docs) {
      totalDues += (doc.data()['due_amount'] ?? 0).toDouble();
    }

    final activeRentals = await _col('rentals')
        .where('status', isEqualTo: 'active')
        .count()
        .get();

    return {
      'sales': salesTotal,
      'sales_profit': salesProfit,
      'rental_income': rentalIncome,
      'profit': salesProfit + rentalIncome,
      'dues': totalDues,
      'active_rentals': activeRentals.count ?? 0,
      'sales_count': salesSnap.docs.length,
    };
  }
}
