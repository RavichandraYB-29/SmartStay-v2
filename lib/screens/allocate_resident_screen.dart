import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../utils/admin_design_system.dart';
import '../widgets/admin_widgets.dart';

// ─────────────────────────────────────────────────────────────
// ALLOCATE RESIDENT SCREEN
// ─────────────────────────────────────────────────────────────
class AllocateResidentScreen extends StatefulWidget {
  final String adminId;
  const AllocateResidentScreen({super.key, required this.adminId});

  @override
  State<AllocateResidentScreen> createState() => _AllocateResidentScreenState();
}

class _AllocateResidentScreenState extends State<AllocateResidentScreen> {
  // ── Resident selection ──
  String _searchQuery = '';
  QueryDocumentSnapshot? _selectedResident;

  // ── Location dropdowns ──
  String? _hostelId, _pgId, _floorId, _roomId, _bedId;
  List<QueryDocumentSnapshot> _hostels = [], _pgs = [], _floors = [], _rooms = [];
  List<Map<String, dynamic>> _beds = [];
  bool _hostelLoading = true, _allocating = false;

  @override
  void initState() {
    super.initState();
    _loadHostels();
  }

  Future<void> _loadHostels() async {
    final uid = widget.adminId;
    try {
      final byOwner = await FirebaseFirestore.instance.collection('hostels').where('ownerId', isEqualTo: uid).get();
      final byAdmin = await FirebaseFirestore.instance.collection('hostels').where('adminId', isEqualTo: uid).get();
      final all = <String, QueryDocumentSnapshot>{};
      for (final d in byOwner.docs) all[d.id] = d;
      for (final d in byAdmin.docs) all[d.id] = d;
      setState(() { _hostels = all.values.toList(); _hostelLoading = false; });
    } catch (_) { setState(() => _hostelLoading = false); }
  }

  Future<void> _onHostelChanged(String? id) async {
    setState(() { _hostelId = id; _pgId = null; _floorId = null; _roomId = null; _bedId = null; _pgs = []; _floors = []; _rooms = []; _beds = []; });
    if (id == null) return;
    final snap = await FirebaseFirestore.instance.collection('hostels').doc(id).collection('pgs').get();
    setState(() => _pgs = snap.docs);
  }

  Future<void> _onPgChanged(String? id) async {
    setState(() { _pgId = id; _floorId = null; _roomId = null; _bedId = null; _floors = []; _rooms = []; _beds = []; });
    if (id == null || _hostelId == null) return;
    final snap = await FirebaseFirestore.instance.collection('hostels').doc(_hostelId).collection('pgs').doc(id).collection('floors').orderBy('floorIndex').get();
    setState(() => _floors = snap.docs);
  }

  Future<void> _onFloorChanged(String? id) async {
    setState(() { _floorId = id; _roomId = null; _bedId = null; _rooms = []; _beds = []; });
    if (id == null || _hostelId == null || _pgId == null) return;
    final snap = await FirebaseFirestore.instance.collection('hostels').doc(_hostelId).collection('pgs').doc(_pgId).collection('floors').doc(id).collection('rooms').get();
    setState(() => _rooms = snap.docs);
  }

  Future<void> _onRoomChanged(String? id) async {
    setState(() { _roomId = id; _bedId = null; _beds = []; });
    if (id == null || _hostelId == null || _pgId == null || _floorId == null) return;
    await _bootstrapBedsIfNeeded(id);
    final snap = await FirebaseFirestore.instance.collection('hostels').doc(_hostelId).collection('pgs').doc(_pgId).collection('floors').doc(_floorId).collection('rooms').doc(id).collection('beds').orderBy('bedNumber').get();
    final beds = snap.docs.map((d) => {...d.data() as Map<String, dynamic>, 'id': d.id}).toList();
    setState(() => _beds = beds);
  }

