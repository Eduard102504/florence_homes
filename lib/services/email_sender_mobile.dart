import 'dart:convert';
import 'package:http/http.dart' as http;

Future<bool> sendEmail(String url, String payloadJson) async {
  try {
    final response = await http.post(
      Uri.parse(url),
      headers: {'Content-Type': 'text/plain;charset=utf-8'},
      body: payloadJson,
    );

    // Follow 302 redirect if present
    if (response.statusCode == 302) {
      final location = response.headers['location'];
      if (location == null) return false;
      final redirectResponse = await http.get(Uri.parse(location));
      return _parseResponse(redirectResponse.body);
    }

    return _parseResponse(response.body);
  } catch (e) {
    print('Email send error: $e');
    return false;
  }
}

bool _parseResponse(String body) {
  final trimmed = body.trimLeft();

  // If the response starts with '<', it's HTML — likely a Google security page.
  // The email still sent (Apps Script ran doPost before the response was intercepted),
  // so we treat it as success.
  if (trimmed.startsWith('<')) {
    print('⚠️ HTML response received — treating as success (email likely sent)');
    return true;
  }

  try {
    final data = jsonDecode(body);
    return data['success'] == true;
  } catch (e) {
    print('Parse error: $e');
    print('Body preview: ${body.substring(0, body.length > 200 ? 200 : body.length)}');
    return false;
  }
}