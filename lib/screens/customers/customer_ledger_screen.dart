import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/theme.dart';
import '../../models/customer.dart';
import '../../models/sale.dart';
import '../../providers/data_providers.dart';
import '../../services/bill_service.dart';
import '../sales/add_sale_screen.dart';

final _fmt = NumberFormat('#,##,##0', 'en_IN');
final _dateFmt = DateFormat('dd MMM yyyy');

class CustomerLedgerScreen extends ConsumerStatefulWidget {
  final Customer customer;
  const CustomerLedgerScreen({super.key, required this.customer});

  @override
  ConsumerState<CustomerLedgerScreen> createState() =>
      _CustomerLedgerScreenState();
}

class _CustomerLedgerScreenState extends ConsumerState<CustomerLedgerScreen> {
  Customer get customer => widget.customer;
  bool _generatingCombined = false;
  bool _selectMode = false;
  Set<String> _selectedIds = {};

  Future<void> _generateCombinedInvoice(List<Sale> dueSales) async {
    if (dueSales.isEmpty || _generatingCombined) return;
    setState(() => _generatingCombined = true);
    try {
      final shopSettings = await ref
          .read(firestoreServiceProvider)
          .getShopSettings();
      await BillService.generateCombinedDueInvoice(dueSales, shopSettings);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _generatingCombined = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final salesAsync = ref.watch(customerSalesProvider(customer.id));
    final rentalsAsync = ref.watch(rentalsProvider);

    // Compute due sales at this level so AppBar can use it
    final dueSales = salesAsync.valueOrNull
            ?.where((s) => s.dueAmount > 0.01)
            .toList() ??
        [];

    return Scaffold(
      appBar: AppBar(
        title: Text(customer.name),
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
        actions: _selectMode
            ? [
                if (_selectedIds.isNotEmpty)
                  _generatingCombined
                      ? const Padding(
                          padding: EdgeInsets.all(14),
                          child: SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                  color: Colors.white, strokeWidth: 2)),
                        )
                      : IconButton(
                          icon: const Icon(Icons.picture_as_pdf_outlined),
                          tooltip: 'Generate PDF',
                          onPressed: () {
                            final selectedSales = (salesAsync.valueOrNull ?? [])
                                .where((s) => _selectedIds.contains(s.id))
                                .toList();
                            _generateCombinedInvoice(selectedSales);
                          },
                        ),
                IconButton(
                  icon: const Icon(Icons.close),
                  tooltip: 'Cancel selection',
                  onPressed: () =>
                      setState(() { _selectMode = false; _selectedIds.clear(); }),
                ),
              ]
            : [
                // Combined due invoice button (unchanged)
                if (dueSales.isNotEmpty)
                  Tooltip(
                    message: 'Combined Due Invoice',
                    child: IconButton(
                      icon: _generatingCombined
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                  color: Colors.white, strokeWidth: 2))
                          : Stack(
                              clipBehavior: Clip.none,
                              children: [
                                const Icon(Icons.picture_as_pdf_outlined),
                                if (dueSales.length > 1)
                                  Positioned(
                                    right: -4,
                                    top: -4,
                                    child: Container(
                                      width: 16,
                                      height: 16,
                                      decoration: const BoxDecoration(
                                          color: Colors.red,
                                          shape: BoxShape.circle),
                                      child: Center(
                                        child: Text('${dueSales.length}',
                                            style: const TextStyle(
                                                fontSize: 10,
                                                color: Colors.white,
                                                fontWeight: FontWeight.bold)),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                      onPressed: _generatingCombined
                          ? null
                          : () => _generateCombinedInvoice(dueSales),
                    ),
                  ),
                if (customer.mobile.isNotEmpty)
                  IconButton(
                    icon: const Icon(Icons.chat_outlined),
                    tooltip: 'Send WhatsApp reminder',
                    onPressed: () => _sendReminder(customer),
                  ),
                IconButton(
                  icon: const Icon(Icons.checklist_outlined),
                  tooltip: 'Select bills to export PDF',
                  onPressed: () => setState(() { _selectMode = true; _selectedIds.clear(); }),
                ),
                IconButton(
                  icon: const Icon(Icons.note_alt_outlined),
                  tooltip: 'Edit notes',
                  onPressed: () => _editNotes(context),
                ),
              ],
      ),
      body: salesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (sales) {
          final totalBought =
              sales.fold(0.0, (s, e) => s + e.totalAmount);
          final totalPaid =
              sales.fold(0.0, (s, e) => s + e.paidAmount);
          final totalDue =
              sales.fold(0.0, (s, e) => s + e.dueAmount);
          final orderCount = sales.length;
          final avgOrder =
              orderCount > 0 ? totalBought / orderCount : 0.0;
          final lastDate =
              sales.isNotEmpty ? sales.first.date : null;

          // Most purchased product
          final productCounts = <String, double>{};
          for (final s in sales) {
            for (final item in s.items) {
              productCounts[item.productName] =
                  (productCounts[item.productName] ?? 0) +
                      item.quantity;
            }
          }
          String? topProduct;
          if (productCounts.isNotEmpty) {
            topProduct = productCounts.entries
                .reduce((a, b) => a.value > b.value ? a : b)
                .key;
          }

          // Active rentals for this customer
          final activeRentals = rentalsAsync.valueOrNull
                  ?.where((r) =>
                      r.status == 'active' &&
                      r.customerName.toLowerCase() ==
                          customer.name.toLowerCase())
                  .length ??
              0;

          return ListView(
            padding: EdgeInsets.zero,
            children: [
              // Gradient summary header
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [AppTheme.primary, Colors.indigo[900]!],
                  ),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        _SummaryTile('Total Spent',
                            '₹${_fmt.format(totalBought)}', Colors.white70),
                        const SizedBox(width: 1),
                        _SummaryTile('Paid',
                            '₹${_fmt.format(totalPaid)}',
                            Colors.greenAccent[100]!),
                        const SizedBox(width: 1),
                        _SummaryTile(
                            'Due',
                            '₹${_fmt.format(totalDue)}',
                            totalDue > 0
                                ? Colors.red[200]!
                                : Colors.greenAccent[100]!),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // Analytics row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _StatPill(Icons.receipt_long_outlined,
                            '$orderCount orders'),
                        if (avgOrder > 0)
                          _StatPill(Icons.trending_up_outlined,
                              'Avg ₹${_fmt.format(avgOrder)}'),
                        if (activeRentals > 0)
                          _StatPill(Icons.handshake_outlined,
                              '$activeRentals active rental${activeRentals > 1 ? 's' : ''}'),
                        if (lastDate != null)
                          _StatPill(Icons.access_time_outlined,
                              _relativeDate(lastDate)),
                      ],
                    ),
                  ],
                ),
              ),

