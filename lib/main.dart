import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import 'package:cloud_firestore/cloud_firestore.dart';
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
        onGenerateRoute: _generateRoute,
      ),
    );
  }

  static Route<dynamic> _generateRoute(RouteSettings settings) {
    switch (settings.name) {
      case '/':
        return MaterialPageRoute(builder: (_) => const SplashScreen());
      case '/login':
        return MaterialPageRoute(builder: (_) => const LoginScreen());
      case '/verify-email':
        return MaterialPageRoute(builder: (_) => const VerifyEmailScreen());
      case '/register-form':
        return MaterialPageRoute(
          builder: (_) => const RegisterFormScreen(email: ''),
        );
      case '/admin':
        return _guardedRoute(
          builder: (_) => const AdminDashboard(),
          requiredRole: 'admin',
        );
      case '/admin/pending':
        return _guardedRoute(
          builder: (_) => const PendingApprovals(),
          requiredRole: 'admin',
        );
      case '/resident':
        return _guardedRoute(
          builder: (_) => const ResidentDashboard(),
          requiredRole: 'resident',
        );
      default:
        return MaterialPageRoute(builder: (_) => const _NotFoundScreen());
    }
  }

  static Route<dynamic> _guardedRoute({
    required WidgetBuilder builder,
    required String requiredRole,
  }) {
    return MaterialPageRoute(
      builder: (_) => _AuthGuard(
        requiredRole: requiredRole,
        child: Builder(builder: builder),
      ),
    );
  }
}

/// Auth guard that waits for Firebase to restore the session, then
/// checks the user's role in Firestore before allowing access.
class _AuthGuard extends StatefulWidget {
  final Widget child;
  final String requiredRole;

  const _AuthGuard({
    required this.child,
    required this.requiredRole,
  });

  @override
  State<_AuthGuard> createState() => _AuthGuardState();
}

class _AuthGuardState extends State<_AuthGuard> {
  bool _checked = false;
  bool _authorized = false;

  @override
  void initState() {
    super.initState();
    _checkAccess();
  }

  Future<void> _checkAccess() async {
    // Wait for Firebase Auth to restore the session (up to 2 seconds)
    User? user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      for (int i = 0; i < 20; i++) {
        await Future.delayed(const Duration(milliseconds: 100));
        user = FirebaseAuth.instance.currentUser;
        if (user != null) break;
      }
    }

    // Not signed in → login
    if (user == null) {
      _redirect('/login');
      return;
    }

    // Signed in — check role in Firestore
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (!doc.exists) {
        _redirect('/login');
        return;
      }

      final data = doc.data() as Map<String, dynamic>;
      final userType = data['userType'] as String?;
      final isApproved = data['isApproved'] as bool? ?? false;

      // Role mismatch → send to correct dashboard
      if (userType != widget.requiredRole) {
        final correctRoute = userType == 'admin' ? '/admin' : '/resident';
        _redirect(correctRoute);
        return;
      }

      // Resident must be approved
      if (widget.requiredRole == 'resident' && !isApproved) {
        await FirebaseAuth.instance.signOut();
        _redirect('/login');
        return;
      }

      // All checks passed
      if (!mounted) return;
      setState(() {
        _checked = true;
        _authorized = true;
      });
    } catch (e) {
      _redirect('/login');
    }
  }

  void _redirect(String route) {
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Navigator.of(context).pushNamedAndRemoveUntil(route, (r) => false);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_checked || !_authorized) {
      return const Scaffold(
        backgroundColor: Color(0xFFFFF8F0),
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFFC4A882)),
        ),
      );
    }
    return widget.child;
  }
}

class _NotFoundScreen extends StatelessWidget {
  const _NotFoundScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Not Found')),
      body: const Center(child: Text('Page not found')),
    );
  }
}