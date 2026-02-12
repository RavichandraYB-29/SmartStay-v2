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
            const SizedBox(height: 6),
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
      ],
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

    final pgsStream = FirebaseFirestore.instance
        .collectionGroup('pgs')
        .where('adminId', isEqualTo: adminId)
        .snapshots();
    final pgsFallbackStream = FirebaseFirestore.instance
        .collectionGroup('pgs')
        .where('ownerId', isEqualTo: adminId)
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
      stream: pgsStream,
      builder: (context, pgsSnap) {
        if (pgsSnap.hasError) {
          return _buildStatsGrid(
            context: context,
            pgDocs: const [],
            residentsStream: residentsStream,
            complaintsStream: complaintsStream,
            paymentsStream: paymentsStream,
          );
        }
        if (!pgsSnap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final pgDocs = pgsSnap.data?.docs ?? [];
        if (pgDocs.isEmpty) {
          return StreamBuilder<QuerySnapshot>(
            stream: pgsFallbackStream,
            builder: (context, fallbackSnap) {
              if (fallbackSnap.hasError) {
                return _buildStatsGrid(
                  context: context,
                  pgDocs: const [],
                  residentsStream: residentsStream,
                  complaintsStream: complaintsStream,
                  paymentsStream: paymentsStream,
                );
              }
              if (!fallbackSnap.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final fallbackPgs = fallbackSnap.data?.docs ?? [];
              return _buildStatsGrid(
                context: context,
                pgDocs: fallbackPgs,
                residentsStream: residentsStream,
                complaintsStream: complaintsStream,
                paymentsStream: paymentsStream,
              );
            },
          );
        }
        return _buildStatsGrid(
          context: context,
          pgDocs: pgDocs,
          residentsStream: residentsStream,
          complaintsStream: complaintsStream,
          paymentsStream: paymentsStream,
        );
      },
    );
  }
}

Widget _buildStatsGrid({
  required BuildContext context,
  required List<QueryDocumentSnapshot> pgDocs,
  required Stream<QuerySnapshot> residentsStream,
  required Stream<QuerySnapshot> complaintsStream,
  required Stream<QuerySnapshot> paymentsStream,
}) {
  int totalBeds = 0;
  int availableBeds = 0;
  for (final doc in pgDocs) {
    final data = doc.data() as Map<String, dynamic>;
    final tbRaw = data['totalBeds'];
    final abRaw = data['availableBeds'];
    final tb = tbRaw is int ? tbRaw : int.tryParse('$tbRaw') ?? 0;
    final ab = abRaw is int ? abRaw : int.tryParse('$abRaw') ?? 0;
    totalBeds += tb;
    availableBeds += ab;
  }

  return StreamBuilder<QuerySnapshot>(
    stream: residentsStream,
    builder: (context, residentsSnap) {
      final residentsDocs = residentsSnap.data?.docs ?? [];
      final totalResidents = residentsDocs.length;
      final allocatedResidents = residentsDocs.where((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return data['isAllocated'] == true;
      }).length;

      final actualOccupiedBeds = (totalBeds - availableBeds).clamp(
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
          final openComplaints = complaintsDocs.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final status = data['status']?.toString().toLowerCase() ?? '';
            return status != 'resolved' && status != 'closed';
          }).length;

          return StreamBuilder<QuerySnapshot>(
            stream: paymentsStream,
            builder: (context, paymentsSnap) {
              final paymentDocs = paymentsSnap.data?.docs ?? [];
              final pendingFromPayments = _sumPendingFeesFromPayments(
                paymentDocs,
              );
              final pendingFromResidents = _sumPendingFeesFromResidents(
                residentsDocs,
              );

              final pendingTotal = pendingFromPayments > 0
                  ? pendingFromPayments
                  : pendingFromResidents;

              final cards = [
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
                  change: '${_countPendingResidents(paymentDocs)} residents',
                  changeType: 'warning',
                ),
                _StatCard(
                  icon: Icons.notifications_active,
                  title: 'Open Complaints',
                  value: openComplaints.toString(),
                  change:
                      '${complaintsDocs.where((c) {
                        final data = c.data() as Map<String, dynamic>;
                        final createdAt = data['createdAt'] as Timestamp?;
                        if (createdAt == null) return false;
                        final now = DateTime.now();
                        final created = createdAt.toDate();
                        return now.difference(created).inDays == 0;
                      }).length} new today',
                  changeType: 'warning',
                ),
              ];

              return LayoutBuilder(
                builder: (context, constraints) {
                  final width = constraints.maxWidth;
                  final crossAxisCount = width >= 1100
                      ? 4
                      : width >= 760
                      ? 2
                      : 1;
                  return GridView.count(
                    crossAxisCount: crossAxisCount,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    childAspectRatio: 2.7,
                    children: cards,
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
      padding: const EdgeInsets.all(10),
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
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isCompact = constraints.maxHeight < 120;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
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
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
                            color: Theme.of(context).textTheme.bodySmall?.color,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          value,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        if (!isCompact && change != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            change!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 10,
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
                      ],
                    ),
                  ),
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: iconBgColor,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(icon, color: iconColor, size: 18),
                  ),
                ],
              ),
              if (showProgress && progressValue != null) ...[
                SizedBox(height: isCompact ? 4 : 6),
                if (!isCompact)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Occupancy Rate',
                        style: TextStyle(
                          fontSize: 10,
                          color: Theme.of(context).textTheme.bodySmall?.color,
                        ),
                      ),
                      if (occupancy != null)
                        Text(
                          '$occupancy%',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: Theme.of(
                              context,
                            ).textTheme.bodyMedium?.color,
                          ),
                        ),
                    ],
                  ),
                if (!isCompact) const SizedBox(height: 3),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: progressValue!,
                    minHeight: isCompact ? 3 : 4,
                    backgroundColor: Theme.of(context).dividerColor,
                    valueColor: AlwaysStoppedAnimation(iconColor),
                  ),
                ),
              ],
            ],
          );
        },
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
          _ActionButton(
            label: 'Send Notice',
            icon: Icons.notifications,
            gradient: const [Color(0xFF9333EA), Color(0xFFEC4899)],
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SendNoticeScreen()),
              );
            },
          ),
        ],
      ),
    ],
  );
}

