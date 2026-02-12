import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'add_room_dialog.dart';

class RoomManagementScreen extends StatelessWidget {
  final String hostelId;
  final String pgId;
  final String floorId;
  final String adminId;

  const RoomManagementScreen({
    super.key,
    required this.hostelId,
    required this.pgId,
    required this.floorId,
    required this.adminId,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('hostels')
            .doc(hostelId)
            .collection('pgs')
            .doc(pgId)
            .collection('floors')
            .doc(floorId)
            .collection('rooms')
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final rooms = snapshot.data!.docs;

          int totalRooms = rooms.length;
          int occupiedRooms = 0;
          int vacantRooms = 0;
          int totalResidents = 0;

          for (final r in rooms) {
            final d = r.data() as Map<String, dynamic>;
            final int occupiedBeds = (d['occupiedBeds'] ?? 0) as int;
            totalResidents += occupiedBeds;
            occupiedBeds == 0 ? vacantRooms++ : occupiedRooms++;
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _header(context),
                const SizedBox(height: 28),
                _summaryRow(
                  context,
                  totalRooms: totalRooms,
                  occupied: occupiedRooms,
                  vacant: vacantRooms,
                  residents: totalResidents,
                ),
                const SizedBox(height: 36),
                _sectionTitle(),
                const SizedBox(height: 20),
                _responsiveRooms(context, rooms),
              ],
            ),
          );
        },
      ),
    );
  }

  // ───────────────── HEADER ─────────────────
  Widget _header(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      children: [
        InkWell(
          onTap: () => Navigator.pop(context),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: _cardDecoration(theme),
            child: Icon(Icons.arrow_back, color: theme.iconTheme.color),
          ),
        ),
        const SizedBox(width: 14),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFFB145FF), Color(0xFFEC4899)],
            ),
            borderRadius: BorderRadius.all(Radius.circular(14)),
          ),
          child: const Icon(Icons.bed, color: Colors.white),
        ),
        const SizedBox(width: 14),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Room Management', style: theme.textTheme.titleLarge),
            Text('SmartStay PG', style: theme.textTheme.bodySmall),
          ],
        ),
        const Spacer(),
        InkWell(
          borderRadius: BorderRadius.circular(30),
          onTap: () {
            showDialog(
              context: context,
              barrierDismissible: false,
              builder: (_) => AddRoomDialog(
                hostelId: hostelId,
                pgId: pgId,
                floorId: floorId,
                adminId: adminId,
              ),
            );
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFFB145FF), Color(0xFFEC4899)],
              ),
              borderRadius: BorderRadius.all(Radius.circular(30)),
            ),
            child: const Row(
              children: [
                Icon(Icons.add, color: Colors.white, size: 18),
                SizedBox(width: 6),
                Text(
                  'Add Room',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ───────────────── HALF WIDTH ALWAYS ─────────────────
  Widget _responsiveRooms(
    BuildContext context,
    List<QueryDocumentSnapshot> rooms,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final cardWidth = (constraints.maxWidth - 24) / 2;

        return Wrap(
          spacing: 24,
          runSpacing: 24,
          children: rooms.map((doc) {
            final data = doc.data() as Map<String, dynamic>;

            return SizedBox(
              width: cardWidth,
              child: _RoomCard(
                context,
                hostelId: hostelId,
                pgId: pgId,
                floorId: floorId,
                roomId: doc.id,
                roomNo: data['roomNumber'].toString(),
                totalBeds: data['totalBeds'] ?? 0,
                occupiedBeds: data['occupiedBeds'] ?? 0,
                rent: (data['rentPerBed'] ?? data['price'] ?? 0).toInt(),
                status: _statusText(data),
                statusColor: _statusColor(data),
              ),
            );
          }).toList(),
        );
      },
    );
  }

  // ───────────────── ROOM CARD ─────────────────
  Widget _RoomCard(
    BuildContext context, {
    required String hostelId,
    required String pgId,
    required String floorId,
    required String roomId,
    required String roomNo,
    required int totalBeds,
    required int occupiedBeds,
    required int rent,
    required String status,
    required Color statusColor,
  }) {
    final theme = Theme.of(context);

    return Container(
      decoration: _cardDecoration(theme),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFFB145FF), Color(0xFFEC4899)],
                  ),
                  borderRadius: BorderRadius.all(Radius.circular(12)),
                ),
                child: Text(
                  roomNo,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Room $roomNo',
                  style: theme.textTheme.bodyLarge!.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  status,
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _infoChip(
                context,
                title: 'Sharing Type',
                value: '$totalBeds Beds',
                bg: const Color(0xFFF3E8FF),
                color: const Color(0xFF7C3AED),
              ),
              const SizedBox(width: 12),
              _infoChip(
                context,
                title: 'Occupancy',
                value: '$occupiedBeds/$totalBeds',
                bg: const Color(0xFFE0F7FA),
                color: const Color(0xFF009688),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceVariant,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '₹$rent per bed',
              style: theme.textTheme.bodyMedium!.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'Residents',
            style: theme.textTheme.bodyMedium!.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('residents')
                .where('hostelId', isEqualTo: hostelId)
                .where('pgId', isEqualTo: pgId)
                .where('floorId', isEqualTo: floorId)
                .where('roomId', isEqualTo: roomId)
                .where('adminId', isEqualTo: adminId)
                .snapshots(),
            builder: (context, snap) {
              if (!snap.hasData || snap.data!.docs.isEmpty) {
                return Text('No residents', style: theme.textTheme.bodySmall);
              }

              return Column(
                children: snap.data!.docs.map((r) {
                  final name = r['fullName'] ?? '';
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 14,
                          backgroundColor: theme.colorScheme.primary
                              .withOpacity(0.15),
                          child: Text(
                            name.isNotEmpty ? name[0].toUpperCase() : '?',
                            style: TextStyle(
                              fontSize: 12,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(name, style: theme.textTheme.bodySmall),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  // ───────────────── HELPERS ─────────────────
  String _statusText(Map<String, dynamic> d) {
    final ob = d['occupiedBeds'] ?? 0;
    final tb = d['totalBeds'] ?? 0;
    if (ob == 0) return 'Vacant';
    if (ob == tb) return 'Fully Occupied';
    return 'Partially Occupied';
  }

  Color _statusColor(Map<String, dynamic> d) {
    final ob = d['occupiedBeds'] ?? 0;
    final tb = d['totalBeds'] ?? 0;
    if (ob == 0) return Colors.grey;
    if (ob == tb) return Colors.green;
    return Colors.orange;
  }

  Widget _infoChip(
    BuildContext context, {
    required String title,
    required String value,
    required Color bg,
    required Color color,
  }) {
    final theme = Theme.of(context);

    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: theme.textTheme.bodySmall),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(fontWeight: FontWeight.bold, color: color),
            ),
          ],
        ),
      ),
    );
  }

  Widget _summaryRow(
    BuildContext context, {
    required int totalRooms,
    required int occupied,
    required int vacant,
    required int residents,
  }) {
    return Row(
      children: [
        _SummaryCard(context, 'Total Rooms', totalRooms),
        const SizedBox(width: 16),
        _SummaryCard(context, 'Occupied', occupied),
        const SizedBox(width: 16),
        _SummaryCard(context, 'Vacant', vacant),
        const SizedBox(width: 16),
        _SummaryCard(context, 'Total Residents', residents),
      ],
    );
  }

  Widget _SummaryCard(BuildContext context, String title, int value) {
    final theme = Theme.of(context);

    return Expanded(
      child: Container(
        decoration: _cardDecoration(theme),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: theme.textTheme.bodySmall),
            const SizedBox(height: 12),
            Text(
              value.toString(),
              style: theme.textTheme.headlineSmall!.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  BoxDecoration _cardDecoration(ThemeData theme) {
    return BoxDecoration(
      color: theme.cardColor,
      borderRadius: BorderRadius.circular(18),
      boxShadow: const [
        BoxShadow(
          color: Color(0x14000000),
          blurRadius: 20,
          offset: Offset(0, 8),
        ),
      ],
    );
  }

  Widget _sectionTitle() {
    return const Row(
      children: [
        SizedBox(
          height: 18,
          child: VerticalDivider(
            thickness: 3,
            width: 20,
            color: Color(0xFFB145FF),
          ),
        ),
        Text(
          'All Rooms',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }
}
