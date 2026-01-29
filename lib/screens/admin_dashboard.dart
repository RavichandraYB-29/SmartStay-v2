import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../main.dart';
import 'login_screen.dart';
import 'hostel_management_screen.dart';
import 'add_resident_screen.dart';
import 'allocate_resident_screen.dart';
import '../theme/app_text_styles.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  bool _checkedRole = false;
  String? _adminId;

  @override
  void initState() {
    super.initState();
    _ensureAdminRole();
  }

  Future<void> _ensureAdminRole() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _signOutToLogin();
      return;
    }

    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      final role = userDoc.data()?['role'];

      if (role != 'admin') {
        _showRoleBlocked();
        return;
      }

      setState(() {
        _adminId = user.uid;
        _checkedRole = true;
      });
    } catch (_) {
      _signOutToLogin();
    }
  }

  void _showRoleBlocked() {
    FirebaseAuth.instance.signOut();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Access Denied'),
        content: const Text(
          'This account is not authorized to access the admin dashboard.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    ).then((_) => _signOutToLogin());
  }

  void _signOutToLogin() {
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final date = DateFormat('MMM dd, yyyy').format(DateTime.now());

    if (!_checkedRole || _adminId == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final adminId = _adminId!;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Header(date: date),
            const SizedBox(height: 22),
            const _SearchBar(),
            const SizedBox(height: 28),
            _StatsRow(adminId: adminId),
            const SizedBox(height: 32),
            _QuickActions(context, adminId),
            const SizedBox(height: 32),
            _MainGrid(adminId: adminId),
          ],
        ),
      ),
    );
  }
}

/* =========================================================
   HEADER
========================================================= */

class _Header extends StatelessWidget {
  final String date;
  const _Header({required this.date});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final app = context.findAncestorWidgetOfExactType<SmartStayApp>();
    final cs = Theme.of(context).colorScheme;

    return Row(
      children: [
        Container(
          height: 44,
          width: 44,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF6C3BFF), Color(0xFF8E6CFF)],
            ),
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Icon(Icons.apartment, color: Colors.white),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text('SmartStay', style: AppTextStyles.h3),
            Text('Admin Dashboard', style: AppTextStyles.bodySmall),
          ],
        ),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: _card(context),
          child: Row(
            children: [
              const Icon(Icons.calendar_today_outlined, size: 16),
              const SizedBox(width: 8),
              Text(date, style: AppTextStyles.bodySmall),
            ],
          ),
        ),
        const SizedBox(width: 14),
        IconButton(
          tooltip: isDark ? 'Light Mode' : 'Dark Mode',
          icon: Icon(isDark ? Icons.light_mode : Icons.dark_mode),
          onPressed: () => app!.themeController.toggleTheme(),
        ),
        const SizedBox(width: 8),
        IconButton(
          tooltip: 'Logout',
          icon: const Icon(Icons.logout),
          onPressed: () async {
            await FirebaseAuth.instance.signOut();
            if (!context.mounted) return;
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (_) => const LoginScreen()),
              (_) => false,
            );
          },
        ),
        const SizedBox(width: 4),
        CircleAvatar(
          backgroundColor: cs.primary.withOpacity(0.15),
          child: Icon(Icons.person, color: cs.primary),
        ),
      ],
    );
  }
}

/* =========================================================
   SEARCH BAR
========================================================= */

class _SearchBar extends StatelessWidget {
  const _SearchBar();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: _card(context),
      child: const TextField(
        decoration: InputDecoration(
          icon: Icon(Icons.search),
          hintText: 'Search residents, rooms, payments...',
          border: InputBorder.none,
        ),
      ),
    );
  }
}

/* =========================================================
   STATS
========================================================= */

class _StatsRow extends StatelessWidget {
  final String adminId;
  const _StatsRow({required this.adminId});

