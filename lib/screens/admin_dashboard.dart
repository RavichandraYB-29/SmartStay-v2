import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../main.dart';
import 'login_screen.dart';
import 'hostel_management_screen.dart';
import 'add_resident_screen.dart';
import 'allocate_resident_screen.dart';
import '../utils/admin_design_system.dart';
import '../widgets/admin_widgets.dart';

// ─────────────────────────────────────────────────────────────
// ADMIN DASHBOARD
// ─────────────────────────────────────────────────────────────

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  bool _checkedRole = false;
  String? _adminId;
  bool _fabOpen = false;

  @override
  void initState() {
    super.initState();
    _ensureAdminRole();
  }

  Future<void> _ensureAdminRole() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) { _signOutToLogin(); return; }
    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      if (doc.data()?['role'] != 'admin') { _showRoleBlocked(); return; }
      setState(() { _adminId = user.uid; _checkedRole = true; });
    } catch (_) { _signOutToLogin(); }
  }

  void _showRoleBlocked() {
    FirebaseAuth.instance.signOut();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Access Denied'),
        content: const Text('This account is not authorized to access the admin dashboard.'),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK'))],
      ),
    ).then((_) => _signOutToLogin());
  }

  void _signOutToLogin() {
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const LoginScreen()), (_) => false);
  }

  @override
  Widget build(BuildContext context) {
    if (!_checkedRole || _adminId == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final adminId = _adminId!;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final app = context.findAncestorWidgetOfExactType<SmartStayApp>();
    final date = DateFormat('EEE, MMM dd').format(DateTime.now());

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F1117) : const Color(0xFFF4F6FB),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 100),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Header ──────────────────────────────
                _DashboardHeader(date: date, app: app, isDark: isDark),
                const SizedBox(height: 28),
                // ── Welcome banner ───────────────────────
                _WelcomeBanner(adminId: adminId),
                const SizedBox(height: 28),
                // ── 6-card KPI grid ──────────────────────
                _StatsSection(adminId: adminId),
                const SizedBox(height: 28),
                // ── Recent Activity & Upcoming Fee Dues ──
                LayoutBuilder(builder: (ctx, c) {
                  final wide = c.maxWidth >= 900;
                  if (wide) {
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: _RecentActivityCard(adminId: adminId)),
                        const SizedBox(width: 20),
                        Expanded(child: _UpcomingFeeDuesCard(adminId: adminId)),
                      ],
                    );
                  }
                  return Column(children: [
                    _RecentActivityCard(adminId: adminId),
                    const SizedBox(height: 20),
                    _UpcomingFeeDuesCard(adminId: adminId),
                  ]);
                }),
                const SizedBox(height: 28),
                // ── Complaints Management ────────────────
                _ComplaintsCard(adminId: adminId),
              ],
            ),
          ),
          // ── Expandable FAB ───────────────────────────
          _ExpandableFab(
            adminId: adminId,
            isOpen: _fabOpen,
            onToggle: () => setState(() => _fabOpen = !_fabOpen),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// HEADER
// ─────────────────────────────────────────────
class _DashboardHeader extends StatelessWidget {
  final String date;
  final SmartStayApp? app;
  final bool isDark;
  const _DashboardHeader({required this.date, required this.app, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 46, height: 46,
          decoration: BoxDecoration(gradient: AdminGradients.primary, borderRadius: BorderRadius.circular(14)),
          child: const Icon(Icons.apartment_rounded, color: Colors.white, size: 22),
        ),
        const SizedBox(width: 12),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('SmartStay', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, fontFamily: 'Inter', letterSpacing: -0.4)),
          Text('Admin Dashboard', style: TextStyle(fontSize: 12, color: isDark ? const Color(0xFF8B9CB6) : AdminColors.textMuted, fontFamily: 'Inter')),
        ]),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E2130) : Colors.white,
            borderRadius: BorderRadius.circular(10),
            boxShadow: AdminShadows.card,
          ),
          child: Row(children: [
            const Icon(Icons.calendar_today_outlined, size: 14, color: AdminColors.textSecondary),
            const SizedBox(width: 6),
            Text(date, style: const TextStyle(fontSize: 12, fontFamily: 'Inter', color: AdminColors.textSecondary)),
          ]),
        ),
        const SizedBox(width: 10),
        _HeaderIconBtn(icon: isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded, onTap: () => app?.themeController.toggleTheme()),
        const SizedBox(width: 6),
        _HeaderIconBtn(icon: Icons.logout_rounded, onTap: () async {
          await FirebaseAuth.instance.signOut();
          if (!context.mounted) return;
          Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const LoginScreen()), (_) => false);
        }),
      ],
    );
  }
}

class _HeaderIconBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _HeaderIconBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: 38, height: 38,
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E2130) : Colors.white,
          borderRadius: BorderRadius.circular(10),
          boxShadow: AdminShadows.card,
        ),
        child: Icon(icon, size: 18, color: AdminColors.textSecondary),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// WELCOME BANNER
// ─────────────────────────────────────────────
class _WelcomeBanner extends StatelessWidget {
  final String adminId;
  const _WelcomeBanner({required this.adminId});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance.collection('users').doc(adminId).get(),
      builder: (ctx, snap) {
        final name = (snap.data?.data() as Map<String, dynamic>?)?['name']?.toString() ?? 'Admin';
        return Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            gradient: AdminGradients.primary,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [BoxShadow(color: AdminColors.primary.withOpacity(0.3), blurRadius: 24, offset: const Offset(0, 10))],
          ),
          child: Row(children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Good ${_greeting()}, $name! 👋', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, fontFamily: 'Inter', color: Colors.white, letterSpacing: -0.3)),
              const SizedBox(height: 6),
              const Text("Here's your hostel overview for today.", style: TextStyle(fontSize: 13, color: Colors.white70, fontFamily: 'Inter')),
            ])),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), borderRadius: BorderRadius.circular(16)),
              child: const Icon(Icons.dashboard_rounded, color: Colors.white, size: 28),
            ),
          ]),
        );
      },
    );
  }

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Morning';
    if (h < 17) return 'Afternoon';
    return 'Evening';
  }
}

