import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../theme/app_colors.dart';

class AddResidentScreen extends StatefulWidget {
  final String adminId;
  final VoidCallback? onBack;
  const AddResidentScreen({super.key, required this.adminId, this.onBack});

  @override
  State<AddResidentScreen> createState() => _AddResidentScreenState();
}

class _AddResidentScreenState extends State<AddResidentScreen> {
  final _formKey = GlobalKey<FormState>();
  bool isSaving = false;

  // ───────── PERSONAL ─────────
  final fullNameController = TextEditingController();
  final phoneController = TextEditingController();
  final emailController = TextEditingController();
  String gender = '';

  // ───────── RESIDENCY ─────────
  String hostelId = '';
  String floorId = '';
  String roomId = '';
  String bedId = '';

  List<Map<String, String>> hostels = [];
  List<Map<String, String>> floors = [];
  List<Map<String, String>> rooms = [];
  List<Map<String, String>> beds = [];

  int selectedRoomTotalBeds = 0;
  int selectedRoomOccupiedBeds = 0;

  // ───────── PAYMENT ─────────
  final depositController = TextEditingController();
  final monthlyFeeController = TextEditingController();

  // ───────── STATUS ─────────
  String status = 'active';

  @override
  void initState() {
    super.initState();
    _loadHostels();
  }

  /* ======================
     FIRESTORE LOADERS
  ====================== */

  Future<void> _loadHostels() async {
    final snap = await FirebaseFirestore.instance
        .collection('hostels')
        .where('ownerId', isEqualTo: widget.adminId)
        .get();
    QuerySnapshot legacySnap = snap;
    if (snap.docs.isEmpty) {
      legacySnap = await FirebaseFirestore.instance
          .collection('hostels')
          .where('adminId', isEqualTo: widget.adminId)
          .get();
    }
    setState(() {
      hostels = legacySnap.docs
          .map((d) => {'id': d.id, 'name': d['name'].toString()})
          .toList();
    });
  }

  Future<void> _loadFloors() async {
    floors.clear();
    rooms.clear();
    beds.clear();

    final snap = await FirebaseFirestore.instance
        .collection('hostels')
        .doc(hostelId)
        .collection('floors')
        .get();

    setState(() {
      floors = snap.docs
          .map(
            (d) => {'id': d.id, 'name': 'Floor ${(d['floorIndex'] ?? 0) + 1}'},
          )
          .toList();
    });
  }

  Future<void> _loadRooms() async {
    rooms.clear();
    beds.clear();

    final snap = await FirebaseFirestore.instance
        .collection('hostels')
        .doc(hostelId)
        .collection('floors')
        .doc(floorId)
        .collection('rooms')
        .get();

    final List<Map<String, String>> availableRooms = [];

    for (final r in snap.docs) {
      final data = r.data();
      final totalBeds = data['totalBeds'] ?? 0;
      final occupiedBeds = data['occupiedBeds'] ?? 0;

      if (occupiedBeds < totalBeds) {
        availableRooms.add({
          'id': r.id,
          'name': 'Room ${data['roomNumber']}',
          'totalBeds': totalBeds.toString(),
          'occupiedBeds': occupiedBeds.toString(),
        });
      }
    }

    setState(() => rooms = availableRooms);
  }

  void _loadBeds() {
    beds.clear();
    final freeBeds = selectedRoomTotalBeds - selectedRoomOccupiedBeds;

    setState(() {
      beds = List.generate(
        freeBeds,
        (i) => {'id': 'bed_${i + 1}', 'name': 'Bed ${i + 1}'},
      );
    });
  }

  /* ======================
     SAVE RESIDENT
  ====================== */

  Future<void> _saveResident() async {
    if (!_formKey.currentState!.validate() ||
        hostelId.isEmpty ||
        floorId.isEmpty ||
        roomId.isEmpty ||
        bedId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill all required fields')),
      );
      return;
    }

    setState(() => isSaving = true);

