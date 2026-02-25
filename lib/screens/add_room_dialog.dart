import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../utils/admin_design_system.dart';
import '../widgets/admin_widgets.dart';

class AddRoomDialog extends StatefulWidget {
  final String hostelId;
  final String pgId;
  final String floorId;
  final String adminId;

  const AddRoomDialog({
    super.key,
    required this.hostelId,
    required this.pgId,
    required this.floorId,
    required this.adminId,
  });

  @override
  State<AddRoomDialog> createState() => _AddRoomDialogState();
}

class _AddRoomDialogState extends State<AddRoomDialog> {
  final _formKey = GlobalKey<FormState>();
  final _roomNoController = TextEditingController();
  final _rentController = TextEditingController();

  String _sharingType = 'Single';
  bool _isLoading = false;

  // Amenities
  final Map<String, bool> _amenities = {
    'Wi-Fi': false,
    'AC': false,
    'Attached Bathroom': false,
    'Wardrobe': false,
    'Geyser': false,
    'TV': false,
  };

  @override
  void initState() {
    super.initState();
    _roomNoController.addListener(() { if (mounted) setState(() {}); });
    _rentController.addListener(() { if (mounted) setState(() {}); });
  }

  @override
  void dispose() {
    _roomNoController.dispose();
    _rentController.dispose();
    super.dispose();
  }

  int get _totalBeds {
    switch (_sharingType) {
      case 'Single': return 1;
      case 'Double': return 2;
      case 'Triple': return 3;
      case '4-Sharing': return 4;
      default: return 1;
    }
  }

  bool get _canSubmit {
    final rent = int.tryParse(_rentController.text.trim());
    return !_isLoading && _roomNoController.text.trim().isNotEmpty && rent != null && rent > 0;
  }

