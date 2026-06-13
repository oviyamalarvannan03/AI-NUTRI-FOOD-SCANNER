/* =============================================
   NUTRIAI – FIREBASE AUTHENTICATION
   Handles: Login, Signup, Google Sign-In,
            Logout, Auth State, OTP/Email verify
   ============================================= */

import {
  signInWithEmailAndPassword,
  createUserWithEmailAndPassword,
  signInWithPopup,
  GoogleAuthProvider,
  sendEmailVerification,
  signOut,
  onAuthStateChanged,
  updateProfile,
  sendPasswordResetEmail
} from 'https://www.gstatic.com/firebasejs/10.12.0/firebase-auth.js';

import { auth } from './firebase-config.js';
import { saveUserProfile, getUserProfile } from './firebase-db.js';

// ─── Auth State Observer ───────────────────────
// Fires on every page load; auto-navigates if already logged in
export function initAuthObserver() {
  onAuthStateChanged(auth, async (user) => {
    if (user) {
      // User is signed in
      window._nutriUser = user;
      const profile = await getUserProfile(user.uid);
      window._nutriProfile = profile;

      // Update UI with real user name
      const nameEl = document.querySelector('.greeting-name');
      const avatarEl = document.querySelector('.avatar');
      const displayName = profile?.name || user.displayName || user.email.split('@')[0] || 'User';
      if (nameEl) {
        nameEl.textContent = displayName;
      }
      if (avatarEl) {
        avatarEl.textContent = displayName.charAt(0).toUpperCase();
      }

      // Update User Profile Screen
      const profName = document.getElementById('profileName');
      const profEmail = document.getElementById('profileEmail');
      const profAvatar = document.getElementById('profileAvatarBig');
      const profAge = document.getElementById('profileAge');
      const profGender = document.getElementById('profileGender');

      if (profName) profName.textContent = displayName;
      if (profEmail && user?.email) profEmail.textContent = user.email;
      if (profAvatar) profAvatar.textContent = displayName.charAt(0).toUpperCase();
      if (profAge && profile?.age) profAge.textContent = profile.age;
      if (profGender && profile?.gender) profGender.textContent = profile.gender;

      // If on login/signup screen, redirect to home
      const authScreens = ['screen-splash', 'screen-login', 'screen-signup', 'screen-otp', 'screen-onboarding'];
      if (authScreens.includes(window.currentScreen)) {
        setTimeout(() => navigateTo('screen-home'), 300);
      }
    } else {
      // Not logged in
      window._nutriUser = null;
      window._nutriProfile = null;
    }
  });
}

// ─── Email / Password Login ────────────────────
export async function loginWithEmail(email, password) {
  if (!email || !password) {
    showToast('⚠️ Please enter email and password', 'error');
    return;
  }

  const btn = document.getElementById('loginBtn');
  if (btn) { btn.textContent = 'Signing in...'; btn.disabled = true; }

  try {
    const cred = await signInWithEmailAndPassword(auth, email, password);
    showToast('✅ Welcome back!', 'success');
    navigateTo('screen-home');
  } catch (err) {
    showToast(`❌ ${getFriendlyAuthError(err.code)}`, 'error');
  } finally {
    if (btn) { btn.textContent = 'Sign In'; btn.disabled = false; }
  }
}

// ─── Email / Password Signup ───────────────────
export async function signupWithEmail(name, email, password, age, gender) {
  if (!name || !email || !password) {
    showToast('⚠️ Please fill all required fields', 'error');
    return;
  }
  if (password.length < 6) {
    showToast('⚠️ Password must be at least 6 characters', 'error');
    return;
  }

  const btn = document.querySelector('#screen-signup .btn-primary');
  if (btn) { btn.textContent = 'Creating account...'; btn.disabled = true; }

  try {
    const cred = await createUserWithEmailAndPassword(auth, email, password);
    const user = cred.user;

    // Update display name and save profile to Firestore in parallel to minimize latency
    await Promise.all([
      updateProfile(user, { displayName: name }),
      saveUserProfile(user.uid, {
        name,
        email,
        age: age || null,
        gender: gender || null,
        dailyCalorieGoal: 2000,
        createdAt: new Date().toISOString()
      })
    ]);

    // Send email verification asynchronously in the background
    sendEmailVerification(user).catch(err => {
      console.warn('Asynchronous email verification failed to send:', err);
    });

    showToast('✅ Account created! Check your email to verify.', 'success');
    navigateTo('screen-otp'); // Show OTP/verification screen

  } catch (err) {
    showToast(`❌ ${getFriendlyAuthError(err.code)}`, 'error');
  } finally {
    if (btn) { btn.textContent = 'Create Account →'; btn.disabled = false; }
  }
}

// ─── Google Sign-In ────────────────────────────
export async function loginWithGoogle() {
  const provider = new GoogleAuthProvider();
  provider.addScope('profile');
  provider.addScope('email');

  try {
    showToast('🔵 Opening Google Sign-In...', 'info');
    const result = await signInWithPopup(auth, provider);
    const user = result.user;

    // Create profile in Firestore if first time
    const existing = await getUserProfile(user.uid);
    if (!existing) {
      await saveUserProfile(user.uid, {
        name: user.displayName || 'NutriAI User',
        email: user.email,
        age: null,
        gender: null,
        dailyCalorieGoal: 2000,
        createdAt: new Date().toISOString()
      });
    }

    showToast(`✅ Welcome, ${user.displayName?.split(' ')[0]}!`, 'success');
    navigateTo('screen-home');
  } catch (err) {
    if (err.code !== 'auth/popup-closed-by-user') {
      showToast(`❌ ${getFriendlyAuthError(err.code)}`, 'error');
    }
  }
}

// ─── Logout ───────────────────────────────────
export async function logoutUser() {
  try {
    await signOut(auth);
    window._nutriUser = null;
    window._nutriProfile = null;
    showToast('👋 Signed out successfully', 'info');
    navigateTo('screen-login');
  } catch (err) {
    showToast('❌ Sign out failed. Try again.', 'error');
  }
}

// ─── Password Reset ────────────────────────────
export async function sendPasswordReset(email) {
  if (!email) {
    showToast('⚠️ Please enter your email address', 'error');
    return;
  }

  const btn = document.querySelector('#screen-forgot .btn-primary');
  if (btn) { btn.textContent = 'Sending...'; btn.disabled = true; }

  try {
    await sendPasswordResetEmail(auth, email);
    showToast('✉️ Password reset email sent!', 'success');
    navigateTo('screen-login');
  } catch (err) {
    showToast(`❌ ${getFriendlyAuthError(err.code)}`, 'error');
  } finally {
    if (btn) { btn.textContent = 'Send Reset Link'; btn.disabled = false; }
  }
}

// ─── Auth Error Messages ───────────────────────
function getFriendlyAuthError(code) {
  const messages = {
    'auth/user-not-found':       'No account found with this email.',
    'auth/wrong-password':       'Incorrect password. Please try again.',
    'auth/invalid-email':        'Please enter a valid email address.',
    'auth/email-already-in-use': 'An account with this email already exists.',
    'auth/weak-password':        'Password is too weak. Use at least 6 characters.',
    'auth/too-many-requests':    'Too many failed attempts. Please try again later.',
    'auth/network-request-failed': 'Network error. Check your internet connection.',
    'auth/invalid-credential':   'Invalid credentials. Please check email and password.',
  };
  return messages[code] || 'Authentication failed. Please try again.';
}