  @override
  Widget build(BuildContext context) {
    final residentsStream = FirebaseFirestore.instance
        .collection('residents')
        .where('adminId', isEqualTo: adminId)
        .snapshots();

    final roomsStream = FirebaseFirestore.instance
        .collectionGroup('rooms')
        .where('adminId', isEqualTo: adminId)
        .snapshots();

    final bedsStream = FirebaseFirestore.instance
        .collectionGroup('beds')
        .snapshots();

    final complaintsStream = FirebaseFirestore.instance
        .collection('complaints')
        .where('adminId', isEqualTo: adminId)
        .snapshots();

    final paymentsStream = FirebaseFirestore.instance
        .collection('payments')
        .where('adminId', isEqualTo: adminId)
        .snapshots();

    return StreamBuilder<QuerySnapshot>(
      stream: roomsStream,
      builder: (context, roomsSnap) {
        final roomsDocs = roomsSnap.data?.docs ?? [];
        final totalBeds = _totalBedsFromRooms(roomsDocs);

        return StreamBuilder<QuerySnapshot>(
          stream: bedsStream,
          builder: (context, bedsSnap) {
            // Count occupied beds by checking beds subcollection
            // Filter beds that belong to rooms owned by this admin
            final bedsDocs = bedsSnap.data?.docs ?? [];
            int occupiedBeds = 0;

            // Get room IDs for this admin
            final adminRoomIds = roomsDocs.map((r) => r.id).toSet();

            // Count occupied beds in admin's rooms
            for (final bedDoc in bedsDocs) {
              final bedData = bedDoc.data() as Map<String, dynamic>;
              // Extract roomId from bed document path
              // Path format: hostels/{hostelId}/floors/{floorId}/rooms/{roomId}/beds/{bedId}
              final pathParts = bedDoc.reference.path.split('/');
              final roomIndex = pathParts.indexOf('rooms');
              if (roomIndex != -1 && roomIndex + 1 < pathParts.length) {
                final roomId = pathParts[roomIndex + 1];
                // Check if bed is in admin's room and is occupied
                if (adminRoomIds.contains(roomId) &&
                    bedData['isOccupied'] == true) {
                  occupiedBeds++;
                }
              }
            }

            return StreamBuilder<QuerySnapshot>(
              stream: residentsStream,
              builder: (context, residentsSnap) {
                final residentsDocs = residentsSnap.data?.docs ?? [];
                final totalResidents = residentsDocs.length;
                final allocatedResidents = residentsDocs
                    .where((r) => r['isAllocated'] == true)
                    .length;

                // Use allocated residents count as fallback if bed count is 0
                final actualOccupiedBeds = occupiedBeds > 0
                    ? occupiedBeds
                    : allocatedResidents;
                final availableBeds = (totalBeds - actualOccupiedBeds).clamp(
                  0,
                  totalBeds,
                );
                final occupancyPercentage = totalBeds > 0
                    ? (actualOccupiedBeds / totalBeds * 100).round()
                    : 0;

                return StreamBuilder<QuerySnapshot>(
                  stream: complaintsStream,
                  builder: (context, complaintsSnap) {
                    final complaintsDocs = complaintsSnap.data?.docs ?? [];
                    final openComplaints = complaintsDocs.where((c) {
                      final status =
                          c['status']?.toString().toLowerCase() ?? '';
                      return status != 'resolved' && status != 'closed';
                    }).length;

                    return StreamBuilder<QuerySnapshot>(
                      stream: paymentsStream,
                      builder: (context, paymentsSnap) {
                        final pendingFromPayments = _sumPendingFeesFromPayments(
                          paymentsSnap.data?.docs ?? [],
                        );
                        final pendingFromResidents =
                            _sumPendingFeesFromResidents(residentsDocs);

                        final pendingTotal = pendingFromPayments > 0
                            ? pendingFromPayments
                            : pendingFromResidents;

                        return GridView.count(
                          crossAxisCount: 4,
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          crossAxisSpacing: 16,
                          mainAxisSpacing: 16,
                          childAspectRatio: 1.2,
                          children: [
                            _StatCard(
                              icon: Icons.people,
                              title: 'Total Residents',
                              value: totalResidents.toString(),
                              change: '+$allocatedResidents allocated',
                              changeType: 'positive',
                            ),
                            _StatCard(
                              icon: Icons.bed,
                              title: 'Available Beds',
                              value: availableBeds.toString(),
                              showProgress: true,
                              progressValue: totalBeds == 0
                                  ? 0
                                  : actualOccupiedBeds / totalBeds,
                              change: 'Out of $totalBeds total',
                              occupancy: occupancyPercentage,
                            ),
                            _StatCard(
                              icon: Icons.currency_rupee,
                              title: 'Pending Fees',
                              value: '₹$pendingTotal',
                              change:
                                  '${paymentsSnap.data?.docs.where((p) {
                                        final status = p['status']?.toString().toLowerCase() ?? '';
                                        final isPaid = p['isPaid'] == true;
                                        return status == 'pending' || (!isPaid && status != 'paid');
                                      }).length ?? 0} residents',
                              changeType: 'warning',
                            ),
                            _StatCard(
                              icon: Icons.notifications_active,
                              title: 'Open Complaints',
                              value: openComplaints.toString(),
                              change:
                                  '${complaintsDocs.where((c) {
                                    final createdAt = c['createdAt'] as Timestamp?;
                                    if (createdAt == null) return false;
                                    final now = DateTime.now();
                                    final created = createdAt.toDate();
                                    return now.difference(created).inDays == 0;
                                  }).length} new today',
                              changeType: 'warning',
                            ),
                          ],
                        );
                      },
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final bool showProgress;
  final double? progressValue;
  final String? change;
  final String? changeType; // 'positive', 'warning', 'neutral'
  final int? occupancy;

  const _StatCard({
    required this.icon,
    required this.title,
    required this.value,
    this.showProgress = false,
    this.progressValue,
    this.change,
    this.changeType,
    this.occupancy,
  });

  @override
  Widget build(BuildContext context) {
    // Icon colors based on card type
    Color iconColor;
    Color iconBgColor;
    if (title == 'Total Residents') {
      iconColor = const Color(0xFF6366F1);
      iconBgColor = const Color(0xFF6366F1).withOpacity(0.1);
    } else if (title == 'Available Beds') {
      iconColor = const Color(0xFF14B8A6);
      iconBgColor = const Color(0xFF14B8A6).withOpacity(0.1);
    } else if (title == 'Pending Fees') {
      iconColor = const Color(0xFFF97316);
      iconBgColor = const Color(0xFFF97316).withOpacity(0.1);
    } else {
      iconColor = const Color(0xFFEF4444);
      iconBgColor = const Color(0xFFEF4444).withOpacity(0.1);
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Theme.of(context).dividerColor, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).textTheme.bodySmall?.color,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      value,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (change != null) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Text(
                            change!,
                            style: TextStyle(
                              fontSize: 11,
                              color: changeType == 'positive'
                                  ? const Color(0xFF14B8A6)
                                  : changeType == 'warning'
                                  ? const Color(0xFFF97316)
                                  : Theme.of(
                                      context,
                                    ).textTheme.bodySmall?.color,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: iconBgColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: iconColor, size: 24),
              ),
            ],
          ),
          if (showProgress && progressValue != null) ...[
            const SizedBox(height: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Occupancy Rate',
                      style: TextStyle(
                        fontSize: 11,
                        color: Theme.of(context).textTheme.bodySmall?.color,
                      ),
                    ),
                    if (occupancy != null)
                      Text(
                        '$occupancy%',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).textTheme.bodyMedium?.color,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: progressValue!,
                    minHeight: 6,
                    backgroundColor: Theme.of(context).dividerColor,
                    valueColor: AlwaysStoppedAnimation(iconColor),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/* =========================================================
   QUICK ACTIONS
========================================================= */

Widget _QuickActions(BuildContext context, String adminId) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text('Quick Actions', style: AppTextStyles.h3),
      const SizedBox(height: 14),
      Wrap(
        spacing: 16,
        runSpacing: 16,
        children: [
          _ActionButton(
            label: 'Manage Hostels',
            icon: Icons.business,
            gradient: const [Color(0xFF7C3AED), Color(0xFFEC4899)],
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => HostelManagementScreen(adminId: adminId),
                ),
              );
            },
          ),
          _ActionButton(
            label: 'Add Resident',
            icon: Icons.person_add,
            gradient: const [Color(0xFF6D28D9), Color(0xFFA855F7)],
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => AddResidentScreen(adminId: adminId),
                ),
              );
            },
          ),
          _ActionButton(
            label: 'Allocate Room',
            icon: Icons.meeting_room,
            gradient: [Color(0xFF0D9488), Color(0xFF06B6D4)],
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => AllocateResidentScreen(adminId: adminId),
                ),
              );
            },
          ),
          const _ActionButton(
            label: 'Send Notice',
            icon: Icons.notifications,
            gradient: [Color(0xFF9333EA), Color(0xFFEC4899)],
          ),
        ],
      ),
    ],
  );
}

