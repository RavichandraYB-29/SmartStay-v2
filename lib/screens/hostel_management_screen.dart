import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'add_hostel_dialog.dart';
import 'floor_management_screen.dart';

class HostelManagementScreen extends StatelessWidget {
  final String adminId;

  const HostelManagementScreen({super.key, required this.adminId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Header(adminId: adminId),
            const SizedBox(height: 28),
            _MetricsAggregator(adminId: adminId),
            const SizedBox(height: 36),
            Text(
              'All Hostels',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 20),
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('hostels')
                  .where('ownerId', isEqualTo: adminId)
                  .snapshots(),
              builder: (context, snap) {
                if (snap.hasError) {
                  return Text(
                    'Failed to load hostels: ${snap.error}',
                    style: Theme.of(context).textTheme.bodySmall,
                  );
                }
                if (!snap.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final hostels = snap.data!.docs;
                if (hostels.isNotEmpty) {
                  return _hostelGrid(hostels, adminId);
                }

                return FutureBuilder<QuerySnapshot>(
                  future: FirebaseFirestore.instance
                      .collection('hostels')
                      .where('adminId', isEqualTo: adminId)
                      .get(),
                  builder: (context, legacySnap) {
                    if (legacySnap.hasError) {
                      return Text(
                        'Failed to load hostels: ${legacySnap.error}',
                        style: Theme.of(context).textTheme.bodySmall,
                      );
                    }
                    if (!legacySnap.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final legacyHostels = legacySnap.data!.docs;
                    if (legacyHostels.isEmpty) {
                      return Padding(
                        padding: const EdgeInsets.all(40),
                        child: Center(
                          child: Text(
                            'No hostels added yet',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                      );
                    }

                    return _hostelGrid(legacyHostels, adminId);
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

/* ───────────────────────── HEADER ───────────────────────── */

class _Header extends StatelessWidget {
  final String adminId;

  const _Header({required this.adminId});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _iconWrapper(
          context,
          child: const Icon(Icons.arrow_back),
          onTap: () => Navigator.pop(context),
        ),
        const SizedBox(width: 14),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            gradient: _primaryGradient(),
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Icon(Icons.apartment, color: Colors.white),
        ),
        const SizedBox(width: 14),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Hostel Management',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 2),
            Text(
              'Manage your hostels, floors & rooms',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
        const Spacer(),
        InkWell(
          onTap: () => showDialog(
            context: context,
            barrierDismissible: false,
            builder: (_) => AddHostelDialog(adminId: adminId),
          ),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            decoration: BoxDecoration(
              gradient: _primaryGradient(),
              borderRadius: BorderRadius.circular(30),
            ),
            child: const Row(
              children: [
                Icon(Icons.add, color: Colors.white, size: 18),
                SizedBox(width: 6),
                Text(
                  'Add Hostel',
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
}

/* ───────────────────────── METRICS ───────────────────────── */

class _MetricsAggregator extends StatelessWidget {
  final String adminId;

  const _MetricsAggregator({required this.adminId});

  Future<Map<String, int>> _calculateTotals() async {
    int floors = 0, rooms = 0, beds = 0;

    final hostels = await FirebaseFirestore.instance
        .collection('hostels')
        .where('ownerId', isEqualTo: adminId)
        .get();

    QuerySnapshot legacyHostels = hostels;
    if (hostels.docs.isEmpty) {
      legacyHostels = await FirebaseFirestore.instance
          .collection('hostels')
          .where('adminId', isEqualTo: adminId)
          .get();
    }

    for (final hostel in legacyHostels.docs) {
      final pgsSnap = await FirebaseFirestore.instance
          .collection('hostels')
          .doc(hostel.id)
          .collection('pgs')
          .get();

      for (final pg in pgsSnap.docs) {
        final floorsSnap = await FirebaseFirestore.instance
            .collection('hostels')
            .doc(hostel.id)
            .collection('pgs')
            .doc(pg.id)
            .collection('floors')
            .get();

        floors += floorsSnap.docs.length;

        for (final floor in floorsSnap.docs) {
          final roomsSnap = await FirebaseFirestore.instance
              .collection('hostels')
              .doc(hostel.id)
              .collection('pgs')
              .doc(pg.id)
              .collection('floors')
              .doc(floor.id)
              .collection('rooms')
              .get();

          rooms += roomsSnap.docs.length;

          for (final room in roomsSnap.docs) {
            beds += (room['totalBeds'] ?? 0) as int;
          }
        }
      }
    }

    return {
      'hostels': legacyHostels.docs.length,
      'floors': floors,
      'rooms': rooms,
      'beds': beds,
    };
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, int>>(
      future: _calculateTotals(),
      builder: (context, snap) {
        if (!snap.hasData) {
          return _metricsRow(context, '—', '—', '—', '—');
        }

        final d = snap.data!;
        return _metricsRow(
          context,
          d['hostels'].toString(),
          d['floors'].toString(),
          d['rooms'].toString(),
          d['beds'].toString(),
        );
      },
    );
  }

  Widget _metricsRow(
    BuildContext context,
    String h,
    String f,
    String r,
    String b,
  ) {
    return Row(
      children: [
        _MetricCard(
          'Total Hostels',
          h,
          Icons.apartment,
          const Color(0xFF6C63FF),
        ),
        _MetricCard('Total Floors', f, Icons.layers, const Color(0xFF4DD0E1)),
        _MetricCard('Total Rooms', r, Icons.bed, const Color(0xFFB388FF)),
        _MetricCard('Total Beds', b, Icons.people, const Color(0xFFFFB74D)),
      ],
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String title, value;
  final IconData icon;
  final Color color;

  const _MetricCard(this.title, this.value, this.icon, this.color);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Expanded(
      child: Container(
        margin: const EdgeInsets.only(right: 16),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(18),
          border: theme.brightness == Brightness.dark
              ? Border.all(color: theme.colorScheme.outline)
              : null,
          boxShadow: const [
            BoxShadow(
              color: Color(0x14000000),
              blurRadius: 24,
              offset: Offset(0, 10),
            ),
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
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color),
            ),
          ],
        ),
      ),
    );
  }
}

/* ───────────────────────── HOSTEL CARD ───────────────────────── */

class _HostelAggregator extends StatelessWidget {
  final String hostelId, name, address, adminId;

  const _HostelAggregator({
    required this.hostelId,
    required this.name,
    required this.address,
    required this.adminId,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<QuerySnapshot>(
      future: FirebaseFirestore.instance
          .collection('hostels')
          .doc(hostelId)
          .collection('pgs')
          .get(),
      builder: (context, pSnap) {
        if (!pSnap.hasData) return const SizedBox();

        final pgs = pSnap.data!.docs;
        if (pgs.isEmpty) {
          return _HostelCard(
            hostelId: hostelId,
            name: name,
            address: address,
            adminId: adminId,
            floors: 0,
            rooms: 0,
            occRooms: 0,
            beds: 0,
            occBeds: 0,
            pgs: const [],
          );
        }

        return FutureBuilder<List<_PgAggregate>>(
          future: Future.wait(
            pgs.map((pg) async {
              final floorsSnap = await FirebaseFirestore.instance
                  .collection('hostels')
                  .doc(hostelId)
                  .collection('pgs')
                  .doc(pg.id)
                  .collection('floors')
                  .get();

              int floorsCount = floorsSnap.docs.length;
              int rooms = 0;
              int occRooms = 0;
              int beds = 0;
              int occBeds = 0;

              for (final f in floorsSnap.docs) {
                final roomsSnap = await FirebaseFirestore.instance
                    .collection('hostels')
                    .doc(hostelId)
                    .collection('pgs')
                    .doc(pg.id)
                    .collection('floors')
                    .doc(f.id)
                    .collection('rooms')
                    .get();
                for (final r in roomsSnap.docs) {
                  final d = r.data();
                  final tbRaw = d['totalBeds'];
                  final obRaw = d['occupiedBeds'];
                  final tb = tbRaw is int ? tbRaw : int.tryParse('$tbRaw') ?? 0;
                  final ob = obRaw is int ? obRaw : int.tryParse('$obRaw') ?? 0;
                  rooms++;
                  beds += tb;
                  occBeds += ob;
                  if (ob > 0) occRooms++;
                }
              }

              final pgData = pg.data() as Map<String, dynamic>;
              final pgName = (pgData['name'] ?? pgData['pgName'] ?? 'PG')
                  .toString();
              return _PgAggregate(
                pgId: pg.id,
                pgName: pgName,
                floors: floorsCount,
                rooms: rooms,
                occRooms: occRooms,
                beds: beds,
                occBeds: occBeds,
              );
            }),
          ),
          builder: (context, aggSnap) {
            if (!aggSnap.hasData) return const SizedBox();
            final aggs = aggSnap.data!;

            int floors = 0, rooms = 0, occRooms = 0, beds = 0, occBeds = 0;
            final pgOptions = <_PgOptionMini>[];
            for (final a in aggs) {
              floors += a.floors;
              rooms += a.rooms;
              occRooms += a.occRooms;
              beds += a.beds;
              occBeds += a.occBeds;
              pgOptions.add(_PgOptionMini(id: a.pgId, name: a.pgName));
            }

            return _HostelCard(
              hostelId: hostelId,
              name: name,
              address: address,
              adminId: adminId,
              floors: floors,
              rooms: rooms,
              occRooms: occRooms,
              beds: beds,
              occBeds: occBeds,
              pgs: pgOptions,
            );
          },
        );
      },
    );
  }
}

class _PgAggregate {
  final String pgId;
  final String pgName;
  final int floors;
  final int rooms;
  final int occRooms;
  final int beds;
  final int occBeds;

  _PgAggregate({
    required this.pgId,
    required this.pgName,
    required this.floors,
    required this.rooms,
    required this.occRooms,
    required this.beds,
    required this.occBeds,
  });
}

class _PgOptionMini {
  final String id;
  final String name;

  const _PgOptionMini({required this.id, required this.name});
}

class _HostelCard extends StatelessWidget {
  final String hostelId, name, address, adminId;
  final int floors, rooms, occRooms, beds, occBeds;
  final List<_PgOptionMini> pgs;

  const _HostelCard({
    required this.hostelId,
    required this.name,
    required this.address,
    required this.adminId,
    required this.floors,
    required this.rooms,
    required this.occRooms,
    required this.beds,
    required this.occBeds,
    required this.pgs,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(22),
        border: theme.brightness == Brightness.dark
            ? Border.all(color: theme.colorScheme.outline)
            : null,
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 28,
            offset: Offset(0, 14),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            height: 8,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF6C3BFF), Color(0xFFE10098)],
              ),
              borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        name,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    _iconAction(context, Icons.edit, Colors.blue),
                    const SizedBox(width: 8),
                    _iconAction(context, Icons.delete, Colors.red),
                  ],
                ),
                const SizedBox(height: 6),
                Text(address, style: theme.textTheme.bodySmall),
                const SizedBox(height: 16),
                _statTile(
                  context,
                  'Floors',
                  floors.toString(),
                  theme.colorScheme.surfaceVariant,
                ),
                _statTile(
                  context,
                  'Total Rooms',
                  rooms.toString(),
                  theme.colorScheme.surfaceVariant,
                ),
                _statTile(
                  context,
                  'Occupied Rooms',
                  '$occRooms/$rooms',
                  theme.colorScheme.surfaceVariant,
                ),
                _statTile(
                  context,
                  'Occupied Beds',
                  '$occBeds/$beds',
                  theme.colorScheme.surfaceVariant,
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.visibility),
                    label: const Text('Manage Floors & Rooms'),
                    onPressed: () {
                      _openPgFloorManagement(context);
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _statTile(BuildContext context, String t, String v, Color bg) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Text(t, style: theme.textTheme.bodySmall),
          const Spacer(),
          Text(
            v,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _iconAction(BuildContext context, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(icon, size: 16, color: color),
    );
  }

  Future<void> _openPgFloorManagement(BuildContext context) async {
    if (pgs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No PGs found for this hostel')),
      );
      return;
    }
    if (pgs.length == 1) {
      final pg = pgs.first;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => FloorManagementScreen(
            hostelId: hostelId,
            pgId: pg.id,
            hostelName: name,
            pgName: pg.name,
            adminId: adminId,
          ),
        ),
      );
      return;
    }

    final selected = await showDialog<_PgOptionMini>(
      context: context,
      builder: (context) {
        return SimpleDialog(
          title: const Text('Select PG'),
          children: pgs
              .map(
                (pg) => SimpleDialogOption(
                  onPressed: () => Navigator.pop(context, pg),
                  child: Text(pg.name),
                ),
              )
              .toList(),
        );
      },
    );

    if (selected == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => FloorManagementScreen(
          hostelId: hostelId,
          pgId: selected.id,
          hostelName: name,
          pgName: selected.name,
          adminId: adminId,
        ),
      ),
    );
  }
}

/* ───────────────────────── HELPERS ───────────────────────── */

Widget _iconWrapper(
  BuildContext context, {
  required Widget child,
  VoidCallback? onTap,
}) {
  return InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(12),
    child: Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Theme.of(context).brightness == Brightness.dark
            ? Border.all(color: Theme.of(context).colorScheme.outline)
            : null,
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 12,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: child,
    ),
  );
}

LinearGradient _primaryGradient() => const LinearGradient(
  colors: [Color(0xFF6C3BFF), Color(0xFF9B4DFF), Color(0xFFE10098)],
);

Widget _hostelGrid(List<QueryDocumentSnapshot> hostels, String adminId) {
  return GridView.builder(
    shrinkWrap: true,
    physics: const NeverScrollableScrollPhysics(),
    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
      crossAxisCount: 2,
      crossAxisSpacing: 24,
      mainAxisSpacing: 24,
      childAspectRatio: 1.22,
    ),
    itemCount: hostels.length,
    itemBuilder: (_, i) {
      final h = hostels[i];
      final d = h.data() as Map<String, dynamic>;
      return _HostelAggregator(
        hostelId: h.id,
        name: d['name'] ?? '',
        address: d['address'] ?? '',
        adminId: adminId,
      );
    },
  );
}
