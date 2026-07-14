import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/theme.dart';
import '../../models/customer.dart';
import '../../providers/data_providers.dart';
import 'customer_ledger_screen.dart';

final _fmt = NumberFormat('#,##,##0', 'en_IN');

class DueAnalysisScreen extends ConsumerStatefulWidget {
  const DueAnalysisScreen({super.key});

  @override
  ConsumerState<DueAnalysisScreen> createState() =>
      _DueAnalysisScreenState();
}

class _DueAnalysisScreenState extends ConsumerState<DueAnalysisScreen> {
  final Set<String> _selected = {};
  bool _selecting = false;

  @override
  Widget build(BuildContext context) {
    final customersAsync = ref.watch(customersProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(_selecting
            ? '${_selected.length} selected'
            : 'Due Analysis'),
        backgroundColor: _selecting ? Colors.indigo[900] : AppTheme.primary,
        foregroundColor: Colors.white,
        leading: _selecting
            ? IconButton(
                icon: const Icon(Icons.close),
                onPressed: () =>
                    setState(() {
                      _selecting = false;
                      _selected.clear();
                    }),
              )
            : null,
        actions: _selecting
            ? [
                TextButton(
                  onPressed: () {
                    final all = customersAsync.valueOrNull
                            ?.where((c) => c.dueAmount > 0)
                            .map((c) => c.id)
                            .toSet() ??
                        {};
                    setState(() => _selected.addAll(all));
                  },
                  child: const Text('Select All',
                      style: TextStyle(color: Colors.white)),
                ),
              ]
            : [
                IconButton(
                  icon: const Icon(Icons.checklist_outlined),
                  tooltip: 'Multi-select',
                  onPressed: () => setState(() => _selecting = true),
                ),
              ],
      ),
      body: customersAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (customers) {
          final dueCustomers = customers
              .where((c) => c.dueAmount > 0)
              .toList()
            ..sort((a, b) => b.dueAmount.compareTo(a.dueAmount));

          final totalDue =
              dueCustomers.fold(0.0, (s, c) => s + c.dueAmount);

          if (dueCustomers.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.check_circle_outline,
                      size: 72, color: Colors.green[400]),
                  const SizedBox(height: 16),
                  const Text('No pending dues',
                      style: TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text('All customers are clear',
                      style: TextStyle(color: Colors.grey[500])),
                ],
              ),
            );
          }

          final selectedCustomers = dueCustomers
              .where((c) => _selected.contains(c.id))
              .toList();
          final selectedTotal = selectedCustomers.fold(
              0.0, (s, c) => s + c.dueAmount);

          return Column(
            children: [
              // Total outstanding banner
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                    vertical: 14, horizontal: 20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.red[700]!, Colors.red[900]!],
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Total Outstanding',
                            style: TextStyle(
                                color: Colors.white70, fontSize: 12)),
                        Text('₹${_fmt.format(totalDue)}',
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.bold)),
                        Text(
                            '${dueCustomers.length} customer${dueCustomers.length == 1 ? '' : 's'}',
                            style: const TextStyle(
                                color: Colors.white70, fontSize: 12)),
                      ],
                    ),
                    if (_selecting && _selected.isNotEmpty)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text('Selected: ${_selected.length}',
                              style: const TextStyle(
                                  color: Colors.white70, fontSize: 11)),
                          Text('₹${_fmt.format(selectedTotal)}',
                              style: const TextStyle(
                                  color: Colors.yellowAccent,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18)),
                        ],
                      ),
                  ],
                ),
              ),

              // Bulk action bar (shown when selecting)
              if (_selecting)
                Container(
                  color: Colors.indigo[50],
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.chat_outlined, size: 18),
                          label: Text(_selected.isEmpty
                              ? 'Select customers'
                              : 'Send ${_selected.length} Reminder${_selected.length == 1 ? '' : 's'}'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF25D366),
                            foregroundColor: Colors.white,
                          ),
                          onPressed: _selected.isEmpty
                              ? null
                              : () =>
                                  _sendBulkReminders(selectedCustomers),
                        ),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton.icon(
                        icon: const Icon(Icons.copy_outlined, size: 18),
                        label: const Text('Copy List'),
                        onPressed: _selected.isEmpty
                            ? null
                            : () => _copyDueList(selectedCustomers),
                      ),
                    ],
                  ),
                ),

              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: dueCustomers.length,
                  itemBuilder: (_, i) {
                    final c = dueCustomers[i];
                    return _DueCustomerCard(
                      customer: c,
                      selecting: _selecting,
                      selected: _selected.contains(c.id),
                      onToggle: () => setState(() {
                        if (_selected.contains(c.id)) {
                          _selected.remove(c.id);
                        } else {
                          _selected.add(c.id);
                        }
                      }),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _sendBulkReminders(List<Customer> customers) {
    final withMobile = customers.where((c) => c.mobile.isNotEmpty).toList();
    final noMobile = customers.where((c) => c.mobile.isEmpty).toList();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Send Reminders'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'WhatsApp will open for each customer one by one (${withMobile.length} with mobile numbers).',
              style: const TextStyle(fontSize: 13),
            ),
            if (noMobile.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                '${noMobile.length} customer${noMobile.length == 1 ? '' : 's'} skipped (no mobile): ${noMobile.map((c) => c.name).join(', ')}',
                style: TextStyle(color: Colors.orange[700], fontSize: 12),
              ),
            ],
            const SizedBox(height: 8),
            const Text(
              'Tap "Open WhatsApp" to start. Press back, then tap "Send Reminders" again for next contact.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF25D366),
                foregroundColor: Colors.white),
            onPressed: () {
              Navigator.pop(ctx);
              _openRemindersSequentially(context, withMobile, 0);
            },
            child: const Text('Open WhatsApp'),
          ),
        ],
      ),
    );
  }

  void _openRemindersSequentially(
      BuildContext context, List<Customer> customers, int index) {
    if (index >= customers.length) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('All ${customers.length} reminders sent!'),
            backgroundColor: Colors.green,
          ),
        );
      }
      return;
    }

    final c = customers[index];
    final digits = c.mobile.replaceAll(RegExp(r'[^0-9]'), '');
    final waNumber = digits.length == 10 ? '91$digits' : digits;
    final message = 'Dear ${c.name},\n\n'
        'You have an outstanding balance of ₹${_fmt.format(c.dueAmount)} '
        'with Royal Building Materials.\n\n'
        'Please make payment at your earliest convenience.\n'
        'PhonePe Sajeed Ali: 8688270190\n\n'
        'Thank you!';

    launchUrl(
      Uri.parse(
          'https://wa.me/$waNumber?text=${Uri.encodeComponent(message)}'),
      mode: LaunchMode.externalNonBrowserApplication,
    );

    if (index + 1 < customers.length && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'Opened ${c.name} — ${customers.length - index - 1} remaining'),
          duration: const Duration(seconds: 4),
          action: SnackBarAction(
            label: 'Next',
            onPressed: () => _openRemindersSequentially(
                context, customers, index + 1),
          ),
        ),
      );
    }
  }

  void _copyDueList(List<Customer> customers) {
    final lines = customers
        .map((c) =>
            '${c.name}${c.mobile.isNotEmpty ? ' (${c.mobile})' : ''} — ₹${_fmt.format(c.dueAmount)}')
        .join('\n');
    final text =
        'Pending Dues — Royal Building Materials\n'
        '${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}\n\n'
        '$lines\n\n'
        'Total: ₹${_fmt.format(customers.fold(0.0, (s, c) => s + c.dueAmount))}';

    Clipboard.setData(ClipboardData(text: text));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Due list copied to clipboard'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }
}

