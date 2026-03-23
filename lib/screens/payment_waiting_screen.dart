import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'payment_status_screen.dart';

/// Shown while the user is completing payment on the PayU tab.
/// Listens for browser tab focus to detect when the user returns.
class PaymentWaitingScreen extends StatefulWidget {
  final String residentId;
  final String adminId;
  final int amount;
  final String monthLabel;
  final String txnId;
  final String residentName;
  final Timestamp? dueDate;
  final String? hostelId;
  final String? pgId;
  final String? floorId;
  final String? roomId;
  final String? bedId;

  const PaymentWaitingScreen({
    super.key,
    required this.residentId,
    required this.adminId,
    required this.amount,
    required this.monthLabel,
    required this.txnId,
    this.residentName = '',
    this.dueDate,
    this.hostelId,
    this.pgId,
    this.floorId,
    this.roomId,
    this.bedId,
  });

  @override
  State<PaymentWaitingScreen> createState() => _PaymentWaitingScreenState();
}

class _PaymentWaitingScreenState extends State<PaymentWaitingScreen> {
  bool _isProcessing = false;

  /// Calculate a dueDate from the current month if none was provided.
  Timestamp _ensureDueDate() {
    if (widget.dueDate != null) return widget.dueDate!;
    // Default: due date = 1st of next month
    final now = DateTime.now();
    final nextMonth = DateTime(now.year, now.month + 1, 1);
    return Timestamp.fromDate(nextMonth);
  }

  Future<void> _confirmPayment() async {
    if (_isProcessing) return;
    setState(() => _isProcessing = true);

    bool writeSuccess = false;
    String? errorMsg;

    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        errorMsg = 'Not logged in. Please log in again.';
      } else {
        final dueDate = _ensureDueDate();
        final now = DateTime.now();
        final monthLabel = widget.monthLabel.isNotEmpty
            ? widget.monthLabel
            : DateFormat('MMMM yyyy').format(now);

        // Write payment record to Firestore
        await FirebaseFirestore.instance.collection('payments').add({
          'residentId': widget.residentId,
          'adminId': widget.adminId,
          'userId': currentUser.uid,
          'residentName': widget.residentName,
          'amount': widget.amount,
          'status': 'paid',
          'isPaid': true,
          'month': monthLabel,
          'dueDate': dueDate,
          'paidAt': FieldValue.serverTimestamp(),
          'paymentGateway': 'payu',
          'payuTxnId': widget.txnId,
          'paymentMode': 'PAYU_TEST',
          'hostelId': widget.hostelId,
          'pgId': widget.pgId,
          'floorId': widget.floorId,
          'roomId': widget.roomId,
          'bedId': widget.bedId,
        });
        writeSuccess = true;
      }
    } catch (e) {
      debugPrint('⚠️ Payment Firestore write failed: $e');
      errorMsg = e.toString();
    }

    if (!mounted) return;

    if (!writeSuccess) {
      // Show error but still let user proceed — payment was done on PayU side
      await showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Payment Recording Issue'),
          content: Text(
            'Your payment was processed on PayU, but we had trouble recording it.\n\n'
            'Error: ${errorMsg ?? "Unknown"}\n\n'
            'Please contact admin if your payment is not reflected.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      if (!mounted) return;
    }

    // Navigate to success screen
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (ctx) => const PaymentStatusScreen(isSuccess: true),
      ),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    const teal = Color(0xFF14B8A6);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Complete Payment'),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Animated waiting icon
              Container(
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(
                  color: teal.withValues(alpha: 0.08),
                  shape: BoxShape.circle,
                ),
                child: _isProcessing
                    ? const SizedBox(
                        width: 64,
                        height: 64,
                        child: CircularProgressIndicator(
                          strokeWidth: 3,
                          color: teal,
                        ),
                      )
                    : const Icon(
                        Icons.open_in_new_rounded,
                        size: 64,
                        color: teal,
                      ),
              ),
              const SizedBox(height: 32),
              Text(
                _isProcessing ? 'Recording Payment...' : 'Payment In Progress',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1E293B),
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                'Complete your payment on the PayU gateway tab.\nOnce done, come back here and tap the button below.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Color(0xFF64748B),
                  height: 1.6,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Text(
                  'TXN: ${widget.txnId}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF94A3B8),
                    fontFamily: 'monospace',
                  ),
                ),
              ),
              const SizedBox(height: 40),

              // Primary action — user has completed payment
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isProcessing ? null : _confirmPayment,
                  icon: const Icon(Icons.check_circle_outline_rounded, size: 20),
                  label: const Text(
                    'I\'ve Completed Payment',
                    style: TextStyle(
                      fontSize: 16,
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
              const SizedBox(height: 14),

              // Secondary — payment failed or cancelled
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: _isProcessing
                      ? null
                      : () {
                          Navigator.of(context).pushAndRemoveUntil(
                            MaterialPageRoute(
                              builder: (ctx) =>
                                  const PaymentStatusScreen(isSuccess: false),
                            ),
                            (route) => false,
                          );
                        },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF64748B),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    side: const BorderSide(color: Color(0xFFE2E8F0)),
                  ),
                  child: const Text(
                    'Payment Failed / Cancel',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