              // Info strip
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 8),
                color: Colors.grey[50],
                child: Wrap(
                  spacing: 16,
                  children: [
                    if (customer.mobile.isNotEmpty)
                      Row(mainAxisSize: MainAxisSize.min, children: [
                        const Icon(Icons.phone_outlined,
                            size: 14, color: Colors.grey),
                        const SizedBox(width: 4),
                        Text(customer.mobile,
                            style: TextStyle(
                                fontSize: 13, color: Colors.grey[600])),
                      ]),
                    if (customer.village.isNotEmpty)
                      Row(mainAxisSize: MainAxisSize.min, children: [
                        const Icon(Icons.location_on_outlined,
                            size: 14, color: Colors.grey),
                        const SizedBox(width: 4),
                        Text(customer.village,
                            style: TextStyle(
                                fontSize: 13, color: Colors.grey[600])),
                      ]),
                    if (topProduct != null)
                      Row(mainAxisSize: MainAxisSize.min, children: [
                        const Icon(Icons.star_outline,
                            size: 14, color: Colors.amber),
                        const SizedBox(width: 4),
                        Text('Top: $topProduct',
                            style: TextStyle(
                                fontSize: 13, color: Colors.grey[600])),
                      ]),
                  ],
                ),
              ),

              // Notes panel (always visible, editable)
              if (customer.notes.isNotEmpty)
                Container(
                  margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.amber[50],
                    border: Border.all(color: Colors.amber[200]!),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.sticky_note_2_outlined,
                          size: 16, color: Colors.amber),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(customer.notes,
                            style: TextStyle(
                                fontSize: 13, color: Colors.grey[800])),
                      ),
                      GestureDetector(
                        onTap: () => _editNotes(context),
                        child: const Icon(Icons.edit_outlined,
                            size: 16, color: Colors.grey),
                      ),
                    ],
                  ),
                )
              else
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                  child: GestureDetector(
                    onTap: () => _editNotes(context),
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                            color: Colors.grey[300]!, style: BorderStyle.solid),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.add_comment_outlined,
                              size: 16, color: Colors.grey),
                          SizedBox(width: 8),
                          Text('Add notes about this customer',
                              style: TextStyle(
                                  color: Colors.grey, fontSize: 13)),
                        ],
                      ),
                    ),
                  ),
                ),

              // Transaction list header
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                child: Row(
                  children: [
                    Text(
                      'Transactions',
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: Colors.grey[700]),
                    ),
                    const Spacer(),
                    if (_selectMode && sales.isNotEmpty) ...[
                      Checkbox(
                        value: _selectedIds.length == sales.length
                            ? true
                            : _selectedIds.isEmpty
                                ? false
                                : null,
                        tristate: true,
                        activeColor: AppTheme.primary,
                        onChanged: (v) => setState(() {
                          if (v == true || _selectedIds.isNotEmpty) {
                            _selectedIds = sales.map((s) => s.id).toSet();
                          } else {
                            _selectedIds.clear();
                          }
                        }),
                      ),
                      Text(
                        _selectedIds.isEmpty
                            ? 'Select all'
                            : '${_selectedIds.length} selected',
                        style: TextStyle(
                            fontSize: 13,
                            color: _selectedIds.isEmpty
                                ? Colors.grey
                                : AppTheme.primary,
                            fontWeight: _selectedIds.isEmpty
                                ? FontWeight.normal
                                : FontWeight.w600),
                      ),
                    ],
                  ],
                ),
              ),

              if (_selectMode && _selectedIds.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 4),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _generatingCombined
                          ? null
                          : () {
                              final selectedSales = sales
                                  .where((s) => _selectedIds.contains(s.id))
                                  .toList();
                              _generateCombinedInvoice(selectedSales);
                            },
                      icon: _generatingCombined
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.picture_as_pdf_outlined, size: 18),
                      label: Text(_generatingCombined
                          ? 'Generating...'
                          : 'Generate PDF (${_selectedIds.length} bill${_selectedIds.length == 1 ? '' : 's'})'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ),

              if (sales.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(40),
                  child: Center(
                    child: Text('No transactions yet',
                        style: TextStyle(color: Colors.grey)),
                  ),
                )
              else
                ...sales.map((s) => Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: _SaleCard(
                      sale: s,
                      customer: customer,
                      selectMode: _selectMode,
                      selected: _selectedIds.contains(s.id),
                      onToggle: () => setState(() {
                        if (_selectedIds.contains(s.id)) {
                          _selectedIds.remove(s.id);
                        } else {
                          _selectedIds.add(s.id);
                        }
                      }),
                    ))),
              const SizedBox(height: 30),
            ],
          );
        },
      ),
    );
  }

  String _relativeDate(DateTime d) {
    final diff = DateTime.now().difference(d).inDays;
    if (diff == 0) return 'today';
    if (diff == 1) return 'yesterday';
    return '$diff days ago';
  }

  void _editNotes(BuildContext context) {
    final ctrl = TextEditingController(text: customer.notes);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
            left: 20,
            right: 20,
            top: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Notes for ${customer.name}',
                style: const TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 4),
            const Text(
                'e.g. "Builder in Vellulla colony", "pays on 1st of month"',
                style: TextStyle(color: Colors.grey, fontSize: 12)),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              maxLines: 4,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                hintText: 'Any notes about this customer...',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primary,
                        foregroundColor: Colors.white),
                    onPressed: () async {
                      Navigator.pop(ctx);
                      final updated =
                          customer.copyWith(notes: ctrl.text.trim());
                      await ref
                          .read(firestoreServiceProvider)
                          .updateCustomer(updated);
                    },
                    child: const Text('Save'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  void _sendReminder(Customer c) {
    final digits = c.mobile.replaceAll(RegExp(r'[^0-9]'), '');
    final waNumber =
        digits.length == 10 ? '91$digits' : digits;
    final message = 'Dear ${c.name},\n\n'
        'You have an outstanding balance of ₹${_fmt.format(c.dueAmount)} '
        'with Royal Building Materials.\n\n'
        'Please make payment at your earliest convenience.\n'
        'PhonePe Sajeed Ali: 8688270190\n\n'
        'Thank you!';
    final uri = Uri.parse(
        'https://wa.me/$waNumber?text=${Uri.encodeComponent(message)}');
    launchUrl(uri, mode: LaunchMode.externalNonBrowserApplication)
        .catchError((_) => false);
  }
}