// ─────────────────────────────────────────────
// 6-CARD KPI STATS
// ─────────────────────────────────────────────
class _StatsSection extends StatefulWidget {
  final String adminId;
  const _StatsSection({required this.adminId});

  @override
  State<_StatsSection> createState() => _StatsSectionState();
}

class _StatsSectionState extends State<_StatsSection> {
  int _totalBeds = 0;
  int _availBeds = 0;
  String _lastHostelKey = '';
  bool _fetching = false;

  /// Fetches all PG docs from hostels owned by this admin.
  Future<void> _fetchPgAggregates(List<QueryDocumentSnapshot> hostels) async {
    _fetching = true;
    int tb = 0, ab = 0;
    for (final hostel in hostels) {
      try {
        final pgSnap = await hostel.reference.collection('pgs').get();
        for (final pg in pgSnap.docs) {
          final d = pg.data();
          tb += _toInt(d['totalBeds']);
          ab += _toInt(d['availableBeds']);
        }
      } catch (_) {}
    }
    _fetching = false;
    if (mounted) {
      setState(() {
        _totalBeds = tb;
        _availBeds = ab;
      });
    }
  }

  int _toInt(dynamic v) => v is int ? v : int.tryParse('$v') ?? 0;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('residents').where('adminId', isEqualTo: widget.adminId).snapshots(),
      builder: (ctx, residentsSnap) => StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('hostels').where('ownerId', isEqualTo: widget.adminId).snapshots(),
        builder: (ctx, hostelsSnap) => StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance.collection('payments').where('adminId', isEqualTo: widget.adminId).snapshots(),
          builder: (ctx, paymentsSnap) {
            final residents = residentsSnap.data?.docs ?? [];
            final hostels = hostelsSnap.data?.docs ?? [];
            final payments = paymentsSnap.data?.docs ?? [];

            // Re-fetch PG aggregates whenever hostels change
            if (hostelsSnap.hasData) {
              final key = hostels.map((h) => h.id).join(',');
              if (key != _lastHostelKey && !_fetching) {
                _lastHostelKey = key;
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  _fetchPgAggregates(hostels);
                });
              }
            }

            final totalResidents = residents.length;
            final allocated = residents.where((d) => (d.data() as Map)['isAllocated'] == true).length;

            final totalBeds = _totalBeds;
            final availBeds = _availBeds;
            final occupied = (totalBeds - availBeds).clamp(0, totalBeds);

            int pending = 0;
            for (final p in payments) {
              final d = p.data() as Map<String, dynamic>;
              if ((d['status'] ?? '').toString().toLowerCase() == 'pending') {
                pending += _toInt(d['amount'] ?? d['monthlyFee']);
              }
            }

            final cards = [
              _StatData('Total Hostels', hostels.length.toString(), Icons.apartment_rounded, AdminColors.hostelsIcon, AdminColors.hostelsBg, '${hostels.length} properties'),
              _StatData('Total Residents', totalResidents.toString(), Icons.people_alt_rounded, AdminColors.residentsIcon, AdminColors.residentsBg, '$allocated allocated'),
              _StatData('Total Beds', totalBeds.toString(), Icons.bed_rounded, AdminColors.roomsIcon, AdminColors.roomsBg, '$occupied occupied'),
              _StatData('Vacant Beds', availBeds.toString(), Icons.check_circle_rounded, AdminColors.bedsIcon, AdminColors.bedsBg, 'Available now'),
              _StatData('Pending Dues', pending > 0 ? '₹$pending' : '₹0', Icons.currency_rupee_rounded, AdminColors.pendingIcon, AdminColors.pendingBg, 'Outstanding'),
              _StatData('Occupancy', totalBeds > 0 ? '${(occupied / totalBeds * 100).toInt()}%' : '0%', Icons.donut_large_rounded, AdminColors.floorsIcon, AdminColors.floorsBg, '$occupied/$totalBeds filled'),
            ];

            return LayoutBuilder(builder: (ctx, c) {
              final cols = c.maxWidth >= 900 ? 3 : c.maxWidth >= 560 ? 2 : 1;
              return GridView.count(
                crossAxisCount: cols,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 1.65,
                children: cards.map((s) => AdminStatCard(
                  title: s.title, value: s.value, icon: s.icon,
                  iconColor: s.iconColor, bgColor: s.bgColor, subtitle: s.subtitle,
                )).toList(),
              );
            });
          },
        ),
      ),
    );
  }
}

class _StatData {
  final String title, value, subtitle;
  final IconData icon;
  final Color iconColor, bgColor;
  const _StatData(this.title, this.value, this.icon, this.iconColor, this.bgColor, this.subtitle);
}


// ─────────────────────────────────────────────
// RECENT ACTIVITY CARD
// ─────────────────────────────────────────────
class _RecentActivityCard extends StatelessWidget {
  final String adminId;
  const _RecentActivityCard({required this.adminId});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 20, offset: const Offset(0, 8))],
        border: Border.all(color: const Color(0xFFF1F5F9)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: const Color(0xFFFEF2F2), borderRadius: BorderRadius.circular(10)),
              child: const Icon(Icons.notifications_active_rounded, size: 20, color: Color(0xFFEF4444)),
            ),
            const SizedBox(width: 12),
            const Text('Recent Activity', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, fontFamily: 'Inter', letterSpacing: -0.3)),
          ]),
          const SizedBox(height: 20),
          _ActivityStream(adminId: adminId),
        ],
      ),
    );
  }
}

class _ActivityStream extends StatelessWidget {
  final String adminId;
  const _ActivityStream({required this.adminId});

