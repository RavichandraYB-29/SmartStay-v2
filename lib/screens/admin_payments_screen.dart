import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

/// Full-page payments screen for admin — shows Paid and Pending residents.
/// Pending = allocated residents whose due date has passed but haven't paid
/// for the current month. Paid = residents with a payment record this month.
class AdminPaymentsScreen extends StatefulWidget {
  final String adminId;
  const AdminPaymentsScreen({super.key, required this.adminId});

  @override
  State<AdminPaymentsScreen> createState() => _AdminPaymentsScreenState();
}

class _AdminPaymentsScreenState extends State<AdminPaymentsScreen> {
  String _searchQuery = '';
  String _selectedMonth = _currentMonthLabel();
  String _statusFilter = 'All';

  // Caches
  final Map<String, String> _locationCache = {};
  final Map<String, int> _rentCache = {};
  final Map<String, String> _nameCache = {};

  static String _currentMonthLabel() {
    final now = DateTime.now();
    return DateFormat('MMMM yyyy').format(now);
  }

  /// Calculate next due date from allocation date
  static DateTime? _nextDueDate(Timestamp? allocTs) {
    if (allocTs == null) return null;
    final allocDate = allocTs.toDate();
    final now = DateTime.now();
    final joinDay = allocDate.day.clamp(1, 28);

    var dueDate = DateTime(allocDate.year, allocDate.month + 1, joinDay);

    while (dueDate.isBefore(now)) {
      final nextMonth = DateTime(dueDate.year, dueDate.month + 1, 1);
      final lastDay = DateTime(nextMonth.year, nextMonth.month + 1, 0).day;
      final d = joinDay > lastDay ? lastDay : joinDay;
      dueDate = DateTime(nextMonth.year, nextMonth.month, d);
    }
    return dueDate;
  }

  /// Check if a due date has passed (resident should have paid by now)
  static bool _isDueDatePassed(Timestamp? allocTs) {
    if (allocTs == null) return false;
    final allocDate = allocTs.toDate();
    final now = DateTime.now();
    final joinDay = allocDate.day.clamp(1, 28);

    // The current period due date
    var periodDue = DateTime(now.year, now.month, joinDay);
    return now.isAfter(periodDue) || now.isAtSameMomentAs(periodDue);
  }

