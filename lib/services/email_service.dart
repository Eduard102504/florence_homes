import 'dart:convert';

// Conditional import selects the correct sender per platform
import 'email_sender_stub.dart'
if (dart.library.io) 'email_sender_mobile.dart'
if (dart.library.js_interop) 'email_sender_web.dart' as sender;

class EmailService {
  static const String scriptUrl =
      'https://script.google.com/macros/s/AKfycbzCyALyKhB9bSfBEXPIJKuWeYNYxKHGfkeuBwHqYWLtQVwCQZxp57N0IE8oOmcFO_b-Pg/exec';

  static Future<bool> sendVerificationCode(String toEmail, String code) async {
    final success = await _send(
      toEmail: toEmail,
      subject: '🔐 Your Verification Code - Florence Homes',
      htmlBody: _buildVerificationEmailTemplate(code),
    );
    print(success ? '✅ OTP sent to $toEmail' : '❌ Failed to send OTP to $toEmail');
    return success;
  }

  static Future<bool> sendApprovalEmail(String toEmail, String fullName) async {
    final success = await _send(
      toEmail: toEmail,
      subject: '✅ Account Approved - Welcome to Florence Homes!',
      htmlBody: _buildApprovalEmailTemplate(fullName),
    );
    print(success ? '✅ Approval email sent to $toEmail' : '❌ Failed to send approval email to $toEmail');
    return success;
  }

  static Future<bool> sendRejectionEmail(
      String toEmail, String fullName, String? reason) async {
    final success = await _send(
      toEmail: toEmail,
      subject: '❌ Account Update - Florence Homes',
      htmlBody: _buildRejectionEmailTemplate(fullName, reason),
    );
    print(success ? '✅ Rejection email sent to $toEmail' : '❌ Failed to send rejection email to $toEmail');
    return success;
  }

  static Future<bool> _send({
    required String toEmail,
    required String subject,
    required String htmlBody,
  }) async {
    final payload = jsonEncode({
      'to': toEmail,
      'subject': subject,
      'htmlBody': htmlBody,
    });
    return sender.sendEmail(scriptUrl, payload);
  }

  // ---- Templates ----

  static String _buildVerificationEmailTemplate(String code) {
    return '''
      <!DOCTYPE html>
      <html>
      <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <style>
          body { font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; margin: 0; padding: 0; background-color: #FFF8F0; }
          .container { max-width: 600px; margin: 20px auto; background: white; border-radius: 20px; overflow: hidden; box-shadow: 0 4px 15px rgba(0,0,0,0.1); }
          .header { background: linear-gradient(135deg, #C4A882 0%, #D4C4A8 100%); padding: 30px; text-align: center; }
          .logo { font-size: 48px; margin-bottom: 10px; }
          .title { color: #FFF8F0; font-size: 28px; font-weight: bold; margin: 0; }
          .subtitle { color: #FFF8F0; font-size: 14px; margin-top: 8px; opacity: 0.9; }
          .content { padding: 40px 30px; background: white; }
          .greeting { color: #5D4037; font-size: 18px; margin-bottom: 20px; }
          .message { color: #6B5B4F; font-size: 14px; line-height: 1.6; margin-bottom: 30px; }
          .code-container { background: #FFF8F0; border: 2px solid #D4C4A8; border-radius: 12px; padding: 20px; text-align: center; margin: 20px 0; }
          .verification-code { font-size: 36px; font-weight: bold; letter-spacing: 8px; color: #C4A882; font-family: monospace; }
          .note { font-size: 12px; color: #B8A99A; text-align: center; margin-top: 20px; }
          .footer { background: #F5F0E8; padding: 20px; text-align: center; border-top: 1px solid #E0D5C1; }
          .footer-text { color: #8D6E63; font-size: 12px; margin: 0; }
        </style>
      </head>
      <body>
        <div class="container">
          <div class="header">
            <div class="logo">🏠</div>
            <h1 class="title">Florence Homes</h1>
            <p class="subtitle">Village Gate Access System</p>
          </div>
          <div class="content">
            <div class="greeting">Hello!</div>
            <div class="message">Your verification code for Florence Homes is:</div>
            <div class="code-container">
              <div class="verification-code">$code</div>
            </div>
            <div class="message">This code will expire in <strong>10 minutes</strong>.</div>
            <div class="note">If you didn't request this code, please ignore this email.</div>
          </div>
          <div class="footer">
            <p class="footer-text">© 2024 Florence Homes. All rights reserved.</p>
            <p class="footer-text">Secure access to your village community</p>
          </div>
        </div>
      </body>
      </html>
    ''';
  }

