// lib/services/email_service.dart
import 'package:http/http.dart' as http;
import 'dart:convert';

class EmailService {
  // You'll need to set up an email service like SendGrid, Mailgun, or your own SMTP server
  final String apiKey = 'YOUR_EMAIL_API_KEY';
  final String fromEmail = 'noreply@florencehomes.com';

  Future<bool> sendApprovalEmail(String toEmail, String fullName) async {
    try {
      // Example using SendGrid API
      final response = await http.post(
        Uri.parse('https://api.sendgrid.com/v3/mail/send'),
        headers: {
          'Authorization': 'Bearer $apiKey',
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'personalizations': [
            {
              'to': [{'email': toEmail}],
              'dynamic_template_data': {
                'name': fullName,
                'welcome_message': 'Welcome to Florence Homes Village!',
              }
            }
          ],
          'from': {'email': fromEmail},
          'template_id': 'YOUR_WELCOME_TEMPLATE_ID',
        }),
      );

      return response.statusCode == 202;
    } catch (e) {
      print('Error sending email: $e');
      return false;
    }
  }

  Future<bool> sendRejectionEmail(String toEmail, String fullName, String reason) async {
    try {
      // Send rejection email
      final response = await http.post(
        Uri.parse('https://api.sendgrid.com/v3/mail/send'),
        headers: {
          'Authorization': 'Bearer $apiKey',
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'personalizations': [
            {
              'to': [{'email': toEmail}],
              'dynamic_template_data': {
                'name': fullName,
                'reason': reason,
              }
            }
          ],
          'from': {'email': fromEmail},
          'template_id': 'YOUR_REJECTION_TEMPLATE_ID',
        }),
      );

      return response.statusCode == 202;
    } catch (e) {
      print('Error sending rejection email: $e');
      return false;
    }
  }
}
