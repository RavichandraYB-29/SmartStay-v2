import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

import 'login_screen.dart';
import 'resident_notices_screen.dart';
import '../main.dart';
import '../theme/app_text_styles.dart';

class ResidentDashboard extends StatefulWidget {
  const ResidentDashboard({super.key});

  @override
  State<ResidentDashboard> createState() => _ResidentDashboardState();
}

class _ResidentDashboardState extends State<ResidentDashboard> {
  String? _residentId;

  Future<Map<String, dynamic>> _fetchAllocationMetadata(
    String? hostelId,
    String? pgId,
    String? floorId,
    String? roomId,
  ) async {
    if (hostelId == null || pgId == null || floorId == null || roomId == null) {
      return {};
    }

    final floorRef = FirebaseFirestore.instance
        .collection('hostels')
        .doc(hostelId)
        .collection('pgs')
        .doc(pgId)
        .collection('floors')
        .doc(floorId);
    final roomRef = floorRef.collection('rooms').doc(roomId);

    final results = await Future.wait([floorRef.get(), roomRef.get()]);
    final floorSnap = results[0];
    final roomSnap = results[1];

    final floorData = floorSnap.data();
    final roomData = roomSnap.data();

    final floorIndex = floorData?['floorIndex'];
    final floorLabel =
        floorData?['floorName']?.toString() ??
        floorData?['floorNumber']?.toString() ??
        (floorIndex != null ? 'Floor ${floorIndex.toString()}' : '');

    return {
      'floorLabel': floorLabel.isEmpty ? null : floorLabel,
      'sharingType': roomData?['sharingType']?.toString(),
      'roomNumber': roomData?['roomNumber']?.toString(),
    };
  }

  Future<void> _showBlockedDialog(String title, String message) async {
    if (!mounted) return;
    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  void initState() {
    super.initState();
  }

  void _logout() async {
    await FirebaseAuth.instance.signOut();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || !user.emailVerified) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showBlockedDialog(
          'Email Verification Required',
          'Please verify your email before accessing the dashboard.',
        );
        _logout();
      });
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('residents')
            .where('authUid', isEqualTo: user.uid)
            .limit(1)
            .snapshots()
            .map((snap) => snap.docs.isNotEmpty ? snap.docs.first : null)
            .where((doc) => doc != null)
            .map((doc) => doc!),
        builder: (context, residentSnap) {
          if (!residentSnap.hasData) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }

          final residentDoc = residentSnap.data!;
          final residentData = residentDoc.data() as Map<String, dynamic>;
          final isAllocated = residentData['isAllocated'] == true;
          final allocationDetails =
              residentData['allocationDetails'] as Map<String, dynamic>?;

          if (_residentId == null) {
            _residentId = residentDoc.id;
          }

          final hostelId =
              allocationDetails?['hostelId'] ?? residentData['hostelId'];
          final pgId = allocationDetails?['pgId'] ?? residentData['pgId'];
          final floorId =
              allocationDetails?['floorId'] ?? residentData['floorId'];
          final roomId = allocationDetails?['roomId'] ?? residentData['roomId'];

          final allocationMetaFuture =
              (hostelId != null &&
                  pgId != null &&
                  floorId != null &&
                  roomId != null)
              ? _fetchAllocationMetadata(hostelId, pgId, floorId, roomId)
              : Future.value(<String, dynamic>{});

          return FutureBuilder<Map<String, dynamic>>(
            future: allocationMetaFuture,
            builder: (context, metaSnap) {
              final allocationMeta = metaSnap.data ?? {};

              return SingleChildScrollView(
                child: Column(
                  children: [
                    _Header(
                      residentName:
                          residentData['name'] ??
                          residentData['fullName'] ??
                          'Resident',
                      onLogout: _logout,
                    ),
                    Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _WelcomeBanner(
                            residentName:
                                residentData['name'] ??
                                residentData['fullName'] ??
                                'Resident',
                            allocationDetails: allocationDetails,
                            allocationMeta: allocationMeta,
                            residentId: _residentId!,
                          ),
                          const SizedBox(height: 24),
                          if (isAllocated) ...[
                            _MainGrid(
                              residentId: _residentId!,
                              allocationDetails: allocationDetails,
                              residentData: residentData,
                              allocationMeta: allocationMeta,
                            ),
                            const SizedBox(height: 24),
                            _PaymentSection(residentId: _residentId!),
                            const SizedBox(height: 24),
                            _QuickActions(
                              residentId: _residentId!,
                              pgId: pgId?.toString(),
                            ),
                            const SizedBox(height: 24),
                            _BottomGrid(
                              residentId: _residentId!,
                              pgId: pgId?.toString(),
                            ),
                          ] else
                            _AllocationPendingCard(),
                        ],
                      ),
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
}

/* =========================================================
   HEADER
========================================================= */

class _Header extends StatelessWidget {
  final String residentName;
  final VoidCallback onLogout;

  const _Header({required this.residentName, required this.onLogout});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final app = context.findAncestorWidgetOfExactType<SmartStayApp>();
    final date = DateFormat('MMM dd, yyyy').format(DateTime.now());

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(
        color: Theme.of(context).appBarTheme.backgroundColor,
        border: Border(
          bottom: BorderSide(color: Theme.of(context).dividerColor, width: 1),
        ),
      ),
      child: Row(
        children: [
          Container(
            height: 44,
            width: 44,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF14B8A6), Color(0xFF06B6D4)],
              ),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.home, color: Colors.white),
          ),
          const SizedBox(width: 12),
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('SmartStay', style: AppTextStyles.h3),
              Text('Resident Portal', style: AppTextStyles.bodySmall),
            ],
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Theme.of(context).dividerColor),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.calendar_today_outlined,
                  size: 16,
                  color: Theme.of(context).iconTheme.color,
                ),
                const SizedBox(width: 8),
                Text(date, style: AppTextStyles.bodySmall),
              ],
            ),
          ),
          const SizedBox(width: 14),
          IconButton(
            tooltip: isDark ? 'Light Mode' : 'Dark Mode',
            icon: Icon(isDark ? Icons.light_mode : Icons.dark_mode),
            onPressed: () => app?.themeController.toggleTheme(),
          ),
          const SizedBox(width: 8),
          IconButton(
            tooltip: 'Logout',
            icon: const Icon(Icons.logout),
            onPressed: onLogout,
          ),
        ],
      ),
    );
  }
}

