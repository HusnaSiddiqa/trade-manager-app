import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'firebase_options.dart';
import 'core/theme.dart';
import 'providers/auth_provider.dart';
import 'providers/data_providers.dart';
import 'screens/splash_screen.dart';
import 'screens/auth/login_screen.dart';
import 'screens/home/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: true,
    cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
  );
  runApp(const ProviderScope(child: RoyalERPApp()));
}

class RoyalERPApp extends ConsumerWidget {
  const RoyalERPApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);
    final isOnline = ref.watch(connectivityProvider).valueOrNull ?? true;

    return MaterialApp(
      title: 'Royal Building Materials ERP',
      theme: AppTheme.lightTheme,
      debugShowCheckedModeBanner: false,
      home: Column(
        children: [
          if (!isOnline)
            Material(
              color: Colors.orange[800],
              child: SafeArea(
                bottom: false,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 6),
                  child: const Row(
                    children: [
                      Icon(Icons.wifi_off, color: Colors.white, size: 16),
                      SizedBox(width: 8),
                      Text(
                        'Offline — changes will sync when connected',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          Expanded(
            child: authState.when(
              loading: () => const SplashScreen(),
              error: (_, __) => const LoginScreen(),
              data: (user) =>
                  user != null ? const HomeScreen() : const LoginScreen(),
            ),
          ),
        ],
      ),
    );
  }
}