  @override
  Widget build(BuildContext context) {
    // Merge payments, complaints, residents, and notices into a single timeline
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('payments').where('adminId', isEqualTo: adminId).orderBy('paidAt', descending: true).limit(3).snapshots(),
      builder: (ctx, paymentsSnap) => StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('complaints').where('adminId', isEqualTo: adminId).orderBy('createdAt', descending: true).limit(3).snapshots(),
        builder: (ctx, complaintsSnap) => StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance.collection('residents').where('adminId', isEqualTo: adminId).orderBy('createdAt', descending: true).limit(3).snapshots(),
          builder: (ctx, residentsSnap) => StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('notices').where('createdByAdminId', isEqualTo: adminId).orderBy('createdAt', descending: true).limit(2).snapshots(),
            builder: (ctx, noticesSnap) {
              final List<_ActivityItem> items = [];

              // Payments
              for (final doc in (paymentsSnap.data?.docs ?? [])) {
                final d = doc.data() as Map<String, dynamic>;
                final name = (d['residentName'] ?? d['fullName'] ?? 'Resident').toString();
                final amount = d['amount'] ?? d['monthlyFee'] ?? 0;
                final ts = d['paidAt'] as Timestamp?;
                if (ts != null) {
                  items.add(_ActivityItem(
                    name: name,
                    description: 'Paid monthly fees of ₹$amount',
                    time: ts.toDate(),
                    color: const Color(0xFF22C55E),
                  ));
                }
              }

              // Complaints
              for (final doc in (complaintsSnap.data?.docs ?? [])) {
                final d = doc.data() as Map<String, dynamic>;
                final name = (d['residentName'] ?? d['fullName'] ?? 'Resident').toString();
                final title = (d['title'] ?? d['subject'] ?? 'Issue reported').toString();
                final ts = d['createdAt'] as Timestamp?;
                if (ts != null) {
                  items.add(_ActivityItem(
                    name: name,
                    description: 'Raised complaint: $title',
                    time: ts.toDate(),
                    color: const Color(0xFFF97316),
                  ));
                }
              }

              // Residents (check-ins)
              for (final doc in (residentsSnap.data?.docs ?? [])) {
                final d = doc.data() as Map<String, dynamic>;
                final name = (d['fullName'] ?? d['name'] ?? 'Resident').toString();
                final isAlloc = d['isAllocated'] == true;
                final bedId = (d['allocationDetails'] as Map?)?['bedId'] ?? d['bedId'];
                final ts = d['createdAt'] as Timestamp?;
                if (ts != null) {
                  items.add(_ActivityItem(
                    name: name,
                    description: isAlloc ? 'Joined the hostel${bedId != null ? ' – Bed $bedId' : ''}' : 'Invited to join',
                    time: ts.toDate(),
                    color: const Color(0xFF3B82F6),
                  ));
                }
              }

              // Notices
              for (final doc in (noticesSnap.data?.docs ?? [])) {
                final d = doc.data() as Map<String, dynamic>;
                final title = (d['title'] ?? 'Notice').toString();
                final ts = d['createdAt'] as Timestamp?;
                if (ts != null) {
                  items.add(_ActivityItem(
                    name: 'Admin',
                    description: 'Posted: $title',
                    time: ts.toDate(),
                    color: const Color(0xFF8B5CF6),
                  ));
                }
              }

              items.sort((a, b) => b.time.compareTo(a.time));
              final display = items.take(5).toList();

              if (display.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(child: Text('No recent activity', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13, fontFamily: 'Inter'))),
                );
              }

              return Column(children: display.map((item) => _ActivityTile(item: item)).toList());
            },
          ),
        ),
      ),
    );
  }
}

class _ActivityItem {
  final String name, description;
  final DateTime time;
  final Color color;
  const _ActivityItem({required this.name, required this.description, required this.time, required this.color});
}

class _ActivityTile extends StatelessWidget {
  final _ActivityItem item;
  const _ActivityTile({required this.item});

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours} hour${diff.inHours == 1 ? '' : 's'} ago';
    if (diff.inDays < 7) return '${diff.inDays} day${diff.inDays == 1 ? '' : 's'} ago';
    return DateFormat('MMM dd').format(dt);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 10, height: 10,
            margin: const EdgeInsets.only(top: 5),
            decoration: BoxDecoration(shape: BoxShape.circle, color: item.color),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, fontFamily: 'Inter', letterSpacing: -0.1)),
                const SizedBox(height: 2),
                Text(item.description, style: const TextStyle(fontSize: 13, color: Color(0xFF64748B), fontFamily: 'Inter')),
                const SizedBox(height: 4),
                Text(_timeAgo(item.time), style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8), fontFamily: 'Inter')),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// UPCOMING FEE DUES CARD
// ─────────────────────────────────────────────
class _UpcomingFeeDuesCard extends StatelessWidget {
  final String adminId;
  const _UpcomingFeeDuesCard({required this.adminId});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 20, offset: const Offset(0, 8))],
        border: Border.all(color: const Color(0xFFF1F5F9)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: const Color(0xFFFFF7ED), borderRadius: BorderRadius.circular(10)),
              child: const Icon(Icons.currency_rupee_rounded, size: 20, color: Color(0xFFF97316)),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text('Upcoming Fee Dues', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, fontFamily: 'Inter', letterSpacing: -0.3)),
            ),
            Icon(Icons.visibility_rounded, size: 18, color: const Color(0xFF94A3B8)),
          ]),
          const SizedBox(height: 20),
          _FeeDuesList(adminId: adminId),
        ],
      ),
    );
  }
}

class _FeeDuesList extends StatefulWidget {
  final String adminId;
  const _FeeDuesList({required this.adminId});

  @override
  State<_FeeDuesList> createState() => _FeeDuesListState();
}

class _FeeDuesListState extends State<_FeeDuesList> {
  List<_DueItem> _resolvedItems = [];
  bool _resolved = false;
  String _lastKey = '';

