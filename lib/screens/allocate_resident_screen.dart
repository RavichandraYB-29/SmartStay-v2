import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/allocation_service.dart';

enum _HostelQueryMode { ownerId, adminId }

class AllocateResidentScreen extends StatefulWidget {
  final String adminId;
  const AllocateResidentScreen({super.key, required this.adminId});

  @override
  State<AllocateResidentScreen> createState() => _AllocateResidentScreenState();
}

class _AllocateResidentScreenState extends State<AllocateResidentScreen> {
  final _searchController = TextEditingController();
  String _searchQuery = '';

  QueryDocumentSnapshot<Map<String, dynamic>>? _selectedResident;

  String? _hostelId;
  String? _floorId;
  String? _roomId;
  String? _bedId;
  String? _hostelName;
  String? _floorName;
  String? _roomNumber;
  String? _bedNumber;

  bool _saving = false;
  late final Future<_HostelQueryMode> _hostelModeFuture;
  final Set<String> _bootstrappedBedsForRooms = <String>{};
  bool _bootstrappingBeds = false;

  String _floorDisplayName(Map<String, dynamic> data, {int? indexFallback}) {
    final raw = (data['floorName'] ?? data['name'] ?? data['title'] ?? '')
        .toString();
    if (raw.trim().isNotEmpty) return raw.trim();

    final idxRaw = data['floorIndex'];
    final idx = idxRaw is int ? idxRaw : int.tryParse('$idxRaw');
    final useIdx = idx ?? indexFallback;
    if (useIdx == null) return 'Floor';

    const names = [
      'Ground Floor',
      'First Floor',
      'Second Floor',
      'Third Floor',
      'Fourth Floor',
      'Fifth Floor',
      'Sixth Floor',
    ];
    return useIdx >= 0 && useIdx < names.length
        ? names[useIdx]
        : 'Floor ${useIdx + 1}';
  }

  Future<void> _bootstrapBedsForSelectedRoom() async {
    final hostelId = _hostelId;
    final floorId = _floorId;
    final roomId = _roomId;
    if (hostelId == null || floorId == null || roomId == null) return;

    final key = '$hostelId/$floorId/$roomId';
    if (_bootstrappedBedsForRooms.contains(key) || _bootstrappingBeds) return;

    setState(() => _bootstrappingBeds = true);
    try {
      final roomRef = FirebaseFirestore.instance
          .collection('hostels')
          .doc(hostelId)
          .collection('floors')
          .doc(floorId)
          .collection('rooms')
          .doc(roomId);

      final roomSnap = await roomRef.get();
      if (!roomSnap.exists) return;

      final room = roomSnap.data() as Map<String, dynamic>;
      final tbRaw = room['totalBeds'] ?? 0;
      final totalBeds = tbRaw is int ? tbRaw : int.tryParse('$tbRaw') ?? 0;
      if (totalBeds <= 0) return;

      debugPrint('BEDS_BOOTSTRAP: creating $totalBeds beds for $key');

      final batch = FirebaseFirestore.instance.batch();
      for (int i = 1; i <= totalBeds; i++) {
        final bedDocId = 'B$i';
        final bedRef = roomRef.collection('beds').doc(bedDocId);
        batch.set(bedRef, {
          'bedNumber': bedDocId,
          'isOccupied': false,
          'residentId': null,
          'occupiedBy': null,
        }, SetOptions(merge: true));
      }
      await batch.commit();

      _bootstrappedBedsForRooms.add(key);
    } catch (e) {
      debugPrint('BEDS_BOOTSTRAP_ERROR: $e');
      _bootstrappedBedsForRooms.add(key); // avoid infinite loops
    } finally {
      if (mounted) setState(() => _bootstrappingBeds = false);
    }
  }

