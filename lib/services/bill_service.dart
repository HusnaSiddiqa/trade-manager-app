import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../models/sale.dart';
import '../models/purchase.dart';
import 'bill_downloader_mobile.dart'
    if (dart.library.html) 'bill_downloader_web.dart';

class BillService {
  static final _fmt = NumberFormat('#,##,##0', 'en_IN');
  static String _r(double v) => '₹${_fmt.format(v)}';

  static Future<void> generateAndShare(
    Sale sale,
    Map<String, dynamic> shopSettings,
  ) async {
    final shopName = shopSettings['shop_name'] as String? ?? 'Royal Building Materials';
    final shopPhone = shopSettings['phone'] as String? ?? '8688270190 | 6305288046';
    final shopAddress = shopSettings['address'] as String? ?? 'Metpally, Vellulla Road, Beside Bridge';

    // Load fonts that support ₹ (U+20B9)
    final regular = await PdfGoogleFonts.notoSansRegular();
    final bold = await PdfGoogleFonts.notoSansBold();
    final italic = await PdfGoogleFonts.notoSansItalic();

    // Load shop logo from assets
    pw.MemoryImage? logo;
    try {
      final bytes = await rootBundle.load('assets/icon/icon.png');
      logo = pw.MemoryImage(bytes.buffer.asUint8List());
    } catch (_) {}

    final pdf = pw.Document(
      theme: pw.ThemeData.withFont(base: regular, bold: bold, italic: italic),
    );

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a5,
        margin: const pw.EdgeInsets.all(0),
        build: (ctx) =>
            _buildPage(ctx, sale, shopName, shopPhone, shopAddress, logo),
      ),
    );

    final bytes = await pdf.save();
    final date = DateFormat('ddMMyy').format(sale.date);
    final filename = 'Bill_${sale.customerName.replaceAll(' ', '_')}_$date.pdf';

    final fmt = NumberFormat('#,##,##0', 'en_IN');
    final isBorrow = sale.paymentMethod == 'credit' ||
        sale.paymentMethod == 'borrow';
    final message = 'Hello ${sale.customerName},\n\n'
        'Here is your bill from $shopName.\n\n'
        'Amount: ₹${fmt.format(sale.totalAmount)}\n'
        'Paid:   ₹${fmt.format(sale.paidAmount)}\n'
        '${sale.dueAmount > 0 ? 'Due:    ₹${fmt.format(sale.dueAmount)}\n' : ''}'
        '${isBorrow ? '\nPhonePe Sajeed Ali: 8688270190\n' : ''}'
        '\nThank you for your business!\n'
        'Build Better, Build Royal 🏗️';

    await platformDownloadOrShare(bytes, filename, sale.customerMobile, message);
  }

  static pw.Widget _buildPage(
    pw.Context ctx,
    Sale sale,
    String shopName,
    String shopPhone,
    String shopAddress,
    pw.MemoryImage? logo,
  ) {
    const navy = PdfColor.fromInt(0xFF1A237E);
    const gold = PdfColor.fromInt(0xFFD4A017);
    const lightBlue = PdfColor.fromInt(0xFFE8EAF6);

    final payLabel = {
          'cash': 'Cash',
          'upi': 'UPI',
          'borrow': 'Borrow',
          'credit': 'Credit',
        }[sale.paymentMethod] ??
        sale.paymentMethod.toUpperCase();

    final payColor = sale.paymentMethod == 'cash'
        ? const PdfColor.fromInt(0xFF2E7D32)
        : sale.paymentMethod == 'upi'
            ? const PdfColor.fromInt(0xFF1565C0)
            : const PdfColor.fromInt(0xFFE65100);

    final subtotal = sale.items.fold(0.0, (s, e) => s + e.total);

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        // ── Header band ───────────────────────────────────────
        pw.Container(
          color: navy,
          padding: const pw.EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          child: pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              // Logo
              if (logo != null)
                pw.Container(
                  width: 52,
                  height: 52,
                  decoration: pw.BoxDecoration(
                    shape: pw.BoxShape.circle,
                    color: PdfColors.white,
                  ),
                  child: pw.ClipOval(
                    child: pw.Image(logo, fit: pw.BoxFit.cover),
                  ),
                )
              else
                pw.Container(
                  width: 52,
                  height: 52,
                  decoration: pw.BoxDecoration(
                    shape: pw.BoxShape.circle,
                    color: gold,
                  ),
                  child: pw.Center(
                    child: pw.Text('R',
                        style: pw.TextStyle(
                            color: navy,
                            fontSize: 28,
                            fontWeight: pw.FontWeight.bold)),
                  ),
                ),
              pw.SizedBox(width: 14),
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      shopName.toUpperCase(),
                      style: pw.TextStyle(
                        color: PdfColors.white,
                        fontSize: 14,
                        fontWeight: pw.FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                    if (shopAddress.isNotEmpty) ...[
                      pw.SizedBox(height: 3),
                      pw.Text(shopAddress,
                          style: const pw.TextStyle(
                              color: PdfColors.grey300, fontSize: 8.5)),
                    ],
                    if (shopPhone.isNotEmpty) ...[
                      pw.SizedBox(height: 3),
                      pw.Text('Ph: $shopPhone',
                          style: pw.TextStyle(
                              color: gold, fontSize: 9)),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),

        // ── Gold bar: SALES BILL + date ───────────────────────
        pw.Container(
          color: gold,
          padding: const pw.EdgeInsets.symmetric(horizontal: 20, vertical: 6),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('SALES BILL',
                  style: pw.TextStyle(
                      color: navy,
                      fontWeight: pw.FontWeight.bold,
                      fontSize: 11,
                      letterSpacing: 1)),
              pw.Text(
                DateFormat('dd MMM yyyy').format(sale.date),
                style: pw.TextStyle(
                    color: navy,
                    fontWeight: pw.FontWeight.bold,
                    fontSize: 10),
              ),
            ],
          ),
        ),

        // ── Customer + payment mode ───────────────────────────
        pw.Container(
          color: lightBlue,
          padding: const pw.EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('Bill To',
                        style: const pw.TextStyle(
                            color: PdfColors.grey600, fontSize: 8)),
                    pw.SizedBox(height: 3),
                    pw.Text(sale.customerName,
                        style: pw.TextStyle(
                            fontWeight: pw.FontWeight.bold, fontSize: 13)),
                    if (sale.customerMobile.isNotEmpty)
                      pw.Text(sale.customerMobile,
                          style: const pw.TextStyle(
                              color: PdfColors.grey700, fontSize: 9)),
                  ],
                ),
              ),
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(
                    horizontal: 10, vertical: 4),
                decoration: pw.BoxDecoration(
                  color: payColor,
                  borderRadius: pw.BorderRadius.circular(4),
                ),
                child: pw.Text(
                  payLabel,
                  style: pw.TextStyle(
                      color: PdfColors.white,
                      fontSize: 9,
                      fontWeight: pw.FontWeight.bold),
                ),
              ),
            ],
          ),
        ),

        pw.SizedBox(height: 0),

        // ── Items table ───────────────────────────────────────
        pw.Padding(
          padding: const pw.EdgeInsets.symmetric(horizontal: 20),
          child: pw.Table(
            border: pw.TableBorder(
              bottom: const pw.BorderSide(color: PdfColors.grey300, width: 0.5),
              horizontalInside:
                  const pw.BorderSide(color: PdfColors.grey200, width: 0.5),
            ),
            columnWidths: {
              0: const pw.FixedColumnWidth(22),   // #
              1: const pw.FlexColumnWidth(3.5),   // Item
              2: const pw.FlexColumnWidth(1.4),   // Qty
              3: const pw.FlexColumnWidth(1.6),   // Rate
              4: const pw.FlexColumnWidth(1.8),   // Amount
            },
            children: [
              // Header
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: navy),
                children: [
                  for (final entry in [
                    ('#', pw.TextAlign.center),
                    ('Item', pw.TextAlign.left),
                    ('Qty', pw.TextAlign.center),
                    ('Rate', pw.TextAlign.right),
                    ('Amount', pw.TextAlign.right),
                  ])
                    pw.Padding(
                      padding: const pw.EdgeInsets.symmetric(
                          horizontal: 5, vertical: 6),
                      child: pw.Text(entry.$1,
                          textAlign: entry.$2,
                          style: pw.TextStyle(
                              color: PdfColors.white,
                              fontWeight: pw.FontWeight.bold,
                              fontSize: 9)),
                    ),
                ],
              ),
              // Rows
              ...sale.items.asMap().entries.map((e) {
                final idx = e.key + 1;
                final item = e.value;
                final isEven = idx % 2 == 0;
                return pw.TableRow(
                  decoration: pw.BoxDecoration(
                      color: isEven
                          ? const PdfColor.fromInt(0xFFF8F9FF)
                          : PdfColors.white),
                  children: [
                    _cell('$idx', align: pw.TextAlign.center),
                    _cell('${item.productName} (${item.unit})'),
                    _cell(
                      item.quantity % 1 == 0
                          ? item.quantity.toInt().toString()
                          : item.quantity.toStringAsFixed(1),
                    ),
                    _cell(_r(item.rate), align: pw.TextAlign.right),
                    _cell(_r(item.total), bold: true, align: pw.TextAlign.right),
                  ],
                );
              }),
            ],
          ),
        ),

        // ── Totals ────────────────────────────────────────────
        pw.Padding(
          padding: const pw.EdgeInsets.fromLTRB(20, 8, 20, 0),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              _totalRow('Subtotal', _r(subtotal)),
              if (sale.transportCharge > 0)
                _totalRow('Transport', _r(sale.transportCharge)),
              pw.Container(
                color: navy,
                padding: const pw.EdgeInsets.symmetric(
                    horizontal: 8, vertical: 5),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('TOTAL',
                        style: pw.TextStyle(
                            color: PdfColors.white,
                            fontWeight: pw.FontWeight.bold,
                            fontSize: 12)),
                    pw.Text(_r(sale.totalAmount),
                        style: pw.TextStyle(
                            color: gold,
                            fontWeight: pw.FontWeight.bold,
                            fontSize: 13)),
                  ],
                ),
              ),
              pw.SizedBox(height: 4),
              _totalRow(
                'Paid',
                _r(sale.paidAmount),
                valueColor: const PdfColor.fromInt(0xFF2E7D32),
              ),
              if (sale.dueAmount > 0)
                _totalRow(
                  'Balance Due',
                  _r(sale.dueAmount),
                  valueColor: const PdfColor.fromInt(0xFFC62828),
                  bold: true,
                ),
            ],
          ),
        ),

        pw.Spacer(),

        // ── Footer ────────────────────────────────────────────
        pw.Container(
          color: lightBlue,
          padding: const pw.EdgeInsets.symmetric(vertical: 10, horizontal: 20),
          child: pw.Column(
            children: [
              pw.Text(
                'Build Better, Build Royal',
                style: pw.TextStyle(
                    color: navy,
                    fontWeight: pw.FontWeight.bold,
                    fontSize: 11),
                textAlign: pw.TextAlign.center,
              ),
              pw.SizedBox(height: 3),
              pw.Text(
                'Thank you for your business!',
                style: const pw.TextStyle(
                    color: PdfColors.grey600, fontSize: 9),
                textAlign: pw.TextAlign.center,
              ),
            ],
          ),
        ),
      ],
    );
  }

  static pw.Widget _cell(String text,
          {bool bold = false,
          pw.TextAlign align = pw.TextAlign.left}) =>
      pw.Padding(
        padding:
            const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 5),
        child: pw.Text(
          text,
          textAlign: align,
          style: pw.TextStyle(
            fontSize: 9,
            fontWeight:
                bold ? pw.FontWeight.bold : pw.FontWeight.normal,
          ),
        ),
      );

  static pw.Widget _totalRow(
    String label,
    String value, {
    bool bold = false,
    PdfColor? valueColor,
  }) =>
      pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 2, horizontal: 8),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(label,
                style: const pw.TextStyle(
                    color: PdfColors.grey700, fontSize: 10)),
            pw.Text(value,
                style: pw.TextStyle(
                    fontSize: 10,
                    fontWeight: bold
                        ? pw.FontWeight.bold
                        : pw.FontWeight.normal,
                    color: valueColor ?? PdfColors.black)),
          ],
        ),
      );

  // ── Purchase / GRN invoice ────────────────────────────────────────────────

  static Future<void> generatePurchaseInvoice(
    Purchase purchase,
    Map<String, dynamic> shopSettings,
  ) async {
    final shopName =
        shopSettings['shop_name'] as String? ?? 'Royal Building Materials';
    final shopPhone = shopSettings['phone'] as String? ?? '8688270190 | 6305288046';
    final shopAddress = shopSettings['address'] as String? ?? 'Metpally, Vellulla Road, Beside Bridge';

    final regular = await PdfGoogleFonts.notoSansRegular();
    final bold = await PdfGoogleFonts.notoSansBold();
    final italic = await PdfGoogleFonts.notoSansItalic();

    pw.MemoryImage? logo;
    try {
      final bytes = await rootBundle.load('assets/icon/icon.png');
      logo = pw.MemoryImage(bytes.buffer.asUint8List());
    } catch (_) {}

    const navy = PdfColor.fromInt(0xFF1A237E);
    const gold = PdfColor.fromInt(0xFFD4A017);
    const lightBlue = PdfColor.fromInt(0xFFE8EAF6);
    final fmt = NumberFormat('#,##,##0', 'en_IN');
    String r(double v) => '₹${fmt.format(v)}';

    final pdf = pw.Document(
        theme: pw.ThemeData.withFont(base: regular, bold: bold, italic: italic));

    pdf.addPage(pw.Page(
      pageFormat: PdfPageFormat.a5,
      margin: const pw.EdgeInsets.all(0),
      build: (_) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          // Header
          pw.Container(
            color: navy,
            padding: const pw.EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            child: pw.Row(
              children: [
                if (logo != null)
                  pw.Container(
                    width: 48, height: 48,
                    decoration: pw.BoxDecoration(
                        shape: pw.BoxShape.circle, color: PdfColors.white),
                    child: pw.ClipOval(
                        child: pw.Image(logo, fit: pw.BoxFit.cover)),
                  )
                else
                  pw.Container(
                    width: 48, height: 48,
                    decoration: pw.BoxDecoration(
                        shape: pw.BoxShape.circle, color: gold),
                    child: pw.Center(
                        child: pw.Text('R',
                            style: pw.TextStyle(
                                color: navy,
                                fontSize: 26,
                                fontWeight: pw.FontWeight.bold))),
                  ),
                pw.SizedBox(width: 12),
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(shopName.toUpperCase(),
                          style: pw.TextStyle(
                              color: PdfColors.white,
                              fontSize: 13,
                              fontWeight: pw.FontWeight.bold)),
                      if (shopAddress.isNotEmpty)
                        pw.Text(shopAddress,
                            style: const pw.TextStyle(
                                color: PdfColors.grey300, fontSize: 8)),
                      if (shopPhone.isNotEmpty)
                        pw.Text('Ph: $shopPhone',
                            style: pw.TextStyle(color: gold, fontSize: 8.5)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // GRN bar
          pw.Container(
            color: gold,
            padding:
                const pw.EdgeInsets.symmetric(horizontal: 20, vertical: 6),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('PURCHASE RECEIPT',
                    style: pw.TextStyle(
                        color: navy,
                        fontWeight: pw.FontWeight.bold,
                        fontSize: 10,
                        letterSpacing: 0.8)),
                pw.Text(DateFormat('dd MMM yyyy').format(purchase.date),
                    style: pw.TextStyle(
                        color: navy,
                        fontWeight: pw.FontWeight.bold,
                        fontSize: 10)),
              ],
            ),
          ),
          // Supplier info
          pw.Container(
            color: lightBlue,
            padding:
                const pw.EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('Supplier',
                    style: const pw.TextStyle(
                        color: PdfColors.grey600, fontSize: 8)),
                pw.SizedBox(height: 2),
                pw.Text(purchase.supplierName,
                    style: pw.TextStyle(
                        fontWeight: pw.FontWeight.bold, fontSize: 13)),
                if (purchase.supplierMobile.isNotEmpty)
                  pw.Text(purchase.supplierMobile,
                      style: const pw.TextStyle(
                          color: PdfColors.grey700, fontSize: 9)),
              ],
            ),
          ),
          // Items table
          pw.Padding(
            padding: const pw.EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: pw.Table(
              border: pw.TableBorder(
                bottom: const pw.BorderSide(
                    color: PdfColors.grey300, width: 0.5),
                horizontalInside:
                    const pw.BorderSide(color: PdfColors.grey200, width: 0.5),
              ),
              columnWidths: {
                0: const pw.FixedColumnWidth(20),
                1: const pw.FlexColumnWidth(3.5),
                2: const pw.FlexColumnWidth(1.4),
                3: const pw.FlexColumnWidth(1.6),
                4: const pw.FlexColumnWidth(1.8),
              },
              children: [
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: navy),
                  children: [
                    for (final entry in [
                      ('#', pw.TextAlign.center),
                      ('Item', pw.TextAlign.left),
                      ('Qty', pw.TextAlign.center),
                      ('Rate', pw.TextAlign.right),
                      ('Amount', pw.TextAlign.right),
                    ])
                      pw.Padding(
                        padding: const pw.EdgeInsets.symmetric(
                            horizontal: 5, vertical: 6),
                        child: pw.Text(entry.$1,
                            textAlign: entry.$2,
                            style: pw.TextStyle(
                                color: PdfColors.white,
                                fontWeight: pw.FontWeight.bold,
                                fontSize: 9)),
                      ),
                  ],
                ),
                ...purchase.items.asMap().entries.map((e) {
                  final idx = e.key + 1;
                  final item = e.value;
                  final isEven = idx % 2 == 0;
                  return pw.TableRow(
                    decoration: pw.BoxDecoration(
                        color: isEven
                            ? const PdfColor.fromInt(0xFFF8F9FF)
                            : PdfColors.white),
                    children: [
                      _cell('$idx', align: pw.TextAlign.center),
                      _cell('${item.productName} (${item.unit})'),
                      _cell(item.quantity % 1 == 0
                          ? item.quantity.toInt().toString()
                          : item.quantity.toStringAsFixed(1)),
                      _cell(r(item.rate), align: pw.TextAlign.right),
                      _cell(r(item.total), bold: true, align: pw.TextAlign.right),
                    ],
                  );
                }),
              ],
            ),
          ),
          // Total
          pw.Padding(
            padding: const pw.EdgeInsets.fromLTRB(20, 0, 20, 0),
            child: pw.Container(
              color: navy,
              padding:
                  const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('TOTAL AMOUNT',
                      style: pw.TextStyle(
                          color: PdfColors.white,
                          fontWeight: pw.FontWeight.bold,
                          fontSize: 11)),
                  pw.Text(r(purchase.totalAmount),
                      style: pw.TextStyle(
                          color: gold,
                          fontWeight: pw.FontWeight.bold,
                          fontSize: 13)),
                ],
              ),
            ),
          ),
          pw.Padding(
            padding: const pw.EdgeInsets.fromLTRB(20, 6, 20, 0),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('Payment Method',
                    style: const pw.TextStyle(
                        color: PdfColors.grey600, fontSize: 9)),
                pw.Text(
                  {
                        'cash': 'Cash',
                        'upi': 'UPI',
                        'credit': 'Due',
                      }[purchase.paymentMethod] ??
                      purchase.paymentMethod.toUpperCase(),
                  style: pw.TextStyle(
                      color: navy,
                      fontWeight: pw.FontWeight.bold,
                      fontSize: 10),
                ),
              ],
            ),
          ),
          if (purchase.notes.isNotEmpty)
            pw.Padding(
              padding: const pw.EdgeInsets.fromLTRB(20, 8, 20, 0),
              child: pw.Text('Note: ${purchase.notes}',
                  style: const pw.TextStyle(
                      color: PdfColors.grey600, fontSize: 9)),
            ),
          pw.Spacer(),
          pw.Container(
            color: lightBlue,
            padding:
                const pw.EdgeInsets.symmetric(vertical: 10, horizontal: 20),
            child: pw.Column(
              children: [
                pw.Text('Build Better, Build Royal',
                    style: pw.TextStyle(
                        color: navy,
                        fontWeight: pw.FontWeight.bold,
                        fontSize: 10),
                    textAlign: pw.TextAlign.center),
              ],
            ),
          ),
        ],
      ),
    ));

    final bytes = await pdf.save();
    final date = DateFormat('ddMMyy').format(purchase.date);
    final filename =
        'Purchase_${purchase.supplierName.replaceAll(' ', '_')}_$date.pdf';
    final fmt2 = NumberFormat('#,##,##0', 'en_IN');
    final payLabel = {
          'cash': 'Cash',
          'upi': 'UPI',
          'credit': 'Credit',
        }[purchase.paymentMethod] ??
        purchase.paymentMethod.toUpperCase();
    final message = 'Hello ${purchase.supplierName},\n\n'
        'Please find attached the purchase receipt from $shopName.\n\n'
        'Date: ${DateFormat('dd MMM yyyy').format(purchase.date)}\n'
        'Total Amount: ₹${fmt2.format(purchase.totalAmount)}\n'
        'Payment: $payLabel\n\n'
        'Thank you!\n'
        'Build Better, Build Royal 🏗️';
    await platformDownloadOrShare(
        bytes, filename, purchase.supplierMobile, message);
  }

  // ─── Rental receipt ───────────────────────────────────────
  static Future<void> generateRentalReceipt(
    dynamic rental, // Rental
    Map<String, dynamic> shopSettings,
    String paymentMethod,
  ) async {
    final shopName = shopSettings['shop_name'] as String? ??
        'Royal Building Materials';
    final shopPhone = shopSettings['phone'] as String? ??
        '8688270190 | 6305288046';
    final shopAddress = shopSettings['address'] as String? ??
        'Metpally, Vellulla Road, Beside Bridge';

    final regular = await PdfGoogleFonts.notoSansRegular();
    final bold = await PdfGoogleFonts.notoSansBold();
    final italic = await PdfGoogleFonts.notoSansItalic();

    pw.MemoryImage? logo;
    try {
      final bytes = await rootBundle.load('assets/icon/icon.png');
      logo = pw.MemoryImage(bytes.buffer.asUint8List());
    } catch (_) {}

    const navy = PdfColor.fromInt(0xFF1A237E);
    const gold = PdfColor.fromInt(0xFFD4A017);
    const lightBlue = PdfColor.fromInt(0xFFE8EAF6);

    final pdf = pw.Document(
      theme: pw.ThemeData.withFont(base: regular, bold: bold, italic: italic),
    );

    final fmt = NumberFormat('#,##,##0', 'en_IN');
    String r(double v) => '₹${fmt.format(v)}';

    final returnDate = rental.returnDate ?? DateTime.now();
    final daysOut = rental.daysOut as int;
    final totalRent = rental.totalRent > 0
        ? rental.totalRent
        : rental.calculatedRent;

    final payLabel = {
          'cash': 'Cash',
          'upi': 'UPI',
          'borrow': 'Borrow / Due',
        }[paymentMethod] ??
        paymentMethod.toUpperCase();

    // Build items rows
    final List<Map<String, dynamic>> rows = [];
    final entries = rental.entries as List;
    if (entries.isNotEmpty) {
      for (final e in entries) {
        rows.add({
          'item': e.itemName,
          'qty': e.quantity,
          'days': daysOut,
          'rate': e.rentPerDay,
          'amount': daysOut * e.quantity * e.rentPerDay,
        });
      }
    } else {
      rows.add({
        'item': rental.itemName,
        'qty': rental.quantity.toInt(),
        'days': daysOut,
        'rate': rental.rentPerDay,
        'amount': totalRent,
      });
    }

    pdf.addPage(pw.Page(
      pageFormat: PdfPageFormat.a5,
      margin: const pw.EdgeInsets.all(0),
      build: (_) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          // Header
          pw.Container(
            color: navy,
            padding:
                const pw.EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                if (logo != null)
                  pw.Container(
                    width: 48,
                    height: 48,
                    decoration: const pw.BoxDecoration(
                        shape: pw.BoxShape.circle, color: PdfColors.white),
                    child: pw.ClipOval(
                        child: pw.Image(logo, fit: pw.BoxFit.cover)),
                  )
                else
                  pw.Container(
                    width: 48,
                    height: 48,
                    decoration: pw.BoxDecoration(
                        shape: pw.BoxShape.circle, color: gold),
                    child: pw.Center(
                        child: pw.Text('R',
                            style: pw.TextStyle(
                                color: navy,
                                fontSize: 26,
                                fontWeight: pw.FontWeight.bold))),
                  ),
                pw.SizedBox(width: 12),
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(shopName.toUpperCase(),
                          style: pw.TextStyle(
                              color: PdfColors.white,
                              fontSize: 13,
                              fontWeight: pw.FontWeight.bold)),
                      if (shopAddress.isNotEmpty)
                        pw.Text(shopAddress,
                            style: const pw.TextStyle(
                                color: PdfColors.grey300, fontSize: 8)),
                      if (shopPhone.isNotEmpty)
                        pw.Text('Ph: $shopPhone',
                            style:
                                pw.TextStyle(color: gold, fontSize: 8.5)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Title bar
          pw.Container(
            color: gold,
            padding: const pw.EdgeInsets.symmetric(
                horizontal: 20, vertical: 8),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('RENTAL RECEIPT',
                    style: pw.TextStyle(
                        color: navy,
                        fontWeight: pw.FontWeight.bold,
                        fontSize: 13,
                        letterSpacing: 0.5)),
                pw.Text(
                    DateFormat('dd MMM yyyy').format(returnDate),
                    style: pw.TextStyle(
                        color: navy,
                        fontWeight: pw.FontWeight.bold,
                        fontSize: 11)),
              ],
            ),
          ),
          // Customer section
          pw.Container(
            color: lightBlue,
            padding: const pw.EdgeInsets.fromLTRB(20, 10, 20, 10),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('Customer',
                        style: const pw.TextStyle(
                            color: PdfColors.grey600, fontSize: 8)),
                    pw.SizedBox(height: 2),
                    pw.Text(rental.customerName,
                        style: pw.TextStyle(
                            fontWeight: pw.FontWeight.bold,
                            fontSize: 13)),
                    if ((rental.customerMobile as String).isNotEmpty)
                      pw.Text(rental.customerMobile,
                          style: const pw.TextStyle(
                              color: PdfColors.grey700, fontSize: 9)),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text(
                        'Issued: ${DateFormat('dd MMM yyyy').format(rental.issueDate)}',
                        style: const pw.TextStyle(
                            color: PdfColors.grey600, fontSize: 8)),
                    pw.Text('Duration: $daysOut day${daysOut == 1 ? '' : 's'}',
                        style: pw.TextStyle(
                            fontWeight: pw.FontWeight.bold,
                            fontSize: 9)),
                  ],
                ),
              ],
            ),
          ),
          // Items table
          pw.Padding(
            padding: const pw.EdgeInsets.symmetric(
                horizontal: 20, vertical: 8),
            child: pw.Table(
              border: pw.TableBorder(
                bottom: const pw.BorderSide(
                    color: PdfColors.grey300, width: 0.5),
                horizontalInside: const pw.BorderSide(
                    color: PdfColors.grey200, width: 0.5),
              ),
              columnWidths: {
                0: const pw.FlexColumnWidth(3),
                1: const pw.FixedColumnWidth(28),
                2: const pw.FixedColumnWidth(28),
                3: const pw.FlexColumnWidth(1.6),
                4: const pw.FlexColumnWidth(1.8),
              },
              children: [
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: navy),
                  children: ['Item', 'Qty', 'Days', 'Rate/Day', 'Amount']
                      .map((h) => pw.Padding(
                            padding: const pw.EdgeInsets.symmetric(
                                horizontal: 5, vertical: 6),
                            child: pw.Text(h,
                                style: pw.TextStyle(
                                    color: PdfColors.white,
                                    fontWeight: pw.FontWeight.bold,
                                    fontSize: 9)),
                          ))
                      .toList(),
                ),
                ...rows.asMap().entries.map((e) {
                  final idx = e.key;
                  final row = e.value;
                  final isEven = idx % 2 == 0;
                  pw.Widget cell(String t,
                          {pw.TextAlign align = pw.TextAlign.left}) =>
                      pw.Padding(
                        padding: const pw.EdgeInsets.symmetric(
                            horizontal: 5, vertical: 5),
                        child: pw.Text(t,
                            style: const pw.TextStyle(fontSize: 9),
                            textAlign: align),
                      );
                  return pw.TableRow(
                    decoration: pw.BoxDecoration(
                        color: isEven
                            ? const PdfColor.fromInt(0xFFF8F9FF)
                            : PdfColors.white),
                    children: [
                      cell(row['item']),
                      cell('${row['qty']}',
                          align: pw.TextAlign.center),
                      cell('${row['days']}',
                          align: pw.TextAlign.center),
                      cell(r(row['rate'].toDouble()),
                          align: pw.TextAlign.right),
                      pw.Padding(
                        padding: const pw.EdgeInsets.symmetric(
                            horizontal: 5, vertical: 5),
                        child: pw.Text(r(row['amount'].toDouble()),
                            style: pw.TextStyle(
                                fontWeight: pw.FontWeight.bold,
                                fontSize: 9),
                            textAlign: pw.TextAlign.right),
                      ),
                    ],
                  );
                }),
              ],
            ),
          ),
          // Total bar
          pw.Padding(
            padding:
                const pw.EdgeInsets.fromLTRB(20, 0, 20, 0),
            child: pw.Container(
              color: navy,
              padding: const pw.EdgeInsets.symmetric(
                  horizontal: 8, vertical: 6),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('TOTAL RENT',
                      style: pw.TextStyle(
                          color: PdfColors.white,
                          fontWeight: pw.FontWeight.bold,
                          fontSize: 11)),
                  pw.Text(r(totalRent),
                      style: pw.TextStyle(
                          color: gold,
                          fontWeight: pw.FontWeight.bold,
                          fontSize: 13)),
                ],
              ),
            ),
          ),
          // Payment method
          pw.Padding(
            padding: const pw.EdgeInsets.fromLTRB(20, 6, 20, 0),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('Payment',
                    style: const pw.TextStyle(
                        color: PdfColors.grey600, fontSize: 9)),
                pw.Text(payLabel,
                    style: pw.TextStyle(
                        color: navy,
                        fontWeight: pw.FontWeight.bold,
                        fontSize: 10)),
              ],
            ),
          ),
          pw.Spacer(),
          pw.Container(
            color: lightBlue,
            padding: const pw.EdgeInsets.symmetric(
                vertical: 10, horizontal: 20),
            child: pw.Text('Build Better, Build Royal',
                style: pw.TextStyle(
                    color: navy,
                    fontWeight: pw.FontWeight.bold,
                    fontSize: 10),
                textAlign: pw.TextAlign.center),
          ),
        ],
      ),
    ));

    final bytes2 = await pdf.save();
    final dateStr = DateFormat('ddMMyy').format(returnDate);
    final filename =
        'Rental_${(rental.customerName as String).replaceAll(' ', '_')}_$dateStr.pdf';
    final payMsgLabel = paymentMethod == 'borrow'
        ? 'Due (will pay later)\nPhonePe Sajeed Ali: 8688270190'
        : payLabel;
    final message = 'Hello ${rental.customerName},\n\n'
        'Your rental receipt from $shopName.\n\n'
        'Items: ${rental.itemsSummary}\n'
        'Issued: ${DateFormat('dd MMM yyyy').format(rental.issueDate)}\n'
        'Returned: ${DateFormat('dd MMM yyyy').format(returnDate)}\n'
        'Days: $daysOut\n'
        'Total Rent: ${r(totalRent)}\n'
        'Payment: $payMsgLabel\n\n'
        'Thank you!\n'
        'Build Better, Build Royal 🏗️';
    await platformDownloadOrShare(
        bytes2, filename, rental.customerMobile as String, message);
  }

  // ─── Combined due statement ───────────────────────────────
  static Future<void> generateCombinedDueInvoice(
    List<Sale> dueSales,
    Map<String, dynamic> shopSettings,
  ) async {
    assert(dueSales.isNotEmpty);

    final shopName =
        shopSettings['shop_name'] as String? ?? 'Royal Building Materials';
    final shopPhone =
        shopSettings['phone'] as String? ?? '8688270190 | 6305288046';
    final shopAddress = shopSettings['address'] as String? ??
        'Metpally, Vellulla Road, Beside Bridge';

    final regular = await PdfGoogleFonts.notoSansRegular();
    final bold = await PdfGoogleFonts.notoSansBold();
    final italic = await PdfGoogleFonts.notoSansItalic();

    pw.MemoryImage? logo;
    try {
      final bytes = await rootBundle.load('assets/icon/icon.png');
      logo = pw.MemoryImage(bytes.buffer.asUint8List());
    } catch (_) {}

    const navy = PdfColor.fromInt(0xFF1A237E);
    const gold = PdfColor.fromInt(0xFFD4A017);
    const lightBlue = PdfColor.fromInt(0xFFE8EAF6);
    const red = PdfColor.fromInt(0xFFB71C1C);

    final fmt = NumberFormat('#,##,##0', 'en_IN');
    String r(double v) => '₹${fmt.format(v)}';

    final customer = dueSales.first;
    final totalDue =
        dueSales.fold(0.0, (s, e) => s + e.dueAmount);
    final totalBilled =
        dueSales.fold(0.0, (s, e) => s + e.totalAmount);
    final totalPaid =
        dueSales.fold(0.0, (s, e) => s + e.paidAmount);
    final today = DateTime.now();

    final pdf = pw.Document(
      theme: pw.ThemeData.withFont(
          base: regular, bold: bold, italic: italic),
    );

    // Build content widgets for all pages
    List<pw.Widget> buildContent() {
      final sections = <pw.Widget>[];

      // ── shop header ──
      sections.add(pw.Container(
        color: navy,
        padding:
            const pw.EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          children: [
            if (logo != null)
              pw.Container(
                width: 48,
                height: 48,
                decoration: const pw.BoxDecoration(
                    shape: pw.BoxShape.circle, color: PdfColors.white),
                child: pw.ClipOval(
                    child: pw.Image(logo, fit: pw.BoxFit.cover)),
              )
            else
              pw.Container(
                width: 48,
                height: 48,
                decoration: pw.BoxDecoration(
                    shape: pw.BoxShape.circle, color: gold),
                child: pw.Center(
                    child: pw.Text('R',
                        style: pw.TextStyle(
                            color: navy,
                            fontSize: 26,
                            fontWeight: pw.FontWeight.bold))),
              ),
            pw.SizedBox(width: 12),
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(shopName.toUpperCase(),
                      style: pw.TextStyle(
                          color: PdfColors.white,
                          fontSize: 13,
                          fontWeight: pw.FontWeight.bold)),
                  if (shopAddress.isNotEmpty)
                    pw.Text(shopAddress,
                        style: const pw.TextStyle(
                            color: PdfColors.grey300, fontSize: 8)),
                  if (shopPhone.isNotEmpty)
                    pw.Text('Ph: $shopPhone',
                        style:
                            pw.TextStyle(color: gold, fontSize: 8.5)),
                ],
              ),
            ),
          ],
        ),
      ));

      // ── title bar ──
      sections.add(pw.Container(
        color: red,
        padding: const pw.EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text('DUE STATEMENT',
                style: pw.TextStyle(
                    color: PdfColors.white,
                    fontWeight: pw.FontWeight.bold,
                    fontSize: 13,
                    letterSpacing: 0.5)),
            pw.Text(DateFormat('dd MMM yyyy').format(today),
                style: pw.TextStyle(
                    color: PdfColors.white,
                    fontWeight: pw.FontWeight.bold,
                    fontSize: 11)),
          ],
        ),
      ));

      // ── customer section ──
      sections.add(pw.Container(
        color: lightBlue,
        padding: const pw.EdgeInsets.fromLTRB(20, 10, 20, 10),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('Customer',
                    style: const pw.TextStyle(
                        color: PdfColors.grey600, fontSize: 8)),
                pw.SizedBox(height: 2),
                pw.Text(customer.customerName,
                    style: pw.TextStyle(
                        fontWeight: pw.FontWeight.bold, fontSize: 14)),
                if (customer.customerMobile.isNotEmpty)
                  pw.Text(customer.customerMobile,
                      style: const pw.TextStyle(
                          color: PdfColors.grey700, fontSize: 9)),
                if (customer.customerVillage.isNotEmpty)
                  pw.Text(customer.customerVillage,
                      style: const pw.TextStyle(
                          color: PdfColors.grey600, fontSize: 9)),
              ],
            ),
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Text('${dueSales.length} unpaid bill${dueSales.length == 1 ? '' : 's'}',
                    style: const pw.TextStyle(
                        color: PdfColors.grey600, fontSize: 9)),
                pw.SizedBox(height: 4),
                pw.Text('Total Due',
                    style: const pw.TextStyle(
                        color: PdfColors.grey600, fontSize: 9)),
                pw.Text(r(totalDue),
                    style: pw.TextStyle(
                        color: red,
                        fontWeight: pw.FontWeight.bold,
                        fontSize: 16)),
              ],
            ),
          ],
        ),
      ));

      sections.add(pw.SizedBox(height: 10));

      // ── each sale as a section ──
      for (int idx = 0; idx < dueSales.length; idx++) {
        final sale = dueSales[idx];
        final saleNum = idx + 1;

        sections.add(pw.Padding(
          padding: const pw.EdgeInsets.symmetric(horizontal: 16),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              // Sale header row
              pw.Container(
                decoration: const pw.BoxDecoration(color: navy),
                padding: const pw.EdgeInsets.symmetric(
                    horizontal: 10, vertical: 6),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('Bill #$saleNum',
                        style: pw.TextStyle(
                            color: PdfColors.white,
                            fontWeight: pw.FontWeight.bold,
                            fontSize: 10)),
                    pw.Text(
                        DateFormat('dd MMM yyyy, hh:mm a')
                            .format(sale.date),
                        style: const pw.TextStyle(
                            color: PdfColors.grey200, fontSize: 9)),
                  ],
                ),
              ),
              // Items table
              pw.Table(
                border: pw.TableBorder(
                  bottom: const pw.BorderSide(
                      color: PdfColors.grey300, width: 0.5),
                  horizontalInside: const pw.BorderSide(
                      color: PdfColors.grey200, width: 0.3),
                ),
                columnWidths: {
                  0: const pw.FlexColumnWidth(3),
                  1: const pw.FixedColumnWidth(34),
                  2: const pw.FlexColumnWidth(1.8),
                  3: const pw.FlexColumnWidth(1.8),
                },
                children: [
                  pw.TableRow(
                    decoration:
                        const pw.BoxDecoration(color: PdfColor.fromInt(0xFFE8EAF6)),
                    children: [
                      for (final entry in [
                        ('Item', pw.TextAlign.left),
                        ('Qty', pw.TextAlign.center),
                        ('Rate', pw.TextAlign.right),
                        ('Amount', pw.TextAlign.right),
                      ])
                        pw.Padding(
                          padding: const pw.EdgeInsets.symmetric(
                              horizontal: 6, vertical: 4),
                          child: pw.Text(entry.$1,
                              textAlign: entry.$2,
                              style: pw.TextStyle(
                                  fontSize: 8,
                                  fontWeight: pw.FontWeight.bold,
                                  color: navy)),
                        ),
                    ],
                  ),
                  ...sale.items.asMap().entries.map((e) {
                    final item = e.value;
                    final isEven = e.key % 2 == 0;
                    pw.Widget cell(String t,
                            {pw.TextAlign align = pw.TextAlign.left}) =>
                        pw.Padding(
                          padding: const pw.EdgeInsets.symmetric(
                              horizontal: 6, vertical: 4),
                          child: pw.Text(t,
                              style: const pw.TextStyle(fontSize: 8),
                              textAlign: align),
                        );
                    return pw.TableRow(
                      decoration: pw.BoxDecoration(
                          color: isEven
                              ? const PdfColor.fromInt(0xFFF8F9FF)
                              : PdfColors.white),
                      children: [
                        cell(item.productName),
                        cell(
                            '${item.quantity % 1 == 0 ? item.quantity.toInt() : item.quantity} ${item.unit}',
                            align: pw.TextAlign.center),
                        cell(r(item.rate),
                            align: pw.TextAlign.right),
                        pw.Padding(
                          padding: const pw.EdgeInsets.symmetric(
                              horizontal: 6, vertical: 4),
                          child: pw.Text(r(item.total),
                              style: pw.TextStyle(
                                  fontWeight: pw.FontWeight.bold,
                                  fontSize: 8),
                              textAlign: pw.TextAlign.right),
                        ),
                      ],
                    );
                  }),
                ],
              ),
              // Sale subtotals
              pw.Container(
                color: const PdfColor.fromInt(0xFFF0F0F8),
                padding: const pw.EdgeInsets.symmetric(
                    horizontal: 10, vertical: 5),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.end,
                  children: [
                    pw.Text('Bill Total: ${r(sale.totalAmount)}',
                        style: const pw.TextStyle(
                            color: PdfColors.grey700, fontSize: 9)),
                    pw.SizedBox(width: 16),
                    if (sale.paidAmount > 0)
                      pw.Text('Paid: ${r(sale.paidAmount)}',
                          style: const pw.TextStyle(
                              color: PdfColors.green800, fontSize: 9)),
                    if (sale.paidAmount > 0) pw.SizedBox(width: 16),
                    pw.Text('Due: ${r(sale.dueAmount)}',
                        style: pw.TextStyle(
                            color: red,
                            fontWeight: pw.FontWeight.bold,
                            fontSize: 10)),
                  ],
                ),
              ),
              pw.SizedBox(height: 10),
            ],
          ),
        ));
      }

      // ── grand total footer ──
      sections.add(pw.Padding(
        padding: const pw.EdgeInsets.symmetric(horizontal: 16),
        child: pw.Container(
          decoration: pw.BoxDecoration(
            color: red,
            borderRadius: const pw.BorderRadius.all(
                pw.Radius.circular(6)),
          ),
          padding: const pw.EdgeInsets.all(12),
          child: pw.Column(
            children: [
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Billed',
                      style: const pw.TextStyle(
                          color: PdfColors.grey200, fontSize: 10)),
                  pw.Text(r(totalBilled),
                      style: const pw.TextStyle(
                          color: PdfColors.white, fontSize: 10)),
                ],
              ),
              if (totalPaid > 0) ...[
                pw.SizedBox(height: 3),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('Paid',
                        style: const pw.TextStyle(
                            color: PdfColors.grey200, fontSize: 10)),
                    pw.Text(r(totalPaid),
                        style: const pw.TextStyle(
                            color: PdfColors.green200, fontSize: 10)),
                  ],
                ),
              ],
              pw.SizedBox(height: 5),
              pw.Divider(color: PdfColors.grey300, thickness: 0.5),
              pw.SizedBox(height: 5),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('TOTAL DUE',
                      style: pw.TextStyle(
                          color: PdfColors.white,
                          fontWeight: pw.FontWeight.bold,
                          fontSize: 13)),
                  pw.Text(r(totalDue),
                      style: pw.TextStyle(
                          color: gold,
                          fontWeight: pw.FontWeight.bold,
                          fontSize: 18)),
                ],
              ),
            ],
          ),
        ),
      ));

      sections.add(pw.SizedBox(height: 8));

      // ── payment instructions ──
      sections.add(pw.Padding(
        padding: const pw.EdgeInsets.symmetric(horizontal: 16),
        child: pw.Container(
          decoration: pw.BoxDecoration(
            border: pw.Border.all(
                color: const PdfColor.fromInt(0xFFD4A017), width: 0.5),
            borderRadius:
                const pw.BorderRadius.all(pw.Radius.circular(6)),
          ),
          padding: const pw.EdgeInsets.all(10),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('Payment:',
                  style: pw.TextStyle(
                      fontSize: 9,
                      fontWeight: pw.FontWeight.bold,
                      color: navy)),
              pw.SizedBox(height: 3),
              pw.Text('PhonePe / GPay: 8688270190 (Sajeed Ali)',
                  style: const pw.TextStyle(
                      fontSize: 9, color: PdfColors.grey700)),
            ],
          ),
        ),
      ));

      // ── footer ──
      sections.add(pw.Container(
        color: lightBlue,
        padding:
            const pw.EdgeInsets.symmetric(vertical: 10, horizontal: 20),
        child: pw.Text('Build Better, Build Royal',
            style: pw.TextStyle(
                color: navy,
                fontWeight: pw.FontWeight.bold,
                fontSize: 10),
            textAlign: pw.TextAlign.center),
      ));

      return sections;
    }

    pdf.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(0),
      footer: (_) => pw.Container(
        color: red,
        padding: const pw.EdgeInsets.symmetric(horizontal: 20, vertical: 7),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text('TOTAL OUTSTANDING DUE',
                style: pw.TextStyle(
                    color: PdfColors.white,
                    fontWeight: pw.FontWeight.bold,
                    fontSize: 10)),
            pw.Text(r(totalDue),
                style: pw.TextStyle(
                    color: gold,
                    fontWeight: pw.FontWeight.bold,
                    fontSize: 14)),
          ],
        ),
      ),
      build: (_) => buildContent(),
    ));

    final pdfBytes = await pdf.save();
    final dateStr = DateFormat('ddMMyy').format(today);
    final filename =
        'DueStatement_${customer.customerName.replaceAll(' ', '_')}_$dateStr.pdf';

    final itemsList = dueSales
        .expand((s) => s.items)
        .map((i) =>
            '${i.productName} ${i.quantity % 1 == 0 ? i.quantity.toInt() : i.quantity} ${i.unit}')
        .join(', ');

    final message =
        'Hello ${customer.customerName},\n\n'
        'Here is your combined due statement from $shopName.\n\n'
        '${dueSales.length} unpaid bill${dueSales.length == 1 ? '' : 's'}:\n'
        '$itemsList\n\n'
        'Total Due: ${r(totalDue)}\n\n'
        'Please pay via PhonePe / GPay: 8688270190\n\n'
        'Thank you!\n'
        'Build Better, Build Royal 🏗️';

    await platformDownloadOrShare(
        pdfBytes, filename, customer.customerMobile, message);
  }
}