  Future<void> _resolveRoomData(List<QueryDocumentSnapshot> docs) async {
    final now = DateTime.now();
    final List<_DueItem> items = [];

    for (final doc in docs) {
      final d = doc.data() as Map<String, dynamic>;
      final name = (d['fullName'] ?? d['name'] ?? 'Resident').toString();
      final alloc = d['allocationDetails'] as Map<String, dynamic>?;

      final hostelId = alloc?['hostelId'] ?? d['hostelId'];
      final pgId = alloc?['pgId'] ?? d['pgId'];
      final floorId = alloc?['floorId'] ?? d['floorId'];
      final roomId = alloc?['roomId'] ?? d['roomId'];

      String roomNumber = '—';
      int rent = 0;

      // Fetch room doc if we have the full path
      if (hostelId != null && pgId != null && floorId != null && roomId != null) {
        try {
          final roomSnap = await FirebaseFirestore.instance
              .collection('hostels').doc(hostelId)
              .collection('pgs').doc(pgId)
              .collection('floors').doc(floorId)
              .collection('rooms').doc(roomId)
              .get();
          if (roomSnap.exists) {
            final rd = roomSnap.data()!;
            roomNumber = (rd['roomNumber'] ?? rd['name'] ?? roomId).toString();
            rent = _toInt(rd['rentPerBed'] ?? rd['monthlyFee'] ?? 0);
          }
        } catch (_) {}
      }

      // Calculate next due date
      final allocTs = alloc?['allocatedAt'] as Timestamp?;
      int daysLeft = 30;
      if (allocTs != null) {
        final allocDate = allocTs.toDate();
        final dueDay = allocDate.day.clamp(1, 28);
        var nextDue = DateTime(now.year, now.month, dueDay);
        if (nextDue.isBefore(now) || nextDue.isAtSameMomentAs(now)) {
          nextDue = DateTime(now.year, now.month + 1, dueDay);
        }
        daysLeft = nextDue.difference(now).inDays;
      }

      items.add(_DueItem(name: name, roomNumber: roomNumber, rent: rent, daysLeft: daysLeft, residentId: doc.id));
    }

    items.sort((a, b) => a.daysLeft.compareTo(b.daysLeft));

    if (mounted) {
      setState(() {
        _resolvedItems = items.take(5).toList();
        _resolved = true;
      });
    }
  }

  int _toInt(dynamic v) => v is int ? v : int.tryParse('$v') ?? 0;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('residents')
          .where('adminId', isEqualTo: widget.adminId)
          .where('isAllocated', isEqualTo: true)
          .snapshots(),
      builder: (ctx, snap) {
        if (!snap.hasData) return const ShimmerBox(width: double.infinity, height: 120);
        final docs = snap.data!.docs;
        if (docs.isEmpty) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(child: Text('No allocated residents', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13, fontFamily: 'Inter'))),
          );
        }

        // Re-resolve when residents change
        final key = docs.map((d) => d.id).join(',');
        if (key != _lastKey) {
          _lastKey = key;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _resolveRoomData(docs);
          });
        }

        if (!_resolved) return const ShimmerBox(width: double.infinity, height: 120);

        return Column(children: _resolvedItems.map((item) => _FeeDueTile(item: item)).toList());
      },
    );
  }
}

class _DueItem {
  final String name, roomNumber, residentId;
  int rent;
  final int daysLeft;
  _DueItem({required this.name, required this.roomNumber, required this.rent, required this.daysLeft, required this.residentId});
}

class _FeeDueTile extends StatelessWidget {
  final _DueItem item;
  const _FeeDueTile({required this.item});

  @override
  Widget build(BuildContext context) {
    Color badgeColor;
    Color badgeBg;
    if (item.daysLeft <= 3) {
      badgeColor = const Color(0xFFDC2626);
      badgeBg = const Color(0xFFFEE2E2);
    } else if (item.daysLeft <= 5) {
      badgeColor = const Color(0xFFF97316);
      badgeBg = const Color(0xFFFFF7ED);
    } else {
      badgeColor = const Color(0xFF64748B);
      badgeBg = const Color(0xFFF1F5F9);
    }

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xFFF1F5F9)))),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, fontFamily: 'Inter', letterSpacing: -0.1)),
                const SizedBox(height: 2),
                Text('Room ${item.roomNumber}', style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8), fontFamily: 'Inter')),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(item.rent > 0 ? '₹${item.rent}' : '—', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15, fontFamily: 'Inter')),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: badgeBg, borderRadius: BorderRadius.circular(6)),
                child: Text(
                  '${item.daysLeft} day${item.daysLeft == 1 ? '' : 's'} left',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: badgeColor, fontFamily: 'Inter'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// COMPLAINTS MANAGEMENT
// ─────────────────────────────────────────────
class _ComplaintsCard extends StatelessWidget {
  final String adminId;
  const _ComplaintsCard({required this.adminId});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 20, offset: const Offset(0, 8))],
        border: Border.all(color: const Color(0xFFF1F5F9)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF7ED),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.report_problem_rounded, size: 20, color: Color(0xFFF97316)),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Resident Complaints',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  fontFamily: 'Inter',
                  letterSpacing: -0.3,
                ),
              ),
            ),
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('complaints')
                  .where('status', isEqualTo: 'pending')
                  .snapshots(),
              builder: (ctx, snap) {
                final count = snap.data?.docs.length ?? 0;
                if (count == 0) return const SizedBox.shrink();
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEF4444),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '$count pending',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      fontFamily: 'Inter',
                    ),
                  ),
                );
              },
            ),
          ]),
          const SizedBox(height: 20),
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('complaints')
                .snapshots(),
            builder: (ctx, snap) {
              if (snap.hasError) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Center(
                    child: Text(
                      'Error loading complaints: ${snap.error}',
                      style: const TextStyle(color: Color(0xFFEF4444), fontSize: 12, fontFamily: 'Inter'),
                      textAlign: TextAlign.center,
                    ),
                  ),
                );
              }
              if (!snap.hasData) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                );
              }
              final allDocs = snap.data!.docs;
              // Sort by createdAt descending on client side
              allDocs.sort((a, b) {
                final aTs = (a.data() as Map<String, dynamic>)['createdAt'] as Timestamp?;
                final bTs = (b.data() as Map<String, dynamic>)['createdAt'] as Timestamp?;
                if (aTs == null && bTs == null) return 0;
                if (aTs == null) return 1;
                if (bTs == null) return -1;
                return bTs.compareTo(aTs);
              });
              // Filter out resolved/closed complaints
              final activeDocs = allDocs.where((doc) {
                final s = ((doc.data() as Map<String, dynamic>)['status'] ?? 'pending').toString().toLowerCase();
                return s != 'resolved' && s != 'closed';
              }).take(10).toList();
              final docs = activeDocs;
              if (docs.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(
                    child: Text(
                      'No complaints yet',
                      style: TextStyle(
                        color: Color(0xFF94A3B8),
                        fontSize: 13,
                        fontFamily: 'Inter',
                      ),
                    ),
                  ),
                );
              }
              return Column(
                children: docs.map((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  return _ComplaintTile(
                    docId: doc.id,
                    data: data,
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

class _ComplaintTile extends StatelessWidget {
  final String docId;
  final Map<String, dynamic> data;

  const _ComplaintTile({required this.docId, required this.data});

  Color _priorityColor(String priority) {
    switch (priority.toLowerCase()) {
      case 'high':
        return const Color(0xFFEF4444);
      case 'medium':
        return const Color(0xFFF59E0B);
      default:
        return const Color(0xFF64748B);
    }
  }

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'resolved':
      case 'closed':
        return const Color(0xFF10B981);
      case 'in progress':
        return const Color(0xFF3B82F6);
      default:
        return const Color(0xFFF59E0B);
    }
  }

  String _statusLabel(String status) {
    switch (status.toLowerCase()) {
      case 'resolved':
        return 'Resolved';
      case 'closed':
        return 'Closed';
      case 'in progress':
        return 'In Progress';
      default:
        return 'Pending';
    }
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return DateFormat('MMM dd').format(dt);
  }

  @override
  Widget build(BuildContext context) {
    final title = (data['title'] ?? 'Untitled').toString();
    final category = (data['category'] ?? '').toString();
    final priority = (data['priority'] ?? 'low').toString();
    final status = (data['status'] ?? 'pending').toString();
    final roomNumber = data['roomNumber']?.toString();
    final createdAt = data['createdAt'] as Timestamp?;

    return InkWell(
      onTap: () => _showComplaintDetail(context, docId, data),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 4),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: Color(0xFFF1F5F9))),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Priority indicator
            Container(
              width: 4,
              height: 48,
              margin: const EdgeInsets.only(right: 14),
              decoration: BoxDecoration(
                color: _priorityColor(priority),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                            fontFamily: 'Inter',
                            letterSpacing: -0.1,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: _statusColor(status).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          _statusLabel(status),
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: _statusColor(status),
                            fontFamily: 'Inter',
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      if (category.isNotEmpty) ...[
                        Icon(Icons.label_outline_rounded, size: 13, color: const Color(0xFF94A3B8)),
                        const SizedBox(width: 4),
                        Text(
                          category,
                          style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xFF94A3B8),
                            fontFamily: 'Inter',
                          ),
                        ),
                        const SizedBox(width: 12),
                      ],
                      if (roomNumber != null && roomNumber != '-') ...[
                        Icon(Icons.meeting_room_outlined, size: 13, color: const Color(0xFF94A3B8)),
                        const SizedBox(width: 4),
                        Text(
                          'Room $roomNumber',
                          style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xFF94A3B8),
                            fontFamily: 'Inter',
                          ),
                        ),
                        const SizedBox(width: 12),
                      ],
                      if (createdAt != null) ...[
                        Icon(Icons.access_time_rounded, size: 13, color: const Color(0xFF94A3B8)),
                        const SizedBox(width: 4),
                        Text(
                          _timeAgo(createdAt.toDate()),
                          style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xFF94A3B8),
                            fontFamily: 'Inter',
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: Color(0xFFCBD5E1), size: 20),
          ],
        ),
      ),
    );
  }
}