  @override
  void initState() {
    super.initState();
    _hostelModeFuture = _detectHostelMode();
    _searchController.addListener(() {
      final next = _searchController.text.trim();
      if (next == _searchQuery) return;
      setState(() => _searchQuery = next);
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<_HostelQueryMode> _detectHostelMode() async {
    final ownerSnap = await FirebaseFirestore.instance
        .collection('hostels')
        .where('ownerId', isEqualTo: widget.adminId)
        .limit(1)
        .get();
    return ownerSnap.docs.isNotEmpty
        ? _HostelQueryMode.ownerId
        : _HostelQueryMode.adminId;
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> _hostelsStream(
    _HostelQueryMode mode,
  ) {
    final hostels = FirebaseFirestore.instance.collection('hostels');
    return (mode == _HostelQueryMode.ownerId
            ? hostels.where('ownerId', isEqualTo: widget.adminId)
            : hostels.where('adminId', isEqualTo: widget.adminId))
        .snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> _residentsStream() {
    return FirebaseFirestore.instance
        .collection('residents')
        .where('adminId', isEqualTo: widget.adminId)
        .snapshots();
  }

  void _clearDownstream({required String level}) {
    setState(() {
      if (level == 'hostel') {
        _floorId = null;
        _roomId = null;
        _bedId = null;
      } else if (level == 'floor') {
        _roomId = null;
        _bedId = null;
      } else if (level == 'room') {
        _bedId = null;
      }
    });
  }

  void _resetAllocation() {
    setState(() {
      _hostelId = null;
      _floorId = null;
      _roomId = null;
      _bedId = null;
      _hostelName = null;
      _floorName = null;
      _roomNumber = null;
      _bedNumber = null;
    });
  }

  void _selectResident(QueryDocumentSnapshot<Map<String, dynamic>> r) {
    setState(() => _selectedResident = r);
    final d = r.data();
    final alloc = d['allocationDetails'];
    setState(() {
      _hostelId =
          (d['hostelId'] ?? (alloc is Map ? alloc['hostelId'] : null))
              as String?;
      _floorId =
          (d['floorId'] ?? (alloc is Map ? alloc['floorId'] : null)) as String?;
      _roomId =
          (d['roomId'] ?? (alloc is Map ? alloc['roomId'] : null)) as String?;
      _bedId =
          (d['bedId'] ??
                  d['bedSlot'] ??
                  (alloc is Map ? alloc['bedId'] : null) ??
                  (alloc is Map ? alloc['bedSlot'] : null))
              as String?;
      _hostelName = (alloc is Map ? alloc['hostelName'] : null)?.toString();
      _floorName = (alloc is Map ? alloc['floorName'] : null)?.toString();
      _roomNumber = (alloc is Map ? alloc['roomNumber'] : null)?.toString();
      _bedNumber = (alloc is Map ? alloc['bedNumber'] : null)?.toString();
    });
  }

  Future<void> _confirmAllocation() async {
    final r = _selectedResident;
    if (r == null) return;
    if (_hostelId == null ||
        _floorId == null ||
        _roomId == null ||
        _bedId == null) {
      await _dialog(
        'Incomplete Selection',
        'Please select hostel, floor, room, and bed.',
        true,
      );
      return;
    }
    setState(() => _saving = true);
    try {
      await AllocationService.upsertResidentAllocation(
        adminId: widget.adminId,
        residentId: r.id,
        hostelId: _hostelId!,
        floorId: _floorId!,
        roomId: _roomId!,
        bedId: _bedId!,
      );
      if (!mounted) return;
      await _dialog(
        'Allocation Updated',
        'Room allocation saved successfully.',
        false,
      );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      await _dialog(
        'Allocation Failed',
        e.toString().replaceFirst('Exception: ', ''),
        true,
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _dialog(String title, String msg, bool isError) async {
    if (!mounted) return;
    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title),
        content: Text(msg),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // If session disappears, close screen.
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.pop(context);
      });
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FB),
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFFF9FAFB), Color(0xFFF3F4F6)],
              ),
            ),
            child: SafeArea(
              child: Column(
                children: [
                  _topHeader(),
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, c) {
                        final wide = c.maxWidth >= 1100;
                        if (wide) {
                          return Row(
                            children: [
                              Expanded(
                                flex: 2,
                                child: SingleChildScrollView(
                                  padding: const EdgeInsets.fromLTRB(
                                    20,
                                    20,
                                    20,
                                    28,
                                  ),
                                  child: _leftPane(),
                                ),
                              ),
                              SizedBox(
                                width: 380,
                                child: Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                    0,
                                    20,
                                    20,
                                    28,
                                  ),
                                  child: _capacityCard(),
                                ),
                              ),
                            ],
                          );
                        }
                        return SingleChildScrollView(
                          padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
                          child: Column(
                            children: [
                              _leftPane(),
                              const SizedBox(height: 18),
                              _capacityCard(),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_saving)
            Container(
              color: Colors.black.withValues(alpha: 0.35),
              child: const Center(
                child: CircularProgressIndicator(color: Colors.white),
              ),
            ),
        ],
      ),
    );
  }

