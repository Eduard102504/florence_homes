import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:intl/intl.dart';
import 'package:csv/csv.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'dart:io';
import 'dart:async';
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF8D6E63),
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
              // ==================== CUSTOM TWO-ROW HEADER ====================
              _buildHeader(),
              Expanded(
                child: Align(
                  alignment: Alignment.topCenter,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: kIsWeb ? 900 : double.infinity,
                    ),
                    child: StreamBuilder<List<ResidentRecordModel>>(
                      stream: _archiveService.streamResidentRecords(),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Center(
                            child: CircularProgressIndicator(
                              valueColor: AlwaysStoppedAnimation<Color>(
                                  Color(0xFFD4C4A8)),
                            ),
                          );
                        }

                        final all = snapshot.data ?? [];
                        final filtered = _filter(all);

                        return Column(
                          children: [
                            // Info banner
                            Container(
                              margin: EdgeInsets.fromLTRB(
                                  kIsWeb ? 20 : 12,
                                  kIsWeb ? 16 : 12,
                                  kIsWeb ? 20 : 12,
                                  8),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFF8D6E63)
                                    .withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                    color: const Color(0xFF8D6E63)
                                        .withOpacity(0.3)),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.info_outline,
                                      size: 18,
                                      color: Color(0xFF8D6E63)),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Read-only permanent history · ${all.length} records · never auto-deleted',
                                      style: const TextStyle(
                                          fontSize: 11,
                                          color: Color(0xFF5D4037),
                                          height: 1.4),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            // Search + date chips
                            Padding(
                              padding: EdgeInsets.symmetric(
                                  horizontal: kIsWeb ? 20 : 12),
                              child: Column(
                                children: [
                                  TextField(
                                    controller: _searchController,
                                    onChanged: (v) =>
                                        setState(() => _searchQuery = v),
                                    decoration: InputDecoration(
                                      hintText: 'Search records...',
                                      hintStyle: const TextStyle(
                                          color: Color(0xFFB8A99A),
                                          fontSize: 12),
                                      prefixIcon: const Icon(Icons.search,
                                          color: Color(0xFFD4C4A8),
                                          size: 20),
                                      suffixIcon: _searchQuery.isNotEmpty
                                          ? IconButton(
                                        icon: const Icon(Icons.clear,
                                            size: 18,
                                            color: Color(0xFFB8A99A)),
                                        onPressed: () {
                                          _searchController.clear();
                                          setState(() =>
                                          _searchQuery = '');
                                        },
                                      )
                                          : null,
                                      border: OutlineInputBorder(
                                        borderRadius:
                                        BorderRadius.circular(14),
                                        borderSide: const BorderSide(
                                            color: Color(0xFFE0D5C1)),
                                      ),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius:
                                        BorderRadius.circular(14),
                                        borderSide: const BorderSide(
                                            color: Color(0xFFE0D5C1)),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius:
                                        BorderRadius.circular(14),
                                        borderSide: const BorderSide(
                                            color: Color(0xFFD4C4A8),
                                            width: 2),
                                      ),
                                      filled: true,
                                      fillColor: Colors.white,
                                      contentPadding:
                                      const EdgeInsets.symmetric(
                                          horizontal: 14,
                                          vertical: 12),
                                    ),
                                  ),
                                  if (_dateRange != null) ...[
                                    const SizedBox(height: 8),
                                    Row(
                                      children: [
                                        Flexible(
                                          child: Chip(
                                            backgroundColor: Colors.white,
                                            label: Text(
                                              '📅 ${DateFormat('MMM dd, yyyy').format(_dateRange!.start)} → ${DateFormat('MMM dd, yyyy').format(_dateRange!.end)}',
                                              style: const TextStyle(
                                                  fontSize: 11,
                                                  color: Color(0xFF6B5B4F)),
                                              overflow: TextOverflow.ellipsis,
                                              maxLines: 1,
                                            ),
                                            deleteIconColor:
                                            const Color(0xFFB8A99A),
                                            onDeleted: () {
                                              setState(
                                                      () => _dateRange = null);
                                            },
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ],
                              ),
                            ),

                            const SizedBox(height: 8),

                            if (all.isEmpty)
                              const Expanded(
                                child: Center(
                                  child: Column(
                                    mainAxisAlignment:
                                    MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.library_books_outlined,
                                          size: 70,
                                          color: Color(0xFFE0D5C1)),
                                      SizedBox(height: 16),
                                      Text(
                                        'No records yet',
                                        style: TextStyle(
                                            fontSize: 16,
                                            color: Color(0xFF6B5B4F),
                                            fontWeight: FontWeight.w500),
                                      ),
                                      SizedBox(height: 8),
                                      Text(
                                        'Archived residents appear here after 30 days',
                                        style: TextStyle(
                                            color: Color(0xFFB8A99A),
                                            fontSize: 12),
                                      ),
                                    ],
                                  ),
                                ),
                              )
                            else
                              Expanded(
                                child: ListView.builder(
                                  padding:
                                  EdgeInsets.all(kIsWeb ? 20 : 12),
                                  itemCount: filtered.length,
                                  itemBuilder: (context, index) =>
                                      _buildRecordCard(filtered[index]),
                                ),
                              ),
                          ],
                        );
                      },
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
  // CUSTOM TWO-ROW HEADER
  // Top row: back button (left) + export/filter icons (right)
  // Bottom row: large title
  // ============================================================
  Widget _buildHeader() {
    return Container(
      color: const Color(0xFF8D6E63),
      padding: EdgeInsets.fromLTRB(
        kIsWeb ? 20 : 16,
        kIsWeb ? 14 : 12,
        kIsWeb ? 20 : 16,
        kIsWeb ? 14 : 12,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ---------- TOP ROW: BACK + ACTIONS ----------
          Row(
            children: [
              _headerIconButton(
                icon: Icons.arrow_back,
                tooltip: 'Back',
                onTap: () => Navigator.pop(context),
              ),
              const Spacer(),
              _headerIconButton(
                icon: Icons.filter_alt_outlined,
                tooltip: 'Filter by date',
                onTap: _pickDateRange,
              ),
              const SizedBox(width: 8),
              _headerIconButton(
                icon: Icons.picture_as_pdf,
                tooltip: 'Export PDF',
                onTap: _isExporting ? () {} : _exportPDF,
                showSpinner: _isExporting,
              ),
              const SizedBox(width: 8),
              _headerIconButton(
                icon: Icons.table_chart_outlined,
                tooltip: 'Export CSV',
                onTap: _isExporting ? () {} : _exportCSV,
              ),
            ],
          ),
          const SizedBox(height: 12),

          // ---------- BOTTOM ROW: TITLE ----------
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: const [
              Icon(Icons.library_books_outlined,
                  size: 26, color: Color(0xFFFFF8F0)),
              SizedBox(width: 10),
              Flexible(
                child: Text(
                  'Resident Records',
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

  Widget _headerIconButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
    bool showSpinner = false,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(10),
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
            child: showSpinner
                ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(
                    Color(0xFFFFF8F0)),
              ),
            )
                : Icon(icon, color: const Color(0xFFFFF8F0), size: 20),
          ),
        ),
      ),
    );
  }

  // ==================== RECORD CARD ====================
  Widget _buildRecordCard(ResidentRecordModel r) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFD4C4A8).withOpacity(0.15),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE0D5C1), width: 1),
        ),
        child: ExpansionTile(
          tilePadding:
          const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          shape: const Border(),
          collapsedShape: const Border(),
          leading: CircleAvatar(
            radius: 18,
            backgroundColor: const Color(0xFF8D6E63).withOpacity(0.15),
            child: const Icon(Icons.library_books,
                size: 18, color: Color(0xFF8D6E63)),
          ),
          title: Text(
            r.fullName,
            style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Color(0xFF6B5B4F),
                fontSize: 13),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (r.residentId != null)
                Text(
                  r.residentId!,
                  style: const TextStyle(
                    color: Color(0xFF8D6E63),
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'monospace',
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              Text(
                'Recorded: ${DateFormat('MMM dd, yyyy').format(r.recordedAt)}',
                style: const TextStyle(
                    color: Color(0xFFB8A99A), fontSize: 11),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ],
          ),
          trailing: Container(
            padding:
            const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF8D6E63).withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: const Color(0xFF8D6E63).withOpacity(0.3)),
            ),
            child: const Text(
              'RECORD',
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.bold,
                color: Color(0xFF8D6E63),
              ),
            ),
          ),
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF8F0),
                borderRadius: BorderRadius.circular(10),
                border:
                Border.all(color: const Color(0xFFE0D5C1), width: 1),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildInfoRow(Icons.badge, 'Resident ID',
                      r.residentId ?? 'N/A'),
                  const SizedBox(height: 6),
                  _buildInfoRow(Icons.email, 'Email',
                      r.email.isEmpty ? 'Not provided' : r.email),
                  const SizedBox(height: 6),
                  _buildInfoRow(Icons.phone, 'Phone',
                      r.phoneNumber ?? 'Not provided'),
                  const SizedBox(height: 6),
                  _buildInfoRow(Icons.home, 'House',
                      r.houseNumber ?? 'Not assigned'),
                  const SizedBox(height: 6),
                  _buildInfoRow(
                      Icons.calendar_today,
                      'Registered',
                      DateFormat('MMM dd, yyyy').format(r.createdAt)),
                  const SizedBox(height: 6),
                  _buildInfoRow(
                      Icons.archive_outlined,
                      'Archived',
                      DateFormat('MMM dd, yyyy').format(r.archivedAt)),
                  const SizedBox(height: 6),
                  _buildInfoRow(
                      Icons.library_books_outlined,
                      'Recorded',
                      DateFormat('MMM dd, yyyy').format(r.recordedAt)),
                  if (r.archivedByName != null) ...[
                    const SizedBox(height: 6),
                    _buildInfoRow(Icons.admin_panel_settings,
                        'Archived By', r.archivedByName!),
                  ],
                  if (r.movedByName != null) ...[
                    const SizedBox(height: 6),
                    _buildInfoRow(Icons.swap_horiz, 'Moved By',
                        r.movedByName!),
                  ],
                  if (r.deleteReason != null &&
                      r.deleteReason!.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    _buildInfoRow(
                        Icons.note_alt_outlined, 'Reason', r.deleteReason!),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 12, color: const Color(0xFFD4C4A8)),
        const SizedBox(width: 6),
        SizedBox(
          width: 90,
          child: Text(
            label,
            style: const TextStyle(
                fontSize: 10,
                color: Color(0xFFB8A99A),
                fontWeight: FontWeight.w500),
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontSize: 11, color: Color(0xFF6B5B4F)),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
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