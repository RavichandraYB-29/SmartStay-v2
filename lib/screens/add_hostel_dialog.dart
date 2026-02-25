import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../utils/admin_design_system.dart';
import '../widgets/admin_widgets.dart';

class AddHostelDialog extends StatefulWidget {
  final String adminId;
  const AddHostelDialog({super.key, required this.adminId});

  @override
  State<AddHostelDialog> createState() => _AddHostelDialogState();
}

class _AddHostelDialogState extends State<AddHostelDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _streetCtrl = TextEditingController();
  final _cityCtrl = TextEditingController();
  final _stateCtrl = TextEditingController();
  final _pincodeCtrl = TextEditingController();
  final _floorsCtrl = TextEditingController();
  final _descCtrl = TextEditingController();

  // Hostel type selection
  String _hostelType = 'Boys PG';
  final _hostelTypes = ['Boys PG', 'Girls PG', 'Co-ed PG', 'Hostel', 'Other'];

  bool _isLoading = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _streetCtrl.dispose();
    _cityCtrl.dispose();
    _stateCtrl.dispose();
    _pincodeCtrl.dispose();
    _floorsCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _createHostel() async {
    if (!_formKey.currentState!.validate()) return;

    final floors = int.tryParse(_floorsCtrl.text.trim()) ?? 0;

    // Confirm
    final confirmed = await showAdminConfirmDialog(
      context,
      title: 'Create Hostel?',
      message:
          '"${_nameCtrl.text.trim()}" will be created with $floors floor(s). You can add rooms after setup.',
      confirmLabel: 'Create',
    );
    if (!confirmed || !mounted) return;

    setState(() => _isLoading = true);
    try {
      final address =
          '${_streetCtrl.text.trim()}, ${_cityCtrl.text.trim()}, '
          '${_stateCtrl.text.trim()} - ${_pincodeCtrl.text.trim()}';

      final hostelRef =
          await FirebaseFirestore.instance.collection('hostels').add({
        'name': _nameCtrl.text.trim(),
        'hostelName': _nameCtrl.text.trim(),
        'ownerId': widget.adminId,
        'adminId': widget.adminId,
        'isActive': true,
        'hostelType': _hostelType,
        'description': _descCtrl.text.trim(),
        'street': _streetCtrl.text.trim(),
        'city': _cityCtrl.text.trim(),
        'state': _stateCtrl.text.trim(),
        'pincode': _pincodeCtrl.text.trim(),
        'address': address,
        'floors': floors,
        'totalRooms': 0,
        'occupiedRooms': 0,
        'totalBeds': 0,
        'availableBeds': 0,
        'createdAt': FieldValue.serverTimestamp(),
      });

      final batch = FirebaseFirestore.instance.batch();
      final pgRef = hostelRef.collection('pgs').doc();
      batch.set(pgRef, {
        'name': _nameCtrl.text.trim(),
        'pgName': _nameCtrl.text.trim(),
        'adminId': widget.adminId,
        'ownerId': widget.adminId,
        'hostelId': hostelRef.id,
        'floors': floors,
        'totalBeds': 0,
        'availableBeds': 0,
        'createdAt': FieldValue.serverTimestamp(),
      });

      for (int i = 0; i < floors; i++) {
        batch.set(pgRef.collection('floors').doc(), {
          'floorName': 'Floor ${i + 1}',
          'floorIndex': i,
          'adminId': widget.adminId,
          'totalRooms': 0,
          'totalBeds': 0,
          'availableBeds': 0,
          'hostelId': hostelRef.id,
          'pgId': pgRef.id,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      await batch.commit();

      if (!mounted) return;
      Navigator.pop(context);
      await showAdminSuccessDialog(
        context,
        title: 'Hostel Created!',
        message:
            '"${_nameCtrl.text.trim()}" has been set up with $floors floor(s). Head to Floor Management to add rooms.',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to create hostel: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 680, maxWidth: 520),
            child: Container(
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E2130) : Colors.white,
                borderRadius: AdminRadius.xl,
                boxShadow: AdminShadows.cardHover,
              ),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // ── Gradient Header ──────────────────────
                    _Header(onClose: () => Navigator.pop(context)),
                    // ── Scrollable Body ──────────────────────
                    Flexible(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(22, 20, 22, 6),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // ── Section: Basic Info ──
                            _SectionLabel(
                              icon: Icons.info_outline_rounded,
                              label: 'Basic Information',
                            ),
                            const SizedBox(height: 12),
                            AdminTextField(
                              label: 'Hostel / PG Name *',
                              hint: 'e.g., SmartStay Boys PG – Koramangala',
                              controller: _nameCtrl,
                              prefixIcon: Icons.apartment_rounded,
                              validator: (v) =>
                                  v == null || v.trim().isEmpty ? 'Required' : null,
                            ),
                            const SizedBox(height: 14),

                            // Hostel type chips
                            const Text(
                              'Hostel Type',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                fontFamily: 'Inter',
                                color: Color(0xFF374151),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 6,
                              children: _hostelTypes.map((t) {
                                final isSelected = _hostelType == t;
                                return GestureDetector(
                                  onTap: () => setState(() => _hostelType = t),
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 160),
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 14, vertical: 8),
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? AdminColors.primary
                                          : (isDark
                                              ? const Color(0xFF252836)
                                              : const Color(0xFFF4F6FB)),
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(
                                        color: isSelected
                                            ? AdminColors.primary
                                            : const Color(0xFFE5E7EB),
                                      ),
                                    ),
                                    child: Text(
                                      t,
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        fontFamily: 'Inter',
                                        color: isSelected
                                            ? Colors.white
                                            : AdminColors.textSecondary,
                                      ),
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                            const SizedBox(height: 14),

                            AdminTextField(
                              label: 'Description (Optional)',
                              hint: 'e.g., Premium PG with AC rooms and home-cooked food',
                              controller: _descCtrl,
                              maxLines: 2,
                            ),

                            const SizedBox(height: 20),

                            // ── Section: Address ──
                            _SectionLabel(
                              icon: Icons.location_on_rounded,
                              label: 'Address',
                            ),
                            const SizedBox(height: 12),
                            AdminTextField(
                              label: 'Street Address *',
                              hint: 'e.g., 123 MG Road, Indiranagar',
                              controller: _streetCtrl,
                              prefixIcon: Icons.home_rounded,
                              validator: (v) =>
                                  v == null || v.trim().isEmpty ? 'Required' : null,
                            ),
                            const SizedBox(height: 12),
                            Row(children: [
                              Expanded(
                                flex: 2,
                                child: AdminTextField(
                                  label: 'City *',
                                  hint: 'Bangalore',
                                  controller: _cityCtrl,
                                  validator: (v) =>
                                      v == null || v.trim().isEmpty ? 'Required' : null,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                flex: 2,
                                child: AdminTextField(
                                  label: 'State *',
                                  hint: 'Karnataka',
                                  controller: _stateCtrl,
                                  validator: (v) =>
                                      v == null || v.trim().isEmpty ? 'Required' : null,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                flex: 1,
                                child: AdminTextField(
                                  label: 'Pincode *',
                                  hint: '560001',
                                  controller: _pincodeCtrl,
                                  keyboardType: TextInputType.number,
                                  validator: (v) {
                                    if (v == null || v.trim().isEmpty) return 'Required';
                                    if (v.trim().length != 6) return 'Invalid';
                                    return null;
                                  },
                                ),
                              ),
                            ]),

                            const SizedBox(height: 20),

                            // ── Section: Structure ──
                            _SectionLabel(
                              icon: Icons.layers_rounded,
                              label: 'Building Structure',
                            ),
                            const SizedBox(height: 12),
                            AdminTextField(
                              label: 'Number of Floors *',
                              hint: 'e.g., 3',
                              controller: _floorsCtrl,
                              keyboardType: TextInputType.number,
                              prefixIcon: Icons.stairs_rounded,
                              validator: (v) {
                                final n = int.tryParse(v?.trim() ?? '');
                                return n == null || n <= 0
                                    ? 'Enter a valid number'
                                    : null;
                              },
                            ),
                            const SizedBox(height: 12),
                            const AdminInfoBanner(
                              message:
                                  'Floors will be pre-created. You can add and configure rooms for each floor from Floor Management.',
                              icon: Icons.lightbulb_outline_rounded,
                              color: AdminColors.info,
                            ),
                            const SizedBox(height: 20),
                          ],
                        ),
                      ),
                    ),
                    // ── Footer Buttons ───────────────────────
                    Padding(
                      padding: const EdgeInsets.fromLTRB(22, 0, 22, 22),
                      child: Row(children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed:
                                _isLoading ? null : () => Navigator.pop(context),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14)),
                              side: const BorderSide(color: AdminColors.cardBorder),
                            ),
                            child: const Text('Cancel',
                                style: TextStyle(fontFamily: 'Inter')),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          flex: 2,
                          child: AdminPrimaryButton(
                            label: 'Create Hostel',
                            icon: Icons.apartment_rounded,
                            isLoading: _isLoading,
                            height: 50,
                            onPressed: _createHostel,
                          ),
                        ),
                      ]),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Private sub-widgets ──────────────────────
class _Header extends StatelessWidget {
  final VoidCallback onClose;
  const _Header({required this.onClose});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      decoration: const BoxDecoration(
        gradient: AdminGradients.primary,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.white.withAlpha(50),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.apartment_rounded, color: Colors.white, size: 22),
        ),
        const SizedBox(width: 14),
        const Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(
              'Add New Hostel / PG',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w700,
                fontFamily: 'Inter',
              ),
            ),
            SizedBox(height: 2),
            Text(
              'Fill in the details to register your property',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 12,
                fontFamily: 'Inter',
              ),
            ),
          ]),
        ),
        InkWell(
          onTap: onClose,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(40),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.close_rounded, color: Colors.white, size: 18),
          ),
        ),
      ]),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final IconData icon;
  final String label;
  const _SectionLabel({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: AdminColors.primary.withAlpha(20),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: AdminColors.primary, size: 14),
      ),
      const SizedBox(width: 8),
      Text(
        label,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          fontFamily: 'Inter',
          color: AdminColors.primary,
          letterSpacing: 0.2,
        ),
      ),
      const SizedBox(width: 10),
      Expanded(child: Container(height: 1, color: AdminColors.primary.withAlpha(30))),
    ]);
  }
}
