import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'firebase_options.dart';
import 'providers/auth_provider.dart';
import 'screens/splash_screen.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/verify_email_screen.dart';
import 'screens/auth/register_form_screen.dart';
import 'screens/admin/admin_dashboard.dart';
import 'screens/admin/pending_approvals.dart';
import 'screens/resident/resident_dashboard.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
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
          '/verify-email': (context) => const VerifyEmailScreen(),
          '/register-form': (context) => const RegisterFormScreen(email: ''),
          '/admin': (context) => const AdminDashboard(),
          '/admin/pending': (context) => const PendingApprovals(),
          '/resident': (context) => const ResidentDashboard(),
        },
      ),
    );
  }
}