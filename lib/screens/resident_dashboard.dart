import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import 'login_screen.dart';
import 'resident_notices_screen.dart';
import 'rent_payments_screen.dart';
import 'raise_complaint_screen.dart';
import '../main.dart';
import '../theme/app_text_styles.dart';
import '../utils/admin_design_system.dart';
import '../widgets/admin_widgets.dart';

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
    String? bedId,
  ) async {
    if (hostelId == null || pgId == null || floorId == null || roomId == null) {
      return {};
    }

    final hostelRef = FirebaseFirestore.instance.collection('hostels').doc(hostelId);
    final floorRef = hostelRef
        .collection('pgs')
        .doc(pgId)
        .collection('floors')
        .doc(floorId);
    final roomRef = floorRef.collection('rooms').doc(roomId);

    final results = await Future.wait([hostelRef.get(), floorRef.get(), roomRef.get()]);
    final hostelSnap = results[0];
    final floorSnap = results[1];
    final roomSnap = results[2];

    final hostelData = hostelSnap.data();
    final floorData = floorSnap.data();
    final roomData = roomSnap.data();

    final hostelName = hostelData?['hostelName']?.toString()
        ?? hostelData?['name']?.toString()
        ?? '';

    final floorIndex = floorData?['floorIndex'];
    final floorLabel =
        floorData?['floorName']?.toString() ??
        floorData?['floorNumber']?.toString() ??
        (floorIndex != null ? 'Floor ${floorIndex.toString()}' : '');

    return {
      'hostelName': hostelName.isEmpty ? null : hostelName,
      'floorLabel': floorLabel.isEmpty ? null : floorLabel,
      'sharingType': roomData?['sharingType']?.toString(),
      'roomNumber': roomData?['roomNumber']?.toString(),
      'rentPerBed': roomData?['rentPerBed'],
      'bedId': bedId,
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
      body: StreamBuilder<DocumentSnapshot?>(
        stream: FirebaseFirestore.instance
            .collection('residents')
            .where('authUid', isEqualTo: user.uid)
            .limit(1)
            .snapshots()
            .map((snap) => snap.docs.isNotEmpty ? snap.docs.first : null),
        builder: (context, residentSnap) {
          if (residentSnap.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }
          if (!residentSnap.hasData || residentSnap.data == null) {
            return const Scaffold(
              body: Center(child: Text('Resident data not found')),
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
          final bedId = allocationDetails?['bedId'] ?? residentData['bedId'];

          final allocationMetaFuture =
              (hostelId != null &&
                      pgId != null &&
                      floorId != null &&
                      roomId != null)
                  ? _fetchAllocationMetadata(hostelId, pgId, floorId, roomId, bedId?.toString())
                  : Future.value(<String, dynamic>{});

          return FutureBuilder<Map<String, dynamic>>(
            future: allocationMetaFuture,
            builder: (context, metaSnap) {
              final allocationMeta = metaSnap.data ?? {};

              return Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      AdminColors.scaffold(context),
                      AdminColors.scaffold(context),
                    ],
                  ),
                ),
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
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
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 24.0,
                        ),
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
                            const SizedBox(height: 32),
                            if (isAllocated) ...[
                              _MainGrid(
                                residentId: _residentId!,
                                allocationDetails: allocationDetails,
                                residentData: residentData,
                                allocationMeta: allocationMeta,
                              ),
                              const SizedBox(height: 32),
                              _PaymentSection(
                                residentId: _residentId!,
                                hostelId: hostelId?.toString(),
                                pgId: pgId?.toString(),
                                floorId: floorId?.toString(),
                                roomId: roomId?.toString(),
                              ),
                              const SizedBox(height: 32),
                              _QuickActions(
                                residentId: _residentId!,
                                pgId: pgId?.toString(),
                              ),
                              const SizedBox(height: 32),
                              _BottomGrid(
                                residentId: _residentId!,
                                pgId: pgId?.toString(),
                              ),
                              const SizedBox(height: 40),
                            ] else
                              _AllocationPendingCard(),
                          ],
                        ),
                      ),
                    ],
                  ),
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
    final date = DateFormat('MMM dd').format(DateTime.now());

    return Container(
      padding: const EdgeInsets.fromLTRB(24, 60, 24, 20),
      decoration: BoxDecoration(
        color: AdminColors.card(context),
        boxShadow: AdminShadows.card,
      ),
      child: Row(
        children: [
          Container(
            height: 48,
            width: 48,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF6366F1), Color(0xFF4F46E5)],
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF6366F1).withOpacity(0.2),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Icon(Icons.home_rounded, color: Colors.white, size: 26),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'SmartStay',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                    color: AdminColors.text(context),
                  ),
                ),
                Text(
                  'Resident Portal • $date',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                IconButton(
                  visualDensity: VisualDensity.compact,
                  icon: Icon(
                    isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
                    size: 20,
                    color: const Color(0xFF475569),
                  ),
                  onPressed: () => app?.themeController.toggleTheme(),
                ),
                Container(
                  width: 1,
                  height: 20,
                  color: const Color(0xFFCBD5E1),
                ),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(
                    Icons.logout_rounded,
                    size: 20,
                    color: Color(0xFFEF4444),
                  ),
                  onPressed: onLogout,
                ),
              ],
            ),
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
    final roomNumber =
        metaRoomNumber?.isNotEmpty == true
            ? metaRoomNumber!
            : allocationDetails?['roomNumber'] ?? '-';
    final floorName =
        metaFloorLabel?.isNotEmpty == true
            ? metaFloorLabel!
            : allocationDetails?['floorName'] ?? '-';

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('payments')
          .where('residentId', isEqualTo: residentId)
          .where('userId', isEqualTo: FirebaseAuth.instance.currentUser?.uid)
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
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                ),
                borderRadius: BorderRadius.circular(32),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF6366F1).withOpacity(0.3),
                    blurRadius: 25,
                    offset: const Offset(0, 12),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        height: 72,
                        width: 72,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white.withOpacity(0.3),
                            width: 2,
                          ),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          _getInitials(residentName),
                          style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(width: 20),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Hello, $residentName',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.5,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.door_front_door_rounded,
                                    size: 14,
                                    color: Colors.white,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Room $roomNumber • $floorName',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),
                  Row(
                    children: [
                      Expanded(
                        child: _StatMiniCard(
                          label: 'Dues Paid',
                          value: onTimePayments.toString(),
                          icon: Icons.currency_rupee_rounded,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _StatMiniCard(
                          label: 'Complaints',
                          value: totalComplaints.toString(),
                          icon: Icons.error_rounded,
                        ),
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
  final IconData icon;

  const _StatMiniCard({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.2), width: 1),
      ),
      child: Column(
        children: [
          Icon(icon, color: Colors.white, size: 20),
          const SizedBox(height: 10),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withOpacity(0.7),
              fontSize: 10,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.2,
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
    final metaHostelName = allocationMeta?['hostelName']?.toString();
    final metaFloorLabel = allocationMeta?['floorLabel']?.toString();
    final metaRoomNumber = allocationMeta?['roomNumber']?.toString();
    final metaSharingType = allocationMeta?['sharingType']?.toString();
    final metaBedId = allocationMeta?['bedId']?.toString();

    final hostelName =
        metaHostelName?.isNotEmpty == true
            ? metaHostelName!
            : allocationDetails?['hostelName'] ?? '-';
    final floorName =
        metaFloorLabel?.isNotEmpty == true
            ? metaFloorLabel!
            : allocationDetails?['floorName'] ?? '-';
    final roomNumber =
        metaRoomNumber?.isNotEmpty == true
            ? metaRoomNumber!
            : allocationDetails?['roomNumber'] ?? '-';
    final bedNumber =
        metaBedId?.isNotEmpty == true
            ? metaBedId!
            : allocationDetails?['bedId']
              ?? allocationDetails?['bedNumber']
              ?? residentData['bedId']
              ?? '-';
    final sharingType =
        metaSharingType?.isNotEmpty == true
            ? metaSharingType!
            : residentData['sharingType'] ?? 'N/A';
    final allocatedAt = allocationDetails?['allocatedAt'] as Timestamp?;

    return Container(
      decoration: BoxDecoration(
        color: AdminColors.card(context),
        borderRadius: BorderRadius.circular(24),
        boxShadow: AdminShadows.card,
        border: Border.all(color: AdminColors.border(context)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF14B8A6).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.meeting_room_rounded,
                    color: Color(0xFF14B8A6),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 14),
                const Text(
                  'Room Details',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.5,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            _InfoRow(
              icon: Icons.business_rounded,
              label: 'Hostel Name',
              value: hostelName,
            ),
            const Divider(height: 24, color: Color(0xFFF1F5F9)),
            Row(
              children: [
                Expanded(
                  child: _InfoRow(
                    icon: Icons.layers_rounded,
                    label: 'Floor',
                    value: floorName,
                  ),
                ),
                Expanded(
                  child: _InfoRow(
                    icon: Icons.numbers_rounded,
                    label: 'Room Number',
                    value: roomNumber,
                  ),
                ),
              ],
            ),
            const Divider(height: 24, color: Color(0xFFF1F5F9)),
            Row(
              children: [
                Expanded(
                  child: _InfoRow(
                    icon: Icons.bed_rounded,
                    label: 'Bed Number',
                    value: bedNumber,
                  ),
                ),
                Expanded(
                  child: _InfoRow(
                    icon: Icons.people_rounded,
                    label: 'Sharing Type',
                    value: sharingType,
                  ),
                ),
              ],
            ),
            const Divider(height: 24, color: Color(0xFFF1F5F9)),
            _InfoRow(
              icon: Icons.event_available_rounded,
              label: 'Resident Since',
              value:
                  allocatedAt != null
                      ? DateFormat('MMM dd, yyyy').format(allocatedAt.toDate())
                      : '-',
            ),
            const SizedBox(height: 24),
            const Text(
              'ROOMMATES',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: Color(0xFF64748B),
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 12),
            Builder(
              builder: (context) {
                final targetRoomId =
                    allocationDetails?['roomId'] ?? residentData['roomId'];
                if (targetRoomId == null) {
                  return const Text(
                    'No roommate data available',
                    style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
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
                    // Exclude self by document ID (most reliable)
                    final otherRoommates =
                        roommates
                            .where((r) => r.id != residentId)
                            .toList();

                    if (otherRoommates.isEmpty) {
                      return const Text(
                        'No other roommates',
                        style: TextStyle(
                          color: Color(0xFF94A3B8),
                          fontSize: 13,
                        ),
                      );
                    }

                    return Column(
                      children: otherRoommates.map((doc) {
                        final data = doc.data() as Map<String, dynamic>;
                        final name =
                            (data['fullName'] ?? data['name'] ?? 'Unknown').toString();
                        final bedId =
                            (data['bedId'] ?? data['allocationDetails']?['bedId'] ?? '').toString();
                        final initials =
                            name
                                .split(' ')
                                .take(2)
                                .map((e) => e.isNotEmpty ? e[0] : '')
                                .join()
                                .toUpperCase();

                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AdminColors.subtleBg(context),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AdminColors.border(context)),
                          ),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 16,
                                backgroundColor: const Color(
                                  0xFF14B8A6,
                                ).withOpacity(0.1),
                                child: Text(
                                  initials,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF14B8A6),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  name,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF334155),
                                  ),
                                ),
                              ),
                              if (bedId.isNotEmpty)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF14B8A6).withOpacity(0.08),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.bed_rounded, size: 12, color: Color(0xFF14B8A6)),
                                      const SizedBox(width: 4),
                                      Text(
                                        'Bed $bedId',
                                        style: const TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w700,
                                          color: Color(0xFF14B8A6),
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
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 14, color: const Color(0xFF64748B)),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Color(0xFF64748B),
                letterSpacing: 0.2,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          value,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: Color(0xFF1E293B),
          ),
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
    return Container(
      decoration: BoxDecoration(
        color: AdminColors.card(context),
        borderRadius: BorderRadius.circular(24),
        boxShadow: AdminShadows.card,
        border: Border.all(color: AdminColors.border(context)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF6366F1).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.insights_rounded,
                    color: Color(0xFF6366F1),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 14),
                const Text(
                  'Quick Stats',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.5,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('complaints')
                  .where('residentId', isEqualTo: residentId)
                  .snapshots(),
              builder: (context, complaintsSnap) {
                final complaints = complaintsSnap.data?.docs ?? [];
                final activeComplaints =
                    complaints.where((c) {
                      final data = c.data() as Map<String, dynamic>;
                      final status =
                          data['status']?.toString().toLowerCase() ?? '';
                      return status != 'resolved' && status != 'closed';
                    }).length;

                return StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('payments')
                      .where('residentId', isEqualTo: residentId)
                      .where('userId', isEqualTo: FirebaseAuth.instance.currentUser?.uid)
                      .orderBy('dueDate', descending: true)
                      .limit(1)
                      .snapshots(),
                  builder: (context, paymentSnap) {
                    final payments = paymentSnap.data?.docs ?? [];
                    final latestPayment =
                        payments.isNotEmpty
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
                        _QuickStatItem(
                          icon: Icons.error_outline_rounded,
                          color: const Color(0xFFEF4444),
                          label: 'Active Complaints',
                          value: activeComplaints.toString(),
                          trailing: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color:
                                  (activeComplaints > 0
                                          ? const Color(0xFFEF4444)
                                          : const Color(0xFF10B981))
                                      .withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              activeComplaints > 0 ? 'Pending' : 'All Clear',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color:
                                    activeComplaints > 0
                                        ? const Color(0xFFEF4444)
                                        : const Color(0xFF10B981),
                              ),
                            ),
                          ),
                        ),
                        const Divider(height: 32, color: Color(0xFFF1F5F9)),
                        FutureBuilder<Timestamp?>(
                          future: () async {
                            try {
                              final snap = await FirebaseFirestore.instance
                                  .collection('residents')
                                  .doc(residentId)
                                  .get();
                              final d = snap.data();
                              final alloc = d?['allocationDetails'] as Map<String, dynamic>?;
                              return alloc?['allocatedAt'] as Timestamp?;
                            } catch (_) {
                              return null;
                            }
                          }(),
                          builder: (context, allocSnap) {
                            final allocatedAt = allocSnap.data;

                            // Calculate next due date from allocation
                            DateTime? nextDue;
                            if (allocatedAt != null) {
                              final aDate = allocatedAt.toDate();
                              final now = DateTime.now();
                              final joinDay = aDate.day;
                              DateTime dd = DateTime(aDate.year, aDate.month + 1, 1);
                              final ldm = DateTime(dd.year, dd.month + 1, 0).day;
                              final d = joinDay > ldm ? ldm : joinDay;
                              dd = DateTime(dd.year, dd.month, d);
                              while (dd.isBefore(now)) {
                                final nm = DateTime(dd.year, dd.month + 1, 1);
                                final ld = DateTime(nm.year, nm.month + 1, 0).day;
                                final nd = joinDay > ld ? ld : joinDay;
                                dd = DateTime(nm.year, nm.month, nd);
                              }
                              nextDue = dd;
                            }

                            // Determine status
                            String statusText;
                            Color statusColor;
                            IconData statusIcon;

                            if (isPaid) {
                              statusText = 'Paid';
                              statusColor = const Color(0xFF10B981);
                              statusIcon = Icons.check_circle_rounded;
                            } else if (nextDue != null) {
                              final now = DateTime.now();
                              final daysUntilDue = nextDue.difference(now).inDays;
                              if (daysUntilDue < 0) {
                                statusText = 'Overdue';
                                statusColor = const Color(0xFFEF4444);
                                statusIcon = Icons.warning_rounded;
                              } else if (daysUntilDue <= 7) {
                                statusText = 'Due Soon';
                                statusColor = const Color(0xFFF59E0B);
                                statusIcon = Icons.info_rounded;
                              } else {
                                statusText = 'Upcoming';
                                statusColor = const Color(0xFF3B82F6);
                                statusIcon = Icons.schedule_rounded;
                              }
                            } else {
                              statusText = 'Not Paid';
                              statusColor = const Color(0xFFF59E0B);
                              statusIcon = Icons.info_rounded;
                            }

                            return _QuickStatItem(
                              icon: Icons.payments_outlined,
                              color: const Color(0xFF10B981),
                              label: 'Payment Status',
                              value: statusText,
                              trailing: Icon(
                                statusIcon,
                                color: statusColor,
                                size: 20,
                              ),
                            );
                          },
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

class _QuickStatItem extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final String value;
  final Widget? trailing;

  const _QuickStatItem({
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          height: 40,
          width: 40,
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF64748B),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1E293B),
                ),
              ),
            ],
          ),
        ),
        if (trailing != null) trailing!,
      ],
    );
  }
}