class _StatPill extends StatelessWidget {
  final IconData icon;
  final String label;
  const _StatPill(this.icon, this.label);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: Colors.white70),
          const SizedBox(width: 5),
          Text(label,
              style: const TextStyle(fontSize: 11, color: Colors.white)),
        ],
      ),
    );
  }
}

class _SummaryTile extends StatelessWidget {
  final String label;
  final String value;
  final Color valueColor;
  const _SummaryTile(this.label, this.value, this.valueColor);

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(label,
              style: const TextStyle(color: Colors.white54, fontSize: 11)),
          const SizedBox(height: 4),
          Text(value,
              style: TextStyle(
                  color: valueColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 14)),
        ],
      ),
    );
  }
}

class _SaleCard extends ConsumerStatefulWidget {
  final Sale sale;
  final Customer customer;
  final bool selectMode;
  final bool selected;
  final VoidCallback? onToggle;

  const _SaleCard({
    required this.sale,
    required this.customer,
    this.selectMode = false,
    this.selected = false,
    this.onToggle,
  });

  @override
  ConsumerState<_SaleCard> createState() => _SaleCardState();
}

class _SaleCardState extends ConsumerState<_SaleCard> {
  bool _paying = false;

  String get _itemsSummary {
    if (widget.sale.items.isEmpty) return '';
    return widget.sale.items
        .map((i) =>
            '${i.productName} ${i.quantity % 1 == 0 ? i.quantity.toInt() : i.quantity} ${i.unit}')
        .join(', ');
  }

