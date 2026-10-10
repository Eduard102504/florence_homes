import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../../providers/auth_provider.dart';
import 'manage_residents.dart';
import 'gate_entries_history.dart';
import 'pending_approvals.dart';
import 'manual_entry_screen.dart';
import 'scanner_management_screen.dart';
import 'pending_visits_screen.dart'; // ← NEW

class AdminDashboard extends StatelessWidget {
  const AdminDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final screenWidth = MediaQuery.of(context).size.width;

    // ==================== LAYOUT CONSTANTS ====================
    final double contentMaxWidth = kIsWeb ? 900 : double.infinity;
    final double outerPadding = kIsWeb ? 20 : 12;

    // ==================== GRID COLUMNS ====================
    int crossAxisCount = 2;
    if (kIsWeb) {
      if (screenWidth > 1200) {
        crossAxisCount = 3;
      } else if (screenWidth > 800) {
        crossAxisCount = 3;
      } else {
        crossAxisCount = 2;
      }
    }
    if (screenWidth < 600) crossAxisCount = 2;

    // ==================== GRID SIZING ====================
    final double gridAspect = kIsWeb ? 1.4 : 1.1;
    final double gridSpacing = kIsWeb ? 14 : 10;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: const [
            Icon(Icons.home_work, size: 22, color: Color(0xFFFFF8F0)),
            SizedBox(width: 8),
            Text(
              'Admin Dashboard',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                letterSpacing: 1,
                fontSize: 18,
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFFD4C4A8),
        elevation: 0,
        centerTitle: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, size: 20),
            onPressed: () => _showLogoutConfirmation(context, authProvider),
            color: const Color(0xFFFFF8F0),
          ),
        ],
      ),
      body: Container(
        constraints: const BoxConstraints.expand(),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFFFF8F0),
              Color(0xFFF5F0E8),
              Color(0xFFEDE5D8),
            ],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: EdgeInsets.all(outerPadding),
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: contentMaxWidth),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // ==================== WELCOME CARD ====================
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFD4C4A8).withOpacity(0.2),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: const Color(0xFFE0D5C1),
                            width: 1.5,
                          ),
                        ),
                        padding: const EdgeInsets.all(14),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    Color(0xFFD4C4A8),
                                    Color(0xFFC4A882),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                Icons.admin_panel_settings,
                                size: kIsWeb ? 28 : 26,
                                color: const Color(0xFFFFF8F0),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Welcome, ${authProvider.currentUser?.fullName ?? 'Admin'}!',
                                    style: TextStyle(
                                      fontSize: kIsWeb ? 16 : 14,
                                      fontWeight: FontWeight.bold,
                                      color: const Color(0xFF6B5B4F),
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Manage residents, gate access, and view reports',
                                    style: TextStyle(
                                      fontSize: kIsWeb ? 11 : 10,
                                      color: const Color(0xFFB8A99A),
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // ==================== STATS ====================
                    StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('users')
                          .where('userType', isEqualTo: 'resident')
                          .snapshots(),
                      builder: (context, snapshot) {
                        if (!snapshot.hasData) {
                          return Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            alignment: WrapAlignment.center,
                            children: [
                              _buildStatCard('Total', '...', Icons.people,
                                  const Color(0xFFD4C4A8), screenWidth),
                              _buildStatCard('RFID', '...', Icons.nfc,
                                  const Color(0xFFC4A882), screenWidth),
                              _buildStatCard('Pending', '...', Icons.pending,
                                  const Color(0xFFB8A99A), screenWidth),
                            ],
                          );
                        }

                        final residents = snapshot.data!.docs;
                        final totalResidents = residents.length;
                        final rfidRegistered = residents.where((doc) {
                          final data = doc.data() as Map<String, dynamic>;
                          return data['rfidTag'] != null &&
                              data['rfidTag'].toString().isNotEmpty;
                        }).length;
                        final pendingApprovals = residents.where((doc) {
                          final data = doc.data() as Map<String, dynamic>;
                          return data['isApproved'] != true;
                        }).length;

                        return Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          alignment: WrapAlignment.center,
                          children: [
                            _buildStatCard('Total', totalResidents.toString(),
                                Icons.people, const Color(0xFFD4C4A8),
                                screenWidth),
                            _buildStatCard('RFID', rfidRegistered.toString(),
                                Icons.nfc, const Color(0xFFC4A882),
                                screenWidth),
                            _buildStatCard(
                                'Pending',
                                pendingApprovals.toString(),
                                Icons.pending,
                                const Color(0xFFB8A99A),
                                screenWidth),
                          ],
                        );
                      },
                    ),

                    const SizedBox(height: 14),

                    // ==================== MENU GRID ====================
                    GridView.count(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisCount: crossAxisCount,
                      crossAxisSpacing: gridSpacing,
                      mainAxisSpacing: gridSpacing,
                      childAspectRatio: gridAspect,
                      children: [
                        _buildMenuCard(
                          context,
                          title: '👥 Residents',
                          icon: Icons.people,
                          color: const Color(0xFFD4C4A8),
                          description: 'Manage residents',
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (context) =>
                                const ManageResidents()),
                          ),
                        ),
                        _buildMenuCard(
                          context,
                          title: '📜 History',
                          icon: Icons.history,
                          color: const Color(0xFFC4A882),
                          description: 'Gate entries',
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (context) =>
                                const GateEntriesHistory()),
                          ),
                        ),
                        _buildMenuCard(
                          context,
                          title: '⏳ Pending',
                          icon: Icons.pending_actions,
                          color: const Color(0xFFB8A99A),
                          description: 'Approve residents',
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (context) =>
                                const PendingApprovals()),
                          ),
                        ),
                        _buildMenuCard(
                          context,
                          title: '✏️ Manual',
                          icon: Icons.edit,
                          color: const Color(0xFF8D6E63),
                          description: 'Manual entry',
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (context) =>
                                const ManualEntryScreen()),
                          ),
                        ),
                        _buildMenuCard(
                          context,
                          title: '📡 QR Scanner',
                          icon: Icons.scanner,
                          color: const Color(0xFFA89070),
                          description: 'For Visitors',
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (context) =>
                                const ScannerManagementScreen()),
                          ),
                        ),
                        // ==================== NEW: PENDING VISITS ====================
                        _buildMenuCard(
                          context,
                          title: '🚪 Pending Visits',
                          icon: Icons.exit_to_app,
                          color: const Color(0xFFFF9800),
                          description: 'Guests still inside',
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (context) =>
                                const PendingVisitsScreen()),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ==================== LOGOUT ====================
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
              Text(
                'Logout',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF6B5B4F),
                ),
              ),
            ],
          ),
          content: const Text(
            'Are you sure you want to logout?',
            style: TextStyle(fontSize: 14, color: Color(0xFF8D6E63)),
          ),
          backgroundColor: const Color(0xFFFFF8F0),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: const BorderSide(color: Color(0xFFE0D5C1), width: 1.5),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFFB8A99A),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 10)),
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
                backgroundColor: const Color(0xFFD4C4A8),
                foregroundColor: const Color(0xFF6B5B4F),
                padding: const EdgeInsets.symmetric(
                    horizontal: 20, vertical: 10),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Logout',
                  style: TextStyle(
                      fontSize: 14, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  // ==================== STAT CARD ====================
  Widget _buildStatCard(String title, String value, IconData icon,
      Color color, double screenWidth) {
    double cardWidth = screenWidth < 600 ? (screenWidth / 3) - 12 : 100;
    double iconSize = screenWidth < 600 ? 16 : 20;
    double fontSize = screenWidth < 600 ? 12 : 14;
    double labelSize = screenWidth < 600 ? 8 : 10;

    return Container(
      width: cardWidth.clamp(70, 100),
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3), width: 1),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: iconSize),
          const SizedBox(height: 2),
          Text(value,
              style: TextStyle(
                  fontSize: fontSize,
                  fontWeight: FontWeight.bold,
                  color: color)),
          const SizedBox(height: 1),
          Text(title,
              style: TextStyle(
                  fontSize: labelSize,
                  color: color,
                  fontWeight: FontWeight.w500),
              textAlign: TextAlign.center),
        ],
      ),
    );
  }

  // ==================== MENU CARD ====================
  Widget _buildMenuCard(
      BuildContext context, {
        required String title,
        required IconData icon,
        required Color color,
        required String description,
        required VoidCallback onTap,
      }) {
    final double cardPadding = kIsWeb ? 12 : 8;
    final double iconBoxPadding = kIsWeb ? 10 : 8;
    final double iconSize = kIsWeb ? 26 : 28;
    final double titleSize = kIsWeb ? 13 : 12;
    final double descSize = kIsWeb ? 10 : 9;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFD4C4A8).withOpacity(0.15),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                  color: const Color(0xFFE0D5C1), width: 1),
            ),
            padding: EdgeInsets.all(cardPadding),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: EdgeInsets.all(iconBoxPadding),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [color, color.withOpacity(0.7)],
                    ),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: color.withOpacity(0.2),
                        blurRadius: 6,
                      ),
                    ],
                  ),
                  child: Icon(icon,
                      size: iconSize, color: const Color(0xFFFFF8F0)),
                ),
                SizedBox(height: kIsWeb ? 8 : 8),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: titleSize,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF6B5B4F),
                    letterSpacing: 0.3,
                  ),
                ),
                SizedBox(height: kIsWeb ? 3 : 2),
                Text(
                  description,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: descSize,
                    color: const Color(0xFFB8A99A),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}