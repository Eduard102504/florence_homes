// lib/screens/guard/guard_dashboard.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../../providers/auth_provider.dart';
import '../admin/manual_entry_screen.dart';
import '../admin/gate_entries_history.dart';
import '../admin/scanner_management_screen.dart';
import '../admin/pending_visits_screen.dart';

class GuardDashboard extends StatelessWidget {
  const GuardDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final user = authProvider.currentUser;

    // 🖥️ WEB LAYOUT
    if (kIsWeb) {
      return Scaffold(
        backgroundColor: const Color(0xFFF5F0E8),
        body: Row(
          children: [
            _buildWebSidebar(context, authProvider, user),
            Expanded(
              child: Column(
                children: [
                  _buildWebHeader(user),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(32),
                      child: _buildWebContent(context),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    // 📱 MOBILE LAYOUT
    return Scaffold(
      backgroundColor: const Color(0xFFF5F0E8),
      body: SafeArea(
        child: Column(
          children: [
            _buildMobileHeader(context, authProvider, user),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: _buildMobileContent(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // 🖥️ WEB COMPONENTS
  // ============================================================

  Widget _buildWebSidebar(BuildContext context, AuthProvider auth, dynamic user) {
    return Container(
      width: 260,
      color: const Color(0xFF5D4037),
      child: Column(
        children: [
          const SizedBox(height: 40),
          const Icon(Icons.shield, size: 48, color: Color(0xFFFFF8F0)),
          const SizedBox(height: 12),
          const Text('Guard Portal', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFFFFF8F0), letterSpacing: 1)),
          const Text('Florence Homes', style: TextStyle(fontSize: 12, color: Color(0xFFD4C4A8))),
          const SizedBox(height: 40),
          _buildSidebarItem(Icons.edit_document, 'Manual Entry', onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ManualEntryScreen()))),
          _buildSidebarItem(Icons.qr_code_scanner, 'QR Scanner', onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ScannerManagementScreen()))),
          _buildSidebarItem(Icons.exit_to_app, 'Pending Visits', onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PendingVisitsScreen()))),
          _buildSidebarItem(Icons.history, 'Gate History', onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const GateEntriesHistory()))),
          const Spacer(),
          ListTile(
            leading: const Icon(Icons.logout, color: Color(0xFFD4C4A8)),
            title: const Text('Logout', style: TextStyle(color: Color(0xFFD4C4A8))),
            onTap: () => _showLogoutConfirmation(context, auth),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildSidebarItem(IconData icon, String title, {required VoidCallback onTap}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListTile(
        onTap: onTap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        leading: Icon(icon, color: const Color(0xFFD4C4A8)),
        title: Text(title, style: const TextStyle(color: Color(0xFFD4C4A8), fontWeight: FontWeight.normal)),
      ),
    );
  }

  Widget _buildWebHeader(dynamic user) {
    return Container(
      height: 80,
      padding: const EdgeInsets.symmetric(horizontal: 32),
      decoration: const BoxDecoration(color: Colors.white, border: Border(bottom: BorderSide(color: Color(0xFFE0D5C1), width: 1))),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text('Guard Dashboard', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF5D4037))),
          Row(
            children: [
              const CircleAvatar(backgroundColor: Color(0xFFD4C4A8), child: Icon(Icons.security, color: Colors.white)),
              const SizedBox(width: 12),
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(user?.fullName ?? 'Security Guard', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF5D4037))),
                  const Text('Gate Security', style: TextStyle(fontSize: 12, color: Color(0xFF8D6E63))),
                ],
              ),
              const SizedBox(width: 24),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildWebContent(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Quick Actions', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF5D4037))),
        const SizedBox(height: 16),
        Wrap(
          spacing: 20,
          runSpacing: 20,
          children: [
            _buildWebActionCard('Manual Entry', 'Record deliveries and guests', Icons.edit_document, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ManualEntryScreen()))),
            _buildWebActionCard('QR Scanner', 'Scan visitor QR codes', Icons.qr_code_scanner, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ScannerManagementScreen()))),
            _buildWebActionCard('Pending Visits', 'Mark guests as OUT', Icons.exit_to_app, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PendingVisitsScreen()))),
            _buildWebActionCard('Gate History', 'View all IN and OUT logs', Icons.history, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const GateEntriesHistory()))),
          ],
        ),
      ],
    );
  }

  Widget _buildWebActionCard(String title, String subtitle, IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: 280,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFE0D5C1)), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))]),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: const Color(0xFF8D6E63).withOpacity(0.1), borderRadius: BorderRadius.circular(12)), child: Icon(icon, size: 32, color: const Color(0xFF8D6E63))),
            const SizedBox(height: 16),
            Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF5D4037))),
            const SizedBox(height: 4),
            Text(subtitle, style: const TextStyle(fontSize: 12, color: Color(0xFF8D6E63))),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // 📱 MOBILE COMPONENTS
  // ============================================================

  Widget _buildMobileHeader(BuildContext context, AuthProvider authProvider, dynamic user) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
      decoration: const BoxDecoration(
        color: Color(0xFF5D4037),
        borderRadius: BorderRadius.only(bottomLeft: Radius.circular(30), bottomRight: Radius.circular(30)),
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(right: -20, top: -20, child: Icon(Icons.shield, size: 120, color: Colors.white.withOpacity(0.05))),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), borderRadius: BorderRadius.circular(12)), child: const Icon(Icons.security, color: Color(0xFFFFF8F0), size: 24)),
                      const SizedBox(width: 12),
                      const Text('Guard Portal', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: Color(0xFFFFF8F0), letterSpacing: 1)),
                    ],
                  ),
                  GestureDetector(
                    onTap: () => _showLogoutConfirmation(context, authProvider),
                    child: Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), borderRadius: BorderRadius.circular(12)), child: const Icon(Icons.logout, color: Color(0xFFFFF8F0), size: 20)),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              const Text('Welcome,', style: TextStyle(fontSize: 14, color: Color(0xFFD4C4A8))),
              const SizedBox(height: 4),
              Text(user?.fullName ?? 'Security Guard', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFFFFF8F0)), overflow: TextOverflow.ellipsis),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMobileContent(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Quick Actions', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF5D4037))),
        const SizedBox(height: 16),
        _buildMobileActionTile(context, title: 'Manual Entry', subtitle: 'Record deliveries and guests', icon: Icons.edit_document, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ManualEntryScreen()))),
        _buildMobileActionTile(context, title: 'QR Scanner', subtitle: 'Scan visitor QR codes', icon: Icons.qr_code_scanner, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ScannerManagementScreen()))),
        _buildMobileActionTile(context, title: 'Pending Visits', subtitle: 'Mark guests as OUT', icon: Icons.exit_to_app, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PendingVisitsScreen()))),
        _buildMobileActionTile(context, title: 'Gate History', subtitle: 'View all IN and OUT logs', icon: Icons.history, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const GateEntriesHistory()))),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildMobileActionTile(BuildContext context, {required String title, required String subtitle, required IconData icon, required VoidCallback onTap}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE0D5C1), width: 1),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 6, offset: const Offset(0, 2))],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: const Color(0xFF5D4037).withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                  child: Icon(icon, size: 24, color: const Color(0xFF5D4037)),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF5D4037))),
                      const SizedBox(height: 2),
                      Text(subtitle, style: const TextStyle(fontSize: 12, color: Color(0xFF8D6E63))),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, color: Color(0xFFD4C4A8)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ============================================================
  // 🔥 SHARED LOGOUT CONFIRMATION
  // ============================================================
  void _showLogoutConfirmation(BuildContext context, AuthProvider authProvider) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.logout, color: Color(0xFFD4C4A8), size: 28),
              SizedBox(width: 12),
              Text('Logout', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF6B5B4F))),
            ],
          ),
          content: const Text('Are you sure you want to logout?', style: TextStyle(fontSize: 14, color: Color(0xFF8D6E63))),
          backgroundColor: const Color(0xFFFFF8F0),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: const BorderSide(color: Color(0xFFE0D5C1), width: 1.5)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              style: TextButton.styleFrom(foregroundColor: const Color(0xFFB8A99A), padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10)),
              child: const Text('Cancel', style: TextStyle(fontSize: 14)),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(context);
                await authProvider.logout();
                if (context.mounted) Navigator.pushReplacementNamed(context, '/login');
              },
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFD4C4A8), foregroundColor: const Color(0xFF6B5B4F), padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              child: const Text('Logout', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }
}