// lib/screens/admin/resident_records_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:intl/intl.dart';
import 'package:csv/csv.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'dart:io';
import '../../models/resident_record_model.dart';
import '../../services/archive_service.dart';

class ResidentRecordsScreen extends StatefulWidget {
  const ResidentRecordsScreen({super.key});

  @override
  State<ResidentRecordsScreen> createState() => _ResidentRecordsScreenState();
}

class _ResidentRecordsScreenState extends State<ResidentRecordsScreen> {
  final ArchiveService _archiveService = ArchiveService();
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  DateTimeRange? _dateRange;
  bool _isExporting = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<ResidentRecordModel> _filter(List<ResidentRecordModel> list) {
    var filtered = list;

    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      filtered = filtered.where((r) {
        return r.fullName.toLowerCase().contains(q) ||
            r.email.toLowerCase().contains(q) ||
            (r.residentId?.toLowerCase().contains(q) ?? false) ||
            (r.houseNumber?.toLowerCase().contains(q) ?? false);
      }).toList();
    }

    if (_dateRange != null) {
      filtered = filtered.where((r) {
        return r.recordedAt.isAfter(_dateRange!.start) &&
            r.recordedAt
                .isBefore(_dateRange!.end.add(const Duration(days: 1)));
      }).toList();
    }

