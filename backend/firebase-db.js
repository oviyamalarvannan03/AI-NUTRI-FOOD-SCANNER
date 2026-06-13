/* =============================================
   NUTRIAI – FIRESTORE DATABASE LAYER
   Handles: User profiles, Food scans,
            Disease risk, Daily stats
   ============================================= */

import {
  doc,
  setDoc,
  getDoc,
  addDoc,
  collection,
  query,
  orderBy,
  limit,
  getDocs,
  updateDoc,
  serverTimestamp
} from 'https://www.gstatic.com/firebasejs/10.12.0/firebase-firestore.js';

import { db } from './firebase-config.js';

// ─── User Profile ──────────────────────────────

export async function saveUserProfile(uid, profileData) {
  try {
    await setDoc(doc(db, 'users', uid), profileData, { merge: true });
  } catch (err) {
    console.error('saveUserProfile error:', err);
  }
}

export async function getUserProfile(uid) {
  try {
    const snap = await getDoc(doc(db, 'users', uid));
    return snap.exists() ? snap.data() : null;
  } catch (err) {
    console.error('getUserProfile error:', err);
    return null;
  }
}

export async function updateUserProfile(uid, updates) {
  try {
    await updateDoc(doc(db, 'users', uid), {
      ...updates,
      updatedAt: serverTimestamp()
    });
    showToast('✅ Profile updated!', 'success');
  } catch (err) {
    console.error('updateUserProfile error:', err);
    showToast('❌ Failed to update profile', 'error');
  }
}

// ─── Food Scans ────────────────────────────────

export async function saveFoodScan(uid, scanData) {
  try {
    const scansRef = collection(db, 'scans', uid, 'history');
    const docRef = await addDoc(scansRef, {
      ...scanData,
      timestamp: serverTimestamp()
    });

    // Update daily calories in user's today document
    await updateDailyStats(uid, {
      caloriesAdded: scanData.calories || 0
    });

    showToast('💾 Scan saved to your history!', 'success');
    return docRef.id;
  } catch (err) {
    console.error('saveFoodScan error:', err);
  }
}

export async function getRecentScans(uid, limitCount = 10) {
  try {
    const scansRef = collection(db, 'scans', uid, 'history');
    const q = query(scansRef, orderBy('timestamp', 'desc'), limit(limitCount));
    const snapshot = await getDocs(q);

    return snapshot.docs.map(d => ({ id: d.id, ...d.data() }));
  } catch (err) {
    console.error('getRecentScans error:', err);
    return [];
  }
}

// ─── Disease Risk Data ─────────────────────────

export async function saveRiskData(uid, riskData) {
  try {
    await setDoc(doc(db, 'risks', uid), {
      diabetes:  riskData.diabetes  ?? 0,
      heart:     riskData.heart     ?? 0,
      obesity:   riskData.obesity   ?? 0,
      bp:        riskData.bp        ?? 0,
      overall:   riskData.overall   ?? 0,
      updatedAt: serverTimestamp()
    });
  } catch (err) {
    console.error('saveRiskData error:', err);
  }
}

export async function getRiskData(uid) {
  try {
    const snap = await getDoc(doc(db, 'risks', uid));
    return snap.exists() ? snap.data() : null;
  } catch (err) {
    console.error('getRiskData error:', err);
    return null;
  }
}

// ─── Daily Stats ───────────────────────────────

function getTodayKey() {
  return new Date().toISOString().slice(0, 10); // "2026-06-01"
}

export async function updateDailyStats(uid, updates) {
  const todayKey = getTodayKey();
  const statsRef = doc(db, 'dailyStats', uid, 'days', todayKey);

  try {
    const snap = await getDoc(statsRef);
    const existing = snap.exists() ? snap.data() : {
      calories: 0,
      water: 0,
      steps: 0,
      scansCount: 0
    };

    await setDoc(statsRef, {
      calories:    (existing.calories   || 0) + (updates.caloriesAdded || 0),
      water:       updates.water        !== undefined ? updates.water       : (existing.water    || 0),
      steps:       updates.steps        !== undefined ? updates.steps       : (existing.steps    || 0),
      scansCount:  (existing.scansCount || 0) + (updates.caloriesAdded ? 1 : 0),
      updatedAt:   serverTimestamp()
    });
  } catch (err) {
    console.error('updateDailyStats error:', err);
  }
}

export async function getDailyStats(uid) {
  const todayKey = getTodayKey();
  try {
    const snap = await getDoc(doc(db, 'dailyStats', uid, 'days', todayKey));
    return snap.exists() ? snap.data() : {
      calories: 0, water: 0, steps: 0, scansCount: 0
    };
  } catch (err) {
    console.error('getDailyStats error:', err);
    return { calories: 0, water: 0, steps: 0, scansCount: 0 };
  }
}

// ─── Weekly Stats (for analytics chart) ────────

export async function getWeeklyStats(uid) {
  const days = [];
  for (let i = 6; i >= 0; i--) {
    const d = new Date();
    d.setDate(d.getDate() - i);
    days.push(d.toISOString().slice(0, 10));
  }

  try {
    const results = await Promise.all(days.map(async (dayKey) => {
      const snap = await getDoc(doc(db, 'dailyStats', uid, 'days', dayKey));
      return {
        date: dayKey,
        ...(snap.exists() ? snap.data() : { calories: 0, water: 0, steps: 0 })
      };
    }));
    return results;
  } catch (err) {
    console.error('getWeeklyStats error:', err);
    return [];
  }
}
