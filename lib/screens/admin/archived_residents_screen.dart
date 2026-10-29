// lib/screens/admin/archived_residents_screen.dart
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
  State<ArchivedResidentsScreen> createState() => _ArchivedResidentsScreenState();
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
      return r.fullName.toLowerCase().contains(q) || r.email.toLowerCase().contains(q) || (r.residentId?.toLowerCase().contains(q) ?? false) || (r.houseNumber?.toLowerCase().contains(q) ?? false) || (r.rfidTag?.toLowerCase().contains(q) ?? false);
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
                    child: StreamBuilder<List<ArchivedResidentModel>>(
                      stream: _archiveService.streamArchivedResidents(),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator(color: Color(0xFF8D6E63)));
                        return Padding(padding: const EdgeInsets.all(32), child: _buildWebContent(snapshot.data ?? []));
                      },
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
            Expanded(
              child: StreamBuilder<List<ArchivedResidentModel>>(
                stream: _archiveService.streamArchivedResidents(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator(color: Color(0xFFD4C4A8)));
                  return _buildMobileContent(snapshot.data ?? []);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWebSidebar() {
    return Container(
      width: 260,
      color: const Color(0xFF5D4037),
      child: Column(
        children: [
          const SizedBox(height: 40),
          const Icon(Icons.home_work, size: 48, color: Color(0xFFFFF8F0)),
          const SizedBox(height: 12),
          const Text('Florence Homes', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFFFFF8F0), letterSpacing: 1)),
          const Text('Admin Portal', style: TextStyle(fontSize: 12, color: Color(0xFFD4C4A8))),
          const SizedBox(height: 40),
          _buildWebSidebarItem(Icons.dashboard, 'Dashboard', onTap: () => Navigator.pop(context)),
          _buildWebSidebarItem(Icons.people, 'Residents', isActive: true, onTap: () => Navigator.pop(context)),
          _buildWebSidebarItem(Icons.security, 'Guards', onTap: () => Navigator.pop(context)),
          _buildWebSidebarItem(Icons.pending_actions, 'Pending Approvals', onTap: () => Navigator.pop(context)),
          _buildWebSidebarItem(Icons.history, 'Gate History', onTap: () => Navigator.pop(context)),
          const Spacer(),
          ListTile(leading: const Icon(Icons.logout, color: Color(0xFFD4C4A8)), title: const Text('Back to Dashboard', style: TextStyle(color: Color(0xFFD4C4A8), fontSize: 13)), onTap: () => Navigator.pop(context)),
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
          const Text('Archived Residents', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF5D4037))),
          _headerIconButton(icon: Icons.delete_sweep_outlined, tooltip: 'Clear entire archive', onTap: _confirmClearAll, color: const Color(0xFFD32F2F)),
        ],
      ),
    );
  }

  Widget _buildWebContent(List<ArchivedResidentModel> all) {
    final filtered = _filter(all);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: const Color(0xFF8D6E63).withOpacity(0.1), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFF8D6E63).withOpacity(0.3))),
          child: Row(children: [const Icon(Icons.info_outline, size: 18, color: Color(0xFF8D6E63)), const SizedBox(width: 8), Expanded(child: Text('${filtered.length} archived · auto-moves to Records after ${ArchiveService.autoMigrateDays} days', style: const TextStyle(fontSize: 12, color: Color(0xFF5D4037), height: 1.4)))]),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFE0D5C1))),
          child: Row(children: [const Icon(Icons.search, color: Color(0xFF8D6E63)), const SizedBox(width: 12), Expanded(child: TextField(controller: _searchController, onChanged: (v) => setState(() => _searchQuery = v), decoration: const InputDecoration(hintText: 'Search archived...', border: InputBorder.none, isDense: true))), if (_searchQuery.isNotEmpty) IconButton(icon: const Icon(Icons.clear, size: 20), onPressed: () { _searchController.clear(); setState(() => _searchQuery = ''); })]),
        ),
        const SizedBox(height: 24),
        Expanded(
          child: all.isEmpty
              ? const Center(child: Text('Archive is empty', style: TextStyle(fontSize: 16, color: Color(0xFF8D6E63))))
              : ListView.builder(itemCount: filtered.length, itemBuilder: (context, index) => _buildWebArchiveRow(filtered[index])),
        ),
      ],
    );
  }

  Widget _buildWebArchiveRow(ArchivedResidentModel r) {
    final daysLeft = _daysLeft(r);
    final isUrgent = daysLeft <= 5;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFE0D5C1))),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        shape: const Border(), collapsedShape: const Border(),
        leading: Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: const Color(0xFFD32F2F).withOpacity(0.1), borderRadius: BorderRadius.circular(10)), child: const Icon(Icons.person_off, size: 20, color: Color(0xFFD32F2F))),
        title: Text(r.fullName, style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF5D4037), fontSize: 15)),
        subtitle: Text(r.residentId ?? 'No ID', style: const TextStyle(color: Color(0xFF8D6E63), fontSize: 12, fontFamily: 'monospace')),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: isUrgent ? const Color(0xFFD32F2F).withOpacity(0.12) : const Color(0xFFFF9800).withOpacity(0.12), borderRadius: BorderRadius.circular(8)), child: Text(daysLeft == 0 ? 'Moves soon' : 'Moves in ${daysLeft}d', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: isUrgent ? const Color(0xFFD32F2F) : const Color(0xFFFF9800)))),
            const SizedBox(width: 10),
            Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5), decoration: BoxDecoration(color: const Color(0xFFD32F2F).withOpacity(0.1), borderRadius: BorderRadius.circular(12)), child: const Text('ARCHIVED', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFFD32F2F)))),
          ],
        ),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: const Color(0xFFFFF8F0), borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFFE0D5C1))),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildInfoRow(Icons.badge, 'Resident ID', r.residentId ?? 'N/A'),
                const SizedBox(height: 6),
                _buildInfoRow(Icons.email, 'Email', r.email.isEmpty ? 'Not provided' : r.email),
                const SizedBox(height: 6),
                _buildInfoRow(Icons.archive_outlined, 'Archived', DateFormat('MMM dd, yyyy • hh:mm a').format(r.archivedAt)),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: ElevatedButton.icon(onPressed: () => _confirmRestore(r), icon: const Icon(Icons.restore, size: 16), label: const Text('Restore'), style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF5D4037), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))))),
              const SizedBox(width: 10),
              Expanded(child: ElevatedButton.icon(onPressed: () => _confirmMoveToRecords(r), icon: const Icon(Icons.drive_file_move_outline, size: 16), label: const Text('To Records'), style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFC4A882), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))))),
              const SizedBox(width: 10),
              OutlinedButton.icon(onPressed: () => _confirmPermanentDelete(r), icon: const Icon(Icons.delete_forever, size: 16, color: Color(0xFFD32F2F)), label: const Text('Delete', style: TextStyle(color: Color(0xFFD32F2F))), style: OutlinedButton.styleFrom(side: const BorderSide(color: Color(0xFFD32F2F)), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)))),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMobileHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
      decoration: const BoxDecoration(color: Color(0xFF5D4037), borderRadius: BorderRadius.only(bottomLeft: Radius.circular(30), bottomRight: Radius.circular(30))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(children: [GestureDetector(onTap: () => Navigator.pop(context), child: Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), borderRadius: BorderRadius.circular(12)), child: const Icon(Icons.arrow_back, color: Color(0xFFFFF8F0), size: 20))), const SizedBox(width: 12), const Text('Archived', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: Color(0xFFFFF8F0), letterSpacing: 1))]),
              GestureDetector(onTap: _confirmClearAll, child: Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), borderRadius: BorderRadius.circular(12)), child: const Icon(Icons.delete_sweep_outlined, color: Color(0xFFFFF8F0), size: 20))),
            ],
          ),
          const SizedBox(height: 24),
          const Text('Deleted Residents', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFFFFF8F0))),
        ],
      ),
    );
  }

  Widget _buildMobileContent(List<ArchivedResidentModel> all) {
    final filtered = _filter(all);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFE0D5C1))),
            child: TextField(controller: _searchController, onChanged: (v) => setState(() => _searchQuery = v), decoration: const InputDecoration(hintText: 'Search archived...', hintStyle: TextStyle(fontSize: 13, color: Color(0xFFB8A99A)), border: InputBorder.none, isDense: true)),
          ),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: filtered.isEmpty
              ? const Center(child: Text('Archive is empty', style: TextStyle(color: Color(0xFF8D6E63), fontSize: 14)))
              : ListView.builder(padding: const EdgeInsets.symmetric(horizontal: 20), itemCount: filtered.length, itemBuilder: (context, index) => _buildMobileArchiveCard(filtered[index])),
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildMobileArchiveCard(ArchivedResidentModel r) {
    final daysLeft = _daysLeft(r);
    final isUrgent = daysLeft <= 5;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFE0D5C1))),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        shape: const Border(), collapsedShape: const Border(),
        leading: Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: const Color(0xFFD32F2F).withOpacity(0.1), borderRadius: BorderRadius.circular(10)), child: const Icon(Icons.person_off, size: 18, color: Color(0xFFD32F2F))),
        title: Text(r.fullName, style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF5D4037), fontSize: 14), maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text(r.residentId ?? 'No ID', style: const TextStyle(color: Color(0xFF8D6E63), fontSize: 11, fontFamily: 'monospace'), maxLines: 1, overflow: TextOverflow.ellipsis),
        trailing: Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: isUrgent ? const Color(0xFFD32F2F).withOpacity(0.12) : const Color(0xFFFF9800).withOpacity(0.12), borderRadius: BorderRadius.circular(8)), child: Text(daysLeft == 0 ? 'Soon' : '${daysLeft}d', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: isUrgent ? const Color(0xFFD32F2F) : const Color(0xFFFF9800)))),
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: const Color(0xFFFFF8F0), borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFFE0D5C1))),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _mobileInfoRow(Icons.badge, 'Resident ID', r.residentId ?? 'N/A'),
                const SizedBox(height: 6),
                _mobileInfoRow(Icons.email, 'Email', r.email.isEmpty ? 'Not provided' : r.email),
                const SizedBox(height: 6),
                _mobileInfoRow(Icons.archive_outlined, 'Archived', DateFormat('MMM dd, yyyy').format(r.archivedAt)),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: ElevatedButton.icon(onPressed: () => _confirmRestore(r), icon: const Icon(Icons.restore, size: 14), label: const Text('Restore', style: TextStyle(fontSize: 12)), style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF5D4037), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 10), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))))),
              const SizedBox(width: 8),
              Expanded(child: ElevatedButton.icon(onPressed: () => _confirmMoveToRecords(r), icon: const Icon(Icons.drive_file_move_outline, size: 14), label: const Text('Records', style: TextStyle(fontSize: 12)), style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFC4A882), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 10), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))))),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(width: double.infinity, child: OutlinedButton.icon(onPressed: () => _confirmPermanentDelete(r), icon: const Icon(Icons.delete_forever, size: 14, color: Color(0xFFD32F2F)), label: const Text('Delete Forever', style: TextStyle(fontSize: 11, color: Color(0xFFD32F2F))), style: OutlinedButton.styleFrom(side: const BorderSide(color: Color(0xFFD32F2F)), padding: const EdgeInsets.symmetric(vertical: 8), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))))),
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
        SizedBox(width: 80, child: Text(label, style: const TextStyle(fontSize: 11, color: Color(0xFF8D6E63), fontWeight: FontWeight.w500), overflow: TextOverflow.ellipsis, maxLines: 1)),
        Expanded(child: Text(value, style: const TextStyle(fontSize: 11, color: Color(0xFF5D4037)), maxLines: 2, overflow: TextOverflow.ellipsis)),
      ],
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 12, color: const Color(0xFFD4C4A8)),
        const SizedBox(width: 6),
        SizedBox(width: 90, child: Text(label, style: const TextStyle(fontSize: 11, color: Color(0xFFB8A99A), fontWeight: FontWeight.w500), overflow: TextOverflow.ellipsis, maxLines: 1)),
        Expanded(child: Text(value, style: const TextStyle(fontSize: 12, color: Color(0xFF5D4037)), maxLines: 2, overflow: TextOverflow.ellipsis)),
      ],
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
          decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12), border: Border.all(color: color.withOpacity(0.3))),
          child: Tooltip(message: tooltip, child: Icon(icon, color: color, size: 20)),
        ),
      ),
    );
  }

  Future<void> _confirmRestore(ArchivedResidentModel r) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFFFFF8F0),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: const BorderSide(color: Color(0xFFE0D5C1), width: 1.5)),
        title: const Text('Restore Resident', style: TextStyle(color: Color(0xFF5D4037))),
        content: Text('Restore ${r.fullName} back to the active residents list?', style: const TextStyle(color: Color(0xFF8D6E63))),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), style: TextButton.styleFrom(foregroundColor: const Color(0xFFB8A99A)), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF5D4037), foregroundColor: Colors.white), child: const Text('Restore')),
        ],
      ),
    );
    if (confirmed != true) return;
    final result = await _archiveService.restoreResident(r);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result['message'] ?? ''), backgroundColor: result['success'] == true ? const Color(0xFF8D6E63) : const Color(0xFFD32F2F), behavior: SnackBarBehavior.floating));
  }

  Future<void> _confirmMoveToRecords(ArchivedResidentModel r) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFFFFF8F0),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: const BorderSide(color: Color(0xFFE0D5C1), width: 1.5)),
        title: const Text('Move to Records', style: TextStyle(color: Color(0xFF5D4037))),
        content: Text('Move ${r.fullName} to Records? They can no longer be restored.', style: const TextStyle(color: Color(0xFF8D6E63))),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), style: TextButton.styleFrom(foregroundColor: const Color(0xFFB8A99A)), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFC4A882), foregroundColor: Colors.white), child: const Text('Move')),
        ],
      ),
    );
    if (confirmed != true) return;
    final adminName = await _currentAdminName();
    final result = await _archiveService.moveToRecords(r, adminUid: _authService.getCurrentUserId(), adminName: adminName);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result['message'] ?? ''), backgroundColor: result['success'] == true ? const Color(0xFF8D6E63) : const Color(0xFFD32F2F), behavior: SnackBarBehavior.floating));
  }

  Future<void> _confirmPermanentDelete(ArchivedResidentModel r) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFFFFF8F0),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: const BorderSide(color: Color(0xFFE0D5C1), width: 1.5)),
        title: const Text('Delete Permanently', style: TextStyle(color: Color(0xFFD32F2F))),
        content: Text('This will permanently delete ${r.fullName}. This action cannot be undone.', style: const TextStyle(color: Color(0xFF8D6E63))),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), style: TextButton.styleFrom(foregroundColor: const Color(0xFFB8A99A)), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFD32F2F), foregroundColor: Colors.white), child: const Text('Delete Forever')),
        ],
      ),
    );
    if (confirmed != true || r.archiveId == null) return;
    final ok = await _archiveService.permanentlyDelete(r.archiveId!);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(ok ? '${r.fullName} permanently deleted' : 'Delete failed'), backgroundColor: ok ? const Color(0xFF8D6E63) : const Color(0xFFD32F2F), behavior: SnackBarBehavior.floating));
  }

  Future<void> _confirmClearAll() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFFFFF8F0),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: const BorderSide(color: Color(0xFFE0D5C1), width: 1.5)),
        title: const Text('Clear Entire Archive', style: TextStyle(color: Color(0xFFD32F2F))),
        content: const Text('This will permanently delete ALL archived records. This action cannot be undone.', style: TextStyle(color: Color(0xFF8D6E63))),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), style: TextButton.styleFrom(foregroundColor: const Color(0xFFB8A99A)), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFD32F2F), foregroundColor: Colors.white), child: const Text('Clear All')),
        ],
      ),
    );
    if (confirmed != true) return;
    final count = await _archiveService.clearAllArchive();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$count archived records deleted'), backgroundColor: const Color(0xFF8D6E63), behavior: SnackBarBehavior.floating));
  }
}