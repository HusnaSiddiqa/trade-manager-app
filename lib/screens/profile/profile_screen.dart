import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../providers/auth_provider.dart';
import '../../providers/data_providers.dart';
import '../settings/settings_screen.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authStateProvider).valueOrNull;
    final shopAsync = ref.watch(shopSettingsProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      body: CustomScrollView(
        slivers: [
          // ── Collapsible royal header ──────────────────────────
          SliverAppBar(
            expandedHeight: 220,
            pinned: true,
            backgroundColor: const Color(0xFF1A237E),
            foregroundColor: Colors.white,
            title: const Text('Account & Shop'),
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF1A237E), Color(0xFF283593)],
                  ),
                ),
                child: SafeArea(
                  child: shopAsync.when(
                    loading: () => const SizedBox.shrink(),
                    error: (_, __) => const SizedBox.shrink(),
                    data: (settings) {
                      final name = settings['shop_name'] as String? ??
                          'Royal Building Materials';
                      final phone =
                          settings['phone'] as String? ?? '—';
                      final address =
                          settings['address'] as String? ?? '—';

                      return Padding(
                        padding: const EdgeInsets.fromLTRB(20, 48, 20, 16),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 52,
                                  height: 52,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFD4A017),
                                    borderRadius:
                                        BorderRadius.circular(14),
                                  ),
                                  child: const Icon(Icons.store,
                                      color: Color(0xFF1A237E), size: 30),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        name,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      const Text(
                                        'Building Materials Shop',
                                        style: TextStyle(
                                            color: Colors.white60,
                                            fontSize: 12),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            _InfoRow(
                                Icons.phone_outlined, phone, Colors.white70),
                            const SizedBox(height: 4),
                            _InfoRow(Icons.location_on_outlined, address,
                                Colors.white70),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Business details card ─────────────────────
                  shopAsync.when(
                    loading: () => const SizedBox.shrink(),
                    error: (_, __) => const SizedBox.shrink(),
                    data: (settings) {
                      final name = settings['shop_name'] as String? ??
                          'Royal Building Materials';
                      final phone =
                          settings['phone'] as String? ?? '';
                      final address =
                          settings['address'] as String? ?? '';
                      final upi = settings['upi_id'] as String? ?? '';

                      return _Card(
                        title: 'Business Details',
                        icon: Icons.business_outlined,
                        children: [
                          _DetailRow(
                              icon: Icons.storefront_outlined,
                              label: 'Shop Name',
                              value: name),
                          if (phone.isNotEmpty)
                            _DetailRow(
                              icon: Icons.phone_outlined,
                              label: 'Phone',
                              value: phone,
                              onTap: () =>
                                  launchUrl(Uri.parse('tel:${phone.split('|').first.trim()}')),
                            ),
                          if (address.isNotEmpty)
                            _DetailRow(
                                icon: Icons.location_on_outlined,
                                label: 'Address',
                                value: address),
                          if (upi.isNotEmpty)
                            _DetailRow(
                                icon: Icons.account_balance_outlined,
                                label: 'UPI ID',
                                value: upi),
                          const SizedBox(height: 8),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              icon: const Icon(Icons.edit_outlined, size: 16),
                              label: const Text('Edit Business Details'),
                              onPressed: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (_) => const SettingsScreen()),
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),

                  const SizedBox(height: 16),

                  // ── Account card ──────────────────────────────
                  _Card(
                    title: 'Account',
                    icon: Icons.account_circle_outlined,
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 28,
                            backgroundColor:
                                const Color(0xFF1A237E).withValues(alpha: 0.1),
                            backgroundImage: user?.photoURL != null
                                ? NetworkImage(user!.photoURL!)
                                : null,
                            child: user?.photoURL == null
                                ? const Icon(Icons.person,
                                    size: 28,
                                    color: Color(0xFF1A237E))
                                : null,
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (user?.displayName != null &&
                                    user!.displayName!.isNotEmpty)
                                  Text(
                                    user.displayName!,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15),
                                  ),
                                Text(
                                  user?.email ?? '—',
                                  style: const TextStyle(
                                      color: Colors.grey, fontSize: 13),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // ── Logout button ─────────────────────────────
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red[700],
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: const Icon(Icons.logout),
                      label: const Text(
                        'Sign Out',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      onPressed: () => _confirmSignOut(context, ref),
                    ),
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _confirmSignOut(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sign Out'),
        content:
            const Text('Are you sure you want to sign out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red[700],
                foregroundColor: Colors.white),
            onPressed: () async {
              Navigator.pop(ctx);
              await ref.read(authServiceProvider).signOut();
            },
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color;
  const _InfoRow(this.icon, this.text, this.color);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            style: TextStyle(color: color, fontSize: 12),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

class _Card extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<Widget> children;
  const _Card(
      {required this.title, required this.icon, required this.children});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 1,
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 18, color: const Color(0xFF1A237E)),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: Color(0xFF1A237E),
                  ),
                ),
              ],
            ),
            const Divider(height: 20),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final VoidCallback? onTap;
  const _DetailRow(
      {required this.icon,
      required this.label,
      required this.value,
      this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 18, color: Colors.grey[600]),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                        color: Colors.grey, fontSize: 11),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: onTap != null
                          ? const Color(0xFF1A237E)
                          : Colors.black87,
                    ),
                  ),
                ],
              ),
            ),
            if (onTap != null)
              const Icon(Icons.open_in_new,
                  size: 14, color: Colors.grey),
          ],
        ),
      ),
    );
  }
}
