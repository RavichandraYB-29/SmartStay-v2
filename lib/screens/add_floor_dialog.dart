import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../utils/admin_design_system.dart';
import '../widgets/admin_widgets.dart';

class AddFloorDialog extends StatefulWidget {
  final String hostelId;
  final String pgId;
  final String adminId;

  const AddFloorDialog({
    super.key,
    required this.hostelId,
    required this.pgId,
    required this.adminId,
  });

  @override
  State<AddFloorDialog> createState() => _AddFloorDialogState();
}

class _AddFloorDialogState extends State<AddFloorDialog> {
  final _formKey = GlobalKey<FormState>();
  final _floorNumberController = TextEditingController();
  final _floorNameController = TextEditingController();
  final _notesController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _floorNumberController.dispose();
    _floorNameController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    // Confirmation dialog
    final confirmed = await showAdminConfirmDialog(
      context,
      title: 'Add Floor?',
      message: 'Add "${_floorNameController.text.trim()}" to this hostel?',
      confirmLabel: 'Add Floor',
    );
    if (!confirmed || !mounted) return;

    setState(() => _isLoading = true);
    try {
      final hostelRef = FirebaseFirestore.instance.collection('hostels').doc(widget.hostelId);
      final pgRef = widget.pgId.isNotEmpty ? hostelRef.collection('pgs').doc(widget.pgId) : null;

      await FirebaseFirestore.instance.runTransaction((tx) async {
        int currentFloors = 0;
        DocumentReference floorRef;

        if (pgRef != null) {
          final pgSnap = await tx.get(pgRef);
          currentFloors = pgSnap.data()?['floors'] ?? 0;
          floorRef = pgRef.collection('floors').doc();
          tx.update(pgRef, {'floors': currentFloors + 1});
        } else {
          final hostelSnap = await tx.get(hostelRef);
          currentFloors = hostelSnap.data()?['floors'] ?? 0;
          floorRef = hostelRef.collection('floors').doc();
          tx.update(hostelRef, {'floors': currentFloors + 1});
        }

        tx.set(floorRef, {
          'floorIndex': currentFloors,
          'floorName': _floorNameController.text.trim(),
          'floorNumber': int.tryParse(_floorNumberController.text.trim()) ?? currentFloors,
          'notes': _notesController.text.trim(),
          'adminId': widget.adminId,
          'totalRooms': 0,
          'totalBeds': 0,
          'availableBeds': 0,
          'hostelId': widget.hostelId,
          'pgId': widget.pgId,
          'createdAt': FieldValue.serverTimestamp(),
        });
      });

      if (!mounted) return;
      Navigator.pop(context);
      await showAdminSuccessDialog(
        context,
        title: 'Floor Added!',
        message: '"${_floorNameController.text.trim()}" has been added successfully.',
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to add floor: $e')));
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
          child: Container(
            width: 460,
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
                    gradient: AdminGradients.teal,
                    borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                  ),
                  child: Row(children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(10)),
                      child: const Icon(Icons.layers_rounded, color: Colors.white, size: 20),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(child: Text('Add New Floor', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700, fontFamily: 'Inter'))),
                    InkWell(onTap: () => Navigator.pop(context), child: const Icon(Icons.close_rounded, color: Colors.white)),
                  ]),
                ),
                // Body
                Padding(
                  padding: const EdgeInsets.all(22),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Expanded(child: AdminTextField(
                        label: 'Floor Number *', hint: 'e.g., 1',
                        controller: _floorNumberController,
                        keyboardType: TextInputType.number,
                        validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                      )),
                      const SizedBox(width: 14),
                      Expanded(child: AdminTextField(
                        label: 'Floor Name *', hint: 'e.g., Ground Floor',
                        controller: _floorNameController,
                        validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                      )),
                    ]),
                    const SizedBox(height: 16),
                    AdminTextField(
                      label: 'Notes (Optional)', hint: 'Any notes about this floor...',
                      controller: _notesController,
                      maxLines: 2,
                    ),
                    const SizedBox(height: 12),
                    const AdminInfoBanner(message: "You'll be able to add rooms and configure sharing options for this floor after creation."),
                    const SizedBox(height: 22),
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
                        label: 'Add Floor',
                        icon: Icons.add_rounded,
                        gradient: AdminGradients.teal,
                        isLoading: _isLoading,
                        height: 48,
                        onPressed: _submit,
                      )),
                    ]),
                  ]),
                ),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}
