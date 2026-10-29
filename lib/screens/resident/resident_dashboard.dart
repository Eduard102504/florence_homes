// lib/screens/resident/resident_dashboard.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../../providers/auth_provider.dart';
import 'generate_visitor_qr.dart';
import 'gate_history.dart';
import 'my_qr_codes.dart';
import 'my_profile_screen.dart';

class ResidentDashboard extends StatelessWidget {
  const ResidentDashboard({super.key});

  // ==================== BUILD ====================
  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final user = authProvider.currentUser;
    final hasRFID = user?.rfidTag != null && user!.rfidTag!.isNotEmpty;

    if (kIsWeb) {
      return Scaffold(
        backgroundColor: const Color(0xFFF5F0E8),
        body: Row(
          children: [
            _buildWebSidebar(context, authProvider),
            Expanded(
              child: Column(
                children: [
                  _buildWebHeader(authProvider),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(32),
                      child: _buildWebContent(context, authProvider, hasRFID),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF5F0E8),
      body: SafeArea(
        child: Column(
          children: [
            _buildMobileHeader(context, authProvider),
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.all(20),
                child: _buildMobileContent(context, authProvider, hasRFID),
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

  Widget _buildWebSidebar(BuildContext context, AuthProvider authProvider) {
    return Container(
      width: 260,
      color: const Color(0xFF5D4037),
      child: Column(
        children: [
          const SizedBox(height: 40),
          const Icon(Icons.home_work, size: 48, color: Color(0xFFFFF8F0)),
          const SizedBox(height: 12),
          const Text('Florence Homes',
              style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFFFF8F0),
                  letterSpacing: 1)),
          const Text('Resident Portal',
              style: TextStyle(fontSize: 12, color: Color(0xFFD4C4A8))),
          const SizedBox(height: 40),
          _buildWebSidebarItem(Icons.dashboard, 'Dashboard',
              isActive: true, onTap: () {}),
          _buildWebSidebarItem(Icons.qr_code, 'Generate QR',
              onTap: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const GenerateVisitorQR()))),
          _buildWebSidebarItem(Icons.qr_code_scanner, 'My QR Codes',
              onTap: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const MyQRCodes()))),
          _buildWebSidebarItem(Icons.history, 'Gate History',
              onTap: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const GateHistory()))),
          _buildWebSidebarItem(Icons.person, 'Profile',
              onTap: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const MyProfileScreen()))),
          const Spacer(),
          ListTile(
            leading: const Icon(Icons.logout, color: Color(0xFFD4C4A8)),
            title: const Text('Logout',
                style: TextStyle(color: Color(0xFFD4C4A8), fontSize: 13)),
            onTap: () => _showLogoutConfirmation(context, authProvider),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildWebSidebarItem(IconData icon, String title,
      {bool isActive = false, required VoidCallback onTap}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListTile(
        onTap: onTap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        tileColor: isActive
            ? const Color(0xFFD4C4A8).withOpacity(0.15)
            : Colors.transparent,
        leading: Icon(icon,
            color: isActive ? const Color(0xFFFFF8F0) : const Color(0xFFD4C4A8)),
        title: Text(title,
            style: TextStyle(
                color: isActive ? const Color(0xFFFFF8F0) : const Color(0xFFD4C4A8),
                fontWeight: isActive ? FontWeight.bold : FontWeight.normal)),
      ),
    );
  }

  Widget _buildWebHeader(AuthProvider authProvider) {
    final user = authProvider.currentUser;
    return Container(
      height: 80,
      padding: const EdgeInsets.symmetric(horizontal: 32),
      decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(bottom: BorderSide(color: Color(0xFFE0D5C1), width: 1))),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text('Dashboard Overview',
              style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF5D4037))),
          Row(
            children: [
              const CircleAvatar(
                  backgroundColor: Color(0xFF5D4037),
                  child: Icon(Icons.person, color: Colors.white)),
              const SizedBox(width: 12),
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(user?.fullName ?? 'Resident',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF5D4037))),
                  Text('House ${user?.houseNumber ?? '—'}',
                      style: const TextStyle(
                          fontSize: 12, color: Color(0xFF8D6E63))),
                ],
              ),
              const SizedBox(width: 24),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildWebContent(
      BuildContext context, AuthProvider authProvider, bool hasRFID) {
    final user = authProvider.currentUser;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Welcome card
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE0D5C1)),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withOpacity(0.03),
                    blurRadius: 8,
                    offset: const Offset(0, 4))
              ]),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [
                      Color(0xFF5D4037),
                      Color(0xFF8D6E63)
                    ]),
                    borderRadius: BorderRadius.circular(14)),
                child: const Icon(Icons.home_work,
                    size: 32, color: Color(0xFFFFF8F0)),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                        'Welcome back, ${user?.fullName?.split(' ').first ?? 'Resident'}!',
                        style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF5D4037))),
                    if (user?.houseNumber != null) ...[
                      const SizedBox(height: 4),
                      Text('House ${user!.houseNumber}',
                          style: const TextStyle(
                              fontSize: 13, color: Color(0xFF8D6E63))),
                    ],
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        _buildStatusBadge(
                          user?.isApproved == true
                              ? '✓ Account Approved'
                              : '⏳ Pending Approval',
                          user?.isApproved == true
                              ? const Color(0xFF4CAF50)
                              : const Color(0xFFFF9800),
                        ),
                        if (hasRFID)
                          _buildStatusBadge(
                              '✓ RFID Registered', const Color(0xFF8D6E63)),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // RFID info card
        if (hasRFID) ...[
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE0D5C1)),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withOpacity(0.03),
                      blurRadius: 8,
                      offset: const Offset(0, 4))
                ]),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [
                        Color(0xFF8D6E63),
                        Color(0xFFD4C4A8)
                      ]),
                      borderRadius: BorderRadius.circular(12)),
                  child: const Icon(Icons.nfc,
                      size: 24, color: Color(0xFFFFF8F0)),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('RFID Tag Information',
                          style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF5D4037))),
                      const SizedBox(height: 4),
                      Text(
                          'Tag ID: ${user!.rfidTag!.substring(0, user.rfidTag!.length > 20 ? 20 : user.rfidTag!.length)}...',
                          style: const TextStyle(
                              fontSize: 12, color: Color(0xFF8D6E63))),
                      const SizedBox(height: 4),
                      Row(
                        children: const [
                          Icon(Icons.check_circle,
                              size: 12, color: Color(0xFF4CAF50)),
                          SizedBox(width: 4),
                          Text('Status: ',
                              style: TextStyle(
                                  fontSize: 11, color: Color(0xFF8D6E63))),
                          Text('Active',
                              style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF4CAF50))),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
        ],

        // Menu grid
        const Text('Quick Actions',
            style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF5D4037))),
        const SizedBox(height: 16),
        Wrap(
          spacing: 20,
          runSpacing: 20,
          children: [
            _buildWebActionCard(
              'Visitor QR',
              'Create visitor QR codes',
              Icons.qr_code,
                  () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const GenerateVisitorQR())),
            ),
            _buildWebActionCard(
              'Gate History',
              'View your gate entries',
              Icons.history,
                  () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const GateHistory())),
            ),
            _buildWebActionCard(
              'My QR Codes',
              'View your QR codes',
              Icons.qr_code_scanner,
                  () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const MyQRCodes())),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildWebActionCard(
      String title, String subtitle, IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: 260,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE0D5C1)),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withOpacity(0.03),
                  blurRadius: 10,
                  offset: const Offset(0, 4))
            ]),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                  color: const Color(0xFF5D4037).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12)),
              child: Icon(icon, size: 28, color: const Color(0xFF5D4037)),
            ),
            const SizedBox(height: 16),
            Text(title,
                style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF5D4037))),
            const SizedBox(height: 4),
            Text(subtitle,
                style: const TextStyle(
                    fontSize: 12, color: Color(0xFF8D6E63))),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // 📱 MOBILE COMPONENTS
  // ============================================================

  Widget _buildMobileHeader(BuildContext context, AuthProvider authProvider) {
    final user = authProvider.currentUser;
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
      decoration: const BoxDecoration(
        color: Color(0xFF5D4037),
        borderRadius: BorderRadius.only(
            bottomLeft: Radius.circular(30),
            bottomRight: Radius.circular(30)),
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
              right: -20,
              top: -20,
              child: Icon(Icons.home_work,
                  size: 120, color: Colors.white.withOpacity(0.05))),
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
                            borderRadius: BorderRadius.circular(12)),
                        child: const Icon(Icons.home_work,
                            color: Color(0xFFFFF8F0), size: 24),
                      ),
                      const SizedBox(width: 12),
                      const Text('Florence Homes',
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 20,
                              color: Color(0xFFFFF8F0),
                              letterSpacing: 1)),
                    ],
                  ),
                  Row(
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.push(context,
                            MaterialPageRoute(
                                builder: (_) => const MyProfileScreen())),
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(12)),
                          child: const Icon(Icons.person,
                              color: Color(0xFFFFF8F0), size: 20),
                        ),
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: () =>
                            _showLogoutConfirmation(context, authProvider),
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(12)),
                          child: const Icon(Icons.logout,
                              color: Color(0xFFFFF8F0), size: 20),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 24),
              const Text('Welcome back,',
                  style:
                  TextStyle(fontSize: 14, color: Color(0xFFD4C4A8))),
              const SizedBox(height: 4),
              Text(
                user?.fullName ?? 'Resident',
                style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFFFF8F0)),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMobileContent(
      BuildContext context, AuthProvider authProvider, bool hasRFID) {
    final user = authProvider.currentUser;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Status badges card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE0D5C1)),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withOpacity(0.03),
                    blurRadius: 6,
                    offset: const Offset(0, 2))
              ]),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (user?.houseNumber != null) ...[
                Row(
                  children: [
                    const Icon(Icons.home_outlined,
                        size: 16, color: Color(0xFF8D6E63)),
                    const SizedBox(width: 6),
                    Text('House ${user!.houseNumber}',
                        style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF5D4037))),
                  ],
                ),
                const SizedBox(height: 10),
              ],
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  _buildStatusBadge(
                    user?.isApproved == true
                        ? '✓ Account Approved'
                        : '⏳ Pending Approval',
                    user?.isApproved == true
                        ? const Color(0xFF4CAF50)
                        : const Color(0xFFFF9800),
                  ),
                  if (hasRFID)
                    _buildStatusBadge(
                        '✓ RFID Registered', const Color(0xFF8D6E63)),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // RFID info
        if (hasRFID) ...[
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE0D5C1)),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withOpacity(0.03),
                      blurRadius: 6,
                      offset: const Offset(0, 2))
                ]),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [
                        Color(0xFF8D6E63),
                        Color(0xFFD4C4A8)
                      ]),
                      borderRadius: BorderRadius.circular(12)),
                  child: const Icon(Icons.nfc,
                      size: 24, color: Color(0xFFFFF8F0)),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('RFID Tag',
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF5D4037))),
                      const SizedBox(height: 4),
                      Text(
                          'Tag ID: ${user!.rfidTag!.substring(0, user.rfidTag!.length > 20 ? 20 : user.rfidTag!.length)}...',
                          style: const TextStyle(
                              fontSize: 11, color: Color(0xFF8D6E63))),
                      const SizedBox(height: 2),
                      Row(
                        children: const [
                          Icon(Icons.check_circle,
                              size: 12, color: Color(0xFF4CAF50)),
                          SizedBox(width: 4),
                          Text('Active',
                              style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF4CAF50))),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],

        const Text('Quick Actions',
            style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF5D4037))),
        const SizedBox(height: 12),

        // Mobile action tiles
        _mobileActionTile(context,
            title: 'Visitor QR',
            subtitle: 'Create visitor QR codes',
            icon: Icons.qr_code,
            onTap: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const GenerateVisitorQR()))),
        _mobileActionTile(context,
            title: 'Gate History',
            subtitle: 'View your gate entries',
            icon: Icons.history,
            onTap: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const GateHistory()))),
        _mobileActionTile(context,
            title: 'My QR Codes',
            subtitle: 'View your QR codes',
            icon: Icons.qr_code_scanner,
            onTap: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const MyQRCodes()))),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _mobileActionTile(BuildContext context,
      {required String title,
        required String subtitle,
        required IconData icon,
        required VoidCallback onTap}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE0D5C1)),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 6,
                offset: const Offset(0, 2))
          ]),
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
                      borderRadius: BorderRadius.circular(12)),
                  child:
                  Icon(icon, size: 24, color: const Color(0xFF5D4037)),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF5D4037))),
                      const SizedBox(height: 2),
                      Text(subtitle,
                          style: const TextStyle(
                              fontSize: 12, color: Color(0xFF8D6E63))),
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

  // ==================== SHARED ====================
  Widget _buildStatusBadge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
          color: color.withOpacity(0.15),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withOpacity(0.3))),
      child: Text(label,
          style: TextStyle(
              fontSize: 10, fontWeight: FontWeight.w600, color: color)),
    );
  }

  void _showLogoutConfirmation(
      BuildContext context, AuthProvider authProvider) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.logout, color: Color(0xFFD4C4A8), size: 28),
              SizedBox(width: 12),
              Text('Logout',
                  style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF5D4037))),
            ],
          ),
          content: const Text('Are you sure you want to logout?',
              style: TextStyle(fontSize: 14, color: Color(0xFF8D6E63))),
          backgroundColor: const Color(0xFFFFF8F0),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: const BorderSide(color: Color(0xFFE0D5C1), width: 1.5)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFFB8A99A),
                  padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 10)),
              child: const Text('Cancel', style: TextStyle(fontSize: 14)),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(context);
                await authProvider.logout();
                if (context.mounted) {
                  Navigator.pushReplacementNamed(context, '/login');
                }
              },
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF5D4037),
                  foregroundColor: Colors.white,
                  padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12))),
              child: const Text('Logout',
                  style: TextStyle(
                      fontSize: 14, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }
}