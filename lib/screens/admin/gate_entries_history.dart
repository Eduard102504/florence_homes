// lib/screens/admin/gate_entries_history.dart
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart' show rootBundle;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'dart:async';

import 'pdf_download_stub.dart'
if (dart.library.js_interop) 'pdf_download_web.dart' as pdf_download;

class GateEntriesHistory extends StatefulWidget {
  const GateEntriesHistory({super.key});

  @override
  State<GateEntriesHistory> createState() => _GateEntriesHistoryState();
}

class _GateEntriesHistoryState extends State<GateEntriesHistory> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  List<Map<String, dynamic>> _entries = [];
  List<Map<String, dynamic>> _allEntries = [];
  String? _errorMessage;
  DateTimeRange? _dateRange;
  String _selectedResident = 'all';
  String _selectedEntryType = 'all';
  Map<String, String> _residentNames = {};
  bool _isExporting = false;

  int _currentPage = 1;
  int _pageSize = 20;

  StreamSubscription<QuerySnapshot>? _entriesSub;
  StreamSubscription<QuerySnapshot>? _residentsSub;

  // ==================== PDF BRAND COLORS ====================
  static final PdfColor _brandBrown = PdfColor.fromHex('#5D4037');
  static final PdfColor _brandCream = PdfColor.fromHex('#D4C4A8');
  static final PdfColor _brandTan = PdfColor.fromHex('#C4A882');
  static final PdfColor _brandLight = PdfColor.fromHex('#FFF8F0');
  static final PdfColor _brandBeige = PdfColor.fromHex('#F5F0E8');
  static final PdfColor _brandBorder = PdfColor.fromHex('#E0D5C1');
  static final PdfColor _pdfWhite = PdfColor.fromHex('#FFFFFF');

  // ==================== TIMESTAMP ====================
  DateTime _parseTimestamp(dynamic timestamp) {
    if (timestamp == null) return DateTime.now();

    DateTime utcTime;
    if (timestamp is Timestamp) {
      utcTime = timestamp.toDate();
    } else if (timestamp is DateTime) {
      utcTime = timestamp;
    } else if (timestamp is String) {
      utcTime = DateTime.parse(timestamp);
    } else {
      return DateTime.now();
    }
    return utcTime.toLocal();
  }

  DateTime _getEntryTimestamp(Map<String, dynamic> entry) {
    if (entry['timestamp'] != null) return _parseTimestamp(entry['timestamp']);
    if (entry['createdAt'] != null) return _parseTimestamp(entry['createdAt']);
    if (entry['date'] != null) return _parseTimestamp(entry['date']);
    if (entry['time'] != null) return _parseTimestamp(entry['time']);
    return DateTime.now();
  }

  // ==================== PAGINATION ====================
  int get _totalPages {
    if (_pageSize == 0) return 1;
    if (_entries.isEmpty) return 1;
    return ((_entries.length - 1) ~/ _pageSize) + 1;
  }

  List<Map<String, dynamic>> get _paginatedEntries {
    if (_pageSize == 0) return _entries;
    final start = (_currentPage - 1) * _pageSize;
    if (start >= _entries.length) return [];
    final end = (start + _pageSize).clamp(0, _entries.length);
    return _entries.sublist(start, end);
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

  // ==================== LIFECYCLE ====================
  @override
  void initState() {
    super.initState();
    _startResidentsStream();
    _startEntriesStream();
  }

  @override
  void dispose() {
    _entriesSub?.cancel();
    _residentsSub?.cancel();
    super.dispose();
  }

  // ==================== LIVE RESIDENTS ====================
  void _startResidentsStream() {
    _residentsSub = _firestore
        .collection('users')
        .where('userType', isEqualTo: 'resident')
        .snapshots()
        .listen(
          (snapshot) {
        final names = <String, String>{};
        for (var doc in snapshot.docs) {
          names[doc.id] = (doc.get('fullName') as String?) ?? 'Unknown';
        }
        if (mounted) setState(() => _residentNames = names);
      },
      onError: (e) => print('Residents stream error: $e'),
    );
  }

  // ==================== LIVE ENTRIES ====================
  void _startEntriesStream() {
    _entriesSub = _firestore
        .collection('gate_entries')
        .snapshots()
        .listen(
          (snapshot) {
        final list = snapshot.docs.map((doc) {
          final data = doc.data() as Map<String, dynamic>;
          data['id'] = doc.id;
          return data;
        }).toList();

        list.sort((a, b) =>
            _getEntryTimestamp(b).compareTo(_getEntryTimestamp(a)));

        if (mounted) {
          setState(() {
            _allEntries = list;
            _applyFiltersInternal();
            if (_currentPage > _totalPages) _currentPage = _totalPages;
            _errorMessage = null;
          });
        }
      },
      onError: (e) {
        print('Entries stream error: $e');
        if (mounted) setState(() => _errorMessage = 'Error: $e');
      },
    );
  }

  // ==================== FILTERS ====================
  void _applyFiltersInternal() {
    List<Map<String, dynamic>> filtered = List.from(_allEntries);

    if (_selectedResident != 'all') {
      filtered = filtered
          .where((e) => e['residentId'] == _selectedResident)
          .toList();
    }

    if (_selectedEntryType != 'all') {
      filtered = filtered
          .where((e) => e['entryType'] == _selectedEntryType)
          .toList();
    }

    if (_dateRange != null) {
      filtered = filtered.where((entry) {
        final t = _getEntryTimestamp(entry);
        return t.isAfter(_dateRange!.start) &&
            t.isBefore(_dateRange!.end.add(const Duration(days: 1)));
      }).toList();
    }

    filtered.sort((a, b) =>
        _getEntryTimestamp(b).compareTo(_getEntryTimestamp(a)));

    _entries = filtered;
  }

  void _applyFilters() {
    setState(() {
      _applyFiltersInternal();
      _currentPage = 1;
    });
  }

  // ==================== DISPLAY HELPERS ====================
  String _getEntryTypeDisplay(String? type) {
    switch (type) {
      case 'uhf_rfid':
      case 'rfid':
        return 'RFID';
      case 'qr_visitor':
        return 'QR Visitor';
      case 'manual':
        return 'Manual Entry';
      default:
        return type?.toUpperCase() ?? 'UNKNOWN';
    }
  }

  // ==================== EXPORT PDF ====================
  Future<void> _exportToPDF() async {
    if (_entries.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No entries to export'),
          backgroundColor: Color(0xFFFF9800),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _isExporting = true);

    try {
      final pdf = pw.Document();

      pw.MemoryImage? logoImage;
      try {
        final logoBytes =
        await rootBundle.load('assets/images/florence_logo.png');
        logoImage = pw.MemoryImage(logoBytes.buffer.asUint8List());
      } catch (e) {
        print('⚠️ Could not load logo: $e');
      }

      final int totalEntries = _entries.length;
      final int rfidEntries = _entries
          .where((e) =>
      e['entryType'] == 'uhf_rfid' || e['entryType'] == 'rfid')
          .length;
      final int qrEntries =
          _entries.where((e) => e['entryType'] == 'qr_visitor').length;
      final int manualEntries =
          _entries.where((e) => e['entryType'] == 'manual').length;

      final String dateRangeLabel = _dateRange != null
          ? '${DateFormat('MMM dd, yyyy').format(_dateRange!.start)} — ${DateFormat('MMM dd, yyyy').format(_dateRange!.end)}'
          : 'All Time';

      final String residentLabel = _selectedResident != 'all'
          ? _residentNames[_selectedResident] ?? 'Unknown Resident'
          : 'All Residents';

      final String entryTypeLabel = _selectedEntryType != 'all'
          ? _selectedEntryType
          .toUpperCase()
          .replaceFirst('UHF_RFID', 'RFID')
          .replaceFirst('QR_VISITOR', 'QR Visitor')
          .replaceFirst('MANUAL', 'Manual')
          : 'All Types';

      // COVER
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          build: (pw.Context context) {
            return pw.Container(
              decoration: pw.BoxDecoration(color: _brandLight),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.center,
                children: [
                  pw.Container(height: 12, color: _brandCream),
                  pw.SizedBox(height: 40),
                  if (logoImage != null)
                    pw.Container(
                      width: 200,
                      height: 200,
                      decoration: pw.BoxDecoration(
                        border: pw.Border.all(color: _brandCream, width: 3),
                        borderRadius: pw.BorderRadius.circular(16),
                      ),
                      padding: pw.EdgeInsets.all(10),
                      child: pw.Image(logoImage, fit: pw.BoxFit.contain),
                    )
                  else
                    pw.Container(
                      width: 200,
                      height: 200,
                      decoration: pw.BoxDecoration(
                        color: _brandBeige,
                        border: pw.Border.all(color: _brandCream, width: 3),
                        borderRadius: pw.BorderRadius.circular(16),
                      ),
                      child: pw.Center(
                        child: pw.Text('🏠',
                            style: pw.TextStyle(fontSize: 72)),
                      ),
                    ),
                  pw.SizedBox(height: 30),
                  pw.Text(
                    'FLORENCE HOMES',
                    style: pw.TextStyle(
                      fontSize: 28,
                      fontWeight: pw.FontWeight.bold,
                      color: _brandBrown,
                      letterSpacing: 3,
                    ),
                  ),
                  pw.SizedBox(height: 6),
                  pw.Text(
                    'MAGDALENA',
                    style: pw.TextStyle(
                      fontSize: 18,
                      fontWeight: pw.FontWeight.bold,
                      color: _brandTan,
                      letterSpacing: 6,
                    ),
                  ),
                  pw.SizedBox(height: 4),
                  pw.Text(
                    'House & Land Development Corp.',
                    style: pw.TextStyle(
                      fontSize: 11,
                      color: _brandBrown,
                      letterSpacing: 1,
                    ),
                  ),
                  pw.SizedBox(height: 40),
                  pw.Container(width: 120, height: 3, color: _brandCream),
                  pw.SizedBox(height: 30),
                  pw.Text(
                    'GATE ENTRY REPORT',
                    style: pw.TextStyle(
                      fontSize: 22,
                      fontWeight: pw.FontWeight.bold,
                      color: _brandBrown,
                      letterSpacing: 2,
                    ),
                  ),
                  pw.SizedBox(height: 20),
                  pw.Container(
                    width: 350,
                    padding: pw.EdgeInsets.all(16),
                    decoration: pw.BoxDecoration(
                      color: _pdfWhite,
                      border:
                      pw.Border.all(color: _brandBorder, width: 1.5),
                      borderRadius: pw.BorderRadius.circular(10),
                    ),
                    child: pw.Column(
                      children: [
                        _pdfMetaRow('Date Range', dateRangeLabel),
                        pw.SizedBox(height: 6),
                        _pdfMetaRow('Resident', residentLabel),
                        pw.SizedBox(height: 6),
                        _pdfMetaRow('Entry Type', entryTypeLabel),
                        pw.SizedBox(height: 6),
                        _pdfMetaRow('Total Records', '$totalEntries'),
                        pw.SizedBox(height: 6),
                        _pdfMetaRow(
                          'Generated',
                          DateFormat('MMM dd, yyyy • hh:mm a')
                              .format(DateTime.now()),
                        ),
                      ],
                    ),
                  ),
                  pw.Spacer(),
                  pw.Container(
                    padding: pw.EdgeInsets.all(12),
                    color: _brandBeige,
                    child: pw.Center(
                      child: pw.Text(
                        'Florence Homes Magdalena  •  Village Gate Access System',
                        style: pw.TextStyle(
                          fontSize: 10,
                          color: _brandBrown,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      );

      // SUMMARY
      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: pw.EdgeInsets.all(40),
          header: (pw.Context context) => _pdfHeader(logoImage),
          footer: (pw.Context context) => _pdfFooter(context),
          build: (pw.Context context) {
            return [
              pw.SizedBox(height: 20),
              pw.Text(
                'Report Summary',
                style: pw.TextStyle(
                  fontSize: 20,
                  fontWeight: pw.FontWeight.bold,
                  color: _brandBrown,
                ),
              ),
              pw.SizedBox(height: 4),
              pw.Container(width: 60, height: 3, color: _brandCream),
              pw.SizedBox(height: 20),
              pw.Container(
                padding: pw.EdgeInsets.all(14),
                decoration: pw.BoxDecoration(
                  color: _brandLight,
                  border: pw.Border.all(color: _brandBorder),
                  borderRadius: pw.BorderRadius.circular(8),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'FILTERS APPLIED',
                      style: pw.TextStyle(
                        fontSize: 10,
                        fontWeight: pw.FontWeight.bold,
                        color: _brandTan,
                        letterSpacing: 1,
                      ),
                    ),
                    pw.SizedBox(height: 10),
                    _pdfFilterRow(
                        Icons.calendar_today, 'Date Range', dateRangeLabel),
                    pw.SizedBox(height: 6),
                    _pdfFilterRow(Icons.person, 'Resident', residentLabel),
                    pw.SizedBox(height: 6),
                    _pdfFilterRow(Icons.tag, 'Entry Type', entryTypeLabel),
                  ],
                ),
              ),
              pw.SizedBox(height: 24),
              pw.Container(
                padding: pw.EdgeInsets.all(20),
                decoration: pw.BoxDecoration(
                  color: _brandCream,
                  borderRadius: pw.BorderRadius.circular(12),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          'TOTAL ENTRIES',
                          style: pw.TextStyle(
                            fontSize: 11,
                            fontWeight: pw.FontWeight.bold,
                            color: _brandBrown,
                            letterSpacing: 1.5,
                          ),
                        ),
                        pw.SizedBox(height: 4),
                        pw.Text(
                          totalEntries.toString(),
                          style: pw.TextStyle(
                            fontSize: 36,
                            fontWeight: pw.FontWeight.bold,
                            color: _brandBrown,
                          ),
                        ),
                      ],
                    ),
                    pw.Icon(pw.IconData(0xe1c7),
                        size: 56, color: _brandBrown),
                  ],
                ),
              ),
              pw.SizedBox(height: 20),
              pw.Row(
                children: [
                  pw.Expanded(
                    child: _pdfStatCard('RFID Scans',
                        rfidEntries.toString(), PdfColor.fromHex('#4CAF50')),
                  ),
                  pw.SizedBox(width: 10),
                  pw.Expanded(
                    child: _pdfStatCard('QR Visitors',
                        qrEntries.toString(), PdfColor.fromHex('#9C27B0')),
                  ),
                  pw.SizedBox(width: 10),
                  pw.Expanded(
                    child: _pdfStatCard('Manual',
                        manualEntries.toString(),
                        PdfColor.fromHex('#FF9800')),
                  ),
                ],
              ),
            ];
          },
        ),
      );

      // DETAILS
      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4.landscape,
          margin: pw.EdgeInsets.all(30),
          header: (pw.Context context) => _pdfHeader(logoImage),
          footer: (pw.Context context) => _pdfFooter(context),
          build: (pw.Context context) {
            return [
              pw.SizedBox(height: 10),
              pw.Text(
                'Gate Entry Details',
                style: pw.TextStyle(
                  fontSize: 18,
                  fontWeight: pw.FontWeight.bold,
                  color: _brandBrown,
                ),
              ),
              pw.SizedBox(height: 4),
              pw.Container(width: 60, height: 3, color: _brandCream),
              pw.SizedBox(height: 16),
              pw.Table.fromTextArray(
                headers: const [
                  '#',
                  'Date',
                  'Time',
                  'Resident',
                  'Type',
                  'Visitor',
                ],
                headerStyle: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold,
                  color: _brandBrown,
                  fontSize: 10,
                ),
                headerDecoration: pw.BoxDecoration(color: _brandCream),
                headerHeight: 26,
                cellStyle: pw.TextStyle(
                  fontSize: 9,
                  color: _brandBrown,
                ),
                cellAlignment: pw.Alignment.centerLeft,
                cellPadding:
                pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
                oddRowDecoration: pw.BoxDecoration(color: _brandLight),
                border: pw.TableBorder.all(color: _brandBorder, width: 0.6),
                data: _entries.asMap().entries.map((pair) {
                  final index = pair.key + 1;
                  final entry = pair.value;
                  final ts = _getEntryTimestamp(entry);
                  return [
                    index.toString(),
                    DateFormat('yyyy-MM-dd').format(ts),
                    DateFormat('hh:mm a').format(ts),
                    entry['residentName'] ?? 'Unknown',
                    _getEntryTypeDisplay(entry['entryType']),
                    entry['visitorName'] ?? '—',
                  ];
                }).toList(),
              ),
              pw.SizedBox(height: 14),
              pw.Text(
                'Total records: ${_entries.length}',
                style: pw.TextStyle(
                  fontSize: 10,
                  color: _brandTan,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ];
          },
        ),
      );

      // SAVE
      final Uint8List bytes = await pdf.save();
      final fileName =
          'gate_report_${DateTime.now().millisecondsSinceEpoch}.pdf';

      if (kIsWeb) {
        pdf_download.downloadPdf(bytes, fileName);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('📥 PDF downloaded'),
              backgroundColor: Color(0xFF8D6E63),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } else {
        final tempDir = await getTemporaryDirectory();
        final file = File('${tempDir.path}/$fileName');
        await file.writeAsBytes(bytes);

        await Share.shareXFiles(
          [XFile(file.path)],
          subject: 'Florence Homes — Gate Entry Report',
          text: 'Florence Homes Magdalena — Gate Entry Report',
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ PDF report generated'),
              backgroundColor: Color(0xFF8D6E63),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } catch (e) {
      print('PDF generation error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error generating PDF: $e'),
            backgroundColor: const Color(0xFFD32F2F),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  // ==================== PDF HELPERS ====================
  pw.Widget _pdfHeader(pw.MemoryImage? logo) {
    return pw.Container(
      padding: pw.EdgeInsets.only(bottom: 10),
      decoration: pw.BoxDecoration(
        border: pw.Border(
          bottom: pw.BorderSide(color: _brandCream, width: 2),
        ),
      ),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          if (logo != null)
            pw.Container(
              width: 36,
              height: 36,
              child: pw.Image(logo, fit: pw.BoxFit.contain),
            )
          else
            pw.Container(
              width: 36,
              height: 36,
              decoration: pw.BoxDecoration(
                color: _brandBeige,
                borderRadius: pw.BorderRadius.circular(6),
              ),
              child: pw.Center(
                child: pw.Text('🏠', style: pw.TextStyle(fontSize: 18)),
              ),
            ),
          pw.SizedBox(width: 10),
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'FLORENCE HOMES MAGDALENA',
                style: pw.TextStyle(
                  fontSize: 12,
                  fontWeight: pw.FontWeight.bold,
                  color: _brandBrown,
                  letterSpacing: 1,
                ),
              ),
              pw.Text(
                'Village Gate Access System',
                style: pw.TextStyle(fontSize: 9, color: _brandTan),
              ),
            ],
          ),
          pw.Spacer(),
          pw.Text(
            DateFormat('MMM dd, yyyy').format(DateTime.now()),
            style: pw.TextStyle(fontSize: 9, color: _brandTan),
          ),
        ],
      ),
    );
  }

  pw.Widget _pdfFooter(pw.Context context) {
    return pw.Container(
      padding: pw.EdgeInsets.only(top: 8),
      decoration: pw.BoxDecoration(
        border: pw.Border(
          top: pw.BorderSide(color: _brandBorder, width: 0.5),
        ),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            'Florence Homes Magdalena — Confidential',
            style: pw.TextStyle(fontSize: 8, color: _brandTan),
          ),
          pw.Text(
            'Page ${context.pageNumber} of ${context.pagesCount}',
            style: pw.TextStyle(fontSize: 8, color: _brandTan),
          ),
        ],
      ),
    );
  }

  pw.Widget _pdfMetaRow(String label, String value) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(
          label,
          style: pw.TextStyle(
            fontSize: 10,
            color: _brandTan,
            fontWeight: pw.FontWeight.bold,
            letterSpacing: 0.5,
          ),
        ),
        pw.Text(
          value,
          style: pw.TextStyle(fontSize: 10, color: _brandBrown),
        ),
      ],
    );
  }

  pw.Widget _pdfFilterRow(IconData icon, String label, String value) {
    return pw.Row(
      children: [
        pw.Icon(pw.IconData(icon.codePoint), size: 12, color: _brandTan),
        pw.SizedBox(width: 8),
        pw.SizedBox(
          width: 90,
          child: pw.Text(
            label,
            style: pw.TextStyle(
              fontSize: 10,
              color: _brandTan,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
        ),
        pw.Expanded(
          child: pw.Text(
            value,
            style: pw.TextStyle(fontSize: 10, color: _brandBrown),
          ),
        ),
      ],
    );
  }

  pw.Widget _pdfStatCard(String label, String value, PdfColor accent) {
    return pw.Container(
      padding: pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        color: _pdfWhite,
        border: pw.Border.all(color: _brandBorder),
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            label.toUpperCase(),
            style: pw.TextStyle(
              fontSize: 9,
              color: _brandTan,
              fontWeight: pw.FontWeight.bold,
              letterSpacing: 1,
            ),
          ),
          pw.SizedBox(height: 6),
          pw.Text(
            value,
            style: pw.TextStyle(
              fontSize: 20,
              fontWeight: pw.FontWeight.bold,
              color: accent,
            ),
          ),
        ],
      ),
    );
  }

  // ==================== BUILD ====================
  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: const [
            Icon(Icons.history, size: 17, color: Color(0xFFFFF8F0)),
            SizedBox(width: 8),
            Text(
              'Gate History',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                letterSpacing: 1,
                fontSize: 12,
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFFD4C4A8),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list, size: 20),
            onPressed: _showFilterDialog,
            color: const Color(0xFFFFF8F0),
            tooltip: 'Filter',
          ),
          IconButton(
            icon: _isExporting
                ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(
                    Color(0xFFFFF8F0)),
              ),
            )
                : const Icon(Icons.picture_as_pdf,
                color: Color(0xFFFFF8F0)),
            onPressed: _isExporting ? null : _exportToPDF,
            tooltip: 'Save as PDF',
          ),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 14),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF8D6E63).withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: Color(0xFF4CAF50),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                const Text('LIVE',
                    style: TextStyle(
                        fontSize: 10,
                        color: Color(0xFFFFF8F0),
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5)),
              ],
            ),
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
              child: _buildBody(screenWidth),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBody(double screenWidth) {
    if (_allEntries.isEmpty && _errorMessage == null) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFD4C4A8)),
            ),
            SizedBox(height: 16),
            Text('Loading gate entries...',
                style: TextStyle(color: Color(0xFFB8A99A))),
          ],
        ),
      );
    }

    if (_errorMessage != null && _allEntries.isEmpty) {
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
              onPressed: () {
                _entriesSub?.cancel();
                _startEntriesStream();
              },
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

    if (_entries.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.history, size: 70, color: Color(0xFFE0D5C1)),
            SizedBox(height: 16),
            Text(
              'No gate entries found',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF6B5B4F)),
            ),
            SizedBox(height: 8),
            Text(
              'Scan RFID tags or generate QR codes to see entries',
              style: TextStyle(color: Color(0xFFB8A99A), fontSize: 13),
            ),
          ],
        ),
      );
    }

    final paginated = _paginatedEntries;
    final total = _totalPages;
    final padding = kIsWeb ? 20.0 : 12.0;

    return Column(
      children: [
        // Filter chips
        if (_dateRange != null ||
            _selectedResident != 'all' ||
            _selectedEntryType != 'all')
          Container(
            margin: EdgeInsets.fromLTRB(padding, padding, padding, 0),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE0D5C1), width: 1),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFD4C4A8).withOpacity(0.15),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  const Icon(Icons.filter_alt,
                      size: 14, color: Color(0xFF8D6E63)),
                  const SizedBox(width: 6),
                  if (_dateRange != null)
                    Chip(
                      backgroundColor: Colors.white,
                      label: Text(
                        '📅 ${DateFormat('MMM dd').format(_dateRange!.start)} - ${DateFormat('MMM dd').format(_dateRange!.end)}',
                        style: const TextStyle(
                            color: Color(0xFF6B5B4F), fontSize: 11),
                      ),
                      deleteIconColor: const Color(0xFFB8A99A),
                      onDeleted: () {
                        setState(() => _dateRange = null);
                        _applyFilters();
                      },
                    ),
                  if (_selectedResident != 'all')
                    Chip(
                      backgroundColor: Colors.white,
                      label: Text(
                        '👤 ${_residentNames[_selectedResident] ?? 'Unknown'}',
                        style: const TextStyle(
                            color: Color(0xFF6B5B4F), fontSize: 11),
                      ),
                      deleteIconColor: const Color(0xFFB8A99A),
                      onDeleted: () {
                        setState(() => _selectedResident = 'all');
                        _applyFilters();
                      },
                    ),
                  if (_selectedEntryType != 'all')
                    Chip(
                      backgroundColor: Colors.white,
                      label: Text(
                        '🔖 ${_selectedEntryType.toUpperCase().replaceFirst('UHF_', '')}',
                        style: const TextStyle(
                            color: Color(0xFF6B5B4F), fontSize: 11),
                      ),
                      deleteIconColor: const Color(0xFFB8A99A),
                      onDeleted: () {
                        setState(() => _selectedEntryType = 'all');
                        _applyFilters();
                      },
                    ),
                  const SizedBox(width: 6),
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _dateRange = null;
                        _selectedResident = 'all';
                        _selectedEntryType = 'all';
                      });
                      _applyFilters();
                    },
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFF8D6E63),
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      minimumSize: Size.zero,
                    ),
                    child: const Text('Clear All',
                        style: TextStyle(fontSize: 11)),
                  ),
                ],
              ),
            ),
          ),

        // Stat cards
        Padding(
          padding: EdgeInsets.all(padding),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [
              _buildStatCard('📊 Total', _entries.length.toString(),
                  Icons.door_front_door, const Color(0xFFD4C4A8), screenWidth),
              _buildStatCard(
                  '📡 RFID',
                  _entries
                      .where((e) =>
                  e['entryType'] == 'uhf_rfid' ||
                      e['entryType'] == 'rfid')
                      .length
                      .toString(),
                  Icons.nfc,
                  const Color(0xFFC4A882),
                  screenWidth),
              _buildStatCard(
                  '👥 Visitors',
                  _entries
                      .where((e) => e['entryType'] == 'qr_visitor')
                      .length
                      .toString(),
                  Icons.people,
                  const Color(0xFFB8A99A),
                  screenWidth),
            ],
          ),
        ),

        // Page size selector
        Container(
          margin: EdgeInsets.symmetric(horizontal: padding),
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
          child: Row(
            children: [
              const Icon(Icons.list_alt,
                  size: 14, color: Color(0xFFB8A99A)),
              const SizedBox(width: 6),
              const Text('Per page:',
                  style: TextStyle(
                      fontSize: 11,
                      color: Color(0xFFB8A99A),
                      fontWeight: FontWeight.w500)),
              const Spacer(),
              ..._pageSizeOptions(),
            ],
          ),
        ),

        const SizedBox(height: 10),

        // List
        Expanded(
          child: ListView.builder(
            padding: EdgeInsets.symmetric(horizontal: padding),
            itemCount: paginated.length,
            itemBuilder: (context, index) {
              final entry = paginated[index];
              final timestamp = _getEntryTimestamp(entry);
              final entryType = entry['entryType'] ?? 'unknown';
              final residentName = entry['residentName'] ?? 'Unknown';
              final visitorName = entry['visitorName'];

              final globalIndex = _pageSize == 0
                  ? index + 1
                  : ((_currentPage - 1) * _pageSize) + index + 1;

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
                    border:
                    Border.all(color: const Color(0xFFE0D5C1), width: 1),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            _getTypeColor(entryType),
                            _getTypeColor(entryType).withOpacity(0.7),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        _getTypeIcon(entryType),
                        color: const Color(0xFFFFF8F0),
                        size: 20,
                      ),
                    ),
                    // ✅ Fixed-width index + Expanded name + ellipsis
                    title: Row(
                      children: [
                        SizedBox(
                          width: 32,
                          child: Text(
                            '#$globalIndex',
                            style: const TextStyle(
                              fontSize: 10,
                              color: Color(0xFFB8A99A),
                              fontWeight: FontWeight.w600,
                              fontFamily: 'monospace',
                            ),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            residentName,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF6B5B4F),
                              fontSize: 13,
                            ),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        ),
                      ],
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 2),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFD4C4A8).withOpacity(0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            _getEntryTypeDisplay(entryType),
                            style: const TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF8D6E63),
                            ),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        ),
                        if (visitorName != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(
                              '👤 $visitorName',
                              style: const TextStyle(
                                  fontSize: 10, color: Color(0xFFB8A99A)),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                          ),
                        Text(
                          '🕐 ${DateFormat('MMM dd, yyyy • hh:mm a').format(timestamp)}',
                          style: const TextStyle(
                              fontSize: 10, color: Color(0xFFD4C4A8)),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),

        // Pagination
        if (_pageSize != 0 && total > 1)
          Container(
            margin: EdgeInsets.fromLTRB(padding, 0, padding, padding),
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
                        color: const Color(0xFFD4C4A8).withOpacity(0.15),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        'Page $_currentPage of $total  •  ${_entries.length} entries',
                        style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFF6B5B4F),
                          fontWeight: FontWeight.w600,
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
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
    );
  }

  List<Widget> _pageSizeOptions() {
    const options = <Map<String, dynamic>>[
      {'label': '10', 'value': 10},
      {'label': '20', 'value': 20},
      {'label': '50', 'value': 50},
      {'label': '100', 'value': 100},
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

  Widget _buildStatCard(String title, String value, IconData icon,
      Color color, double screenWidth) {
    double cardWidth = screenWidth < 600 ? (screenWidth / 3) - 16 : 100;
    double iconSize = screenWidth < 600 ? 14 : 16;
    double fontSize = screenWidth < 600 ? 11 : 13;
    double labelSize = screenWidth < 600 ? 8 : 9;

    return Container(
      width: cardWidth.clamp(80, 120),
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.3), width: 1),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFD4C4A8).withOpacity(0.12),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: iconSize),
          const SizedBox(height: 2),
          Text(value,
              style: TextStyle(
                  fontSize: fontSize,
                  fontWeight: FontWeight.bold,
                  color: color),
              overflow: TextOverflow.ellipsis,
              maxLines: 1),
          Text(title,
              style: TextStyle(
                  fontSize: labelSize,
                  color: color,
                  fontWeight: FontWeight.w500),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
              textAlign: TextAlign.center),
        ],
      ),
    );
  }

  IconData _getTypeIcon(String type) {
    switch (type) {
      case 'rfid':
      case 'uhf_rfid':
        return Icons.nfc;
      case 'qr_visitor':
        return Icons.qr_code;
      case 'manual':
        return Icons.person;
      default:
        return Icons.door_front_door;
    }
  }

  Color _getTypeColor(String type) {
    switch (type) {
      case 'rfid':
      case 'uhf_rfid':
        return const Color(0xFFD4C4A8);
      case 'qr_visitor':
        return const Color(0xFFC4A882);
      case 'manual':
        return const Color(0xFFB8A99A);
      default:
        return const Color(0xFF8D6E63);
    }
  }

  // ==================== FILTER DIALOG ====================
  void _showFilterDialog() {
    String searchText = '';
    final searchController = TextEditingController();

    final allResidents = <MapEntry<String, String>>[];
    for (final entry in _residentNames.entries) {
      if (entry.value.trim().isNotEmpty && entry.value != 'Unknown') {
        allResidents.add(entry);
      }
    }
    allResidents.sort((a, b) =>
        a.value.toLowerCase().compareTo(b.value.toLowerCase()));

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final filteredResidents = searchText.isEmpty
                ? allResidents
                : allResidents
                .where((r) => r.value
                .toLowerCase()
                .contains(searchText.toLowerCase()))
                .toList();

            return AlertDialog(
              title: const Text('🔍 Filter Entries',
                  style: TextStyle(
                      color: Color(0xFF6B5B4F),
                      fontWeight: FontWeight.bold,
                      fontSize: 15)),
              backgroundColor: const Color(0xFFFFF8F0),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
                side:
                const BorderSide(color: Color(0xFFE0D5C1), width: 1.5),
              ),
              content: SizedBox(
                width: 380,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      InkWell(
                        onTap: () async {
                          final picked = await showDateRangePicker(
                            context: context,
                            firstDate: DateTime(2024),
                            lastDate: DateTime.now(),
                            builder: (context, child) {
                              return Theme(
                                data: Theme.of(context).copyWith(
                                  colorScheme: const ColorScheme.light(
                                    primary: Color(0xFFD4C4A8),
                                    onPrimary: Color(0xFFFFF8F0),
                                    surface: Color(0xFFFFF8F0),
                                  ),
                                ),
                                child: child!,
                              );
                            },
                          );
                          if (picked != null) {
                            setDialogState(() => _dateRange = picked);
                          }
                        },
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                                color: const Color(0xFFE0D5C1), width: 1),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.calendar_today,
                                  size: 16, color: Color(0xFFD4C4A8)),
                              const SizedBox(width: 10),
                              const Text(
                                '📅 Date Range',
                                style: TextStyle(
                                  color: Color(0xFF6B5B4F),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  _dateRange == null
                                      ? 'Select range'
                                      : '${DateFormat('MMM dd').format(_dateRange!.start)} - ${DateFormat('MMM dd').format(_dateRange!.end)}',
                                  style: TextStyle(
                                    color: _dateRange == null
                                        ? const Color(0xFFB8A99A)
                                        : const Color(0xFF8D6E63),
                                    fontSize: 11,
                                    fontWeight: _dateRange == null
                                        ? FontWeight.normal
                                        : FontWeight.w600,
                                  ),
                                  textAlign: TextAlign.right,
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1,
                                ),
                              ),
                              if (_dateRange != null) ...[
                                const SizedBox(width: 6),
                                GestureDetector(
                                  onTap: () => setDialogState(
                                          () => _dateRange = null),
                                  child: const Icon(Icons.clear,
                                      size: 16,
                                      color: Color(0xFFB8A99A)),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 12),

                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: const Color(0xFFE0D5C1), width: 1),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.person,
                                    size: 14, color: Color(0xFFB8A99A)),
                                SizedBox(width: 6),
                                Text('Resident',
                                    style: TextStyle(
                                        color: Color(0xFFB8A99A),
                                        fontSize: 11,
                                        fontWeight: FontWeight.w500)),
                              ],
                            ),
                            const SizedBox(height: 8),
                            TextField(
                              controller: searchController,
                              decoration: InputDecoration(
                                hintText: 'Search resident name...',
                                hintStyle: const TextStyle(
                                    color: Color(0xFFB8A99A),
                                    fontSize: 12),
                                prefixIcon: const Icon(Icons.search,
                                    size: 18, color: Color(0xFFD4C4A8)),
                                suffixIcon: searchText.isNotEmpty
                                    ? IconButton(
                                  icon: const Icon(Icons.clear,
                                      size: 16,
                                      color: Color(0xFFB8A99A)),
                                  onPressed: () {
                                    searchController.clear();
                                    setDialogState(
                                            () => searchText = '');
                                  },
                                )
                                    : null,
                                isDense: true,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: const BorderSide(
                                      color: Color(0xFFE0D5C1)),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: const BorderSide(
                                      color: Color(0xFFE0D5C1)),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: const BorderSide(
                                      color: Color(0xFFD4C4A8), width: 2),
                                ),
                                filled: true,
                                fillColor: const Color(0xFFFFF8F0),
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 8),
                              ),
                              onChanged: (value) {
                                setDialogState(() => searchText = value);
                              },
                            ),
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: const Color(0xFFD4C4A8)
                                    .withOpacity(0.15),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.check_circle,
                                      size: 14, color: Color(0xFF8D6E63)),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      _selectedResident == 'all'
                                          ? 'All Residents'
                                          : _residentNames[
                                      _selectedResident] ??
                                          'Unknown',
                                      style: const TextStyle(
                                          fontSize: 12,
                                          color: Color(0xFF6B5B4F),
                                          fontWeight: FontWeight.w600),
                                      overflow: TextOverflow.ellipsis,
                                      maxLines: 1,
                                    ),
                                  ),
                                  if (_selectedResident != 'all')
                                    GestureDetector(
                                      onTap: () => setDialogState(
                                              () => _selectedResident = 'all'),
                                      child: const Text('Reset',
                                          style: TextStyle(
                                              fontSize: 11,
                                              color: Color(0xFFD32F2F),
                                              fontWeight: FontWeight.w600)),
                                    ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 8),
                            Container(
                              constraints:
                              const BoxConstraints(maxHeight: 200),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                    color: const Color(0xFFE0D5C1),
                                    width: 1),
                              ),
                              child: SingleChildScrollView(
                                child: Column(
                                  children: [
                                    _buildResidentOption(
                                      id: 'all',
                                      name: 'All Residents',
                                      isSelected: _selectedResident == 'all',
                                      onTap: () => setDialogState(
                                              () => _selectedResident = 'all'),
                                    ),
                                    const Divider(height: 1),
                                    if (filteredResidents.isEmpty)
                                      const Padding(
                                        padding: EdgeInsets.all(12),
                                        child: Text(
                                          'No residents match your search',
                                          style: TextStyle(
                                              fontSize: 11,
                                              color: Color(0xFFB8A99A),
                                              fontStyle: FontStyle.italic),
                                        ),
                                      )
                                    else
                                      ...filteredResidents.map((r) {
                                        return _buildResidentOption(
                                          id: r.key,
                                          name: r.value,
                                          isSelected:
                                          _selectedResident == r.key,
                                          onTap: () => setDialogState(
                                                  () =>
                                              _selectedResident = r.key),
                                        );
                                      }).toList(),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 12),

                      DropdownButtonFormField<String>(
                        value: _selectedEntryType,
                        decoration: InputDecoration(
                          labelText: '🔖 Entry Type',
                          labelStyle: const TextStyle(
                              color: Color(0xFFB8A99A), fontSize: 11),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide:
                            const BorderSide(color: Color(0xFFE0D5C1)),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide:
                            const BorderSide(color: Color(0xFFE0D5C1)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(
                                color: Color(0xFFD4C4A8), width: 2),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 8),
                        ),
                        items: const [
                          DropdownMenuItem(
                              value: 'all',
                              child: Text('All Types',
                                  style: TextStyle(fontSize: 12))),
                          DropdownMenuItem(
                              value: 'uhf_rfid',
                              child: Text('RFID 📡',
                                  style: TextStyle(fontSize: 12))),
                          DropdownMenuItem(
                              value: 'qr_visitor',
                              child: Text('QR Visitor 📱',
                                  style: TextStyle(fontSize: 12))),
                          DropdownMenuItem(
                              value: 'manual',
                              child: Text('Manual Entry ✏️',
                                  style: TextStyle(fontSize: 12))),
                        ],
                        onChanged: (value) =>
                            setDialogState(() => _selectedEntryType = value!),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFFB8A99A)),
                  child:
                  const Text('Cancel', style: TextStyle(fontSize: 12)),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    _applyFilters();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFD4C4A8),
                    foregroundColor: const Color(0xFF6B5B4F),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  child:
                  const Text('Apply', style: TextStyle(fontSize: 12)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildResidentOption({
    required String id,
    required String name,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        color: isSelected
            ? const Color(0xFFD4C4A8).withOpacity(0.15)
            : Colors.transparent,
        child: Row(
          children: [
            Icon(
              isSelected
                  ? Icons.radio_button_checked
                  : Icons.radio_button_off,
              size: 16,
              color: isSelected
                  ? const Color(0xFF8D6E63)
                  : const Color(0xFFB8A99A),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                name,
                style: TextStyle(
                  fontSize: 12,
                  color: const Color(0xFF6B5B4F),
                  fontWeight:
                  isSelected ? FontWeight.bold : FontWeight.normal,
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}