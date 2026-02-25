import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../utils/admin_design_system.dart';
import '../widgets/admin_widgets.dart';
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor:
          isDark ? AdminColors.scaffoldDark : AdminColors.scaffoldLight,
      floatingActionButton: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          boxShadow: AdminShadows.fab,
        ),
        child: FloatingActionButton.extended(
          onPressed: () => _showAddRoomDialog(context),
          backgroundColor: AdminColors.primary,
          icon: const Icon(Icons.add_rounded, color: Colors.white),
          label: const Text(
            'Add Room',
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
      ),
      body: SafeArea(
        child: Column(
          children: [
            AdminPageHeader(
              title: 'Room Management',
              subtitle: 'Floors → Rooms',
              icon: Icons.meeting_room_rounded,
              iconGradient: AdminGradients.pink,
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
                    .doc(floorId)
                    .collection('rooms')
                    .snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return _buildShimmerLoading();
                  }

                  final rooms = snapshot.data!.docs;

                  if (rooms.isEmpty) {
                    return AdminEmptyState(
                      icon: Icons.meeting_room_rounded,
                      title: 'No rooms yet',
                      subtitle:
                          'Add your first room to start managing beds and residents.',
                      actionLabel: 'Add Room',
                      onAction: () => _showAddRoomDialog(context),
                    );
                  }

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
                    padding: AdminSpacing.pagePadding,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        /// SUMMARY STAT CARDS
                        _SummaryGrid(
                          totalRooms: totalRooms,
                          occupied: occupiedRooms,
                          vacant: vacantRooms,
                          residents: totalResidents,
                        ),
                        const SizedBox(height: 28),

                        /// SECTION TITLE
                        const AdminSectionTitle(title: 'All Rooms'),
                        const SizedBox(height: 16),

                        /// ROOM CARDS
                        _ResponsiveRoomGrid(
                          rooms: rooms,
                          hostelId: hostelId,
                          pgId: pgId,
                          floorId: floorId,
                          adminId: adminId,
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddRoomDialog(BuildContext context) {
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
  }

  Widget _buildShimmerLoading() {
    return Padding(
      padding: AdminSpacing.pagePadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const ShimmerStatCardGrid(count: 4),
          const SizedBox(height: 28),
          ShimmerBox(width: 120, height: 20),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: ShimmerBox(width: double.infinity, height: 240)),
              const SizedBox(width: 16),
              Expanded(child: ShimmerBox(width: double.infinity, height: 240)),
            ],
          ),
        ],
      ),
    );
  }
}

// ───────────────── SUMMARY GRID ─────────────────

class _SummaryGrid extends StatelessWidget {
  final int totalRooms, occupied, vacant, residents;

  const _SummaryGrid({
    required this.totalRooms,
    required this.occupied,
    required this.vacant,
    required this.residents,
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
          title: 'Total Rooms',
          value: '$totalRooms',
          icon: Icons.meeting_room_rounded,
          iconColor: AdminColors.roomsIcon,
          bgColor: AdminColors.roomsBg,
        ),
        AdminStatCard(
          title: 'Occupied',
          value: '$occupied',
          icon: Icons.hotel_rounded,
          iconColor: AdminColors.hostelsIcon,
          bgColor: AdminColors.hostelsBg,
        ),
        AdminStatCard(
          title: 'Vacant',
          value: '$vacant',
          icon: Icons.check_circle_rounded,
          iconColor: AdminColors.success,
          bgColor: AdminColors.successLight,
        ),
        AdminStatCard(
          title: 'Total Residents',
          value: '$residents',
          icon: Icons.people_rounded,
          iconColor: AdminColors.residentsIcon,
          bgColor: AdminColors.residentsBg,
        ),
      ],
    );
  }
}

// ───────────────── RESPONSIVE ROOM GRID ─────────────────

class _ResponsiveRoomGrid extends StatelessWidget {
  final List<QueryDocumentSnapshot> rooms;
  final String hostelId, pgId, floorId, adminId;

  const _ResponsiveRoomGrid({
    required this.rooms,
    required this.hostelId,
    required this.pgId,
    required this.floorId,
    required this.adminId,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final cardWidth = (constraints.maxWidth - 16) / 2;

        return Wrap(
          spacing: 16,
          runSpacing: 16,
          children: rooms.map((doc) {
            final data = doc.data() as Map<String, dynamic>;

            return SizedBox(
              width: cardWidth,
              child: _RoomCard(
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
                adminId: adminId,
              ),
            );
          }).toList(),
        );
      },
    );
  }

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
    if (ob == 0) return AdminColors.textMuted;
    if (ob == tb) return AdminColors.danger;
    return AdminColors.success;
  }
}

// ───────────────── ROOM CARD ─────────────────

class _RoomCard extends StatelessWidget {
  final String hostelId, pgId, floorId, roomId, roomNo, adminId;
  final int totalBeds, occupiedBeds, rent;
  final String status;
  final Color statusColor;