  Future<void> _bootstrapBedsIfNeeded(String roomId) async {
    final roomRef = FirebaseFirestore.instance.collection('hostels').doc(_hostelId).collection('pgs').doc(_pgId).collection('floors').doc(_floorId).collection('rooms').doc(roomId);
    final bedsRef = roomRef.collection('beds');
    final existing = await bedsRef.get();
    if (existing.docs.isNotEmpty) return;
    final rd = (await roomRef.get()).data() as Map<String, dynamic>? ?? {};
    final total = rd['totalBeds'] is int ? rd['totalBeds'] as int : int.tryParse('${rd['totalBeds']}') ?? 1;
    final batch = FirebaseFirestore.instance.batch();
    for (int i = 1; i <= total; i++) {
      batch.set(bedsRef.doc('B$i'), {'bedNumber': 'B$i', 'isOccupied': false, 'residentId': null});
    }
    await batch.commit();
  }

  bool get _canAllocate =>
      _selectedResident != null && _hostelId != null && _pgId != null && _floorId != null && _roomId != null && _bedId != null;

  Future<void> _confirmAllocation() async {
    if (!_canAllocate) return;
    final r = _selectedResident!;
    final rName = ((r.data() as Map<String, dynamic>)['fullName'] ?? (r.data() as Map<String, dynamic>)['name'] ?? 'Resident').toString();
    final confirmed = await showAdminConfirmDialog(
      context,
      title: 'Confirm Allocation?',
      message: 'Allocate $rName to bed $_bedId?',
      confirmLabel: 'Allocate',
    );
    if (!confirmed || !mounted) return;

    setState(() => _allocating = true);
    try {
      final bedRef = FirebaseFirestore.instance
          .collection('hostels').doc(_hostelId)
          .collection('pgs').doc(_pgId)
          .collection('floors').doc(_floorId)
          .collection('rooms').doc(_roomId)
          .collection('beds').doc(_bedId);
      final roomRef = FirebaseFirestore.instance
          .collection('hostels').doc(_hostelId)
          .collection('pgs').doc(_pgId)
          .collection('floors').doc(_floorId)
          .collection('rooms').doc(_roomId);
      final pgRef = FirebaseFirestore.instance.collection('hostels').doc(_hostelId).collection('pgs').doc(_pgId);
      final residentRef = FirebaseFirestore.instance.collection('residents').doc(r.id);
      final floorRef = FirebaseFirestore.instance.collection('hostels').doc(_hostelId).collection('pgs').doc(_pgId).collection('floors').doc(_floorId);

      final batch = FirebaseFirestore.instance.batch();
      batch.update(bedRef, {'isOccupied': true, 'residentId': r.id, 'allocatedAt': FieldValue.serverTimestamp()});
      batch.update(roomRef, {'availableBeds': FieldValue.increment(-1), 'occupiedBeds': FieldValue.increment(1)});
      batch.update(pgRef, {'availableBeds': FieldValue.increment(-1)});
      batch.update(floorRef, {'availableBeds': FieldValue.increment(-1)});
      batch.update(residentRef, {
        'isAllocated': true,
        'status': 'active',
        'hostelId': _hostelId,
        'pgId': _pgId,
        'floorId': _floorId,
        'roomId': _roomId,
        'bedId': _bedId,
        'allocationDetails': {
          'hostelId': _hostelId, 'pgId': _pgId, 'floorId': _floorId,
          'roomId': _roomId, 'bedId': _bedId,
          'allocatedAt': FieldValue.serverTimestamp(),
          'allocatedByAdminId': widget.adminId,
        },
      });
      await batch.commit();

      if (!mounted) return;
      setState(() { _selectedResident = null; _bedId = null; _beds = []; _roomId = null; });
      await showAdminSuccessDialog(context, title: 'Allocated!', message: '$rName has been successfully allocated to bed $_bedId.');
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Allocation failed: $e')));
    } finally {
      if (mounted) setState(() => _allocating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F1117) : AdminColors.scaffoldLight,
      body: SafeArea(child: Column(children: [
        AdminPageHeader(
          title: 'Allocate Resident',
          subtitle: 'Dashboard → Allocation',
          icon: Icons.bed_rounded,
          iconGradient: AdminGradients.teal,
          onBack: () => Navigator.pop(context),
        ),
        Expanded(child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(children: [
            // ── Step 1: Select resident ──────────────────
            AdminSectionCard(
              title: 'Step 1 – Select Resident', icon: Icons.person_search_rounded,
              headerGradient: AdminGradients.headerLight, iconColor: AdminColors.primary,
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                AdminTextField(
                  label: 'Search', hint: 'Search by name or email...',
                  prefixIcon: Icons.search_rounded,
                  onChanged: (v) => setState(() { _searchQuery = v.trim().toLowerCase(); _selectedResident = null; }),
                ),
                const SizedBox(height: 14),
                StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance.collection('residents')
                      .where('adminId', isEqualTo: widget.adminId)
                      .where('isAllocated', isEqualTo: false)
                      .snapshots(),
                  builder: (ctx, snap) {
                    if (!snap.hasData) return const ShimmerBox(width: double.infinity, height: 100);
                    final docs = snap.data!.docs.where((d) {
                      if (_searchQuery.isEmpty) return true;
                      final data = d.data() as Map<String, dynamic>;
                      final name = ((data['name'] ?? data['fullName'] ?? '') as String).toLowerCase();
                      final email = ((data['email'] ?? '') as String).toLowerCase();
                      return name.contains(_searchQuery) || email.contains(_searchQuery);
                    }).toList();
                    if (docs.isEmpty) return const AdminEmptyState(icon: Icons.person_off_rounded, title: 'No unallocated residents', subtitle: 'All residents are allocated or search did not match.');
                    return Column(children: docs.map((d) {
                      final data = d.data() as Map<String, dynamic>;
                      final name = (data['fullName'] ?? data['name'] ?? 'Resident').toString();
                      final email = (data['email'] ?? '').toString();
                      final isSelected = _selectedResident?.id == d.id;
                      return GestureDetector(
                        onTap: () => setState(() => _selectedResident = isSelected ? null : d),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: isSelected ? AdminColors.primary.withOpacity(0.08) : (isDark ? const Color(0xFF252836) : const Color(0xFFF8F9FC)),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: isSelected ? AdminColors.primary : const Color(0xFFE5E7EB), width: isSelected ? 2 : 1),
                          ),
                          child: Row(children: [
                            CircleAvatar(
                              radius: 18,
                              backgroundColor: isSelected ? AdminColors.primary : AdminColors.primary.withOpacity(0.15),
                              child: Text(name.isNotEmpty ? name[0].toUpperCase() : '?', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: isSelected ? Colors.white : AdminColors.primary, fontFamily: 'Inter')),
                            ),
                            const SizedBox(width: 12),
                            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text(name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, fontFamily: 'Inter')),
                              Text(email, style: const TextStyle(fontSize: 12, color: AdminColors.textSecondary, fontFamily: 'Inter')),
                            ])),
                            if (isSelected) const Icon(Icons.check_circle_rounded, color: AdminColors.primary),
                          ]),
                        ),
                      );
                    }).toList());
                  },
                ),
              ]),
            ),
            const SizedBox(height: 16),
            // ── Step 2: Location selection ──────────────
            AdminSectionCard(
              title: 'Step 2 – Select Location', icon: Icons.location_on_rounded,
              headerGradient: AdminGradients.headerTeal, iconColor: AdminColors.secondary,
              child: Column(children: [
                _hostelLoading
                  ? const ShimmerBox(width: double.infinity, height: 56)
                  : _Dropdown(label: 'Hostel', hint: 'Select Hostel',
                      items: _hostels.map((h) {
                        final d = h.data() as Map<String, dynamic>;
                        return DropdownMenuItem(value: h.id, child: Text((d['name'] ?? 'Hostel').toString()));
                      }).toList(),
                      value: _hostelId, onChanged: _onHostelChanged),
                if (_hostelId != null) ...[
                  const SizedBox(height: 12),
                  _pgs.isEmpty
                    ? const Text('No PGs found', style: TextStyle(fontSize: 12, color: AdminColors.textMuted, fontFamily: 'Inter'))
                    : _Dropdown(label: 'PG', hint: 'Select PG',
                        items: _pgs.map((p) {
                          final d = p.data() as Map<String, dynamic>;
                          return DropdownMenuItem(value: p.id, child: Text((d['name'] ?? d['pgName'] ?? 'PG').toString()));
                        }).toList(),
                        value: _pgId, onChanged: _onPgChanged),
                ],
                if (_pgId != null) ...[
                  const SizedBox(height: 12),
                  _floors.isEmpty
                    ? const Text('No floors found', style: TextStyle(fontSize: 12, color: AdminColors.textMuted, fontFamily: 'Inter'))
                    : _Dropdown(label: 'Floor', hint: 'Select Floor',
                        items: _floors.map((f) {
                          final d = f.data() as Map<String, dynamic>;
                          final n = (d['floorName'] ?? 'Floor ${d['floorIndex']}').toString();
                          return DropdownMenuItem(value: f.id, child: Text(n));
                        }).toList(),
                        value: _floorId, onChanged: _onFloorChanged),
                ],
                if (_floorId != null) ...[
                  const SizedBox(height: 12),
                  _rooms.isEmpty
                    ? const Text('No rooms found', style: TextStyle(fontSize: 12, color: AdminColors.textMuted, fontFamily: 'Inter'))
                    : _Dropdown(label: 'Room', hint: 'Select Room',
                        items: _rooms.map((r) {
                          final d = r.data() as Map<String, dynamic>;
                          final avail = (d['availableBeds'] ?? 0).toString();
                          return DropdownMenuItem(value: r.id, child: Text('Room ${d['roomNumber']} ($avail available)'));
                        }).toList(),
                        value: _roomId, onChanged: _onRoomChanged),
                ],
              ]),
            ),
            // ── Step 3: Bed grid ────────────────────────
            if (_beds.isNotEmpty) ...[
              const SizedBox(height: 16),
              AdminSectionCard(
                title: 'Step 3 – Select Bed', icon: Icons.hotel_rounded,
                headerGradient: AdminGradients.headerPurple, iconColor: AdminColors.primary,
                child: Column(children: [
                  BedGrid(
                    totalBeds: _beds.length,
                    occupiedBedIds: _beds.where((b) => b['isOccupied'] == true).map((b) => b['id'].toString()).toSet(),
                    selectedBedId: _bedId,
                    onBedTap: (id) => setState(() => _bedId = id),
                  ),
                  const SizedBox(height: 12),
                  Row(children: [
                    _BedLegend(color: AdminColors.success, label: 'Available'),
                    const SizedBox(width: 16),
                    _BedLegend(color: AdminColors.danger, label: 'Occupied'),
                    const SizedBox(width: 16),
                    _BedLegend(color: AdminColors.primary, label: 'Selected'),
                  ]),
                ]),
              ),
            ],
            const SizedBox(height: 24),
            AdminPrimaryButton(
              label: 'Confirm Allocation',
              icon: Icons.check_rounded,
              isLoading: _allocating,
              onPressed: _canAllocate ? _confirmAllocation : null,
            ),
          ]),
        )),
      ])),
    );
  }
}

