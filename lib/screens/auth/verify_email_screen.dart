import 'package:flutter/material.dart';
import '../../services/email_service.dart';
import 'register_form_screen.dart';

class VerifyEmailScreen extends StatefulWidget {
  const VerifyEmailScreen({super.key});

  @override
  State<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends State<VerifyEmailScreen> {
  final TextEditingController _emailController = TextEditingController();
  final List<TextEditingController> _codeControllers = List.generate(6, (index) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(6, (index) => FocusNode());

  bool _isSendingCode = false;
  bool _isVerifying = false;
  bool _codeSent = false;
  String _verificationCode = '';
  int _timeLeft = 0;
  bool _canResend = false;

  @override
  void dispose() {
    _emailController.dispose();
    for (var controller in _codeControllers) {
      controller.dispose();
    }
    for (var focusNode in _focusNodes) {
      focusNode.dispose();
    }
    super.dispose();
  }

  void _startTimer() {
    _timeLeft = 600; // 10 minutes
    _canResend = false;

    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 1));
      if (mounted) {
        setState(() {
          if (_timeLeft > 0) {
            _timeLeft--;
          } else {
            _canResend = true;
          }
        });
      }
      return _timeLeft > 0 && mounted;
    });
  }

  String _getFormattedTime() {
    int minutes = _timeLeft ~/ 60;
    int seconds = _timeLeft % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  Future<void> _sendVerificationCode() async {
    if (_emailController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter your email address'),
          backgroundColor: Color(0xFFD32F2F),
        ),
      );
      return;
    }

    if (!_emailController.text.contains('@') || !_emailController.text.contains('.')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid email address'),
          backgroundColor: Color(0xFFD32F2F),
        ),
      );
      return;
    }

    setState(() {
      _isSendingCode = true;
    });

    try {
      // Generate 6-digit verification code
      _verificationCode = (100000 + DateTime.now().millisecondsSinceEpoch % 900000).toString();

      // Send verification email
      bool emailSent = await EmailService.sendVerificationCode(
        _emailController.text.trim(),
        _verificationCode,
      );

      if (emailSent) {
        setState(() {
          _codeSent = true;
          _isSendingCode = false;
        });
        _startTimer();

        // Clear any existing code inputs
        for (var controller in _codeControllers) {
          controller.clear();
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Verification code sent to ${_emailController.text}'),
            backgroundColor: const Color(0xFF8D6E63),
          ),
        );
      } else {
        setState(() {
          _isSendingCode = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to send verification code. Please try again.'),
            backgroundColor: Color(0xFFD32F2F),
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isSendingCode = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: const Color(0xFFD32F2F),
        ),
      );
    }
  }

  Future<void> _resendCode() async {
    if (!_canResend) return;

    setState(() {
      _isSendingCode = true;
    });

    try {
      // Generate new code
      _verificationCode = (100000 + DateTime.now().millisecondsSinceEpoch % 900000).toString();

      bool emailSent = await EmailService.sendVerificationCode(
        _emailController.text.trim(),
        _verificationCode,
      );

      if (emailSent) {
        setState(() {
          _isSendingCode = false;
          _timeLeft = 600;
          _canResend = false;
        });

        // Clear code inputs
        for (var controller in _codeControllers) {
          controller.clear();
        }

        _startTimer();

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('New verification code sent!'),
            backgroundColor: Color(0xFF8D6E63),
          ),
        );
      } else {
        setState(() {
          _isSendingCode = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to resend code. Please try again.'),
            backgroundColor: Color(0xFFD32F2F),
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isSendingCode = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: const Color(0xFFD32F2F),
        ),
      );
    }
  }

  Future<void> _verifyCode() async {
    String enteredCode = _codeControllers.map((c) => c.text).join();

    if (enteredCode.length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter the 6-digit verification code'),
          backgroundColor: Color(0xFFD32F2F),
        ),
      );
      return;
    }

    if (enteredCode != _verificationCode) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Invalid verification code. Please try again.'),
          backgroundColor: Color(0xFFD32F2F),
        ),
      );
      return;
    }

    setState(() {
      _isVerifying = true;
    });

    // Email verified successfully - navigate to registration form
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => RegisterFormScreen(
            email: _emailController.text.trim(),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFFFF8F0),
              Color(0xFFF5F0E8),
              Color(0xFFEDE5D8),
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 500),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Back Button
                    Align(
                      alignment: Alignment.centerLeft,
                      child: IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.9),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 5,
                              ),
                            ],
                          ),
                          child: const Icon(Icons.arrow_back, color: Color(0xFFC4A882)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Icon
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [Color(0xFFC4A882), Color(0xFFD4C4A8)],
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
                      child: Icon(
                        _codeSent ? Icons.mark_email_read : Icons.email,
                        size: 50,
                        color: const Color(0xFFFFF8F0),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Title
                    Text(
                      _codeSent ? 'Verify Your Email' : 'Enter Your Email',
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF5D4037),
                        letterSpacing: 1.5,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),

                    if (!_codeSent) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFC4A882).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(30),
                        ),
                        child: const Text(
                          'We\'ll send a verification code to your email address',
                          style: TextStyle(
                            fontSize: 14,
                            color: Color(0xFF8D6E63),
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      const SizedBox(height: 12),
                      // SPAM WARNING - BEFORE SENDING CODE
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF3E0),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFFFE0B2), width: 1),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.info_outline, size: 18, color: Color(0xFFE6A500)),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'If you don\'t see the email in your inbox, please check your spam or junk folder.',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFFA87900),
                                  height: 1.3,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 32),

                      // Email Input Card
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 20,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
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
                                hintText: 'Enter your email address',
                              ),
                              keyboardType: TextInputType.emailAddress,
                            ),
                            const SizedBox(height: 24),

                            _isSendingCode
                                ? const Center(
                              child: CircularProgressIndicator(
                                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFC4A882)),
                              ),
                            )
                                : ElevatedButton(
                              onPressed: _sendVerificationCode,
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
                              child: const Text('Send Verification Code'),
                            ),
                          ],
                        ),
                      ),
                    ],

                    if (_codeSent) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFC4A882).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(30),
                        ),
                        child: Column(
                          children: [
                            const Text(
                              'We sent a verification code to',
                              style: TextStyle(
                                fontSize: 14,
                                color: Color(0xFF8D6E63),
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _emailController.text,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFFC4A882),
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      // SPAM WARNING - AFTER SENDING CODE
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF3E0),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFFFE0B2), width: 1),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.info_outline, size: 18, color: Color(0xFFE6A500)),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Please check your inbox. If you don\'t see the email within a few minutes, kindly check your spam or junk folder.',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFFA87900),
                                  height: 1.3,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 32),

                      // Verification Code Input Card
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 20,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            const Text(
                              'Enter Verification Code',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF5D4037),
                              ),
                            ),
                            const SizedBox(height: 20),
                            // Fixed: Wrapped Row in a SingleChildScrollView to prevent overflow
                            SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: List.generate(6, (index) {
                                  return Container(
                                    width: 50,
                                    margin: const EdgeInsets.symmetric(horizontal: 4),
                                    child: TextFormField(
                                      controller: _codeControllers[index],
                                      focusNode: _focusNodes[index],
                                      textAlign: TextAlign.center,
                                      keyboardType: TextInputType.number,
                                      maxLength: 1,
                                      style: const TextStyle(
                                        fontSize: 24,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFFC4A882),
                                      ),
                                      decoration: InputDecoration(
                                        counterText: '',
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
                                      ),
                                      onChanged: (value) {
                                        if (value.isNotEmpty && index < 5) {
                                          FocusScope.of(context).nextFocus();
                                        } else if (value.isEmpty && index > 0) {
                                          FocusScope.of(context).previousFocus();
                                        }
                                      },
                                    ),
                                  );
                                }),
                              ),
                            ),
                            const SizedBox(height: 24),

                            // Timer
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.timer, size: 16, color: Color(0xFFC4A882)),
                                const SizedBox(width: 8),
                                Text(
                                  'Code expires in: ${_getFormattedTime()}',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: Color(0xFF8D6E63),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),

                            // Resend Button
                            TextButton(
                              onPressed: _canResend && !_isSendingCode ? _resendCode : null,
                              style: TextButton.styleFrom(
                                foregroundColor: _canResend && !_isSendingCode ? const Color(0xFFC4A882) : const Color(0xFFB8A99A),
                              ),
                              child: const Text('Resend Verification Code'),
                            ),
                            const SizedBox(height: 24),

                            // Verify Button
                            _isVerifying
                                ? const Center(
                              child: CircularProgressIndicator(
                                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFC4A882)),
                              ),
                            )
                                : ElevatedButton(
                              onPressed: _verifyCode,
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
                              child: const Text('Verify & Continue'),
                            ),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 20),

                    // Back to Login
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      style: TextButton.styleFrom(
                        foregroundColor: const Color(0xFF5D4037),
                        backgroundColor: Colors.white.withOpacity(0.9),
                        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                      ),
                      child: const Text(
                        '← Back to Login',
                        style: TextStyle(
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
    );
  }
}