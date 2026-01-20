import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../widgets/custom_textfield.dart';
import '../widgets/gradient_button.dart';
import '../widgets/loading_overlay.dart';
import '../widgets/success_dialog.dart';

class EditHostelDialog extends StatefulWidget {
  final String hostelId;
  final String name;
  final String address;
  final String description;

  const EditHostelDialog({
    super.key,
    required this.hostelId,
    required this.name,
    required this.address,
    required this.description,
  });

  @override
  State<EditHostelDialog> createState() => _EditHostelDialogState();
}

class _EditHostelDialogState extends State<EditHostelDialog> {
  late final TextEditingController nameController;
  late final TextEditingController addressController;
  late final TextEditingController descriptionController;

  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    nameController = TextEditingController(text: widget.name);
    addressController = TextEditingController(text: widget.address);
    descriptionController = TextEditingController(text: widget.description);
  }

  @override
  void dispose() {
    nameController.dispose();
    addressController.dispose();
    descriptionController.dispose();
    super.dispose();
  }

  Future<void> _updateHostel() async {
    if (nameController.text.trim().isEmpty ||
        addressController.text.trim().isEmpty) {
      return;
    }

    setState(() => isLoading = true);

    try {
      await FirebaseFirestore.instance
          .collection('hostels')
          .doc(widget.hostelId)
          .update({
            'name': nameController.text.trim(),
            'address': addressController.text.trim(),
            'description': descriptionController.text.trim(),
            'updatedAt': FieldValue.serverTimestamp(),
          });

      if (!mounted) return;

      Navigator.of(context).pop(); // close edit dialog

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const SuccessDialog(
          title: 'Hostel Updated',
          message: 'Hostel details updated successfully.',
        ),
      );
    } catch (e) {
      debugPrint('Edit hostel error: $e');
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(24),
      child: LoadingOverlay(
        isLoading: isLoading,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Edit Hostel',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 20),

                CustomTextField(
                  controller: nameController,
                  hintText: 'Hostel Name',
                  label: 'Hostel Name',
                ),
                const SizedBox(height: 12),

                CustomTextField(
                  controller: addressController,
                  hintText: 'Address',
                  label: 'Address',
                ),
                const SizedBox(height: 12),

                CustomTextField(
                  controller: descriptionController,
                  hintText: 'Description (optional)',
                  label: 'Description',
                ),
                const SizedBox(height: 24),

                GradientButton(text: 'Update Hostel', onPressed: _updateHostel),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