class _ActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final List<Color> gradient;
  final VoidCallback? onTap;

  const _ActionButton({
    required this.label,
    required this.icon,
    required this.gradient,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: 260,
        height: 56,
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: gradient),
          borderRadius: BorderRadius.circular(16),
          boxShadow: _shadow,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white),
            const SizedBox(width: 10),
            Text(
              label,
              style: AppTextStyles.bodyMedium.copyWith(color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }
}

/* =========================================================
   MAIN GRID
========================================================= */

class _MainGrid extends StatelessWidget {
  final String adminId;
  const _MainGrid({required this.adminId});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(flex: 2, child: _RecentResidents(adminId: adminId)),
            const SizedBox(width: 16),
            Expanded(child: _OccupancyByFloor(adminId: adminId)),
          ],
        ),
        const SizedBox(height: 24),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: _RecentActivity(adminId: adminId)),
            const SizedBox(width: 16),
            Expanded(child: _UpcomingDues(adminId: adminId)),
          ],
        ),
      ],
    );
  }
}

/* =========================================================
   RECENT RESIDENTS
========================================================= */

class _RecentResidents extends StatelessWidget {
  final String adminId;
  const _RecentResidents({required this.adminId});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: _card(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Recent Residents', style: AppTextStyles.h3),
          const SizedBox(height: 18),
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('residents')
                .where('adminId', isEqualTo: adminId)
                .where('isAllocated', isEqualTo: true)
                .limit(5)
                .snapshots(),

            builder: (context, snapshot) {
              if (snapshot.hasError) {
                debugPrint('RECENT_RESIDENTS_ERROR: ${snapshot.error}');
                return const Text(
                  'Recent residents will appear once data is available.',
                  style: AppTextStyles.bodySmall,
                );
              }
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              if (snapshot.data!.docs.isEmpty) {
                return const Text(
                  'No allocated residents yet',
                  style: AppTextStyles.bodySmall,
                );
              }

              return _residentList(context, snapshot.data!.docs);
            },
          ),
        ],
      ),
    );
  }
}

