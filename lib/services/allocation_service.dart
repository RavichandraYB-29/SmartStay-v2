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
    required String pgId,
    required String floorId,
    required String roomId,
    required String bedId,
  }) async {
    final residentRef = _db.collection('residents').doc(residentId);
    final hostelRef = _db.collection('hostels').doc(hostelId);
    final pgRef = hostelRef.collection('pgs').doc(pgId);
    final floorRef = pgRef.collection('floors').doc(floorId);
    final roomRef = floorRef.collection('rooms').doc(roomId);
    final bedRef = roomRef.collection('beds').doc(bedId);

    await _db.runTransaction((tx) async {
      int toInt(dynamic value) {
        if (value is int) return value;
        if (value is String) return int.tryParse(value) ?? 0;
        return 0;
      }

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
      final prevPgId = (resident['pgId'] ?? alloc['pgId'])?.toString();
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

      final pgSnap = await tx.get(pgRef);
      if (!pgSnap.exists) throw Exception('PG does not exist');
      final pg = pgSnap.data() as Map<String, dynamic>;

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
            prevPgId != null &&
            prevFloorId != null &&
            prevRoomId != null &&
            prevBedId != null) {
          final prevBedRef = _db
              .collection('hostels')
              .doc(prevHostelId)
              .collection('pgs')
              .doc(prevPgId)
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

          // decrement old room counters only if changing rooms
          if (changingRoom) {
            final prevRoomRef = _db
                .collection('hostels')
                .doc(prevHostelId)
                .collection('pgs')
                .doc(prevPgId)
                .collection('floors')
                .doc(prevFloorId)
                .collection('rooms')
                .doc(prevRoomId);
            final prevRoomSnap = await tx.get(prevRoomRef);
            if (prevRoomSnap.exists) {
              final prevRoom = prevRoomSnap.data() as Map<String, dynamic>;
              final prevTotal = toInt(prevRoom['totalBeds']);
              final prevOcc = toInt(prevRoom['occupiedBeds']);
              final prevAvail = prevRoom.containsKey('availableBeds')
                  ? toInt(prevRoom['availableBeds'])
                  : (prevTotal - prevOcc);
              tx.update(prevRoomRef, {
                'occupiedBeds': (prevOcc - 1).clamp(0, 1 << 30),
                'availableBeds': (prevAvail + 1).clamp(0, prevTotal),
              });
            }

            final prevFloorRef = _db
                .collection('hostels')
                .doc(prevHostelId)
                .collection('pgs')
                .doc(prevPgId)
                .collection('floors')
                .doc(prevFloorId);
            final prevFloorSnap = await tx.get(prevFloorRef);
            if (prevFloorSnap.exists) {
              final prevFloor = prevFloorSnap.data() as Map<String, dynamic>;
              final prevTotal = toInt(prevFloor['totalBeds']);
              final prevAvail = prevFloor.containsKey('availableBeds')
                  ? toInt(prevFloor['availableBeds'])
                  : prevTotal;
              tx.update(prevFloorRef, {
                'availableBeds': (prevAvail + 1).clamp(0, prevTotal),
              });
            }

            final prevPgRef = _db
                .collection('hostels')
                .doc(prevHostelId)
                .collection('pgs')
                .doc(prevPgId);
            final prevPgSnap = await tx.get(prevPgRef);
            if (prevPgSnap.exists) {
              final prevPg = prevPgSnap.data() as Map<String, dynamic>;
              final prevTotal = toInt(prevPg['totalBeds']);
              final prevAvail = prevPg.containsKey('availableBeds')
                  ? toInt(prevPg['availableBeds'])
                  : prevTotal;
              tx.update(prevPgRef, {
                'availableBeds': (prevAvail + 1).clamp(0, prevTotal),
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

      // increment new room counters when:
      // - previously unallocated, OR
      // - moved from different room
      if (!prevAllocated || changingRoom) {
        final total = toInt(room['totalBeds']);
        final occ = toInt(room['occupiedBeds']);
        final avail = room.containsKey('availableBeds')
            ? toInt(room['availableBeds'])
            : (total - occ);
        tx.update(roomRef, {
          'occupiedBeds': occ + 1,
          'availableBeds': (avail - 1).clamp(0, total),
        });

        final floorTotal = toInt(floor['totalBeds']);
        final floorAvail = floor.containsKey('availableBeds')
            ? toInt(floor['availableBeds'])
            : floorTotal;
        tx.update(floorRef, {
          'availableBeds': (floorAvail - 1).clamp(0, floorTotal),
        });

        final pgTotal = toInt(pg['totalBeds']);
        final pgAvail = pg.containsKey('availableBeds')
            ? toInt(pg['availableBeds'])
            : pgTotal;
        tx.update(pgRef, {'availableBeds': (pgAvail - 1).clamp(0, pgTotal)});
      }

      final hostelName = (hostel['name'] ?? '').toString();
      final floorName = (floor['floorName'] ?? '').toString();
      final roomNumber = (room['roomNumber'] ?? '').toString();
      final bedNumber = (bed['bedNumber'] ?? bedId).toString();

      tx.update(residentRef, {
        'isAllocated': true,
        'allocationStatus': 'active',
        'hostelId': hostelId,
        'pgId': pgId,
        'floorId': floorId,
        'roomId': roomId,
        'bedId': bedId,
        // keep backward compatibility with existing UI
        'bedSlot': bedId,
        'allocatedAt': FieldValue.serverTimestamp(),
        'allocationDetails': {
          'hostelId': hostelId,
          'pgId': pgId,
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
    required String pgId,
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
        .collection('pgs')
        .doc(pgId)
        .collection('floors')
        .doc(floorId)
        .collection('rooms')
        .doc(roomId)
        .collection('beds')
        .doc(bedId);

    await _db.runTransaction((tx) async {
      int toInt(dynamic value) {
        if (value is int) return value;
        if (value is String) return int.tryParse(value) ?? 0;
        return 0;
      }

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

      final roomRef = _db
          .collection('hostels')
          .doc(hostelId)
          .collection('pgs')
          .doc(pgId)
          .collection('floors')
          .doc(floorId)
          .collection('rooms')
          .doc(roomId);
      final floorRef = _db
          .collection('hostels')
          .doc(hostelId)
          .collection('pgs')
          .doc(pgId)
          .collection('floors')
          .doc(floorId);
      final pgRef = _db
          .collection('hostels')
          .doc(hostelId)
          .collection('pgs')
          .doc(pgId);

      final roomSnap = await tx.get(roomRef);
      final floorSnap = await tx.get(floorRef);
      final pgSnap = await tx.get(pgRef);

      if (roomSnap.exists) {
        final room = roomSnap.data() as Map<String, dynamic>;
        final total = toInt(room['totalBeds']);
        final occ = toInt(room['occupiedBeds']);
        final avail = room.containsKey('availableBeds')
            ? toInt(room['availableBeds'])
            : (total - occ);
        tx.update(roomRef, {
          'occupiedBeds': occ + 1,
          'availableBeds': (avail - 1).clamp(0, total),
        });
      }

      if (floorSnap.exists) {
        final floor = floorSnap.data() as Map<String, dynamic>;
        final total = toInt(floor['totalBeds']);
        final avail = floor.containsKey('availableBeds')
            ? toInt(floor['availableBeds'])
            : total;
        tx.update(floorRef, {'availableBeds': (avail - 1).clamp(0, total)});
      }

      if (pgSnap.exists) {
        final pg = pgSnap.data() as Map<String, dynamic>;
        final total = toInt(pg['totalBeds']);
        final avail = pg.containsKey('availableBeds')
            ? toInt(pg['availableBeds'])
            : total;
        tx.update(pgRef, {'availableBeds': (avail - 1).clamp(0, total)});
      }

      tx.update(residentRef, {
        'isAllocated': true,
        'hostelId': hostelId,
        'pgId': pgId,
        'floorId': floorId,
        'roomId': roomId,
        'bedSlot': bedId,
        'allocationDetails': {
          'hostelId': hostelId,
          'pgId': pgId,
          'floorId': floorId,
          'roomId': roomId,
          'bedSlot': bedId,
        },
      });
    });
  }

  /// Deallocate a resident and free their bed (ADMIN ONLY).
  static Future<void> deallocateResident({
    required String adminId,
    required String residentId,
  }) async {
    final residentRef = _db.collection('residents').doc(residentId);

    await _db.runTransaction((tx) async {
      int toInt(dynamic value) {
        if (value is int) return value;
        if (value is String) return int.tryParse(value) ?? 0;
        return 0;
      }

      final residentSnap = await tx.get(residentRef);
      if (!residentSnap.exists) throw Exception('Resident does not exist');
      final resident = residentSnap.data() as Map<String, dynamic>;

      if (resident['adminId']?.toString() != adminId) {
        throw Exception('Missing or insufficient permissions.');
      }

      if (resident['isAllocated'] != true) {
        tx.update(residentRef, {
          'isAllocated': false,
          'allocationStatus': 'inactive',
          'allocationDetails': null,
        });
        return;
      }

      final alloc = resident['allocationDetails'] is Map<String, dynamic>
          ? (resident['allocationDetails'] as Map<String, dynamic>)
          : <String, dynamic>{};

      final hostelId = (resident['hostelId'] ?? alloc['hostelId'])?.toString();
      final pgId = (resident['pgId'] ?? alloc['pgId'])?.toString();
      final floorId = (resident['floorId'] ?? alloc['floorId'])?.toString();
      final roomId = (resident['roomId'] ?? alloc['roomId'])?.toString();
      final bedId =
          (resident['bedId'] ??
                  resident['bedSlot'] ??
                  alloc['bedId'] ??
                  alloc['bedSlot'])
              ?.toString();

      if (hostelId == null ||
          pgId == null ||
          floorId == null ||
          roomId == null ||
          bedId == null) {
        tx.update(residentRef, {
          'isAllocated': false,
          'allocationStatus': 'inactive',
          'allocationDetails': null,
        });
        return;
      }

      final bedRef = _db
          .collection('hostels')
          .doc(hostelId)
          .collection('pgs')
          .doc(pgId)
          .collection('floors')
          .doc(floorId)
          .collection('rooms')
          .doc(roomId)
          .collection('beds')
          .doc(bedId);
      final roomRef = _db
          .collection('hostels')
          .doc(hostelId)
          .collection('pgs')
          .doc(pgId)
          .collection('floors')
          .doc(floorId)
          .collection('rooms')
          .doc(roomId);
      final floorRef = _db
          .collection('hostels')
          .doc(hostelId)
          .collection('pgs')
          .doc(pgId)
          .collection('floors')
          .doc(floorId);
      final pgRef = _db
          .collection('hostels')
          .doc(hostelId)
          .collection('pgs')
          .doc(pgId);

      final bedSnap = await tx.get(bedRef);
      if (bedSnap.exists) {
        final bed = bedSnap.data() as Map<String, dynamic>;
        final occupiedBy = (bed['residentId'] ?? bed['occupiedBy'])?.toString();
        if (bed['isOccupied'] == true && occupiedBy == residentId) {
          tx.update(bedRef, {
            'isOccupied': false,
            'residentId': null,
            'occupiedBy': null,
          });
        }
      }

      final roomSnap = await tx.get(roomRef);
      if (roomSnap.exists) {
        final room = roomSnap.data() as Map<String, dynamic>;
        final total = toInt(room['totalBeds']);
        final occ = toInt(room['occupiedBeds']);
        final avail = room.containsKey('availableBeds')
            ? toInt(room['availableBeds'])
            : (total - occ);
        tx.update(roomRef, {
          'occupiedBeds': (occ - 1).clamp(0, 1 << 30),
          'availableBeds': (avail + 1).clamp(0, total),
        });
      }

      final floorSnap = await tx.get(floorRef);
      if (floorSnap.exists) {
        final floor = floorSnap.data() as Map<String, dynamic>;
        final total = toInt(floor['totalBeds']);
        final avail = floor.containsKey('availableBeds')
            ? toInt(floor['availableBeds'])
            : total;
        tx.update(floorRef, {'availableBeds': (avail + 1).clamp(0, total)});
      }

      final pgSnap = await tx.get(pgRef);
      if (pgSnap.exists) {
        final pg = pgSnap.data() as Map<String, dynamic>;
        final total = toInt(pg['totalBeds']);
        final avail = pg.containsKey('availableBeds')
            ? toInt(pg['availableBeds'])
            : total;
        tx.update(pgRef, {'availableBeds': (avail + 1).clamp(0, total)});
      }

      tx.update(residentRef, {
        'isAllocated': false,
        'allocationStatus': 'inactive',
        'hostelId': null,
        'pgId': null,
        'floorId': null,
        'roomId': null,
        'bedId': null,
        'bedSlot': null,
        'allocationDetails': null,
      });
    });
  }
}