class _Dropdown extends StatelessWidget {
  final String label, hint;
  final List<DropdownMenuItem<String>> items;
  final String? value;
  final ValueChanged<String?> onChanged;
  const _Dropdown({required this.label, required this.hint, required this.items, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, fontFamily: 'Inter', color: Color(0xFF374151))),
      const SizedBox(height: 6),
      DropdownButtonFormField<String>(
        value: value,
        decoration: InputDecoration(
          hintText: hint,
          filled: true,
          fillColor: isDark ? const Color(0xFF252836) : const Color(0xFFF8F9FC),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AdminColors.primary, width: 1.8)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        ),
        items: items,
        onChanged: onChanged,
        icon: const Icon(Icons.keyboard_arrow_down_rounded),
        borderRadius: BorderRadius.circular(12),
      ),
    ]);
  }
}

class _BedLegend extends StatelessWidget {
  final Color color; final String label;
  const _BedLegend({required this.color, required this.label});

  @override
  Widget build(BuildContext context) => Row(children: [
    Container(width: 12, height: 12, decoration: BoxDecoration(color: color.withOpacity(0.3), borderRadius: BorderRadius.circular(3), border: Border.all(color: color))),
    const SizedBox(width: 4),
    Text(label, style: TextStyle(fontSize: 11, color: color, fontFamily: 'Inter', fontWeight: FontWeight.w500)),
  ]);
}