/* =========================================================
   OCCUPANCY BY FLOOR
========================================================= */

class _OccupancyByFloor extends StatelessWidget {
  final String adminId;
  const _OccupancyByFloor({required this.adminId});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: _card(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.trending_up,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 8),
              const Text('Occupancy by Floor', style: AppTextStyles.h3),
            ],
          ),
          const SizedBox(height: 18),
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collectionGroup('floors')
                .where('adminId', isEqualTo: adminId)
                .snapshots(),
            builder: (context, floorsSnap) {
              if (!floorsSnap.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final floors = floorsSnap.data!.docs;
              if (floors.isEmpty) {
                return const Text(
                  'No floors available',
                  style: AppTextStyles.bodySmall,
                );
              }

              return Column(
                children: floors.map((floor) {
                  final floorId = floor.id;
                  final floorName =
                      (floor['floorName'] ?? '').toString().trim().isEmpty
                      ? 'Floor ${floor['floorIndex'] ?? ''}'
                      : floor['floorName'].toString();
                  final hostelId = floor['hostelId']?.toString();

                  if (hostelId == null || floorId.isEmpty) {
                    return _emptyFloorRow(context, floorName);
                  }

                  final roomsStream = FirebaseFirestore.instance
                      .collection('hostels')
                      .doc(hostelId)
                      .collection('floors')
                      .doc(floorId)
                      .collection('rooms')
                      .snapshots();

                  return StreamBuilder<QuerySnapshot>(
                    stream: roomsStream,
                    builder: (context, roomsSnap) {
                      if (!roomsSnap.hasData) {
                        return _emptyFloorRow(context, floorName);
                      }

                      int totalBeds = 0;
                      int occupiedBeds = 0;
                      for (final room in roomsSnap.data!.docs) {
                        final data = room.data() as Map<String, dynamic>;
                        final tb = data['totalBeds'];
                        final ob = data['occupiedBeds'];
                        totalBeds += tb is int
                            ? tb
                            : (tb is String ? int.tryParse(tb) ?? 0 : 0);
                        occupiedBeds += ob is int
                            ? ob
                            : (ob is String ? int.tryParse(ob) ?? 0 : 0);
                      }

                      if (totalBeds == 0) {
                        return _emptyFloorRow(context, floorName);
                      }

                      final percentage = (occupiedBeds / totalBeds).clamp(
                        0.0,
                        1.0,
                      );

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(floorName, style: AppTextStyles.bodySmall),
                                Text(
                                  '$occupiedBeds/$totalBeds',
                                  style: AppTextStyles.bodySmall,
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: percentage,
                                minHeight: 6,
                                backgroundColor: Theme.of(context).dividerColor,
                                valueColor: AlwaysStoppedAnimation(
                                  Theme.of(context).colorScheme.primary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}

/* =========================================================
   RECENT ACTIVITY
========================================================= */

class _RecentActivity extends StatelessWidget {
  final String adminId;
  const _RecentActivity({required this.adminId});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: _card(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.notifications_active, color: const Color(0xFFF97316)),
              const SizedBox(width: 8),
              const Text('Recent Activity', style: AppTextStyles.h3),
            ],
          ),
          const SizedBox(height: 18),
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('payments')
                .where('adminId', isEqualTo: adminId)
                .orderBy('paidAt', descending: true)
                .limit(5)
                .snapshots(),
            builder: (context, paymentsSnap) {
              return StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('complaints')
                    .where('adminId', isEqualTo: adminId)
                    .orderBy('createdAt', descending: true)
                    .limit(5)
                    .snapshots(),
                builder: (context, complaintsSnap) {
                  final activities = <Map<String, dynamic>>[];

                  // Add payment activities
                  if (paymentsSnap.hasData) {
                    for (final doc in paymentsSnap.data!.docs) {
                      final data = doc.data() as Map<String, dynamic>;
                      final residentName = data['residentName'] ?? 'Resident';
                      final amount = data['amount'] ?? data['monthlyFee'] ?? 0;
                      final paidAt = data['paidAt'] as Timestamp?;
                      if (paidAt != null) {
                        activities.add({
                          'type': 'payment',
                          'resident': residentName,
                          'action': 'Paid monthly fees of ₹$amount',
                          'time': paidAt,
                        });
                      }
                    }
                  }

                  // Add complaint activities
                  if (complaintsSnap.hasData) {
                    for (final doc in complaintsSnap.data!.docs) {
                      final data = doc.data() as Map<String, dynamic>;
                      final residentName = data['residentName'] ?? 'Resident';
                      final title = data['title'] ?? 'Complaint';
                      final createdAt = data['createdAt'] as Timestamp?;
                      if (createdAt != null) {
                        activities.add({
                          'type': 'complaint',
                          'resident': residentName,
                          'action': 'Raised complaint: $title',
                          'time': createdAt,
                        });
                      }
                    }
                  }

                  // Sort by time
                  activities.sort((a, b) {
                    final aTime = a['time'] as Timestamp;
                    final bTime = b['time'] as Timestamp;
                    return bTime.compareTo(aTime);
                  });

                  // Take top 5
                  final recentActivities = activities.take(5).toList();

                  if (recentActivities.isEmpty) {
                    return const Text(
                      'No recent activity',
                      style: AppTextStyles.bodySmall,
                    );
                  }

                  return Column(
                    children: recentActivities.map((activity) {
                      final time = activity['time'] as Timestamp;
                      final now = DateTime.now();
                      final diff = now.difference(time.toDate());
                      String timeStr;
                      if (diff.inHours < 1) {
                        timeStr = '${diff.inMinutes} minutes ago';
                      } else if (diff.inDays < 1) {
                        timeStr = '${diff.inHours} hours ago';
                      } else {
                        timeStr =
                            '${diff.inDays} day${diff.inDays > 1 ? 's' : ''} ago';
                      }

                      final type = activity['type'] as String;
                      Color dotColor;
                      if (type == 'payment') {
                        dotColor = const Color(0xFF14B8A6);
                      } else if (type == 'complaint') {
                        dotColor = const Color(0xFFF97316);
                      } else {
                        dotColor = Theme.of(context).colorScheme.primary;
                      }

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              margin: const EdgeInsets.only(top: 8),
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: dotColor,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    activity['resident'],
                                    style: AppTextStyles.bodyMedium,
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    activity['action'],
                                    style: AppTextStyles.bodySmall,
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    timeStr,
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Theme.of(
                                        context,
                                      ).textTheme.bodySmall?.color,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }
}

/* =========================================================
   UPCOMING DUES
========================================================= */

class _UpcomingDues extends StatelessWidget {
  final String adminId;
  const _UpcomingDues({required this.adminId});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: _card(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Upcoming Fee Dues', style: AppTextStyles.h3),
          const SizedBox(height: 18),
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('residents')
                .where('adminId', isEqualTo: adminId)
                .where('isAllocated', isEqualTo: true)
                .snapshots(),
            builder: (context, residentSnap) {
              if (residentSnap.hasError) {
                return Text(
                  'Unable to load residents: ${residentSnap.error}',
                  style: AppTextStyles.bodySmall,
                );
              }

              if (!residentSnap.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final residents = residentSnap.data!.docs;
              if (residents.isEmpty) {
                return const Text(
                  'No allocated residents yet',
                  style: AppTextStyles.bodySmall,
                );
              }

              return StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('payments')
                    .where('adminId', isEqualTo: adminId)
                    .snapshots(),
                builder: (context, paymentsSnap) {
                  if (paymentsSnap.hasError) {
                    return Text(
                      'Unable to load dues: ${paymentsSnap.error}',
                      style: AppTextStyles.bodySmall,
                    );
                  }

                  if (!paymentsSnap.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final dueEntries = _calculateDueEntries(
                    residents,
                    paymentsSnap.data!.docs,
                  );

                  if (dueEntries.isEmpty) {
                    return const Text(
                      'Nothing due in the next cycle',
                      style: AppTextStyles.bodySmall,
                    );
                  }

                  return Column(
                    children: dueEntries.map((entry) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    entry.name,
                                    style: AppTextStyles.bodyMedium,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    entry.roomLabel,
                                    style: AppTextStyles.bodySmall,
                                  ),
                                ],
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  '₹${entry.amount}',
                                  style: AppTextStyles.bodyMedium,
                                ),
                                const SizedBox(height: 4),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: entry.badgeColor.withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    entry.statusLabel,
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: entry.badgeColor,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Due ${DateFormat('MMM dd').format(entry.dueDate)}',
                                  style: AppTextStyles.caption.copyWith(
                                    color: Theme.of(
                                      context,
                                    ).textTheme.bodySmall?.color,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }
}

/* =========================================================
   HELPERS
========================================================= */

BoxDecoration _card(BuildContext context) => BoxDecoration(
  color: Theme.of(context).cardColor,
  borderRadius: BorderRadius.circular(18),
  boxShadow: _shadow,
);

const _shadow = [
  BoxShadow(color: Color(0x11000000), blurRadius: 20, offset: Offset(0, 8)),
];

int _sumPendingFeesFromResidents(List<QueryDocumentSnapshot> docs) {
  int total = 0;
  for (final doc in docs) {
    final data = doc.data() as Map<String, dynamic>;
    final status = data['status']?.toString().toLowerCase() ?? '';
    if (status == 'pending') {
      final monthlyFee = data['monthlyFee'];
      if (monthlyFee is int) {
        total += monthlyFee;
      } else if (monthlyFee is String) {
        total += int.tryParse(monthlyFee) ?? 0;
      }
    }
  }
  return total;
}

int _sumPendingFeesFromPayments(List<QueryDocumentSnapshot> docs) {
  int total = 0;
  for (final doc in docs) {
    final data = doc.data() as Map<String, dynamic>;
    final status =
        data['status']?.toString().toLowerCase() ??
        data['paymentStatus']?.toString().toLowerCase() ??
        '';
    final isPending = status == 'pending' || data['isPaid'] == false;
    if (isPending) {
      total += _extractPaymentAmount(data);
    }
  }
  return total;
}

int _extractPaymentAmount(Map<String, dynamic> data) {
  final candidates = [data['pendingAmount'], data['dueAmount'], data['amount']];
  for (final value in candidates) {
    if (value is int) return value;
    if (value is String) {
      final parsed = int.tryParse(value);
      if (parsed != null) return parsed;
    }
  }
  return 0;
}

int _totalBedsFromRooms(List<QueryDocumentSnapshot> docs) {
  int total = 0;
  for (final doc in docs) {
    final data = doc.data() as Map<String, dynamic>;
    final beds = data['totalBeds'];
    if (beds is int) total += beds;
    if (beds is String) total += int.tryParse(beds) ?? 0;
  }
  return total;
}

Widget _emptyFloorRow(BuildContext context, String floorName) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(floorName, style: AppTextStyles.bodySmall),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: 0,
            minHeight: 6,
            backgroundColor: Theme.of(context).dividerColor,
            valueColor: AlwaysStoppedAnimation(
              Theme.of(context).colorScheme.primary,
            ),
          ),
        ),
      ],
    ),
  );
}

class _DueEntry {
  final String name;
  final String roomLabel;
  final DateTime dueDate;
  final int amount;
  final String statusLabel;
  final Color badgeColor;

  _DueEntry({
    required this.name,
    required this.roomLabel,
    required this.dueDate,
    required this.amount,
    required this.statusLabel,
    required this.badgeColor,
  });
}

List<_DueEntry> _calculateDueEntries(
  List<QueryDocumentSnapshot> residents,
  List<QueryDocumentSnapshot> payments,
) {
  final paymentsByResident = <String, List<QueryDocumentSnapshot>>{};
  for (final payment in payments) {
    final data = payment.data() as Map<String, dynamic>;
    final residentId = (data['residentId'] ?? data['residentDocId'])
        ?.toString();
    if (residentId == null) continue;
    paymentsByResident.putIfAbsent(residentId, () => []).add(payment);
  }

  final now = DateTime.now();
  final entries = <_DueEntry>[];

  for (final resident in residents) {
    final data = resident.data() as Map<String, dynamic>;
    final name = data['fullName'] ?? data['name'] ?? 'Resident';
    final allocation = data['allocationDetails'] as Map<String, dynamic>?;
    final allocationDate =
        _timestampToDate(allocation?['allocatedAt']) ??
        _timestampToDate(data['allocatedAt']);
    if (allocationDate == null) continue;

    DateTime baseDue = allocationDate;
    final residentPayments = paymentsByResident[resident.id] ?? [];
    final latestPaid = _latestPaidDueDate(residentPayments);
    if (latestPaid != null) {
      baseDue = latestPaid;
    }

    DateTime nextDue = _addMonths(baseDue, 1);
    int safety = 0;
    while (!nextDue.isAfter(now) && safety < 24) {
      nextDue = _addMonths(nextDue, 1);
      safety++;
    }

    final difference = nextDue.difference(now).inDays;
    String label;
    Color color;
    if (difference < 0) {
      label = 'Overdue';
      color = Colors.red;
    } else if (difference <= 3) {
      label = 'Reminder';
      color = Colors.orange;
    } else {
      label = 'Upcoming';
      color = Colors.grey.shade600;
    }

    final roomNumber =
        allocation?['roomNumber'] ??
        data['roomNumber'] ??
        data['roomId'] ??
        '-';
    final bedNumber =
        allocation?['bedNumber'] ?? data['bedId'] ?? data['bedSlot'] ?? '';
    final roomLabel = bedNumber.isNotEmpty
        ? 'Room $roomNumber • Bed $bedNumber'
        : 'Room $roomNumber';

    final amount = _extractPaymentAmount(data);
    entries.add(
      _DueEntry(
        name: name,
        roomLabel: roomLabel,
        dueDate: nextDue,
        amount: amount,
        statusLabel: label,
        badgeColor: color,
      ),
    );
  }

  entries.sort((a, b) => a.dueDate.compareTo(b.dueDate));
  return entries.take(5).toList();
}

DateTime? _latestPaidDueDate(List<QueryDocumentSnapshot> payments) {
  DateTime? candidate;
  for (final payment in payments) {
    final data = payment.data() as Map<String, dynamic>;
    final status = data['status']?.toString().toLowerCase() ?? '';
    final isPaid = status == 'paid' || data['isPaid'] == true;
    if (!isPaid) continue;

    final due = _timestampToDate(data['dueDate']);
    final paid = _timestampToDate(data['paidAt']);
    final candidateDate = due ?? paid;
    if (candidateDate == null) continue;
    if (candidate == null || candidateDate.isAfter(candidate)) {
      candidate = candidateDate;
    }
  }
  return candidate;
}

DateTime _addMonths(DateTime original, int months) {
  final newMonthOffset = original.month - 1 + months;
  final newYear = original.year + newMonthOffset ~/ 12;
  final newMonth = newMonthOffset % 12 + 1;
  final lastDayOfMonth = DateTime(newYear, newMonth + 1, 0).day;
  final day = original.day <= lastDayOfMonth ? original.day : lastDayOfMonth;
  return DateTime(
    newYear,
    newMonth,
    day,
    original.hour,
    original.minute,
    original.second,
    original.millisecond,
    original.microsecond,
  );
}

DateTime? _timestampToDate(dynamic value) {
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  return null;
}

Widget _residentList(BuildContext context, List<QueryDocumentSnapshot> docs) {
  return Column(
    children: docs.map((doc) {
      final data = doc.data() as Map<String, dynamic>;
      final name = data['fullName'] ?? '';
      final allocation = data['allocationDetails'] as Map<String, dynamic>?;
      final room = allocation?['roomNumber'] ?? data['roomId'] ?? '-';
      final bed = allocation?['bedNumber'] ?? data['bedSlot'] ?? '-';
      final allocatedAt =
          data['allocatedAt'] as Timestamp? ??
          allocation?['allocatedAt'] as Timestamp?;

      final date = allocatedAt != null
          ? DateFormat('MMM dd, yyyy').format(allocatedAt.toDate())
          : '';

      final initials = name.isNotEmpty
          ? name.trim().split(' ').take(2).map((e) => e[0]).join()
          : '?';

      return Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: Theme.of(
                context,
              ).colorScheme.primary.withOpacity(0.15),
              child: Text(
                initials,
                style: TextStyle(color: Theme.of(context).colorScheme.primary),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: AppTextStyles.bodyMedium),
                  Text('Room $room • Bed $bed', style: AppTextStyles.bodySmall),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'Allocated',
                    style: AppTextStyles.label.copyWith(color: Colors.white),
                  ),
                ),
                const SizedBox(height: 4),
                Text(date, style: AppTextStyles.caption),
              ],
            ),
          ],
        ),
      );
    }).toList(),
  );
}
