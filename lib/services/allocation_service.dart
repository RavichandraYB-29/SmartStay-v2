import 'package:cloud_firestore/cloud_firestore.dart';

class AllocationService {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Allocate a resident to a bed (ADMIN ONLY)
  static Future<void> allocateResidentToBed({
    required String residentId,
    required String hostelId,
    required String floorId,
    required String roomId,
    required String bedId,
  }) async {
    final residentRef = _db.collection('residents').doc(residentId);

    final bedRef = _db
        .collection('hostels')
        .doc(hostelId)
        .collection('floors')
        .doc(floorId)
        .collection('rooms')
        .doc(roomId)
        .collection('beds')
        .doc(bedId);

    await _db.runTransaction((transaction) async {
      // 1️⃣ Read bed
      final bedSnapshot = await transaction.get(bedRef);
      if (!bedSnapshot.exists) {
        throw Exception('Bed does not exist');
      }

      final bedData = bedSnapshot.data() as Map<String, dynamic>;

      // 2️⃣ Prevent double booking
      if (bedData['isOccupied'] == true) {
        throw Exception('Bed already occupied');
      }

      // 3️⃣ Read resident
      final residentSnapshot = await transaction.get(residentRef);
      if (!residentSnapshot.exists) {
        throw Exception('Resident does not exist');
      }

      final residentData = residentSnapshot.data() as Map<String, dynamic>;

      // Extra safety: prevent double allocation
      if (residentData['isAllocated'] == true) {
        throw Exception('Resident already allocated');
      }

      // 4️⃣ Update bed
      transaction.update(
        bedRef,
        {'isOccupied': true, 'occupiedBy': residentId, 'residentId': residentId},
      );

      // 5️⃣ Update resident
      transaction.update(residentRef, {
        'isAllocated': true,
        'hostelId': hostelId,
        'floorId': floorId,
        'roomId': roomId,
        'bedSlot': bedId,
        'allocationDetails': {
          'hostelId': hostelId,
          'floorId': floorId,
          'roomId': roomId,
          'bedSlot': bedId,
        },
      });
    });
  }
}