/* =========================================================
   WELCOME BANNER
========================================================= */

class _WelcomeBanner extends StatelessWidget {
  final String residentName;
  final Map<String, dynamic>? allocationDetails;
  final Map<String, dynamic>? allocationMeta;
  final String residentId;

  const _WelcomeBanner({
    required this.residentName,
    required this.allocationDetails,
    required this.allocationMeta,
    required this.residentId,
  });

  String _getInitials(String name) {
    final parts = name.trim().split(' ');
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return (parts[0][0] + parts[1][0]).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final metaRoomNumber = allocationMeta?['roomNumber']?.toString();
    final metaFloorLabel = allocationMeta?['floorLabel']?.toString();
    final roomNumber = metaRoomNumber?.isNotEmpty == true
        ? metaRoomNumber!
        : allocationDetails?['roomNumber'] ?? '-';
    final floorName = metaFloorLabel?.isNotEmpty == true
        ? metaFloorLabel!
        : allocationDetails?['floorName'] ?? '-';

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('payments')
          .where('residentId', isEqualTo: residentId)
          .orderBy('paidAt', descending: true)
          .limit(12)
          .snapshots(),
      builder: (context, paymentsSnap) {
        final payments = paymentsSnap.data?.docs ?? [];
        final onTimePayments = payments.length;

        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('complaints')
              .where('residentId', isEqualTo: residentId)
              .snapshots(),
          builder: (context, complaintsSnap) {
            final complaints = complaintsSnap.data?.docs ?? [];
            final totalComplaints = complaints.length;

            return Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF14B8A6), Color(0xFF06B6D4)],
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 32,
                        backgroundColor: Colors.white.withOpacity(0.3),
                        child: Text(
                          _getInitials(residentName),
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Welcome back, $residentName!',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Room $roomNumber • $floorName',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.9),
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: _StatMiniCard(
                          label: 'On-Time Pays',
                          value: onTimePayments.toString(),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _StatMiniCard(
                          label: 'Complaints',
                          value: totalComplaints.toString(),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _StatMiniCard(label: 'Status', value: 'Active'),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _StatMiniCard extends StatelessWidget {
  final String label;
  final String value;

  const _StatMiniCard({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withOpacity(0.9),
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/* =========================================================
   MAIN GRID
========================================================= */

class _MainGrid extends StatelessWidget {
  final String residentId;
  final Map<String, dynamic>? allocationDetails;
  final Map<String, dynamic> residentData;
  final Map<String, dynamic>? allocationMeta;

  const _MainGrid({
    required this.residentId,
    required this.allocationDetails,
    required this.residentData,
    required this.allocationMeta,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 900;
        if (isCompact) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _RoomDetailsCard(
                allocationDetails: allocationDetails,
                residentData: residentData,
                residentId: residentId,
                allocationMeta: allocationMeta,
              ),
              const SizedBox(height: 16),
              _QuickStatsCard(residentId: residentId),
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 2,
              child: _RoomDetailsCard(
                allocationDetails: allocationDetails,
                residentData: residentData,
                residentId: residentId,
                allocationMeta: allocationMeta,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(child: _QuickStatsCard(residentId: residentId)),
          ],
        );
      },
    );
  }
}

class _RoomDetailsCard extends StatelessWidget {
  final Map<String, dynamic>? allocationDetails;
  final Map<String, dynamic> residentData;
  final String residentId;
  final Map<String, dynamic>? allocationMeta;

  const _RoomDetailsCard({
    required this.allocationDetails,
    required this.residentData,
    required this.residentId,
    required this.allocationMeta,
  });

  @override
  Widget build(BuildContext context) {
    final hostelName = allocationDetails?['hostelName'] ?? '-';
    final metaFloorLabel = allocationMeta?['floorLabel']?.toString();
    final metaRoomNumber = allocationMeta?['roomNumber']?.toString();
    final metaSharingType = allocationMeta?['sharingType']?.toString();

    final floorName = metaFloorLabel?.isNotEmpty == true
        ? metaFloorLabel!
        : allocationDetails?['floorName'] ?? '-';
    final roomNumber = metaRoomNumber?.isNotEmpty == true
        ? metaRoomNumber!
        : allocationDetails?['roomNumber'] ?? '-';
    final bedNumber = allocationDetails?['bedNumber'] ?? '-';
    final sharingType = metaSharingType?.isNotEmpty == true
        ? metaSharingType!
        : residentData['sharingType'] ?? 'N/A';
    final allocatedAt = allocationDetails?['allocatedAt'] as Timestamp?;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Theme.of(context).dividerColor),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF14B8A6).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.bed, color: Color(0xFF14B8A6)),
                ),
                const SizedBox(width: 12),
                const Text(
                  'My Room Details',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: _InfoRow(label: 'Hostel Name', value: hostelName),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _InfoRow(label: 'Floor', value: floorName),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _InfoRow(label: 'Room Number', value: roomNumber),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _InfoRow(label: 'Bed Number', value: bedNumber),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _InfoRow(label: 'Sharing Type', value: sharingType),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _InfoRow(
                    label: 'Resident Since',
                    value: allocatedAt != null
                        ? DateFormat(
                            'MMM dd, yyyy',
                          ).format(allocatedAt.toDate())
                        : '-',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            const Text(
              'Roommates',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Color(0xFF14B8A6),
              ),
            ),
            const SizedBox(height: 12),
            Builder(
              builder: (context) {
                final targetRoomId =
                    allocationDetails?['roomId'] ?? residentData['roomId'];
                if (targetRoomId == null) {
                  return Text(
                    'No roommate data available',
                    style: TextStyle(
                      color: Theme.of(context).textTheme.bodySmall?.color,
                      fontSize: 14,
                    ),
                  );
                }

                return StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('residents')
                      .where('roomId', isEqualTo: targetRoomId)
                      .where('isAllocated', isEqualTo: true)
                      .snapshots(),
                  builder: (context, roommatesSnap) {
                    final roommates = roommatesSnap.data?.docs ?? [];
                    final selfAuthUid =
                        residentData['authUid'] ?? residentData['uid'];
                    final otherRoommates = roommates
                        .where(
                          (r) =>
                              (r.data() as Map<String, dynamic>)['authUid'] !=
                                  selfAuthUid &&
                              (r.data() as Map<String, dynamic>)['uid'] !=
                                  selfAuthUid,
                        )
                        .toList();

                    if (otherRoommates.isEmpty) {
                      return Text(
                        'No other roommates',
                        style: TextStyle(
                          color: Theme.of(context).textTheme.bodySmall?.color,
                          fontSize: 14,
                        ),
                      );
                    }

                    return Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: otherRoommates.map((doc) {
                        final data = doc.data() as Map<String, dynamic>;
                        final name =
                            data['name'] ?? data['fullName'] ?? 'Unknown';
                        final initials = name
                            .split(' ')
                            .take(2)
                            .map((e) => e.isNotEmpty ? e[0] : '')
                            .join()
                            .toUpperCase();

                        return Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: Theme.of(context).cardColor,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: Theme.of(context).dividerColor,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              CircleAvatar(
                                radius: 14,
                                backgroundColor: const Color(0xFF14B8A6),
                                child: Text(
                                  initials,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(name, style: const TextStyle(fontSize: 14)),
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
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Theme.of(context).textTheme.bodySmall?.color,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}

class _QuickStatsCard extends StatelessWidget {
  final String residentId;

  const _QuickStatsCard({required this.residentId});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Theme.of(context).dividerColor),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF6C63FF).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.trending_up,
                    color: Color(0xFF6C63FF),
                  ),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Quick Stats',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                ),
              ],
            ),
            const SizedBox(height: 20),
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('complaints')
                  .where('residentId', isEqualTo: residentId)
                  .snapshots(),
              builder: (context, complaintsSnap) {
                final complaints = complaintsSnap.data?.docs ?? [];
                final activeComplaints = complaints.where((c) {
                  final data = c.data() as Map<String, dynamic>;
                  final status = data['status']?.toString().toLowerCase() ?? '';
                  return status != 'resolved' && status != 'closed';
                }).length;

                return StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('payments')
                      .where('residentId', isEqualTo: residentId)
                      .orderBy('dueDate', descending: true)
                      .limit(1)
                      .snapshots(),
                  builder: (context, paymentSnap) {
                    final payments = paymentSnap.data?.docs ?? [];
                    final latestPayment = payments.isNotEmpty
                        ? payments.first.data() as Map<String, dynamic>
                        : null;
                    final paymentStatus =
                        latestPayment?['status']?.toString() ??
                        latestPayment?['isPaid']?.toString() ??
                        'unknown';
                    final isPaid =
                        paymentStatus.toLowerCase() == 'paid' ||
                        latestPayment?['isPaid'] == true;

                    return Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Active Complaints'),
                            Chip(
                              label: Text(activeComplaints.toString()),
                              backgroundColor: activeComplaints > 0
                                  ? Colors.orange.withOpacity(0.2)
                                  : Colors.green.withOpacity(0.2),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        const Divider(),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Payment Status'),
                            Chip(
                              label: Text(isPaid ? 'Up to Date' : 'Pending'),
                              backgroundColor: isPaid
                                  ? Colors.green.withOpacity(0.2)
                                  : Colors.red.withOpacity(0.2),
                            ),
                          ],
                        ),
                      ],
                    );
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

/* =========================================================
   PAYMENT SECTION
========================================================= */

class _PaymentSection extends StatelessWidget {
  final String residentId;

  const _PaymentSection({required this.residentId});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Theme.of(context).dividerColor),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF14B8A6).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.currency_rupee,
                        color: Color(0xFF14B8A6),
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'Fee Status & Payment History',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('payments')
                      .where('residentId', isEqualTo: residentId)
                      .orderBy('dueDate', descending: true)
                      .limit(1)
                      .snapshots(),
                  builder: (context, snap) {
                    final latest = snap.data?.docs.firstOrNull;
                    final status = latest?.data() as Map<String, dynamic>?;
                    final isPaid =
                        status?['status']?.toString().toLowerCase() == 'paid' ||
                        status?['isPaid'] == true;
                    final dueDate = status?['dueDate'] as Timestamp?;
                    final dueDateTime = dueDate?.toDate();
                    final isOverdue =
                        !isPaid &&
                        dueDateTime != null &&
                        DateTime.now().isAfter(dueDateTime);

                    return Chip(
                      label: Text(
                        isPaid ? 'Paid' : (isOverdue ? 'Overdue' : 'Pending'),
                      ),
                      backgroundColor: isPaid
                          ? Colors.green.withOpacity(0.2)
                          : (isOverdue
                                ? Colors.red.withOpacity(0.2)
                                : Colors.orange.withOpacity(0.2)),
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: 20),
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('payments')
                  .where('residentId', isEqualTo: residentId)
                  .orderBy('dueDate', descending: true)
                  .limit(1)
                  .snapshots(),
              builder: (context, snap) {
                if (!snap.hasData || snap.data!.docs.isEmpty) {
                  return Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: const Color(0xFF14B8A6).withOpacity(0.05),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Center(
                      child: Text('No payment records found'),
                    ),
                  );
                }

                final payment = snap.data!.docs.first;
                final data = payment.data() as Map<String, dynamic>;
                final amount = data['amount'] ?? data['monthlyFee'] ?? 0;
                final dueDate = data['dueDate'] as Timestamp?;
                final paidAt = data['paidAt'] as Timestamp?;
                final month = data['month'] ?? '';

                return Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        const Color(0xFF14B8A6).withOpacity(0.1),
                        const Color(0xFF06B6D4).withOpacity(0.1),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: _PaymentInfoItem(
                          label: 'Current Month',
                          value: month.isNotEmpty
                              ? month
                              : (dueDate != null
                                    ? DateFormat(
                                        'MMMM yyyy',
                                      ).format(dueDate.toDate())
                                    : '-'),
                        ),
                      ),
                      Expanded(
                        child: _PaymentInfoItem(
                          label: 'Amount',
                          value: '₹${amount.toString()}',
                        ),
                      ),
                      Expanded(
                        child: _PaymentInfoItem(
                          label: 'Paid On',
                          value: paidAt != null
                              ? DateFormat(
                                  'MMM dd, yyyy',
                                ).format(paidAt.toDate())
                              : '-',
                        ),
                      ),
                      Expanded(
                        child: _PaymentInfoItem(
                          label: 'Due Date',
                          value: dueDate != null
                              ? DateFormat(
                                  'MMM dd, yyyy',
                                ).format(dueDate.toDate())
                              : '-',
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 20),
            Builder(
              builder: (context) {
                return StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('payments')
                      .where('residentId', isEqualTo: residentId)
                      .orderBy('dueDate', descending: true)
                      .limit(1)
                      .snapshots(),
                  builder: (context, snap) {
                    if (!snap.hasData || snap.data!.docs.isEmpty) {
                      return const SizedBox.shrink();
                    }
                    final data =
                        snap.data!.docs.first.data() as Map<String, dynamic>;
                    final dueDate = data['dueDate'] as Timestamp?;
                    final isPaid =
                        data['status']?.toString().toLowerCase() == 'paid' ||
                        data['isPaid'] == true;
                    final dueDateTime = dueDate?.toDate();
                    final isOverdue =
                        !isPaid &&
                        dueDateTime != null &&
                        DateTime.now().isAfter(dueDateTime);
                    final startOfMonth = dueDateTime != null
                        ? DateTime(dueDateTime.year, dueDateTime.month, 1)
                        : null;
                    final totalDays =
                        dueDateTime != null && startOfMonth != null
                        ? dueDateTime.difference(startOfMonth).inDays
                        : 0;
                    final elapsedDays =
                        dueDateTime != null && startOfMonth != null
                        ? DateTime.now().difference(startOfMonth).inDays
                        : 0;
                    final progress = totalDays > 0
                        ? (elapsedDays / totalDays).clamp(0.0, 1.0)
                        : 0.0;

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Next Due Date',
                              style: TextStyle(
                                fontSize: 12,
                                color: Theme.of(
                                  context,
                                ).textTheme.bodySmall?.color,
                              ),
                            ),
                            Text(
                              dueDateTime != null
                                  ? DateFormat(
                                      'MMM dd, yyyy',
                                    ).format(dueDateTime)
                                  : '-',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: isOverdue ? Colors.red : Colors.teal,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: LinearProgressIndicator(
                            value: isPaid ? 1 : progress,
                            minHeight: 8,
                            backgroundColor: Colors.grey.withOpacity(0.2),
                            valueColor: AlwaysStoppedAnimation<Color>(
                              isPaid
                                  ? Colors.green
                                  : (isOverdue ? Colors.red : Colors.teal),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                );
              },
            ),
            const SizedBox(height: 20),
            const Text(
              'Payment History',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('payments')
                  .where('residentId', isEqualTo: residentId)
                  .orderBy('paidAt', descending: true)
                  .limit(6)
                  .snapshots(),
              builder: (context, snap) {
                if (!snap.hasData || snap.data!.docs.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.all(20),
                    child: Center(child: Text('No payment history')),
                  );
                }

                return Column(
                  children: snap.data!.docs.map((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    final amount = data['amount'] ?? data['monthlyFee'] ?? 0;
                    final paidAt = data['paidAt'] as Timestamp?;
                    final month = data['month'] ?? '';

                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Theme.of(context).cardColor,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Theme.of(context).dividerColor,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  month.isNotEmpty
                                      ? month
                                      : (paidAt != null
                                            ? DateFormat(
                                                'MMMM yyyy',
                                              ).format(paidAt.toDate())
                                            : 'Unknown'),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                if (paidAt != null)
                                  Text(
                                    DateFormat(
                                      'MMM dd, yyyy',
                                    ).format(paidAt.toDate()),
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Theme.of(
                                        context,
                                      ).textTheme.bodySmall?.color,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          Row(
                            children: [
                              Text(
                                '₹${amount.toString()}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Chip(
                                label: const Text('Paid'),
                                backgroundColor: Colors.green.withOpacity(0.2),
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
      ),
    );
  }
}

class _PaymentInfoItem extends StatelessWidget {
  final String label;
  final String value;

  const _PaymentInfoItem({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Theme.of(context).textTheme.bodySmall?.color,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Color(0xFF14B8A6),
          ),
        ),
      ],
    );
  }
}

/* =========================================================
   QUICK ACTIONS
========================================================= */

class _QuickActions extends StatelessWidget {
  final String residentId;
  final String? pgId;

  const _QuickActions({required this.residentId, required this.pgId});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Quick Actions',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, constraints) {
            final isCompact = constraints.maxWidth < 520;
            if (isCompact) {
              return Column(
                children: [
                  _GradientActionButton(
                    label: 'Raise Complaint',
                    icon: Icons.notifications_outlined,
                    gradient: const LinearGradient(
                      colors: [Color(0xFFF97316), Color(0xFFFB923C)],
                    ),
                    onTap: () {
                      // TODO: Navigate to raise complaint
                    },
                  ),
                  const SizedBox(height: 10),
                  _GradientActionButton(
                    label: 'View Notices',
                    icon: Icons.description_outlined,
                    gradient: const LinearGradient(
                      colors: [Color(0xFF6C63FF), Color(0xFF8B7BFF)],
                    ),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ResidentNoticesScreen(
                            residentId: residentId,
                            pgId: pgId,
                          ),
                        ),
                      );
                    },
                  ),
                ],
              );
            }
            return Row(
              children: [
                Expanded(
                  child: _GradientActionButton(
                    label: 'Raise Complaint',
                    icon: Icons.notifications_outlined,
                    gradient: const LinearGradient(
                      colors: [Color(0xFFF97316), Color(0xFFFB923C)],
                    ),
                    onTap: () {
                      // TODO: Navigate to raise complaint
                    },
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: _GradientActionButton(
                    label: 'View Notices',
                    icon: Icons.description_outlined,
                    gradient: const LinearGradient(
                      colors: [Color(0xFF6C63FF), Color(0xFF8B7BFF)],
                    ),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ResidentNoticesScreen(
                            residentId: residentId,
                            pgId: pgId,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _GradientActionButton extends StatefulWidget {
  final String label;
  final IconData icon;
  final LinearGradient gradient;
  final VoidCallback onTap;

  const _GradientActionButton({
    required this.label,
    required this.icon,
    required this.gradient,
    required this.onTap,
  });

  @override
  State<_GradientActionButton> createState() => _GradientActionButtonState();
}

class _GradientActionButtonState extends State<_GradientActionButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapCancel: () => setState(() => _pressed = false),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      child: AnimatedScale(
        duration: const Duration(milliseconds: 120),
        scale: _pressed ? 0.98 : 1,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            gradient: widget.gradient,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.12),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                height: 32,
                width: 32,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(widget.icon, color: Colors.white, size: 18),
              ),
              const SizedBox(width: 12),
              Text(
                widget.label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              const Icon(
                Icons.arrow_forward_ios,
                color: Colors.white,
                size: 14,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NoticesPreviewLoading extends StatelessWidget {
  const _NoticesPreviewLoading();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(
        2,
        (index) => Container(
          margin: const EdgeInsets.only(bottom: 12),
          height: 64,
          decoration: BoxDecoration(
            color: Theme.of(context).dividerColor.withOpacity(0.2),
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }
}

class _NoticesEmptyCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          Container(
            height: 64,
            width: 64,
            decoration: BoxDecoration(
              color: Colors.teal.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.notifications_off, color: Colors.teal),
          ),
          const SizedBox(height: 12),
          const Text(
            'No Notices Yet',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
          Text(
            'Admin announcements will appear here.',
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).textTheme.bodySmall?.color,
            ),
          ),
        ],
      ),
    );
  }
}

/* =========================================================
   BOTTOM GRID
========================================================= */

class _BottomGrid extends StatelessWidget {
  final String residentId;
  final String? pgId;

  const _BottomGrid({required this.residentId, required this.pgId});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 900;
        if (isCompact) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _ComplaintsCard(residentId: residentId),
              const SizedBox(height: 16),
              _NoticesPreviewCard(residentId: residentId, pgId: pgId),
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: _ComplaintsCard(residentId: residentId)),
            const SizedBox(width: 16),
            Expanded(
              child: _NoticesPreviewCard(residentId: residentId, pgId: pgId),
            ),
          ],
        );
      },
    );
  }
}

class _ComplaintsCard extends StatelessWidget {
  final String residentId;

  const _ComplaintsCard({required this.residentId});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Theme.of(context).dividerColor),
      ),
      child: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('complaints')
            .where('residentId', isEqualTo: residentId)
            .orderBy('createdAt', descending: true)
            .limit(3)
            .snapshots(),
        builder: (context, snap) {
          final docs = snap.data?.docs ?? [];
          final totalCount = docs.length;

          return Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.orange.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.notifications_outlined,
                            color: Colors.orange,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Text(
                          'My Complaints',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.orange.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            totalCount.toString(),
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.orange,
                            ),
                          ),
                        ),
                      ],
                    ),
                    TextButton(
                      onPressed: () {
                        // TODO: View all complaints
                      },
                      child: const Text('View All'),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (docs.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        Icon(
                          Icons.check_circle_outline,
                          color: Colors.green.withOpacity(0.6),
                          size: 40,
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'No Complaints',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'You are all set. No pending issues.',
                          style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(context).textTheme.bodySmall?.color,
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  Column(
                    children: docs.map((doc) {
                      final data = doc.data() as Map<String, dynamic>;
                      final title = data['title'] ?? 'Untitled';
                      final category = data['category'] ?? 'General';
                      final status =
                          data['status']?.toString().toLowerCase() ?? '';
                      final createdAt = data['createdAt'] as Timestamp?;
                      final priority =
                          data['priority']?.toString().toLowerCase() ?? '';

                      final isResolved =
                          status == 'resolved' || status == 'closed';
                      final badgeColor = isResolved
                          ? Colors.green
                          : Colors.orange;

                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Theme.of(context).cardColor,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Theme.of(context).dividerColor,
                          ),
                        ),
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
                                    ),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: badgeColor.withOpacity(0.12),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    isResolved ? 'Resolved' : 'In Progress',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: badgeColor,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Category: $category',
                              style: TextStyle(
                                fontSize: 12,
                                color: Theme.of(
                                  context,
                                ).textTheme.bodySmall?.color,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                Text(
                                  createdAt != null
                                      ? DateFormat(
                                          'MMM dd, yyyy',
                                        ).format(createdAt.toDate())
                                      : '-',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Theme.of(
                                      context,
                                    ).textTheme.bodySmall?.color,
                                  ),
                                ),
                                const Spacer(),
                                if (priority.isNotEmpty)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.grey.withOpacity(0.15),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Text(
                                      priority,
                                      style: const TextStyle(fontSize: 11),
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _NoticesPreviewCard extends StatelessWidget {
  final String residentId;
  final String? pgId;

  const _NoticesPreviewCard({required this.residentId, required this.pgId});

  Stream<QuerySnapshot> _allNoticesStream() {
    if (pgId == null || pgId!.isEmpty) {
      return Stream.empty();
    }
    return FirebaseFirestore.instance
        .collection('notices')
        .where('scope', isEqualTo: 'ALL')
        .where('senderRole', isEqualTo: 'admin')
        .where('isActive', isEqualTo: true)
        .where('pgIds', arrayContains: pgId)
        .orderBy('createdAt', descending: true)
        .limit(3)
        .snapshots();
  }

  Stream<QuerySnapshot> _hostelNoticesStream() {
    if (pgId == null || pgId!.isEmpty) {
      return Stream.empty();
    }
    return FirebaseFirestore.instance
        .collection('notices')
        .where('scope', isEqualTo: 'PG')
        .where('senderRole', isEqualTo: 'admin')
        .where('isActive', isEqualTo: true)
        .where('pgIds', arrayContains: pgId)
        .orderBy('createdAt', descending: true)
        .limit(3)
        .snapshots();
  }

  Stream<QuerySnapshot> _residentNoticesStream() {
    return FirebaseFirestore.instance
        .collection('notices')
        .where('scope', isEqualTo: 'RESIDENT')
        .where('senderRole', isEqualTo: 'admin')
        .where('isActive', isEqualTo: true)
        .where('residentIds', arrayContains: residentId)
        .orderBy('createdAt', descending: true)
        .limit(3)
        .snapshots();
  }

  List<QueryDocumentSnapshot> _mergeNotices(
    List<QueryDocumentSnapshot> a,
    List<QueryDocumentSnapshot> b,
    List<QueryDocumentSnapshot> c,
  ) {
    final map = <String, QueryDocumentSnapshot>{};
    for (final doc in a) {
      map[doc.id] = doc;
    }
    for (final doc in b) {
      map[doc.id] = doc;
    }
    for (final doc in c) {
      map[doc.id] = doc;
    }
    final merged = map.values.toList();
    merged.sort((x, y) {
      final xData = x.data() as Map<String, dynamic>;
      final yData = y.data() as Map<String, dynamic>;
      final xTime = xData['createdAt'] as Timestamp?;
      final yTime = yData['createdAt'] as Timestamp?;
      final xMillis = xTime?.millisecondsSinceEpoch ?? 0;
      final yMillis = yTime?.millisecondsSinceEpoch ?? 0;
      return yMillis.compareTo(xMillis);
    });
    return merged.take(3).toList();
  }

  bool _isRead(Map<String, dynamic> data) {
    final readers = data['readBy'];
    if (readers is Iterable) {
      return readers.contains(residentId);
    }
    return false;
  }

  String _formatDate(Timestamp? createdAt) {
    if (createdAt == null) return '—';
    return DateFormat('MMM dd, yyyy').format(createdAt.toDate());
  }

  @override
  Widget build(BuildContext context) {
    if (pgId == null || pgId!.isEmpty) {
      return _NoticesEmptyCard();
    }
    return Card(
      elevation: 2,
      shadowColor: Colors.black.withOpacity(0.08),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF6C63FF).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.description_outlined,
                        color: Color(0xFF6C63FF),
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Text(
                      'Recent Notices',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                TextButton(
                  onPressed: () {
                    if (pgId == null) return;
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ResidentNoticesScreen(
                          residentId: residentId,
                          pgId: pgId,
                        ),
                      ),
                    );
                  },
                  child: const Text('View All'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            StreamBuilder<QuerySnapshot>(
              stream: _allNoticesStream(),
              builder: (context, allSnap) {
                if (allSnap.hasError) {
                  return _NoticesEmptyCard();
                }
                if (allSnap.connectionState == ConnectionState.waiting) {
                  return const _NoticesPreviewLoading();
                }
                final allDocs = allSnap.data?.docs ?? [];

                final hostelStream = pgId == null
                    ? Stream<QuerySnapshot?>.value(null)
                    : _hostelNoticesStream();
                return StreamBuilder<QuerySnapshot?>(
                  stream: hostelStream,
                  builder: (context, hostelSnap) {
                    if (hostelSnap.hasError) {
                      return _NoticesEmptyCard();
                    }
                    if (pgId != null &&
                        hostelSnap.connectionState == ConnectionState.waiting) {
                      return const _NoticesPreviewLoading();
                    }
                    final hostelDocs = hostelSnap.data?.docs ?? [];

                    return StreamBuilder<QuerySnapshot>(
                      stream: _residentNoticesStream(),
                      builder: (context, residentSnap) {
                        if (residentSnap.hasError) {
                          return _NoticesEmptyCard();
                        }
                        if (residentSnap.connectionState ==
                            ConnectionState.waiting) {
                          return const _NoticesPreviewLoading();
                        }

                        final residentDocs = residentSnap.data?.docs ?? [];
                        final merged = _mergeNotices(
                          allDocs,
                          hostelDocs,
                          residentDocs,
                        );

                        if (merged.isEmpty) {
                          return _NoticesEmptyCard();
                        }

                        return Column(
                          children: merged.map((doc) {
                            final data = doc.data() as Map<String, dynamic>;
                            final title = (data['title'] ?? 'Notice')
                                .toString();
                            final message = (data['message'] ?? '').toString();
                            final createdAt = data['createdAt'] as Timestamp?;
                            final isRead = _isRead(data);
                            final noticeType = (data['noticeType'] ?? 'Notice')
                                .toString();

                            return Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: Theme.of(context).cardColor,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: Theme.of(context).dividerColor,
                                ),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    width: 6,
                                    height: 52,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF14B8A6),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                title,
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ),
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 8,
                                                    vertical: 4,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: const Color(
                                                  0xFF6C63FF,
                                                ).withOpacity(0.12),
                                                borderRadius:
                                                    BorderRadius.circular(10),
                                              ),
                                              child: Text(
                                                noticeType,
                                                style: const TextStyle(
                                                  fontSize: 10,
                                                  color: Color(0xFF6C63FF),
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          message.isEmpty
                                              ? 'No message provided.'
                                              : message,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Theme.of(
                                              context,
                                            ).textTheme.bodySmall?.color,
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        Row(
                                          children: [
                                            Text(
                                              _formatDate(createdAt),
                                              style: TextStyle(
                                                fontSize: 11,
                                                color: Theme.of(
                                                  context,
                                                ).textTheme.bodySmall?.color,
                                              ),
                                            ),
                                            const Spacer(),
                                            if (!isRead)
                                              Container(
                                                width: 8,
                                                height: 8,
                                                decoration: const BoxDecoration(
                                                  color: Colors.teal,
                                                  shape: BoxShape.circle,
                                                ),
                                              ),
                                          ],
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
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

/* =========================================================
   ALLOCATION PENDING
========================================================= */

class _AllocationPendingCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Theme.of(context).dividerColor),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Row(
          children: [
            Icon(
              Icons.info_outline,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Allocation Pending',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).textTheme.titleLarge?.color,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Your account is registered. Room allocation will appear here once assigned.',
                    style: TextStyle(
                      color: Theme.of(context).textTheme.bodySmall?.color,
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
