import * as admin from "firebase-admin";
import * as functions from "firebase-functions";

admin.initializeApp();
const db = admin.firestore();

// ── Helper: today key ────────────────────────────────────────────────────────

function todayKey(): string {
  const now = new Date();
  const y = now.getFullYear();
  const m = String(now.getMonth() + 1).padStart(2, "0");
  const d = String(now.getDate()).padStart(2, "0");
  return `${y}${m}${d}`;
}

// ── Helper: week key ──────────────────────────────────────────────────────────

function weekKeyOf(d: Date): number {
  const startOfYear = new Date(d.getFullYear(), 0, 1);
  const dayOfYear =
    Math.floor((d.getTime() - startOfYear.getTime()) / 86400000) + 1;
  const weekOfYear = Math.ceil(
    (dayOfYear + startOfYear.getDay()) / 7
  );
  return d.getFullYear() * 100 + weekOfYear;
}

// ─────────────────────────────────────────────────────────────────────────────
// 1. Firestore trigger: when a waterGift is created, auto-apply to garden
// ─────────────────────────────────────────────────────────────────────────────

export const onWaterGiftCreated = functions.firestore
  .document("waterGifts/{giftId}")
  .onCreate(async (snap) => {
    const gift = snap.data();
    if (!gift || gift.applied === true) return;

    const toUid = gift.toUid as string;
    const amount = (gift.amount as number) ?? 20;

    try {
      const gardenRef = db.collection("gardens").doc(toUid);
      await db.runTransaction(async (tx) => {
        const garden = await tx.get(gardenRef);
        if (!garden.exists) return;

        const data = garden.data()!;
        const plots: Array<Record<string, unknown>> =
          Array.isArray(data.plots) ? [...data.plots] : [];

        // Find the driest occupied plot
        let driestIdx = -1;
        let driestHydration = Infinity;
        for (let i = 0; i < plots.length; i++) {
          const plot = plots[i] as Record<string, unknown>;
          const plant = plot.plant as Record<string, unknown> | null;
          if (!plant) continue;
          const h = (plant.hydration as number) ?? 0;
          if (h < driestHydration) {
            driestHydration = h;
            driestIdx = i;
          }
        }

        if (driestIdx >= 0) {
          const plot = { ...(plots[driestIdx] as Record<string, unknown>) };
          const plant = { ...(plot.plant as Record<string, unknown>) };
          plant.hydration = Math.min(
            100,
            (plant.hydration as number) + amount
          );
          plot.plant = plant;
          plots[driestIdx] = plot;
          tx.update(gardenRef, { plots, lastSaved: admin.firestore.FieldValue.serverTimestamp() });
        }

        // Mark gift as applied
        tx.update(snap.ref, { applied: true });
      });
    } catch (e) {
      functions.logger.error("onWaterGiftCreated error", e);
    }
  });

// ─────────────────────────────────────────────────────────────────────────────
// 2. Callable: claimDailyReward (server-side validation)
// ─────────────────────────────────────────────────────────────────────────────

export const claimDailyReward = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError("unauthenticated", "Login required");
  }

  const uid = context.auth.uid;
  const gardenRef = db.collection("gardens").doc(uid);

  return await db.runTransaction(async (tx) => {
    const garden = await tx.get(gardenRef);
    const d = garden.exists ? garden.data()! : {};

    const lastMs = (d.lastDailyRewardAt as number) ?? 0;
    const lastDate = lastMs ? new Date(lastMs) : null;
    const now = new Date();

    // Already claimed today?
    if (
      lastDate &&
      lastDate.getFullYear() === now.getFullYear() &&
      lastDate.getMonth() === now.getMonth() &&
      lastDate.getDate() === now.getDate()
    ) {
      throw new functions.https.HttpsError(
        "already-exists",
        "Already claimed today"
      );
    }

    // Consecutive days
    const streak = (d.consecutiveDays as number) ?? 0;
    let newStreak = 1;
    if (lastDate) {
      const yesterday = new Date(now);
      yesterday.setDate(yesterday.getDate() - 1);
      const wasYesterday =
        lastDate.getFullYear() === yesterday.getFullYear() &&
        lastDate.getMonth() === yesterday.getMonth() &&
        lastDate.getDate() === yesterday.getDate();
      newStreak = wasYesterday ? streak + 1 : 1;
    }

    const coins = 20 + Math.floor(Math.random() * 31);
    const seeds = 1 + Math.floor(Math.random() * 3);

    tx.set(
      gardenRef,
      {
        coins: admin.firestore.FieldValue.increment(coins),
        lastDailyRewardAt: now.getTime(),
        consecutiveDays: newStreak,
        lastSaved: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true }
    );

    return { coins, seeds, consecutiveDays: newStreak };
  });
});

