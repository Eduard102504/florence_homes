// lib/screens/admin/pending_visits_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../services/auth_service.dart';

class PendingVisitsScreen extends StatefulWidget {
  const PendingVisitsScreen({super.key});

  @override
  State<PendingVisitsScreen> createState() => _PendingVisitsScreenState();
}

class _PendingVisitsScreenState extends State<PendingVisitsScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final AuthService _authService = AuthService();

  List<Map<String, dynamic>> _visits = [];
  List<Map<String, dynamic>> _filteredVisits = [];
  bool _isLoading = true;
  String? _errorMessage;
  bool _isProcessing = false;

  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  int _currentPage = 1;
  int _pageSize = 10;

  @override
  void initState() {
    super.initState();
    _loadPendingVisits();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // ==================== LOAD ====================
  Future<void> _loadPendingVisits() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final snapshot = await _firestore
          .collection('gate_entries')
          .where('isGuest', isEqualTo: true)
          .where('visitStatus', isEqualTo: 'inside')
          .get();

      final list = snapshot.docs.map((doc) {
        final d = doc.data();
        d['id'] = doc.id;
        return d;
      }).toList();

      list.sort((a, b) {
        final ta = (a['checkInTime'] ?? '').toString();
        final tb = (b['checkInTime'] ?? '').toString();
        return tb.compareTo(ta);
      });

      if (mounted) {
        setState(() {
          _visits = list;
          _applyFiltersInternal();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Error: $e';
          _isLoading = false;
        });
      }
    }
  }

  // ==================== FILTERS + PAGINATION ====================
  void _applyFiltersInternal() {
    if (_searchQuery.isEmpty) {
      _filteredVisits = List.from(_visits);
    } else {
      final q = _searchQuery.toLowerCase();
      _filteredVisits = _visits.where((v) {
        return (v['visitorName'] ?? '').toString().toLowerCase().contains(q) ||
            (v['visitingResidentName'] ?? '')
                .toString()
                .toLowerCase()
                .contains(q) ||
            (v['visitingResidentHouse'] ?? '')
                .toString()
                .toLowerCase()
                .contains(q);
      }).toList();
    }

    if (_currentPage > _totalPages) {
      _currentPage = _totalPages < 1 ? 1 : _totalPages;
    }
  }

  void _onSearchChanged(String value) {
    setState(() {
      _searchQuery = value;
      _currentPage = 1;
      _applyFiltersInternal();
    });
  }

  void _clearSearch() {
    _searchController.clear();
    setState(() {
      _searchQuery = '';
      _currentPage = 1;
      _applyFiltersInternal();
    });
  }

  int get _totalPages {
    if (_pageSize == 0) return 1;
    if (_filteredVisits.isEmpty) return 1;
    return ((_filteredVisits.length - 1) ~/ _pageSize) + 1;
  }

  List<Map<String, dynamic>> get _paginatedVisits {
    if (_pageSize == 0) return _filteredVisits;
    final start = (_currentPage - 1) * _pageSize;
    if (start >= _filteredVisits.length) return [];
    final end = (start + _pageSize).clamp(0, _filteredVisits.length);
    return _filteredVisits.sublist(start, end);
  }

  void _goToPage(int page) {
    if (page < 1 || page > _totalPages) return;
    setState(() => _currentPage = page);
  }

  void _changePageSize(int newSize) {
    setState(() {
      _pageSize = newSize;
      _currentPage = 1;
    });
  }

  // ==================== MARK EXIT ====================
  Future<void> _markExit(Map<String, dynamic> visit) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFFFFF8F0),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: Color(0xFFE0D5C1), width: 1.5),
        ),
        title: Row(
          children: const [
            Icon(Icons.logout, color: Color(0xFF4CAF50), size: 24),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Confirm Exit',
                style: TextStyle(
                  color: Color(0xFF5D4037),
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Mark ${visit['visitorName']} as OUT?',
              style: const TextStyle(fontSize: 13, color: Color(0xFF6B5B4F)),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF4CAF50).withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: const Color(0xFF4CAF50).withOpacity(0.3)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.badge_outlined,
                      size: 16, color: Color(0xFF4CAF50)),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Return the visitor\'s ID before completing the exit.',
                      style: TextStyle(
                        fontSize: 11,
                        color: Color(0xFF4CAF50),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            style: TextButton.styleFrom(
                foregroundColor: const Color(0xFFB8A99A)),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4CAF50),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Mark as OUT'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isProcessing = true);

    try {
      final exitTime = DateTime.now().toIso8601String();

      final guardId = _authService.getCurrentUserId();
      String guardName = 'Staff';
      if (guardId != null) {
        final guardDoc =
        await _firestore.collection('users').doc(guardId).get();
        guardName = guardDoc.get('fullName') ?? 'Staff';
      }

      await _firestore
          .collection('gate_entries')
          .doc(visit['id'])
          .update({
        'visitStatus': 'outside',
        'checkOutTime': exitTime,
        'closedBy': guardName,
        'closedById': guardId,
      });

      await _firestore.collection('gate_entries').add({
        'residentId': visit['visitingResidentId'] ?? 'guest',
        'residentName': '👤 Guest Exit: ${visit['visitorName']}',
        'entryType': visit['entryType'] ?? 'manual',
        'timestamp': exitTime,
        'visitorName': visit['visitorName'],
        'status': 'exit',
        'isGuestExit': true,
        'originalEntryId': visit['id'],
        'visitingResidentName': visit['visitingResidentName'],
        'openedBy': guardName,
        'openedById': guardId,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ ${visit['visitorName']} marked as OUT'),
            backgroundColor: const Color(0xFF4CAF50),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }

      _loadPendingVisits();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: const Color(0xFFD32F2F),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  // ==================== BUILD ====================
  @override
  Widget build(BuildContext context) {
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

    return Scaffold(
      backgroundColor: const Color(0xFFF5F0E8),
      body: SafeArea(
        child: Column(
          children: [
            _buildMobileHeader(),
            Expanded(child: _buildMobileContent()),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // 🖥️ WEB COMPONENTS
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
          const Text('Florence Homes',
              style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFFFF8F0),
                  letterSpacing: 1)),
          const Text('Admin Portal',
              style: TextStyle(fontSize: 12, color: Color(0xFFD4C4A8))),
          const SizedBox(height: 40),
          _buildWebSidebarItem(Icons.dashboard, 'Dashboard',
              onTap: () => Navigator.pop(context)),
          _buildWebSidebarItem(Icons.people, 'Residents',
              onTap: () => Navigator.pop(context)),
          _buildWebSidebarItem(Icons.security, 'Guards',
              onTap: () => Navigator.pop(context)),
          _buildWebSidebarItem(Icons.pending_actions, 'Pending Approvals',
              onTap: () => Navigator.pop(context)),
          _buildWebSidebarItem(Icons.history, 'Gate History',
              onTap: () => Navigator.pop(context)),
          const Spacer(),
          ListTile(
            leading: const Icon(Icons.logout, color: Color(0xFFD4C4A8)),
            title: const Text('Back to Dashboard',
                style: TextStyle(color: Color(0xFFD4C4A8), fontSize: 13)),
            onTap: () => Navigator.pop(context),
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

  Widget _buildWebHeader() {
    return Container(
      height: 80,
      padding: const EdgeInsets.symmetric(horizontal: 32),
      decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(bottom: BorderSide(color: Color(0xFFE0D5C1), width: 1))),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text('Pending Visits',
              style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF5D4037))),
          Row(
            children: [
              _headerIconButton(
                  icon: Icons.refresh,
                  tooltip: 'Refresh',
                  onTap: _isProcessing ? () {} : _loadPendingVisits,
                  color: const Color(0xFF8D6E63)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _headerIconButton(
      {required IconData icon,
        required String tooltip,
        required VoidCallback onTap,
        Color color = const Color(0xFF5D4037)}) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: color.withOpacity(0.3))),
          child:
          Tooltip(message: tooltip, child: Icon(icon, color: color, size: 20)),
        ),
      ),
    );
  }

  Widget _buildWebContent() {
    if (_isLoading) {
      return const Center(
          child: CircularProgressIndicator(color: Color(0xFF8D6E63)));
    }
    if (_errorMessage != null) {
      return Center(
          child: Text(_errorMessage!,
              style: const TextStyle(color: Color(0xFFD32F2F))));
    }

    final paginated = _paginatedVisits;
    final total = _totalPages;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Stat Row
        Row(
          children: [
            _buildWebStatCard('Visitors Inside', _visits.length.toString(),
                Icons.exit_to_app, const Color(0xFFFF9800)),
            const SizedBox(width: 20),
            _buildWebStatCard('Filtered', _filteredVisits.length.toString(),
                Icons.filter_alt, const Color(0xFF8D6E63)),
          ],
        ),
        const SizedBox(height: 24),

        // Search
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE0D5C1))),
          child: Row(
            children: [
              const Icon(Icons.search, color: Color(0xFF8D6E63)),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _searchController,
                  onChanged: _onSearchChanged,
                  decoration: const InputDecoration(
                      hintText: 'Search visitor, resident, or house...',
                      border: InputBorder.none,
                      isDense: true),
                ),
              ),
              if (_searchQuery.isNotEmpty)
                IconButton(
                    icon: const Icon(Icons.clear, size: 20),
                    onPressed: _clearSearch),
            ],
          ),
        ),
        const SizedBox(height: 24),

        if (paginated.isEmpty)
          Container(
            padding: const EdgeInsets.all(40),
            decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE0D5C1))),
            child: Center(
              child: Column(
                children: [
                  Icon(
                      _visits.isEmpty ? Icons.check_circle : Icons.search_off,
                      size: 56,
                      color: const Color(0xFFD4C4A8)),
                  const SizedBox(height: 12),
                  Text(
                    _visits.isEmpty
                        ? 'No visitors inside'
                        : 'No matches found',
                    style: const TextStyle(
                        fontSize: 16,
                        color: Color(0xFF5D4037),
                        fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _visits.isEmpty
                        ? 'All guests have checked out'
                        : 'Try a different search term',
                    style: const TextStyle(
                        fontSize: 12, color: Color(0xFF8D6E63)),
                  ),
                ],
              ),
            ),
          )
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: paginated.length,
            itemBuilder: (context, index) {
              return _buildWebVisitRow(paginated[index]);
            },
          ),

        if (_pageSize != 0 && total > 1)
          Padding(
            padding: const EdgeInsets.only(top: 24),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                    onPressed:
                    _currentPage > 1 ? () => _goToPage(_currentPage - 1) : null,
                    icon: const Icon(Icons.chevron_left)),
                Text('Page $_currentPage of $total',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF5D4037))),
                IconButton(
                    onPressed: _currentPage < total
                        ? () => _goToPage(_currentPage + 1)
                        : null,
                    icon: const Icon(Icons.chevron_right)),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildWebStatCard(
      String title, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
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
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12)),
                child: Icon(icon, size: 24, color: color)),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF8D6E63),
                        fontWeight: FontWeight.w500)),
                const SizedBox(height: 4),
                Text(value,
                    style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: color)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWebVisitRow(Map<String, dynamic> visit) {
    final checkIn = DateTime.tryParse((visit['checkInTime'] ?? '').toString());

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE0D5C1)),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.02),
                blurRadius: 4,
                offset: const Offset(0, 2))
          ]),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
                color: const Color(0xFFFF9800).withOpacity(0.1),
                borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.person,
                color: Color(0xFFFF9800), size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(visit['visitorName'] ?? 'Unknown',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: Color(0xFF5D4037))),
                Text(
                    'Visiting: ${visit['visitingResidentName'] ?? 'Unknown'}',
                    style: const TextStyle(
                        fontSize: 12, color: Color(0xFF8D6E63))),
              ],
            ),
          ),
          Expanded(
              flex: 1,
              child: Text(visit['visitingResidentHouse'] ?? '—',
                  style: const TextStyle(
                      fontSize: 13, color: Color(0xFF8D6E63)))),
          Expanded(
              flex: 1,
              child: Text(
                  checkIn != null
                      ? DateFormat('MMM dd, yyyy • hh:mm a').format(checkIn)
                      : '—',
                  style: const TextStyle(
                      fontSize: 13, color: Color(0xFF8D6E63)))),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
                color: const Color(0xFFFF9800).withOpacity(0.15),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                    color: const Color(0xFFFF9800).withOpacity(0.3))),
            child: const Text('● INSIDE',
                style: TextStyle(
                    color: Color(0xFFFF9800),
                    fontWeight: FontWeight.bold,
                    fontSize: 10)),
          ),
          const SizedBox(width: 12),
          ElevatedButton.icon(
            onPressed: _isProcessing ? null : () => _markExit(visit),
            icon: const Icon(Icons.logout, size: 14),
            label: const Text('Mark as OUT'),
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4CAF50),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
                elevation: 0),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // 📱 MOBILE COMPONENTS
  // ============================================================

  Widget _buildMobileHeader() {
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
              child: Icon(Icons.exit_to_app,
                  size: 120, color: Colors.white.withOpacity(0.05))),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(12)),
                          child: const Icon(Icons.arrow_back,
                              color: Color(0xFFFFF8F0), size: 20),
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Text('Pending Visits',
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 20,
                              color: Color(0xFFFFF8F0),
                              letterSpacing: 1)),
                    ],
                  ),
                  GestureDetector(
                    onTap: _isProcessing ? null : _loadPendingVisits,
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(12)),
                      child: const Icon(Icons.refresh,
                          color: Color(0xFFFFF8F0), size: 20),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Visitors Inside',
                      style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFFFFF8F0))),
                  Container(
                    padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                        color: const Color(0xFFFF9800).withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFFF9800))),
                    child: Text(
                      '${_visits.length}',
                      style: const TextStyle(
                          fontSize: 14,
                          color: Color(0xFFFF9800),
                          fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMobileContent() {
    if (_isLoading) {
      return const Center(
          child: CircularProgressIndicator(color: Color(0xFFD4C4A8)));
    }
    if (_errorMessage != null) {
      return Center(
          child: Text(_errorMessage!,
              style: const TextStyle(color: Color(0xFFD32F2F))));
    }

    final paginated = _paginatedVisits;
    final total = _totalPages;

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Search
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE0D5C1))),
            child: TextField(
              controller: _searchController,
              onChanged: _onSearchChanged,
              decoration: const InputDecoration(
                  hintText: 'Search visitor or resident...',
                  hintStyle:
                  TextStyle(fontSize: 13, color: Color(0xFFB8A99A)),
                  border: InputBorder.none,
                  isDense: true),
            ),
          ),
          const SizedBox(height: 16),

          if (paginated.isEmpty)
            Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE0D5C1))),
              child: Column(
                children: [
                  Icon(
                      _visits.isEmpty ? Icons.check_circle : Icons.search_off,
                      size: 56,
                      color: const Color(0xFFD4C4A8)),
                  const SizedBox(height: 12),
                  Text(
                    _visits.isEmpty
                        ? 'No visitors inside'
                        : 'No matches found',
                    style: const TextStyle(
                        fontSize: 14,
                        color: Color(0xFF6B5B4F),
                        fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _visits.isEmpty
                        ? 'All guests have checked out'
                        : 'Try a different search term',
                    style: const TextStyle(
                        fontSize: 12, color: Color(0xFFB8A99A)),
                  ),
                ],
              ),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: paginated.length,
              itemBuilder: (context, index) {
                final globalIndex = _pageSize == 0
                    ? index + 1
                    : ((_currentPage - 1) * _pageSize) + index + 1;
                return _buildMobileVisitCard(paginated[index], globalIndex);
              },
            ),

          if (_pageSize != 0 && total > 1)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Container(
                padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE0D5C1))),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                        onPressed: _currentPage > 1
                            ? () => _goToPage(_currentPage - 1)
                            : null,
                        icon: const Icon(Icons.chevron_left,
                            color: Color(0xFF8D6E63))),
                    Text('Page $_currentPage of $total',
                        style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF5D4037))),
                    IconButton(
                        onPressed: _currentPage < total
                            ? () => _goToPage(_currentPage + 1)
                            : null,
                        icon: const Icon(Icons.chevron_right,
                            color: Color(0xFF8D6E63))),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildMobileVisitCard(Map<String, dynamic> visit, int index) {
    final checkIn = DateTime.tryParse((visit['checkInTime'] ?? '').toString());

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: const Color(0xFFFF9800).withOpacity(0.4), width: 1.5),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 6,
              offset: const Offset(0, 2))
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF9800).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.person,
                      size: 22, color: Color(0xFFFF9800)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text('#$index',
                              style: const TextStyle(
                                  fontSize: 10,
                                  color: Color(0xFFB8A99A),
                                  fontFamily: 'monospace',
                                  fontWeight: FontWeight.w600)),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              visit['visitorName'] ?? 'Unknown',
                              style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF5D4037)),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Visiting: ${visit['visitingResidentName'] ?? 'Unknown'}',
                        style: const TextStyle(
                            fontSize: 12, color: Color(0xFF8D6E63)),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Container(
                  padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF9800).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                        color: const Color(0xFFFF9800).withOpacity(0.3)),
                  ),
                  child: const Text(
                    '● INSIDE',
                    style: TextStyle(
                        color: Color(0xFFFF9800),
                        fontWeight: FontWeight.bold,
                        fontSize: 9),
                  ),
                ),
              ],
            ),
            const Divider(color: Color(0xFFE0D5C1), height: 24),
            if ((visit['visitingResidentHouse'] ?? '').toString().isNotEmpty)
              _mobileInfoRow(Icons.home, 'House',
                  visit['visitingResidentHouse'].toString()),
            if (checkIn != null) ...[
              const SizedBox(height: 6),
              _mobileInfoRow(
                  Icons.login,
                  'Check-In',
                  DateFormat('MMM dd, yyyy • hh:mm a').format(checkIn)),
            ],
            if ((visit['note'] ?? '').toString().isNotEmpty) ...[
              const SizedBox(height: 6),
              _mobileInfoRow(
                  Icons.notes, 'Note', visit['note'].toString()),
            ],
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isProcessing ? null : () => _markExit(visit),
                icon: const Icon(Icons.logout, size: 16),
                label: const Text('Mark as OUT (Return ID)'),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 44),
                  backgroundColor: const Color(0xFF4CAF50),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  textStyle: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _mobileInfoRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 14, color: const Color(0xFFD4C4A8)),
        const SizedBox(width: 8),
        SizedBox(
          width: 70,
          child: Text(label,
              style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF8D6E63),
                  fontWeight: FontWeight.w500)),
        ),
        Expanded(
          child: Text(value,
              style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF5D4037),
                  fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }
}