import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';

import 'firebase_options.dart';
import 'providers/role_provider.dart';
import 'providers/cart_provider.dart';
import 'screens/customer/customer_home_screen.dart';
import 'screens/delivery/delivery_home_screen.dart';
import 'screens/retailer/retailer_home_screen.dart';
import 'screens/role_select_screen.dart';
import 'screens/admin/admin_screen.dart';


// ── App entry point ───────────────────────────────────────────────────────────

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => RoleProvider()),
        ChangeNotifierProvider(create: (_) => CartProvider()),
      ],
      child: const NearFindApp(),
    ),
  );
}

class NearFindApp extends StatelessWidget {
  const NearFindApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'NearFind',
      debugShowCheckedModeBanner: false,

      // ── Material 3 theming ─────────────────────────────────────────
      theme: ThemeData(
        colorSchemeSeed: const Color(0xFF6750A4), // deep purple
        useMaterial3: true,
        brightness: Brightness.light,
      ),
      darkTheme: ThemeData(
        colorSchemeSeed: const Color(0xFF6750A4),
        useMaterial3: true,
        brightness: Brightness.dark,
      ),

      // ── Routing ────────────────────────────────────────────────────
      initialRoute: '/role-select',
      routes: {
        '/role-select': (_) => const RoleSelectScreen(),
        '/customer': (_) => const CustomerHomeScreen(),
        '/retailer': (_) => const RetailerHomeScreen(),
        '/delivery': (_) => const DeliveryHomeScreen(),
        '/admin': (_) => const AdminScreen(),
      },
    );
  }
}
