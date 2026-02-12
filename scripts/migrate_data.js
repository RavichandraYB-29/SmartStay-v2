import fs from 'fs';
import admin from 'firebase-admin';

const serviceAccountPath =
  process.env.GOOGLE_APPLICATION_CREDENTIALS ||
  process.env.SERVICE_ACCOUNT_PATH;

if (!serviceAccountPath) {
  console.error(
    'Missing service account. Set GOOGLE_APPLICATION_CREDENTIALS or SERVICE_ACCOUNT_PATH.',
  );
  process.exit(1);
}

const serviceAccount = JSON.parse(fs.readFileSync(serviceAccountPath, 'utf8'));
admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
});

const db = admin.firestore();
const DRY_RUN = process.env.DRY_RUN === 'true';
const DELETE_OLD = process.env.DELETE_OLD === 'true';

let batch = db.batch();
let batchOps = 0;

async function commitBatch(force = false) {
  if (DRY_RUN) {
    batch = db.batch();
    batchOps = 0;
    return;
  }
  if (!force && batchOps < 400) return;
  if (batchOps === 0) return;
  await batch.commit();
  batch = db.batch();
  batchOps = 0;
}

async function queueSet(ref, data, options) {
  if (DRY_RUN) return;
  batch.set(ref, data, options);
  batchOps += 1;
  await commitBatch();
}

async function queueUpdate(ref, data) {
  if (DRY_RUN) return;
  batch.update(ref, data);
  batchOps += 1;
  await commitBatch();
}

async function queueDelete(ref) {
  if (DRY_RUN) return;
  batch.delete(ref);
  batchOps += 1;
  await commitBatch();
}

function toInt(value) {
  if (typeof value === 'number') return value;
  if (typeof value === 'string') return parseInt(value, 10) || 0;
  return 0;
}

async function migrateHostelsToPgs() {
  const adminToPgIds = new Map();
  const hostelsSnap = await db.collection('hostels').get();

  for (const hostel of hostelsSnap.docs) {
    const hostelId = hostel.id;
    const hostelData = hostel.data();
    const adminId = hostelData.adminId || hostelData.ownerId;
    const ownerId = hostelData.ownerId || hostelData.adminId;

    const pgId = hostelId;
    const pgRef = hostel.ref.collection('pgs').doc(pgId);
    const pgSnap = await pgRef.get();
    if (!pgSnap.exists) {
      await queueSet(
        pgRef,
        {
          name: hostelData.name || 'PG',
          pgName: hostelData.name || 'PG',
          adminId,
          ownerId,
          hostelId,
          floors: 0,
          totalBeds: 0,
          availableBeds: 0,
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
        },
        { merge: true },
      );
    }

    if (adminId) {
      if (!adminToPgIds.has(adminId)) adminToPgIds.set(adminId, new Set());
      adminToPgIds.get(adminId).add(pgId);
    }

    let pgTotalBeds = 0;
    let pgAvailableBeds = 0;
    let pgFloors = 0;

    const oldFloorsSnap = await hostel.ref.collection('floors').get();
    for (const floor of oldFloorsSnap.docs) {
      pgFloors += 1;
      const floorId = floor.id;
      const floorData = floor.data();
      const newFloorRef = pgRef.collection('floors').doc(floorId);

      let floorTotalBeds = 0;
      let floorAvailableBeds = 0;

      const oldRoomsSnap = await floor.ref.collection('rooms').get();
      for (const room of oldRoomsSnap.docs) {
        const roomData = room.data();
        const oldBedsSnap = await room.ref.collection('beds').get();
        let totalBeds = 0;
        let availableBeds = 0;

        if (oldBedsSnap.docs.length > 0) {
          totalBeds = oldBedsSnap.docs.length;
          availableBeds = oldBedsSnap.docs.filter(
            (b) => b.data().isOccupied !== true,
          ).length;
        } else {
          const candidateTotal =
            roomData.totalBeds || roomData.bedCount || roomData.beds;
          if (Array.isArray(candidateTotal)) {
            totalBeds = candidateTotal.length;
          } else {
            totalBeds = toInt(candidateTotal);
          }
          const occupiedBeds = toInt(roomData.occupiedBeds);
          availableBeds = Math.max(0, totalBeds - occupiedBeds);
        }

        const newRoomRef = newFloorRef.collection('rooms').doc(room.id);
        await queueSet(
          newRoomRef,
          {
            ...roomData,
            hostelId,
            pgId,
            floorId,
            totalBeds,
            availableBeds,
            occupiedBeds: Math.max(0, totalBeds - availableBeds),
          },
          { merge: true },
        );

        for (const bed of oldBedsSnap.docs) {
          const newBedRef = newRoomRef.collection('beds').doc(bed.id);
          await queueSet(newBedRef, bed.data(), { merge: true });
        }

        if (DELETE_OLD) {
          for (const bed of oldBedsSnap.docs) {
            await queueDelete(bed.ref);
          }
          await queueDelete(room.ref);
        }

        floorTotalBeds += totalBeds;
        floorAvailableBeds += availableBeds;
      }

      await queueSet(
        newFloorRef,
        {
          ...floorData,
          hostelId,
          pgId,
          totalRooms: oldRoomsSnap.docs.length,
          totalBeds: floorTotalBeds,
          availableBeds: floorAvailableBeds,
        },
        { merge: true },
      );

      if (DELETE_OLD) {
        await queueDelete(floor.ref);
      }

      pgTotalBeds += floorTotalBeds;
      pgAvailableBeds += floorAvailableBeds;
    }

    await queueSet(
      pgRef,
      {
        hostelId,
        totalBeds: pgTotalBeds,
        availableBeds: pgAvailableBeds,
        floors: pgFloors,
      },
      { merge: true },
    );
  }

  await commitBatch(true);
  return adminToPgIds;
}

