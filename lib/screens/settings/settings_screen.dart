import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme.dart';
import '../../providers/data_providers.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final _upiCtrl = TextEditingController();
  final _shopNameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  bool _saving = false;
  bool _loaded = false;

  @override
  void dispose() {
    _upiCtrl.dispose();
    _shopNameCtrl.dispose();
    _phoneCtrl.dispose();
    _addressCtrl.dispose();
    super.dispose();
  }

  void _loadSettings(Map<String, dynamic> settings) {
    if (_loaded) return;
    _upiCtrl.text = settings['upi_id'] ?? '';
    _shopNameCtrl.text = settings['shop_name'] ?? 'Royal Building Materials';
    _phoneCtrl.text = settings['phone'] ?? '';
    _addressCtrl.text = settings['address'] ?? '';
    _loaded = true;
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await ref.read(firestoreServiceProvider).saveShopSettings({
        'upi_id': _upiCtrl.text.trim(),
        'shop_name': _shopNameCtrl.text.trim(),
        'phone': _phoneCtrl.text.trim(),
        'address': _addressCtrl.text.trim(),
      });
      ref.invalidate(shopSettingsProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Settings saved!'),
            backgroundColor: AppTheme.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final settingsAsync = ref.watch(shopSettingsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Shop Settings')),
      body: settingsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (settings) {
          _loadSettings(settings);
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Shop info section
              _SectionHeader(icon: Icons.store_outlined, title: 'Shop Information'),
              const SizedBox(height: 12),
              TextField(
                controller: _shopNameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Shop Name',
                  prefixIcon: Icon(Icons.business_outlined),
                ),
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _phoneCtrl,
                decoration: const InputDecoration(
                  labelText: 'Shop Phone (e.g. 8688270190 | 6305288046)',
                  prefixIcon: Icon(Icons.phone_outlined),
                ),
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _addressCtrl,
                decoration: const InputDecoration(
                  labelText: 'Shop Address',
                  hintText: 'e.g. Metpally, Vellulla Road, Beside Bridge',
                  prefixIcon: Icon(Icons.location_on_outlined),
                ),
                textCapitalization: TextCapitalization.words,
                maxLines: 2,
              ),
              const SizedBox(height: 24),

              // UPI section
              _SectionHeader(icon: Icons.qr_code_outlined, title: 'UPI Payment'),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.blue[100]!),
                ),
                child: const Text(
                  'Enter your UPI ID so customers can pay directly. '
                  'This is used to generate payment links.\n\n'
                  'Example formats:\n'
                  '• 9876543210@upi\n'
                  '• shopname@okaxis\n'
                  '• shopname@ybl  (PhonePe)\n'
                  '• shopname@okhdfcbank',
                  style: TextStyle(fontSize: 13, height: 1.5),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _upiCtrl,
                decoration: const InputDecoration(
                  labelText: 'UPI ID (VPA) *',
                  hintText: 'e.g. 9876543210@upi',
                  prefixIcon: Icon(Icons.account_balance_outlined),
                ),
                keyboardType: TextInputType.emailAddress,
              ),
              if (_upiCtrl.text.isNotEmpty) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      _upiCtrl.text.contains('@')
                          ? Icons.check_circle_outline
                          : Icons.warning_amber_outlined,
                      size: 16,
                      color: _upiCtrl.text.contains('@')
                          ? Colors.green
                          : Colors.orange,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _upiCtrl.text.contains('@')
                          ? 'UPI ID format looks correct'
                          : 'UPI ID must contain @ (e.g. number@upi)',
                      style: TextStyle(
                        fontSize: 12,
                        color: _upiCtrl.text.contains('@')
                            ? Colors.green[700]
                            : Colors.orange[700],
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _saving ? null : _save,
                  icon: _saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.save_outlined),
                  label: const Text('Save Settings'),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  const _SectionHeader({required this.icon, required this.title});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: AppTheme.primary, size: 20),
        const SizedBox(width: 8),
        Text(title,
            style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: AppTheme.primary)),
        const SizedBox(width: 8),
        const Expanded(child: Divider()),
      ],
    );
  }
}
