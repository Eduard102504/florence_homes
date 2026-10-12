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

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final screenWidth = MediaQuery.of(context).size.width;
    final user = authProvider.currentUser;
    final hasRFID = user?.rfidTag != null && user!.rfidTag!.isNotEmpty;

    final double contentMaxWidth = kIsWeb ? 900 : double.infinity;
    final double outerPadding = kIsWeb ? 24 : 16;

    int crossAxisCount = 3;
    if (!kIsWeb && screenWidth < 600) crossAxisCount = 2;

    final double gridAspect = kIsWeb ? 1.6 : 1.0;
    final double gridSpacing = kIsWeb ? 16 : 12;

    return Scaffold(
      backgroundColor: const Color(0xFFD4C4A8),
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
          child: Column(
            children: [
              _buildHeader(context, authProvider),
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: EdgeInsets.all(outerPadding),
                  child: Center(
                    child: ConstrainedBox(
                      constraints:
                      BoxConstraints(maxWidth: contentMaxWidth),
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
                                  color: const Color(0xFFD4C4A8)
                                      .withOpacity(0.2),
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
                              padding:
                              EdgeInsets.all(kIsWeb ? 14 : 16),
                              child: Row(
                                children: [
                                  Container(
                                    padding:
                                    EdgeInsets.all(kIsWeb ? 10 : 12),
                                    decoration: BoxDecoration(
                                      gradient: const LinearGradient(
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                        colors: [
                                          Color(0xFFD4C4A8),
                                          Color(0xFFC4A882)
                                        ],
                                      ),
                                      borderRadius:
                                      BorderRadius.circular(14),
                                    ),
                                    child: Icon(
                                      Icons.home_work,
                                      size: kIsWeb ? 28 : 36,
                                      color: const Color(0xFFFFF8F0),
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Welcome, ${user?.fullName?.split(' ').first ?? 'Resident'}!',
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                            color: Color(0xFF6B5B4F),
                                            letterSpacing: 0.5,
                                          ),
                                        ),
                                        if (user?.houseNumber != null)
                                          Padding(
                                            padding: const EdgeInsets.only(
                                                top: 4),
                                            child: Row(
                                              children: [
                                                const Icon(
                                                    Icons.home_outlined,
                                                    size: 12,
                                                    color:
                                                    Color(0xFFB8A99A)),
                                                const SizedBox(width: 4),
                                                Text(
                                                  'House: ${user?.houseNumber}',
                                                  style: const TextStyle(
                                                    fontSize: 12,
                                                    color:
                                                    Color(0xFF8D6E63),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        const SizedBox(height: 8),
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
                                                '✓ RFID Registered',
                                                const Color(0xFF8D6E63),
                                              ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),

                          // ==================== RFID INFO CARD ====================
                          if (hasRFID) ...[
                            Container(
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFFD4C4A8)
                                        .withOpacity(0.15),
                                    blurRadius: 6,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: const Color(0xFFE0D5C1),
                                    width: 1,
                                  ),
                                ),
                                padding:
                                EdgeInsets.all(kIsWeb ? 12 : 14),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: EdgeInsets.all(
                                          kIsWeb ? 8 : 10),
                                      decoration: BoxDecoration(
                                        gradient: const LinearGradient(
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                          colors: [
                                            Color(0xFF8D6E63),
                                            Color(0xFFD4C4A8)
                                          ],
                                        ),
                                        borderRadius:
                                        BorderRadius.circular(10),
                                      ),
                                      child: Icon(
                                        Icons.nfc,
                                        size: kIsWeb ? 22 : 28,
                                        color: const Color(0xFFFFF8F0),
                                      ),
                                    ),
                                    const SizedBox(width: 14),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'RFID Tag Information',
                                            style: TextStyle(
                                              fontSize:
                                              kIsWeb ? 13 : 14,
                                              fontWeight: FontWeight.bold,
                                              color:
                                              const Color(0xFF6B5B4F),
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Row(
                                            children: [
                                              const Icon(Icons.tag,
                                                  size: 12,
                                                  color:
                                                  Color(0xFFB8A99A)),
                                              const SizedBox(width: 4),
                                              Expanded(
                                                child: Text(
                                                  'Tag ID: ${user?.rfidTag?.substring(0, user!.rfidTag!.length > 20 ? 20 : user.rfidTag!.length)}...',
                                                  style: const TextStyle(
                                                    fontSize: 11,
                                                    color:
                                                    Color(0xFF8D6E63),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 2),
                                          Row(
                                            children: const [
                                              Icon(Icons.check_circle,
                                                  size: 12,
                                                  color:
                                                  Color(0xFF4CAF50)),
                                              SizedBox(width: 4),
                                              Text(
                                                'Status: ',
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  color:
                                                  Color(0xFFB8A99A),
                                                ),
                                              ),
                                              Text(
                                                'Active',
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  fontWeight:
                                                  FontWeight.w600,
                                                  color:
                                                  Color(0xFF4CAF50),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                          ],

                          // ==================== MENU GRID ====================
                          GridView.count(
                            shrinkWrap: true,
                            physics:
                            const NeverScrollableScrollPhysics(),
                            crossAxisCount: crossAxisCount,
                            crossAxisSpacing: gridSpacing,
                            mainAxisSpacing: gridSpacing,
                            childAspectRatio: gridAspect,
                            children: [
                              _buildMenuCard(
                                context,
                                title: 'Visitor QR',
                                icon: Icons.qr_code,
                                color: const Color(0xFFD4C4A8),
                                description: 'Create visitor QR codes',
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                        builder: (context) =>
                                        const GenerateVisitorQR()),
                                  );
                                },
                              ),
                              _buildMenuCard(
                                context,
                                title: 'Gate History',
                                icon: Icons.history,
                                color: const Color(0xFFC4A882),
                                description: 'View your gate entries',
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                        builder: (context) =>
                                        const GateHistory()),
                                  );
                                },
                              ),
                              _buildMenuCard(
                                context,
                                title: 'My QR Codes',
                                icon: Icons.qr_code_scanner,
                                color: const Color(0xFFB8A99A),
                                description: 'View your QR codes',
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                        builder: (context) =>
                                        const MyQRCodes()),
                                  );
                                },
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // INLINE HEADER (resident theme)
  // ============================================================
  Widget _buildHeader(BuildContext context, AuthProvider authProvider) {
    return Container(
      color: const Color(0xFFD4C4A8),
      padding: EdgeInsets.fromLTRB(
        kIsWeb ? 20 : 16,
        kIsWeb ? 14 : 12,
        kIsWeb ? 20 : 16,
        kIsWeb ? 14 : 12,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: 40,
            child: Row(
              children: [
                const Spacer(),
                // Profile pill
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) =>
                            const MyProfileScreen()),
                      );
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF8F0).withOpacity(0.15),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color:
                          const Color(0xFFFFF8F0).withOpacity(0.25),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(
                              color: Color(0xFFFFF8F0),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.person,
                                size: 14, color: Color(0xFF8D6E63)),
                          ),
                          const SizedBox(width: 6),
                          const Text(
                            'Profile',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFFFFF8F0),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // Logout pill
                _iconPill(
                  icon: Icons.logout,
                  tooltip: 'Logout',
                  onTap: () =>
                      _showLogoutConfirmation(context, authProvider),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: const [
              Icon(Icons.home_work,
                  size: 26, color: Color(0xFFFFF8F0)),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Florence Homes',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                    fontSize: 22,
                    color: Color(0xFFFFF8F0),
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _iconPill({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: const Color(0xFFFFF8F0).withOpacity(0.15),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: const Color(0xFFFFF8F0).withOpacity(0.25),
              width: 1,
            ),
          ),
          child: Tooltip(
            message: tooltip,
            child: Icon(icon, color: const Color(0xFFFFF8F0), size: 20),
          ),
        ),
      ),
    );
  }

  // ==================== SMALL STATUS BADGE ====================
  Widget _buildStatusBadge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }

  // ==================== LOGOUT CONFIRMATION ====================
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
                padding:
                const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              ),
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
                padding:
                const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
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

  // ==================== MENU CARD ====================
  Widget _buildMenuCard(
      BuildContext context, {
        required String title,
        required IconData icon,
        required Color color,
        required String description,
        required VoidCallback onTap,
      }) {
    final double cardPadding = kIsWeb ? 12 : 14;
    final double iconBoxPadding = kIsWeb ? 10 : 12;
    final double iconSize = kIsWeb ? 22 : 34;
    final double titleSize = kIsWeb ? 13 : 14;
    final double descSize = 10;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFD4C4A8).withOpacity(0.15),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: const Color(0xFFE0D5C1),
                width: 1.5,
              ),
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
                    borderRadius: BorderRadius.circular(10),
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
                SizedBox(height: kIsWeb ? 8 : 12),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: titleSize,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF6B5B4F),
                    letterSpacing: 0.4,
                  ),
                ),
                SizedBox(height: kIsWeb ? 3 : 6),
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