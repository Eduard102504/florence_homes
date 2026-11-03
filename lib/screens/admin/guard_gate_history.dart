// lib/screens/admin/guard_gate_history.dart
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'dart:async';

import '../guard/guard_dashboard.dart';
import 'manual_entry_screen.dart';
import 'scanner_management_screen.dart';
import 'pending_visits_screen.dart';

class GuardGateHistory extends StatefulWidget {
  const GuardGateHistory({super.key});

  @override
  State<GuardGateHistory> createState() => _GuardGateHistoryState();
}

class _GuardGateHistoryState extends State<GuardGateHistory> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  List<Map<String, dynamic>> _entries = [];
  List<Map<String, dynamic>> _filteredEntries = [];
  String? _errorMessage;
  bool _isLoading = true;

  int _currentPage = 1;
  int _pageSize = 20;

  StreamSubscription<QuerySnapshot>? _entriesSub;

  @override
  void initState() {
    super.initState();
    _startEntriesStream();
  }

  @override
  void dispose() {
    _entriesSub?.cancel();
    super.dispose();
  }

  void _startEntriesStream() {
    _entriesSub = _firestore
        .collection('gate_entries')
        .orderBy('timestamp', descending: true)
        .limit(200)
        .snapshots()
        .listen(
          (snapshot) {
        try {
          final list = snapshot.docs.map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            data['id'] = doc.id;
            return data;
          }).toList();

          if (mounted) {
            setState(() {
              _entries = list;
              _filteredEntries = list;
              _isLoading = false;
              if (_currentPage > _totalPages) _currentPage = _totalPages < 1 ? 1 : _totalPages;
            });
          }
        } catch (e) {
          if (mounted) {
            setState(() {
              _entries = [];
              _filteredEntries = [];
              _errorMessage = 'Error: $e';
              _isLoading = false;
            });
          }
        }
      },
      onError: (e) {
        if (mounted) setState(() { _errorMessage = 'Error: $e'; _isLoading = false; });
      },
    );
  }

  int get _totalPages {
    if (_pageSize == 0) return 1;
    if (_filteredEntries.isEmpty) return 1;
    return ((_filteredEntries.length - 1) ~/ _pageSize) + 1;
  }

  List<Map<String, dynamic>> get _paginatedEntries {
    if (_pageSize == 0) return _filteredEntries;
    final start = (_currentPage - 1) * _pageSize;
    if (start >= _filteredEntries.length) return [];
    final end = (start + _pageSize).clamp(0, _filteredEntries.length);
    return _filteredEntries.sublist(start, end);
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

  Widget _buildPageSizeOptions() {
    const options = <Map<String, dynamic>>[
      {'label': '10', 'value': 10},
      {'label': '20', 'value': 20},
      {'label': '50', 'value': 50},
      {'label': '100', 'value': 100},
      {'label': 'All', 'value': 0},
    ];

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: options.map((opt) {
        final value = opt['value'] as int;
        final isSelected = _pageSize == value;
        return Padding(
          padding: const EdgeInsets.only(left: 4),
          child: GestureDetector(
            onTap: () => _changePageSize(value),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: isSelected ? const Color(0xFFD4C4A8) : Colors.transparent,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: isSelected ? const Color(0xFFD4C4A8) : const Color(0xFFE0D5C1), width: 1),
              ),
              child: Text(
                opt['label'] as String,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  color: isSelected ? const Color(0xFFFFF8F0) : const Color(0xFF8D6E63),
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDesktopWeb = kIsWeb && MediaQuery.of(context).size.width >= 800;

    if (isDesktopWeb) {
      return Scaffold(
        backgroundColor: const Color(0xFFF5F0E8),
        body: Row(
          children: [
            _buildWebSidebar(context),
            Expanded(
              child: Column(
                children: [
                  _buildWebHeader(),
                  Expanded(
                    child: Padding(
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

  Widget _buildWebSidebar(BuildContext context) {
    return Container(
      width: 260,
      color: const Color(0xFF5D4037),
      child: Column(
        children: [
          const SizedBox(height: 40),
          const Icon(Icons.home_work, size: 48, color: Color(0xFFFFF8F0)),
          const SizedBox(height: 12),
          const Text('Florence Homes', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFFFFF8F0), letterSpacing: 1)),
          const Text('Guard Portal', style: TextStyle(fontSize: 12, color: Color(0xFFD4C4A8))),
          const SizedBox(height: 40),
          _buildWebSidebarItem(Icons.dashboard, 'Dashboard', onTap: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const GuardDashboard()))),
          _buildWebSidebarItem(Icons.edit_document, 'Manual Entry', onTap: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const ManualEntryScreen()))),
          _buildWebSidebarItem(Icons.qr_code_scanner, 'QR Scanner', onTap: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const ScannerManagementScreen()))),
          _buildWebSidebarItem(Icons.exit_to_app, 'Pending Visits', onTap: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const PendingVisitsScreen()))),
          _buildWebSidebarItem(Icons.history, 'Gate History', isActive: true, onTap: () {}),
          const Spacer(),
          ListTile(leading: const Icon(Icons.logout, color: Color(0xFFD4C4A8)), title: const Text('Back to Dashboard', style: TextStyle(color: Color(0xFFD4C4A8), fontSize: 13)), onTap: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const GuardDashboard()))),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildWebSidebarItem(IconData icon, String title, {bool isActive = false, required VoidCallback onTap}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListTile(
        onTap: onTap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        tileColor: isActive ? const Color(0xFFD4C4A8).withOpacity(0.15) : Colors.transparent,
        leading: Icon(icon, color: isActive ? const Color(0xFFFFF8F0) : const Color(0xFFD4C4A8)),
        title: Text(title, style: TextStyle(color: isActive ? const Color(0xFFFFF8F0) : const Color(0xFFD4C4A8), fontWeight: isActive ? FontWeight.bold : FontWeight.normal)),
      ),
    );
  }

  Widget _buildWebHeader() {
    return Container(
      height: 80,
      padding: const EdgeInsets.symmetric(horizontal: 32),
      decoration: const BoxDecoration(color: Colors.white, border: Border(bottom: BorderSide(color: Color(0xFFE0D5C1), width: 1))),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text('Gate History', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF5D4037))),
          Row(
            children: [
              _headerIconButton(icon: Icons.refresh, tooltip: 'Refresh', onTap: () { setState(() => _isLoading = true); _startEntriesStream(); }, color: const Color(0xFF8D6E63)),
              const SizedBox(width: 24),
              Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), decoration: BoxDecoration(color: const Color(0xFF4CAF50).withOpacity(0.1), borderRadius: BorderRadius.circular(20), border: Border.all(color: const Color(0xFF4CAF50).withOpacity(0.3))), child: const Row(children: [Icon(Icons.circle, size: 10, color: Color(0xFF4CAF50)), SizedBox(width: 6), Text('LIVE', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF4CAF50)))])),
            ],
          ),
        ],
      ),
    );
  }

  Widget _headerIconButton({required IconData icon, required String tooltip, required VoidCallback onTap, Color color = const Color(0xFF5D4037)}) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12), border: Border.all(color: color.withOpacity(0.3), width: 1)),
          child: Tooltip(message: tooltip, child: Icon(icon, color: color, size: 20)),
        ),
      ),
    );
  }

  Widget _buildWebContent() {
    if (_isLoading) return const Center(child: CircularProgressIndicator(color: Color(0xFF8D6E63)));
    if (_errorMessage != null) return Center(child: Text(_errorMessage!, style: const TextStyle(color: Color(0xFFD32F2F))));
    if (_entries.isEmpty) return const Center(child: Text('No gate entries found.', style: TextStyle(fontSize: 18, color: Color(0xFF8D6E63))));

    final paginated = _paginatedEntries;
    final total = _totalPages;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFE0D5C1)), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 4))]),
          child: Row(
            children: [
              Container(padding: const EdgeInsets.all(14), decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFF5D4037), Color(0xFF8D6E63)]), borderRadius: BorderRadius.circular(12)), child: const Icon(Icons.history, color: Color(0xFFFFF8F0), size: 24)),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Recent Entries', style: TextStyle(fontSize: 13, color: Color(0xFF8D6E63), fontWeight: FontWeight.w500)),
                    const SizedBox(height: 4),
                    Text('${_entries.length}', style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Color(0xFF5D4037))),
                  ],
                ),
              ),
              Row(
                children: [
                  const Text('Per page:', style: TextStyle(fontSize: 11, color: Color(0xFFB8A99A), fontWeight: FontWeight.w500)),
                  const SizedBox(width: 6),
                  _buildPageSizeOptions(),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Expanded(
          child: ListView.builder(
            itemCount: paginated.length,
            itemBuilder: (context, index) {
              final entry = paginated[index];
              final ts = DateTime.tryParse((entry['timestamp'] ?? '').toString()) ?? DateTime.now();
              final entryType = entry['entryType'] ?? 'unknown';
              final residentName = entry['residentName'] ?? 'Unknown';
              final status = entry['status'] ?? 'entry';
              final visitorName = entry['visitorName'];
              final isManualGate = entryType == 'manual_gate';
              final isDelivery = entry['isDelivery'] == true;

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFE0D5C1)), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 4, offset: const Offset(0, 2))]),
                child: Row(
                  children: [
                    Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: _getTypeColor(entryType).withOpacity(0.1), borderRadius: BorderRadius.circular(10)), child: Icon(isDelivery ? Icons.local_shipping : _getTypeIcon(entryType), color: isDelivery ? const Color(0xFFFF9800) : _getTypeColor(entryType), size: 24)),
                    const SizedBox(width: 16),
                    Expanded(flex: 2, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(residentName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF5D4037))), if (visitorName != null) Text('Visitor: $visitorName', style: const TextStyle(fontSize: 12, color: Color(0xFF8D6E63)))])),
                    Expanded(flex: 1, child: Text(_getEntryTypeDisplay(entryType), style: const TextStyle(fontSize: 13, color: Color(0xFF8D6E63)))),
                    Expanded(flex: 1, child: Text(DateFormat('MMM dd, yyyy • hh:mm a').format(ts), style: const TextStyle(fontSize: 13, color: Color(0xFF8D6E63)))),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: isManualGate
                            ? const Color(0xFF6B5B4F).withOpacity(0.1)
                            : (status == 'entry' ? const Color(0xFF4CAF50).withOpacity(0.1) : const Color(0xFFD32F2F).withOpacity(0.1)),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        isManualGate
                            ? (entry['direction'] == 'UP' ? '⬆️ UP' : '⬇️ DOWN')
                            : (status == 'entry' ? '🟢 IN' : '🔴 OUT'),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: isManualGate
                              ? const Color(0xFF6B5B4F)
                              : (status == 'entry' ? const Color(0xFF4CAF50) : const Color(0xFFD32F2F)),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        if (_pageSize != 0 && total > 1)
          Padding(
            padding: const EdgeInsets.only(top: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(onPressed: _currentPage > 1 ? () => _goToPage(1) : null, icon: const Icon(Icons.first_page, size: 20)),
                IconButton(onPressed: _currentPage > 1 ? () => _goToPage(_currentPage - 1) : null, icon: const Icon(Icons.chevron_left, size: 20)),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(color: const Color(0xFFD4C4A8).withOpacity(0.15), borderRadius: BorderRadius.circular(20)),
                  child: Text('Page $_currentPage of $total', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF5D4037))),
                ),
                IconButton(onPressed: _currentPage < total ? () => _goToPage(_currentPage + 1) : null, icon: const Icon(Icons.chevron_right, size: 20)),
                IconButton(onPressed: _currentPage < total ? () => _goToPage(total) : null, icon: const Icon(Icons.last_page, size: 20)),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildMobileHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
      decoration: const BoxDecoration(color: Color(0xFF5D4037), borderRadius: BorderRadius.only(bottomLeft: Radius.circular(30), bottomRight: Radius.circular(30))),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(right: -20, top: -20, child: Icon(Icons.history, size: 120, color: Colors.white.withOpacity(0.05))),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(children: [GestureDetector(onTap: () => Navigator.pop(context), child: Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), borderRadius: BorderRadius.circular(12)), child: const Icon(Icons.arrow_back, color: Color(0xFFFFF8F0), size: 20))), const SizedBox(width: 12), const Text('Gate History', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: Color(0xFFFFF8F0), letterSpacing: 1))]),
                  GestureDetector(onTap: () { setState(() => _isLoading = true); _startEntriesStream(); }, child: Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), borderRadius: BorderRadius.circular(12)), child: const Icon(Icons.refresh, color: Color(0xFFFFF8F0), size: 20))),
                ],
              ),
              const SizedBox(height: 24),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('Live Activity Log', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFFFFF8F0))), Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: const Color(0xFF4CAF50).withOpacity(0.2), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFF4CAF50))), child: const Text('LIVE', style: TextStyle(fontSize: 10, color: Color(0xFF4CAF50), fontWeight: FontWeight.bold)))]),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMobileContent() {
    if (_isLoading) return const Center(child: CircularProgressIndicator(color: Color(0xFFD4C4A8)));
    if (_errorMessage != null) return Center(child: Text(_errorMessage!, style: const TextStyle(color: Color(0xFFD32F2F))));
    if (_entries.isEmpty) return const Center(child: Text('No entries found', style: TextStyle(fontSize: 16, color: Color(0xFF8D6E63))));

    final paginated = _paginatedEntries;
    final total = _totalPages;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Entries:', style: TextStyle(fontSize: 11, color: Color(0xFFB8A99A), fontWeight: FontWeight.w500)),
                  Text('${_entries.length}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF5D4037))),
                  const Spacer(),
                  const Text('Per page:', style: TextStyle(fontSize: 11, color: Color(0xFFB8A99A), fontWeight: FontWeight.w500)),
                  const SizedBox(width: 6),
                  _buildPageSizeOptions(),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: paginated.length,
            itemBuilder: (context, index) {
              final entry = paginated[index];
              final ts = DateTime.tryParse((entry['timestamp'] ?? '').toString()) ?? DateTime.now();
              final entryType = entry['entryType'] ?? 'unknown';
              final residentName = entry['residentName'] ?? 'Unknown';
              final visitorName = entry['visitorName'];
              final status = entry['status'] ?? 'entry';
              final isManualGate = entryType == 'manual_gate';
              final isDelivery = entry['isDelivery'] == true;

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFE0D5C1), width: 1), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 6, offset: const Offset(0, 2))]),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: _getTypeColor(entryType).withOpacity(0.1), borderRadius: BorderRadius.circular(10)), child: Icon(isDelivery ? Icons.local_shipping : _getTypeIcon(entryType), size: 20, color: isDelivery ? const Color(0xFFFF9800) : _getTypeColor(entryType))),
                          const SizedBox(width: 12),
                          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(residentName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF5D4037))), if (visitorName != null) Text('👤 $visitorName', style: const TextStyle(fontSize: 12, color: Color(0xFF8D6E63)))])),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: isManualGate
                                  ? const Color(0xFF6B5B4F).withOpacity(0.1)
                                  : (status == 'entry' ? const Color(0xFF4CAF50).withOpacity(0.1) : const Color(0xFFD32F2F).withOpacity(0.1)),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isManualGate
                                    ? const Color(0xFF6B5B4F).withOpacity(0.3)
                                    : (status == 'entry' ? const Color(0xFF4CAF50).withOpacity(0.3) : const Color(0xFFD32F2F).withOpacity(0.3)),
                              ),
                            ),
                            child: Text(
                              isManualGate
                                  ? (entry['direction'] == 'UP' ? '⬆️ UP' : '⬇️ DOWN')
                                  : (status == 'entry' ? '🟢 IN' : '🔴 OUT'),
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: isManualGate
                                    ? const Color(0xFF6B5B4F)
                                    : (status == 'entry' ? const Color(0xFF4CAF50) : const Color(0xFFD32F2F)),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const Divider(color: Color(0xFFE0D5C1), height: 24),
                      _mobileInfoRow(Icons.access_time, 'Time', DateFormat('MMM dd, yyyy • hh:mm a').format(ts)),
                      const SizedBox(height: 6),
                      _mobileInfoRow(Icons.category, 'Type', _getEntryTypeDisplay(entryType)),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        if (_pageSize != 0 && total > 1)
          Padding(
            padding: const EdgeInsets.all(20),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFE0D5C1))),
              child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [IconButton(onPressed: _currentPage > 1 ? () => _goToPage(_currentPage - 1) : null, icon: const Icon(Icons.chevron_left, color: Color(0xFF8D6E63))), Text('Page $_currentPage of $total', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF5D4037))), IconButton(onPressed: _currentPage < total ? () => _goToPage(_currentPage + 1) : null, icon: const Icon(Icons.chevron_right, color: Color(0xFF8D6E63)))]),
            ),
          ),
      ],
    );
  }

  Widget _mobileInfoRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 14, color: const Color(0xFFD4C4A8)),
        const SizedBox(width: 8),
        SizedBox(width: 100, child: Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF8D6E63), fontWeight: FontWeight.w500))),
        Expanded(child: Text(value, style: const TextStyle(fontSize: 12, color: Color(0xFF5D4037), fontWeight: FontWeight.bold))),
      ],
    );
  }

  String _getEntryTypeDisplay(String? type) {
    switch (type) {
      case 'uhf_rfid': case 'rfid': return 'RFID';
      case 'qr_visitor': return 'QR Visitor';
      case 'manual': return 'Manual Entry';
      case 'manual_gate': return 'Manual Gate';
      default: return type?.toUpperCase() ?? 'UNKNOWN';
    }
  }

  IconData _getTypeIcon(String type) {
    switch (type) { case 'rfid': case 'uhf_rfid': return Icons.nfc; case 'qr_visitor': return Icons.qr_code; case 'manual': return Icons.person; case 'manual_gate': return Icons.swap_vert; default: return Icons.door_front_door; }
  }

  Color _getTypeColor(String type) {
    switch (type) { case 'rfid': case 'uhf_rfid': return const Color(0xFFD4C4A8); case 'qr_visitor': return const Color(0xFFC4A882); case 'manual': return const Color(0xFFB8A99A); case 'manual_gate': return const Color(0xFF6B5B4F); default: return const Color(0xFF8D6E63); }
  }
}