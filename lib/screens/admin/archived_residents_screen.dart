import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/archived_resident_model.dart';
import '../../services/archive_service.dart';
import '../../services/auth_service.dart';

class ArchivedResidentsScreen extends StatefulWidget {
  const ArchivedResidentsScreen({super.key});

  @override
  State<ArchivedResidentsScreen> createState() =>
      _ArchivedResidentsScreenState();
}

class _ArchivedResidentsScreenState extends State<ArchivedResidentsScreen> {
  final ArchiveService _archiveService = ArchiveService();
  final AuthService _authService = AuthService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<ArchivedResidentModel> _filter(List<ArchivedResidentModel> list) {
    if (_searchQuery.isEmpty) return list;
    final q = _searchQuery.toLowerCase();
    return list.where((r) {
      return r.fullName.toLowerCase().contains(q) ||
          r.email.toLowerCase().contains(q) ||
          (r.residentId?.toLowerCase().contains(q) ?? false) ||
          (r.houseNumber?.toLowerCase().contains(q) ?? false) ||
          (r.rfidTag?.toLowerCase().contains(q) ?? false);
    }).toList();
  }

  int _daysLeft(ArchivedResidentModel r) {
    final elapsed = DateTime.now().difference(r.archivedAt).inDays;
    final left = ArchiveService.autoMigrateDays - elapsed;
    return left < 0 ? 0 : left;
  }

  Future<String?> _currentAdminName() async {
    final uid = _authService.getCurrentUserId();
    if (uid == null) return null;
    final doc = await _firestore.collection('users').doc(uid).get();
    return doc.get('fullName') as String?;
  }

