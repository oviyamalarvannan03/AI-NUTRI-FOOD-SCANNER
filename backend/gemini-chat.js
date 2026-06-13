/* =============================================
   NUTRIAI – AI ENGINE (Gemini 2.0 Flash via Google AI API)
   Food scanning + chat powered by Google Gemini AI.
   Works on ANY device — no local server needed.
   ============================================= */

import { GEMINI_API_KEY } from './firebase-config.js';

// ─── Model Configuration ─────────────────────────────────────────────────────
// gemini-2.0-flash: vision-capable, available on ALL Google AI Studio keys,
// fast and reliable for food scanning and health chat.
const SCAN_MODEL  = 'gemini-2.0-flash';
const CHAT_MODEL  = 'gemini-2.0-flash';
const API_BASE    = 'https://generativelanguage.googleapis.com/v1beta/models';

export function getGeminiApiKey() {
  const localKey = localStorage.getItem('GEMINI_API_KEY');
  if (localKey && localKey.trim() !== '' && localKey !== 'YOUR_GEMINI_API_KEY') {
    return localKey.trim();
  }
  return GEMINI_API_KEY;
}

function getScanUrl() { return `${API_BASE}/${SCAN_MODEL}:generateContent?key=${getGeminiApiKey()}`; }
function getChatUrl() { return `${API_BASE}/${CHAT_MODEL}:generateContent?key=${getGeminiApiKey()}`; }

function cleanJsonString(str) {
  let cleaned = str.trim();
  // Strip markdown code fences
  if (cleaned.includes('```')) {
    cleaned = cleaned.replace(/```(?:json)?\s*/gi, '').replace(/```/g, '').trim();
  }
  // Extract the first complete JSON object (Gemini may add preamble text)
  const start = cleaned.indexOf('{');
  const end   = cleaned.lastIndexOf('}');
  if (start !== -1 && end !== -1 && end > start) {
    cleaned = cleaned.substring(start, end + 1);
  }
  return cleaned.trim();
}

// Conversation history for multi-turn chat
let conversationHistory = [];

// ─── Build Health Context System Prompt ────────
function buildSystemPrompt(userProfile, todayStats, riskData) {
  const profile = userProfile || {};
  const stats   = todayStats  || {};
  const risks   = riskData    || {};

  return `You are NutriAI, an expert AI health assistant and nutritionist. You are friendly, concise, and science-backed.

USER HEALTH PROFILE:
- Name: ${profile.name || 'User'}
- Age: ${profile.age || 'unknown'}
- Gender: ${profile.gender || 'unknown'}
- Daily Calorie Goal: ${profile.dailyCalorieGoal || 2000} kcal

TODAY'S STATS:
- Calories consumed: ${stats.calories || 0} kcal
- Water intake: ${stats.water || 0} L
- Steps: ${stats.steps || 0}
- Food items scanned: ${stats.scansCount || 0}

DISEASE RISK PROFILE:
- Diabetes risk: ${risks.diabetes || 'unknown'}%
- Heart disease risk: ${risks.heart || 'unknown'}%
- Obesity risk: ${risks.obesity || 'unknown'}%
- Blood pressure risk: ${risks.bp || 'unknown'}%

INSTRUCTIONS:
- Give personalized advice based on the user's actual data above.
- Keep responses concise (under 200 words) but rich in actionable advice.
- Use emojis sparingly for readability.
- When relevant, mention specific numbers from their profile.
- Always be encouraging and positive.
- If asked about food, provide specific nutrition facts.
- Format lists with bullet points using •.
- Do NOT use markdown headers (#) — use plain text only.`;
}

// ─── Send Message to Gemini ────────────────────
export async function sendToGemini(userMessage) {
  const profile = window._nutriProfile || {};
  const stats   = window._nutriDailyStats || {};
  const risks   = window._nutriRiskData || {};

  // Add user message to history
  conversationHistory.push({
    role: 'user',
    parts: [{ text: userMessage }]
  });

  // Keep history to last 10 exchanges (20 messages) to avoid token limits
  if (conversationHistory.length > 20) {
    conversationHistory = conversationHistory.slice(-20);
  }

  // Gemini chat: prepend system context as first conversation turn
  const systemTurn = [
    { role: 'user',  parts: [{ text: `[SYSTEM] ${buildSystemPrompt(profile, stats, risks)}` }] },
    { role: 'model', parts: [{ text: 'Understood. I am NutriAI, your personal AI nutritionist.' }] },
    ...conversationHistory
  ];

  const requestBody = {
    contents: systemTurn,
    generationConfig: {
      temperature:     0.7,
      maxOutputTokens: 400,
      topP:            0.9,
    }
  };

  try {
    const response = await fetch(getChatUrl(), {
      method:  'POST',
      headers: { 'Content-Type': 'application/json' },
      body:    JSON.stringify(requestBody)
    });

    if (!response.ok) {
      const errData = await response.json();
      throw new Error(errData?.error?.message || `HTTP ${response.status}`);
    }

    const data = await response.json();
    const aiText = data?.candidates?.[0]?.content?.parts?.[0]?.text;

    if (!aiText) throw new Error('Empty response from Gemini');

    // Add AI response to history
    conversationHistory.push({
      role: 'model',
      parts: [{ text: aiText }]
    });

    return aiText;

  } catch (err) {
    console.error('Gemini API error:', err);

    // Fallback to local responses if API fails
    const activeKey = getGeminiApiKey();
    if (activeKey === 'YOUR_GEMINI_API_KEY' || !activeKey) {
      return getFallbackResponse(userMessage);
    }

    return `⚠️ I'm having trouble connecting right now. Please check your internet connection and try again.\n\nError: ${err.message}`;
  }
}

