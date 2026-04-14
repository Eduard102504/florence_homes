import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'firebase_options.dart';
import 'providers/auth_provider.dart';
import 'providers/gate_provider.dart';
import 'screens/splash_screen.dart';
import 'screens/auth/login_screen.dart';
import 'screens/admin/admin_dashboard.dart';
import 'screens/resident/resident_dashboard.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // SAFEGUARD - CHECK IF ALREADY INITIALIZED
  FirebaseApp? app;
  try {
    app = Firebase.app();
    print('Using existing Firebase app');
  } catch (e) {
    print('No existing Firebase app, initializing...');
    app = await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => GateProvider()),
      ],
      child: MaterialApp(
        title: 'Florence Homes',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          primarySwatch: Colors.green,
          useMaterial3: true,
        ),
        initialRoute: '/',
        routes: {
          '/': (context) => const SplashScreen(),
          '/login': (context) => const LoginScreen(),
          '/admin': (context) => const AdminDashboard(),
          '/resident': (context) => const ResidentDashboard(),
        },
      ),
    );
  }
}