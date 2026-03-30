import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import 'generate_visitor_qr.dart';
import 'gate_history.dart';
import 'my_qr_codes.dart';

class ResidentDashboard extends StatelessWidget {
  const ResidentDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Florence Homes'),
        backgroundColor: Colors.green,
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
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Card(
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  children: [
                    const Icon(Icons.home, size: 60, color: Colors.green),
                    const SizedBox(height: 10),
                    Text(
                      'Welcome, ${authProvider.currentUser?.fullName ?? 'Resident'}!',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    if (authProvider.currentUser?.houseNumber != null)
                      Text(
                        'House: ${authProvider.currentUser?.houseNumber}',
                        style: const TextStyle(color: Colors.grey),
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
                          fontWeight: FontWeight.w500,
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
            ),
            const SizedBox(height: 20),
            Expanded(
              child: GridView.count(
                crossAxisCount: 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                children: [
                  _buildMenuCard(
                    context,
                    title: 'Generate Visitor QR',
                    icon: Icons.qr_code,
                    color: Colors.blue,
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
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const MyQRCodes()),
                      );
                    },
                  ),
                  _buildMenuCard(
                    context,
                    title: 'Register RFID',
                    icon: Icons.nfc,
                    color: Colors.green,
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Please contact admin to register RFID'),
                          backgroundColor: Colors.orange,
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuCard(BuildContext context, {
    required String title,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 4,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 40, color: color),
              const SizedBox(height: 8),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ),
      ),
    );
  }
}