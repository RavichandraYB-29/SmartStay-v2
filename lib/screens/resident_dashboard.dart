import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ResidentDashboard extends StatelessWidget {
  const ResidentDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    final String userId = FirebaseAuth.instance.currentUser!.uid;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Resident Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              Navigator.pushNamedAndRemoveUntil(context, '/', (_) => false);
            },
          ),
        ],
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final data = snapshot.data!.data() as Map<String, dynamic>?;

          /// ================= NOT ASSIGNED =================
          if (data == null || data['stayStatus'] != 'active') {
            return const Center(
              child: Text(
                'Room not yet assigned.\nPlease contact admin.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 18),
              ),
            );
          }

          /// ================= ASSIGNED =================
          final String hostelId = data['assignedHostelId'];
          final String floorId = data['assignedFloorId'];
          final String roomId = data['assignedRoomId'];
          final Timestamp checkInDate = data['checkInDate'];

          return Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _infoCard(
                  title: 'Stay Status',
                  value: 'Active',
                  icon: Icons.verified,
                ),

                const SizedBox(height: 10),

                _infoCard(
                  title: 'Check-in Date',
                  value: checkInDate.toDate().toLocal().toString().split(
                    ' ',
                  )[0],
                  icon: Icons.calendar_today,
                ),

                const SizedBox(height: 20),

                /// ================= HOSTEL =================
                StreamBuilder<DocumentSnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('hostels')
                      .doc(hostelId)
                      .snapshots(),
                  builder: (context, hostelSnap) {
                    if (!hostelSnap.hasData) {
                      return const CircularProgressIndicator();
                    }

                    final hostel =
                        hostelSnap.data!.data() as Map<String, dynamic>;

                    return _infoCard(
                      title: 'Hostel',
                      value: hostel['name'],
                      icon: Icons.apartment,
                    );
                  },
                ),

                const SizedBox(height: 10),

                /// ================= FLOOR =================
                StreamBuilder<DocumentSnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('hostels')
                      .doc(hostelId)
                      .collection('floors')
                      .doc(floorId)
                      .snapshots(),
                  builder: (context, floorSnap) {
                    if (!floorSnap.hasData) {
                      return const CircularProgressIndicator();
                    }

                    final floor =
                        floorSnap.data!.data() as Map<String, dynamic>;

                    return _infoCard(
                      title: 'Floor',
                      value: floor['name'],
                      icon: Icons.layers,
                    );
                  },
                ),

                const SizedBox(height: 10),

                /// ================= ROOM =================
                StreamBuilder<DocumentSnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('hostels')
                      .doc(hostelId)
                      .collection('floors')
                      .doc(floorId)
                      .collection('rooms')
                      .doc(roomId)
                      .snapshots(),
                  builder: (context, roomSnap) {
                    if (!roomSnap.hasData) {
                      return const CircularProgressIndicator();
                    }

                    final room = roomSnap.data!.data() as Map<String, dynamic>;

                    return _infoCard(
                      title: 'Room',
                      value: 'Room ${room['roomNumber']}',
                      icon: Icons.meeting_room,
                    );
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  /// ================= REUSABLE CARD =================
  Widget _infoCard({
    required String title,
    required String value,
    required IconData icon,
  }) {
    return Card(
      elevation: 2,
      child: ListTile(
        leading: Icon(icon),
        title: Text(title),
        subtitle: Text(
          value,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}