/* =========================================================
   PAYMENT SECTION
========================================================= */

class _PaymentSection extends StatelessWidget {
  final String residentId;
  final String? hostelId;
  final String? pgId;
  final String? floorId;
  final String? roomId;

  const _PaymentSection({
    required this.residentId,
    this.hostelId,
    this.pgId,
    this.floorId,
    this.roomId,
  });

   Future<int?> _fetchRentPerBed() async {
    if (hostelId == null || pgId == null || floorId == null || roomId == null) {
      return null;
    }
    try {
      final roomSnap = await FirebaseFirestore.instance
          .collection('hostels')
          .doc(hostelId)
          .collection('pgs')
          .doc(pgId)
          .collection('floors')
          .doc(floorId)
          .collection('rooms')
          .doc(roomId)
          .get();
      final data = roomSnap.data();
      if (data != null && data['rentPerBed'] != null) {
        return (data['rentPerBed'] as num).toInt();
      }
    } catch (_) {}
    return null;
  }

  Future<Timestamp?> _fetchAllocatedAt() async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('residents')
          .doc(residentId)
          .get();
      final data = snap.data();
      final allocation = data?['allocationDetails'] as Map<String, dynamic>?;
      return allocation?['allocatedAt'] as Timestamp?;
    } catch (_) {
      return null;
    }
  }

  /// Calculates the next monthly due date from allocation date.
  /// e.g. joined Jan 1 → due Feb 1, Mar 1, Apr 1, etc.
  static DateTime? _calculateNextDueDate(Timestamp? allocatedAtTs) {
    if (allocatedAtTs == null) return null;
    final allocatedAt = allocatedAtTs.toDate();
    final now = DateTime.now();
    final joinDay = allocatedAt.day;

    DateTime dueDate = DateTime(allocatedAt.year, allocatedAt.month + 1, 1);
    final lastDayOfMonth = DateTime(dueDate.year, dueDate.month + 1, 0).day;
    final day = joinDay > lastDayOfMonth ? lastDayOfMonth : joinDay;
    dueDate = DateTime(dueDate.year, dueDate.month, day);

    while (dueDate.isBefore(now)) {
      final nextMonth = DateTime(dueDate.year, dueDate.month + 1, 1);
      final lastDay = DateTime(nextMonth.year, nextMonth.month + 1, 0).day;
      final d = joinDay > lastDay ? lastDay : joinDay;
      dueDate = DateTime(nextMonth.year, nextMonth.month, d);
    }

    return dueDate;
  }

  @override
  Widget build(BuildContext context) {
    const teal = Color(0xFF14B8A6);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
        border: Border.all(color: const Color(0xFFF1F5F9)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: FutureBuilder<List<dynamic>>(
          future: Future.wait([_fetchRentPerBed(), _fetchAllocatedAt()]),
          builder: (context, snapList) {
            final rentPerBed = snapList.data?[0] as int?;
            final allocatedAt = snapList.data?[1] as Timestamp?;
            final calculatedDueDate = _calculateNextDueDate(allocatedAt);

            return StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('payments')
                  .where('residentId', isEqualTo: residentId)
                  .where('userId', isEqualTo: FirebaseAuth.instance.currentUser?.uid)
                  .orderBy('dueDate', descending: true)
                  .snapshots(),
              builder: (context, paymentSnap) {
                final allPayments = paymentSnap.data?.docs ?? [];
                final latestPayment = allPayments.isNotEmpty
                    ? allPayments.first.data() as Map<String, dynamic>
                    : null;

                final isPaid = latestPayment != null &&
                    (latestPayment['status']?.toString().toLowerCase() == 'paid' ||
                        latestPayment['isPaid'] == true);
                final dueDate = latestPayment?['dueDate'] as Timestamp?;
                final dueDateTime = dueDate?.toDate();
                final isOverdue = !isPaid &&
                    dueDateTime != null &&
                    DateTime.now().isAfter(dueDateTime);

                // Determine amount: prefer rentPerBed from room, fallback to payment amount
                final paymentAmount = latestPayment?['amount'] ?? latestPayment?['monthlyFee'] ?? 0;
                final displayAmount = rentPerBed ?? paymentAmount;

                final paidAt = latestPayment?['paidAt'] as Timestamp?;
                final currentMonth = DateFormat('MMMM yyyy').format(DateTime.now());

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Header Row ──
                    Row(
                      children: [
                        const Icon(
                          Icons.attach_money_rounded,
                          color: Color(0xFF334155),
                          size: 24,
                        ),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            'Fee Status & Payment History',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF1E293B),
                              letterSpacing: -0.3,
                            ),
                          ),
                        ),
                        // Status badge
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: isPaid
                                ? teal
                                : (isOverdue
                                    ? const Color(0xFFEF4444)
                                    : const Color(0xFFF59E0B)),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            isPaid ? 'Paid' : (isOverdue ? 'Overdue' : 'Pending'),
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        // View Rent Payment link
                        GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => RentPaymentsScreen(
                                  residentId: residentId,
                                  hostelId: hostelId,
                                  pgId: pgId,
                                  floorId: floorId,
                                  roomId: roomId,
                                ),
                              ),
                            );
                          },
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'View Rent Payment',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: teal,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Icon(
                                Icons.arrow_forward_rounded,
                                size: 16,
                                color: teal,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // ── Current Month Info Card ──
                    Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 20,
                        ),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              teal.withOpacity(0.06),
                              teal.withOpacity(0.02),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: teal.withOpacity(0.15),
                          ),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: _PaymentInfoItem(
                                label: 'Current Month',
                                value: currentMonth,
                              ),
                            ),
                            Expanded(
                              child: _PaymentInfoItem(
                                label: 'Amount',
                                value: '₹$displayAmount',
                              ),
                            ),
                            Expanded(
                              child: _PaymentInfoItem(
                                label: 'Paid On',
                                value: isPaid && paidAt != null
                                    ? DateFormat('MMM dd, yyyy').format(paidAt.toDate())
                                    : 'Not Paid',
                              ),
                            ),
                            Expanded(
                              child: _PaymentInfoItem(
                                label: 'Due Date',
                                value: calculatedDueDate != null
                                    ? DateFormat('MMM dd, yyyy').format(calculatedDueDate)
                                    : (dueDate != null
                                        ? DateFormat('MMM dd, yyyy').format(dueDate.toDate())
                                        : '-'),
                              ),
                            ),
                          ],
                        ),
                      ),

                    // ── Days Left Warning ──
                    if (!isPaid && calculatedDueDate != null) ...[
                      const SizedBox(height: 14),
                      () {
                        final daysLeft = calculatedDueDate.difference(DateTime.now()).inDays;
                        final isUrgent = daysLeft <= 3;
                        final isNear = daysLeft <= 5;
                        final warningColor = isUrgent
                            ? const Color(0xFFEF4444)
                            : isNear
                                ? const Color(0xFFF59E0B)
                                : teal;
                        final bgColor = isUrgent
                            ? const Color(0xFFFEF2F2)
                            : isNear
                                ? const Color(0xFFFFF7ED)
                                : teal.withOpacity(0.06);
                        final icon = isUrgent
                            ? Icons.warning_amber_rounded
                            : Icons.schedule_rounded;

                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            color: bgColor,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: warningColor.withOpacity(0.3)),
                          ),
                          child: Row(
                            children: [
                              Icon(icon, color: warningColor, size: 20),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  isOverdue
                                      ? 'Payment overdue! Was due on ${DateFormat('MMM dd, yyyy').format(calculatedDueDate)}'
                                      : 'Payment due by ${DateFormat('MMM dd, yyyy').format(calculatedDueDate)}',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: warningColor,
                                  ),
                                ),
                              ),
                              if (!isOverdue)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: warningColor.withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    '$daysLeft day${daysLeft == 1 ? '' : 's'} left',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: warningColor,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        );
                      }(),
                    ],

                    const SizedBox(height: 28),

                    // ── Payment History Header ──
                    Row(
                      children: [
                        Container(
                          width: 4,
                          height: 20,
                          decoration: BoxDecoration(
                            color: teal,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        const SizedBox(width: 10),
                        const Text(
                          'Payment History',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF1E293B),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // ── Payment History List ──
                    if (allPayments.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 20),
                        child: Center(
                          child: Text(
                            'No history',
                            style: TextStyle(
                              color: Color(0xFF94A3B8),
                              fontSize: 13,
                            ),
                          ),
                        ),
                      )
                    else
                      ScrollableCardContent(
                        maxHeight: 280,
                        child: Column(
                          children: allPayments.take(5).map((doc) {
                        final data = doc.data() as Map<String, dynamic>;
                        final amt = data['amount'] ?? data['monthlyFee'] ?? 0;
                        final paid = data['paidAt'] as Timestamp?;
                        final monthLabel = data['month']?.toString() ?? '';
                        final docIsPaid =
                            data['status']?.toString().toLowerCase() == 'paid' ||
                            data['isPaid'] == true;

                        final monthDisplay = monthLabel.isNotEmpty
                            ? monthLabel
                            : (paid != null
                                ? DateFormat('MMMM yyyy').format(paid.toDate())
                                : 'Unknown');
                        final dateDisplay = paid != null
                            ? DateFormat('MMM d, yyyy').format(paid.toDate())
                            : '';

                        return Container(
                          margin: const EdgeInsets.only(bottom: 2),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 18,
                          ),
                          decoration: BoxDecoration(
                            border: Border(
                              bottom: BorderSide(
                                color: AdminColors.border(context),
                                width: 1,
                              ),
                            ),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      monthDisplay,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 15,
                                        color: Color(0xFF1E293B),
                                      ),
                                    ),
                                    if (dateDisplay.isNotEmpty)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 3),
                                        child: Text(
                                          dateDisplay,
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: Color(0xFF94A3B8),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              Text(
                                '₹$amt',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 15,
                                  color: Color(0xFF334155),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 5,
                                ),
                                decoration: BoxDecoration(
                                  color: docIsPaid
                                      ? teal
                                      : const Color(0xFFF59E0B),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  docIsPaid ? 'Paid' : 'Pending',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                              if (docIsPaid) ...[
                                const SizedBox(width: 8),
                                GestureDetector(
                                  onTap: () => _generateReceipt(
                                    context: context,
                                    month: monthDisplay,
                                    amount: amt is int ? amt : (amt as num).toInt(),
                                    paidOn: dateDisplay,
                                    txnId: data['payuTxnId']?.toString() ?? data['paymentMode']?.toString() ?? '-',
                                    paymentMode: data['paymentMode']?.toString() ?? 'Online',
                                    residentId: residentId,
                                  ),
                                  child: const Icon(
                                    Icons.download_rounded,
                                    size: 18,
                                    color: Color(0xFF64748B),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        );
                      }).toList(),
                        ),
                      ),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }

  static Future<void> _generateReceipt({
    required BuildContext context,
    required String month,
    required int amount,
    required String paidOn,
    required String txnId,
    required String paymentMode,
    required String residentId,
  }) async {
    final pdf = pw.Document();

    String fmtAmt(int a) {
      final s = a.toString();
      final b = StringBuffer();
      int c = 0;
      for (int i = s.length - 1; i >= 0; i--) {
        b.write(s[i]);
        c++;
        if (c == 3 && i > 0) { b.write(','); c = 0; }
        else if (c > 3 && (c - 3) % 2 == 0 && i > 0) { b.write(','); }
      }
      return b.toString().split('').reversed.join();
    }

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        build: (pw.Context pdfCtx) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.all(20),
                decoration: pw.BoxDecoration(
                  color: PdfColor.fromHex('#14B8A6'),
                  borderRadius: pw.BorderRadius.circular(8),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('SmartStay', style: pw.TextStyle(fontSize: 28, fontWeight: pw.FontWeight.bold, color: PdfColors.white)),
                    pw.SizedBox(height: 4),
                    pw.Text('Payment Receipt', style: pw.TextStyle(fontSize: 16, color: PdfColor.fromHex('#E0F2F1'))),
                  ],
                ),
              ),
              pw.SizedBox(height: 30),
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: pw.BoxDecoration(color: PdfColor.fromHex('#D1FAE5'), borderRadius: pw.BorderRadius.circular(20)),
                child: pw.Text('PAYMENT SUCCESSFUL', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('#065F46'))),
              ),
              pw.SizedBox(height: 24),
              pw.Table(
                border: pw.TableBorder.all(color: PdfColor.fromHex('#E2E8F0'), width: 0.5),
                children: [
                  _pdfRow('Billing Month', month),
                  _pdfRow('Amount Paid', 'Rs. ${fmtAmt(amount)}'),
                  _pdfRow('Paid On', paidOn),
                  _pdfRow('Transaction ID', txnId),
                  _pdfRow('Payment Mode', paymentMode),
                  _pdfRow('Resident ID', residentId),
                  _pdfRow('Receipt Date', DateFormat('MMM dd, yyyy \u2013 hh:mm a').format(DateTime.now())),
                ],
              ),
              pw.SizedBox(height: 40),
              pw.Divider(color: PdfColor.fromHex('#E2E8F0')),
              pw.SizedBox(height: 12),
              pw.Text('This is a computer-generated receipt and does not require a signature.', style: pw.TextStyle(fontSize: 10, color: PdfColor.fromHex('#94A3B8'))),
              pw.SizedBox(height: 4),
              pw.Text('Powered by SmartStay Hostel Management', style: pw.TextStyle(fontSize: 10, color: PdfColor.fromHex('#94A3B8'))),
            ],
          );
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: 'SmartStay_Receipt_${month.replaceAll(' ', '_')}',
    );
  }

  static pw.TableRow _pdfRow(String label, String value) {
    return pw.TableRow(
      children: [
        pw.Padding(
          padding: const pw.EdgeInsets.all(10),
          child: pw.Text(label, style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('#475569'))),
        ),
        pw.Padding(
          padding: const pw.EdgeInsets.all(10),
          child: pw.Text(value, style: pw.TextStyle(fontSize: 12, color: PdfColor.fromHex('#1E293B'))),
        ),
      ],
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
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: Color(0xFF14B8A6),
            letterSpacing: 0.3,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          value,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: Color(0xFF1E293B),
            letterSpacing: -0.2,
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
          'QUICK ACTIONS',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            color: Color(0xFF64748B),
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, constraints) {
            final isCompact = constraints.maxWidth < 520;
            if (isCompact) {
              return Column(
                children: [
                  _GradientActionButton(
                    label: 'Raise Complaint',
                    icon: Icons.add_moderator_rounded,
                    gradient: const LinearGradient(
                      colors: [Color(0xFFF97316), Color(0xFFFB923C)],
                    ),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => RaiseComplaintScreen(
                            residentId: residentId,
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                  _GradientActionButton(
                    label: 'View Notices',
                    icon: Icons.notifications_active_rounded,
                    gradient: const LinearGradient(
                      colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                    ),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder:
                              (_) => ResidentNoticesScreen(
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
                    icon: Icons.add_moderator_rounded,
                    gradient: const LinearGradient(
                      colors: [Color(0xFFF97316), Color(0xFFFB923C)],
                    ),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => RaiseComplaintScreen(
                            residentId: residentId,
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _GradientActionButton(
                    label: 'View Notices',
                    icon: Icons.notifications_active_rounded,
                    gradient: const LinearGradient(
                      colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                    ),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder:
                              (_) => ResidentNoticesScreen(
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
          height: 64,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: BoxDecoration(
            gradient: widget.gradient,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: widget.gradient.colors.first.withOpacity(0.3),
                blurRadius: 15,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                height: 40,
                width: 40,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(widget.icon, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 16),
              Text(
                widget.label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.2,
                ),
              ),
              const Spacer(),
              const Icon(
                Icons.arrow_forward_ios_rounded,
                color: Colors.white30,
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
        3,
        (index) => _ShimmerEffect(
          child: Container(
            margin: const EdgeInsets.only(bottom: 12),
            height: 90,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
            ),
          ),
        ),
      ),
    );
  }
}

class _ShimmerEffect extends StatefulWidget {
  final Widget child;
  const _ShimmerEffect({required this.child});

  @override
  State<_ShimmerEffect> createState() => _ShimmerEffectState();
}

class _ShimmerEffectState extends State<_ShimmerEffect>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller =
        AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: 1500),
        )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (bounds) {
            return LinearGradient(
              colors: const [
                Color(0xFFF1F5F9),
                Color(0xFFE2E8F0),
                Color(0xFFF1F5F9),
              ],
              stops: const [0.1, 0.5, 0.9],
              begin: Alignment(-1.0 + _controller.value * 2, -0.3),
              end: Alignment(0.0 + _controller.value * 2, 0.3),
            ).createShader(bounds);
          },
          child: widget.child,
        );
      },
    );
  }
}

