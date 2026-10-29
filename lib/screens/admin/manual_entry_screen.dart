// lib/screens/admin/manual_entry_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../../services/gate_service.dart';
import '../../services/tcp_service.dart';
import '../../providers/auth_provider.dart';

class ManualEntryScreen extends StatefulWidget {
  const ManualEntryScreen({super.key});

  @override
  State<ManualEntryScreen> createState() => _ManualEntryScreenState();
}

class _ManualEntryScreenState extends State<ManualEntryScreen> {
  final GateService _gateService = GateService();
  final TCPService _tcpService = TCPService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _reasonController = TextEditingController();

  String _selectedEntryType = 'delivery';

  String? _selectedResidentId;
  String? _selectedResidentName;
  String? _selectedResidentHouse;

  bool _isSubmitting = false;

  bool _isGateUp = false;
  bool _isGateBusy = false;

  @override
  void initState() {
    super.initState();
    _tcpService.connect();
  }

  Future<void> _manualUp() async {
    if (_isGateBusy || _isGateUp) return;
    setState(() => _isGateBusy = true);

    try {
      bool success = await _tcpService.manualGateUp();
      if (!success) success = await _tcpService.manualGateUp();

      if (success) {
        setState(() => _isGateUp = true);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Gate is UP — scanning paused.'), backgroundColor: Color(0xFF8D6E63), behavior: SnackBarBehavior.floating));
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to raise gate. Check connection.'), backgroundColor: Color(0xFFD32F2F), behavior: SnackBarBehavior.floating));
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: const Color(0xFFD32F2F), behavior: SnackBarBehavior.floating));
      }
    } finally {
      if (mounted) setState(() => _isGateBusy = false);
    }
  }

  Future<void> _manualDown() async {
    if (_isGateBusy) return;
    setState(() => _isGateBusy = true);

    try {
      bool success = await _tcpService.manualGateDown();
      if (!success) success = await _tcpService.manualGateDown();

      if (success) {
        setState(() => _isGateUp = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Gate is DOWN — scanning resumed.'), backgroundColor: Color(0xFF8D6E63), behavior: SnackBarBehavior.floating));
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to lower gate. Check connection.'), backgroundColor: Color(0xFFD32F2F), behavior: SnackBarBehavior.floating));
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: const Color(0xFFD32F2F), behavior: SnackBarBehavior.floating));
      }
    } finally {
      if (mounted) setState(() => _isGateBusy = false);
    }
  }

  Future<void> _showResidentPicker() async {
    String searchText = '';
    final searchController = TextEditingController();

    final snapshot = await _firestore.collection('users').where('userType', isEqualTo: 'resident').where('isApproved', isEqualTo: true).get();

    final residents = snapshot.docs.map((doc) {
      final d = doc.data();
      return {'id': doc.id, 'name': (d['fullName'] ?? 'Unknown').toString(), 'house': (d['houseNumber'] ?? '').toString()};
    }).toList();

    residents.sort((a, b) => (a['name'] as String).toLowerCase().compareTo((b['name'] as String).toLowerCase()));

    if (!mounted) return;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final filtered = searchText.isEmpty ? residents : residents.where((r) { final q = searchText.toLowerCase(); return (r['name'] as String).toLowerCase().contains(q) || (r['house'] as String).toLowerCase().contains(q); }).toList();

          return AlertDialog(
            backgroundColor: const Color(0xFFFFF8F0),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: const BorderSide(color: Color(0xFFE0D5C1), width: 1.5)),
            title: Row(children: const [Icon(Icons.person_search, color: Color(0xFF8D6E63), size: 22), SizedBox(width: 10), Expanded(child: Text('Select Resident to Visit', style: TextStyle(color: Color(0xFF5D4037), fontWeight: FontWeight.bold, fontSize: 16)))]),
            content: SizedBox(
              width: 380, height: 400,
              child: Column(
                children: [
                  TextField(
                    controller: searchController,
                    decoration: InputDecoration(hintText: 'Search name or house...', hintStyle: const TextStyle(color: Color(0xFFB8A99A), fontSize: 12), prefixIcon: const Icon(Icons.search, size: 18, color: Color(0xFFD4C4A8)), suffixIcon: searchText.isNotEmpty ? IconButton(icon: const Icon(Icons.clear, size: 16, color: Color(0xFFB8A99A)), onPressed: () { searchController.clear(); setDialogState(() => searchText = ''); }) : null, isDense: true, border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE0D5C1))), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE0D5C1))), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFD4C4A8), width: 2)), filled: true, fillColor: Colors.white, contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8)),
                    onChanged: (v) => setDialogState(() => searchText = v),
                  ),
                  const SizedBox(height: 10),
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFFE0D5C1), width: 1)),
                      child: filtered.isEmpty
                          ? const Center(child: Padding(padding: EdgeInsets.all(20), child: Text('No residents found', style: TextStyle(fontSize: 12, color: Color(0xFFB8A99A), fontStyle: FontStyle.italic))))
                          : ListView.builder(
                        itemCount: filtered.length,
                        itemBuilder: (context, i) {
                          final r = filtered[i];
                          return InkWell(
                            onTap: () {
                              setState(() { _selectedResidentId = r['id'] as String; _selectedResidentName = r['name'] as String; _selectedResidentHouse = r['house'] as String; });
                              Navigator.pop(ctx);
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xFFF5F0E8), width: 1))),
                              child: Row(
                                children: [
                                  Container(width: 32, height: 32, decoration: BoxDecoration(color: const Color(0xFFD4C4A8).withOpacity(0.2), borderRadius: BorderRadius.circular(8)), child: Center(child: Text((r['name'] as String).isNotEmpty ? (r['name'] as String)[0].toUpperCase() : '?', style: const TextStyle(color: Color(0xFF8D6E63), fontWeight: FontWeight.bold)))),
                                  const SizedBox(width: 10),
                                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(r['name'] as String, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF5D4037))), if ((r['house'] as String).isNotEmpty) Text('🏠 ${r['house']}', style: const TextStyle(fontSize: 11, color: Color(0xFFB8A99A)))])),
                                  const Icon(Icons.chevron_right, size: 18, color: Color(0xFFD4C4A8)),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
            actions: [TextButton(onPressed: () => Navigator.pop(ctx), style: TextButton.styleFrom(foregroundColor: const Color(0xFFB8A99A)), child: const Text('Cancel'))],
          );
        },
      ),
    );
  }

  Future<void> _submitManualEntry() async {
    if (_selectedEntryType == 'guest' && _selectedResidentId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select a resident to visit'), backgroundColor: Color(0xFFFF9800), behavior: SnackBarBehavior.floating));
      return;
    }

    if (!_formKey.currentState!.validate()) return;
    if (_isSubmitting) return;

    setState(() => _isSubmitting = true);

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final adminId = authProvider.currentUser?.id;

    String residentName;
    String residentId;
    String visitorName = _nameController.text.trim();

    if (_selectedEntryType == 'delivery') {
      residentName = '📦 Delivery: $visitorName';
      residentId = 'manual_${DateTime.now().millisecondsSinceEpoch}';
    } else {
      residentName = '👤 Guest: $visitorName → ${_selectedResidentName ?? 'Unknown'}';
      residentId = _selectedResidentId!;
    }

    try {
      await _firestore.collection('gate_entries').add({
        'residentId': residentId,
        'residentName': residentName,
        'entryType': 'manual',
        'timestamp': DateTime.now().toIso8601String(),
        'visitorName': visitorName,
        'status': 'entry',
        if (_selectedEntryType == 'guest') ...{
          'visitingResidentId': _selectedResidentId,
          'visitingResidentName': _selectedResidentName,
          'visitingResidentHouse': _selectedResidentHouse,
          'note': _reasonController.text.trim(),
          'isGuest': true,
          'visitStatus': 'inside',
          'checkInTime': DateTime.now().toIso8601String(),
        },
      });

      await _firestore.collection('manual_openings').add({
        'adminId': adminId,
        'entryType': _selectedEntryType,
        'personName': visitorName,
        'reason': _selectedEntryType == 'guest' ? _reasonController.text.trim() : null,
        'visitedResident': _selectedEntryType == 'guest' ? _selectedResidentName : null,
        'timestamp': DateTime.now(),
        'status': 'completed',
      });

      bool gateOpened = await _tcpService.openGate();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(gateOpened ? '✅ Entry recorded and gate opened' : '⚠️ Entry recorded but gate failed to open'), backgroundColor: gateOpened ? const Color(0xFF8D6E63) : const Color(0xFFFF9800), behavior: SnackBarBehavior.floating));
      }

      _nameController.clear();
      _reasonController.clear();
      setState(() { _selectedResidentId = null; _selectedResidentName = null; _selectedResidentHouse = null; });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: const Color(0xFFD32F2F), behavior: SnackBarBehavior.floating));
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
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
                    child: SingleChildScrollView(padding: const EdgeInsets.all(32), child: _buildWebContent()),
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
              child: SingleChildScrollView(physics: const BouncingScrollPhysics(), padding: const EdgeInsets.all(20), child: Form(key: _formKey, child: _buildFormContent())),
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
          const Text('Guard Portal', style: TextStyle(fontSize: 12, color: Color(0xFFD4C4A8))),
          const SizedBox(height: 40),
          _buildWebSidebarItem(Icons.edit_document, 'Manual Entry', isActive: true, onTap: () {}),
          _buildWebSidebarItem(Icons.qr_code_scanner, 'QR Scanner', onTap: () => Navigator.pop(context)),
          _buildWebSidebarItem(Icons.exit_to_app, 'Pending Visits', onTap: () => Navigator.pop(context)),
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
          const Text('Manual Entry', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF5D4037))),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(color: (_isGateUp ? const Color(0xFFFF9800) : const Color(0xFF4CAF50)).withOpacity(0.1), borderRadius: BorderRadius.circular(20), border: Border.all(color: (_isGateUp ? const Color(0xFFFF9800) : const Color(0xFF4CAF50)).withOpacity(0.3))),
            child: Row(children: [Icon(_isGateUp ? Icons.arrow_upward : Icons.arrow_downward, size: 12, color: _isGateUp ? const Color(0xFFFF9800) : const Color(0xFF4CAF50)), const SizedBox(width: 6), Text(_isGateUp ? 'GATE UP' : 'GATE DOWN', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: _isGateUp ? const Color(0xFFFF9800) : const Color(0xFF4CAF50)))]),
          ),
        ],
      ),
    );
  }

  Widget _buildWebContent() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(flex: 2, child: Form(key: _formKey, child: _buildFormContent())),
        const SizedBox(width: 24),
        Expanded(flex: 1, child: _buildGateControlPanel()),
      ],
    );
  }

  Widget _buildGateControlPanel() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFE0D5C1))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(children: [Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFFFF9800), Color(0xFFF5A623)]), borderRadius: BorderRadius.circular(12)), child: const Icon(Icons.door_front_door, size: 24, color: Color(0xFFFFF8F0))), const SizedBox(width: 12), const Expanded(child: Text('Manual Gate Control', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF5D4037))))]),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(color: (_isGateUp ? const Color(0xFFFF9800) : const Color(0xFFD4C4A8)).withOpacity(0.15), borderRadius: BorderRadius.circular(12)),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(_isGateUp ? Icons.arrow_upward : Icons.arrow_downward, size: 14, color: _isGateUp ? const Color(0xFFFF9800) : const Color(0xFF8D6E63)), const SizedBox(width: 6), Text(_isGateUp ? 'GATE UP — SCANNING PAUSED' : 'GATE DOWN — SCANNING ACTIVE', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.5, color: _isGateUp ? const Color(0xFFFF9800) : const Color(0xFF8D6E63)))]),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: (_isGateBusy || _isGateUp) ? null : _manualUp,
            icon: (_isGateBusy && !_isGateUp) ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFFF8F0)))) : const Icon(Icons.keyboard_arrow_up, size: 20),
            label: const Text('Manual Up'),
            style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 46), backgroundColor: const Color(0xFFFF9800), foregroundColor: const Color(0xFFFFF8F0), disabledBackgroundColor: const Color(0xFFFF9800).withOpacity(0.4), disabledForegroundColor: const Color(0xFFFFF8F0).withOpacity(0.7), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
          ),
          const SizedBox(height: 10),
          ElevatedButton.icon(
            onPressed: _isGateBusy ? null : _manualDown,
            icon: const Icon(Icons.keyboard_arrow_down, size: 20),
            label: const Text('Manual Down'),
            style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 46), backgroundColor: const Color(0xFF6B5B4F), foregroundColor: const Color(0xFFFFF8F0), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
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
              Row(children: [GestureDetector(onTap: () => Navigator.pop(context), child: Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), borderRadius: BorderRadius.circular(12)), child: const Icon(Icons.arrow_back, color: Color(0xFFFFF8F0), size: 20))), const SizedBox(width: 12), const Text('Manual Entry', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: Color(0xFFFFF8F0), letterSpacing: 1))]),
              Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: (_isGateUp ? const Color(0xFFFF9800) : const Color(0xFF4CAF50)).withOpacity(0.2), borderRadius: BorderRadius.circular(12), border: Border.all(color: _isGateUp ? const Color(0xFFFF9800) : const Color(0xFF4CAF50))), child: Text(_isGateUp ? 'UP' : 'DOWN', style: TextStyle(fontSize: 10, color: _isGateUp ? const Color(0xFFFF9800) : const Color(0xFF4CAF50), fontWeight: FontWeight.bold))),
            ],
          ),
          const SizedBox(height: 24),
          const Text('Record Visitor', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFFFFF8F0))),
        ],
      ),
    );
  }

  Widget _buildFormContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!kIsWeb) ...[
          _buildGateControlPanel(),
          const SizedBox(height: 16),
        ],
        _buildCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [_iconBox(Icons.category), const SizedBox(width: 10), const Text('Entry Type', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF5D4037)))]),
              const SizedBox(height: 14),
              Row(children: [Expanded(child: _buildEntryTypeButton('delivery', Icons.local_shipping, '📦 Delivery')), const SizedBox(width: 10), Expanded(child: _buildEntryTypeButton('guest', Icons.people, '👤 Guest'))]),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _buildCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [_iconBox(Icons.person), const SizedBox(width: 10), Text(_selectedEntryType == 'delivery' ? 'Courier Information' : 'Visitor Information', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF5D4037)))]),
              const SizedBox(height: 14),
              TextFormField(controller: _nameController, decoration: _inputDecoration(label: _selectedEntryType == 'delivery' ? '🚚 Courier Name' : '👤 Visitor Full Name', icon: Icons.person_outline), validator: (value) { if (value == null || value.trim().isEmpty) return 'Please enter name'; return null; }),
              if (_selectedEntryType == 'guest') ...[const SizedBox(height: 14), _buildResidentPickerTile()],
            ],
          ),
        ),
        if (_selectedEntryType == 'guest') ...[
          const SizedBox(height: 16),
          _buildCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [_iconBox(Icons.info), const SizedBox(width: 10), const Text('Purpose & Note', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF5D4037)))]),
                const SizedBox(height: 14),
                TextFormField(controller: _reasonController, decoration: _inputDecoration(label: '💡 Reason for Visit', icon: Icons.description_outlined, hint: 'e.g., Visiting family, Friend visit'), maxLines: 3, validator: (value) { if (_selectedEntryType == 'guest' && (value == null || value.trim().isEmpty)) return 'Please enter a reason'; return null; }),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: const Color(0xFFFF9800).withOpacity(0.1), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFFF9800).withOpacity(0.3), width: 1.5)),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [const Icon(Icons.badge_outlined, color: Color(0xFFFF9800), size: 20), const SizedBox(width: 10), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: const [Text('IMPORTANT — ID Required', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFFE65100), letterSpacing: 0.5)), SizedBox(height: 4), Text('Hand over your valid ID to the guard. The ID will be returned when you leave the premises.', style: TextStyle(fontSize: 11, color: Color(0xFF6B5B4F), height: 1.4))]))]),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 20),
        ElevatedButton(
          onPressed: _isSubmitting ? null : _submitManualEntry,
          style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 52), backgroundColor: const Color(0xFF5D4037), foregroundColor: const Color(0xFFFFF8F0), elevation: 3, shadowColor: const Color(0xFF5D4037).withOpacity(0.5), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)), textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, letterSpacing: 1)),
          child: _isSubmitting ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFFF8F0)))) : const Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.record_voice_over, size: 20), SizedBox(width: 8), Text('Record Entry & Open Gate')]),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildResidentPickerTile() {
    final hasSelection = _selectedResidentId != null;
    return InkWell(
      onTap: _showResidentPicker,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: hasSelection ? const Color(0xFFD4C4A8).withOpacity(0.15) : Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: hasSelection ? const Color(0xFF8D6E63) : const Color(0xFFE0D5C1), width: 1.5)),
        child: Row(
          children: [
            Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: const Color(0xFFD4C4A8).withOpacity(0.2), borderRadius: BorderRadius.circular(10)), child: const Icon(Icons.home_work, size: 20, color: Color(0xFF8D6E63))),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Resident to Visit', style: TextStyle(fontSize: 10, color: Color(0xFFB8A99A), fontWeight: FontWeight.w600, letterSpacing: 0.5)),
                  const SizedBox(height: 2),
                  Text(hasSelection ? _selectedResidentName ?? 'Select' : 'Tap to select a resident', style: TextStyle(fontSize: 13, fontWeight: hasSelection ? FontWeight.bold : FontWeight.normal, color: hasSelection ? const Color(0xFF5D4037) : const Color(0xFFB8A99A), fontStyle: hasSelection ? FontStyle.normal : FontStyle.italic)),
                  if (hasSelection && _selectedResidentHouse != null && _selectedResidentHouse!.isNotEmpty) Text('🏠 ${_selectedResidentHouse}', style: const TextStyle(fontSize: 11, color: Color(0xFF8D6E63))),
                ],
              ),
            ),
            if (hasSelection) IconButton(icon: const Icon(Icons.clear, size: 18, color: Color(0xFFB8A99A)), onPressed: () { setState(() { _selectedResidentId = null; _selectedResidentName = null; _selectedResidentHouse = null; }); }, tooltip: 'Clear') else const Icon(Icons.chevron_right, size: 20, color: Color(0xFFD4C4A8)),
          ],
        ),
      ),
    );
  }

  Widget _buildCard({required Widget child}) {
    return Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: const Color(0xFFD4C4A8).withOpacity(0.15), blurRadius: 8, offset: const Offset(0, 3))]),
      child: Container(decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFE0D5C1), width: 1.5)), padding: EdgeInsets.all(kIsWeb ? 20 : 16), child: child),
    );
  }

  Widget _iconBox(IconData icon) {
    return Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: const Color(0xFFD4C4A8).withOpacity(0.15), borderRadius: BorderRadius.circular(10)), child: Icon(icon, color: const Color(0xFF8D6E63), size: 18));
  }

  InputDecoration _inputDecoration({required String label, required IconData icon, String? hint}) {
    return InputDecoration(labelText: label, hintText: hint, labelStyle: const TextStyle(color: Color(0xFFB8A99A), fontSize: 12), hintStyle: const TextStyle(color: Color(0xFFD4C4A8), fontSize: 12), prefixIcon: Icon(icon, color: const Color(0xFFD4C4A8), size: 20), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE0D5C1))), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE0D5C1))), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFD4C4A8), width: 2)), filled: true, fillColor: const Color(0xFFFFF8F0));
  }

  Widget _buildEntryTypeButton(String value, IconData icon, String label) {
    final isSelected = _selectedEntryType == value;
    return GestureDetector(
      onTap: () => setState(() => _selectedEntryType = value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(gradient: isSelected ? const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF5D4037), Color(0xFF8D6E63)]) : null, color: isSelected ? null : const Color(0xFFF5F0E8), borderRadius: BorderRadius.circular(12), border: Border.all(color: isSelected ? const Color(0xFF5D4037) : const Color(0xFFE0D5C1), width: 1.5)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 26, color: isSelected ? const Color(0xFFFFF8F0) : const Color(0xFF8D6E63)),
            const SizedBox(height: 6),
            Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: isSelected ? const Color(0xFFFFF8F0) : const Color(0xFF5D4037)), textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _reasonController.dispose();
    super.dispose();
  }
}