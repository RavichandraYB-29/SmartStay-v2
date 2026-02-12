import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'add_floor_dialog.dart';
import 'room_management_screen.dart';

class FloorManagementScreen extends StatelessWidget {
  final String hostelId;
  final String pgId;
  final String hostelName;
  final String pgName;
  final String adminId;

  const FloorManagementScreen({
    super.key,
    required this.hostelId,
    required this.pgId,
    required this.hostelName,
    required this.pgName,
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
            .orderBy('floorIndex')
            .snapshots(),
        builder: (context, floorSnap) {
          if (!floorSnap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final floors = floorSnap.data!.docs;

          return FutureBuilder<List<_FloorAggregate>>(
            future: _aggregateFloors(floors),
            builder: (context, aggSnap) {
              if (!aggSnap.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final data = aggSnap.data!;

              int totalFloors = data.length;
              int totalRooms = 0;
              int occupiedRooms = 0;
              int totalBeds = 0;
              int occupiedBeds = 0;

              for (final f in data) {
                totalRooms += f.totalRooms;
                occupiedRooms += f.occupiedRooms;
                totalBeds += f.totalBeds;
                occupiedBeds += f.occupiedBeds;
              }

              final int rate = totalBeds == 0
                  ? 0
                  : ((occupiedBeds / totalBeds) * 100).toInt();

              return SingleChildScrollView(
                padding: const EdgeInsets.all(28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _header(context),
                    const SizedBox(height: 28),

                    /// SUMMARY ROW
                    Row(
                      children: [
                        SummaryCard(
                          title: 'Total Floors',
                          value: '$totalFloors',
                          color: const Color(0xFF26C6DA),
                          icon: Icons.layers,
                        ),
                        const SizedBox(width: 16),
                        SummaryCard(
                          title: 'Total Rooms',
                          value: '$totalRooms',
                          color: const Color(0xFFB388FF),
                          icon: Icons.bed,
                        ),
                        const SizedBox(width: 16),
                        SummaryCard(
                          title: 'Occupied Rooms',
                          value: '$occupiedRooms',
                          color: const Color(0xFF7C4DFF),
                          icon: Icons.hotel,
                        ),
                        const SizedBox(width: 16),
                        SummaryCard(
                          title: 'Occupancy Rate',
                          value: '$rate%',
                          color: const Color(0xFFFFA726),
                          icon: Icons.people,
                        ),
                      ],
                    ),

                    const SizedBox(height: 36),
                    Text(
                      'All Floors',
                      style: theme.textTheme.titleLarge!.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 20),

                    Column(
                      children: data.map((f) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 28),
                          child: _floorCard(
                            context,
                            f.floorIndex,
                            f.totalRooms,
                            f.occupiedRooms,
                            f.totalBeds,
                            f.occupiedBeds,
                            f.floorId,
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  // ───────────────── DATA AGGREGATION ─────────────────

  Future<List<_FloorAggregate>> _aggregateFloors(
    List<QueryDocumentSnapshot> floors,
  ) async {
    return Future.wait(
      floors.map((floor) async {
        final roomsSnap = await FirebaseFirestore.instance
            .collection('hostels')
            .doc(hostelId)
            .collection('pgs')
            .doc(pgId)
            .collection('floors')
            .doc(floor.id)
            .collection('rooms')
            .get();

        int tr = roomsSnap.docs.length;
        int or = 0;
        int tb = 0;
        int ob = 0;

        for (final r in roomsSnap.docs) {
          final d = r.data();
          final bedsRaw = d['totalBeds'];
          final occRaw = d['occupiedBeds'];
          final beds = bedsRaw is int ? bedsRaw : int.tryParse('$bedsRaw') ?? 0;
          final occ = occRaw is int ? occRaw : int.tryParse('$occRaw') ?? 0;

          tb += beds;
          ob += occ;
          if (occ > 0) or++;
        }

        return _FloorAggregate(
          floorId: floor.id,
          floorIndex: floor['floorIndex'] ?? 0,
          totalRooms: tr,
          occupiedRooms: or,
          totalBeds: tb,
          occupiedBeds: ob,
        );
      }),
    );
  }

  // ───────────────── UI ─────────────────

  Widget _header(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Row(
      children: [
        InkWell(
          onTap: () => Navigator.pop(context),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: _box(context),
            child: Icon(Icons.arrow_back, color: cs.primary),
          ),
        ),
        const SizedBox(width: 14),
        Icon(Icons.layers, size: 26, color: cs.primary),
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Floor Management',
              style: theme.textTheme.titleLarge!.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            Text('$hostelName • $pgName', style: theme.textTheme.bodySmall),
          ],
        ),
        const Spacer(),
        _addFloorBtn(context),
      ],
    );
  }

  Widget _addFloorBtn(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return InkWell(
      borderRadius: BorderRadius.circular(30),
      onTap: () {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (_) =>
              AddFloorDialog(hostelId: hostelId, pgId: pgId, adminId: adminId),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        decoration: BoxDecoration(
          color: cs.primary,
          borderRadius: BorderRadius.circular(30),
        ),
        child: const Row(
          children: [
            Icon(Icons.add, color: Colors.white, size: 18),
            SizedBox(width: 6),
            Text(
              'Add Floor',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _floorCard(
    BuildContext context,
    int index,
    int tr,
    int or,
    int tb,
    int ob,
    String floorId,
  ) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    final roomRate = tr == 0 ? 0.0 : or / tr;
    final bedRate = tb == 0 ? 0.0 : ob / tb;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(22),
        border: theme.brightness == Brightness.dark
            ? Border.all(color: cs.outline)
            : null,
        boxShadow: const [BoxShadow(color: Color(0x11000000), blurRadius: 18)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _floorHeader(context, index),
          const SizedBox(height: 22),
          _statsCards(context, tr, or, tb, ob),
          const SizedBox(height: 18),
          _progressBar(context, 'Room Occupancy', roomRate),
          const SizedBox(height: 12),
          _progressBar(context, 'Bed Occupancy', bedRate),
          const SizedBox(height: 22),
          _actionRow(context, floorId),
        ],
      ),
    );
  }

  Widget _floorHeader(BuildContext context, int index) {
    final cs = Theme.of(context).colorScheme;

    return Row(
      children: [
        Container(
          width: 56,
          height: 56,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: cs.primary,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Text(
            '${index + 1}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(width: 16),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _floorTitle(index),
              style: Theme.of(
                context,
              ).textTheme.titleMedium!.copyWith(fontWeight: FontWeight.w600),
            ),
            Text(
              'Floor ${index + 1}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ],
    );
  }

  Widget _statsCards(BuildContext context, int tr, int or, int tb, int ob) {
    return Row(
      children: [
        _statCard(context, 'Total Rooms', '$tr'),
        _statCard(context, 'Occupied', '$or'),
        _statCard(context, 'Total Beds', '$tb'),
        _statCard(context, 'Occupied Beds', '$ob'),
      ],
    );
  }

  Widget _statCard(BuildContext context, String label, String value) {
    final theme = Theme.of(context);

    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 6),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceVariant,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          children: [
            Text(label, style: theme.textTheme.bodySmall),
            const SizedBox(height: 6),
            Text(
              value,
              style: theme.textTheme.titleMedium!.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _progressBar(BuildContext context, String label, double value) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(label),
            const Spacer(),
            Text('${(value * 100).toInt()}%'),
          ],
        ),
        const SizedBox(height: 6),
        LinearProgressIndicator(
          value: value,
          minHeight: 6,
          backgroundColor: theme.dividerColor,
          color: cs.primary,
        ),
      ],
    );
  }

  Widget _actionRow(BuildContext context, String floorId) {
    final cs = Theme.of(context).colorScheme;

    return Row(
      children: [
        Expanded(
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => RoomManagementScreen(
                    hostelId: hostelId,
                    pgId: pgId,
                    floorId: floorId,
                    adminId: adminId,
                  ),
                ),
              );
            },
            child: Container(
              height: 46,
              decoration: BoxDecoration(
                color: cs.primary,
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.visibility, color: Colors.white, size: 18),
                  SizedBox(width: 8),
                  Text(
                    'View Rooms',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        _iconBtn(cs.primary, Icons.edit),
        const SizedBox(width: 8),
        _iconBtn(Colors.red, Icons.delete),
      ],
    );
  }

  Widget _iconBtn(Color color, IconData icon) {
    return Container(
      height: 46,
      width: 46,
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(icon, color: color),
    );
  }

  String _floorTitle(int index) {
    const names = [
      'Ground Floor',
      'First Floor',
      'Second Floor',
      'Third Floor',
      'Fourth Floor',
      'Fifth Floor',
    ];
    return index < names.length ? names[index] : 'Floor ${index + 1}';
  }

  BoxDecoration _box(BuildContext context) {
    final theme = Theme.of(context);

    return BoxDecoration(
      color: theme.cardColor,
      borderRadius: BorderRadius.circular(12),
      border: theme.brightness == Brightness.dark
          ? Border.all(color: theme.colorScheme.outline)
          : null,
      boxShadow: const [BoxShadow(color: Color(0x11000000), blurRadius: 10)],
    );
  }
}

// ───────────────── SUMMARY CARD ─────────────────

class SummaryCard extends StatelessWidget {
  final String title;
  final String value;
  final Color color;
  final IconData icon;

  const SummaryCard({
    super.key,
    required this.title,
    required this.value,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(18),
          border: theme.brightness == Brightness.dark
              ? Border.all(color: theme.colorScheme.outline)
              : null,
          boxShadow: const [
            BoxShadow(color: Color(0x11000000), blurRadius: 16),
          ],
        ),
        child: Row(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: theme.textTheme.bodySmall),
                const SizedBox(height: 6),
                Text(
                  value,
                  style: theme.textTheme.titleMedium!.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const Spacer(),
            Icon(icon, size: 30, color: color),
          ],
        ),
      ),
    );
  }
}

// ───────────────── MODEL ─────────────────

class _FloorAggregate {
  final String floorId;
  final int floorIndex;
  final int totalRooms;
  final int occupiedRooms;
  final int totalBeds;
  final int occupiedBeds;

  _FloorAggregate({
    required this.floorId,
    required this.floorIndex,
    required this.totalRooms,
    required this.occupiedRooms,
    required this.totalBeds,
    required this.occupiedBeds,
  });
}