// ─── Fallback responses (when no API key) ──────
function getFallbackResponse(message) {
  const msg = message.toLowerCase();

  if (msg.includes('diabet'))
    return '🩸 For diabetes risk reduction:\n• Limit refined carbs and sugary drinks\n• Eat more fiber (vegetables, legumes)\n• Exercise at least 30 min daily\n• Monitor your carb intake with each meal\n• Aim for a healthy BMI\n\nAdd your Gemini API key in firebase-config.js for personalized AI advice!';

  if (msg.includes('heart') || msg.includes('cholesterol'))
    return '❤️ Heart health tips:\n• Reduce sodium intake (aim under 2300mg/day)\n• Eat omega-3 rich foods (salmon, walnuts, flaxseeds)\n• Avoid trans fats and processed foods\n• Exercise 150 min/week\n• Quit smoking if applicable\n\nAdd your Gemini API key for personalized advice!';

  if (msg.includes('weight') || msg.includes('calori'))
    return '⚖️ For healthy weight management:\n• Track all meals with the NutriAI scanner\n• Aim for a 300-500 kcal daily deficit for weight loss\n• Prioritize protein (keeps you full longer)\n• Drink 2-3L water daily\n• Get 7-8 hours of sleep\n\nConnect Gemini API for real AI-powered recommendations!';

  if (msg.includes('water') || msg.includes('hydrat'))
    return '💧 Hydration guide:\n• Daily target: 2.5-3L for most adults\n• Drink a glass first thing in the morning\n• Eat water-rich foods (cucumber, watermelon)\n• Urine should be light yellow — if dark, drink more!\n• Add the NutriAI water tracker to log intake';

  return '🤖 I\'m NutriAI, your personal health assistant!\n\nI can help you with:\n• Food nutrition and meal planning\n• Disease risk reduction strategies\n• Personalized diet recommendations\n• Exercise and lifestyle advice\n• Understanding your health scores\n\n💡 Tip: Add a Gemini API key in firebase-config.js to unlock real AI-powered responses personalized to your health profile!';
}

// ─── Clear Chat History ─────────────────────────
export function clearChatHistory() {
  conversationHistory = [];
}

function getFoodEmoji(name) {
  const n = name.toLowerCase();
  if (n.includes('banana')) return '🍌';
  if (n.includes('pizza')) return '🍕';
  if (n.includes('burger')) return '🍔';
  if (n.includes('apple')) return '🍎';
  if (n.includes('salad')) return '🥗';
  return '🍽️';
}