class _NoticesEmptyCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Center(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF6366F1).withOpacity(0.05),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.notifications_none_rounded,
                color: Color(0xFF6366F1),
                size: 32,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'All Caught Up!',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 15,
                color: Color(0xFF334155),
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'No new announcements for you',
              style: TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
            ),
          ],
        ),
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

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'in progress': return const Color(0xFF3B82F6);
      case 'resolved': return const Color(0xFF10B981);
      case 'closed': return const Color(0xFF64748B);
      default: return const Color(0xFFF59E0B);
    }
  }

  String _statusLabel(String status) {
    switch (status.toLowerCase()) {
      case 'in progress': return 'In Progress';
      case 'resolved': return 'Resolved';
      case 'closed': return 'Closed';
      default: return 'Pending';
    }
  }

  IconData _statusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'in progress': return Icons.autorenew_rounded;
      case 'resolved': return Icons.check_circle_rounded;
      case 'closed': return Icons.cancel_rounded;
      default: return Icons.schedule_rounded;
    }
  }

  Color _priorityColor(String p) {
    switch (p.toLowerCase()) {
      case 'high': return const Color(0xFFEF4444);
      case 'medium': return const Color(0xFFF59E0B);
      default: return const Color(0xFF64748B);
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
    return Container(
      decoration: BoxDecoration(
        color: AdminColors.card(context),
        borderRadius: BorderRadius.circular(24),
        boxShadow: AdminShadows.card,
        border: Border.all(color: AdminColors.border(context)),
      ),
      child: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('complaints')
            .where('residentId', isEqualTo: residentId)
            .snapshots(),
        builder: (context, snap) {
          if (snap.hasError) {
            return Padding(
              padding: const EdgeInsets.all(24),
              child: Center(child: Text('Error loading complaints', style: TextStyle(color: Color(0xFFEF4444), fontSize: 12))),
            );
          }

          final allDocs = snap.data?.docs ?? [];
          // Sort by createdAt desc client-side
          allDocs.sort((a, b) {
            final aTs = (a.data() as Map<String, dynamic>)['createdAt'] as Timestamp?;
            final bTs = (b.data() as Map<String, dynamic>)['createdAt'] as Timestamp?;
            if (aTs == null && bTs == null) return 0;
            if (aTs == null) return 1;
            if (bTs == null) return -1;
            return bTs.compareTo(aTs);
          });

          // Filter: only show active complaints (not resolved/closed)
          final activeDocs = allDocs.where((doc) {
            final s = ((doc.data() as Map<String, dynamic>)['status'] ?? 'pending').toString().toLowerCase();
            return s != 'resolved' && s != 'closed';
          }).take(5).toList();

          final activeCount = activeDocs.length;

          return Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF59E0B).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.error_outline_rounded, color: Color(0xFFF59E0B), size: 24),
                    ),
                    const SizedBox(width: 14),
                    const Text('My Complaints', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, letterSpacing: -0.5)),
                    if (activeCount > 0) ...[
                      const SizedBox(width: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(color: const Color(0xFFEF4444), borderRadius: BorderRadius.circular(10)),
                        child: Text('$activeCount active', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Colors.white)),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 20),
                if (activeDocs.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 32),
                    child: Center(
                      child: Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(color: const Color(0xFF10B981).withOpacity(0.05), shape: BoxShape.circle),
                            child: const Icon(Icons.verified_rounded, color: Color(0xFF10B981), size: 32),
                          ),
                          const SizedBox(height: 16),
                          const Text('All Clear!', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: Color(0xFF334155))),
                          const SizedBox(height: 4),
                          const Text('No active complaints', style: TextStyle(fontSize: 13, color: Color(0xFF94A3B8))),
                        ],
                      ),
                    ),
                  )
                else
                  ScrollableCardContent(
                    maxHeight: 280,
                    child: Column(
                    children: activeDocs.map((doc) {
                      final data = doc.data() as Map<String, dynamic>;
                      final title = (data['title'] ?? 'Untitled').toString();
                      final category = (data['category'] ?? 'General').toString();
                      final status = (data['status'] ?? 'pending').toString();
                      final priority = (data['priority'] ?? 'low').toString();
                      final createdAt = data['createdAt'] as Timestamp?;

                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AdminColors.subtleBg(context),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AdminColors.border(context)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Title + Status badge
                            Row(
                              children: [
                                Container(
                                  width: 3, height: 36,
                                  margin: const EdgeInsets.only(right: 12),
                                  decoration: BoxDecoration(color: _priorityColor(priority), borderRadius: BorderRadius.circular(2)),
                                ),
                                Expanded(
                                  child: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: Color(0xFF334155))),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: _statusColor(status).withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: _statusColor(status).withOpacity(0.3)),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(_statusIcon(status), size: 12, color: _statusColor(status)),
                                      const SizedBox(width: 4),
                                      Text(_statusLabel(status),
                                        style: TextStyle(fontSize: 10, color: _statusColor(status), fontWeight: FontWeight.w700)),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            // Category + Priority + Time
                            Row(
                              children: [
                                const Icon(Icons.label_outline_rounded, size: 13, color: Color(0xFF94A3B8)),
                                const SizedBox(width: 4),
                                Text(category, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF94A3B8))),
                                const SizedBox(width: 12),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: _priorityColor(priority).withOpacity(0.08),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    '${priority[0].toUpperCase()}${priority.substring(1)} priority',
                                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: _priorityColor(priority)),
                                  ),
                                ),
                                const Spacer(),
                                if (createdAt != null) Text(_timeAgo(createdAt.toDate()),
                                  style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
                              ],
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                    ),
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

  Stream<Set<String>> _readStatusStream() {
    return FirebaseFirestore.instance
        .collection('residents')
        .doc(residentId)
        .collection('readStatus')
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => doc.id).toSet());
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

  bool _isRead(String noticeId, Set<String> readIds) {
    return readIds.contains(noticeId);
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
    return Container(
      decoration: BoxDecoration(
        color: AdminColors.card(context),
        borderRadius: BorderRadius.circular(24),
        boxShadow: AdminShadows.card,
        border: Border.all(color: AdminColors.border(context)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF6366F1).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.campaign_outlined,
                        color: Color(0xFF6366F1),
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 14),
                    const Text(
                      'Announcements',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ],
                ),
                TextButton(
                  onPressed: () {
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
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFF6366F1),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text(
                    'View All',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            StreamBuilder<Set<String>>(
              stream: _readStatusStream(),
              builder: (context, readStatusSnap) {
                final readIds = readStatusSnap.data ?? {};

                return StreamBuilder<QuerySnapshot>(
                  stream: _allNoticesStream(),
                  builder: (context, allSnap) {
                    final hostelStream = pgId == null
                        ? Stream<QuerySnapshot?>.value(null)
                        : _hostelNoticesStream();

                    return StreamBuilder<QuerySnapshot?>(
                      stream: hostelStream,
                      builder: (context, hostelSnap) {
                        return StreamBuilder<QuerySnapshot>(
                          stream: _residentNoticesStream(),
                          builder: (context, residentSnap) {
                            if (allSnap.connectionState ==
                                    ConnectionState.waiting ||
                                (pgId != null &&
                                    hostelSnap.connectionState ==
                                        ConnectionState.waiting) ||
                                residentSnap.connectionState ==
                                    ConnectionState.waiting) {
                              return const _NoticesPreviewLoading();
                            }

                            final allDocs = allSnap.data?.docs ?? [];
                            final hostelDocs = hostelSnap.data?.docs ?? [];
                            final residentDocs = residentSnap.data?.docs ?? [];
                            final merged = _mergeNotices(
                              allDocs,
                              hostelDocs,
                              residentDocs,
                            );

                            if (merged.isEmpty) {
                              return _NoticesEmptyCard();
                            }

                            return ScrollableCardContent(
                              maxHeight: 280,
                              child: Column(
                              children: merged.map((doc) {
                                final data = doc.data() as Map<String, dynamic>;
                                final title = (data['title'] ?? 'Notice')
                                    .toString();
                                final message =
                                    (data['message'] ?? '').toString();
                                final createdAt =
                                    data['createdAt'] as Timestamp?;
                                final isRead = _isRead(doc.id, readIds);
                                final noticeType =
                                    (data['noticeType'] ?? 'Notice').toString();

                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: InkWell(
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
                                    borderRadius: BorderRadius.circular(16),
                                    child: Container(
                                      padding: const EdgeInsets.all(16),
                                      decoration: BoxDecoration(
                                        color: isRead
                                            ? AdminColors.subtleBg(context)
                                            : AdminColors.scaffold(context),
                                        borderRadius: BorderRadius.circular(20),
                                        border: Border.all(
                                          color: isRead
                                              ? AdminColors.border(context)
                                              : const Color(0xFF6366F1)
                                                  .withOpacity(0.1),
                                        ),
                                        boxShadow: isRead
                                            ? []
                                            : [
                                                BoxShadow(
                                                  color: const Color(0xFF6366F1)
                                                      .withOpacity(0.05),
                                                  blurRadius: 10,
                                                  offset: const Offset(0, 4),
                                                ),
                                              ],
                                      ),
                                      child: Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Container(
                                            width: 4,
                                            height: 40,
                                            decoration: BoxDecoration(
                                              color: _getNoticeColor(
                                                noticeType,
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(2),
                                            ),
                                          ),
                                          const SizedBox(width: 16),
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
                                                          maxLines: 1,
                                                          overflow:
                                                              TextOverflow
                                                                  .ellipsis,
                                                          style: TextStyle(
                                                            fontSize: 14,
                                                            fontWeight:
                                                                isRead
                                                                    ? FontWeight
                                                                        .w600
                                                                    : FontWeight
                                                                        .w700,
                                                            color: const Color(
                                                              0xFF1E293B,
                                                            ),
                                                          ),
                                                        ),
                                                    ),
                                                    if (!isRead)
                                                      Container(
                                                        width: 8,
                                                        height: 8,
                                                        decoration:
                                                            const BoxDecoration(
                                                              color: Color(
                                                                0xFF6366F1,
                                                              ),
                                                              shape: BoxShape
                                                                  .circle,
                                                            ),
                                                      ),
                                                  ],
                                                ),
                                                const SizedBox(height: 4),
                                                Text(
                                                    message,
                                                    maxLines: 1,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                    style: const TextStyle(
                                                      fontSize: 12,
                                                      color: Color(0xFF64748B),
                                                    ),
                                                  ),
                                                const SizedBox(height: 8),
                                                Row(
                                                  mainAxisAlignment:
                                                      MainAxisAlignment
                                                          .spaceBetween,
                                                  children: [
                                                    Text(
                                                      _formatDate(createdAt),
                                                      style: const TextStyle(
                                                        fontSize: 11,
                                                        color: Color(
                                                          0xFF94A3B8,
                                                        ),
                                                      ),
                                                    ),
                                                     Container(
                                                       padding: const EdgeInsets.symmetric(
                                                         horizontal: 8,
                                                         vertical: 2,
                                                       ),
                                                       decoration: BoxDecoration(
                                                         color: _getNoticeColor(
                                                           noticeType,
                                                         ).withOpacity(0.1),
                                                         borderRadius: BorderRadius.circular(6),
                                                       ),
                                                       child: Text(
                                                         noticeType.toUpperCase(),
                                                         style: TextStyle(
                                                           fontSize: 10,
                                                           fontWeight: FontWeight.w700,
                                                           color: _getNoticeColor(noticeType),
                                                         ),
                                                       ),
                                                     ),
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
                               }).toList(),
                             ),
                             );
                           },
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

  Color _getNoticeColor(String type) {
    switch (type.toLowerCase()) {
      case 'warning':
        return const Color(0xFFEF4444);
      case 'maintenance':
        return const Color(0xFFF59E0B);
      case 'payment':
        return const Color(0xFF10B981);
      default:
        return const Color(0xFF6366F1);
    }
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