void _showComplaintDetail(BuildContext context, String docId, Map<String, dynamic> data) {
  final title = (data['title'] ?? 'Untitled').toString();
  final category = (data['category'] ?? '-').toString();
  final priority = (data['priority'] ?? 'low').toString();
  final status = (data['status'] ?? 'pending').toString();
  final description = (data['description'] ?? 'No description provided.').toString();
  final hostelName = data['hostelName']?.toString() ?? '-';
  final floorLabel = data['floorLabel']?.toString() ?? '-';
  final roomNumber = data['roomNumber']?.toString() ?? '-';
  final residentId = data['residentId']?.toString();
  final createdAt = data['createdAt'] as Timestamp?;

  const teal = Color(0xFF14B8A6);

  Color priorityColor(String p) {
    switch (p.toLowerCase()) {
      case 'high': return const Color(0xFFEF4444);
      case 'medium': return const Color(0xFFF59E0B);
      default: return const Color(0xFF64748B);
    }
  }

  Color statusColor(String s) {
    switch (s.toLowerCase()) {
      case 'resolved': case 'closed': return const Color(0xFF10B981);
      case 'in progress': return const Color(0xFF3B82F6);
      default: return const Color(0xFFF59E0B);
    }
  }

  showDialog(
    context: context,
    builder: (ctx) {
      return Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── Header ──
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [const Color(0xFF1E293B), const Color(0xFF334155)],
                    ),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(20),
                      topRight: Radius.circular(20),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.report_problem_rounded, color: Color(0xFFF59E0B), size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                                fontFamily: 'Inter',
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            if (createdAt != null)
                              Text(
                                DateFormat('MMM dd, yyyy • hh:mm a').format(createdAt.toDate()),
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Color(0xFF94A3B8),
                                  fontFamily: 'Inter',
                                ),
                              ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, color: Colors.white54),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                ),

                // ── Body ──
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Status + Priority badges
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                            decoration: BoxDecoration(
                              color: statusColor(status).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: statusColor(status).withOpacity(0.3)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 6, height: 6,
                                  decoration: BoxDecoration(
                                    color: statusColor(status),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  status.isEmpty ? 'Pending' : '${status[0].toUpperCase()}${status.substring(1)}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: statusColor(status),
                                    fontFamily: 'Inter',
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                            decoration: BoxDecoration(
                              color: priorityColor(priority).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: priorityColor(priority).withOpacity(0.3)),
                            ),
                            child: Text(
                              '${priority[0].toUpperCase()}${priority.substring(1)} Priority',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: priorityColor(priority),
                                fontFamily: 'Inter',
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // Category
                      Row(
                        children: [
                          const Icon(Icons.label_outline_rounded, size: 16, color: Color(0xFF64748B)),
                          const SizedBox(width: 8),
                          const Text('Category: ', style: TextStyle(fontSize: 13, color: Color(0xFF64748B), fontFamily: 'Inter')),
                          Text(
                            category,
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF1E293B), fontFamily: 'Inter'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Resident info
                      if (residentId != null)
                        FutureBuilder<DocumentSnapshot>(
                          future: FirebaseFirestore.instance.collection('residents').doc(residentId).get(),
                          builder: (ctx, snap) {
                            final name = (snap.data?.data() as Map<String, dynamic>?)?['fullName']?.toString() ?? 'Unknown';
                            return Row(
                              children: [
                                const Icon(Icons.person_rounded, size: 16, color: Color(0xFF64748B)),
                                const SizedBox(width: 8),
                                const Text('Resident: ', style: TextStyle(fontSize: 13, color: Color(0xFF64748B), fontFamily: 'Inter')),
                                Text(
                                  name,
                                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF1E293B), fontFamily: 'Inter'),
                                ),
                              ],
                            );
                          },
                        ),
                      const SizedBox(height: 16),

                      // Location
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFF1F5F9)),
                        ),
                        child: Row(
                          children: [
                            _detailChip(Icons.apartment_rounded, hostelName, const Color(0xFF6366F1)),
                            const SizedBox(width: 12),
                            _detailChip(Icons.layers_rounded, floorLabel, teal),
                            const SizedBox(width: 12),
                            _detailChip(Icons.meeting_room_outlined, 'Room $roomNumber', const Color(0xFFF59E0B)),
                          ],
                        ),
                      ),

                      const SizedBox(height: 20),

                      // Description
                      const Text(
                        'Description',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1E293B),
                          fontFamily: 'Inter',
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFF1F5F9)),
                        ),
                        child: Text(
                          description,
                          style: const TextStyle(
                            fontSize: 13,
                            color: Color(0xFF475569),
                            height: 1.5,
                            fontFamily: 'Inter',
                          ),
                        ),
                      ),

                      const SizedBox(height: 24),

                      // ── Action Buttons ──
                      const Text(
                        'Update Status',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1E293B),
                          fontFamily: 'Inter',
                        ),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _statusActionBtn(ctx, docId, 'pending', 'Pending', const Color(0xFFF59E0B), status),
                          _statusActionBtn(ctx, docId, 'in progress', 'In Progress', const Color(0xFF3B82F6), status),
                          _statusActionBtn(ctx, docId, 'resolved', 'Resolved', const Color(0xFF10B981), status),
                          _statusActionBtn(ctx, docId, 'closed', 'Closed', const Color(0xFF64748B), status),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

