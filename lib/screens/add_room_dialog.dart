import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AddRoomDialog extends StatefulWidget {
  final String hostelId;
  final String floorId;
  final String adminId;

  const AddRoomDialog({
    super.key,
    required this.hostelId,
    required this.floorId,
    required this.adminId,
  });

  @override
  State<AddRoomDialog> createState() => _AddRoomDialogState();
}

class _AddRoomDialogState extends State<AddRoomDialog> {
  final TextEditingController _roomNoController = TextEditingController();
  final TextEditingController _bedsController = TextEditingController();
  final TextEditingController _rentController = TextEditingController();

  String _sharingType = 'Single';
  bool _isLoading = false;

  int _getBedsFromSharing() {
    switch (_sharingType) {
      case 'Single':
        return 1;
      case 'Double':
        return 2;
      case 'Triple':
        return 3;
      case '4-Sharing':
        return 4;
      default:
        return 1;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    _bedsController.text = _getBedsFromSharing().toString();

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 620),
            child: Container(
              width: 440,
              decoration: BoxDecoration(
                color: theme.dialogBackgroundColor,
                borderRadius: BorderRadius.circular(20),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x26000000),
                    blurRadius: 30,
                    offset: Offset(0, 20),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _header(context),
                  Flexible(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(22, 20, 22, 22),
                      child: _body(context),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ───────────────── HEADER ─────────────────
  Widget _header(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFB145FF), Color(0xFFEC4899)],
        ),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.bed, color: Colors.white),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Add New Room',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          InkWell(
            onTap: () => Navigator.pop(context),
            child: const Icon(Icons.close, color: Colors.white),
          ),
        ],
      ),
    );
  }

  // ───────────────── BODY ─────────────────
  Widget _body(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label(context, 'Room Number *'),
        _input(context, _roomNoController, 'e.g., 101'),
        const SizedBox(height: 16),

        _label(context, 'Sharing Type *'),
        _sharingGrid(context),
        const SizedBox(height: 18),

        _label(context, 'Total Beds *'),
        _input(
          context,
          _bedsController,
          'e.g., 3',
          keyboard: TextInputType.number,
        ),
        const SizedBox(height: 16),

        _label(context, 'Monthly Rent per Bed *'),
        _input(
          context,
          _rentController,
          '₹ 5000',
          keyboard: TextInputType.number,
        ),
        const SizedBox(height: 26),

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
                onPressed: _isLoading ? null : _addRoom,
                icon: const Icon(Icons.add),
                label: const Text('Add Room'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFEC4899),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ───────────────── SHARING GRID ─────────────────
  Widget _sharingGrid(BuildContext context) {
    final theme = Theme.of(context);
    final options = {'Single': 1, 'Double': 2, 'Triple': 3, '4-Sharing': 4};

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      children: options.entries.map((e) {
        final selected = _sharingType == e.key;

        return InkWell(
          onTap: () {
            setState(() {
              _sharingType = e.key;
              _bedsController.text = e.value.toString();
            });
          },
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: selected
                    ? const Color(0xFFEC4899)
                    : theme.colorScheme.outline,
                width: selected ? 2 : 1,
              ),
              color: selected ? const Color(0xFFFDF2F8) : theme.cardColor,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: selected
                      ? const Color(0xFFEC4899)
                      : theme.dividerColor,
                  child: Text(
                    e.value.toString(),
                    style: TextStyle(
                      color: selected
                          ? Colors.white
                          : theme.textTheme.bodyLarge!.color,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text('${e.key} Sharing', style: theme.textTheme.bodySmall),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  // ───────────────── FIRESTORE LOGIC (UPDATED) ─────────────────
  Future<void> _addRoom() async {
    if (_roomNoController.text.trim().isEmpty ||
        _rentController.text.trim().isEmpty)
      return;

    final totalBeds = _getBedsFromSharing();
    setState(() => _isLoading = true);

    final firestore = FirebaseFirestore.instance;
    final batch = firestore.batch();

    final roomRef = firestore
        .collection('hostels')
        .doc(widget.hostelId)
        .collection('floors')
        .doc(widget.floorId)
        .collection('rooms')
        .doc();

    batch.set(roomRef, {
      'adminId': widget.adminId,
      'hostelId': widget.hostelId,
      'floorId': widget.floorId,
      'roomNumber': _roomNoController.text.trim(),
      'name': 'Room ${_roomNoController.text.trim()}',
      'sharingType': _sharingType,
      'totalBeds': totalBeds,
      'occupiedBeds': 0,
      'rentPerBed': int.parse(_rentController.text.trim()),
      'createdAt': FieldValue.serverTimestamp(),
    });

    for (int i = 1; i <= totalBeds; i++) {
      batch.set(roomRef.collection('beds').doc('B$i'), {
        'bedNumber': 'B$i',
        'isOccupied': false,
        'residentId': null,
      });
    }

    batch.update(
      firestore
          .collection('hostels')
          .doc(widget.hostelId)
          .collection('floors')
          .doc(widget.floorId),
      {
        'totalRooms': FieldValue.increment(1),
        'totalBeds': FieldValue.increment(totalBeds),
      },
    );

    batch.update(firestore.collection('hostels').doc(widget.hostelId), {
      'totalRooms': FieldValue.increment(1),
      'totalBeds': FieldValue.increment(totalBeds),
    });

    await batch.commit();
    if (mounted) Navigator.pop(context);
  }

  // ───────────────── HELPERS ─────────────────
  Widget _label(BuildContext context, String text) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Text(
      text,
      style: Theme.of(
        context,
      ).textTheme.bodySmall!.copyWith(fontWeight: FontWeight.w500),
    ),
  );

  Widget _input(
    BuildContext context,
    TextEditingController c,
    String hint, {
    TextInputType keyboard = TextInputType.text,
  }) {
    final theme = Theme.of(context);

    return TextField(
      controller: c,
      keyboardType: keyboard,
      decoration: InputDecoration(
        hintText: hint,
        filled: true,
        fillColor: theme.colorScheme.surfaceVariant,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: theme.colorScheme.outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: theme.colorScheme.primary, width: 1.5),
        ),
      ),
    );
  }
}
