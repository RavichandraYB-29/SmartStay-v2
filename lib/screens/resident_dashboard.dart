import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'login_screen.dart';

class ResidentDashboard extends StatefulWidget {
  const ResidentDashboard({super.key});

  @override
  State<ResidentDashboard> createState() => _ResidentDashboardState();
}

class _ResidentDashboardState extends State<ResidentDashboard> {
  bool isLoading = true;
  Map<String, dynamic>? resident;
  bool isAllocated = false;

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
    _loadResident();
  }

  /* ======================
     LOAD RESIDENT DATA
  ====================== */

  Future<void> _loadResident() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _logout();
      return;
    }

    try {
      if (!user.emailVerified) {
        await _showBlockedDialog(
          'Email Verification Required',
          'Please verify your email before accessing the dashboard.',
        );
        _logout();
        return;
      }

      /// 1️⃣ Load user profile
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (!userDoc.exists || userDoc['role'] != 'resident') {
        _logout();
        return;
      }

      /// 2️⃣ Load resident document by uid
      final residentSnap = await FirebaseFirestore.instance
          .collection('residents')
          .where('uid', isEqualTo: user.uid)
          .limit(1)
          .get();
      final residentDoc = residentSnap.docs.isNotEmpty
          ? residentSnap.docs.first
          : await FirebaseFirestore.instance
              .collection('residents')
              .doc('_missing')
              .get();

      if (!residentDoc.exists) {
        _logout();
        return;
      }

      final data = residentDoc.data() ?? {};
      final allocated = data['isAllocated'] == true;

      setState(() {
        resident = data;
        isAllocated = allocated;
        isLoading = false;
      });
    } catch (e) {
      _logout();
    }
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

  /* ======================
     BUILD
  ====================== */

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final name = resident!['name'] ?? resident!['fullName'] ?? 'Resident';
    final allocation = resident!['allocationDetails'] as Map<String, dynamic>?;
    final room = allocation?['roomNumber'] ??
        allocation?['roomId'] ??
        resident!['roomId'] ??
        '-';
    final bed = allocation?['bedNumber'] ??
        allocation?['bedSlot'] ??
        resident!['bedSlot'] ??
        '-';
    final deposit = resident!['deposit'] ?? 0;
    final monthlyFee = resident!['monthlyFee'] ?? 0;

    return Scaffold(
      backgroundColor: const Color(0xFFF6F8FB),
      appBar: _buildTopBar(),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 30),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _welcomeBanner(name, room, bed),
            const SizedBox(height: 20),
            if (isAllocated) _roomAndStats(room, bed),
            if (!isAllocated)
              _infoCard(
                title: 'Allocation Pending',
                message:
                    'Your account is registered. Room allocation will appear here once assigned.',
              ),
            const SizedBox(height: 20),
            if (isAllocated) _paymentSection(deposit, monthlyFee),
          ],
        ),
      ),
    );
  }

  /* ======================
     UI (UNCHANGED)
  ====================== */

  AppBar _buildTopBar() {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0.8,
      centerTitle: true,
      title: const Column(
        children: [
          Text(
            "SmartStay",
            style: TextStyle(fontWeight: FontWeight.w600, color: Colors.black),
          ),
          SizedBox(height: 2),
          Text(
            "Resident Portal",
            style: TextStyle(fontSize: 12, color: Colors.black54),
          ),
        ],
      ),
    );
  }

  Widget _welcomeBanner(String name, String room, String bed) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF14B8A6), Color(0xFF06B6D4)],
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          const CircleAvatar(
            radius: 28,
            backgroundColor: Colors.white,
            child: Text(
              "R",
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Color(0xFF14B8A6),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Welcome back, $name!",
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                "Room $room • Bed $bed",
                style: const TextStyle(color: Colors.white70),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _roomAndStats(String room, String bed) {
    return Row(
      children: [
        Expanded(
          child: _card(
            "My Room Details",
            Icons.bed,
            Column(children: [_info("Room ID", room), _info("Bed Slot", bed)]),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: _card(
            "Quick Stats",
            Icons.trending_up,
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _StatusRow("Payment Status", "Active"),
                SizedBox(height: 12),
                _StatusRow("Complaints", "0"),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _paymentSection(int deposit, int monthlyFee) {
    return _card(
      "Payments",
      Icons.currency_rupee,
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _info("Deposit Paid", "₹$deposit"),
          _info("Monthly Fee", "₹$monthlyFee"),
        ],
      ),
    );
  }

  Widget _card(String title, IconData icon, Widget child) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 18),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ],
            ),
            const SizedBox(height: 14),
            child,
          ],
        ),
      ),
    );
  }

  Widget _infoCard({required String title, required String message}) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const Icon(Icons.info_outline, color: Color(0xFF2563EB)),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Text(message, style: const TextStyle(color: Colors.black54)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _info(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

/* ======================
   SMALL WIDGETS
====================== */

class _StatusRow extends StatelessWidget {
  final String label;
  final String value;
  const _StatusRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label),
        Chip(label: Text(value)),
      ],
    );
  }
}