Widget _detailChip(IconData icon, String text, Color color) {
  return Expanded(
    child: Row(
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
              fontFamily: 'Inter',
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    ),
  );
}

Widget _statusActionBtn(BuildContext ctx, String docId, String newStatus, String label, Color color, String currentStatus) {
  final isActive = currentStatus.toLowerCase() == newStatus.toLowerCase();
  return Material(
    color: Colors.transparent,
    child: InkWell(
      onTap: isActive ? null : () async {
        try {
          await FirebaseFirestore.instance.collection('complaints').doc(docId).update({
            'status': newStatus,
            'updatedAt': FieldValue.serverTimestamp(),
          });
          if (ctx.mounted) {
            Navigator.pop(ctx);
            ScaffoldMessenger.of(ctx).showSnackBar(
              SnackBar(
                content: Text('Status updated to $label'),
                backgroundColor: color,
              ),
            );
          }
        } catch (e) {
          if (ctx.mounted) {
            ScaffoldMessenger.of(ctx).showSnackBar(
              SnackBar(content: Text('Failed: $e'), backgroundColor: const Color(0xFFEF4444)),
            );
          }
        }
      },
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? color : color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withOpacity(isActive ? 1 : 0.3)),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: isActive ? Colors.white : color,
            fontFamily: 'Inter',
          ),
        ),
      ),
    ),
  );
}

// ─────────────────────────────────────────────
// EXPANDABLE FAB
// ─────────────────────────────────────────────
class _ExpandableFab extends StatefulWidget {
  final String adminId;
  final bool isOpen;
  final VoidCallback onToggle;
  const _ExpandableFab({required this.adminId, required this.isOpen, required this.onToggle});

  @override
  State<_ExpandableFab> createState() => _ExpandableFabState();
}

class _ExpandableFabState extends State<_ExpandableFab> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 220));
  }

  @override
  void didUpdateWidget(_ExpandableFab old) {
    super.didUpdateWidget(old);
    widget.isOpen ? _ctrl.forward() : _ctrl.reverse();
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  void _navigate(Widget screen) {
    widget.onToggle();
    Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
  }

  @override
  Widget build(BuildContext context) {
    final actions = [
      _FabAction(label: 'Manage Hostels', icon: Icons.apartment_rounded, gradient: AdminGradients.primary, onTap: () => _navigate(HostelManagementScreen(adminId: widget.adminId))),
      _FabAction(label: 'Add Resident', icon: Icons.person_add_rounded, gradient: AdminGradients.indigo, onTap: () => _navigate(AddResidentScreen(adminId: widget.adminId))),
      _FabAction(label: 'Allocate Resident', icon: Icons.bed_rounded, gradient: AdminGradients.teal, onTap: () => _navigate(AllocateResidentScreen(adminId: widget.adminId))),
      _FabAction(label: 'Send Notice', icon: Icons.notifications_rounded, gradient: AdminGradients.pink, onTap: () => _navigate(const SendNoticeScreen())),
    ];

    return Positioned(
      right: 20, bottom: 24,
      child: Column(crossAxisAlignment: CrossAxisAlignment.end, mainAxisSize: MainAxisSize.min, children: [
        ...List.generate(actions.length, (i) {
          final delay = i * 0.1;
          return AnimatedBuilder(
            animation: _ctrl,
            builder: (_, child) {
              final v = (_ctrl.value - delay).clamp(0.0, 1.0);
              return Transform.translate(
                offset: Offset(0, 10 * (1 - v)),
                child: Opacity(opacity: v, child: child),
              );
            },
            child: Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _FabActionButton(action: actions[i]),
            ),
          );
        }).reversed.toList(),
        const SizedBox(height: 4),
        GestureDetector(
          onTap: widget.onToggle,
          child: Container(
            width: 56, height: 56,
            decoration: BoxDecoration(gradient: AdminGradients.primary, shape: BoxShape.circle, boxShadow: AdminShadows.fab),
            child: AnimatedBuilder(
              animation: _ctrl,
              builder: (_, __) => Transform.rotate(
                angle: _ctrl.value * 0.785,
                child: Icon(widget.isOpen ? Icons.close_rounded : Icons.add_rounded, color: Colors.white, size: 26),
              ),
            ),
          ),
        ),
      ]),
    );
  }
}

