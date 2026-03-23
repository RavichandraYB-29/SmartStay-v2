import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../services/payu_service.dart';

class RentPaymentsScreen extends StatelessWidget {
  final String residentId;
  final String? hostelId;
  final String? pgId;
  final String? floorId;
  final String? roomId;

  const RentPaymentsScreen({
    super.key,
    required this.residentId,
    this.hostelId,
    this.pgId,
    this.floorId,
    this.roomId,
  });

  Future<Map<String, dynamic>> _fetchRoomDetails() async {
    try {
      // First, get the allocation IDs from the resident document
      String? hId = hostelId;
      String? pId = pgId;
      String? fId = floorId;
      String? rId = roomId;
      Timestamp? allocatedAtTs;

      // Always fetch the resident doc to get allocatedAt
      final residentSnap = await FirebaseFirestore.instance
          .collection('residents')
          .doc(residentId)
          .get();
      final residentData = residentSnap.data();
      if (residentData == null) return {};

      final allocation =
          residentData['allocationDetails'] as Map<String, dynamic>?;

      allocatedAtTs = allocation?['allocatedAt'] as Timestamp?;

      // Fill missing IDs from resident document
      hId = hId ?? allocation?['hostelId']?.toString() ?? residentData['hostelId']?.toString();
      pId = pId ?? allocation?['pgId']?.toString() ?? residentData['pgId']?.toString();
      fId = fId ?? allocation?['floorId']?.toString() ?? residentData['floorId']?.toString();
      rId = rId ?? allocation?['roomId']?.toString() ?? residentData['roomId']?.toString();

      if (hId == null || pId == null || fId == null || rId == null) {
        return {};
      }

      final hostelRef =
          FirebaseFirestore.instance.collection('hostels').doc(hId);
      final floorRef = hostelRef
          .collection('pgs')
          .doc(pId)
          .collection('floors')
          .doc(fId);
      final roomRef = floorRef.collection('rooms').doc(rId);

      final results =
          await Future.wait([hostelRef.get(), floorRef.get(), roomRef.get()]);

      final hostelData = results[0].data();
      final floorData = results[1].data();
      final roomData = results[2].data();

      final hostelName = hostelData?['hostelName']?.toString() ??
          hostelData?['name']?.toString() ??
          '-';

      final floorIndex = floorData?['floorIndex'];
      final floorLabel = floorData?['floorName']?.toString() ??
          floorData?['floorNumber']?.toString() ??
          (floorIndex != null ? 'Floor $floorIndex' : '-');

      return {
        'hostelId': hId,
        'pgId': pId,
        'floorId': fId,
        'roomId': rId,
        'bedId': allocation?['bedId']?.toString() ?? residentData['bedId']?.toString(),
        'hostelName': hostelName,
        'floorLabel': floorLabel,
        'roomNumber': roomData?['roomNumber']?.toString() ?? '-',
        'sharingType': roomData?['sharingType']?.toString() ?? '-',
        'rentPerBed': roomData?['rentPerBed'],
        'allocatedAt': allocatedAtTs,
        'adminId': hostelData?['adminId'],
        'residentName': residentData['name'] ?? residentData['fullName'] ?? 'Resident',
        'email': residentData['email'] ?? 'test@example.com',
        'phone': residentData['phone'] ?? '9999999999',
      };
    } catch (_) {
      return {};
    }
  }

