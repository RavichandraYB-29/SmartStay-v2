import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../main.dart';
import 'hostel_management_screen.dart';
import 'add_resident_screen.dart';
import '../theme/app_text_styles.dart';

class AdminDashboard extends StatelessWidget {
  const AdminDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    final date = DateFormat('MMM dd, yyyy').format(DateTime.now());
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return const Scaffold(body: Center(child: Text('User not logged in')));
    }

    final adminId = user.uid;

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
            const _StatsRow(),
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
  const _StatsRow();

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 16,
      runSpacing: 16,
      children: const [
        _StatCard(icon: Icons.people, title: 'Total Residents', value: '124'),
        _StatCard(
          icon: Icons.bed,
          title: 'Available Beds',
          value: '18',
          showProgress: true,
        ),
        _StatCard(
          icon: Icons.currency_rupee,
          title: 'Pending Fees',
          value: '₹45,000',
        ),
        _StatCard(
          icon: Icons.notifications_active,
          title: 'Open Complaints',
          value: '5',
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final bool showProgress;

  const _StatCard({
    required this.icon,
    required this.title,
    required this.value,
    this.showProgress = false,
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
                value: 0.88,
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
        const Expanded(flex: 4, child: _UpcomingDues()),
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
                .orderBy('createdAt', descending: true)
                .limit(4)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Text(
                  'Failed to load residents: ${snapshot.error}',
                  style: AppTextStyles.bodySmall,
                );
              }
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              if (snapshot.data!.docs.isEmpty) {
                return FutureBuilder<QuerySnapshot>(
                  future: FirebaseFirestore.instance
                      .collection('residents')
                      .where('ownerId', isEqualTo: adminId)
                      .orderBy('createdAt', descending: true)
                      .limit(4)
                      .get(),
                  builder: (context, legacySnap) {
                    if (legacySnap.hasError) {
                      return Text(
                        'Failed to load residents: ${legacySnap.error}',
                        style: AppTextStyles.bodySmall,
                      );
                    }
                    if (!legacySnap.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (legacySnap.data!.docs.isEmpty) {
                      return const Text(
                        'No residents added yet',
                        style: AppTextStyles.bodySmall,
                      );
                    }
                    return _residentList(context, legacySnap.data!.docs);
                  },
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
  const _UpcomingDues();

  @override
  Widget build(BuildContext context) {
    final dues = [
      ('Vikram Singh', '201A', '₹5,500', '2 days left', true),
      ('Anjali Desai', '102B', '₹5,500', '3 days left', true),
      ('Karan Mehta', '305C', '₹5,500', '5 days left', false),
      ('Riya Kapoor', '204A', '₹5,500', '7 days left', false),
    ];

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: _card(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Upcoming Fee Dues', style: AppTextStyles.h3),
          const SizedBox(height: 18),
          ...dues.map(
            (d) => Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(d.$1, style: AppTextStyles.bodyMedium),
                        Text('Room ${d.$2}', style: AppTextStyles.bodySmall),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(d.$3, style: AppTextStyles.bodyMedium),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: d.$5
                              ? const Color(0xFFEF4444)
                              : Theme.of(context).dividerColor,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          d.$4,
                          style: AppTextStyles.caption.copyWith(
                            color: d.$5
                                ? Colors.white
                                : Theme.of(context).textTheme.bodyMedium!.color,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
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

Widget _residentList(
  BuildContext context,
  List<QueryDocumentSnapshot> docs,
) {
  return Column(
    children: docs.map((doc) {
      final data = doc.data() as Map<String, dynamic>;
      final name = data['fullName'] ?? '';
      final room = data['roomId'] ?? '-';
      final status = data['status'] ?? 'pending';
      final createdAt = data['createdAt'] as Timestamp?;

      final date = createdAt != null
          ? DateFormat('MMM dd, yyyy').format(createdAt.toDate())
          : '';

      final initials = name.isNotEmpty
          ? name.trim().split(' ').take(2).map((e) => e[0]).join()
          : '?';

      final isActive = status == 'active';

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
                    'Room $room',
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
                    color: isActive
                        ? const Color(0xFF10B981)
                        : const Color(0xFFF59E0B),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    isActive ? 'Active' : 'Pending',
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