  Widget _topHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Color(0x11000000),
            blurRadius: 12,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          InkWell(
            onTap: () => Navigator.pop(context),
            borderRadius: BorderRadius.circular(10),
            child: const Padding(
              padding: EdgeInsets.all(6),
              child: Icon(Icons.arrow_back),
            ),
          ),
          const SizedBox(width: 12),
          Container(
            width: 42,
            height: 42,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF0D9488), Color(0xFF06B6D4)],
              ),
              borderRadius: BorderRadius.all(Radius.circular(12)),
              boxShadow: [
                BoxShadow(
                  color: Color(0x330D9488),
                  blurRadius: 10,
                  offset: Offset(0, 6),
                ),
              ],
            ),
            child: const Icon(Icons.bed, color: Colors.white),
          ),
          const SizedBox(width: 12),
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Allocate Room',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF134E4A),
                ),
              ),
              SizedBox(height: 4),
              Text(
                'Dashboard → Residents → Allocate Room',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _leftPane() {
    return Column(
      children: [
        _searchCard(),
        const SizedBox(height: 18),
        if (_selectedResident != null) _selectedResidentCard(),
        if (_selectedResident != null) const SizedBox(height: 18),
        if (_selectedResident != null) _allocationCard(),
        if (_selectedResident != null) const SizedBox(height: 18),
        if (_selectedResident != null) _actionRow(),
      ],
    );
  }

  Widget _card({
    required List<Color> headerGradient,
    required IconData icon,
    required Color iconColor,
    required String title,
    required Widget child,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(
            color: Color(0x11000000),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: headerGradient),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(18),
              ),
            ),
            child: Row(
              children: [
                Icon(icon, color: iconColor),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
          Padding(padding: const EdgeInsets.all(20), child: child),
        ],
      ),
    );
  }

  Widget _searchCard() {
    return _card(
      headerGradient: const [Color(0xFFEFF6FF), Color(0xFFEDE9FE)],
      icon: Icons.search,
      iconColor: const Color(0xFF4F46E5),
      title: 'Search Resident',
      child: Column(
        children: [
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search by name or ID...',
              prefixIcon: const Icon(Icons.search),
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 16,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(
                  color: Color(0xFF0D9488),
                  width: 1.6,
                ),
              ),
            ),
          ),
          if (_searchQuery.isNotEmpty) ...[
            const SizedBox(height: 14),
            StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _residentsStream(),
              builder: (context, snap) {
                if (snap.hasError) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Text('Unable to load residents right now.'),
                  );
                }
                if (!snap.hasData) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                final docs = snap.data!.docs.toList();
                docs.sort((a, b) {
                  final an = (a.data()['fullName'] ?? a.data()['name'] ?? '')
                      .toString();
                  final bn = (b.data()['fullName'] ?? b.data()['name'] ?? '')
                      .toString();
                  return an.toLowerCase().compareTo(bn.toLowerCase());
                });
                final q = _searchQuery.toLowerCase();
                final filtered = docs.where((d) {
                  final data = d.data();
                  final name = (data['fullName'] ?? data['name'] ?? '')
                      .toString()
                      .toLowerCase();
                  final email = (data['email'] ?? '').toString().toLowerCase();
                  return name.contains(q) ||
                      email.contains(q) ||
                      d.id.toLowerCase().contains(q);
                }).toList();
                if (filtered.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    child: Text(
                      'No residents found matching "$_searchQuery"',
                      style: TextStyle(color: Colors.grey.shade600),
                      textAlign: TextAlign.center,
                    ),
                  );
                }
                return Column(children: filtered.map(_residentTile).toList());
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _badge(String text, Color bg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: const TextStyle(fontSize: 11, color: Colors.white),
      ),
    );
  }

  Widget _avatar(String name, List<Color> grad) {
    final parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .toList();
    final initials = parts.isEmpty
        ? '?'
        : parts.take(2).map((p) => p[0].toUpperCase()).join();
    return Container(
      width: 46,
      height: 46,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: grad),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(
        initials,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _residentTile(QueryDocumentSnapshot<Map<String, dynamic>> r) {
    final d = r.data();
    final name = (d['fullName'] ?? d['name'] ?? 'Resident').toString();
    final email = (d['email'] ?? '').toString();
    final isAllocated = d['isAllocated'] == true;
    final alloc = d['allocationDetails'] as Map<String, dynamic>?;
    final hostelName = (alloc?['hostelName'] ?? '').toString();
    final floorName = (alloc?['floorName'] ?? '').toString();
    final room = (alloc?['roomNumber'] ?? d['roomId'] ?? 'Unassigned')
        .toString();
    final bed = (alloc?['bedNumber'] ?? alloc?['bedSlot'] ?? d['bedSlot'] ?? '')
        .toString();
    final selected = _selectedResident?.id == r.id;

    return InkWell(
      onTap: () => _selectResident(r),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFEFF6FF) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? const Color(0xFF4F46E5) : Colors.grey.shade300,
            width: selected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            _avatar(name, const [Color(0xFF4F46E5), Color(0xFF7C3AED)]),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    email.isEmpty ? 'ID: ${r.id}' : email,
                    style: TextStyle(color: Colors.grey.shade700, fontSize: 12),
                  ),
                  if (isAllocated &&
                      (hostelName.isNotEmpty || floorName.isNotEmpty)) ...[
                    const SizedBox(height: 4),
                    Text(
                      [
                        if (hostelName.isNotEmpty) hostelName,
                        if (floorName.isNotEmpty) floorName,
                      ].join(' • '),
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 12,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  'Current Room',
                  style: TextStyle(color: Colors.grey.shade700, fontSize: 12),
                ),
                const SizedBox(height: 4),
                _badge(
                  isAllocated
                      ? 'Room $room${bed.isNotEmpty ? ' • $bed' : ''}'
                      : 'Unassigned',
                  isAllocated
                      ? const Color(0xFF0D9488)
                      : const Color(0xFFF97316),
                ),
                const SizedBox(height: 6),
                _badge(
                  isAllocated ? 'ACTIVE' : 'UNALLOCATED',
                  isAllocated
                      ? const Color(0xFF0D9488)
                      : const Color(0xFFF97316),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _selectedResidentCard() {
    final r = _selectedResident!;
    final d = r.data();
    final name = (d['fullName'] ?? d['name'] ?? 'Resident').toString();
    final email = (d['email'] ?? '').toString();
    final isAllocated = d['isAllocated'] == true;
    final alloc = d['allocationDetails'] as Map<String, dynamic>?;
    final room = (alloc?['roomNumber'] ?? d['roomId'] ?? 'Unassigned')
        .toString();
    final bed = (alloc?['bedNumber'] ?? alloc?['bedSlot'] ?? d['bedSlot'] ?? '')
        .toString();

    return _card(
      headerGradient: const [Color(0xFFF3E8FF), Color(0xFFFCE7F3)],
      icon: Icons.person,
      iconColor: const Color(0xFF7C3AED),
      title: 'Selected Resident',
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFF3E8FF), Color(0xFFFCE7F3)],
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            _avatar(name, const [Color(0xFF7C3AED), Color(0xFFEC4899)]),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    email.isEmpty ? 'Resident ID: ${r.id}' : email,
                    style: TextStyle(color: Colors.grey.shade700, fontSize: 12),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    children: [
                      _badge(
                        isAllocated
                            ? 'Room $room${bed.isNotEmpty ? ' • $bed' : ''}'
                            : 'Not Assigned',
                        isAllocated
                            ? const Color(0xFF0D9488)
                            : const Color(0xFFF97316),
                      ),
                      _badge(
                        isAllocated ? 'Active' : 'Pending',
                        const Color(0xFF4F46E5),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _ddDecoration() => InputDecoration(
    filled: true,
    fillColor: Colors.white,
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: Colors.grey.shade300),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: Color(0xFF0D9488), width: 1.6),
    ),
  );

  Widget _label(String text, IconData icon) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey.shade600),
        const SizedBox(width: 6),
        Text(
          text,
          style: const TextStyle(fontSize: 13, color: Color(0xFF374151)),
        ),
      ],
    ),
  );

  Widget _allocationCard() {
    return _card(
      headerGradient: const [Color(0xFFECFDF5), Color(0xFFCFFAFE)],
      icon: Icons.business,
      iconColor: const Color(0xFF0D9488),
      title: 'Room Allocation',
      child: FutureBuilder<_HostelQueryMode>(
        future: _hostelModeFuture,
        builder: (context, modeSnap) {
          if (!modeSnap.hasData)
            return const Center(child: CircularProgressIndicator());
          return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: _hostelsStream(modeSnap.data!),
            builder: (context, hSnap) {
              if (!hSnap.hasData)
                return const Center(child: CircularProgressIndicator());
              final hostels = hSnap.data!.docs;
              final hostelNameById = <String, String>{
                for (final h in hostels)
                  h.id: (h.data()['name'] ?? '').toString(),
              };
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _label('Hostel / PG *', Icons.business),
                  DropdownButtonFormField<String>(
                    value: _hostelId,
                    isExpanded: true,
                    items: [
                      const DropdownMenuItem(
                        value: null,
                        child: Text('Select hostel'),
                      ),
                      ...hostels.map((h) {
                        final name = (h.data()['name'] ?? '').toString();
                        return DropdownMenuItem(
                          value: h.id,
                          child: Text(name.isEmpty ? h.id : name),
                        );
                      }),
                    ],
                    onChanged: (v) {
                      setState(() {
                        _hostelId = v;
                        _hostelName = v == null
                            ? null
                            : (hostelNameById[v] ?? '');
                        _floorName = null;
                        _roomNumber = null;
                        _bedNumber = null;
                      });
                      _clearDownstream(level: 'hostel');
                    },
                    decoration: _ddDecoration(),
                  ),
                  const SizedBox(height: 14),
                  _floorDropdown(),
                  const SizedBox(height: 14),
                  _roomDropdown(),
                  const SizedBox(height: 14),
                  _bedDropdown(),
                  if (_selectedResident != null &&
                      _hostelId != null &&
                      _floorId != null &&
                      _roomId != null &&
                      _bedId != null) ...[
                    const SizedBox(height: 14),
                    _allocationSummary(),
                  ],
                ],
              );
            },
          );
        },
      ),
    );
  }

  Widget _allocationSummary() {
    final r = _selectedResident!;
    final d = r.data();
    final name = (d['fullName'] ?? d['name'] ?? 'Resident').toString();

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFECFDF5), Color(0xFFCFFAFE)],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF99F6E4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Allocation Summary:',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: Color(0xFF134E4A),
            ),
          ),
          const SizedBox(height: 10),
          _sumLine('Resident', name),
          _sumLine(
            'Hostel',
            (_hostelName != null && _hostelName!.isNotEmpty)
                ? _hostelName!
                : _hostelId!,
          ),
          _sumLine(
            'Floor',
            (_floorName != null && _floorName!.isNotEmpty)
                ? _floorName!
                : _floorId!,
          ),
          _sumLine(
            'Room',
            (_roomNumber != null && _roomNumber!.isNotEmpty)
                ? _roomNumber!
                : _roomId!,
          ),
          _sumLine(
            'Bed',
            (_bedNumber != null && _bedNumber!.isNotEmpty)
                ? _bedNumber!
                : _bedId!,
          ),
        ],
      ),
    );
  }

  Widget _sumLine(String k, String v) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        '• $k: $v',
        style: const TextStyle(fontSize: 12, color: Color(0xFF0F766E)),
      ),
    );
  }

  Widget _floorDropdown() {
    if (_hostelId == null) {
      return _disabled('Floor *', Icons.layers, 'Select hostel first');
    }
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('hostels')
          .doc(_hostelId)
          .collection('floors')
          .where('adminId', isEqualTo: widget.adminId)
          .snapshots(),
      builder: (context, snap) {
        if (snap.hasError) {
          debugPrint('FLOORS_LOAD_ERROR: ${snap.error}');
          return _disabled(
            'Floor *',
            Icons.layers,
            'Unable to load floors. Please try again.',
          );
        }
        if (!snap.hasData)
          return const Center(child: CircularProgressIndicator());

        final floors = snap.data!.docs.toList()
          ..sort((a, b) {
            final aiRaw = a.data()['floorIndex'];
            final biRaw = b.data()['floorIndex'];
            final ai = aiRaw is int ? aiRaw : int.tryParse('$aiRaw') ?? 0;
            final bi = biRaw is int ? biRaw : int.tryParse('$biRaw') ?? 0;
            return ai.compareTo(bi);
          });
        final floorNameById = <String, String>{
          for (final f in floors)
            f.id: _floorDisplayName(
              f.data(),
              indexFallback: (() {
                final idxRaw = f.data()['floorIndex'];
                return idxRaw is int ? idxRaw : int.tryParse('$idxRaw');
              })(),
            ),
        };
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _label('Floor *', Icons.layers),
            DropdownButtonFormField<String>(
              value: _floorId,
              isExpanded: true,
              items: [
                const DropdownMenuItem(
                  value: null,
                  child: Text('Select floor'),
                ),
                ...floors.map((f) {
                  final name = floorNameById[f.id] ?? 'Floor';
                  return DropdownMenuItem(value: f.id, child: Text(name));
                }),
              ],
              onChanged: (v) {
                setState(() {
                  _floorId = v;
                  _floorName = v == null ? null : (floorNameById[v] ?? '');
                  _roomNumber = null;
                  _bedNumber = null;
                });
                _clearDownstream(level: 'floor');
              },
              decoration: _ddDecoration(),
            ),
          ],
        );
      },
    );
  }

  Widget _roomDropdown() {
    if (_hostelId == null || _floorId == null) {
      return _disabled(
        'Room Number *',
        Icons.meeting_room,
        'Select hostel & floor first',
      );
    }
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('hostels')
          .doc(_hostelId)
          .collection('floors')
          .doc(_floorId)
          .collection('rooms')
          .where('adminId', isEqualTo: widget.adminId)
          .snapshots(),
      builder: (context, snap) {
        if (snap.hasError) {
          debugPrint('ROOMS_LOAD_ERROR: ${snap.error}');
          return _disabled(
            'Room Number *',
            Icons.meeting_room,
            'Unable to load rooms. Please try again.',
          );
        }
        if (!snap.hasData)
          return const Center(child: CircularProgressIndicator());

        final rooms = snap.data!.docs.toList()
          ..sort((a, b) {
            final ar = (a.data()['roomNumber'] ?? a.id).toString();
            final br = (b.data()['roomNumber'] ?? b.id).toString();
            final an = int.tryParse(ar);
            final bn = int.tryParse(br);
            if (an != null && bn != null) return an.compareTo(bn);
            return ar.toLowerCase().compareTo(br.toLowerCase());
          });
        final roomNoById = <String, String>{
          for (final r in rooms)
            r.id: (r.data()['roomNumber'] ?? r.id).toString(),
        };
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _label('Room Number *', Icons.bed),
            DropdownButtonFormField<String>(
              value: _roomId,
              isExpanded: true,
              items: [
                const DropdownMenuItem(value: null, child: Text('Select room')),
                ...rooms.map((r) {
                  final roomNo = (r.data()['roomNumber'] ?? r.id).toString();
                  return DropdownMenuItem(
                    value: r.id,
                    child: Text('Room $roomNo'),
                  );
                }),
              ],
              onChanged: (v) {
                setState(() {
                  _roomId = v;
                  _roomNumber = v == null ? null : (roomNoById[v] ?? '');
                  _bedNumber = null;
                });
                _clearDownstream(level: 'room');
              },
              decoration: _ddDecoration(),
            ),
          ],
        );
      },
    );
  }

  Widget _bedDropdown() {
    if (_hostelId == null || _floorId == null || _roomId == null) {
      return _disabled(
        'Bed Position *',
        Icons.bed,
        'Select hostel, floor & room first',
      );
    }
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('hostels')
          .doc(_hostelId)
          .collection('floors')
          .doc(_floorId)
          .collection('rooms')
          .doc(_roomId)
          .collection('beds')
          .snapshots(),
      builder: (context, snap) {
        if (snap.hasError) {
          debugPrint('BEDS_LOAD_ERROR: ${snap.error}');
          return _disabled(
            'Bed Position *',
            Icons.bed,
            'Unable to load beds. Please try again.',
          );
        }
        if (!snap.hasData)
          return const Center(child: CircularProgressIndicator());
        final beds = snap.data!.docs.toList()
          ..sort((a, b) => a.id.compareTo(b.id));

        // If older rooms have `totalBeds` but no `beds` docs, auto-create them.
        if (beds.isEmpty && !_bootstrappingBeds) {
          Future.microtask(_bootstrapBedsForSelectedRoom);
        }
        final selectedResidentId = _selectedResident?.id;
        final bedNoById = <String, String>{
          for (final b in beds)
            b.id: (b.data()['bedNumber'] ?? b.id).toString(),
        };
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _label('Bed Position *', Icons.bed),
            if (beds.isEmpty) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFFBEB),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFFDE68A)),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.info_outline,
                      size: 18,
                      color: Color(0xFFB45309),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _bootstrappingBeds
                            ? 'Preparing beds for this room...'
                            : 'No beds found for this room. Preparing...',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF92400E),
                        ),
                      ),
                    ),
                    if (_bootstrappingBeds)
                      const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
            ],
            DropdownButtonFormField<String>(
              value: _bedId,
              isExpanded: true,
              items: [
                const DropdownMenuItem(
                  value: null,
                  child: Text('Select bed position'),
                ),
                ...beds.map((b) {
                  final d = b.data();
                  final bedNo = (d['bedNumber'] ?? b.id).toString();
                  final isOcc = d['isOccupied'] == true;
                  final occBy = (d['residentId'] ?? d['occupiedBy'])
                      ?.toString();
                  final isMine =
                      selectedResidentId != null && occBy == selectedResidentId;
                  final disabled = isOcc && !isMine;
                  final label = bedNo.startsWith('B') && bedNo.length > 1
                      ? 'Bed ${bedNo.substring(1)}'
                      : bedNo;
                  return DropdownMenuItem(
                    value: b.id,
                    enabled: !disabled,
                    child: SizedBox(
                      width: double.infinity,
                      child: Row(
                        mainAxisSize: MainAxisSize.max,
                        children: [
                          Flexible(
                            fit: FlexFit.tight,
                            child: Text(label, overflow: TextOverflow.ellipsis),
                          ),
                          const SizedBox(width: 10),
                          _badge(
                            disabled
                                ? 'OCCUPIED'
                                : (isMine ? 'ASSIGNED' : 'AVAILABLE'),
                            disabled
                                ? const Color(0xFFF97316)
                                : const Color(0xFF0D9488),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              ],
              onChanged: (v) => setState(() {
                _bedId = v;
                _bedNumber = v == null ? null : (bedNoById[v] ?? '');
              }),
              decoration: _ddDecoration(),
            ),
          ],
        );
      },
    );
  }

  Widget _disabled(String label, IconData icon, String hint) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label(label, icon),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          decoration: BoxDecoration(
            color: const Color(0xFFF3F4F6),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE5E7EB)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  hint,
                  style: const TextStyle(color: Color(0xFF6B7280)),
                ),
              ),
              const Icon(Icons.lock, size: 18, color: Color(0xFF9CA3AF)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _actionRow() {
    final canConfirm =
        _hostelId != null &&
        _floorId != null &&
        _roomId != null &&
        _bedId != null &&
        !_saving;
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: _saving ? null : _resetAllocation,
            icon: const Icon(Icons.refresh),
            label: const Text('Reset Selection'),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              side: const BorderSide(color: Color(0xFFD1D5DB)),
              backgroundColor: Colors.white,
            ),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: ElevatedButton.icon(
            onPressed: canConfirm ? _confirmAllocation : null,
            icon: const Icon(Icons.check_circle_outline),
            label: const Text('Confirm Allocation'),
            style: ElevatedButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
              backgroundColor: const Color(0xFF0D9488),
              disabledBackgroundColor: const Color(0xFF9CA3AF),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _capacityCard() {
    return _card(
      headerGradient: const [Color(0xFFFFF7ED), Color(0xFFFEE2E2)],
      icon: Icons.bed,
      iconColor: const Color(0xFFF97316),
      title: 'Room Capacity',
      child: (_hostelId == null || _floorId == null || _roomId == null)
          ? Column(
              children: [
                const SizedBox(height: 18),
                Icon(Icons.bed, size: 48, color: Colors.grey.shade300),
                const SizedBox(height: 10),
                Text(
                  'Select a room to view capacity',
                  style: TextStyle(color: Colors.grey.shade600),
                ),
              ],
            )
          : StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('hostels')
                  .doc(_hostelId)
                  .collection('floors')
                  .doc(_floorId)
                  .collection('rooms')
                  .doc(_roomId)
                  .snapshots(),
              builder: (context, roomSnap) {
                if (!roomSnap.hasData)
                  return const Center(child: CircularProgressIndicator());
                final roomData = roomSnap.data!.data() ?? {};
                final roomNo = (roomData['roomNumber'] ?? _roomId).toString();
                final tbRaw = roomData['totalBeds'] ?? 0;
                final totalBeds = tbRaw is int
                    ? tbRaw
                    : int.tryParse('$tbRaw') ?? 0;

                return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: FirebaseFirestore.instance
                      .collection('hostels')
                      .doc(_hostelId)
                      .collection('floors')
                      .doc(_floorId)
                      .collection('rooms')
                      .doc(_roomId)
                      .collection('beds')
                      .snapshots(),
                  builder: (context, bedsSnap) {
                    if (!bedsSnap.hasData)
                      return const Center(child: CircularProgressIndicator());
                    final beds = bedsSnap.data!.docs;
                    final occupied = beds
                        .where((b) => b.data()['isOccupied'] == true)
                        .length;
                    final available = (totalBeds - occupied).clamp(
                      0,
                      totalBeds,
                    );
                    final pct = totalBeds == 0
                        ? 0.0
                        : (occupied / totalBeds).clamp(0, 1).toDouble();

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Center(
                          child: Container(
                            width: 80,
                            height: 80,
                            alignment: Alignment.center,
                            decoration: const BoxDecoration(
                              gradient: LinearGradient(
                                colors: [Color(0xFFF97316), Color(0xFFEF4444)],
                              ),
                              borderRadius: BorderRadius.all(
                                Radius.circular(18),
                              ),
                            ),
                            child: Text(
                              roomNo,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        _capRow(
                          'Total Beds',
                          '$totalBeds',
                          const Color(0xFF6B7280),
                        ),
                        _capRow(
                          'Occupied',
                          '$occupied',
                          const Color(0xFFF97316),
                        ),
                        _capRow(
                          'Available',
                          '$available',
                          const Color(0xFF0D9488),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            const Text(
                              'Occupancy Rate',
                              style: TextStyle(
                                fontSize: 12,
                                color: Color(0xFF374151),
                              ),
                            ),
                            const Spacer(),
                            Text(
                              '${(pct * 100).round()}%',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: LinearProgressIndicator(
                            value: pct,
                            minHeight: 10,
                            backgroundColor: const Color(0xFFE5E7EB),
                            valueColor: const AlwaysStoppedAnimation(
                              Color(0xFFF97316),
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        if (available > 0)
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFECFDF5),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: const Color(0xFF99F6E4),
                              ),
                            ),
                            child: Text(
                              '✓ $available bed${available > 1 ? 's' : ''} available for allocation',
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF0F766E),
                              ),
                            ),
                          )
                        else
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFEF2F2),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: const Color(0xFFFECACA),
                              ),
                            ),
                            child: const Text(
                              '⚠ Room is fully occupied',
                              style: TextStyle(
                                fontSize: 12,
                                color: Color(0xFFB91C1C),
                              ),
                            ),
                          ),
                      ],
                    );
                  },
                );
              },
            ),
    );
  }

  Widget _capRow(String label, String value, Color badgeColor) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 12, color: Color(0xFF374151)),
          ),
          const Spacer(),
          _badge(value, badgeColor),
        ],
      ),
    );
  }
}