  /// Calculates the next monthly due date based on when the resident was allocated.
  /// e.g. joined Jan 1 → due dates are Feb 1, Mar 1, Apr 1, etc.
  static DateTime? _calculateNextDueDate(Timestamp? allocatedAtTs) {
    if (allocatedAtTs == null) return null;
    final allocatedAt = allocatedAtTs.toDate();
    final now = DateTime.now();
    final joinDay = allocatedAt.day;

    // Start from the month after allocation
    DateTime dueDate = DateTime(allocatedAt.year, allocatedAt.month + 1, 1);
    // Set the day — clamp to last day of month if needed
    final lastDayOfMonth = DateTime(dueDate.year, dueDate.month + 1, 0).day;
    final day = joinDay > lastDayOfMonth ? lastDayOfMonth : joinDay;
    dueDate = DateTime(dueDate.year, dueDate.month, day);

    // Advance to the current or next upcoming due date
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

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Column(
        children: [
          // ── App Bar ──
          Container(
            padding: const EdgeInsets.fromLTRB(8, 56, 24, 16),
            decoration: BoxDecoration(
              color: Colors.white,
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
                  icon: const Icon(
                    Icons.arrow_back_rounded,
                    color: Color(0xFF334155),
                  ),
                  onPressed: () => Navigator.pop(context),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF14B8A6), Color(0xFF0D9488)],
                    ),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.attach_money_rounded,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 14),
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Rent & Payments',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF1E293B),
                        letterSpacing: -0.5,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Your monthly room rent and payment status',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF94A3B8),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // ── Body ──
          Expanded(
            child: FutureBuilder<Map<String, dynamic>>(
              future: _fetchRoomDetails(),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final data = snap.data ?? {};
                final hostelName = data['hostelName'] ?? '-';
                final floorLabel = data['floorLabel'] ?? '-';
                final roomNumber = data['roomNumber'] ?? '-';
                final sharingType = data['sharingType'] ?? '-';
                final rentPerBed = data['rentPerBed'];
                final rentDisplay =
                    rentPerBed != null ? (rentPerBed as num).toInt() : null;

                return SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── Info Banner ──
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: teal.withOpacity(0.06),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: teal.withOpacity(0.18),
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              margin: const EdgeInsets.only(top: 2),
                              child: Icon(
                                Icons.info_outline_rounded,
                                color: teal,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Rent amount is based on your allocated room',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF1E293B),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'The monthly rent is automatically set according to your room type and cannot be modified.',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                      color: teal.withOpacity(0.8),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 24),

                      // ── Allocated Room Details Card ──
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.04),
                              blurRadius: 20,
                              offset: const Offset(0, 8),
                            ),
                          ],
                          border: Border.all(
                            color: const Color(0xFFF1F5F9),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Card header
                            Row(
                              children: [
                                Icon(
                                  Icons.home_rounded,
                                  color: const Color(0xFF64748B),
                                  size: 22,
                                ),
                                const SizedBox(width: 10),
                                const Expanded(
                                  child: Text(
                                    'Allocated Room Details',
                                    style: TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF1E293B),
                                      letterSpacing: -0.3,
                                    ),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: teal,
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: const Text(
                                    'Allocated',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 28),

                            // Row 1: Hostel Name & Room Number
                            Row(
                              children: [
                                Expanded(
                                  child: _DetailItem(
                                    label: 'Hostel Name',
                                    value: hostelName,
                                  ),
                                ),
                                Expanded(
                                  child: _DetailItem(
                                    label: 'Room Number',
                                    value: roomNumber,
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 24),

                            // Row 2: Floor & Bed Type
                            Row(
                              children: [
                                Expanded(
                                  child: _DetailItem(
                                    label: 'Floor',
                                    value: floorLabel,
                                  ),
                                ),
                                Expanded(
                                  child: _DetailItem(
                                    label: 'Bed Type',
                                    value: sharingType,
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 28),

                            // Monthly Rent Card
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: teal.withOpacity(0.04),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: teal.withOpacity(0.2),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Monthly Rent',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: teal,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.baseline,
                                    textBaseline: TextBaseline.alphabetic,
                                    children: [
                                      Text(
                                        rentDisplay != null
                                            ? '₹${_formatAmount(rentDisplay)}'
                                            : '—',
                                        style: const TextStyle(
                                          fontSize: 32,
                                          fontWeight: FontWeight.w900,
                                          color: Color(0xFF1E293B),
                                          letterSpacing: -1,
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      const Text(
                                        '/month',
                                        style: TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w500,
                                          color: Color(0xFF94A3B8),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Amount is fixed based on room type',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                      color: teal.withOpacity(0.7),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 32),

                      // ── Current Month Payment + Quick Actions ──
                      StreamBuilder<QuerySnapshot>(
                        stream: FirebaseFirestore.instance
                            .collection('payments')
                            .where('residentId', isEqualTo: residentId)
                            .where('userId', isEqualTo: FirebaseAuth.instance.currentUser?.uid)
                            .orderBy('dueDate', descending: true)
                            .limit(1)
                            .snapshots(),
                        builder: (context, paySnap) {
                          final latestDoc = paySnap.data?.docs.firstOrNull;
                          final latest = latestDoc?.data() as Map<String, dynamic>?;

                          final isPaid = latest != null &&
                              (latest['status']?.toString().toLowerCase() == 'paid' ||
                                  latest['isPaid'] == true);
                          final dueDateTs = latest?['dueDate'] as Timestamp?;
                          final paymentAmt = latest?['amount'] ?? latest?['monthlyFee'] ?? rentDisplay ?? 0;

                          // Calculate due date from allocation date
                          final allocatedAtTs = data['allocatedAt'] as Timestamp?;
                          final calculatedDueDate = _calculateNextDueDate(allocatedAtTs);
                          final dueDateToUse = calculatedDueDate ?? (dueDateTs?.toDate());

                          final billingMonth = DateFormat('MMMM yyyy').format(DateTime.now());
                          final dueDateStr = dueDateToUse != null
                              ? DateFormat('MMM dd, yyyy').format(dueDateToUse)
                              : '-';
                          final amountToDisplay = rentDisplay ?? paymentAmt;

                          return LayoutBuilder(
                            builder: (context, constraints) {
                              final isWide = constraints.maxWidth > 700;

                              final currentMonthCard = Container(
                                padding: const EdgeInsets.all(24),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(20),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.04),
                                      blurRadius: 20,
                                      offset: const Offset(0, 8),
                                    ),
                                  ],
                                  border: Border.all(color: const Color(0xFFF1F5F9)),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Header
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.calendar_month_rounded,
                                          color: const Color(0xFF64748B),
                                          size: 22,
                                        ),
                                        const SizedBox(width: 10),
                                        const Text(
                                          'Current Month Payment',
                                          style: TextStyle(
                                            fontSize: 17,
                                            fontWeight: FontWeight.w700,
                                            color: Color(0xFF1E293B),
                                            letterSpacing: -0.3,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 24),

                                    // Info Row: Billing Month, Rent Amount, Due Date
                                    Row(
                                      children: [
                                        Expanded(
                                          child: _DetailItem(
                                            label: 'Billing Month',
                                            value: billingMonth,
                                          ),
                                        ),
                                        Expanded(
                                          child: _DetailItem(
                                            label: 'Rent Amount',
                                            value: '₹${_formatAmount(amountToDisplay is int ? amountToDisplay : (amountToDisplay as num).toInt())}',
                                          ),
                                        ),
                                        Expanded(
                                          child: _DetailItem(
                                            label: 'Due Date',
                                            value: dueDateStr,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 20),

                                    // Payment Status row
                                    Row(
                                      children: [
                                        const Text(
                                          'Payment Status:',
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                            color: Color(0xFF64748B),
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 14,
                                            vertical: 5,
                                          ),
                                          decoration: BoxDecoration(
                                            color: isPaid ? teal : const Color(0xFFF59E0B),
                                            borderRadius: BorderRadius.circular(20),
                                          ),
                                          child: Text(
                                            isPaid ? 'Paid' : 'Due',
                                            style: const TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w700,
                                              color: Colors.white,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),

                                    // Due banner (only if not paid)
                                    if (!isPaid && dueDateStr != '-') ...[
                                      const SizedBox(height: 16),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 16,
                                          vertical: 12,
                                        ),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFF59E0B).withOpacity(0.08),
                                          borderRadius: BorderRadius.circular(12),
                                          border: Border.all(
                                            color: const Color(0xFFF59E0B).withOpacity(0.2),
                                          ),
                                        ),
                                        child: Row(
                                          children: [
                                            const Icon(
                                              Icons.schedule_rounded,
                                              color: Color(0xFFF59E0B),
                                              size: 18,
                                            ),
                                            const SizedBox(width: 10),
                                            Text(
                                              'Payment due by $dueDateStr',
                                              style: const TextStyle(
                                                fontSize: 13,
                                                fontWeight: FontWeight.w600,
                                                color: Color(0xFF92400E),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              );

                              final quickActionsCard = Container(
                                padding: const EdgeInsets.all(24),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [
                                      teal.withOpacity(0.06),
                                      teal.withOpacity(0.02),
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: teal.withOpacity(0.15)),
                                ),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Text(
                                      'Quick Actions',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF1E293B),
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      'Amount to Pay',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: teal,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      isPaid ? '₹0' : '₹${_formatAmount(amountToDisplay is int ? amountToDisplay : (amountToDisplay as num).toInt())}',
                                      style: const TextStyle(
                                        fontSize: 28,
                                        fontWeight: FontWeight.w900,
                                        color: Color(0xFF1E293B),
                                        letterSpacing: -1,
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    SizedBox(
                                      width: double.infinity,
                                      child: ElevatedButton.icon(
                                        onPressed: isPaid ? null : () {
                                          _showPaymentMethodDialog(
                                            context: context,
                                            amount: amountToDisplay is int ? amountToDisplay : (amountToDisplay as num).toInt(),
                                            residentId: residentId,
                                            adminId: data['adminId']?.toString() ?? '', // we need to fetch adminId
                                            monthLabel: billingMonth,
                                            dueDate: dueDateTs ?? (dueDateToUse != null ? Timestamp.fromDate(dueDateToUse) : null),
                                            hostelId: data['hostelId']?.toString() ?? hostelId,
                                            pgId: data['pgId']?.toString() ?? pgId,
                                            floorId: data['floorId']?.toString() ?? floorId,
                                            roomId: data['roomId']?.toString() ?? roomId,
                                            bedId: data['bedId']?.toString(), // Get these from _fetchRoomDetails
                                            residentName: (data['residentName'] ?? '').toString(),
                                            email: (data['email'] ?? '').toString(),
                                            phone: (data['phone'] ?? '').toString(),
                                          );
                                        },
                                        icon: const Icon(Icons.attach_money_rounded, size: 18),
                                        label: Text(
                                          isPaid ? 'Paid' : 'Pay ₹${_formatAmount(amountToDisplay is int ? amountToDisplay : (amountToDisplay as num).toInt())}',
                                          style: const TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: teal,
                                          foregroundColor: Colors.white,
                                          disabledBackgroundColor: const Color(0xFFE2E8F0),
                                          disabledForegroundColor: const Color(0xFF94A3B8),
                                          padding: const EdgeInsets.symmetric(vertical: 14),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(14),
                                          ),
                                          elevation: 0,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        const Icon(
                                          Icons.lock_rounded,
                                          size: 12,
                                          color: Color(0xFF94A3B8),
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          'Secure payment powered by SmartStay',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w500,
                                            color: const Color(0xFF94A3B8),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              );

                              if (isWide) {
                                return Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(flex: 3, child: currentMonthCard),
                                    const SizedBox(width: 20),
                                    Expanded(flex: 2, child: quickActionsCard),
                                  ],
                                );
                              } else {
                                return Column(
                                  children: [
                                    currentMonthCard,
                                    const SizedBox(height: 16),
                                    quickActionsCard,
                                  ],
                                );
                              }
                            },
                          );
                        },
                      ),

                      const SizedBox(height: 32),

                      // ── Payment History ──
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.04),
                              blurRadius: 20,
                              offset: const Offset(0, 8),
                            ),
                          ],
                          border: Border.all(color: const Color(0xFFF1F5F9)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Header
                            Row(
                              children: [
                                Icon(
                                  Icons.calendar_today_rounded,
                                  color: const Color(0xFF64748B),
                                  size: 20,
                                ),
                                const SizedBox(width: 10),
                                const Text(
                                  'Payment History',
                                  style: TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF1E293B),
                                    letterSpacing: -0.3,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),

                            // Table header
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Row(
                                children: [
                                  Expanded(
                                    flex: 3,
                                    child: Text(
                                      'Month',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF64748B),
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    flex: 2,
                                    child: Text(
                                      'Amount',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF64748B),
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    flex: 2,
                                    child: Text(
                                      'Status',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF64748B),
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    flex: 3,
                                    child: Text(
                                      'Paid On',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF64748B),
                                      ),
                                    ),
                                  ),
                                  SizedBox(
                                    width: 50,
                                    child: Text(
                                      'Receipt',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF64748B),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            // Table rows from Firestore
                            StreamBuilder<QuerySnapshot>(
                              stream: FirebaseFirestore.instance
                                  .collection('payments')
                                  .where('residentId', isEqualTo: residentId)
                                  .where('userId', isEqualTo: FirebaseAuth.instance.currentUser?.uid)
                                  .orderBy('dueDate', descending: true)
                                  .snapshots(),
                              builder: (context, histSnap) {
                                if (histSnap.connectionState == ConnectionState.waiting) {
                                  return const Padding(
                                    padding: EdgeInsets.symmetric(vertical: 24),
                                    child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                                  );
                                }

                                final docs = histSnap.data?.docs ?? [];
                                if (docs.isEmpty) {
                                  return const Padding(
                                    padding: EdgeInsets.symmetric(vertical: 28),
                                    child: Center(
                                      child: Text(
                                        'No payment history',
                                        style: TextStyle(
                                          color: Color(0xFF94A3B8),
                                          fontSize: 13,
                                        ),
                                      ),
                                    ),
                                  );
                                }

                                return Column(
                                  children: docs.map((doc) {
                                    final d = doc.data() as Map<String, dynamic>;
                                    final amt = d['amount'] ?? d['monthlyFee'] ?? 0;
                                    final paid = d['paidAt'] as Timestamp?;
                                    final due = d['dueDate'] as Timestamp?;
                                    final monthLabel = d['month']?.toString() ?? '';
                                    final docIsPaid =
                                        d['status']?.toString().toLowerCase() == 'paid' ||
                                        d['isPaid'] == true;

                                    final monthDisplay = monthLabel.isNotEmpty
                                        ? monthLabel
                                        : (due != null
                                            ? DateFormat('MMMM yyyy').format(due.toDate())
                                            : (paid != null
                                                ? DateFormat('MMMM yyyy').format(paid.toDate())
                                                : '-'));
                                    final paidOnDisplay = paid != null
                                        ? DateFormat('MMM d, yyyy').format(paid.toDate())
                                        : '-';

                                    return Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 16,
                                      ),
                                      decoration: const BoxDecoration(
                                        border: Border(
                                          bottom: BorderSide(
                                            color: Color(0xFFF1F5F9),
                                            width: 1,
                                          ),
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          // Month
                                          Expanded(
                                            flex: 3,
                                            child: Text(
                                              monthDisplay,
                                              style: const TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w600,
                                                color: Color(0xFF1E293B),
                                              ),
                                            ),
                                          ),
                                          // Amount
                                          Expanded(
                                            flex: 2,
                                            child: Text(
                                              '₹${_formatAmount(amt is int ? amt : (amt as num).toInt())}',
                                              style: const TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w700,
                                                color: Color(0xFF334155),
                                              ),
                                            ),
                                          ),
                                          // Status
                                          Expanded(
                                            flex: 2,
                                            child: Align(
                                              alignment: Alignment.centerLeft,
                                              child: Container(
                                                padding: const EdgeInsets.symmetric(
                                                  horizontal: 12,
                                                  vertical: 4,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: docIsPaid ? teal : const Color(0xFFF59E0B),
                                                  borderRadius: BorderRadius.circular(20),
                                                ),
                                                child: Text(
                                                  docIsPaid ? 'Paid' : 'Due',
                                                  style: const TextStyle(
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.w700,
                                                    color: Colors.white,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                          // Paid On
                                          Expanded(
                                            flex: 3,
                                            child: Text(
                                              paidOnDisplay,
                                              style: const TextStyle(
                                                fontSize: 13,
                                                color: Color(0xFF64748B),
                                              ),
                                            ),
                                          ),
                                          // Receipt icon
                                          SizedBox(
                                            width: 50,
                                            child: Center(
                                              child: GestureDetector(
                                                onTap: docIsPaid
                                                    ? () => _generateReceipt(
                                                          context: context,
                                                          month: monthDisplay,
                                                          amount: amt is int ? amt : (amt as num).toInt(),
                                                          paidOn: paidOnDisplay,
                                                          txnId: d['payuTxnId']?.toString() ?? d['paymentMode']?.toString() ?? '-',
                                                          paymentMode: d['paymentMode']?.toString() ?? 'Online',
                                                          residentId: residentId,
                                                        )
                                                    : null,
                                                child: Icon(
                                                  Icons.download_rounded,
                                                  color: docIsPaid
                                                      ? const Color(0xFF64748B)
                                                      : const Color(0xFFCBD5E1),
                                                  size: 20,
                                                ),
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
                        ),
                      ),

                      const SizedBox(height: 40),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  String _formatAmount(int amount) {
    final str = amount.toString();
    final buffer = StringBuffer();
    int count = 0;
    for (int i = str.length - 1; i >= 0; i--) {
      buffer.write(str[i]);
      count++;
      if (count == 3 && i > 0) {
        buffer.write(',');
        count = 0;
      } else if (count > 3 && (count - 3) % 2 == 0 && i > 0) {
        buffer.write(',');
      }
    }
    return buffer.toString().split('').reversed.join();
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
              // Header
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
                    pw.Text(
                      'SmartStay',
                      style: pw.TextStyle(
                        fontSize: 28,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.white,
                      ),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      'Payment Receipt',
                      style: pw.TextStyle(
                        fontSize: 16,
                        color: PdfColor.fromHex('#E0F2F1'),
                      ),
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 30),

              // Status badge
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: pw.BoxDecoration(
                  color: PdfColor.fromHex('#D1FAE5'),
                  borderRadius: pw.BorderRadius.circular(20),
                ),
                child: pw.Text(
                  'PAYMENT SUCCESSFUL',
                  style: pw.TextStyle(
                    fontSize: 12,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColor.fromHex('#065F46'),
                  ),
                ),
              ),
              pw.SizedBox(height: 24),

              // Details table
              pw.Table(
                border: pw.TableBorder.all(
                  color: PdfColor.fromHex('#E2E8F0'),
                  width: 0.5,
                ),
                children: [
                  _pdfTableRow('Billing Month', month),
                  _pdfTableRow('Amount Paid', 'Rs. ${fmtAmt(amount)}'),
                  _pdfTableRow('Paid On', paidOn),
                  _pdfTableRow('Transaction ID', txnId),
                  _pdfTableRow('Payment Mode', paymentMode),
                  _pdfTableRow('Resident ID', residentId),
                  _pdfTableRow('Receipt Date', DateFormat('MMM dd, yyyy – hh:mm a').format(DateTime.now())),
                ],
              ),
              pw.SizedBox(height: 40),

              // Footer
              pw.Divider(color: PdfColor.fromHex('#E2E8F0')),
              pw.SizedBox(height: 12),
              pw.Text(
                'This is a computer-generated receipt and does not require a signature.',
                style: pw.TextStyle(
                  fontSize: 10,
                  color: PdfColor.fromHex('#94A3B8'),
                ),
              ),
              pw.SizedBox(height: 4),
              pw.Text(
                'Powered by SmartStay Hostel Management',
                style: pw.TextStyle(
                  fontSize: 10,
                  color: PdfColor.fromHex('#94A3B8'),
                ),
              ),
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

  static pw.TableRow _pdfTableRow(String label, String value) {
    return pw.TableRow(
      children: [
        pw.Padding(
          padding: const pw.EdgeInsets.all(10),
          child: pw.Text(
            label,
            style: pw.TextStyle(
              fontSize: 12,
              fontWeight: pw.FontWeight.bold,
              color: PdfColor.fromHex('#475569'),
            ),
          ),
        ),
        pw.Padding(
          padding: const pw.EdgeInsets.all(10),
          child: pw.Text(
            value,
            style: pw.TextStyle(
              fontSize: 12,
              color: PdfColor.fromHex('#1E293B'),
            ),
          ),
        ),
      ],
    );
  }
}

class _DetailItem extends StatelessWidget {
  final String label;
  final String value;

  const _DetailItem({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: Color(0xFF94A3B8),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          value,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: Color(0xFF1E293B),
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════
// PAYMENT METHOD DIALOG
// ═══════════════════════════════════════════════════════

void _showPaymentMethodDialog({
  required BuildContext context,
  required int amount,
  required String residentId,
  required String adminId,
  required String monthLabel,
  Timestamp? dueDate,
  String? hostelId,
  String? pgId,
  String? floorId,
  String? roomId,
  String? bedId,
  required String residentName,
  required String email,
  required String phone,
}) {
  const teal = Color(0xFF14B8A6);

  String _fmt(int a) {
    final str = a.toString();
    final buf = StringBuffer();
    int count = 0;
    for (int i = str.length - 1; i >= 0; i--) {
      buf.write(str[i]);
      count++;
      if (count == 3 && i > 0) {
        buf.write(',');
        count = 0;
      } else if (count > 3 && (count - 3) % 2 == 0 && i > 0) {
        buf.write(',');
      }
    }
    return buf.toString().split('').reversed.join();
  }

  showDialog(
    context: context,
    builder: (ctx) {
      return _PaymentMethodDialogContent(
        amount: amount,
        formattedAmount: _fmt(amount),
        teal: teal,
        residentId: residentId,
        adminId: adminId,
        monthLabel: monthLabel,
        dueDate: dueDate,
        hostelId: hostelId,
        pgId: pgId,
        floorId: floorId,
        roomId: roomId,
        bedId: bedId,
        residentName: residentName,
        email: email,
        phone: phone,
      );
    },
  );
}

class _PaymentMethodDialogContent extends StatefulWidget {
  final int amount;
  final String formattedAmount;
  final Color teal;
  final String residentId;
  final String adminId;
  final String monthLabel;
  final Timestamp? dueDate;
  final String? hostelId;
  final String? pgId;
  final String? floorId;
  final String? roomId;
  final String? bedId;
  final String residentName;
  final String email;
  final String phone;

  const _PaymentMethodDialogContent({
    required this.amount,
    required this.formattedAmount,
    required this.teal,
    required this.residentId,
    required this.adminId,
    required this.monthLabel,
    this.dueDate,
    this.hostelId,
    this.pgId,
    this.floorId,
    this.roomId,
    this.bedId,
    required this.residentName,
    required this.email,
    required this.phone,
  });

  @override
  State<_PaymentMethodDialogContent> createState() =>
      _PaymentMethodDialogContentState();
}

class _PaymentMethodDialogContentState
    extends State<_PaymentMethodDialogContent> {
  String _selectedMethod = 'upi'; // UPI selected by default

  @override
  Widget build(BuildContext context) {
    final teal = widget.teal;

    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Header ──
                Row(
                  children: [
                    Icon(
                      Icons.credit_card_rounded,
                      color: const Color(0xFF334155),
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Select Payment Method',
                        style: TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF1E293B),
                          letterSpacing: -0.5,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.arrow_back_rounded,
                        color: Color(0xFF64748B),
                      ),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                // ── Amount Banner ──
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 20,
                  ),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        teal.withOpacity(0.08),
                        teal.withOpacity(0.03),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: teal.withOpacity(0.2)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Amount to Pay',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: teal,
                        ),
                      ),
                      Text(
                        '₹${widget.formattedAmount}',
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF1E293B),
                          letterSpacing: -1,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 28),

                // ── Choose Payment Method ──
                const Text(
                  'Choose Payment Method',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1E293B),
                  ),
                ),
                const SizedBox(height: 16),

                // Payment Method Grid
                Row(
                  children: [
                    Expanded(
                      child: _PaymentMethodCard(
                        id: 'upi',
                        icon: Icons.phone_android_rounded,
                        title: 'UPI',
                        subtitle: 'PhonePe, GPay, Paytm',
                        badge: 'Popular',
                        isSelected: _selectedMethod == 'upi',
                        isAvailable: true,
                        teal: teal,
                        onTap: () => setState(() => _selectedMethod = 'upi'),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: _PaymentMethodCard(
                        id: 'card',
                        icon: Icons.credit_card_rounded,
                        title: 'Credit / Debit Card',
                        subtitle: 'Visa, Mastercard, RuPay',
                        isSelected: _selectedMethod == 'card',
                        isAvailable: true,
                        teal: teal,
                        onTap: () => setState(() => _selectedMethod = 'card'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: _PaymentMethodCard(
                        id: 'netbanking',
                        icon: Icons.account_balance_rounded,
                        title: 'Net Banking',
                        subtitle: 'All major banks',
                        isSelected: _selectedMethod == 'netbanking',
                        isAvailable: true,
                        teal: teal,
                        onTap: () => setState(() => _selectedMethod = 'netbanking'),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: _PaymentMethodCard(
                        id: 'wallet',
                        icon: Icons.account_balance_wallet_rounded,
                        title: 'Digital Wallet',
                        subtitle: 'Paytm, PhonePe Wallet',
                        isSelected: _selectedMethod == 'wallet',
                        isAvailable: true,
                        teal: teal,
                        onTap: () => setState(() => _selectedMethod = 'wallet'),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                // ── Secure Payment Info ──
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: teal.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: teal.withOpacity(0.12)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.info_outline_rounded,
                        color: teal,
                        size: 18,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Secure Payment via PayU',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF1E293B),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Your payment information is encrypted and secure. Supported by PayU gateway.',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: const Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // ── Confirm Payment Button ──
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      // Don't pop dialog here — payu_service closes it
                      // after capturing the navigator context.
                      final payuService = PayUService();
                      payuService.startPayment(
                        context: context,
                        residentId: widget.residentId,
                        adminId: widget.adminId,
                        amount: widget.amount,
                        name: widget.residentName,
                        email: widget.email,
                        phone: widget.phone,
                        monthLabel: widget.monthLabel,
                        dueDate: widget.dueDate,
                        hostelId: widget.hostelId,
                        pgId: widget.pgId,
                        floorId: widget.floorId,
                        roomId: widget.roomId,
                        bedId: widget.bedId,
                      );
                    },
                    icon: const Icon(Icons.verified_outlined, size: 20),
                    label: const Text(
                      'Confirm Payment',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: teal,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      elevation: 0,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PaymentMethodCard extends StatelessWidget {
  final String id;
  final IconData icon;
  final String title;
  final String subtitle;
  final String? badge;
  final bool isSelected;
  final bool isAvailable;
  final Color teal;
  final VoidCallback onTap;

  const _PaymentMethodCard({
    required this.id,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.badge,
    required this.isSelected,
    required this.isAvailable,
    required this.teal,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final borderColor = isSelected ? teal : const Color(0xFFE2E8F0);
    final bgColor = isSelected
        ? teal.withOpacity(0.04)
        : (isAvailable ? Colors.white : const Color(0xFFF8FAFC));
    final iconBg = isSelected ? teal.withOpacity(0.12) : const Color(0xFFF1F5F9);
    final iconColor = isSelected ? teal : const Color(0xFF94A3B8);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderColor, width: isSelected ? 2 : 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: iconBg,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: iconColor, size: 22),
                ),
                if (badge != null) ...[
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF6B35),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      badge!,
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 14),
            Text(
              title,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: isAvailable
                    ? const Color(0xFF1E293B)
                    : const Color(0xFF94A3B8),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: isAvailable
                    ? const Color(0xFF64748B)
                    : const Color(0xFFCBD5E1),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
