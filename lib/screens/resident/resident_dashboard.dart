flutimport 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../../providers/auth_provider.dart';
import '../../widgets/responsive_wrapper.dart';
import 'generate_visitor_qr.dart';
import 'gate_history.dart';
import 'my_qr_codes.dart';

class ResidentDashboard extends StatelessWidget {
  const ResidentDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final screenWidth = MediaQuery.of(context).size.width;

    int crossAxisCount = 2;
    if (kIsWeb) {
      if (screenWidth > 1000) {
        crossAxisCount = 4;
      } else if (screenWidth > 700) {
        crossAxisCount = 3;
      } else {
        crossAxisCount = 2;
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Florence Homes'),
        backgroundColor: Colors.green,
        centerTitle: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await authProvider.logout();
              Navigator.pushReplacementNamed(context, '/login');
            },
          ),
        ],
      ),
      body: ResponsiveWrapper(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              // Welcome Card
              Card(
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.green.shade100,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.home, size: 40, color: Colors.green),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Welcome, ${authProvider.currentUser?.fullName ?? 'Resident'}!',
                              style: TextStyle(
                                fontSize: kIsWeb ? 20 : 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            if (authProvider.currentUser?.houseNumber != null)
                              Text(
                                'House: ${authProvider.currentUser?.houseNumber}',
                                style: TextStyle(color: Colors.grey.shade600),
                              ),
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                              decoration: BoxDecoration(
                                color: authProvider.currentUser?.isApproved == true
                                    ? Colors.green.shade100
                                    : Colors.orange.shade100,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                authProvider.currentUser?.isApproved == true
                                    ? '✓ Account Approved'
                                    : '⏳ Pending Approval',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: authProvider.currentUser?.isApproved == true
                                      ? Colors.green.shade800
                                      : Colors.orange.shade800,
                                ),
                              ),
                            ),
                            if (authProvider.currentUser?.rfidTag != null)
                              Container(
                                margin: const EdgeInsets.only(top: 8),
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.purple.shade100,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  '✓ RFID Registered',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.purple.shade800,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Menu Grid
              Expanded(
                child: GridView.count(
                  crossAxisCount: crossAxisCount,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  childAspectRatio: kIsWeb ? 1.2 : 1,
                  children: [
                    _buildMenuCard(
                      context,
                      title: 'Gate Scanner',
                      icon: Icons.scanner,
                      color: Colors.green,
                      description: 'Scan RFID for gate access',
                      onTap: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Use mobile app for NFC scanning')),
                        );
                      },
                    ),
                    _buildMenuCard(
                      context,
                      title: 'Generate Visitor QR',
                      icon: Icons.qr_code,
                      color: Colors.blue,
                      description: 'Create visitor QR codes',
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const GenerateVisitorQR()),
                        );
                      },
                    ),
                    _buildMenuCard(
                      context,
                      title: 'Gate History',
                      icon: Icons.history,
                      color: Colors.orange,
                      description: 'View your gate entries',
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const GateHistory()),
                        );
                      },
                    ),
                    _buildMenuCard(
                      context,
                      title: 'My QR Codes',
                      icon: Icons.qr_code_scanner,
                      color: Colors.purple,
                      description: 'View your QR codes',
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const MyQRCodes()),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMenuCard(BuildContext context, {
    required String title,
    required IconData icon,
    required Color color,
    required String description,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, size: 40, color: color),
              ),
              const SizedBox(height: 16),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                description,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}