    try {
      final batch = FirebaseFirestore.instance.batch();

      final residentRef = FirebaseFirestore.instance
          .collection('residents')
          .doc();

      final roomRef = FirebaseFirestore.instance
          .collection('hostels')
          .doc(hostelId)
          .collection('floors')
          .doc(floorId)
          .collection('rooms')
          .doc(roomId);

      batch.set(residentRef, {
        'adminId': widget.adminId,
        'fullName': fullNameController.text.trim(),
        'phone': phoneController.text.trim(),
        'email': emailController.text.trim(),
        'gender': gender,
        'hostelId': hostelId,
        'floorId': floorId,
        'roomId': roomId,
        'bedSlot': bedId,
        'deposit': int.tryParse(depositController.text) ?? 0,
        'monthlyFee': int.tryParse(monthlyFeeController.text) ?? 0,
        'status': status,
        'createdAt': FieldValue.serverTimestamp(),
      });

      batch.update(roomRef, {'occupiedBeds': FieldValue.increment(1)});
      await batch.commit();

      if (mounted) Navigator.pop(context);
    } finally {
      if (mounted) setState(() => isSaving = false);
    }
  }

  /* ======================
     UI HELPERS
  ====================== */

  InputDecoration _input(BuildContext context, String hint) {
    final theme = Theme.of(context);
    return InputDecoration(
      hintText: hint,
      filled: true,
      fillColor: theme.colorScheme.surfaceVariant,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
    );
  }

  Widget _dropdown({
    required BuildContext context,
    required String value,
    required String hint,
    required List<Map<String, String>> items,
    required ValueChanged<String?> onChanged,
    bool enabled = true,
  }) {
    final theme = Theme.of(context);

    return DropdownButtonFormField<String>(
      value: value.isEmpty ? null : value,
      decoration: _input(context, hint),
      dropdownColor: theme.cardColor,
      icon: const Icon(Icons.keyboard_arrow_down_rounded),
      borderRadius: BorderRadius.circular(12),
      menuMaxHeight: 260,
      items: items
          .map(
            (e) => DropdownMenuItem(
              value: e['id'],
              child: Text(e['name']!, style: theme.textTheme.bodyMedium),
            ),
          )
          .toList(),
      onChanged: enabled ? onChanged : null,
    );
  }

  Widget _sectionCard({
    required BuildContext context,
    required String title,
    required IconData icon,
    required Color accent,
    required Widget child,
  }) {
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: accent.withOpacity(.15),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                Icon(icon, color: accent),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: theme.textTheme.bodyMedium!.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          Padding(padding: const EdgeInsets.all(20), child: child),
        ],
      ),
    );
  }

  /* ======================
     BUILD
  ====================== */

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            /// ───────── HEADER (RESTORED) ─────────
            Row(
              children: [
                InkWell(
                  onTap: () => widget.onBack != null
                      ? widget.onBack!()
                      : Navigator.pop(context),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: theme.cardColor,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.arrow_back),
                  ),
                ),
                const SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      'Add Resident',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Dashboard → Residents → Add Resident',
                      style: TextStyle(fontSize: 13, color: Colors.grey),
                    ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 32),

            Form(
              key: _formKey,
              child: Column(
                children: [
                  _sectionCard(
                    context: context,
                    title: 'Personal Details',
                    icon: Icons.person_outline,
                    accent: AppColors.primary,
                    child: Column(
                      children: [
                        TextFormField(
                          controller: fullNameController,
                          decoration: _input(context, 'Enter full name'),
                          validator: (v) => v!.isEmpty ? 'Required' : null,
                        ),
                        const SizedBox(height: 16),
                        _dropdown(
                          context: context,
                          value: gender,
                          hint: 'Select gender',
                          items: const [
                            {'id': 'Male', 'name': 'Male'},
                            {'id': 'Female', 'name': 'Female'},
                            {'id': 'Other', 'name': 'Other'},
                          ],
                          onChanged: (v) => setState(() => gender = v ?? ''),
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: phoneController,
                          decoration: _input(context, '+91 98765 43210'),
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: emailController,
                          decoration: _input(context, 'resident@example.com'),
                        ),
                      ],
                    ),
                  ),

                  _sectionCard(
                    context: context,
                    title: 'Residency Details',
                    icon: Icons.apartment,
                    accent: Colors.teal,
                    child: Column(
                      children: [
                        _dropdown(
                          context: context,
                          value: hostelId,
                          hint: 'Select hostel',
                          items: hostels,
                          onChanged: (v) {
                            hostelId = v!;
                            floorId = roomId = bedId = '';
                            _loadFloors();
                            setState(() {});
                          },
                        ),
                        const SizedBox(height: 16),
                        _dropdown(
                          context: context,
                          value: floorId,
                          hint: 'Select floor',
                          items: floors,
                          enabled: hostelId.isNotEmpty,
                          onChanged: (v) {
                            floorId = v!;
                            roomId = bedId = '';
                            _loadRooms();
                            setState(() {});
                          },
                        ),
                        const SizedBox(height: 16),
                        _dropdown(
                          context: context,
                          value: roomId,
                          hint: 'Select room',
                          items: rooms,
                          enabled: floorId.isNotEmpty,
                          onChanged: (v) {
                            final r = rooms.firstWhere((e) => e['id'] == v);
                            roomId = v!;
                            selectedRoomTotalBeds = int.parse(r['totalBeds']!);
                            selectedRoomOccupiedBeds = int.parse(
                              r['occupiedBeds']!,
                            );
                            _loadBeds();
                            setState(() {});
                          },
                        ),
                        const SizedBox(height: 16),
                        _dropdown(
                          context: context,
                          value: bedId,
                          hint: 'Select bed slot',
                          items: beds,
                          enabled: roomId.isNotEmpty,
                          onChanged: (v) => setState(() => bedId = v!),
                        ),
                      ],
                    ),
                  ),

                  _sectionCard(
                    context: context,
                    title: 'Payment Setup',
                    icon: Icons.payments_outlined,
                    accent: Colors.purple,
                    child: Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: depositController,
                            decoration: _input(context, 'Deposit Amount'),
                            keyboardType: TextInputType.number,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: TextFormField(
                            controller: monthlyFeeController,
                            decoration: _input(context, 'Monthly Fee'),
                            keyboardType: TextInputType.number,
                          ),
                        ),
                      ],
                    ),
                  ),

                  _sectionCard(
                    context: context,
                    title: 'Resident Status',
                    icon: Icons.verified_user_outlined,
                    accent: Colors.orange,
                    child: Row(
                      children: [
                        ChoiceChip(
                          label: const Text('Active'),
                          selected: status == 'active',
                          onSelected: (_) => setState(() => status = 'active'),
                        ),
                        const SizedBox(width: 12),
                        ChoiceChip(
                          label: const Text('Pending'),
                          selected: status == 'pending',
                          onSelected: (_) => setState(() => status = 'pending'),
                        ),
                      ],
                    ),
                  ),

                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Cancel'),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: isSaving ? null : _saveResident,
                          child: isSaving
                              ? const CircularProgressIndicator()
                              : const Text('Save Resident'),
                        ),
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
}
