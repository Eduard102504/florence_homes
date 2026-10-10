// lib/screens/admin/pending_visits_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class PendingVisitsScreen extends StatefulWidget {
  const PendingVisitsScreen({super.key});

  @override
  State<PendingVisitsScreen> createState() => _PendingVisitsScreenState();
}

class _PendingVisitsScreenState extends State<PendingVisitsScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  List<Map<String, dynamic>> _visits = [];
  List<Map<String, dynamic>> _filteredVisits = [];
  bool _isLoading = true;
  String? _errorMessage;
  bool _isProcessing = false;

  // ==================== SEARCH + PAGINATION ====================
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  int _currentPage = 1;
  int _pageSize = 10; // 0 = All

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

  // ==================== SEARCH + PAGINATION HELPERS ====================
  void _applyFiltersInternal() {
    if (_searchQuery.isEmpty) {
      _filteredVisits = List.from(_visits);
    } else {
      final q = _searchQuery.toLowerCase();
      _filteredVisits = _visits.where((v) {
        return (v['visitorName'] ?? '')
            .toString()
            .toLowerCase()
            .contains(q) ||
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
    final total = _totalPages;
    if (page < 1 || page > total) return;
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
              style:
              const TextStyle(fontSize: 13, color: Color(0xFF6B5B4F)),
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

      await _firestore
          .collection('gate_entries')
          .doc(visit['id'])
          .update({
        'visitStatus': 'outside',
        'checkOutTime': exitTime,
      });

      await _firestore.collection('gate_entries').add({
        'residentId': visit['visitingResidentId'] ?? 'guest',
        'residentName': '👤 Guest Exit: ${visit['visitorName']}',
        'entryType': 'manual',
        'timestamp': exitTime,
        'visitorName': visit['visitorName'],
        'status': 'exit',
        'isGuestExit': true,
        'originalEntryId': visit['id'],
        'visitingResidentName': visit['visitingResidentName'],
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
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: const [
            Icon(Icons.exit_to_app, size: 20, color: Color(0xFFFFF8F0)),
            SizedBox(width: 8),
            Text(
              'Pending Visits',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                letterSpacing: 1,
                fontSize: 15,
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFFD4C4A8),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, size: 20),
            onPressed: _isProcessing ? null : _loadPendingVisits,
            color: const Color(0xFFFFF8F0),
            tooltip: 'Refresh',
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
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: kIsWeb ? 900 : double.infinity,
              ),
              child: _buildBody(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    final padding = kIsWeb ? 20.0 : 16.0;

    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFD4C4A8)),
            ),
            SizedBox(height: 16),
            Text('Loading pending visits...',
                style: TextStyle(color: Color(0xFFB8A99A))),
          ],
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error, size: 48, color: Color(0xFFD32F2F)),
            const SizedBox(height: 16),
            Text(_errorMessage!,
                style: const TextStyle(color: Color(0xFF8D6E63))),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadPendingVisits,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFD4C4A8),
                foregroundColor: const Color(0xFF6B5B4F),
              ),
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    final paginated = _paginatedVisits;
    final total = _totalPages;

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: EdgeInsets.fromLTRB(
          padding, kIsWeb ? 12 : 8, padding, padding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ==================== SEARCH + COUNT + PAGE SIZE ====================
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE0D5C1), width: 1),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFD4C4A8).withOpacity(0.15),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              children: [
                TextField(
                  controller: _searchController,
                  onChanged: _onSearchChanged,
                  decoration: InputDecoration(
                    hintText: 'Search visitor or resident...',
                    hintStyle: const TextStyle(
                        color: Color(0xFFB8A99A), fontSize: 12),
                    prefixIcon: const Icon(Icons.search,
                        color: Color(0xFFD4C4A8), size: 20),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                      icon: const Icon(Icons.clear,
                          size: 18, color: Color(0xFFB8A99A)),
                      onPressed: _clearSearch,
                      tooltip: 'Clear',
                    )
                        : null,
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 4, vertical: 12),
                  ),
                ),
                const Divider(color: Color(0xFFF5F0E8), height: 1),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.person_pin_circle,
                        size: 14, color: Color(0xFFFF9800)),
                    const SizedBox(width: 6),
                    Text(
                      '${_filteredVisits.length} inside',
                      style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFF8D6E63),
                          fontWeight: FontWeight.w600),
                    ),
                    const Spacer(),
                    const Text('Per page:',
                        style: TextStyle(
                            fontSize: 11,
                            color: Color(0xFFB8A99A),
                            fontWeight: FontWeight.w500)),
                    const SizedBox(width: 6),
                    ..._pageSizeOptions(),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // ==================== SUMMARY CARD ====================
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF8D6E63), Color(0xFFD4C4A8)],
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF8D6E63).withOpacity(0.3),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.25),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.exit_to_app,
                      color: Colors.white, size: 26),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'VISITORS INSIDE',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.2,
                          color: Color(0xFFFFF8F0),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _visits.length.toString(),
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // ==================== RESULTS ====================
          if (paginated.isEmpty)
            Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border:
                Border.all(color: const Color(0xFFE0D5C1), width: 1),
              ),
              child: Column(
                children: [
                  Icon(
                    _visits.isEmpty ? Icons.check_circle : Icons.search_off,
                    size: 56,
                    color: const Color(0xFFD4C4A8),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _visits.isEmpty
                        ? ' No visitors inside'
                        : 'No matches found',
                    style: const TextStyle(
                      fontSize: 14,
                      color: Color(0xFF6B5B4F),
                      fontWeight: FontWeight.w600,
                    ),
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
                return _buildVisitCard(paginated[index], globalIndex);
              },
            ),

          const SizedBox(height: 12),

          // ==================== PAGINATION CONTROLS ====================
          if (_pageSize != 0 && total > 1)
            Container(
              padding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border:
                Border.all(color: const Color(0xFFE0D5C1), width: 1),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFD4C4A8).withOpacity(0.15),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.first_page, size: 20),
                    onPressed: _currentPage > 1 ? () => _goToPage(1) : null,
                    color: const Color(0xFF8D6E63),
                    disabledColor: const Color(0xFFE0D5C1),
                    tooltip: 'First page',
                  ),
                  IconButton(
                    icon: const Icon(Icons.chevron_left, size: 20),
                    onPressed: _currentPage > 1
                        ? () => _goToPage(_currentPage - 1)
                        : null,
                    color: const Color(0xFF8D6E63),
                    disabledColor: const Color(0xFFE0D5C1),
                    tooltip: 'Previous page',
                  ),
                  Expanded(
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color:
                          const Color(0xFFD4C4A8).withOpacity(0.15),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          'Page $_currentPage of $total',
                          style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xFF6B5B4F),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.chevron_right, size: 20),
                    onPressed: _currentPage < total
                        ? () => _goToPage(_currentPage + 1)
                        : null,
                    color: const Color(0xFF8D6E63),
                    disabledColor: const Color(0xFFE0D5C1),
                    tooltip: 'Next page',
                  ),
                  IconButton(
                    icon: const Icon(Icons.last_page, size: 20),
                    onPressed: _currentPage < total
                        ? () => _goToPage(total)
                        : null,
                    color: const Color(0xFF8D6E63),
                    disabledColor: const Color(0xFFE0D5C1),
                    tooltip: 'Last page',
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  // ==================== VISIT CARD ====================
  Widget _buildVisitCard(Map<String, dynamic> visit, int index) {
    final checkIn =
    DateTime.tryParse((visit['checkInTime'] ?? '').toString());

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFD4C4A8).withOpacity(0.15),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: const Color(0xFFFF9800).withOpacity(0.4), width: 1.5),
        ),
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        const Color(0xFFFF9800).withOpacity(0.2),
                        const Color(0xFFFF9800).withOpacity(0.1),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.person,
                      size: 24, color: Color(0xFFFF9800)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            '#$index',
                            style: const TextStyle(
                              fontSize: 10,
                              color: Color(0xFFB8A99A),
                              fontFamily: 'monospace',
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              visit['visitorName'] ?? 'Unknown',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF6B5B4F),
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Visiting: ${visit['visitingResidentName'] ?? 'Unknown'}',
                        style: const TextStyle(
                            fontSize: 11, color: Color(0xFF8D6E63)),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 4),
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
                      fontSize: 9,
                    ),
                  ),
                ),
              ],
            ),

            const Divider(color: Color(0xFFE0D5C1), height: 20),

            if ((visit['visitingResidentHouse'] ?? '').toString().isNotEmpty)
              _infoRow(Icons.home, '🏠 House',
                  visit['visitingResidentHouse'].toString()),
            if (checkIn != null) ...[
              const SizedBox(height: 6),
              _infoRow(
                Icons.login,
                '📥 Check-In',
                DateFormat('MMM dd, yyyy • hh:mm a').format(checkIn),
              ),
            ],
            if ((visit['note'] ?? '').toString().isNotEmpty) ...[
              const SizedBox(height: 6),
              _infoRow(Icons.notes, '📝 Note', visit['note'].toString()),
            ],

            const SizedBox(height: 14),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed:
                _isProcessing ? null : () => _markExit(visit),
                icon: const Icon(Icons.logout, size: 16),
                label: const Text('Mark as OUT (Return ID)'),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 44),
                  backgroundColor: const Color(0xFF4CAF50),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  textStyle: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==================== PAGE SIZE CHIPS ====================
  List<Widget> _pageSizeOptions() {
    const options = <Map<String, dynamic>>[
      {'label': '5', 'value': 5},
      {'label': '10', 'value': 10},
      {'label': '20', 'value': 20},
      {'label': '50', 'value': 50},
      {'label': 'All', 'value': 0},
    ];

    return options.map((opt) {
      final value = opt['value'] as int;
      final isSelected = _pageSize == value;
      return Padding(
        padding: const EdgeInsets.only(left: 4),
        child: GestureDetector(
          onTap: () => _changePageSize(value),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: isSelected
                  ? const Color(0xFFD4C4A8)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isSelected
                    ? const Color(0xFFD4C4A8)
                    : const Color(0xFFE0D5C1),
                width: 1,
              ),
            ),
            child: Text(
              opt['label'] as String,
              style: TextStyle(
                fontSize: 10,
                fontWeight:
                isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected
                    ? const Color(0xFFFFF8F0)
                    : const Color(0xFF8D6E63),
              ),
            ),
          ),
        ),
      );
    }).toList();
  }

  // ==================== INFO ROW ====================
  Widget _infoRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 14, color: const Color(0xFFD4C4A8)),
        const SizedBox(width: 8),
        SizedBox(
          width: 76,
          child: Text(
            label,
            style: const TextStyle(
                fontSize: 11,
                color: Color(0xFFB8A99A),
                fontWeight: FontWeight.w500),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
                fontSize: 11, color: Color(0xFF6B5B4F)),
          ),
        ),
      ],
    );
  }
}