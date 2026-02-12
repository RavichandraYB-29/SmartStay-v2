import 'package:cloud_firestore/cloud_firestore.dart';

class RoomService {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Get room capacity summary
  /// Returns: totalBeds, occupiedBeds, freeBeds
  static Future<Map<String, int>> getRoomCapacity({
    required String hostelId,
    required String pgId,
    required String floorId,
    required String roomId,
  }) async {
    final bedsSnapshot = await _db
        .collection('hostels')
        .doc(hostelId)
        .collection('pgs')
        .doc(pgId)
        .collection('floors')
        .doc(floorId)
        .collection('rooms')
        .doc(roomId)
        .collection('beds')
        .get();

    final totalBeds = bedsSnapshot.docs.length;
    int occupiedBeds = 0;

    for (final doc in bedsSnapshot.docs) {
      if (doc.data()['isOccupied'] == true) {
        occupiedBeds++;
      }
    }

    final freeBeds = totalBeds - occupiedBeds;

    return {
      'totalBeds': totalBeds,
      'occupiedBeds': occupiedBeds,
      'freeBeds': freeBeds,
    };
  }

  /// Get list of FREE beds only
  static Future<List<QueryDocumentSnapshot>> getFreeBeds({
    required String hostelId,
    required String pgId,
    required String floorId,
    required String roomId,
  }) async {
    final freeBedsSnapshot = await _db
        .collection('hostels')
        .doc(hostelId)
        .collection('pgs')
        .doc(pgId)
        .collection('floors')
        .doc(floorId)
        .collection('rooms')
        .doc(roomId)
        .collection('beds')
        .where('isOccupied', isEqualTo: false)
        .get();

    return freeBedsSnapshot.docs;
  }
}