// ─── Analyze Food Image with Gemini 2.0 Flash Vision ───────────────────────
// Works on ANY device — no local server or Ollama needed.
export async function analyzeFoodImage(imageBase64, mimeType) {
  const activeKey = getGeminiApiKey();
  if (!activeKey || activeKey === 'YOUR_GEMINI_API_KEY') {
    return 'Please add your Google AI API key in Settings to use the AI food scanner.';
  }

  // Strip the data URI prefix if present (e.g. data:image/jpeg;base64,)
  let base64Data = imageBase64;
  if (base64Data.includes(',')) {
    base64Data = base64Data.split(',')[1];
  }

  const profile = window._nutriProfile  || {};
  const risks   = window._nutriRiskData || {};

  const systemPrompt = `You are NutriAI, an expert visual food scanner powered by Google Gemini AI. Analyze the food image provided.
Return ONLY a valid JSON object with these exact fields:
{
  "name": "Name of the food dish",
  "emoji": "single emoji like \ud83e\udd57 or \ud83c\udf55",
  "calories": 320,
  "score": 85,
  "serving": "1 plate",
  "warnings": ["High Sodium"],
  "macros": { "carbs": 35, "fat": 12, "protein": 18 },
  "nutrients": { "sodium": 340, "sugar": 8, "fiber": 4, "cholesterol": 15, "vitaminA": 20, "calcium": 150 },
  "recommendation": "Personalized advice considering diabetes risk ${risks.diabetes || 0}%, heart risk ${risks.heart || 0}%, obesity risk ${risks.obesity || 0}%."
}`;

  const requestBody = {
    contents: [
      {
        parts: [
          { inlineData: { mimeType: mimeType || 'image/jpeg', data: base64Data } },
          { text: systemPrompt }
        ]
      }
    ],
    generationConfig: {
      temperature: 0.2,
      maxOutputTokens: 1024,
      responseMimeType: 'application/json'
    }
  };

  try {
    console.log(`🤖 Gemini 2.0 Flash Vision analyzing food image...`);
    const response = await fetch(getScanUrl(), {
      method:  'POST',
      headers: { 'Content-Type': 'application/json' },
      body:    JSON.stringify(requestBody)
    });

    if (!response.ok) {
      const errData = await response.json().catch(() => ({}));
      const msg = errData?.error?.message || `HTTP ${response.status}`;
      throw new Error(`Gemini API error: ${msg}`);
    }

    const data = await response.json();
    const candidates = data?.candidates || [];
    if (!candidates.length) throw new Error('No candidates returned — image may be blocked by safety filters.');
    if (candidates[0]?.finishReason === 'SAFETY') throw new Error('Image blocked by safety filters. Try a clearer food photo.');

    const aiText = candidates[0]?.content?.parts?.[0]?.text;
    if (!aiText || !aiText.trim()) throw new Error('Empty response from Gemini. Please try again.');

    console.log('✅ Gemini raw response:', aiText);
    return processGeminiResult(aiText);

  } catch (err) {
    console.error('❌ Food scan failed:', err.message || err);
    return `AI scan failed: ${err.message || 'Unknown error'}. Please check your API key in Settings.`;
  }
}

function processGeminiResult(aiText) {
  let foodJson;
  try {
    foodJson = JSON.parse(cleanJsonString(aiText));
  } catch (parseErr) {
    console.error('❌ JSON parse failed. Raw AI text:', aiText);
    throw new Error('Could not parse AI response as JSON. Please try again.');
  }

  // Ensure all required fields exist with safe defaults
  return {
    name:           foodJson.name           || 'Unknown Food',
    food_name:      foodJson.name           || 'Unknown Food',
    emoji:          foodJson.emoji          || getFoodEmoji(foodJson.name || ''),
    calories:       Number(foodJson.calories)  || 0,
    score:          Number(foodJson.score)     || 75,
    serving:        foodJson.serving        || '1 serving',
    warnings:       foodJson.warnings       || [],
    macros:         foodJson.macros         || { carbs: 0, fat: 0, protein: 0 },
    nutrients:      foodJson.nutrients      || { sodium: 0, sugar: 0, fiber: 0, cholesterol: 0, vitaminA: 0, calcium: 0 },
    recommendation: foodJson.recommendation || '',
    confidence:     `${foodJson.score || 75}%`,
    ingredients:    [foodJson.name || 'Unknown']
  };
}

// ─── Generate Desi Swap Suggestion ───
export async function generateDesiSwapSuggestion(junkFood) {
  const systemPrompt = `You are a traditional Indian health advisor. Generate a healthy traditional Indian superfood swap for: "${junkFood}".

CRITICAL: Output ONLY a raw JSON object. Start with { and end with }. No markdown, no code fences, no explanation.

Required JSON structure:
{
  "junkName": "${junkFood}",
  "junkEmoji": "🍩",
  "junkKcal": 420,
  "junkTag": "High Sugar",
  "healthyName": "Traditional Indian alternative name",
  "healthyEmoji": "🥣",
  "healthyKcal": 150,
  "healthyTag": "Rich Fiber",
  "savesKcal": 270,
  "xp": 40,
  "deltas": {
    "calories": "-64%",
    "sugar": "-90%",
    "protein": "+150%",
    "fiber": "+250%"
  },
  "insight": "One compelling scientific reason why this traditional swap is healthier."
}

Return only the JSON above with real values for the food: ${junkFood}`;

  const requestBody = {
    contents: [
      { parts: [{ text: systemPrompt }] }
    ],
    generationConfig: {
      temperature: 0.5,
      maxOutputTokens: 500
    }
  };

  try {
    // Use Gemini text model for desi swap generation
    const response = await fetch(getChatUrl(), {
      method:  'POST',
      headers: { 'Content-Type': 'application/json' },
      body:    JSON.stringify(requestBody)
    });

    if (!response.ok) {
      const errData = await response.json().catch(() => ({}));
      throw new Error(errData?.error?.message || `HTTP ${response.status}`);
    }

    const data = await response.json();
    const candidates = data?.candidates || [];
    if (!candidates.length) throw new Error('No response from Gemini.');

    const aiText = candidates[0]?.content?.parts?.[0]?.text;
    if (!aiText) throw new Error('Empty response from Gemini');

    return JSON.parse(cleanJsonString(aiText));
  } catch (err) {
    console.error('Failed to generate Desi Swap suggestion:', err);
    throw err;
  }
}