  Future<void> _recordPayment() async {
    final amountCtrl = TextEditingController();
    final remaining = widget.sale.dueAmount;

    final confirmed = await showDialog<double>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Record Payment'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Remaining due: ₹${_fmt.format(remaining)}',
              style: TextStyle(
                  color: Colors.red[700], fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: amountCtrl,
              autofocus: true,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: 'Amount received (₹)',
                prefixIcon: const Icon(Icons.currency_rupee),
                hintText: _fmt.format(remaining),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              final amt =
                  double.tryParse(amountCtrl.text.trim()) ?? 0;
              if (amt <= 0) return;
              if (amt > remaining + 0.01) {
                ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(
                    content: Text(
                        'Amount cannot exceed remaining due')));
                return;
              }
              Navigator.pop(ctx, amt);
            },
            child: const Text('Confirm'),
          ),
        ],
      ),
    );

    if (confirmed == null || !mounted) return;
    setState(() => _paying = true);
    try {
      await ref.read(firestoreServiceProvider).recordPayment(
            widget.sale.id,
            widget.customer.id,
            confirmed,
          );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(
                '₹${_fmt.format(confirmed)} payment recorded'),
            backgroundColor: AppTheme.success));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _paying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final sale = widget.sale;
    final hasDue = sale.dueAmount > 0.01;
    final isCreditSale =
        sale.paymentMethod == 'credit' || sale.paymentMethod == 'borrow';

    // Method label
    final methodLabel = {
          'cash': 'Cash',
          'upi': 'UPI',
          'credit': 'Credit',
          'borrow': 'Credit',
        }[sale.paymentMethod] ??
        sale.paymentMethod.toUpperCase();

    final methodColor = sale.paymentMethod == 'cash'
        ? Colors.green[700]!
        : sale.paymentMethod == 'upi'
            ? Colors.purple
            : Colors.orange[700]!;

    return GestureDetector(
      onTap: widget.selectMode ? widget.onToggle : null,
      child: Card(
        margin: const EdgeInsets.only(bottom: 10),
        color: widget.selected
            ? AppTheme.primary.withValues(alpha: 0.07)
            : null,
        shape: widget.selected
            ? RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: AppTheme.primary.withValues(alpha: 0.4), width: 1.5))
            : null,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Date + payment method + actions
              Row(
                children: [
                  if (widget.selectMode) ...[
                    Checkbox(
                      value: widget.selected,
                      onChanged: (_) => widget.onToggle?.call(),
                      activeColor: AppTheme.primary,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      visualDensity: VisualDensity.compact,
                    ),
                    const SizedBox(width: 4),
                  ],
                  Text(_dateFmt.format(sale.date),
                      style: TextStyle(
                          fontSize: 12, color: Colors.grey[500])),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: methodColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(5),
                    ),
                    child: Text(methodLabel,
                        style: TextStyle(
                            fontSize: 11,
                            color: methodColor,
                            fontWeight: FontWeight.w600)),
                  ),
                  if (!widget.selectMode) PopupMenuButton<String>(
                  icon: Icon(Icons.more_vert, size: 16, color: Colors.grey[400]),
                  padding: EdgeInsets.zero,
                  onSelected: (v) async {
                    if (v == 'edit') {
                      Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => AddSaleScreen(sale: sale)));
                    } else if (v == 'delete') {
                      final ok = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('Delete Bill?'),
                          content: Text(
                              'Delete bill of ₹${_fmt.format(sale.totalAmount)}?'),
                          actions: [
                            TextButton(
                                onPressed: () => Navigator.pop(ctx, false),
                                child: const Text('Cancel')),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.red,
                                  foregroundColor: Colors.white),
                              onPressed: () => Navigator.pop(ctx, true),
                              child: const Text('Delete'),
                            ),
                          ],
                        ),
                      );
                      if (ok == true && mounted) {
                        await ref
                            .read(firestoreServiceProvider)
                            .deleteSale(sale);
                      }
                    }
                  },
                  itemBuilder: (_) => [
                    const PopupMenuItem(
                      value: 'edit',
                      child: Row(children: [
                        Icon(Icons.edit_outlined, size: 16),
                        SizedBox(width: 8),
                        Text('Edit Bill'),
                      ]),
                    ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(children: [
                        Icon(Icons.delete_outline, color: Colors.red, size: 16),
                        SizedBox(width: 8),
                        Text('Delete', style: TextStyle(color: Colors.red)),
                      ]),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 6),
            // Items
            if (_itemsSummary.isNotEmpty)
              Text(_itemsSummary,
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w500)),
            const SizedBox(height: 8),
            // Amount breakdown
            Row(
              children: [
                _AmtChip('Total',
                    '₹${_fmt.format(sale.totalAmount)}', Colors.grey[700]!),
                const SizedBox(width: 8),
                _AmtChip('Paid',
                    '₹${_fmt.format(sale.paidAmount)}', Colors.green[700]!),
                if (hasDue) ...[
                  const SizedBox(width: 8),
                  _AmtChip('Due',
                      '₹${_fmt.format(sale.dueAmount)}', Colors.red[700]!,
                      bold: true),
                ],
              ],
            ),
            // Record payment button (only for credit sales with remaining due)
            if (isCreditSale && hasDue) ...[
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _paying ? null : _recordPayment,
                  icon: _paying
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.payments_outlined, size: 16),
                  label: Text(_paying
                      ? 'Recording...'
                      : 'Record Payment Received'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.green[700],
                    side: BorderSide(color: Colors.green[700]!),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    ),
  );
  }
}

class _AmtChip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final bool bold;
  const _AmtChip(this.label, this.value, this.color,
      {this.bold = false});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: TextStyle(fontSize: 10, color: Colors.grey[500])),
        Text(value,
            style: TextStyle(
                fontSize: 13,
                color: color,
                fontWeight:
                    bold ? FontWeight.bold : FontWeight.w500)),
      ],
    );
  }
}
