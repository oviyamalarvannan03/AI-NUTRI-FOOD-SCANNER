/* =============================================
   NUTRIAI – FIREBASE CONFIGURATION
   =============================================
   
   HOW TO GET YOUR FIREBASE CONFIG:
   ─────────────────────────────────
   1. Go to https://console.firebase.google.com
   2. Click "Add project" → name it "NutriAI" → Continue
   3. Disable Google Analytics (optional) → Create project
   4. Once created, click the </> (Web) icon to add a web app
   5. Register app with name "NutriAI Web" → click Register App
   6. Copy the firebaseConfig object shown below and paste it here
   7. Click "Continue to console"
   
   ENABLE SERVICES (in Firebase Console):
   ─────────────────────────────────────
   • Authentication → Sign-in method → Enable: Email/Password + Google
   • Firestore Database → Create database → Start in test mode → Choose a region
   
   GEMINI API KEY:
   ──────────────
   1. Go to https://aistudio.google.com/app/apikey
   2. Click "Create API key" → Copy it
   3. Paste it in GEMINI_API_KEY below
   
   ============================================= */

// ⚠️ REAL FIREBASE CONFIG:
const firebaseConfig = {
  apiKey: "AIzaSyB2NMiF9-a3GSt0X2qIO1SuTr0uIPF2iZo",
  authDomain: "nutri-ai-scanner-bc363.firebaseapp.com",
  projectId: "nutri-ai-scanner-bc363",
  storageBucket: "nutri-ai-scanner-bc363.firebasestorage.app",
  messagingSenderId: "875349047347",
  appId: "1:875349047347:web:1a951edb4b123a3b574b46"
};

// ⚠️ REPLACE WITH YOUR GEMINI API KEY:
const GEMINI_API_KEY = "YOUR_GEMINI_API_KEY";

// ─── Initialize Firebase ───────────────────────
import { initializeApp }              from 'https://www.gstatic.com/firebasejs/10.12.0/firebase-app.js';
import { getAuth }                    from 'https://www.gstatic.com/firebasejs/10.12.0/firebase-auth.js';
import { getFirestore }               from 'https://www.gstatic.com/firebasejs/10.12.0/firebase-firestore.js';
import { getStorage }                 from 'https://www.gstatic.com/firebasejs/10.12.0/firebase-storage.js';

const firebaseApp = initializeApp(firebaseConfig);
const auth        = getAuth(firebaseApp);
const db          = getFirestore(firebaseApp);
const storage     = getStorage(firebaseApp);

export { auth, db, storage, GEMINI_API_KEY };