  const _RoomCard({
    required this.hostelId,
    required this.pgId,
    required this.floorId,
    required this.roomId,
    required this.roomNo,
    required this.totalBeds,
    required this.occupiedBeds,
    required this.rent,
    required this.status,
    required this.statusColor,
    required this.adminId,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final vacantBeds = totalBeds - occupiedBeds;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E2130) : Colors.white,
        borderRadius: AdminRadius.lg,
        border: isDark ? Border.all(color: const Color(0xFF2E3347)) : null,
        boxShadow: AdminShadows.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          /// CARD HEADER
          _buildHeader(isDark),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                /// INFO CHIPS
                _buildInfoChips(isDark),
                const SizedBox(height: 14),

                /// RENT BADGE
                Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: isDark
                          ? [
                              const Color(0xFF1A2332),
                              const Color(0xFF1A1D24),
                            ]
                          : [
                              const Color(0xFFF8FAFC),
                              const Color(0xFFF1F5F9),
                            ],
                    ),
                    borderRadius: AdminRadius.sm,
                    border: Border.all(
                      color:
                          isDark ? const Color(0xFF2E3347) : const Color(0xFFE2E8F0),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.currency_rupee_rounded,
                        size: 16,
                        color: AdminColors.bedsIcon,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '$rent per bed',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          fontFamily: 'Inter',
                          color: isDark ? Colors.white : AdminColors.textPrimary,
                        ),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: vacantBeds > 0
                              ? AdminColors.success.withOpacity(0.1)
                              : AdminColors.danger.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '$vacantBeds vacant',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            fontFamily: 'Inter',
                            color: vacantBeds > 0
                                ? AdminColors.success
                                : AdminColors.danger,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                /// OCCUPANCY BAR
                OccupancyBar(
                  label: 'Occupancy',
                  occupied: occupiedBeds,
                  total: totalBeds,
                ),
                const SizedBox(height: 16),

                /// RESIDENTS SECTION
                _buildResidents(context, isDark),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: isDark
            ? const LinearGradient(
                colors: [Color(0xFF252A3A), Color(0xFF1E2130)],
              )
            : AdminGradients.headerPurple,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(18),
          topRight: Radius.circular(18),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              gradient: AdminGradients.pink,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFEC4899).withOpacity(0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Text(
              roomNo,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontFamily: 'Inter',
                fontSize: 14,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Room $roomNo',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    fontFamily: 'Inter',
                    color: isDark ? Colors.white : AdminColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '$totalBeds beds · ₹$rent/bed',
                  style: TextStyle(
                    fontSize: 11,
                    fontFamily: 'Inter',
                    color: isDark
                        ? const Color(0xFFB5B5C3)
                        : AdminColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.12),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              status,
              style: TextStyle(
                color: statusColor,
                fontSize: 11,
                fontWeight: FontWeight.w600,
                fontFamily: 'Inter',
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoChips(bool isDark) {
    return Row(
      children: [
        _InfoChip(
          icon: Icons.bed_rounded,
          title: 'Sharing',
          value: '$totalBeds Beds',
          bgColor:
              isDark ? AdminColors.hostelsBg.withOpacity(0.15) : AdminColors.hostelsBg,
          iconColor: AdminColors.hostelsIcon,
        ),
        const SizedBox(width: 10),
        _InfoChip(
          icon: Icons.people_rounded,
          title: 'Occupancy',
          value: '$occupiedBeds/$totalBeds',
          bgColor:
              isDark ? AdminColors.residentsBg.withOpacity(0.15) : AdminColors.residentsBg,
          iconColor: AdminColors.residentsIcon,
        ),
      ],
    );
  }

  Widget _buildResidents(BuildContext context, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.people_outline_rounded,
                size: 14, color: AdminColors.primary),
            const SizedBox(width: 6),
            const Text(
              'Residents',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                fontFamily: 'Inter',
                color: AdminColors.textSecondary,
              ),
            ),
          ],
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
              return Container(
                padding:
                    const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF252A3A)
                      : const Color(0xFFF8FAFC),
                  borderRadius: AdminRadius.sm,
                ),
                child: Row(
                  children: [
                    Icon(Icons.person_off_rounded,
                        size: 14, color: AdminColors.textMuted),
                    const SizedBox(width: 8),
                    const Text(
                      'No residents assigned',
                      style: TextStyle(
                        fontSize: 12,
                        fontFamily: 'Inter',
                        color: AdminColors.textMuted,
                      ),
                    ),
                  ],
                ),
              );
            }

            return Column(
              children: snap.data!.docs.map((r) {
                final name = r['fullName'] ?? '';
                return Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    children: [
                      Container(
                        width: 28,
                        height: 28,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          gradient: AdminGradients.primary,
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          name.isNotEmpty ? name[0].toUpperCase() : '?',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            fontFamily: 'Inter',
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          name,
                          style: TextStyle(
                            fontSize: 13,
                            fontFamily: 'Inter',
                            fontWeight: FontWeight.w500,
                            color: isDark
                                ? Colors.white
                                : AdminColors.textPrimary,
                          ),
                        ),
                      ),
                      Icon(
                        Icons.chevron_right_rounded,
                        size: 16,
                        color: AdminColors.textMuted,
                      ),
                    ],
                  ),
                );
              }).toList(),
            );
          },
        ),
      ],
    );
  }
}

// ───────────────── INFO CHIP ─────────────────

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String title, value;
  final Color bgColor, iconColor;

  const _InfoChip({
    required this.icon,
    required this.title,
    required this.value,
    required this.bgColor,
    required this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: AdminRadius.sm,
        ),
        child: Row(
          children: [
            Icon(icon, size: 16, color: iconColor),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                      fontFamily: 'Inter',
                      color: AdminColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      fontFamily: 'Inter',
                      color: iconColor,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
