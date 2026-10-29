import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../../providers/auth_provider.dart';
import '../../services/archive_service.dart';
import 'manage_residents.dart';
import 'manage_guards.dart';
import 'gate_entries_history.dart';
import 'pending_approvals.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  final ArchiveService _archiveService = ArchiveService();
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    _runArchiveMigration();
  }

  Future<void> _runArchiveMigration() async {
    try {
      final moved = await _archiveService.migrateOldArchivesToRecords();
      if (moved > 0 && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('📖 $moved old archive${moved == 1 ? "" : "s"} moved to Records'),
            backgroundColor: const Color(0xFF8D6E63),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      print('Archive migration error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    // 🖥️ WEB LAYOUT (UNTOUCHED)
    if (kIsWeb) {
      return Scaffold(
        backgroundColor: const Color(0xFFF5F0E8),
        body: Row(
          children: [
            _buildWebSidebar(),
            Expanded(
              child: Column(
                children: [
                  _buildWebHeader(),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(32),
                      child: _buildWebContent(),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    // 📱 MOBILE LAYOUT (UPDATED)
    return Scaffold(
      backgroundColor: const Color(0xFFF5F0E8),
      body: SafeArea(
        child: Column(
          children: [
            _buildMobileHeader(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: _buildMobileContent(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // 🖥️ WEB COMPONENTS (UNTOUCHED)
  // ============================================================

  Widget _buildWebSidebar() {
    return Container(
      width: 260,
      color: const Color(0xFF5D4037),
      child: Column(
        children: [
          const SizedBox(height: 40),
          const Icon(Icons.home_work, size: 48, color: Color(0xFFFFF8F0)),
          const SizedBox(height: 12),
          const Text('Florence Homes', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFFFFF8F0), letterSpacing: 1)),
          const Text('Admin Portal', style: TextStyle(fontSize: 12, color: Color(0xFFD4C4A8))),
          const SizedBox(height: 40),
          _buildSidebarItem(0, Icons.dashboard, 'Dashboard'),
          _buildSidebarItem(1, Icons.people, 'Residents', onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ManageResidents()))),
          _buildSidebarItem(2, Icons.security, 'Guards', onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ManageGuards()))),
          _buildSidebarItem(3, Icons.pending_actions, 'Pending Approvals', onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PendingApprovals()))),
          _buildSidebarItem(4, Icons.history, 'Gate History', onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const GateEntriesHistory()))),
          const Spacer(),
          ListTile(
            leading: const Icon(Icons.logout, color: Color(0xFFD4C4A8)),
            title: const Text('Logout', style: TextStyle(color: Color(0xFFD4C4A8))),
            onTap: () {
              final authProvider = Provider.of<AuthProvider>(context, listen: false);
              _showLogoutConfirmation(context, authProvider);
            },
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildSidebarItem(int index, IconData icon, String title, {VoidCallback? onTap}) {
    bool isActive = _selectedIndex == index;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListTile(
        onTap: onTap ?? () => setState(() => _selectedIndex = index),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        tileColor: isActive ? const Color(0xFFD4C4A8).withOpacity(0.15) : Colors.transparent,
        leading: Icon(icon, color: isActive ? const Color(0xFFFFF8F0) : const Color(0xFFD4C4A8)),
        title: Text(title, style: TextStyle(color: isActive ? const Color(0xFFFFF8F0) : const Color(0xFFD4C4A8), fontWeight: isActive ? FontWeight.bold : FontWeight.normal)),
      ),
    );
  }

  Widget _buildWebHeader() {
    final auth = Provider.of<AuthProvider>(context);
    return Container(
      height: 80,
      padding: const EdgeInsets.symmetric(horizontal: 32),
      decoration: const BoxDecoration(color: Colors.white, border: Border(bottom: BorderSide(color: Color(0xFFE0D5C1), width: 1))),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text('Dashboard Overview', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF5D4037))),
          Row(
            children: [
              const CircleAvatar(backgroundColor: Color(0xFFD4C4A8), child: Icon(Icons.admin_panel_settings, color: Colors.white)),
              const SizedBox(width: 12),
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(auth.currentUser?.fullName ?? 'Admin', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF5D4037))),
                  const Text('System Administrator', style: TextStyle(fontSize: 12, color: Color(0xFF8D6E63))),
                ],
              ),
              const SizedBox(width: 24),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildWebContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance.collection('users').where('userType', isEqualTo: 'resident').snapshots(),
          builder: (context, snapshot) {
            int total = 0, rfid = 0, pending = 0;
            if (snapshot.hasData) {
              total = snapshot.data!.docs.length;
              rfid = snapshot.data!.docs.where((d) => (d.data() as Map)['rfidTag'] != null).length;
              pending = snapshot.data!.docs.where((d) => (d.data() as Map)['isApproved'] != true).length;
            }
            return Row(
              children: [
                _buildWebStatCard('Total Residents', total.toString(), Icons.people, const Color(0xFF8D6E63)),
                const SizedBox(width: 20),
                _buildWebStatCard('RFID Registered', rfid.toString(), Icons.nfc, const Color(0xFFC4A882)),
                const SizedBox(width: 20),
                _buildWebStatCard('Pending Approvals', pending.toString(), Icons.pending_actions, const Color(0xFFFF9800)),
              ],
            );
          },
        ),
        const SizedBox(height: 32),
        const Text('Quick Actions', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF5D4037))),
        const SizedBox(height: 16),
        Wrap(
          spacing: 20,
          runSpacing: 20,
          children: [
            _buildWebActionCard('Manage Residents', 'Add, edit, and archive residents', Icons.people, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ManageResidents()))),
            _buildWebActionCard('Manage Guards', 'Add and manage security personnel', Icons.security, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ManageGuards()))),
            _buildWebActionCard('Gate History', 'View all IN and OUT logs', Icons.history, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const GateEntriesHistory()))),
            _buildWebActionCard('Pending Approvals', 'Review new resident signups', Icons.pending_actions, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PendingApprovals()))),
          ],
        ),
      ],
    );
  }

  Widget _buildWebStatCard(String title, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))]),
        child: Row(
          children: [
            Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12)), child: Icon(icon, size: 32, color: color)),
            const SizedBox(width: 20),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 14, color: Color(0xFF8D6E63), fontWeight: FontWeight.w500)),
                const SizedBox(height: 4),
                Text(value, style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: color)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWebActionCard(String title, String subtitle, IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: 280,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFE0D5C1))),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 32, color: const Color(0xFF8D6E63)),
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
  // 📱 MOBILE COMPONENTS (NEW DESIGN)
  // ============================================================

  Widget _buildMobileHeader() {
    final authProvider = Provider.of<AuthProvider>(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
      decoration: const BoxDecoration(
        color: Color(0xFF5D4037), // Deep professional brown
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(30),
          bottomRight: Radius.circular(30),
        ),
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Background watermark icon for design
          Positioned(
            right: -20,
            top: -20,
            child: Icon(Icons.home_work, size: 120, color: Colors.white.withOpacity(0.05)),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.admin_panel_settings, color: Color(0xFFFFF8F0), size: 24),
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        'Admin Portal',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: Color(0xFFFFF8F0), letterSpacing: 1),
                      ),
                    ],
                  ),
                  GestureDetector(
                    onTap: () => _showLogoutConfirmation(context, authProvider),
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), borderRadius: BorderRadius.circular(12)),
                      child: const Icon(Icons.logout, color: Color(0xFFFFF8F0), size: 20),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              const Text(
                'Welcome back,',
                style: TextStyle(fontSize: 14, color: Color(0xFFD4C4A8)),
              ),
              const SizedBox(height: 4),
              Text(
                authProvider.currentUser?.fullName ?? 'System Administrator',
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFFFFF8F0)),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMobileContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Stats Row (One Line)
        StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance.collection('users').where('userType', isEqualTo: 'resident').snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) return const SizedBox();
            final residents = snapshot.data!.docs;
            final totalResidents = residents.length;
            final rfidRegistered = residents.where((doc) => (doc.data() as Map)['rfidTag'] != null && (doc.data() as Map)['rfidTag'].toString().isNotEmpty).length;
            final pendingApprovals = residents.where((doc) => (doc.data() as Map)['isApproved'] != true).length;

            return Row(
              children: [
                _mobileStatCard('Total', totalResidents.toString(), Icons.people, const Color(0xFF5D4037)),
                const SizedBox(width: 8),
                _mobileStatCard('Pending', pendingApprovals.toString(), Icons.pending_actions, const Color(0xFFFF9800)),
                const SizedBox(width: 8),
                _mobileStatCard('RFID', rfidRegistered.toString(), Icons.nfc, const Color(0xFF8D6E63)),
              ],
            );
          },
        ),

        const SizedBox(height: 28),

        const Text(
          'Quick Actions',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF5D4037)),
        ),
        const SizedBox(height: 12),

        // Quick Actions List
        _mobileActionTile(context, title: 'Manage Residents', subtitle: 'Add, edit, and archive residents', icon: Icons.people, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const ManageResidents()))),
        _mobileActionTile(context, title: 'Manage Guards', subtitle: 'Add and manage security personnel', icon: Icons.security, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const ManageGuards()))),
        _mobileActionTile(context, title: 'Gate History', subtitle: 'View all IN and OUT logs', icon: Icons.history, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const GateEntriesHistory()))),
        _mobileActionTile(context, title: 'Pending Approvals', subtitle: 'Review new resident signups', icon: Icons.pending_actions, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const PendingApprovals()))),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _mobileStatCard(String title, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE0D5C1), width: 1),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 3))],
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(height: 8),
            Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
            const SizedBox(height: 2),
            Text(title, style: const TextStyle(fontSize: 11, color: Color(0xFF8D6E63), fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    );
  }

  Widget _mobileActionTile(BuildContext context, {required String title, required String subtitle, required IconData icon, required VoidCallback onTap}) {
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
                  decoration: BoxDecoration(
                    color: const Color(0xFF5D4037).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
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