// ─────────────────────────────────────────────────────────────────────────────
// 3. Callable: claimWeeklyReward (server-side rank validation)
// ─────────────────────────────────────────────────────────────────────────────

export const claimWeeklyReward = functions.https.onCall(async (_data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError("unauthenticated", "Login required");
  }

  const uid = context.auth.uid;
  const lastWeek = weekKeyOf(new Date(Date.now() - 7 * 86400000));
  const claimRef = db.collection("weeklyRewards").doc(`${lastWeek}_${uid}`);

  const claimed = await claimRef.get();
  if (claimed.exists) {
    throw new functions.https.HttpsError("already-exists", "Already claimed");
  }

  const snap = await db
    .collection("scores")
    .where("weekKey", "==", lastWeek)
    .orderBy("total", "descending")
    .limit(10)
    .get();

  const rank = snap.docs.findIndex((d) => d.id === uid) + 1;
  if (rank <= 0) {
    throw new functions.https.HttpsError("not-found", "Not in top 10");
  }

  const reward = rankReward(rank);
  await claimRef.set({
    uid,
    rank,
    claimedAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  return { rank, ...reward };
});

function rankReward(rank: number): { coins: number; seeds: number } {
  if (rank === 1) return { coins: 1000, seeds: 3 };
  if (rank === 2) return { coins: 800, seeds: 2 };
  if (rank === 3) return { coins: 600, seeds: 2 };
  if (rank <= 5) return { coins: 400, seeds: 1 };
  return { coins: 200, seeds: 1 };
}

// ─────────────────────────────────────────────────────────────────────────────
// 4. Scheduled: clean up old waterGifts (runs daily)
// ─────────────────────────────────────────────────────────────────────────────

export const cleanupWaterGifts = functions.pubsub
  .schedule("every 24 hours")
  .onRun(async () => {
    const cutoff = new Date();
    cutoff.setDate(cutoff.getDate() - 3); // older than 3 days

    const snap = await db
      .collection("waterGifts")
      .where("applied", "==", true)
      .where("createdAt", "<", cutoff)
      .limit(300)
      .get();

    const batch = db.batch();
    snap.docs.forEach((d) => batch.delete(d.ref));
    await batch.commit();

    functions.logger.info(`Cleaned up ${snap.size} old waterGifts`);
  });

// ─────────────────────────────────────────────────────────────────────────────
// 5. Scheduled: clean up old friendRequests (accepted/rejected, > 30 days)
// ─────────────────────────────────────────────────────────────────────────────

export const cleanupFriendRequests = functions.pubsub
  .schedule("every 72 hours")
  .onRun(async () => {
    const cutoff = new Date();
    cutoff.setDate(cutoff.getDate() - 30);

    const snap = await db
      .collection("friendRequests")
      .where("status", "in", ["accepted", "rejected"])
      .where("createdAt", "<", cutoff)
      .limit(300)
      .get();

    const batch = db.batch();
    snap.docs.forEach((d) => batch.delete(d.ref));
    await batch.commit();

    functions.logger.info(`Cleaned up ${snap.size} old friend requests`);
  });

// ─────────────────────────────────────────────────────────────────────────────
// 6. Firestore trigger: new friend accepted → unlock achievement for both
// ─────────────────────────────────────────────────────────────────────────────

export const onFriendRequestAccepted = functions.firestore
  .document("friendRequests/{reqId}")
  .onUpdate(async (change) => {
    const before = change.before.data();
    const after = change.after.data();
    if (before?.status === after?.status) return;
    if (after?.status !== "accepted") return;

    const fromUid = after.fromUid as string;
    const toUid = after.toUid as string;

    // Write achievement unlock marker for both users
    // (Flutter reads achievements from garden doc, so we just add a flag)
    await Promise.all([
      _markFriendAchievement(fromUid),
      _markFriendAchievement(toUid),
    ]);
  });

async function _markFriendAchievement(uid: string) {
  const ref = db.collection("gardens").doc(uid);
  await ref.set(
    {
      "achievements.first_friend": {
        unlocked: true,
        unlockedAt: Date.now(),
      },
      lastSaved: admin.firestore.FieldValue.serverTimestamp(),
    },
    { merge: true }
  );
}
