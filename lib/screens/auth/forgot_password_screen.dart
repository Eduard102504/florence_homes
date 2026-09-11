import 'package:flutter/material.dart';
import '../../services/auth_service.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final AuthService _authService = AuthService();
  final _emailController = TextEditingController();
  final _codeController = TextEditingController();

  int _step = 1; // 1: Email, 2: Code
  String? _email;
  bool _isLoading = false;
  String? _errorMessage;
  int _resendCooldown = 0;

  @override
  void initState() {
    super.initState();
    _startResendTimer();
  }

  void _startResendTimer() {
    Future.delayed(const Duration(seconds: 1), () {
      if (_resendCooldown > 0 && mounted) {
        setState(() {
          _resendCooldown--;
        });
        _startResendTimer();
      }
    });
  }

  Future<void> _sendResetCode() async {
    if (_emailController.text.isEmpty) {
      setState(() {
        _errorMessage = 'Please enter your email';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final result = await _authService.sendPasswordResetCode(_emailController.text.trim());

    setState(() {
      _isLoading = false;
    });

    if (result['success']) {
      setState(() {
        _email = _emailController.text.trim();
        _step = 2;
        _resendCooldown = 60;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['message']),
          backgroundColor: const Color(0xFF8D6E63),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 5),
        ),
      );
    } else {
      setState(() {
        _errorMessage = result['message'];
      });
    }
  }

  Future<void> _resendCode() async {
    if (_resendCooldown > 0) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final result = await _authService.sendPasswordResetCode(_email!);

    setState(() {
      _isLoading = false;
    });

    if (result['success']) {
      setState(() {
        _resendCooldown = 60;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['message']),
          backgroundColor: const Color(0xFF8D6E63),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 5),
        ),
      );
    } else {
      setState(() {
        _errorMessage = result['message'];
      });
    }
  }

  Future<void> _verifyCode() async {
    if (_codeController.text.length != 6) {
      setState(() {
        _errorMessage = 'Please enter the 6-digit code';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final result = await _authService.verifyResetCode(_email!, _codeController.text);

    setState(() {
      _isLoading = false;
    });

    if (result['success']) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['message']),
          backgroundColor: const Color(0xFF8D6E63),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 5),
        ),
      );

      // Go back to login after 3 seconds
      Future.delayed(const Duration(seconds: 3), () {
        Navigator.pop(context);
      });
    } else {
      setState(() {
        _errorMessage = result['message'];
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              const Color(0xFFD4C4A8),
              const Color(0xFFC4A882),
              const Color(0xFFB8A99A),
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.all(24.0),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 500),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFD4C4A8).withOpacity(0.3),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: const Color(0xFFE0D5C1),
                        width: 1.5,
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(32.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Icon
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  const Color(0xFFD4C4A8),
                                  const Color(0xFFC4A882),
                                ],
                              ),
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFFD4C4A8).withOpacity(0.3),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Icon(
                              _step == 1 ? Icons.lock_reset : Icons.pin,
                              size: 50,
                              color: const Color(0xFFFFF8F0),
                            ),
                          ),
                          const SizedBox(height: 24),

                          // Title
                          Text(
                            _step == 1 ? 'Reset Password' : 'Enter Verification Code',
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF6B5B4F),
                              letterSpacing: 0.5,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _step == 1
                                ? 'Enter your email to receive a verification code'
                                : 'Enter the 6-digit code sent to your email',
                            style: const TextStyle(
                              color: Color(0xFFB8A99A),
                              fontSize: 13,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 32),

                          // Error Message
                          if (_errorMessage != null)
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFFD32F2F).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: const Color(0xFFD32F2F).withOpacity(0.3),
                                ),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.error, color: Color(0xFFD32F2F), size: 20),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      _errorMessage!,
                                      style: const TextStyle(color: Color(0xFFD32F2F), fontSize: 13),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                          if (_errorMessage != null) const SizedBox(height: 16),

                          // Step 1: Email Form
                          if (_step == 1) ...[
                            TextFormField(
                              controller: _emailController,
                              decoration: InputDecoration(
                                labelText: 'Email Address',
                                labelStyle: const TextStyle(color: Color(0xFFB8A99A), fontWeight: FontWeight.w500),
                                prefixIcon: const Icon(Icons.email_outlined, color: Color(0xFFD4C4A8), size: 22),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: const BorderSide(color: Color(0xFFE0D5C1)),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: const BorderSide(color: Color(0xFFE0D5C1)),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: const BorderSide(color: Color(0xFFD4C4A8), width: 2),
                                ),
                                filled: true,
                                fillColor: const Color(0xFFFFF8F0),
                                hintText: 'your@email.com',
                                hintStyle: const TextStyle(color: Color(0xFFD4C4A8), fontSize: 13),
                              ),
                              keyboardType: TextInputType.emailAddress,
                            ),
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFF3E0),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: const Color(0xFFFFE0B2),
                                  width: 1,
                                ),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.info_outline, size: 16, color: Color(0xFFE6A500)),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Check your spam folder if you don\'t see the email',
                                      style: const TextStyle(fontSize: 11, color: Color(0xFFA87900)),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 24),

                            if (_isLoading)
                              const Center(
                                child: CircularProgressIndicator(
                                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFD4C4A8)),
                                ),
                              )
                            else
                              ElevatedButton(
                                onPressed: _sendResetCode,
                                style: ElevatedButton.styleFrom(
                                  minimumSize: const Size(double.infinity, 52),
                                  backgroundColor: const Color(0xFFD4C4A8),
                                  foregroundColor: const Color(0xFF6B5B4F),
                                  elevation: 2,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  textStyle: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                child: const Text('Send Reset Code'),
                              ),
                          ],

                          // Step 2: Code Verification
                          if (_step == 2) ...[
                            TextFormField(
                              controller: _codeController,
                              decoration: InputDecoration(
                                labelText: 'Verification Code',
                                labelStyle: const TextStyle(color: Color(0xFFB8A99A), fontWeight: FontWeight.w500),
                                prefixIcon: const Icon(Icons.pin, color: Color(0xFFD4C4A8), size: 22),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: const BorderSide(color: Color(0xFFE0D5C1)),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: const BorderSide(color: Color(0xFFE0D5C1)),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: const BorderSide(color: Color(0xFFD4C4A8), width: 2),
                                ),
                                filled: true,
                                fillColor: const Color(0xFFFFF8F0),
                                hintText: 'Enter 6-digit code',
                                hintStyle: const TextStyle(color: Color(0xFFD4C4A8), fontSize: 13),
                              ),
                              keyboardType: TextInputType.number,
                              maxLength: 6,
                            ),
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFF3E0),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: const Color(0xFFFFE0B2),
                                  width: 1,
                                ),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.info_outline, size: 16, color: Color(0xFFE6A500)),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'After verification, you will receive a password reset link in your email',
                                      style: const TextStyle(fontSize: 11, color: Color(0xFFA87900)),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                TextButton(
                                  onPressed: _resendCooldown > 0 ? null : _resendCode,
                                  style: TextButton.styleFrom(
                                    foregroundColor: const Color(0xFF8D6E63),
                                  ),
                                  child: Text(
                                    _resendCooldown > 0
                                        ? 'Resend code in ${_resendCooldown}s'
                                        : 'Resend Code',
                                    style: const TextStyle(fontSize: 13),
                                  ),
                                ),
                                TextButton(
                                  onPressed: () {
                                    setState(() {
                                      _step = 1;
                                      _errorMessage = null;
                                    });
                                  },
                                  style: TextButton.styleFrom(
                                    foregroundColor: const Color(0xFF8D6E63),
                                  ),
                                  child: const Text('Back', style: TextStyle(fontSize: 13)),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),

                            if (_isLoading)
                              const Center(
                                child: CircularProgressIndicator(
                                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFD4C4A8)),
                                ),
                              )
                            else
                              ElevatedButton(
                                onPressed: _verifyCode,
                                style: ElevatedButton.styleFrom(
                                  minimumSize: const Size(double.infinity, 52),
                                  backgroundColor: const Color(0xFFD4C4A8),
                                  foregroundColor: const Color(0xFF6B5B4F),
                                  elevation: 2,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  textStyle: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                child: const Text('Verify Code'),
                              ),
                          ],

                          const SizedBox(height: 16),

                          // Back to Login
                          TextButton(
                            onPressed: () {
                              Navigator.pop(context);
                            },
                            style: TextButton.styleFrom(
                              foregroundColor: const Color(0xFFD4C4A8),
                            ),
                            child: const Text(
                              '← Back to Login',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
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
        ),
      ),
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _codeController.dispose();
    super.dispose();
  }
}