  Future<Map<String, dynamic>> _resolveRowData(Map<String, dynamic> d, bool isPaid, String residentId) async {
    String location = '-';
    int rent = 0;
    String name = (d['residentName'] ?? d['fullName'] ?? d['residentId'] ?? 'Resident').toString();

    // 1. Resolve Name (for Paid records where it might be missing)
    if (isPaid && d['residentName'] == null && d['fullName'] == null) {
      if (_nameCache.containsKey(residentId)) {
        name = _nameCache[residentId]!;
      } else {
        try {
          final snap = await FirebaseFirestore.instance.collection('residents').doc(residentId).get();
          if (snap.exists) {
            name = (snap.data()?['fullName'] ?? snap.data()?['name'] ?? residentId).toString();
            _nameCache[residentId] = name;
          }
        } catch (_) {}
      }
    }

    // 2. Resolve Location and Rent
    final hostelId = d['hostelId']?.toString();
    final pgId = d['pgId']?.toString();
    final floorId = d['floorId']?.toString();
    final roomId = d['roomId']?.toString();

    if (hostelId != null && pgId != null) {
      final locKey = '$hostelId/$pgId/$floorId/$roomId';
      if (_locationCache.containsKey(locKey) && _rentCache.containsKey(locKey)) {
        location = _locationCache[locKey]!;
        rent = _rentCache[locKey]!;
      } else {
        String pgName = '';
        String roomNumber = '';
        try {
          final pgSnap = await FirebaseFirestore.instance.collection('hostels').doc(hostelId).collection('pgs').doc(pgId).get();
          if (pgSnap.exists) {
            pgName = (pgSnap.data()?['name'] ?? pgSnap.data()?['pgName'] ?? 'PG').toString();
          }
        } catch (_) {}

        if (floorId != null && roomId != null) {
          try {
            final roomSnap = await FirebaseFirestore.instance
                .collection('hostels').doc(hostelId)
                .collection('pgs').doc(pgId)
                .collection('floors').doc(floorId)
                .collection('rooms').doc(roomId)
                .get();
            if (roomSnap.exists) {
              final rd = roomSnap.data()!;
              roomNumber = (rd['roomNumber'] ?? rd['name'] ?? '').toString();
              rent = _toInt(rd['rentPerBed'] ?? rd['monthlyFee'] ?? 0);
            }
          } catch (_) {}
        }
        location = roomNumber.isNotEmpty ? '$pgName · Room $roomNumber' : (pgName.isNotEmpty ? pgName : '-');
        _locationCache[locKey] = location;
        _rentCache[locKey] = rent;
      }
    }

    return {'name': name, 'location': location, 'rent': rent};
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF1E293B)),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'All Payments',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: Color(0xFF1E293B), fontFamily: 'Inter', letterSpacing: -0.3),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: const Color(0xFFF1F5F9)),
        ),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    // We need two streams: residents + payments
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('residents')
          .where('adminId', isEqualTo: widget.adminId)
          .where('isAllocated', isEqualTo: true)
          .snapshots(),
      builder: (ctx, residentSnap) {
        if (residentSnap.hasError) {
          return Center(child: Text('Error: ${residentSnap.error}', style: const TextStyle(color: Color(0xFFEF4444))));
        }
        if (!residentSnap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('payments')
              .where('adminId', isEqualTo: widget.adminId)
              .orderBy('paidAt', descending: true)
              .snapshots(),
          builder: (ctx, paymentSnap) {
            if (paymentSnap.hasError) {
              return Center(child: Text('Error: ${paymentSnap.error}', style: const TextStyle(color: Color(0xFFEF4444))));
            }
            if (!paymentSnap.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final residents = residentSnap.data!.docs;
            final payments = paymentSnap.data!.docs;

            // Build month options from payments
            final Set<String> monthOptions = {_currentMonthLabel()};
            for (final p in payments) {
              final m = (p.data() as Map<String, dynamic>)['month']?.toString() ?? '';
              if (m.isNotEmpty) monthOptions.add(m);
            }
            final sortedMonths = monthOptions.toList()
              ..sort((a, b) => b.compareTo(a));

            if (!monthOptions.contains(_selectedMonth)) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) setState(() => _selectedMonth = _currentMonthLabel());
              });
            }

            // Build a set of residentIds who paid for the selected month
            final Set<String> paidResidentIds = {};
            final List<Map<String, dynamic>> paidRecords = [];
            for (final doc in payments) {
              final d = doc.data() as Map<String, dynamic>;
              final status = d['status']?.toString().toLowerCase() ?? '';
              final isPaid = status == 'paid' || d['isPaid'] == true;
              final month = d['month']?.toString() ?? '';
              if (isPaid && month == _selectedMonth) {
                paidResidentIds.add(d['residentId']?.toString() ?? '');
                paidRecords.add({...d, '_docId': doc.id});
              }
            }

            // Build pending list: allocated residents who should have paid but haven't
            final List<Map<String, dynamic>> pendingRecords = [];
            final now = DateTime.now();
            final selectedIsCurrentMonth = _selectedMonth == _currentMonthLabel();

            for (final doc in residents) {
              final d = doc.data() as Map<String, dynamic>;
              final residentId = doc.id;

              // Skip if already paid
              if (paidResidentIds.contains(residentId)) continue;

              final alloc = d['allocationDetails'] as Map<String, dynamic>? ?? {};
              final allocTs = alloc['allocatedAt'] as Timestamp? ?? d['allocatedAt'] as Timestamp?;

              // For current month: check if due date has passed
              if (selectedIsCurrentMonth) {
                if (!_isDueDatePassed(allocTs)) continue;
              }

              final fullName = (d['fullName'] ?? d['name'] ?? 'Resident').toString();
              final dueDate = _nextDueDate(allocTs);
              final daysOverdue = dueDate != null && now.isAfter(dueDate)
                  ? now.difference(dueDate).inDays
                  : (dueDate != null ? -dueDate.difference(now).inDays : 0);

              pendingRecords.add({
                'residentId': residentId,
                'residentName': fullName,
                'status': 'pending',
                'month': _selectedMonth,
                'dueDate': dueDate,
                'daysOverdue': daysOverdue,
                'hostelId': alloc['hostelId'] ?? d['hostelId'],
                'pgId': alloc['pgId'] ?? d['pgId'],
                'floorId': alloc['floorId'] ?? d['floorId'],
                'roomId': alloc['roomId'] ?? d['roomId'],
              });
            }

            // Combine based on filter
            List<Map<String, dynamic>> displayList = [];
            if (_statusFilter == 'Paid') {
              displayList = paidRecords;
            } else if (_statusFilter == 'Pending') {
              displayList = pendingRecords;
            } else {
              displayList = [...paidRecords, ...pendingRecords];
            }

            // Apply search
            if (_searchQuery.isNotEmpty) {
              final q = _searchQuery.toLowerCase();
              displayList = displayList.where((d) {
                final name = (d['residentName'] ?? d['fullName'] ?? '').toString().toLowerCase();
                return name.contains(q);
              }).toList();
            }

            // Stats
            final paidCount = paidRecords.length;
            final pendingCount = pendingRecords.length;
            int totalCollected = 0;
            for (final r in paidRecords) {
              totalCollected += _toInt(r['amount'] ?? r['monthlyFee'] ?? 0);
            }

            return Column(
              children: [
                // ── Summary Stats ──
                Container(
                  margin: const EdgeInsets.all(20),
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFF10B981), Color(0xFF059669)],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [BoxShadow(color: const Color(0xFF10B981).withOpacity(0.3), blurRadius: 20, offset: const Offset(0, 8))],
                  ),
                  child: Row(
                    children: [
                      _StatBadge(label: 'Paid', value: '$paidCount', icon: Icons.check_circle_rounded),
                      const SizedBox(width: 20),
                      _StatBadge(label: 'Pending', value: '$pendingCount', icon: Icons.schedule_rounded),
                      const SizedBox(width: 20),
                      _StatBadge(label: 'Collected', value: '₹${NumberFormat('#,##,###').format(totalCollected)}', icon: Icons.account_balance_wallet_rounded),
                    ],
                  ),
                ),

                // ── Filters Row ──
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: [
                      // Search
                      Expanded(
                        flex: 3,
                        child: Container(
                          height: 42,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: TextField(
                            onChanged: (v) => setState(() => _searchQuery = v),
                            style: const TextStyle(fontSize: 13, fontFamily: 'Inter'),
                            decoration: const InputDecoration(
                              hintText: 'Search resident...',
                              hintStyle: TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                              prefixIcon: Icon(Icons.search_rounded, size: 18, color: Color(0xFF94A3B8)),
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Status filter
                      _DropdownFilter(
                        value: _statusFilter,
                        items: const ['All', 'Paid', 'Pending'],
                        icon: Icons.filter_list_rounded,
                        onChanged: (v) => setState(() => _statusFilter = v),
                      ),
                      const SizedBox(width: 12),
                      // Month filter
                      _DropdownFilter(
                        value: monthOptions.contains(_selectedMonth) ? _selectedMonth : _currentMonthLabel(),
                        items: sortedMonths,
                        icon: Icons.calendar_month_rounded,
                        onChanged: (v) => setState(() => _selectedMonth = v),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // ── Table Header ──
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 20),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: const BorderRadius.only(topLeft: Radius.circular(14), topRight: Radius.circular(14)),
                    border: Border.all(color: const Color(0xFFF1F5F9)),
                  ),
                  child: const Row(
                    children: [
                      Expanded(flex: 3, child: Text('Resident', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF64748B), fontFamily: 'Inter', letterSpacing: 0.5))),
                      Expanded(flex: 2, child: Text('Amount', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF64748B), fontFamily: 'Inter', letterSpacing: 0.5))),
                      Expanded(flex: 2, child: Text('Date', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF64748B), fontFamily: 'Inter', letterSpacing: 0.5))),
                      Expanded(flex: 2, child: Text('Status', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF64748B), fontFamily: 'Inter', letterSpacing: 0.5))),
                      Expanded(flex: 3, child: Text('Location', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF64748B), fontFamily: 'Inter', letterSpacing: 0.5))),
                    ],
                  ),
                ),

                // ── Table Rows ──
                Expanded(
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(14), bottomRight: Radius.circular(14)),
                      border: const Border(
                        left: BorderSide(color: Color(0xFFF1F5F9)),
                        right: BorderSide(color: Color(0xFFF1F5F9)),
                        bottom: BorderSide(color: Color(0xFFF1F5F9)),
                      ),
                    ),
                    child: displayList.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.receipt_outlined, size: 48, color: const Color(0xFFCBD5E1)),
                                const SizedBox(height: 12),
                                Text(
                                  _statusFilter == 'Pending'
                                      ? 'All residents have paid! 🎉'
                                      : 'No matching records',
                                  style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 14, fontFamily: 'Inter'),
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            padding: EdgeInsets.zero,
                            itemCount: displayList.length,
                            itemBuilder: (ctx, i) => _buildRow(displayList[i], i, displayList.length),
                          ),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildRow(Map<String, dynamic> d, int index, int total) {
    final isPaid = d['status']?.toString().toLowerCase() == 'paid' || d['isPaid'] == true;
    final residentId = d['residentId']?.toString() ?? '';
    final month = d['month']?.toString() ?? '';

    // Date display
    String dateStr;
    if (isPaid) {
      final paidAt = d['paidAt'] as Timestamp?;
      dateStr = paidAt != null ? DateFormat('MMM dd, yyyy').format(paidAt.toDate()) : '-';
    } else {
      final dueDate = d['dueDate'] as DateTime?;
      final daysOverdue = d['daysOverdue'] as int? ?? 0;
      dateStr = dueDate != null
          ? '${DateFormat('MMM dd').format(dueDate)}${daysOverdue > 0 ? ' (${daysOverdue}d late)' : ''}'
          : '-';
    }

    return FutureBuilder<Map<String, dynamic>>(
      future: _resolveRowData(d, isPaid, residentId),
      builder: (ctx, snap) {
        final locData = snap.data ?? {'name': d['residentId'] ?? 'Resident', 'location': '-', 'rent': 0};
        final location = locData['location'] as String;
        final name = locData['name'] as String;
        final amount = isPaid ? (d['amount'] ?? d['monthlyFee'] ?? 0) : locData['rent'];

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          decoration: BoxDecoration(
            color: isPaid ? Colors.white : const Color(0xFFFFFBEB),
            border: index < total - 1
                ? const Border(bottom: BorderSide(color: Color(0xFFF1F5F9)))
                : null,
          ),
          child: Row(
            children: [
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, fontFamily: 'Inter'), overflow: TextOverflow.ellipsis),
                    if (month.isNotEmpty)
                      Text(month, style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8), fontFamily: 'Inter')),
                  ],
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  isPaid ? '₹$amount' : (amount > 0 ? '₹$amount' : '-'),
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, fontFamily: 'Inter'),
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(dateStr, style: TextStyle(fontSize: 12, color: isPaid ? const Color(0xFF64748B) : const Color(0xFFEF4444), fontFamily: 'Inter')),
              ),
              Expanded(
                flex: 2,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: isPaid ? const Color(0xFFECFDF5) : const Color(0xFFFEE2E2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      isPaid ? 'Paid' : 'Pending',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: isPaid ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                        fontFamily: 'Inter',
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(
                flex: 3,
                child: Row(
                  children: [
                    const Icon(Icons.location_on_outlined, size: 14, color: Color(0xFF94A3B8)),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(location, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), fontFamily: 'Inter'), overflow: TextOverflow.ellipsis),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  int _toInt(dynamic v) => v is int ? v : int.tryParse('$v') ?? 0;
}

/// ── Stat Badge (inside green banner) ──
class _StatBadge extends StatelessWidget {
  final String label, value;
  final IconData icon;
  const _StatBadge({required this.label, required this.value, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, color: Colors.white.withOpacity(0.8), size: 22),
          const SizedBox(height: 6),
          Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Colors.white, fontFamily: 'Inter')),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: Colors.white.withOpacity(0.75), fontFamily: 'Inter')),
        ],
      ),
    );
  }
}

/// ── Dropdown Filter Chip ──
class _DropdownFilter extends StatelessWidget {
  final String value;
  final List<String> items;
  final IconData icon;
  final ValueChanged<String> onChanged;
  const _DropdownFilter({required this.value, required this.items, required this.icon, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 42,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: Color(0xFF64748B)),
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF334155), fontFamily: 'Inter'),
          items: items.map((s) => DropdownMenuItem(value: s, child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14, color: const Color(0xFF94A3B8)),
              const SizedBox(width: 6),
              Text(s),
            ],
          ))).toList(),
          onChanged: (v) { if (v != null) onChanged(v); },
        ),
      ),
    );
  }
}
