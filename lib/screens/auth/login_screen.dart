import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isPasswordVisible = false;
  bool _isRegistering = false;
  bool _imageLoaded = true;

  final _regNameController = TextEditingController();
  final _regEmailController = TextEditingController();
  final _regPasswordController = TextEditingController();
  final _regConfirmPasswordController = TextEditingController();
  final _regHouseController = TextEditingController();
  final _regPhoneController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _checkImageAsset();
  }

  Future<void> _checkImageAsset() async {
    try {
      await rootBundle.load('assets/images/gate_background.jpg');
      setState(() {
        _imageLoaded = true;
      });
      print('✅ Background image loaded successfully');
    } catch (e) {
      print('❌ Background image not found: $e');
      setState(() {
        _imageLoaded = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          // Background image with LIGHT overlay (not dark)
          image: _imageLoaded
              ? const DecorationImage(
            image: AssetImage('assets/images/gate_background.jpg'),
            fit: BoxFit.cover,
            // REMOVED the dark colorFilter that was causing black background
            // OR use a lighter overlay:
            // colorFilter: ColorFilter.mode(
            //   Colors.white.withOpacity(0.1),
            //   BlendMode.lighten,
            // ),
          )
              : null,
          // Fallback gradient if image doesn't load
          gradient: !_imageLoaded
              ? LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              const Color(0xFFFFF8F0),
              const Color(0xFFF5F0E8),
              const Color(0xFFEDE5D8),
            ],
          )
              : null,
        ),
        child: Container(
          // Add a semi-transparent overlay for better text readability
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.3), // Light overlay, not dark
          ),
          child: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24.0),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: kIsWeb ? 500 : double.infinity,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Logo Section
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Color(0xFFC4A882),
                              Color(0xFFD4C4A8),
                            ],
                          ),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.2),
                              blurRadius: 15,
                              offset: const Offset(0, 5),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.home_work,
                          size: 50,
                          color: Color(0xFFFFF8F0),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Title
                      const Text(
                        'Florence Homes',
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFFFFF8F0),
                          letterSpacing: 1.5,
                          shadows: [
                            Shadow(
                              blurRadius: 10,
                              color: Colors.black,
                              offset: Offset(2, 2),
                            ),
                          ],
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),

                      // Subtitle
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.4),
                          borderRadius: BorderRadius.circular(30),
                        ),
                        child: const Text(
                          'Village Gate Access System',
                          style: TextStyle(
                            fontSize: 14,
                            color: Color(0xFFFFF8F0),
                            fontWeight: FontWeight.w500,
                            letterSpacing: 0.5,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      const SizedBox(height: 48),

                      // Form Card
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.95),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.15),
                              blurRadius: 20,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: const Color(0xFFE0D5C1),
                              width: 1,
                            ),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(32.0),
                            child: _isRegistering
                                ? _buildRegisterForm(authProvider)
                                : _buildLoginForm(authProvider),
                          ),
                        ),
                      ),

                      const SizedBox(height: 20),

                      // Toggle button
                      TextButton(
                        onPressed: () {
                          setState(() {
                            _isRegistering = !_isRegistering;
                          });
                        },
                        style: TextButton.styleFrom(
                          foregroundColor: const Color(0xFF5D4037),
                          backgroundColor: Colors.white.withOpacity(0.9),
                          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                        ),
                        child: Text(
                          _isRegistering
                              ? '← Back to Login'
                              : 'Create New Account',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLoginForm(AuthProvider authProvider) {
    return Form(
      key: _formKey,
      child: Column(
        children: [
          const Text(
            'Welcome Back',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Color(0xFF5D4037),
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Please enter your credentials to continue',
            style: TextStyle(
              color: Color(0xFF8D6E63),
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 32),

          TextFormField(
            controller: _emailController,
            decoration: InputDecoration(
              labelText: 'Email Address',
              labelStyle: const TextStyle(color: Color(0xFF8D6E63), fontWeight: FontWeight.w500),
              prefixIcon: const Icon(Icons.email_outlined, color: Color(0xFFC4A882), size: 22),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFE0D5C1)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFE0D5C1)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFC4A882), width: 2),
              ),
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            ),
            keyboardType: TextInputType.emailAddress,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter your email';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),

          TextFormField(
            controller: _passwordController,
            decoration: InputDecoration(
              labelText: 'Password',
              labelStyle: const TextStyle(color: Color(0xFF8D6E63), fontWeight: FontWeight.w500),
              prefixIcon: const Icon(Icons.lock_outline, color: Color(0xFFC4A882), size: 22),
              suffixIcon: IconButton(
                icon: Icon(
                  _isPasswordVisible
                      ? Icons.visibility
                      : Icons.visibility_off,
                  color: const Color(0xFFC4A882),
                  size: 20,
                ),
                onPressed: () {
                  setState(() {
                    _isPasswordVisible = !_isPasswordVisible;
                  });
                },
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFE0D5C1)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFE0D5C1)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFC4A882), width: 2),
              ),
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            ),
            obscureText: !_isPasswordVisible,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter your password';
              }
              return null;
            },
          ),

          const SizedBox(height: 32),

          if (authProvider.isLoading)
            const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFC4A882)),
              ),
            )
          else
            ElevatedButton(
              onPressed: () async {
                if (_formKey.currentState!.validate()) {
                  bool success = await authProvider.login(
                    _emailController.text,
                    _passwordController.text,
                  );

                  if (success) {
                    if (authProvider.isAdmin) {
                      Navigator.pushReplacementNamed(context, '/admin');
                    } else {
                      Navigator.pushReplacementNamed(context, '/resident');
                    }
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Invalid email or password'),
                        backgroundColor: Color(0xFFD32F2F),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
                backgroundColor: const Color(0xFFC4A882),
                foregroundColor: const Color(0xFFFFF8F0),
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                textStyle: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              ),
              child: const Text('Sign In'),
            ),
        ],
      ),
    );
  }

  Widget _buildRegisterForm(AuthProvider authProvider) {
    return Form(
      key: _formKey,
      child: Column(
        children: [
          const Text(
            'Create Account',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Color(0xFF5D4037),
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Register as a resident of Florence Homes',
            style: TextStyle(
              color: Color(0xFF8D6E63),
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 24),

          TextFormField(
            controller: _regNameController,
            decoration: InputDecoration(
              labelText: 'Full Name',
              labelStyle: const TextStyle(color: Color(0xFF8D6E63), fontWeight: FontWeight.w500),
              prefixIcon: const Icon(Icons.person_outline, color: Color(0xFFC4A882), size: 22),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFE0D5C1)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFE0D5C1)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFC4A882), width: 2),
              ),
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter your full name';
              }
              return null;
            },
          ),
          const SizedBox(height: 12),

          TextFormField(
            controller: _regEmailController,
            decoration: InputDecoration(
              labelText: 'Email Address',
              labelStyle: const TextStyle(color: Color(0xFF8D6E63), fontWeight: FontWeight.w500),
              prefixIcon: const Icon(Icons.email_outlined, color: Color(0xFFC4A882), size: 22),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFE0D5C1)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFE0D5C1)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFC4A882), width: 2),
              ),
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
            keyboardType: TextInputType.emailAddress,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter your email';
              }
              if (!value.contains('@')) {
                return 'Please enter a valid email';
              }
              return null;
            },
          ),
          const SizedBox(height: 12),

          TextFormField(
            controller: _regPasswordController,
            decoration: InputDecoration(
              labelText: 'Password',
              labelStyle: const TextStyle(color: Color(0xFF8D6E63), fontWeight: FontWeight.w500),
              prefixIcon: const Icon(Icons.lock_outline, color: Color(0xFFC4A882), size: 22),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFE0D5C1)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFE0D5C1)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFC4A882), width: 2),
              ),
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              helperText: 'Minimum 6 characters',
              helperStyle: const TextStyle(color: Color(0xFFB8A99A), fontSize: 11),
            ),
            obscureText: true,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter a password';
              }
              if (value.length < 6) {
                return 'Password must be at least 6 characters';
              }
              return null;
            },
          ),
          const SizedBox(height: 12),

          TextFormField(
            controller: _regConfirmPasswordController,
            decoration: InputDecoration(
              labelText: 'Confirm Password',
              labelStyle: const TextStyle(color: Color(0xFF8D6E63), fontWeight: FontWeight.w500),
              prefixIcon: const Icon(Icons.lock_outline, color: Color(0xFFC4A882), size: 22),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFE0D5C1)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFE0D5C1)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFC4A882), width: 2),
              ),
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
            obscureText: true,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please confirm your password';
              }
              if (value != _regPasswordController.text) {
                return 'Passwords do not match';
              }
              return null;
            },
          ),
          const SizedBox(height: 12),

          TextFormField(
            controller: _regHouseController,
            decoration: InputDecoration(
              labelText: 'House Number / Unit (Optional)',
              labelStyle: const TextStyle(color: Color(0xFF8D6E63), fontWeight: FontWeight.w500),
              prefixIcon: const Icon(Icons.home_outlined, color: Color(0xFFC4A882), size: 22),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFE0D5C1)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFE0D5C1)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFC4A882), width: 2),
              ),
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              hintText: 'e.g., Block A, Lot 12',
              hintStyle: const TextStyle(color: Color(0xFFD4C4A8), fontSize: 12),
            ),
          ),
          const SizedBox(height: 12),

          TextFormField(
            controller: _regPhoneController,
            decoration: InputDecoration(
              labelText: 'Phone Number (Optional)',
              labelStyle: const TextStyle(color: Color(0xFF8D6E63), fontWeight: FontWeight.w500),
              prefixIcon: const Icon(Icons.phone_outlined, color: Color(0xFFC4A882), size: 22),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFE0D5C1)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFE0D5C1)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFC4A882), width: 2),
              ),
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
            keyboardType: TextInputType.phone,
          ),
          const SizedBox(height: 24),

          if (authProvider.isLoading)
            const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFC4A882)),
              ),
            )
          else
            ElevatedButton(
              onPressed: () async {
                if (_formKey.currentState!.validate()) {
                  final result = await authProvider.register(
                    email: _regEmailController.text,
                    password: _regPasswordController.text,
                    fullName: _regNameController.text,
                    userType: 'resident',
                    houseNumber: _regHouseController.text.isNotEmpty
                        ? _regHouseController.text
                        : null,
                    phoneNumber: _regPhoneController.text.isNotEmpty
                        ? _regPhoneController.text
                        : null,
                  );

                  if (result['success']) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(result['message']),
                        backgroundColor: const Color(0xFF8D6E63),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );

                    setState(() {
                      _isRegistering = false;
                      _regNameController.clear();
                      _regEmailController.clear();
                      _regPasswordController.clear();
                      _regConfirmPasswordController.clear();
                      _regHouseController.clear();
                      _regPhoneController.clear();
                    });
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(result['message']),
                        backgroundColor: const Color(0xFFD32F2F),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
                backgroundColor: const Color(0xFFC4A882),
                foregroundColor: const Color(0xFFFFF8F0),
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                textStyle: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              ),
              child: const Text('Register'),
            ),
        ],
      ),
    );
  }
}