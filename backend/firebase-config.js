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
  apiKey: "AIzaSyBGXYH3Sc0AH1HjW-t5MxOMnsa3I1S8iOQ",
  authDomain: "nutri-ai-scanner.firebaseapp.com",
  projectId: "nutri-ai-scanner",
  storageBucket: "nutri-ai-scanner.firebasestorage.app",
  messagingSenderId: "602975199072",
  appId: "1:602975199072:web:a0ea09761d39efcdaa0805",
  measurementId: "G-Z8LLQT27NX"
};

// ⚠️ REPLACE WITH YOUR GEMINI API KEY:
const GEMINI_API_KEY = "YOUR_GEMINI_API_KEY";

// ─── Initialize Firebase ───────────────────────
import { initializeApp }              from 'https://www.gstatic.com/firebasejs/10.12.0/firebase-app.js';
import { getAuth }                    from 'https://www.gstatic.com/firebasejs/10.12.0/firebase-auth.js';
import { getFirestore }               from 'https://www.gstatic.com/firebasejs/10.12.0/firebase-firestore.js';

const firebaseApp = initializeApp(firebaseConfig);
const auth        = getAuth(firebaseApp);
const db          = getFirestore(firebaseApp);

export { auth, db, GEMINI_API_KEY };