class _DueCustomerCard extends StatelessWidget {
  final Customer customer;
  final bool selecting;
  final bool selected;
  final VoidCallback onToggle;

  const _DueCustomerCard({
    required this.customer,
    required this.selecting,
    required this.selected,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      color: selected ? Colors.indigo[50] : null,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: selected
            ? const BorderSide(color: Colors.indigo, width: 1.5)
            : BorderSide.none,
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: selecting
            ? onToggle
            : () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) =>
                          CustomerLedgerScreen(customer: customer)),
                ),
        onLongPress: !selecting ? onToggle : null,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              if (selecting)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Checkbox(
                    value: selected,
                    onChanged: (_) => onToggle(),
                    activeColor: Colors.indigo,
                  ),
                ),
              CircleAvatar(
                radius: 24,
                backgroundColor:
                    selected ? Colors.indigo[100] : Colors.red[50],
                child: Text(
                  customer.name.isNotEmpty
                      ? customer.name[0].toUpperCase()
                      : '?',
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: selected ? Colors.indigo : Colors.red[700]),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(customer.name,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 15)),
                    if (customer.village.isNotEmpty ||
                        customer.mobile.isNotEmpty)
                      Text(
                        [customer.village, customer.mobile]
                            .where((s) => s.isNotEmpty)
                            .join(' • '),
                        style: TextStyle(
                            fontSize: 12, color: Colors.grey[500]),
                      ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.red[50],
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'Due: ₹${_fmt.format(customer.dueAmount)}',
                        style: TextStyle(
                            color: Colors.red[700],
                            fontWeight: FontWeight.bold,
                            fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
              if (!selecting) ...[
                if (customer.mobile.isNotEmpty)
                  IconButton(
                    icon: const Icon(Icons.chat_outlined),
                    color: Colors.green[700],
                    tooltip: 'Send reminder',
                    onPressed: () => _sendReminder(customer),
                  ),
                const Icon(Icons.chevron_right, color: Colors.grey),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _sendReminder(Customer c) {
    final digits = c.mobile.replaceAll(RegExp(r'[^0-9]'), '');
    final waNumber = digits.length == 10 ? '91$digits' : digits;
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
