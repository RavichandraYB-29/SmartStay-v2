import 'package:cloud_firestore/cloud_firestore.dart';

class AllocationService {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Allocate OR re-allocate a resident to a bed (ADMIN ONLY).
  ///
  /// - Enforces admin isolation by validating `resident.adminId == adminId`
  /// - Uses a transaction to update:
  ///   - old bed (release) when changing
  ///   - new bed (occupy)
  ///   - room occupiedBeds counters
  ///   - resident allocation fields + allocationDetails
  static Future<void> upsertResidentAllocation({
    required String adminId,
    required String residentId,
    required String hostelId,
    required String floorId,
    required String roomId,
    required String bedId,
  }) async {
    final residentRef = _db.collection('residents').doc(residentId);
    final hostelRef = _db.collection('hostels').doc(hostelId);
    final floorRef = hostelRef.collection('floors').doc(floorId);
    final roomRef = floorRef.collection('rooms').doc(roomId);
    final bedRef = roomRef.collection('beds').doc(bedId);

    await _db.runTransaction((tx) async {
      final residentSnap = await tx.get(residentRef);
      if (!residentSnap.exists) throw Exception('Resident does not exist');
      final resident = residentSnap.data() as Map<String, dynamic>;

      if (resident['adminId']?.toString() != adminId) {
        throw Exception('Missing or insufficient permissions.');
      }

      final alloc = resident['allocationDetails'] is Map<String, dynamic>
          ? (resident['allocationDetails'] as Map<String, dynamic>)
          : <String, dynamic>{};

      final prevHostelId = (resident['hostelId'] ?? alloc['hostelId'])
          ?.toString();
      final prevFloorId = (resident['floorId'] ?? alloc['floorId'])?.toString();
      final prevRoomId = (resident['roomId'] ?? alloc['roomId'])?.toString();
      final prevBedId =
          (resident['bedId'] ??
                  resident['bedSlot'] ??
                  alloc['bedId'] ??
                  alloc['bedSlot'])
              ?.toString();

      final prevAllocated = resident['isAllocated'] == true;

      // Read target docs for display fields
      final hostelSnap = await tx.get(hostelRef);
      if (!hostelSnap.exists) throw Exception('Hostel does not exist');
      final hostel = hostelSnap.data() as Map<String, dynamic>;
      final hostelAdmin = hostel['adminId']?.toString();
      final hostelOwner = hostel['ownerId']?.toString();
      if (hostelAdmin != adminId && hostelOwner != adminId) {
        throw Exception('Missing or insufficient permissions.');
      }

      final floorSnap = await tx.get(floorRef);
      if (!floorSnap.exists) throw Exception('Floor does not exist');
      final floor = floorSnap.data() as Map<String, dynamic>;
      if (floor['adminId']?.toString() != adminId) {
        throw Exception('Missing or insufficient permissions.');
      }

      final roomSnap = await tx.get(roomRef);
      if (!roomSnap.exists) throw Exception('Room does not exist');
      final room = roomSnap.data() as Map<String, dynamic>;
      if (room['adminId']?.toString() != adminId) {
        throw Exception('Missing or insufficient permissions.');
      }

      // 1) Validate target bed
      final bedSnap = await tx.get(bedRef);
      if (!bedSnap.exists) throw Exception('Bed does not exist');
      final bed = bedSnap.data() as Map<String, dynamic>;

      final isOccupied = bed['isOccupied'] == true;
      final occupiedBy = (bed['residentId'] ?? bed['occupiedBy'])?.toString();
      if (isOccupied && occupiedBy != residentId) {
        throw Exception('Bed already occupied');
      }

      // 2) Release previous bed if changing beds/rooms
      final changingRoom = prevRoomId != null && prevRoomId != roomId;
      final changingBed = prevBedId != null && prevBedId != bedId;

      if (prevAllocated && (changingRoom || changingBed)) {
        if (prevHostelId != null &&
            prevFloorId != null &&
            prevRoomId != null &&
            prevBedId != null) {
          final prevBedRef = _db
              .collection('hostels')
              .doc(prevHostelId)
              .collection('floors')
              .doc(prevFloorId)
              .collection('rooms')
              .doc(prevRoomId)
              .collection('beds')
              .doc(prevBedId);
          final prevBedSnap = await tx.get(prevBedRef);
          if (prevBedSnap.exists) {
            final prevBed = prevBedSnap.data() as Map<String, dynamic>;
            final prevOccBy = (prevBed['residentId'] ?? prevBed['occupiedBy'])
                ?.toString();
            if (prevBed['isOccupied'] == true && prevOccBy == residentId) {
              tx.update(prevBedRef, {
                'isOccupied': false,
                'residentId': null,
                'occupiedBy': null,
              });
            }
          }

          // decrement old room occupiedBeds only if changing rooms
          if (changingRoom) {
            final prevRoomRef = _db
                .collection('hostels')
                .doc(prevHostelId)
                .collection('floors')
                .doc(prevFloorId)
                .collection('rooms')
                .doc(prevRoomId);
            final prevRoomSnap = await tx.get(prevRoomRef);
            if (prevRoomSnap.exists) {
              final prevRoom = prevRoomSnap.data() as Map<String, dynamic>;
              final ob = (prevRoom['occupiedBeds'] ?? 0) is int
                  ? (prevRoom['occupiedBeds'] ?? 0) as int
                  : int.tryParse('${prevRoom['occupiedBeds']}') ?? 0;
              tx.update(prevRoomRef, {
                'occupiedBeds': (ob - 1).clamp(0, 1 << 30),
              });
            }
          }
        }
      }

      // 3) Occupy new bed (no-op if already occupied by same resident)
      tx.update(bedRef, {
        'isOccupied': true,
        'residentId': residentId,
        'occupiedBy': residentId,
      });

      // increment new room occupiedBeds when:
      // - previously unallocated, OR
      // - moved from different room
      if (!prevAllocated || changingRoom) {
        final ob = (room['occupiedBeds'] ?? 0) is int
            ? (room['occupiedBeds'] ?? 0) as int
            : int.tryParse('${room['occupiedBeds']}') ?? 0;
        tx.update(roomRef, {'occupiedBeds': (ob + 1)});
      }

      final hostelName = (hostel['name'] ?? '').toString();
      final floorName = (floor['floorName'] ?? '').toString();
      final roomNumber = (room['roomNumber'] ?? '').toString();
      final bedNumber = (bed['bedNumber'] ?? bedId).toString();

      tx.update(residentRef, {
        'isAllocated': true,
        'allocationStatus': 'active',
        'hostelId': hostelId,
        'floorId': floorId,
        'roomId': roomId,
        'bedId': bedId,
        // keep backward compatibility with existing UI
        'bedSlot': bedId,
        'allocatedAt': FieldValue.serverTimestamp(),
        'allocationDetails': {
          'hostelId': hostelId,
          'hostelName': hostelName,
          'floorId': floorId,
          'floorName': floorName,
          'roomId': roomId,
          'roomNumber': roomNumber,
          'bedId': bedId,
          'bedNumber': bedNumber,
          'bedSlot': bedId,
          'allocatedAt': FieldValue.serverTimestamp(),
        },
      });
    });
  }

  /// Legacy: first-time allocation only (kept for compatibility).
  static Future<void> allocateResidentToBed({
    required String residentId,
    required String hostelId,
    required String floorId,
    required String roomId,
    required String bedId,
  }) async {
    // For older call sites, we do not have adminId here.
    // This method keeps the original behavior (no reallocation).
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

    await _db.runTransaction((tx) async {
      final bedSnapshot = await tx.get(bedRef);
      if (!bedSnapshot.exists) throw Exception('Bed does not exist');
      final bedData = bedSnapshot.data() as Map<String, dynamic>;
      if (bedData['isOccupied'] == true)
        throw Exception('Bed already occupied');

      final residentSnapshot = await tx.get(residentRef);
      if (!residentSnapshot.exists) throw Exception('Resident does not exist');
      final residentData = residentSnapshot.data() as Map<String, dynamic>;
      if (residentData['isAllocated'] == true) {
        throw Exception('Resident already allocated');
      }

      tx.update(bedRef, {
        'isOccupied': true,
        'occupiedBy': residentId,
        'residentId': residentId,
      });
      tx.update(residentRef, {
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
