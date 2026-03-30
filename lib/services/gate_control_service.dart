// lib/services/gate_control_service.dart
import 'dart:io';
import 'package:http/http.dart' as http;
import 'dart:convert';

class GateControlService {
  static const String defaultGateIp = '192.168.1.100';
  static const int defaultGatePort = 8080;

  Future<bool> openGate({String? gateIp, int? port}) async {
    try {
      final ip = gateIp ?? defaultGateIp;
      final portNumber = port ?? defaultGatePort;

      final response = await http.post(
        Uri.parse('http://$ip:$portNumber/open'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'command': 'open',
          'timestamp': DateTime.now().toIso8601String(),
        }),
      ).timeout(const Duration(seconds: 5));

      return response.statusCode == 200;
    } catch (e) {
      print('Error opening gate: $e');
      return false;
    }
  }

  Future<bool> closeGate({String? gateIp, int? port}) async {
    try {
      final ip = gateIp ?? defaultGateIp;
      final portNumber = port ?? defaultGatePort;

      final response = await http.post(
        Uri.parse('http://$ip:$portNumber/close'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'command': 'close',
          'timestamp': DateTime.now().toIso8601String(),
        }),
      ).timeout(const Duration(seconds: 5));

      return response.statusCode == 200;
    } catch (e) {
      print('Error closing gate: $e');
      return false;
    }
  }

  Future<bool> getGateStatus({String? gateIp, int? port}) async {
    try {
      final ip = gateIp ?? defaultGateIp;
      final portNumber = port ?? defaultGatePort;

      final response = await http.get(
        Uri.parse('http://$ip:$portNumber/status'),
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['isOpen'] ?? false;
      }
      return false;
    } catch (e) {
      print('Error getting gate status: $e');
      return false;
    }
  }
}