class _FabAction {
  final String label;
  final IconData icon;
  final LinearGradient gradient;
  final VoidCallback onTap;
  const _FabAction({required this.label, required this.icon, required this.gradient, required this.onTap});
}

class _FabActionButton extends StatelessWidget {
  final _FabAction action;
  const _FabActionButton({required this.action});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: action.onTap,
      child: Container(
        height: 46,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(gradient: action.gradient, borderRadius: BorderRadius.circular(24), boxShadow: AdminShadows.card),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(action.icon, color: Colors.white, size: 18),
          const SizedBox(width: 8),
          Text(action.label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13, fontFamily: 'Inter')),
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// SEND NOTICE SCREEN (preserved from original)
// ─────────────────────────────────────────────
class SendNoticeScreen extends StatefulWidget {
  final VoidCallback? onBack;
  const SendNoticeScreen({super.key, this.onBack});

  @override
  State<SendNoticeScreen> createState() => _SendNoticeScreenState();
}

class _PgOption {
  final String pgId, label, hostelId;
  const _PgOption({required this.pgId, required this.label, required this.hostelId});
}

class _SendNoticeScreenState extends State<SendNoticeScreen> {
  final _titleController = TextEditingController();
  final _messageController = TextEditingController();

  String _noticeType = '';
  String _scope = '';
  String _selectedPgId = '';
  String _selectedResidentId = '';
  String _selectedResidentLabel = '';
  late final Future<List<_PgOption>> _pgsFuture = _loadPgsForAdmin();

  final _noticeTypes = const [
    {'value': 'general', 'label': 'General', 'description': 'General announcements and updates', 'color': Color(0xFF4F46E5)},
    {'value': 'maintenance', 'label': 'Maintenance', 'description': 'Facility maintenance schedules', 'color': Color(0xFF7C3AED)},
    {'value': 'payment', 'label': 'Payment', 'description': 'Fee reminders and payment notices', 'color': Color(0xFFEA580C)},
    {'value': 'warning', 'label': 'Warning', 'description': 'Important warnings and alerts', 'color': Color(0xFFDC2626)},
  ];

  bool get _isFormValid =>
      _titleController.text.trim().isNotEmpty &&
      _messageController.text.trim().isNotEmpty &&
      _noticeType.isNotEmpty &&
      _scope.isNotEmpty &&
      !(_scope == 'PG' && _selectedPgId.isEmpty) &&
      !(_scope == 'RESIDENT' && _selectedResidentId.isEmpty);

  @override
  void dispose() { _titleController.dispose(); _messageController.dispose(); super.dispose(); }

