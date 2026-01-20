import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AddHostelDialog extends StatefulWidget {
  final String adminId;

  const AddHostelDialog({super.key, required this.adminId});

  @override
  State<AddHostelDialog> createState() => _AddHostelDialogState();
}

class _AddHostelDialogState extends State<AddHostelDialog> {
  final _nameController = TextEditingController();
  final _streetController = TextEditingController();
  final _cityController = TextEditingController();
  final _stateController = TextEditingController();
  final _pincodeController = TextEditingController();
  final _floorsController = TextEditingController();

  bool _isLoading = false;

  Future<void> _createHostel() async {
    if (_nameController.text.trim().isEmpty ||
        _streetController.text.trim().isEmpty ||
        _cityController.text.trim().isEmpty ||
        _stateController.text.trim().isEmpty ||
        _pincodeController.text.trim().isEmpty ||
        _floorsController.text.trim().isEmpty) {
      return;
    }

    final floors = int.tryParse(_floorsController.text.trim());
    if (floors == null || floors <= 0) return;

    setState(() => _isLoading = true);

    try {
      final hostelRef = await FirebaseFirestore.instance.collection('hostels').add({
        'name': _nameController.text.trim(),
        'ownerId': widget.adminId,
        'adminId': widget.adminId,
        'isActive': true,
        'street': _streetController.text.trim(),
        'city': _cityController.text.trim(),
        'state': _stateController.text.trim(),
        'pincode': _pincodeController.text.trim(),
        'address':
            '${_streetController.text.trim()}, ${_cityController.text.trim()}, '
            '${_stateController.text.trim()} - ${_pincodeController.text.trim()}',
        'floors': floors,
        'totalRooms': 0,
        'occupiedRooms': 0,
        'totalBeds': 0,
        'occupiedBeds': 0,
        'createdAt': FieldValue.serverTimestamp(),
      });

      final batch = FirebaseFirestore.instance.batch();

      for (int i = 0; i < floors; i++) {
        batch.set(hostelRef.collection('floors').doc(), {
          'name': 'Floor ${i + 1}',
          'floorIndex': i,
          'adminId': widget.adminId,
          'totalRooms': 0,
          'occupiedRooms': 0,
          'totalBeds': 0,
          'occupiedBeds': 0,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      await batch.commit();

      if (mounted) Navigator.pop(context);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Dialog(
      insetPadding: const EdgeInsets.all(24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: Colors.transparent,
      child: Container(
        width: 520,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: theme.dialogBackgroundColor,
          borderRadius: BorderRadius.circular(20),
          border: theme.brightness == Brightness.dark
              ? Border.all(color: cs.outline)
              : null,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _header(context),
            const SizedBox(height: 20),
            _section(context, 'Basic Information'),
            _field(
              context,
              _nameController,
              'Hostel / PG Name',
              'SmartStay PG - Koramangala',
            ),
            _field(context, _streetController, 'Street Address', '123 MG Road'),
            Row(
              children: [
                Expanded(
                  child: _field(context, _cityController, 'City', 'Bangalore'),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _field(
                    context,
                    _stateController,
                    'State',
                    'Karnataka',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _field(
                    context,
                    _pincodeController,
                    'Pincode',
                    '560001',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 22),
            _section(context, 'Building Structure'),
            _field(context, _floorsController, 'Number of Floors', '5'),
            const SizedBox(height: 28),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _isLoading ? null : () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isLoading ? null : _createHostel,
                    icon: const Icon(Icons.add),
                    label: const Text('Create Hostel'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _header(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF6C3BFF), Color(0xFF9B5CFF)],
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.apartment, color: Colors.white),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            'Add New Hostel / PG',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.close),
        ),
      ],
    );
  }

  Widget _section(BuildContext context, String title) {
    final cs = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: cs.primary,
        ),
      ),
    );
  }

  Widget _field(
    BuildContext context,
    TextEditingController controller,
    String label,
    String hint,
  ) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          filled: true,
          fillColor: theme.colorScheme.surfaceVariant,
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: theme.brightness == Brightness.dark
                ? BorderSide(color: theme.colorScheme.outline)
                : BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
              color: theme.colorScheme.primary,
              width: 1.5,
            ),
          ),
        ),
      ),
    );
  }
}
