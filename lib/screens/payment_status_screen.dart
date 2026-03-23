import 'package:flutter/material.dart';
import 'resident_dashboard.dart';

class PaymentStatusScreen extends StatelessWidget {
  final bool isSuccess;

  const PaymentStatusScreen({super.key, required this.isSuccess});

  @override
  Widget build(BuildContext context) {
    const teal = Color(0xFF14B8A6);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(isSuccess ? 'Payment Successful' : 'Payment Failed'),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false, // Force them to use the button below
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: isSuccess ? teal.withValues(alpha: 0.1) : Colors.redAccent.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isSuccess ? Icons.check_circle_rounded : Icons.cancel_rounded,
                  size: 80,
                  color: isSuccess ? teal : Colors.redAccent,
                ),
              ),
              const SizedBox(height: 32),
              Text(
                isSuccess ? 'Payment Completed!' : 'Payment Failed',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1E293B),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                isSuccess 
                  ? 'Your rent has been paid successfully. The dashboard will now reflect your updated payment status.' 
                  : 'Something went wrong with your transaction. No charges were made.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 15,
                  color: Color(0xFF64748B),
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 48),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    // Pop everything and replace with Dashboard to ensure clean state
                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(builder: (context) => const ResidentDashboard()),
                      (Route<dynamic> route) => false,
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: teal,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: const Text(
                    'Return to Dashboard',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
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