  // ============================================================
  // REUSABLE HEADER (inline)
  // ============================================================
  Widget _buildHeader() {
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
                _iconPill(
                  icon: Icons.arrow_back,
                  tooltip: 'Back',
                  onTap: () => Navigator.pop(context),
                ),
                const Spacer(),
                _iconPill(
                  icon: Icons.delete_sweep_outlined,
                  tooltip: 'Clear entire archive',
                  onTap: _confirmClearAll,
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: const [
              Icon(Icons.archive_outlined,
                  size: 26, color: Color(0xFFFFF8F0)),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Archived Residents',
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

  @override
  Widget build(BuildContext context) {
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
              _buildHeader(),
              Expanded(
                child: Align(
                  alignment: Alignment.topCenter,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: kIsWeb ? 900 : double.infinity,
                    ),
                    child:
                    StreamBuilder<List<ArchivedResidentModel>>(
                      stream: _archiveService.streamArchivedResidents(),
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
                        if (snapshot.hasError) {
                          return Center(
                            child: Text(
                              'Error: ${snapshot.error}',
                              style: const TextStyle(
                                  color: Color(0xFFD32F2F)),
                            ),
                          );
                        }

                        final all = snapshot.data ?? [];
                        final filtered = _filter(all);

                        if (all.isEmpty) {
                          return const Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.archive_outlined,
                                    size: 70, color: Color(0xFFE0D5C1)),
                                SizedBox(height: 16),
                                Text(
                                  'Archive is empty',
                                  style: TextStyle(
                                      fontSize: 16,
                                      color: Color(0xFF6B5B4F),
                                      fontWeight: FontWeight.w500),
                                ),
                                SizedBox(height: 8),
                                Text(
                                  'Deleted residents will appear here',
                                  style: TextStyle(
                                      color: Color(0xFFB8A99A),
                                      fontSize: 12),
                                ),
                              ],
                            ),
                          );
                        }

                        return Column(
                          children: [
                            Padding(
                              padding:
                              EdgeInsets.all(kIsWeb ? 20 : 12),
                              child: TextField(
                                controller: _searchController,
                                onChanged: (v) => setState(
                                        () => _searchQuery = v),
                                decoration: InputDecoration(
                                  hintText: 'Search archived...',
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
                                    borderRadius: BorderRadius.circular(14),
                                    borderSide: const BorderSide(
                                        color: Color(0xFFE0D5C1)),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(14),
                                    borderSide: const BorderSide(
                                        color: Color(0xFFE0D5C1)),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(14),
                                    borderSide: const BorderSide(
                                        color: Color(0xFFD4C4A8),
                                        width: 2),
                                  ),
                                  filled: true,
                                  fillColor: Colors.white,
                                  contentPadding:
                                  const EdgeInsets.symmetric(
                                      horizontal: 14, vertical: 12),
                                ),
                              ),
                            ),

                            Container(
                              margin: EdgeInsets.symmetric(
                                  horizontal: kIsWeb ? 20 : 12),
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: const Color(0xFFD4C4A8)
                                    .withOpacity(0.2),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.info_outline,
                                      size: 16,
                                      color: Color(0xFF8D6E63)),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      '${filtered.length} archived · auto-moves to Records after ${ArchiveService.autoMigrateDays} days',
                                      style: const TextStyle(
                                          fontSize: 11,
                                          color: Color(0xFF6B5B4F)),
                                      overflow: TextOverflow.ellipsis,
                                      maxLines: 2,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(height: 8),

                            Expanded(
                              child: ListView.builder(
                                padding:
                                EdgeInsets.all(kIsWeb ? 20 : 12),
                                itemCount: filtered.length,
                                itemBuilder: (context, index) =>
                                    _buildArchiveCard(filtered[index]),
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

  Widget _buildArchiveCard(ArchivedResidentModel r) {
    final daysLeft = _daysLeft(r);
    final isUrgent = daysLeft <= 5;

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
            child: const Icon(Icons.person_off,
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
              const SizedBox(height: 2),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      r.email.isEmpty ? 'No email on file' : r.email,
                      style: const TextStyle(
                          color: Color(0xFFB8A99A), fontSize: 11),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: isUrgent
                          ? const Color(0xFFD32F2F).withOpacity(0.12)
                          : const Color(0xFFFF9800).withOpacity(0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      daysLeft == 0
                          ? 'Moves soon'
                          : 'Moves in ${daysLeft}d',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        color: isUrgent
                            ? const Color(0xFFD32F2F)
                            : const Color(0xFFFF9800),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          trailing: Container(
            padding:
            const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFD32F2F).withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: const Color(0xFFD32F2F).withOpacity(0.3)),
            ),
            child: const Text(
              'ARCHIVED',
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.bold,
                color: Color(0xFFD32F2F),
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
                  _buildInfoRow(Icons.nfc, 'RFID',
                      r.rfidTag ?? 'Not registered'),
                  const SizedBox(height: 6),
                  _buildInfoRow(
                      Icons.calendar_today,
                      'Registered',
                      DateFormat('MMM dd, yyyy').format(r.createdAt)),
                  const SizedBox(height: 6),
                  _buildInfoRow(
                      Icons.archive_outlined,
                      'Archived',
                      DateFormat('MMM dd, yyyy • hh:mm a')
                          .format(r.archivedAt)),
                  if (r.archivedByName != null) ...[
                    const SizedBox(height: 6),
                    _buildInfoRow(Icons.admin_panel_settings, 'By',
                        r.archivedByName!),
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
            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _confirmRestore(r),
                    icon: const Icon(Icons.restore, size: 16),
                    label: const Text('Restore',
                        style: TextStyle(fontSize: 12)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF8D6E63),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _confirmMoveToRecords(r),
                    icon: const Icon(Icons.drive_file_move_outline,
                        size: 16),
                    label: const Text('To Records',
                        style: TextStyle(fontSize: 12)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFC4A882),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _confirmPermanentDelete(r),
                icon: const Icon(Icons.delete_forever,
                    size: 14, color: Color(0xFFD32F2F)),
                label: const Text('Delete Forever',
                    style:
                    TextStyle(fontSize: 11, color: Color(0xFFD32F2F))),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Color(0xFFD32F2F)),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
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
          width: 80,
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

  // ==================== RESTORE ====================
  Future<void> _confirmRestore(ArchivedResidentModel r) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFFFFF8F0),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: Color(0xFFE0D5C1), width: 1.5),
        ),
        title: const Text('Restore Resident',
            style: TextStyle(color: Color(0xFF6B5B4F))),
        content: Text(
          'Restore ${r.fullName} back to the active residents list?',
          style: const TextStyle(color: Color(0xFF8D6E63)),
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
              backgroundColor: const Color(0xFF8D6E63),
              foregroundColor: Colors.white,
            ),
            child: const Text('Restore'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final result = await _archiveService.restoreResident(r);
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(result['message'] ?? ''),
        backgroundColor: result['success'] == true
            ? const Color(0xFF8D6E63)
            : const Color(0xFFD32F2F),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // ==================== MOVE TO RECORDS ====================
  Future<void> _confirmMoveToRecords(ArchivedResidentModel r) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFFFFF8F0),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: Color(0xFFE0D5C1), width: 1.5),
        ),
        title: const Text('Move to Records',
            style: TextStyle(
                color: Color(0xFF5D4037), fontWeight: FontWeight.bold)),
        content: Text(
          'Move ${r.fullName} to Records?\n\n'
              'Records are read-only history. The resident will no longer be '
              'restorable from the Archive after this.',
          style: const TextStyle(color: Color(0xFF8D6E63), height: 1.5),
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
              backgroundColor: const Color(0xFFC4A882),
              foregroundColor: Colors.white,
            ),
            child: const Text('Move'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final adminName = await _currentAdminName();
    final result = await _archiveService.moveToRecords(
      r,
      adminUid: _authService.getCurrentUserId(),
      adminName: adminName,
    );

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(result['message'] ?? ''),
        backgroundColor: result['success'] == true
            ? const Color(0xFF8D6E63)
            : const Color(0xFFD32F2F),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // ==================== PERMANENT DELETE ====================
  Future<void> _confirmPermanentDelete(ArchivedResidentModel r) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFFFFF8F0),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: Color(0xFFE0D5C1), width: 1.5),
        ),
        title: const Text('Delete Permanently',
            style: TextStyle(
                color: Color(0xFFD32F2F), fontWeight: FontWeight.bold)),
        content: Text(
          'This will permanently delete ${r.fullName} from the archive. '
              'This action cannot be undone.\n\n'
              'Consider "Move to Records" instead to keep a permanent history.',
          style: const TextStyle(color: Color(0xFF8D6E63), height: 1.5),
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
              backgroundColor: const Color(0xFFD32F2F),
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete Forever'),
          ),
        ],
      ),
    );

    if (confirmed != true || r.archiveId == null) return;

    final ok = await _archiveService.permanentlyDelete(r.archiveId!);
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content:
        Text(ok ? '${r.fullName} permanently deleted' : 'Delete failed'),
        backgroundColor:
        ok ? const Color(0xFF8D6E63) : const Color(0xFFD32F2F),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // ==================== CLEAR ALL ====================
  Future<void> _confirmClearAll() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFFFFF8F0),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: Color(0xFFE0D5C1), width: 1.5),
        ),
        title: const Text('Clear Entire Archive',
            style: TextStyle(
                color: Color(0xFFD32F2F), fontWeight: FontWeight.bold)),
        content: const Text(
          'This will permanently delete ALL archived records. '
              'This action cannot be undone.\n\n'
              'Consider using "Move to Records" on individual entries instead.',
          style: TextStyle(color: Color(0xFF8D6E63), height: 1.5),
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
              backgroundColor: const Color(0xFFD32F2F),
              foregroundColor: Colors.white,
            ),
            child: const Text('Clear All'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final count = await _archiveService.clearAllArchive();
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$count archived records deleted'),
        backgroundColor: const Color(0xFF8D6E63),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}