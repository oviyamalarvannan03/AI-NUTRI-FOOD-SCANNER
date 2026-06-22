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
  serverTimestamp,
  onSnapshot,
  where
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
    // Generate a unique scan ID
    const scansCollectionRef = collection(db, 'food_scans');
    const docRef = await addDoc(scansCollectionRef, {
      userId: uid,
      foodName: scanData.food,
      calories: scanData.calories || 0,
      protein: scanData.macros?.protein || 0,
      carbohydrates: scanData.macros?.carbs || 0,
      fat: scanData.macros?.fat || 0,
      fiber: scanData.nutrients?.fiber || 0,
      sugar: scanData.nutrients?.sugar || 0,
      sodium: scanData.nutrients?.sodium || 0,
      confidence: scanData.healthScore ? `${scanData.healthScore}%` : '75%',
      imageUrl: scanData.imageUrl || '',
      scanDate: serverTimestamp()
    });

    // Update daily nutrition statistics in daily_nutrition collection
    const todayStr = new Date().toISOString().slice(0, 10);
    const dailyDocRef = doc(db, 'daily_nutrition', `${uid}_${todayStr}`);
    
    const dailySnap = await getDoc(dailyDocRef);
    const existingStats = dailySnap.exists() ? dailySnap.data() : {
      userId: uid,
      date: todayStr,
      totalCalories: 0,
      totalProtein: 0,
      totalCarbs: 0,
      totalFat: 0
    };

    await setDoc(dailyDocRef, {
      userId: uid,
      date: todayStr,
      totalCalories: (existingStats.totalCalories || 0) + (scanData.calories || 0),
      totalProtein: (existingStats.totalProtein || 0) + (scanData.macros?.protein || 0),
      totalCarbs: (existingStats.totalCarbs || 0) + (scanData.macros?.carbs || 0),
      totalFat: (existingStats.totalFat || 0) + (scanData.macros?.fat || 0)
    }, { merge: true });

    // Backward compatibility updates for dailyStats structure
    await updateDailyStats(uid, {
      caloriesAdded: scanData.calories || 0
    });

    showToast('💾 Scan saved to Firebase!', 'success');
    return docRef.id;
  } catch (err) {
    console.error('saveFoodScan error:', err);
    throw err;
  }
}

export async function getRecentScans(uid, limitCount = 10) {
  try {
    const scansRef = collection(db, 'food_scans');
    const q = query(
      scansRef, 
      where('userId', '==', uid), 
      orderBy('scanDate', 'desc'), 
      limit(limitCount)
    );
    const snapshot = await getDocs(q);

    // Map fields backwards so the app logic consumes properties without breaking
    return snapshot.docs.map(d => {
      const data = d.data();
      return {
        id: d.id,
        food: data.foodName,
        calories: data.calories,
        healthScore: data.confidence ? parseInt(data.confidence) : 75,
        imageUrl: data.imageUrl,
        timestamp: data.scanDate,
        macros: {
          carbs: data.carbohydrates,
          fat: data.fat,
          protein: data.protein
        },
        nutrients: {
          sodium: data.sodium,
          sugar: data.sugar,
          fiber: data.fiber
        }
      };
    });
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

// ─── Real-Time Subscriptions ──────────────────

export function subscribeToDailyStats(uid, callback) {
  const todayKey = getTodayKey();
  const statsRef = doc(db, 'dailyStats', uid, 'days', todayKey);
  return onSnapshot(statsRef, (docSnap) => {
    if (docSnap.exists()) {
      callback(docSnap.data());
    } else {
      callback({ calories: 0, water: 0, steps: 0, scansCount: 0 });
    }
  }, (err) => {
    console.error("subscribeToDailyStats error:", err);
  });
}

export function subscribeToRecentScans(uid, limitCount = 5, callback) {
  const scansRef = collection(db, 'food_scans');
  const q = query(
    scansRef,
    where('userId', '==', uid),
    orderBy('scanDate', 'desc'),
    limit(limitCount)
  );
  return onSnapshot(q, (snapshot) => {
    const scans = snapshot.docs.map(d => {
      const data = d.data();
      return {
        id: d.id,
        food: data.foodName,
        calories: data.calories,
        healthScore: data.confidence ? parseInt(data.confidence) : 75,
        imageUrl: data.imageUrl,
        timestamp: data.scanDate,
        macros: {
          carbs: data.carbohydrates,
          fat: data.fat,
          protein: data.protein
        },
        nutrients: {
          sodium: data.sodium,
          sugar: data.sugar,
          fiber: data.fiber
        }
      };
    });
    callback(scans);
  }, (err) => {
    console.error("subscribeToRecentScans error:", err);
  });
}
