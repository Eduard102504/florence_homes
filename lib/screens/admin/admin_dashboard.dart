import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import 'manage_residents.dart';
import 'gate_entries_history.dart';
import 'pending_approvals.dart';
import 'manual_entry_screen.dart';
import 'scanner_management_screen.dart';

class AdminDashboard extends StatelessWidget {
  const AdminDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
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
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  children: [
                    const Icon(Icons.admin_panel_settings, size: 60, color: Colors.green),
                    const SizedBox(height: 10),
                    Text(
                      'Welcome, ${authProvider.currentUser?.fullName ?? 'Admin'}!',
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    const Text('Manage residents, gate access, and view reports'),
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
                    title: 'Manage Residents',
                    icon: Icons.people,
                    color: Colors.blue,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const ManageResidents()),
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
                        MaterialPageRoute(builder: (context) => const GateEntriesHistory()),
                      );
                    },
                  ),
                  _buildMenuCard(
                    context,
                    title: 'Pending Approvals',
                    icon: Icons.pending_actions,
                    color: Colors.purple,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const PendingApprovals()),
                      );
                    },
                  ),
                  _buildMenuCard(
                    context,
                    title: 'Manual Entry',
                    icon: Icons.edit,
                    color: Colors.teal,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const ManualEntryScreen()),
                      );
                    },
                  ),
                  _buildMenuCard(
                    context,
                    title: 'Scanner Setup',
                    icon: Icons.scanner,
                    color: Colors.indigo,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const ScannerManagementScreen()),
                      );
                    },
                  ),
                  _buildMenuCard(
                    context,
                    title: 'Reports',
                    icon: Icons.bar_chart,
                    color: Colors.green,
                    onTap: () {
                      // Reports feature - you can create this later
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Reports feature coming soon!')),
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