  Future<void> _handleSubmit() async {
    if (!_isFormValid) return;
    final adminUid = FirebaseAuth.instance.currentUser?.uid;
    if (adminUid == null) return;
    try {
      final pgIds = <String>[];
      if (_scope == 'ALL') {
        final pgs = await _loadPgsForAdmin();
        pgIds.addAll(pgs.map((p) => p.pgId));
      } else if (_scope == 'PG') {
        pgIds.add(_selectedPgId);
      } else if (_scope == 'RESIDENT' && _selectedResidentId.isNotEmpty) {
        try {
          final rDoc = await FirebaseFirestore.instance.collection('residents').doc(_selectedResidentId).get();
          if (rDoc.exists) {
            final rData = rDoc.data()!;
            final alloc = rData['allocationDetails'];
            final pgId = alloc is Map ? alloc['pgId'] : rData['pgId'];
            if (pgId != null && pgId.toString().isNotEmpty) pgIds.add(pgId.toString());
          }
        } catch (e) { debugPrint('pgId fetch: $e'); }
      }
      final ref = FirebaseFirestore.instance.collection('notices').doc();
      await ref.set({
        'noticeId': ref.id,
        'title': _titleController.text.trim(),
        'message': _messageController.text.trim(),
        'noticeType': _noticeTypeLabel(_noticeType),
        'scope': _scope,
        'senderRole': 'admin',
        'createdByAdminId': adminUid,
        'hostelOwnerId': adminUid,
        'pgIds': pgIds,
        'residentIds': _scope == 'RESIDENT' ? [_selectedResidentId] : <String>[],
        'isActive': true,
        'createdAt': FieldValue.serverTimestamp(),
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Notice published successfully')));
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to publish notice')));
    }
  }

  String _noticeTypeLabel(String raw) {
    switch (raw.toLowerCase()) {
      case 'general': return 'General';
      case 'maintenance': return 'Maintenance';
      case 'payment': return 'Payment';
      case 'warning': return 'Warning';
      default: return raw;
    }
  }

  Future<List<_PgOption>> _loadPgsForAdmin() async {
    final adminUid = FirebaseAuth.instance.currentUser?.uid;
    if (adminUid == null) return [];
    final byAdmin = await FirebaseFirestore.instance.collection('hostels').where('adminId', isEqualTo: adminUid).get();
    final byOwner = await FirebaseFirestore.instance.collection('hostels').where('ownerId', isEqualTo: adminUid).get();
    final hostels = <String, QueryDocumentSnapshot>{};
    for (final d in byAdmin.docs) hostels[d.id] = d;
    for (final d in byOwner.docs) hostels[d.id] = d;
    final pgs = <_PgOption>[];
    for (final entry in hostels.entries) {
      final hData = entry.value.data() as Map<String, dynamic>;
      final hName = (hData['name'] ?? 'Hostel').toString();
      final pgSnap = await FirebaseFirestore.instance.collection('hostels').doc(entry.key).collection('pgs').get();
      for (final p in pgSnap.docs) {
        final pData = p.data();
        pgs.add(_PgOption(pgId: p.id, hostelId: entry.key, label: '${(pData['name'] ?? pData['pgName'] ?? 'PG')} • $hName'));
      }
    }
    pgs.sort((a, b) => a.label.compareTo(b.label));
    return pgs;
  }

  void _handleCancel() {
    if (widget.onBack != null) { widget.onBack!(); return; }
    Navigator.maybePop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FB),
      body: SafeArea(child: Column(children: [
        AdminPageHeader(
          title: 'Send Notice',
          subtitle: 'Dashboard → Communication → Send Notice',
          icon: Icons.notifications_rounded,
          iconGradient: AdminGradients.indigo,
          onBack: _handleCancel,
        ),
        Expanded(child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(children: [
            AdminSectionCard(
              title: 'Notice Details', icon: Icons.description_rounded,
              headerGradient: AdminGradients.headerLight, iconColor: AdminColors.primary,
              child: Column(children: [
                AdminTextField(label: 'Notice Title *', hint: 'e.g., Holiday Announcement', controller: _titleController, onChanged: (_) => setState(() {})),
                const SizedBox(height: 16),
                AdminTextField(label: 'Notice Description *', hint: 'Enter your notice message here...', controller: _messageController, maxLines: 5, onChanged: (_) => setState(() {})),
              ]),
            ),
            const SizedBox(height: 16),
            AdminSectionCard(
              title: 'Notice Type', icon: Icons.local_offer_rounded,
              headerGradient: AdminGradients.headerPurple, iconColor: AdminColors.primary,
              child: Wrap(
                spacing: 12, runSpacing: 12,
                children: _noticeTypes.map((t) {
                  final isSelected = _noticeType == t['value'];
                  final color = t['color'] as Color;
                  return GestureDetector(
                    onTap: () => setState(() => _noticeType = t['value'] as String),
                    child: Container(
                      width: 200, padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: isSelected ? color : const Color(0xFFE5E7EB), width: isSelected ? 2 : 1),
                        color: isSelected ? color.withOpacity(0.08) : Colors.white,
                      ),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Row(children: [
                          Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
                          const SizedBox(width: 8),
                          Text(t['label'] as String, style: TextStyle(fontWeight: FontWeight.w600, color: isSelected ? color : AdminColors.textPrimary, fontFamily: 'Inter')),
                        ]),
                        const SizedBox(height: 6),
                        Text(t['description'] as String, style: const TextStyle(fontSize: 12, color: AdminColors.textSecondary, fontFamily: 'Inter')),
                      ]),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 16),
            AdminSectionCard(
              title: 'Audience Selection', icon: Icons.people_rounded,
              headerGradient: AdminGradients.headerTeal, iconColor: AdminColors.secondary,
              child: Column(children: [
                for (final s in [('ALL', 'All Residents', 'Send to every resident'), ('PG', 'Specific PG', 'Send to one PG'), ('RESIDENT', 'Specific Resident', 'Send to one person')])
                  RadioListTile<String>(
                    value: s.$1, groupValue: _scope,
                    onChanged: (v) => setState(() { _scope = v ?? ''; _selectedPgId = ''; _selectedResidentId = ''; _selectedResidentLabel = ''; }),
                    title: Text(s.$2, style: const TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w500)),
                    subtitle: Text(s.$3, style: const TextStyle(fontSize: 12, fontFamily: 'Inter')),
                    contentPadding: EdgeInsets.zero,
                  ),
                if (_scope == 'PG') ...[
                  const SizedBox(height: 8),
                  FutureBuilder<List<_PgOption>>(
                    future: _pgsFuture,
                    builder: (_, snap) => DropdownButtonFormField<String>(
                      value: _selectedPgId.isEmpty ? null : _selectedPgId,
                      decoration: InputDecoration(border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)), hintText: 'Select PG', filled: true, fillColor: const Color(0xFFF8F9FC)),
                      items: (snap.data ?? []).map((pg) => DropdownMenuItem(value: pg.pgId, child: Text(pg.label))).toList(),
                      onChanged: (v) => setState(() => _selectedPgId = v ?? ''),
                    ),
                  ),
                ],
                if (_scope == 'RESIDENT') ...[
                  const SizedBox(height: 8),
                  StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance.collection('residents').where('adminId', isEqualTo: FirebaseAuth.instance.currentUser?.uid).snapshots(),
                    builder: (_, snap) => DropdownButtonFormField<String>(
                      value: _selectedResidentId.isEmpty ? null : _selectedResidentId,
                      decoration: InputDecoration(border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)), hintText: 'Select resident', filled: true, fillColor: const Color(0xFFF8F9FC)),
                      items: (snap.data?.docs ?? []).map((doc) {
                        final d = doc.data() as Map<String, dynamic>;
                        final label = (d['name'] ?? d['fullName'] ?? d['email'] ?? 'Resident').toString();
                        return DropdownMenuItem(value: doc.id, child: Text(label));
                      }).toList(),
                      onChanged: (v) {
                        final docs = snap.data?.docs ?? [];
                        final sel = docs.where((d) => d.id == v).toList();
                        String lbl = '';
                        if (sel.isNotEmpty) {
                          final d = sel.first.data() as Map<String, dynamic>;
                          lbl = (d['name'] ?? d['fullName'] ?? d['email'] ?? '').toString();
                        }
                        setState(() { _selectedResidentId = v ?? ''; _selectedResidentLabel = lbl; });
                      },
                    ),
                  ),
                ],
              ]),
            ),
            const SizedBox(height: 24),
            Row(children: [
              Expanded(child: OutlinedButton.icon(onPressed: _handleCancel, icon: const Icon(Icons.close), label: const Text('Cancel'),
                style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))))),
              const SizedBox(width: 16),
              Expanded(child: ElevatedButton.icon(
                onPressed: _isFormValid ? _handleSubmit : null,
                icon: const Icon(Icons.send_rounded), label: const Text('Publish Notice'),
                style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16), backgroundColor: AdminColors.primary, foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
              )),
            ]),
          ]),
        )),
      ])),
    );
  }
}
