import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../main.dart';
import 'login_screen.dart';
import 'hostel_management_screen.dart';
import 'add_resident_screen.dart';
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
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
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

    final complaintsStream = FirebaseFirestore.instance
        .collection('complaints')
        .where('adminId', isEqualTo: adminId)
        .snapshots();

    final paymentsStream = FirebaseFirestore.instance
        .collection('payments')
        .where('adminId', isEqualTo: adminId)
        .snapshots();

    return StreamBuilder<QuerySnapshot>(
      stream: residentsStream,
      builder: (context, residentsSnap) {
        final residentsDocs = residentsSnap.data?.docs ?? [];
        final totalResidents = residentsDocs.length;
        final pendingFees = _sumPendingFeesFromResidents(residentsDocs);

        return StreamBuilder<QuerySnapshot>(
          stream: roomsStream,
          builder: (context, roomsSnap) {
            final roomsDocs = roomsSnap.data?.docs ?? [];
            final bedStats = _bedStats(roomsDocs);
            final availableBeds = bedStats['available'] ?? 0;
            final totalBeds = bedStats['total'] ?? 0;
            final occupiedBeds = bedStats['occupied'] ?? 0;
            final progressValue = totalBeds > 0
                ? (occupiedBeds / totalBeds).clamp(0, 1).toDouble()
                : 0.0;

            return StreamBuilder<QuerySnapshot>(
              stream: complaintsStream,
              builder: (context, complaintsSnap) {
                final complaintsDocs = complaintsSnap.data?.docs ?? [];
                final openComplaints = complaintsDocs.length;

                return StreamBuilder<QuerySnapshot>(
                  stream: paymentsStream,
                  builder: (context, paymentsSnap) {
                    final paymentsDocs = paymentsSnap.data?.docs ?? [];
                    final pendingFromPayments =
                        _sumPendingFeesFromPayments(paymentsDocs);
                    final pendingTotal =
                        pendingFromPayments > 0 ? pendingFromPayments : pendingFees;

                    return Wrap(
                      spacing: 16,
                      runSpacing: 16,
                      children: [
                        _StatCard(
                          icon: Icons.people,
                          title: 'Total Residents',
                          value: totalResidents.toString(),
                        ),
                        _StatCard(
                          icon: Icons.bed,
                          title: 'Available Beds',
                          value: availableBeds.toString(),
                          showProgress: true,
                          progressValue: progressValue,
                        ),
                        _StatCard(
                          icon: Icons.currency_rupee,
                          title: 'Pending Fees',
                          value: '₹$pendingTotal',
                        ),
                        _StatCard(
                          icon: Icons.notifications_active,
                          title: 'Open Complaints',
                          value: openComplaints.toString(),
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
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final bool showProgress;
  final double? progressValue;

  const _StatCard({
    required this.icon,
    required this.title,
    required this.value,
    this.showProgress = false,
    this.progressValue,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return SizedBox(
      width: 260,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: _card(context),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              backgroundColor: cs.primary.withOpacity(0.15),
              child: Icon(icon, color: cs.primary),
            ),
            const SizedBox(height: 14),
            Text(value, style: AppTextStyles.h2),
            Text(title, style: AppTextStyles.bodySmall),
            if (showProgress) ...[
              const SizedBox(height: 10),
              LinearProgressIndicator(
                value: progressValue ?? 0,
                backgroundColor: Theme.of(context).dividerColor,
                valueColor: AlwaysStoppedAnimation(cs.primary),
              ),
            ],
          ],
        ),
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
          const _ActionButton(
            label: 'Allocate Room',
            icon: Icons.meeting_room,
            gradient: [Color(0xFF0D9488), Color(0xFF06B6D4)],
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
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(flex: 6, child: _RecentResidents(adminId: adminId)),
        const SizedBox(width: 24),
        Expanded(flex: 4, child: _UpcomingDues(adminId: adminId)),
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
                .orderBy('allocatedAt', descending: true)
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
                .collection('payments')
                .where('adminId', isEqualTo: adminId)
                .limit(5)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Text(
                  'Failed to load dues: ${snapshot.error}',
                  style: AppTextStyles.bodySmall,
                );
              }
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.data!.docs.isEmpty) {
                return const Text(
                  'No dues data available',
                  style: AppTextStyles.bodySmall,
                );
              }

              return Column(
                children: snapshot.data!.docs.map((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final name =
                      data['residentName'] ?? data['fullName'] ?? 'Resident';
                  final room = data['roomNumber'] ?? data['roomId'] ?? '-';
                  final amount = _extractPaymentAmount(data);
                  final status = data['status'] ?? data['paymentStatus'] ?? '';
                  final isCritical = status.toString().toLowerCase() == 'pending';

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(name, style: AppTextStyles.bodyMedium),
                              Text('Room $room', style: AppTextStyles.bodySmall),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text('₹$amount', style: AppTextStyles.bodyMedium),
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: isCritical
                                    ? const Color(0xFFEF4444)
                                    : Theme.of(context).dividerColor,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                status.toString().isEmpty ? '-' : status,
                                style: AppTextStyles.caption.copyWith(
                                  color: isCritical
                                      ? Colors.white
                                      : Theme.of(context)
                                          .textTheme
                                          .bodyMedium!
                                          .color,
                                ),
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
    final status = data['status']?.toString().toLowerCase() ??
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
  final candidates = [
    data['pendingAmount'],
    data['dueAmount'],
    data['amount'],
  ];
  for (final value in candidates) {
    if (value is int) return value;
    if (value is String) {
      final parsed = int.tryParse(value);
      if (parsed != null) return parsed;
    }
  }
  return 0;
}

Map<String, int> _bedStats(List<QueryDocumentSnapshot> docs) {
  int total = 0;
  int occupied = 0;
  for (final doc in docs) {
    final data = doc.data() as Map<String, dynamic>;
    final totalBeds = data['totalBeds'] ?? 0;
    final occupiedBeds = data['occupiedBeds'] ?? 0;
    final tb = totalBeds is int ? totalBeds : int.tryParse('$totalBeds') ?? 0;
    final ob = occupiedBeds is int ? occupiedBeds : int.tryParse('$occupiedBeds') ?? 0;
    total += tb;
    occupied += ob;
  }
  final available = (total - occupied).clamp(0, total);
  return {'total': total, 'occupied': occupied, 'available': available};
}

Widget _residentList(
  BuildContext context,
  List<QueryDocumentSnapshot> docs,
) {
  return Column(
    children: docs.map((doc) {
      final data = doc.data() as Map<String, dynamic>;
      final name = data['fullName'] ?? '';
      final allocation = data['allocationDetails'] as Map<String, dynamic>?;
      final room = allocation?['roomNumber'] ?? data['roomId'] ?? '-';
      final bed = allocation?['bedNumber'] ?? data['bedSlot'] ?? '-';
      final allocatedAt = data['allocatedAt'] as Timestamp? ??
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
                style: TextStyle(
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: AppTextStyles.bodyMedium),
                  Text(
                    'Room $room • Bed $bed',
                    style: AppTextStyles.bodySmall,
                  ),
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
                    style: AppTextStyles.label.copyWith(
                      color: Colors.white,
                    ),
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