  Future<void> _addRoom() async {
    if (!_formKey.currentState!.validate()) return;
    final rent = int.tryParse(_rentController.text.trim()) ?? 0;
    final totalBeds = _totalBeds;

    setState(() => _isLoading = true);
    try {
      final fs = FirebaseFirestore.instance;
      final batch = fs.batch();
      final hostelRef = fs.collection('hostels').doc(widget.hostelId);
      final pgRef = hostelRef.collection('pgs').doc(widget.pgId);
      final floorRef = pgRef.collection('floors').doc(widget.floorId);
      final roomRef = floorRef.collection('rooms').doc();
      final selectedAmenities = _amenities.entries.where((e) => e.value).map((e) => e.key).toList();

      batch.set(roomRef, {
        'adminId': widget.adminId,
        'hostelId': widget.hostelId,
        'pgId': widget.pgId,
        'floorId': widget.floorId,
        'roomNumber': _roomNoController.text.trim(),
        'name': 'Room ${_roomNoController.text.trim()}',
        'sharingType': _sharingType,
        'totalBeds': totalBeds,
        'availableBeds': totalBeds,
        'occupiedBeds': 0,
        'rentPerBed': rent,
        'amenities': selectedAmenities,
        'createdAt': FieldValue.serverTimestamp(),
      });
      batch.update(floorRef, {
        'totalRooms': FieldValue.increment(1),
        'totalBeds': FieldValue.increment(totalBeds),
        'availableBeds': FieldValue.increment(totalBeds),
      });
      batch.update(pgRef, {
        'totalBeds': FieldValue.increment(totalBeds),
        'availableBeds': FieldValue.increment(totalBeds),
      });
      for (int i = 1; i <= totalBeds; i++) {
        batch.set(roomRef.collection('beds').doc('B$i'), {
          'bedNumber': 'B$i', 'isOccupied': false, 'residentId': null,
        });
      }
      await batch.commit();

      if (!mounted) return;
      Navigator.pop(context);
      await showAdminSuccessDialog(
        context,
        title: 'Room Added!',
        message: 'Room ${_roomNoController.text.trim()} with $totalBeds bed(s) has been created.',
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 680),
            child: Container(
              width: 480,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E2130) : Colors.white,
                borderRadius: AdminRadius.xl,
                boxShadow: AdminShadows.cardHover,
              ),
              child: Form(
                key: _formKey,
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  // Header
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: const BoxDecoration(
                      gradient: AdminGradients.pink,
                      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                    ),
                    child: Row(children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(10)),
                        child: const Icon(Icons.bed_rounded, color: Colors.white, size: 20),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(child: Text('Add New Room', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700, fontFamily: 'Inter'))),
                      InkWell(onTap: () => Navigator.pop(context), child: const Icon(Icons.close_rounded, color: Colors.white)),
                    ]),
                  ),
                  Flexible(child: SingleChildScrollView(
                    padding: const EdgeInsets.all(22),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        Expanded(child: AdminTextField(
                          label: 'Room Number *', hint: 'e.g., 101',
                          controller: _roomNoController,
                          validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                        )),
                        const SizedBox(width: 14),
                        Expanded(child: AdminTextField(
                          label: 'Monthly Rent / Bed *', hint: '₹ 5000',
                          controller: _rentController,
                          keyboardType: TextInputType.number,
                          prefixIcon: Icons.currency_rupee_rounded,
                          validator: (v) {
                            final n = int.tryParse(v?.trim() ?? '');
                            return n == null || n <= 0 ? 'Enter valid rent' : null;
                          },
                        )),
                      ]),
                      const SizedBox(height: 20),
                      // Sharing type selector
                      const Text('Sharing Type *', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, fontFamily: 'Inter', color: Color(0xFF374151))),
                      const SizedBox(height: 10),
                      Row(children: [
                        for (final entry in {'Single': 1, 'Double': 2, 'Triple': 3, '4-Sharing': 4}.entries)
                          Expanded(child: Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: GestureDetector(
                              onTap: () => setState(() => _sharingType = entry.key),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 180),
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                decoration: BoxDecoration(
                                  color: _sharingType == entry.key ? AdminColors.primary : (isDark ? const Color(0xFF252836) : const Color(0xFFF4F6FB)),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: _sharingType == entry.key ? AdminColors.primary : const Color(0xFFE5E7EB),
                                    width: _sharingType == entry.key ? 2 : 1,
                                  ),
                                ),
                                child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                                  Text('${entry.value}', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, fontFamily: 'Inter', color: _sharingType == entry.key ? Colors.white : AdminColors.textPrimary)),
                                  const SizedBox(height: 2),
                                  Text(entry.key, style: TextStyle(fontSize: 10, fontFamily: 'Inter', color: _sharingType == entry.key ? Colors.white70 : AdminColors.textMuted)),
                                ]),
                              ),
                            ),
                          )),
                      ]),
                      const SizedBox(height: 16),
                      // Bed preview
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(color: const Color(0xFFF0FDF4), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFF86EFAC))),
                        child: Row(children: [
                          const Icon(Icons.bed_rounded, color: AdminColors.success, size: 18),
                          const SizedBox(width: 8),
                          Text('$_totalBeds bed(s) will be created', style: const TextStyle(fontSize: 13, color: AdminColors.success, fontWeight: FontWeight.w600, fontFamily: 'Inter')),
                          const Spacer(),
                          ...List.generate(_totalBeds, (_) => const Padding(
                            padding: EdgeInsets.only(left: 4),
                            child: Icon(Icons.bed, color: AdminColors.success, size: 16),
                          )),
                        ]),
                      ),
                      const SizedBox(height: 20),
                      // Amenities
                      const Text('Amenities (Optional)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, fontFamily: 'Inter', color: Color(0xFF374151))),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8, runSpacing: 8,
                        children: _amenities.keys.map((a) {
                          final sel = _amenities[a]!;
                          return FilterChip(
                            label: Text(a, style: TextStyle(fontSize: 12, fontFamily: 'Inter', color: sel ? Colors.white : AdminColors.textSecondary)),
                            selected: sel,
                            onSelected: (v) => setState(() => _amenities[a] = v),
                            selectedColor: AdminColors.primary,
                            backgroundColor: isDark ? const Color(0xFF252836) : const Color(0xFFF4F6FB),
                            checkmarkColor: Colors.white,
                            side: BorderSide(color: sel ? AdminColors.primary : const Color(0xFFE5E7EB)),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 24),
                      Row(children: [
                        Expanded(child: OutlinedButton(
                          onPressed: _isLoading ? null : () => Navigator.pop(context),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            side: const BorderSide(color: AdminColors.cardBorder),
                          ),
                          child: const Text('Cancel', style: TextStyle(fontFamily: 'Inter')),
                        )),
                        const SizedBox(width: 14),
                        Expanded(child: AdminPrimaryButton(
                          label: 'Add Room',
                          icon: Icons.add_rounded,
                          gradient: AdminGradients.pink,
                          isLoading: _isLoading,
                          height: 48,
                          onPressed: _canSubmit ? _addRoom : null,
                        )),
                      ]),
                    ]),
                  )),
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
