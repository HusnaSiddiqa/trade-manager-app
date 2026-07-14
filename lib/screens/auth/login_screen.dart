import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme.dart';
import '../../providers/auth_provider.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  bool _loading = false;
  bool _googleLoading = false;
  bool _obscure = true;

  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _signInWithGoogle() async {
    setState(() => _googleLoading = true);
    try {
      await ref.read(authServiceProvider).signInWithGoogle();
    } catch (e) {
      _showError('Google sign in failed. Please try again.');
    } finally {
      if (mounted) setState(() => _googleLoading = false);
    }
  }

  Future<void> _emailSignIn() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    final email = _emailCtrl.text.trim();
    final pass = _passCtrl.text;
    try {
      await ref.read(authServiceProvider).signInWithEmail(email, pass);
    } catch (e) {
      final raw = e.toString();
      if (raw.contains('user-not-found')) {
        // New user — auto-create account
        try {
          await ref.read(authServiceProvider).registerWithEmail(email, pass);
        } catch (regErr) {
          if (mounted) _showError(_friendlyError(regErr.toString()));
        }
      } else if (raw.contains('invalid-credential') ||
          raw.contains('INVALID_LOGIN_CREDENTIALS')) {
        // Firebase merges "wrong password" and "user not found" into invalid-credential.
        // Try registering to distinguish new vs existing account.
        try {
          await ref.read(authServiceProvider).registerWithEmail(email, pass);
        } catch (regErr) {
          final regRaw = regErr.toString();
          if (regRaw.contains('email-already-in-use')) {
            // Account exists — sign-in may have failed transiently. Retry sign-in.
            try {
              await ref.read(authServiceProvider).signInWithEmail(email, pass);
              // Success — user is now signed in.
            } catch (_) {
              if (mounted) {
                _showError(
                    'Incorrect password. Tap "Forgot password?" to reset it.');
              }
            }
          } else {
            if (mounted) _showError(_friendlyError(regRaw));
          }
        }
      } else {
        _showError(_friendlyError(raw));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _forgotPassword() async {
    final email = _emailCtrl.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      _showError('Enter your email address above first');
      return;
    }
    try {
      await ref.read(authServiceProvider).sendPasswordReset(email);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Password reset email sent. Check your inbox.'),
            backgroundColor: AppTheme.success,
          ),
        );
      }
    } catch (_) {
      _showError('Could not send reset email. Check the address and try again.');
    }
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.red[700]));
  }

  String _friendlyError(String raw) {
    if (raw.contains('wrong-password')) return 'Incorrect password. Try again or use Forgot password.';
    if (raw.contains('weak-password')) return 'Password must be at least 6 characters.';
    if (raw.contains('invalid-email')) return 'Enter a valid email address.';
    if (raw.contains('email-already-in-use')) return 'This email is already registered.';
    if (raw.contains('too-many-requests')) return 'Too many attempts. Please wait and try again.';
    return 'Sign in failed. Please try again.';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [AppTheme.primary, AppTheme.primaryDark],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: MediaQuery.of(context).size.height -
                    MediaQuery.of(context).padding.top -
                    MediaQuery.of(context).padding.bottom,
              ),
              child: IntrinsicHeight(
                child: Column(
                  children: [
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.all(22),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.store_rounded, size: 64, color: Colors.white),
                    ),
                    const SizedBox(height: 22),
                    const Text(
                      'Royal Building\nMaterials',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                          height: 1.2),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'ERP Management System',
                      style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.85), fontSize: 14),
                    ),
                    const Spacer(),
                    // ── Login card ────────────────────────────────
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 24),
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                              color: Colors.black.withValues(alpha: 0.15),
                              blurRadius: 20,
                              offset: const Offset(0, 8)),
                        ],
                      ),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text('Welcome Back',
                                style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.grey[800]),
                                textAlign: TextAlign.center),
                            const SizedBox(height: 4),
                            Text('Sign in to manage your business',
                                style: TextStyle(color: Colors.grey[500], fontSize: 13),
                                textAlign: TextAlign.center),
                            const SizedBox(height: 20),

                            // Google button
                            OutlinedButton.icon(
                              onPressed: (_loading || _googleLoading) ? null : _signInWithGoogle,
                              icon: _googleLoading
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(strokeWidth: 2))
                                  : Image.network(
                                      'https://www.gstatic.com/firebasejs/ui/2.0.0/images/auth/google.svg',
                                      width: 20,
                                      height: 20,
                                      errorBuilder: (_, __, ___) =>
                                          const Icon(Icons.login, size: 20),
                                    ),
                              label: Text(
                                _googleLoading ? 'Signing in...' : 'Continue with Google',
                                style: const TextStyle(
                                    fontSize: 15, fontWeight: FontWeight.w600),
                              ),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.grey[800],
                                padding: const EdgeInsets.symmetric(vertical: 13),
                                side: BorderSide(color: Colors.grey[300]!),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10)),
                              ),
                            ),

                            const SizedBox(height: 16),
                            Row(children: [
                              Expanded(child: Divider(color: Colors.grey[300])),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 12),
                                child: Text('or use email',
                                    style: TextStyle(color: Colors.grey[400], fontSize: 12)),
                              ),
                              Expanded(child: Divider(color: Colors.grey[300])),
                            ]),
                            const SizedBox(height: 16),

                            // Email field
                            TextFormField(
                              controller: _emailCtrl,
                              decoration: const InputDecoration(
                                labelText: 'Email',
                                prefixIcon: Icon(Icons.email_outlined),
                              ),
                              keyboardType: TextInputType.emailAddress,
                              textInputAction: TextInputAction.next,
                              autocorrect: false,
                              validator: (v) =>
                                  v == null || !v.contains('@')
                                      ? 'Enter a valid email'
                                      : null,
                            ),
                            const SizedBox(height: 12),

                            // Password field
                            TextFormField(
                              controller: _passCtrl,
                              decoration: InputDecoration(
                                labelText: 'Password',
                                prefixIcon: const Icon(Icons.lock_outline),
                                suffixIcon: IconButton(
                                  icon: Icon(_obscure
                                      ? Icons.visibility_off
                                      : Icons.visibility),
                                  onPressed: () =>
                                      setState(() => _obscure = !_obscure),
                                ),
                              ),
                              obscureText: _obscure,
                              textInputAction: TextInputAction.done,
                              onFieldSubmitted: (_) => _emailSignIn(),
                              validator: (v) =>
                                  v == null || v.length < 6
                                      ? 'Minimum 6 characters'
                                      : null,
                            ),

                            // Forgot password
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton(
                                onPressed:
                                    (_loading || _googleLoading) ? null : _forgotPassword,
                                style: TextButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 0, vertical: 4)),
                                child: Text('Forgot password?',
                                    style: TextStyle(
                                        fontSize: 12, color: AppTheme.primary)),
                              ),
                            ),

                            const SizedBox(height: 4),

                            // Sign In button
                            ElevatedButton(
                              onPressed: (_loading || _googleLoading) ? null : _emailSignIn,
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10)),
                              ),
                              child: _loading
                                  ? const SizedBox(
                                      height: 20,
                                      width: 20,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2, color: Colors.white))
                                  : const Text('Sign In',
                                      style: TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w600)),
                            ),

                            const SizedBox(height: 12),
                            Text(
                              'New here? Just enter any email & password — your account will be created automatically.',
                              style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey[500],
                                  height: 1.4),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 28),
                    Text(
                      'Royal Building Materials Mtpl • v1.0',
                      style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.6), fontSize: 12),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
