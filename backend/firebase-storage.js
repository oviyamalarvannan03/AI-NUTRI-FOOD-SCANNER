import {
  ref,
  uploadString,
  getDownloadURL
} from 'https://www.gstatic.com/firebasejs/10.12.0/firebase-storage.js';

import { storage } from './firebase-config.js';

/**
 * Uploads a base64 encoded image string to Firebase Storage
 * and returns the public download URL.
 * 
 * @param {string} uid User ID
 * @param {string} base64Str Base64 image data (without data:image/... prefix)
 * @param {string} mimeType File format mimetype (e.g. image/jpeg)
 * @returns {Promise<string>} Download URL link
 */
export async function uploadFoodImage(uid, base64Str, mimeType = 'image/jpeg') {
  try {
    const filename = `scans/${uid}/${Date.now()}.jpg`;
    const storageRef = ref(storage, filename);
    
    // Upload string directly as base64
    const metadata = {
      contentType: mimeType
    };
    
    await uploadString(storageRef, base64Str, 'base64', metadata);
    const downloadURL = await getDownloadURL(storageRef);
    return downloadURL;
  } catch (err) {
    console.error('Upload food image to storage error:', err);
    throw err;
  }
}