async function migrateResidents() {
  const residentsSnap = await db.collection('residents').get();
  for (const resident of residentsSnap.docs) {
    const data = resident.data();
    const alloc = data.allocationDetails || {};
    const hostelId = data.hostelId || alloc.hostelId;
    const pgId = data.pgId || alloc.pgId || hostelId || null;
    if (!hostelId || !pgId) continue;

    const updates = {
      pgId,
      allocationDetails: {
        ...alloc,
        hostelId: hostelId,
        pgId,
      },
    };

    await queueUpdate(resident.ref, updates);
  }
  await commitBatch(true);
}

async function migrateNotices(adminToPgIds) {
  const noticesSnap = await db.collection('notices').get();
  for (const notice of noticesSnap.docs) {
    const data = notice.data();
    const updates = {};

    if (!data.message && data.description) {
      updates.message = data.description;
    }

    let scope = data.scope;
    if (!scope && data.audienceType) {
      if (data.audienceType === 'all') scope = 'ALL';
      if (data.audienceType === 'hostel') scope = 'PG';
      if (data.audienceType === 'resident') scope = 'RESIDENT';
      updates.scope = scope;
    }

    if (!data.isActive) updates.isActive = true;
    if (!data.hostelOwnerId && data.createdByAdminId) {
      updates.hostelOwnerId = data.createdByAdminId;
    }

    if (scope === 'PG' && !data.pgIds) {
      const hostelId = data.hostelId;
      updates.pgIds = hostelId ? [hostelId] : [];
    }
    if (scope === 'RESIDENT' && !data.residentIds) {
      const residentId = data.residentId;
      updates.residentIds = residentId ? [residentId] : [];
    }
    if (scope === 'ALL' && !data.pgIds) {
      const adminId = data.createdByAdminId;
      const pgIds = adminId && adminToPgIds.has(adminId)
        ? Array.from(adminToPgIds.get(adminId))
        : [];
      updates.pgIds = pgIds;
    }

    if (Object.keys(updates).length > 0) {
      await queueUpdate(notice.ref, updates);
    }
  }
  await commitBatch(true);
}

async function main() {
  console.log('Starting migration...');
  console.log(`DRY_RUN=${DRY_RUN} DELETE_OLD=${DELETE_OLD}`);

  const adminToPgIds = await migrateHostelsToPgs();
  await migrateResidents();
  await migrateNotices(adminToPgIds);

  console.log('Migration completed.');
}

main().catch((err) => {
  console.error('Migration failed:', err);
  process.exit(1);
});
