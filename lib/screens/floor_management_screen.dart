import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../utils/admin_design_system.dart';
import '../widgets/admin_widgets.dart';
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor:
          isDark ? AdminColors.scaffoldDark : AdminColors.scaffoldLight,
      floatingActionButton: _FloatingAddButton(
        onPressed: () => _showAddFloorDialog(context),
      ),
      body: SafeArea(
        child: Column(
          children: [
            AdminPageHeader(
              title: 'Floor Management',
              subtitle: '$hostelName • $pgName',
              icon: Icons.layers_rounded,
              iconGradient: AdminGradients.blue,
              onBack: () => Navigator.pop(context),
            ),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
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
                    return _buildShimmerLoading();
                  }

                  final floors = floorSnap.data!.docs;

                  return FutureBuilder<List<_FloorAggregate>>(
                    future: _aggregateFloors(floors),
                    builder: (context, aggSnap) {
                      if (!aggSnap.hasData) {
                        return _buildShimmerLoading();
                      }

                      final data = aggSnap.data!;

                      if (data.isEmpty) {
                        return AdminEmptyState(
                          icon: Icons.layers_rounded,
                          title: 'No floors yet',
                          subtitle:
                              'Add your first floor to start managing rooms.',
                          actionLabel: 'Add Floor',
                          onAction: () => _showAddFloorDialog(context),
                        );
                      }

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
                        padding: AdminSpacing.pagePadding,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            /// SUMMARY STAT CARDS
                            _SummaryGrid(
                              totalFloors: totalFloors,
                              totalRooms: totalRooms,
                              occupiedRooms: occupiedRooms,
                              rate: rate,
                            ),
                            const SizedBox(height: 28),

                            /// SECTION TITLE
                            const AdminSectionTitle(
                              title: 'All Floors',
                            ),
                            const SizedBox(height: 16),

                            /// FLOOR CARDS
                            ...data.map((f) => Padding(
                                  padding: const EdgeInsets.only(bottom: 16),
                                  child: _FloorCard(
                                    floorIndex: f.floorIndex,
                                    totalRooms: f.totalRooms,
                                    occupiedRooms: f.occupiedRooms,
                                    totalBeds: f.totalBeds,
                                    occupiedBeds: f.occupiedBeds,
                                    floorId: f.floorId,
                                    hostelId: hostelId,
                                    pgId: pgId,
                                    adminId: adminId,
                                  ),
                                )),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddFloorDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) =>
          AddFloorDialog(hostelId: hostelId, pgId: pgId, adminId: adminId),
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
          final beds =
              bedsRaw is int ? bedsRaw : int.tryParse('$bedsRaw') ?? 0;
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

  Widget _buildShimmerLoading() {
    return SingleChildScrollView(
      padding: AdminSpacing.pagePadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const ShimmerStatCardGrid(count: 4),
          const SizedBox(height: 28),
          ShimmerBox(width: 120, height: 20),
          const SizedBox(height: 16),
          ShimmerBox(width: double.infinity, height: 200),
          const SizedBox(height: 16),
          ShimmerBox(width: double.infinity, height: 200),
        ],
      ),
    );
  }
}

// ───────────────── FLOATING ADD BUTTON ─────────────────

class _FloatingAddButton extends StatelessWidget {
  final VoidCallback onPressed;
  const _FloatingAddButton({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: AdminShadows.fab,
      ),
      child: FloatingActionButton.extended(
        onPressed: onPressed,
        backgroundColor: AdminColors.primary,
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: const Text(
          'Add Floor',
          style: TextStyle(
            color: Colors.white,
            fontFamily: 'Inter',
            fontWeight: FontWeight.w600,
          ),
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    );
  }
}

// ───────────────── SUMMARY GRID ─────────────────

class _SummaryGrid extends StatelessWidget {
  final int totalFloors, totalRooms, occupiedRooms, rate;

  const _SummaryGrid({
    required this.totalFloors,
    required this.totalRooms,
    required this.occupiedRooms,
    required this.rate,
  });

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 4,
      mainAxisSpacing: 14,
      crossAxisSpacing: 14,
      childAspectRatio: 1.6,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: [
        AdminStatCard(
          title: 'Total Floors',
          value: '$totalFloors',
          icon: Icons.layers_rounded,
          iconColor: AdminColors.floorsIcon,
          bgColor: AdminColors.floorsBg,
        ),
        AdminStatCard(
          title: 'Total Rooms',
          value: '$totalRooms',
          icon: Icons.meeting_room_rounded,
          iconColor: AdminColors.roomsIcon,
          bgColor: AdminColors.roomsBg,
        ),
        AdminStatCard(
          title: 'Occupied Rooms',
          value: '$occupiedRooms',
          icon: Icons.hotel_rounded,
          iconColor: AdminColors.hostelsIcon,
          bgColor: AdminColors.hostelsBg,
        ),
        AdminStatCard(
          title: 'Occupancy Rate',
          value: '$rate%',
          icon: Icons.pie_chart_rounded,
          iconColor: rate >= 80
              ? AdminColors.danger
              : rate >= 50
                  ? AdminColors.warning
                  : AdminColors.success,
          bgColor: rate >= 80
              ? AdminColors.dangerLight
              : rate >= 50
                  ? AdminColors.warningLight
                  : AdminColors.successLight,
        ),
      ],
    );
  }
}