  static String _buildApprovalEmailTemplate(String fullName) {
    return '''
      <!DOCTYPE html>
      <html>
      <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <style>
          body { font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; margin: 0; padding: 0; background-color: #FFF8F0; }
          .container { max-width: 600px; margin: 20px auto; background: white; border-radius: 20px; overflow: hidden; box-shadow: 0 4px 15px rgba(0,0,0,0.1); }
          .header { background: linear-gradient(135deg, #C4A882 0%, #D4C4A8 100%); padding: 30px; text-align: center; }
          .success-icon { font-size: 64px; margin-bottom: 10px; }
          .title { color: #FFF8F0; font-size: 28px; font-weight: bold; margin: 0; }
          .content { padding: 40px 30px; background: white; }
          .greeting { color: #5D4037; font-size: 20px; font-weight: bold; margin-bottom: 20px; }
          .message { color: #6B5B4F; font-size: 14px; line-height: 1.6; margin-bottom: 20px; }
          .footer { background: #F5F0E8; padding: 20px; text-align: center; border-top: 1px solid #E0D5C1; }
          .footer-text { color: #8D6E63; font-size: 12px; margin: 0; }
        </style>
      </head>
      <body>
        <div class="container">
          <div class="header">
            <div class="success-icon">✅</div>
            <h1 class="title">Welcome to Florence Homes!</h1>
          </div>
          <div class="content">
            <div class="greeting">Dear $fullName,</div>
            <div class="message">
              Congratulations! Your account has been <strong>approved</strong> by the administration.
              You can now log in to the Florence Homes app and start using all features.
            </div>
          </div>
          <div class="footer">
            <p class="footer-text">© 2024 Florence Homes. All rights reserved.</p>
          </div>
        </div>
      </body>
      </html>
    ''';
  }

  static String _buildRejectionEmailTemplate(String fullName, String? reason) {
    return '''
      <!DOCTYPE html>
      <html>
      <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <style>
          body { font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; margin: 0; padding: 0; background-color: #FFF8F0; }
          .container { max-width: 600px; margin: 20px auto; background: white; border-radius: 20px; overflow: hidden; box-shadow: 0 4px 15px rgba(0,0,0,0.1); }
          .header { background: linear-gradient(135deg, #C4A882 0%, #D4C4A8 100%); padding: 30px; text-align: center; }
          .error-icon { font-size: 64px; margin-bottom: 10px; }
          .title { color: #FFF8F0; font-size: 28px; font-weight: bold; margin: 0; }
          .content { padding: 40px 30px; background: white; }
          .greeting { color: #5D4037; font-size: 20px; font-weight: bold; margin-bottom: 20px; }
          .message { color: #6B5B4F; font-size: 14px; line-height: 1.6; margin-bottom: 20px; }
          .footer { background: #F5F0E8; padding: 20px; text-align: center; border-top: 1px solid #E0D5C1; }
          .footer-text { color: #8D6E63; font-size: 12px; margin: 0; }
        </style>
      </head>
      <body>
        <div class="container">
          <div class="header">
            <div class="error-icon">❌</div>
            <h1 class="title">Application Status Update</h1>
          </div>
          <div class="content">
            <div class="greeting">Dear $fullName,</div>
            <div class="message">
              Thank you for your interest in Florence Homes. After careful review, your registration could not be approved at this time.
            </div>
            ${reason != null && reason.isNotEmpty ? '''
            <div class="message">
              <strong>Reason:</strong> $reason
            </div>
            ''' : ''}
          </div>
          <div class="footer">
            <p class="footer-text">© 2024 Florence Homes. All rights reserved.</p>
          </div>
        </div>
      </body>
      </html>
    ''';
  }
}