    return filtered;
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
                  Expanded(child: _buildWebContent()),
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
          const Text('Resident Records',
              style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF5D4037))),
          Row(
            children: [
              _headerIconButton(
                  icon: Icons.filter_alt_outlined,
                  tooltip: 'Filter by date',
                  onTap: _pickDateRange,
                  color: const Color(0xFF8D6E63)),
              const SizedBox(width: 12),
              _headerIconButton(
                  icon: Icons.picture_as_pdf,
                  tooltip: 'Export PDF',
                  onTap: _isExporting ? () {} : _exportPDF,
                  showSpinner: _isExporting,
                  color: const Color(0xFFD32F2F)),
              const SizedBox(width: 12),
              _headerIconButton(
                  icon: Icons.table_chart_outlined,
                  tooltip: 'Export CSV',
                  onTap: _isExporting ? () {} : _exportCSV,
                  color: const Color(0xFF4CAF50)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _headerIconButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
    bool showSpinner = false,
    Color color = const Color(0xFF5D4037),
  }) {
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
          child: Tooltip(
            message: tooltip,
            child: showSpinner
                ? SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(color)),
            )
                : Icon(icon, color: color, size: 20),
          ),
        ),
      ),
    );
  }

  Widget _buildWebContent() {
    return StreamBuilder<List<ResidentRecordModel>>(
      stream: _archiveService.streamResidentRecords(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
              child: CircularProgressIndicator(color: Color(0xFF8D6E63)));
        }

        final all = snapshot.data ?? [];
        final filtered = _filter(all);

        return SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Info banner
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                    color: const Color(0xFF8D6E63).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: const Color(0xFF8D6E63).withOpacity(0.3))),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline,
                        size: 18, color: Color(0xFF8D6E63)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Read-only permanent history · ${all.length} records · never auto-deleted',
                        style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF5D4037),
                            height: 1.4),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Search + date chip
              Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border:
                          Border.all(color: const Color(0xFFE0D5C1))),
                      child: Row(
                        children: [
                          const Icon(Icons.search, color: Color(0xFF8D6E63)),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextField(
                              controller: _searchController,
                              onChanged: (v) =>
                                  setState(() => _searchQuery = v),
                              decoration: const InputDecoration(
                                  hintText:
                                  'Search by name, ID, house, or email...',
                                  border: InputBorder.none,
                                  isDense: true),
                            ),
                          ),
                          if (_searchQuery.isNotEmpty)
                            IconButton(
                                icon: const Icon(Icons.clear, size: 20),
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() => _searchQuery = '');
                                }),
                        ],
                      ),
                    ),
                  ),
                  if (_dateRange != null) ...[
                    const SizedBox(width: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border:
                          Border.all(color: const Color(0xFFE0D5C1))),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '📅 ${DateFormat('MMM dd').format(_dateRange!.start)} → ${DateFormat('MMM dd').format(_dateRange!.end)}',
                            style: const TextStyle(
                                fontSize: 12, color: Color(0xFF5D4037)),
                          ),
                          const SizedBox(width: 6),
                          InkWell(
                            onTap: () => setState(() => _dateRange = null),
                            child: const Icon(Icons.close,
                                size: 16, color: Color(0xFF8D6E63)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 24),

              // Records list
              if (all.isEmpty)
                Container(
                  padding: const EdgeInsets.all(40),
                  decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFE0D5C1))),
                  child: const Center(
                    child: Column(
                      children: [
                        Icon(Icons.library_books_outlined,
                            size: 70, color: Color(0xFFE0D5C1)),
                        SizedBox(height: 16),
                        Text('No records yet',
                            style: TextStyle(
                                fontSize: 16,
                                color: Color(0xFF5D4037),
                                fontWeight: FontWeight.bold)),
                        SizedBox(height: 8),
                        Text('Archived residents appear here after 30 days',
                            style: TextStyle(
                                color: Color(0xFF8D6E63), fontSize: 12)),
                      ],
                    ),
                  ),
                )
              else
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) =>
                      _buildWebRecordRow(filtered[index]),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildWebRecordRow(ResidentRecordModel r) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
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
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        shape: const Border(),
        collapsedShape: const Border(),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
              color: const Color(0xFF8D6E63).withOpacity(0.1),
              borderRadius: BorderRadius.circular(10)),
          child: const Icon(Icons.library_books,
              size: 20, color: Color(0xFF8D6E63)),
        ),
        title: Text(r.fullName,
            style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Color(0xFF5D4037),
                fontSize: 15)),
        subtitle: Row(
          children: [
            if (r.residentId != null) ...[
              Text(r.residentId!,
                  style: const TextStyle(
                      color: Color(0xFF8D6E63),
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'monospace')),
              const SizedBox(width: 12),
            ],
            Text('Recorded: ${DateFormat('MMM dd, yyyy').format(r.recordedAt)}',
                style:
                const TextStyle(color: Color(0xFF8D6E63), fontSize: 12)),
          ],
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
              color: const Color(0xFF8D6E63).withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border:
              Border.all(color: const Color(0xFF8D6E63).withOpacity(0.3))),
          child: const Text('RECORD',
              style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF8D6E63))),
        ),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
                color: const Color(0xFFFFF8F0),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFE0D5C1))),
            child: Wrap(
              spacing: 32,
              runSpacing: 10,
              children: [
                _buildInfoRow(Icons.badge, 'Resident ID', r.residentId ?? 'N/A'),
                _buildInfoRow(Icons.email, 'Email',
                    r.email.isEmpty ? 'Not provided' : r.email),
                _buildInfoRow(
                    Icons.phone, 'Phone', r.phoneNumber ?? 'Not provided'),
                _buildInfoRow(
                    Icons.home, 'House', r.houseNumber ?? 'Not assigned'),
                _buildInfoRow(Icons.calendar_today, 'Registered',
                    DateFormat('MMM dd, yyyy').format(r.createdAt)),
                _buildInfoRow(Icons.archive_outlined, 'Archived',
                    DateFormat('MMM dd, yyyy').format(r.archivedAt)),
                _buildInfoRow(Icons.library_books_outlined, 'Recorded',
                    DateFormat('MMM dd, yyyy').format(r.recordedAt)),
                if (r.archivedByName != null)
                  _buildInfoRow(Icons.admin_panel_settings, 'Archived By',
                      r.archivedByName!),
                if (r.movedByName != null)
                  _buildInfoRow(Icons.swap_horiz, 'Moved By', r.movedByName!),
                if (r.deleteReason != null && r.deleteReason!.isNotEmpty)
                  _buildInfoRow(
                      Icons.note_alt_outlined, 'Reason', r.deleteReason!),
              ],
            ),
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
              child: Icon(Icons.library_books,
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
                      const Text('Resident Records',
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
                        onTap: _pickDateRange,
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(12)),
                          child: const Icon(Icons.filter_alt_outlined,
                              color: Color(0xFFFFF8F0), size: 20),
                        ),
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: _isExporting ? null : _exportPDF,
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(12)),
                          child: _isExporting
                              ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                      Color(0xFFFFF8F0))))
                              : const Icon(Icons.picture_as_pdf,
                              color: Color(0xFFFFF8F0), size: 20),
                        ),
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: _isExporting ? null : _exportCSV,
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(12)),
                          child: const Icon(Icons.table_chart_outlined,
                              color: Color(0xFFFFF8F0), size: 20),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 24),
              const Text('Permanent Archive',
                  style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFFFF8F0))),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMobileContent() {
    return StreamBuilder<List<ResidentRecordModel>>(
      stream: _archiveService.streamResidentRecords(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
              child: CircularProgressIndicator(color: Color(0xFFD4C4A8)));
        }

        final all = snapshot.data ?? [];
        final filtered = _filter(all);

        return SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Info banner
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                    color: const Color(0xFF8D6E63).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: const Color(0xFF8D6E63).withOpacity(0.3))),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline,
                        size: 16, color: Color(0xFF8D6E63)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Read-only · ${all.length} records · never deleted',
                        style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xFF5D4037),
                            height: 1.4),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Search
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE0D5C1))),
                child: TextField(
                  controller: _searchController,
                  onChanged: (v) => setState(() => _searchQuery = v),
                  decoration: const InputDecoration(
                      hintText: 'Search records...',
                      hintStyle: TextStyle(
                          fontSize: 13, color: Color(0xFFB8A99A)),
                      border: InputBorder.none,
                      isDense: true),
                ),
              ),
              if (_dateRange != null) ...[
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFFE0D5C1))),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '📅 ${DateFormat('MMM dd').format(_dateRange!.start)} → ${DateFormat('MMM dd').format(_dateRange!.end)}',
                          style: const TextStyle(
                              fontSize: 12, color: Color(0xFF5D4037)),
                        ),
                        const SizedBox(width: 6),
                        InkWell(
                          onTap: () => setState(() => _dateRange = null),
                          child: const Icon(Icons.close,
                              size: 14, color: Color(0xFF8D6E63)),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 16),

              if (all.isEmpty)
                Container(
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFE0D5C1))),
                  child: const Column(
                    children: [
                      Icon(Icons.library_books_outlined,
                          size: 56, color: Color(0xFFD4C4A8)),
                      SizedBox(height: 12),
                      Text('No records yet',
                          style: TextStyle(
                              fontSize: 14,
                              color: Color(0xFF6B5B4F),
                              fontWeight: FontWeight.w600)),
                      SizedBox(height: 4),
                      Text('Archived residents appear here after 30 days',
                          style: TextStyle(
                              fontSize: 12, color: Color(0xFFB8A99A))),
                    ],
                  ),
                )
              else
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) =>
                      _buildMobileRecordCard(filtered[index]),
                ),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMobileRecordCard(ResidentRecordModel r) {
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
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        shape: const Border(),
        collapsedShape: const Border(),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
              color: const Color(0xFF8D6E63).withOpacity(0.15),
              borderRadius: BorderRadius.circular(10)),
          child:
          const Icon(Icons.library_books, size: 18, color: Color(0xFF8D6E63)),
        ),
        title: Text(r.fullName,
            style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Color(0xFF5D4037),
                fontSize: 14),
            maxLines: 1,
            overflow: TextOverflow.ellipsis),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (r.residentId != null)
              Text(r.residentId!,
                  style: const TextStyle(
                      color: Color(0xFF8D6E63),
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'monospace'),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1),
            Text(
                'Recorded: ${DateFormat('MMM dd, yyyy').format(r.recordedAt)}',
                style: const TextStyle(color: Color(0xFF8D6E63), fontSize: 11),
                overflow: TextOverflow.ellipsis,
                maxLines: 1),
          ],
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
              color: const Color(0xFF8D6E63).withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border:
              Border.all(color: const Color(0xFF8D6E63).withOpacity(0.3))),
          child: const Text('RECORD',
              style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF8D6E63))),
        ),
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
                color: const Color(0xFFFFF8F0),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFE0D5C1))),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _mobileInfoRow(
                    Icons.badge, 'Resident ID', r.residentId ?? 'N/A'),
                const SizedBox(height: 6),
                _mobileInfoRow(Icons.email, 'Email',
                    r.email.isEmpty ? 'Not provided' : r.email),
                const SizedBox(height: 6),
                _mobileInfoRow(
                    Icons.phone, 'Phone', r.phoneNumber ?? 'Not provided'),
                const SizedBox(height: 6),
                _mobileInfoRow(
                    Icons.home, 'House', r.houseNumber ?? 'Not assigned'),
                const SizedBox(height: 6),
                _mobileInfoRow(Icons.calendar_today, 'Registered',
                    DateFormat('MMM dd, yyyy').format(r.createdAt)),
                const SizedBox(height: 6),
                _mobileInfoRow(Icons.archive_outlined, 'Archived',
                    DateFormat('MMM dd, yyyy').format(r.archivedAt)),
                const SizedBox(height: 6),
                _mobileInfoRow(Icons.library_books_outlined, 'Recorded',
                    DateFormat('MMM dd, yyyy').format(r.recordedAt)),
                if (r.archivedByName != null) ...[
                  const SizedBox(height: 6),
                  _mobileInfoRow(Icons.admin_panel_settings, 'Archived By',
                      r.archivedByName!),
                ],
                if (r.movedByName != null) ...[
                  const SizedBox(height: 6),
                  _mobileInfoRow(Icons.swap_horiz, 'Moved By', r.movedByName!),
                ],
                if (r.deleteReason != null && r.deleteReason!.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  _mobileInfoRow(
                      Icons.note_alt_outlined, 'Reason', r.deleteReason!),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _mobileInfoRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 12, color: const Color(0xFFD4C4A8)),
        const SizedBox(width: 6),
        SizedBox(
          width: 90,
          child: Text(label,
              style: const TextStyle(
                  fontSize: 11,
                  color: Color(0xFF8D6E63),
                  fontWeight: FontWeight.w500),
              overflow: TextOverflow.ellipsis,
              maxLines: 1),
        ),
        Expanded(
          child: Text(value,
              style: const TextStyle(fontSize: 11, color: Color(0xFF5D4037)),
              maxLines: 2,
              overflow: TextOverflow.ellipsis),
        ),
      ],
    );
  }

  // ============================================================
  // 🔥 SHARED HELPERS
  // ============================================================

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return SizedBox(
      width: 220,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 12, color: const Color(0xFFD4C4A8)),
          const SizedBox(width: 6),
          SizedBox(
            width: 90,
            child: Text(label,
                style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFFB8A99A),
                    fontWeight: FontWeight.w500),
                overflow: TextOverflow.ellipsis,
                maxLines: 1),
          ),
          Expanded(
            child: Text(value,
                style:
                const TextStyle(fontSize: 12, color: Color(0xFF5D4037)),
                maxLines: 2,
                overflow: TextOverflow.ellipsis),
          ),
        ],
      ),
    );
  }

  Future<void> _pickDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: _dateRange,
    );
    if (picked != null) {
      setState(() => _dateRange = picked);
    }
  }

  // ==================== EXPORT CSV ====================
  Future<void> _exportCSV() async {
    try {
      final snap = await _archiveService.streamResidentRecords().first;
      if (snap.isEmpty) {
        _snack('No records to export', isError: true);
        return;
      }
      final rows = <List<dynamic>>[
        [
          'Resident ID',
          'Full Name',
          'Email',
          'House',
          'Phone',
          'RFID',
          'Registered',
          'Archived',
          'Recorded',
          'Reason'
        ]
      ];
      for (final r in snap) {
        rows.add([
          r.residentId ?? '',
          r.fullName,
          r.email,
          r.houseNumber ?? '',
          r.phoneNumber ?? '',
          r.rfidTag ?? '',
          DateFormat('yyyy-MM-dd').format(r.createdAt),
          DateFormat('yyyy-MM-dd').format(r.archivedAt),
          DateFormat('yyyy-MM-dd').format(r.recordedAt),
          r.deleteReason ?? '',
        ]);
      }
      final csv = const ListToCsvConverter().convert(rows);
      final dir = await getTemporaryDirectory();
      final file = File(
          '${dir.path}/resident_records_${DateTime.now().millisecondsSinceEpoch}.csv');
      await file.writeAsString(csv);
      await Share.shareXFiles([XFile(file.path)],
          text: 'Florence Homes — Resident Records');
      _snack('CSV exported successfully');
    } catch (e) {
      _snack('CSV export failed: $e', isError: true);
    }
  }

  // ==================== EXPORT PDF ====================
  Future<void> _exportPDF() async {
    setState(() => _isExporting = true);
    try {
      final snap = await _archiveService.streamResidentRecords().first;
      if (snap.isEmpty) {
        _snack('No records to export', isError: true);
        return;
      }
      final pdf = pw.Document();
      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          orientation: pw.PageOrientation.landscape,
          build: (_) => [
            pw.Header(
                level: 0,
                child: pw.Text('Florence Homes — Resident Records',
                    style: pw.TextStyle(
                        fontSize: 18, fontWeight: pw.FontWeight.bold))),
            pw.SizedBox(height: 10),
            pw.Text(
                'Generated: ${DateFormat('MMMM dd, yyyy hh:mm a').format(DateTime.now())}'),
            pw.SizedBox(height: 16),
            pw.Table.fromTextArray(
              headers: [
                'Resident ID',
                'Full Name',
                'House',
                'Phone',
                'Registered',
                'Archived',
                'Recorded'
              ],
              headerStyle:
              pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10),
              headerDecoration:
              pw.BoxDecoration(color: PdfColors.brown100),
              cellStyle: pw.TextStyle(fontSize: 9),
              data: snap
                  .map((r) => [
                r.residentId ?? 'N/A',
                r.fullName,
                r.houseNumber ?? '',
                r.phoneNumber ?? '',
                DateFormat('yyyy-MM-dd').format(r.createdAt),
                DateFormat('yyyy-MM-dd').format(r.archivedAt),
                DateFormat('yyyy-MM-dd').format(r.recordedAt),
              ])
                  .toList(),
            ),
          ],
        ),
      );
      final bytes = await pdf.save();
      final dir = await getTemporaryDirectory();
      final file = File(
          '${dir.path}/resident_records_${DateTime.now().millisecondsSinceEpoch}.pdf');
      await file.writeAsBytes(bytes);
      await Share.shareXFiles([XFile(file.path)],
          text: 'Florence Homes — Resident Records');
      _snack('PDF exported successfully');
    } catch (e) {
      _snack('PDF export failed: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  void _snack(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor:
        isError ? const Color(0xFFD32F2F) : const Color(0xFF8D6E63),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}