// ───────────────── FLOOR CARD ─────────────────

class _FloorCard extends StatelessWidget {
  final int floorIndex, totalRooms, occupiedRooms, totalBeds, occupiedBeds;
  final String floorId, hostelId, pgId, adminId;

  const _FloorCard({
    required this.floorIndex,
    required this.totalRooms,
    required this.occupiedRooms,
    required this.totalBeds,
    required this.occupiedBeds,
    required this.floorId,
    required this.hostelId,
    required this.pgId,
    required this.adminId,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E2130) : Colors.white,
        borderRadius: AdminRadius.lg,
        border:
            isDark ? Border.all(color: const Color(0xFF2E3347)) : null,
        boxShadow: AdminShadows.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(context),
          const SizedBox(height: 18),
          _buildMiniStats(context),
          const SizedBox(height: 18),
          OccupancyBar(
            label: 'Room Occupancy',
            occupied: occupiedRooms,
            total: totalRooms,
          ),
          const SizedBox(height: 12),
          OccupancyBar(
            label: 'Bed Occupancy',
            occupied: occupiedBeds,
            total: totalBeds,
          ),
          const SizedBox(height: 20),
          _buildActions(context),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 50,
          height: 50,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            gradient: AdminGradients.primary,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Text(
            '${floorIndex + 1}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w800,
              fontFamily: 'Inter',
            ),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _floorTitle(floorIndex),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  fontFamily: 'Inter',
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '$totalRooms rooms · $totalBeds beds',
                style: const TextStyle(
                  fontSize: 12,
                  color: AdminColors.textSecondary,
                  fontFamily: 'Inter',
                ),
              ),
            ],
          ),
        ),
        _StatusChip(
          label: occupiedBeds == 0
              ? 'Empty'
              : totalBeds == occupiedBeds
                  ? 'Full'
                  : 'Active',
          color: occupiedBeds == 0
              ? AdminColors.textMuted
              : totalBeds == occupiedBeds
                  ? AdminColors.danger
                  : AdminColors.success,
        ),
      ],
    );
  }

  Widget _buildMiniStats(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Row(
      children: [
        _MiniStatChip(
          icon: Icons.meeting_room_rounded,
          label: 'Rooms',
          value: '$totalRooms',
          bgColor: isDark
              ? AdminColors.floorsBg.withOpacity(0.15)
              : AdminColors.floorsBg,
          iconColor: AdminColors.floorsIcon,
        ),
        const SizedBox(width: 8),
        _MiniStatChip(
          icon: Icons.hotel_rounded,
          label: 'Occupied',
          value: '$occupiedRooms',
          bgColor: isDark
              ? AdminColors.hostelsBg.withOpacity(0.15)
              : AdminColors.hostelsBg,
          iconColor: AdminColors.hostelsIcon,
        ),
        const SizedBox(width: 8),
        _MiniStatChip(
          icon: Icons.bed_rounded,
          label: 'Beds',
          value: '$totalBeds',
          bgColor: isDark
              ? AdminColors.bedsBg.withOpacity(0.15)
              : AdminColors.bedsBg,
          iconColor: AdminColors.bedsIcon,
        ),
        const SizedBox(width: 8),
        _MiniStatChip(
          icon: Icons.person_rounded,
          label: 'Filled',
          value: '$occupiedBeds',
          bgColor: isDark
              ? AdminColors.residentsBg.withOpacity(0.15)
              : AdminColors.residentsBg,
          iconColor: AdminColors.residentsIcon,
        ),
      ],
    );
  }

  Widget _buildActions(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: AdminRadius.md,
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
                height: 44,
                decoration: BoxDecoration(
                  gradient: AdminGradients.primary,
                  borderRadius: AdminRadius.md,
                  boxShadow: [
                    BoxShadow(
                      color: AdminColors.primary.withOpacity(0.25),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.visibility_rounded, color: Colors.white,
                        size: 16),
                    SizedBox(width: 8),
                    Text(
                      'View Rooms',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontFamily: 'Inter',
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        _ActionIconButton(
          icon: Icons.edit_rounded,
          color: AdminColors.info,
          tooltip: 'Edit Floor',
        ),
        const SizedBox(width: 8),
        _ActionIconButton(
          icon: Icons.delete_rounded,
          color: AdminColors.danger,
          tooltip: 'Delete Floor',
        ),
      ],
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
}

// ───────────────── SUPPORTING WIDGETS ─────────────────

class _StatusChip extends StatelessWidget {
  final String label;
  final Color color;
  const _StatusChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          fontFamily: 'Inter',
          color: color,
        ),
      ),
    );
  }
}

class _MiniStatChip extends StatelessWidget {
  final IconData icon;
  final String label, value;
  final Color bgColor, iconColor;

  const _MiniStatChip({
    required this.icon,
    required this.label,
    required this.value,
    required this.bgColor,
    required this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: AdminRadius.sm,
        ),
        child: Column(
          children: [
            Icon(icon, size: 16, color: iconColor),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                fontFamily: 'Inter',
                color: iconColor,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w500,
                fontFamily: 'Inter',
                color: AdminColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionIconButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String tooltip;

  const _ActionIconButton({
    required this.icon,
    required this.color,
    required this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          child: Container(
            height: 44,
            width: 44,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: color.withOpacity(0.2)),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
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