/* =========================================================
   SEND NOTICE (UI ONLY)
========================================================= */

class SendNoticeScreen extends StatefulWidget {
  final VoidCallback? onBack;

  const SendNoticeScreen({super.key, this.onBack});

  @override
  State<SendNoticeScreen> createState() => _SendNoticeScreenState();
}

class _PgOption {
  final String pgId;
  final String label;
  final String hostelId;

  const _PgOption({
    required this.pgId,
    required this.label,
    required this.hostelId,
  });
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
    {
      'value': 'general',
      'label': 'General',
      'description': 'General announcements and updates',
      'color': Color(0xFF4F46E5),
    },
    {
      'value': 'maintenance',
      'label': 'Maintenance',
      'description': 'Facility maintenance schedules',
      'color': Color(0xFF7C3AED),
    },
    {
      'value': 'payment',
      'label': 'Payment',
      'description': 'Fee reminders and payment notices',
      'color': Color(0xFFEA580C),
    },
    {
      'value': 'warning',
      'label': 'Warning',
      'description': 'Important warnings and alerts',
      'color': Color(0xFFDC2626),
    },
  ];

  bool get _isFormValid {
    if (_titleController.text.trim().isEmpty) return false;
    if (_messageController.text.trim().isEmpty) return false;
    if (_noticeType.isEmpty) return false;
    if (_scope.isEmpty) return false;
    if (_scope == 'PG' && _selectedPgId.isEmpty) return false;
    if (_scope == 'RESIDENT' && _selectedResidentId.isEmpty) {
      return false;
    }
    return true;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    if (!_isFormValid) return;
    final adminUid = FirebaseAuth.instance.currentUser?.uid;
    if (adminUid == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Failed to publish notice')));
      return;
    }

    try {
      final pgIds = <String>[];
      if (_scope == 'ALL') {
        final pgs = await _loadPgsForAdmin();
        pgIds.addAll(pgs.map((p) => p.pgId));
      } else if (_scope == 'PG') {
        pgIds.add(_selectedPgId);
      }

      final docRef = FirebaseFirestore.instance.collection('notices').doc();
      final payload = <String, dynamic>{
        'noticeId': docRef.id,
        'title': _titleController.text.trim(),
        'message': _messageController.text.trim(),
        'noticeType': _noticeTypeLabel(_noticeType),
        'scope': _scope,
        'senderRole': 'admin',
        'createdByAdminId': adminUid,
        'hostelOwnerId': adminUid,
        'pgIds': pgIds,
        'residentIds': _scope == 'RESIDENT'
            ? [_selectedResidentId]
            : <String>[],
        'isActive': true,
        'createdAt': FieldValue.serverTimestamp(),
      };

      await docRef.set(payload);

      debugPrint('Notice published: ${docRef.id}');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Notice published successfully')),
      );
    } catch (_) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Failed to publish notice')));
    }
  }

  String _noticeTypeLabel(String raw) {
    switch (raw.toLowerCase()) {
      case 'general':
        return 'General';
      case 'maintenance':
        return 'Maintenance';
      case 'payment':
        return 'Payment';
      case 'warning':
        return 'Warning';
      default:
        return raw;
    }
  }

  Future<List<_PgOption>> _loadPgsForAdmin() async {
    final adminUid = FirebaseAuth.instance.currentUser?.uid;
    if (adminUid == null) return [];

    final hostelsByAdmin = await FirebaseFirestore.instance
        .collection('hostels')
        .where('adminId', isEqualTo: adminUid)
        .get();
    final hostelsByOwner = await FirebaseFirestore.instance
        .collection('hostels')
        .where('ownerId', isEqualTo: adminUid)
        .get();

    final hostels = <String, QueryDocumentSnapshot>{};
    for (final doc in hostelsByAdmin.docs) {
      hostels[doc.id] = doc;
    }
    for (final doc in hostelsByOwner.docs) {
      hostels[doc.id] = doc;
    }

    final pgs = <_PgOption>[];
    for (final entry in hostels.entries) {
      final hostelId = entry.key;
      final hostelData = entry.value.data() as Map<String, dynamic>;
      final hostelName =
          (hostelData['name'] ?? hostelData['hostelName'] ?? 'Hostel')
              .toString();

      final pgSnap = await FirebaseFirestore.instance
          .collection('hostels')
          .doc(hostelId)
          .collection('pgs')
          .get();
      for (final pgDoc in pgSnap.docs) {
        final pgData = pgDoc.data();
        final pgName = (pgData['name'] ?? pgData['pgName'] ?? 'PG').toString();
        pgs.add(
          _PgOption(
            pgId: pgDoc.id,
            hostelId: hostelId,
            label: '$pgName • $hostelName',
          ),
        );
      }
    }

    pgs.sort((a, b) => a.label.compareTo(b.label));
    return pgs;
  }

  void _handleCancel() {
    if (widget.onBack != null) {
      widget.onBack!();
      return;
    }
    Navigator.maybePop(context);
  }

  @override
  Widget build(BuildContext context) {
    Map<String, Object?>? selectedType;
    for (final item in _noticeTypes) {
      if (item['value'] == _noticeType) {
        selectedType = item;
        break;
      }
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF7F7FB),
      body: SafeArea(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                border: Border(
                  bottom: BorderSide(color: Theme.of(context).dividerColor),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back),
                    onPressed: _handleCancel,
                  ),
                  Container(
                    height: 44,
                    width: 44,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF4F46E5), Color(0xFF7C3AED)],
                      ),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF4F46E5).withOpacity(0.25),
                          blurRadius: 10,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.description_outlined,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Send Notice',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Dashboard → Communication → Send Notice',
                          style: TextStyle(fontSize: 12, color: Colors.black54),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16),
                            decoration: const BoxDecoration(
                              gradient: LinearGradient(
                                colors: [Color(0xFFEFF1FF), Color(0xFFF5EEFF)],
                              ),
                              borderRadius: BorderRadius.vertical(
                                top: Radius.circular(16),
                              ),
                            ),
                            child: const Row(
                              children: [
                                Icon(
                                  Icons.description,
                                  color: Color(0xFF4F46E5),
                                ),
                                SizedBox(width: 8),
                                Text(
                                  'Notice Details',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Notice Title *',
                                  style: TextStyle(fontSize: 12),
                                ),
                                const SizedBox(height: 8),
                                TextField(
                                  controller: _titleController,
                                  decoration: const InputDecoration(
                                    hintText:
                                        'Enter notice title (e.g., Holiday Announcement)',
                                    border: OutlineInputBorder(),
                                  ),
                                  onChanged: (_) => setState(() {}),
                                ),
                                const SizedBox(height: 20),
                                const Text(
                                  'Notice Description *',
                                  style: TextStyle(fontSize: 12),
                                ),
                                const SizedBox(height: 8),
                                TextField(
                                  controller: _messageController,
                                  maxLines: 6,
                                  decoration: const InputDecoration(
                                    hintText:
                                        'Enter your notice message here...',
                                    border: OutlineInputBorder(),
                                  ),
                                  onChanged: (_) => setState(() {}),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  '${_messageController.text.length} characters',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: Colors.black54,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16),
                            decoration: const BoxDecoration(
                              gradient: LinearGradient(
                                colors: [Color(0xFFF4EDFF), Color(0xFFFFF0F8)],
                              ),
                              borderRadius: BorderRadius.vertical(
                                top: Radius.circular(16),
                              ),
                            ),
                            child: const Row(
                              children: [
                                Icon(
                                  Icons.local_offer,
                                  color: Color(0xFF7C3AED),
                                ),
                                SizedBox(width: 8),
                                Text(
                                  'Notice Type',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              children: [
                                Wrap(
                                  spacing: 12,
                                  runSpacing: 12,
                                  children: _noticeTypes.map((type) {
                                    final isSelected =
                                        _noticeType == type['value'];
                                    final typeColor = type['color'] as Color;
                                    return InkWell(
                                      onTap: () {
                                        setState(() {
                                          _noticeType = type['value'] as String;
                                        });
                                      },
                                      borderRadius: BorderRadius.circular(14),
                                      child: Container(
                                        width: 240,
                                        padding: const EdgeInsets.all(14),
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(
                                            14,
                                          ),
                                          border: Border.all(
                                            color: isSelected
                                                ? typeColor
                                                : Theme.of(
                                                    context,
                                                  ).dividerColor,
                                            width: 2,
                                          ),
                                          color: isSelected
                                              ? typeColor.withOpacity(0.08)
                                              : Theme.of(context).cardColor,
                                          boxShadow: isSelected
                                              ? [
                                                  BoxShadow(
                                                    color: typeColor
                                                        .withOpacity(0.15),
                                                    blurRadius: 12,
                                                    offset: const Offset(0, 6),
                                                  ),
                                                ]
                                              : [],
                                        ),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Container(
                                                  height: 10,
                                                  width: 10,
                                                  decoration: BoxDecoration(
                                                    color: typeColor,
                                                    shape: BoxShape.circle,
                                                  ),
                                                ),
                                                const SizedBox(width: 8),
                                                Text(
                                                  type['label'] as String,
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.w600,
                                                    color: isSelected
                                                        ? typeColor
                                                        : Colors.black87,
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 8),
                                            Text(
                                              type['description'] as String,
                                              style: const TextStyle(
                                                fontSize: 12,
                                                color: Colors.black54,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  }).toList(),
                                ),
                                if (selectedType != null) ...[
                                  const SizedBox(height: 16),
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      gradient: const LinearGradient(
                                        colors: [
                                          Color(0xFFEFF1FF),
                                          Color(0xFFF5EEFF),
                                        ],
                                      ),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: const Color(
                                          0xFF4F46E5,
                                        ).withOpacity(0.2),
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        const Text(
                                          'Notice will be marked as:',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.black87,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 10,
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            color:
                                                selectedType['color'] as Color,
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                          ),
                                          child: Text(
                                            selectedType['label'] as String,
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16),
                            decoration: const BoxDecoration(
                              gradient: LinearGradient(
                                colors: [Color(0xFFEAFBF7), Color(0xFFE6F7FF)],
                              ),
                              borderRadius: BorderRadius.vertical(
                                top: Radius.circular(16),
                              ),
                            ),
                            child: const Row(
                              children: [
                                Icon(Icons.people, color: Color(0xFF0F766E)),
                                SizedBox(width: 8),
                                Text(
                                  'Audience Selection',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              children: [
                                RadioListTile<String>(
                                  value: 'ALL',
                                  groupValue: _scope,
                                  onChanged: (value) {
                                    setState(() {
                                      _scope = value ?? '';
                                      _selectedPgId = '';
                                      _selectedResidentId = '';
                                      _selectedResidentLabel = '';
                                    });
                                  },
                                  title: const Text('All Residents'),
                                  subtitle: const Text(
                                    'Send to every resident',
                                  ),
                                  secondary: const Icon(Icons.groups),
                                ),
                                RadioListTile<String>(
                                  value: 'PG',
                                  groupValue: _scope,
                                  onChanged: (value) {
                                    setState(() {
                                      _scope = value ?? '';
                                      _selectedPgId = '';
                                      _selectedResidentId = '';
                                      _selectedResidentLabel = '';
                                    });
                                  },
                                  title: const Text('Specific PG'),
                                  subtitle: const Text('Send to one PG'),
                                  secondary: const Icon(Icons.apartment),
                                ),
                                RadioListTile<String>(
                                  value: 'RESIDENT',
                                  groupValue: _scope,
                                  onChanged: (value) {
                                    setState(() {
                                      _scope = value ?? '';
                                      _selectedPgId = '';
                                      _selectedResidentId = '';
                                      _selectedResidentLabel = '';
                                    });
                                  },
                                  title: const Text('Specific Resident'),
                                  subtitle: const Text('Send to one person'),
                                  secondary: const Icon(Icons.person),
                                ),
                                const SizedBox(height: 12),
                                if (_scope == 'PG') ...[
                                  const Align(
                                    alignment: Alignment.centerLeft,
                                    child: Text(
                                      'Select PG *',
                                      style: TextStyle(fontSize: 12),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  FutureBuilder<List<_PgOption>>(
                                    future: _pgsFuture,
                                    builder: (context, snap) {
                                      final items = snap.data ?? [];
                                      return DropdownButtonFormField<String>(
                                        value: _selectedPgId.isEmpty
                                            ? null
                                            : _selectedPgId,
                                        decoration: const InputDecoration(
                                          border: OutlineInputBorder(),
                                          hintText: 'Select PG',
                                        ),
                                        items: items.map((pg) {
                                          return DropdownMenuItem<String>(
                                            value: pg.pgId,
                                            child: Text(pg.label),
                                          );
                                        }).toList(),
                                        onChanged: (value) {
                                          setState(() {
                                            _selectedPgId = value ?? '';
                                          });
                                        },
                                      );
                                    },
                                  ),
                                ],
                                if (_scope == 'RESIDENT') ...[
                                  const Align(
                                    alignment: Alignment.centerLeft,
                                    child: Text(
                                      'Select Resident *',
                                      style: TextStyle(fontSize: 12),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  StreamBuilder<QuerySnapshot>(
                                    stream: FirebaseFirestore.instance
                                        .collection('residents')
                                        .where(
                                          'adminId',
                                          isEqualTo: FirebaseAuth
                                              .instance
                                              .currentUser
                                              ?.uid,
                                        )
                                        .snapshots(),
                                    builder: (context, snap) {
                                      final items = snap.data?.docs ?? [];
                                      return DropdownButtonFormField<String>(
                                        value: _selectedResidentId.isEmpty
                                            ? null
                                            : _selectedResidentId,
                                        decoration: const InputDecoration(
                                          border: OutlineInputBorder(),
                                          hintText: 'Select resident',
                                        ),
                                        items: items.map((doc) {
                                          final data =
                                              doc.data()
                                                  as Map<String, dynamic>;
                                          final label =
                                              data['name'] ??
                                              data['fullName'] ??
                                              data['email'] ??
                                              'Resident';
                                          return DropdownMenuItem<String>(
                                            value: doc.id,
                                            child: Text(label.toString()),
                                          );
                                        }).toList(),
                                        onChanged: (value) {
                                          final selected = items
                                              .where((doc) => doc.id == value)
                                              .toList();
                                          String label = '';
                                          if (selected.isNotEmpty) {
                                            final data =
                                                selected.first.data()
                                                    as Map<String, dynamic>;
                                            label =
                                                (data['name'] ??
                                                        data['fullName'] ??
                                                        data['email'] ??
                                                        '')
                                                    .toString();
                                          }
                                          setState(() {
                                            _selectedResidentId = value ?? '';
                                            _selectedResidentLabel = label;
                                          });
                                        },
                                      );
                                    },
                                  ),
                                ],
                                if (_scope.isNotEmpty) ...[
                                  const SizedBox(height: 16),
                                  Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      gradient: const LinearGradient(
                                        colors: [
                                          Color(0xFFEAFBF7),
                                          Color(0xFFE6F7FF),
                                        ],
                                      ),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: const Color(
                                          0xFF0F766E,
                                        ).withOpacity(0.2),
                                      ),
                                    ),
                                    child: Text(
                                      _scope == 'ALL'
                                          ? '✓ All residents across your PGs'
                                          : _scope == 'PG'
                                          ? _selectedPgId.isEmpty
                                                ? 'Please select a PG'
                                                : '✓ Residents in selected PG'
                                          : _selectedResidentId.isEmpty
                                          ? 'Please select a resident'
                                          : '✓ $_selectedResidentLabel',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Color(0xFF0F766E),
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _handleCancel,
                            icon: const Icon(Icons.close),
                            label: const Text('Cancel'),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _isFormValid ? _handleSubmit : null,
                            icon: const Icon(Icons.send),
                            label: const Text('Publish Notice'),
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              backgroundColor: const Color(0xFF4F46E5),
                              foregroundColor: Colors.white,
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
      ),
    );
  }
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

class _OccupancyByFloor extends StatefulWidget {
  final String adminId;
  const _OccupancyByFloor({required this.adminId});

  @override
  State<_OccupancyByFloor> createState() => _OccupancyByFloorState();
}

class _OccupancyByFloorState extends State<_OccupancyByFloor> {
  String? _selectedPgId;

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
          const SizedBox(height: 14),
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collectionGroup('pgs')
                .where('adminId', isEqualTo: widget.adminId)
                .snapshots(),
            builder: (context, pgsSnap) {
              if (!pgsSnap.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final pgs = pgsSnap.data!.docs;
              if (pgs.isEmpty) {
                return StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collectionGroup('pgs')
                      .where('ownerId', isEqualTo: widget.adminId)
                      .snapshots(),
                  builder: (context, fallbackSnap) {
                    if (!fallbackSnap.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    return _buildPgFloorSection(fallbackSnap.data!.docs);
                  },
                );
              }

              return _buildPgFloorSection(pgs);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildPgFloorSection(List<QueryDocumentSnapshot> pgs) {
    if (pgs.isEmpty) {
      return const Text('No floors available', style: AppTextStyles.bodySmall);
    }

    if (_selectedPgId == null || !pgs.any((pg) => pg.id == _selectedPgId)) {
      _selectedPgId = pgs.first.id;
    }

    final selectedPg = pgs.firstWhere(
      (pg) => pg.id == _selectedPgId,
      orElse: () => pgs.first,
    );
    final pgData = selectedPg.data() as Map<String, dynamic>;
    final pgLabel = (pgData['name'] ?? pgData['pgName'] ?? 'PG').toString();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DropdownButtonFormField<String>(
          value: _selectedPgId,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            labelText: 'Select PG',
            isDense: true,
          ),
          items: pgs.map((pg) {
            final data = pg.data() as Map<String, dynamic>;
            final label = (data['name'] ?? data['pgName'] ?? 'PG').toString();
            return DropdownMenuItem(value: pg.id, child: Text(label));
          }).toList(),
          onChanged: (value) {
            setState(() => _selectedPgId = value);
          },
        ),
        const SizedBox(height: 12),
        Text(pgLabel, style: AppTextStyles.bodySmall),
        const SizedBox(height: 12),
        StreamBuilder<QuerySnapshot>(
          stream: selectedPg.reference
              .collection('floors')
              .orderBy('floorIndex')
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
                final floorData = floor.data() as Map<String, dynamic>;
                final floorNameRaw = floorData['floorName'];
                final floorIndex = floorData['floorIndex'];
                final floorName = (floorNameRaw ?? '').toString().trim().isEmpty
                    ? 'Floor ${floorIndex ?? ''}'
                    : floorNameRaw.toString();

                final totalRaw = floorData['totalBeds'];
                final availRaw = floorData['availableBeds'];
                final total = totalRaw is int
                    ? totalRaw
                    : int.tryParse('$totalRaw') ?? 0;
                final available = availRaw is int
                    ? availRaw
                    : int.tryParse('$availRaw') ?? 0;
                final occupied = (total - available).clamp(0, total);

                if (total == 0) {
                  return _emptyFloorRow(context, floorName);
                }

                final percentage = (occupied / total).clamp(0.0, 1.0);

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
                            '$occupied/$total',
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
              }).toList(),
            );
          },
        ),
      ],
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

int _countPendingResidents(List<QueryDocumentSnapshot> payments) {
  int count = 0;
  for (final doc in payments) {
    final data = doc.data() as Map<String, dynamic>;
    final status = data['status']?.toString().toLowerCase() ?? '';
    final isPaid = data['isPaid'] == true;
    if (status == 'pending' || (!isPaid && status != 'paid')) {
      count++;
    }
  }
  return count;
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
