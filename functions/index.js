/* ============================================================
   NutriAI — Firebase Cloud Function: scanFood
   ============================================================
   Endpoint: POST /scanFood
   Body: { base64Image: string, mimeType: string, riskProfile: object }

   The function calls Gemini 2.0 Flash Vision with the expert food
   recognition prompt and returns a structured FoodItem-compatible JSON.

   The Gemini API key is read from Firebase Secret Manager —
   never stored in code or sent to the client.

   Deploy: firebase deploy --only functions
   Set key: firebase functions:secrets:set GEMINI_API_KEY
   ============================================================ */

const { onRequest } = require('firebase-functions/v2/https');
const { defineSecret } = require('firebase-functions/params');
const { GoogleGenerativeAI } = require('@google/generative-ai');

// ── Secret (stored in Firebase Secret Manager, never in code) ───────────────
const geminiApiKey = defineSecret('GEMINI_API_KEY');

// ── CORS helper ─────────────────────────────────────────────────────────────
function setCorsHeaders(res) {
  res.set('Access-Control-Allow-Origin', '*');
  res.set('Access-Control-Allow-Methods', 'POST, OPTIONS');
  res.set('Access-Control-Allow-Headers', 'Content-Type, Authorization');
}

// ── Food scan prompt (same as mobile Ollama prompt) ──────────────────────────
function buildPrompt(riskProfile) {
  const r = riskProfile || {};
  return `Analyze the uploaded image as a food recognition expert.

Identify the exact name of the food visible in the image.

Rules:
- Never return mock or simulated data. You must analyze the image directly and output real database-verified nutritional values.
- Specifically identify food items accurately, including: samosa, cup cakes, donuts, french fries, ice cream, banana, apple, cashew, cherry, fig.
- Categorize the food item as healthy or junk food:
  - If it is a junk food (like samosa, donut, cup cake, french fries, ice cream, pizza, burger, chocolate, cake), append "🛑 Junk Food Detected" to the warnings.
  - If it is a healthy food (like banana, apple, cashew, cherry, fig, salad, yogurt, salmon, chicken), append "☘️ Healthy Food" to the warnings.
- If the image is unclear, set food_name to "Unable to identify confidently" and confidence to 0.
- If confidence is below 70, populate the "alternatives" array with the top 3 possible foods.
- If confidence is 70 or above, set alternatives to [].
- Verify the food name exists in real food databases (USDA, Open Food Facts). Set database_verified accordingly.
- All numeric fields must be plain numbers — no units, no strings, no % signs.
- Return only valid JSON. No markdown, no code fences, no backticks, no explanation.
- Start directly with { and end with }.

Return this exact JSON:
{
  "food_name": "Exact food name visible in image",
  "emoji": "single relevant emoji",
  "confidence": 92,
  "database_verified": true,
  "category": "e.g. Street Food / Salad / Beverage / Dessert / Fast Food / Fruit / Snack",
  "ingredients": ["ingredient 1", "ingredient 2", "ingredient 3"],
  "calories": 320,
  "protein": 18,
  "carbohydrates": 35,
  "fat": 12,
  "health_score": 85,
  "possible_diabetes_risk": "Moderate — contains 35g carbs and 8g sugar; monitor portion size",
  "serving": "1 plate (approx. 250g)",
  "warnings": ["High Sodium", "Balanced Meal"],
  "nutrients": {
    "sodium": 340,
    "sugar": 8,
    "fiber": 4,
    "cholesterol": 15,
    "vitaminA": 20,
    "calcium": 150
  },
  "alternatives": [
    { "name": "Possible Food 1", "emoji": "🍛", "confidence": 45, "calories": 280 },
    { "name": "Possible Food 2", "emoji": "🥘", "confidence": 30, "calories": 310 },
    { "name": "Possible Food 3", "emoji": "🍲", "confidence": 15, "calories": 250 }
  ],
  "recommendation": "Personalized advice: diabetes risk ${r.diabetes ?? 'unknown'}%, heart risk ${r.heart ?? 'unknown'}%, obesity risk ${r.obesity ?? 'unknown'}%."
}

Analyze the image now and return only the filled JSON.`;
}

// ── Normalize flat Gemini response → FoodItem schema ────────────────────────
function normalize(raw, riskProfile) {
  const r = riskProfile || {};
  const toInt = (v) => {
    if (v == null) return null;
    if (typeof v === 'number') return Math.round(v);
    if (typeof v === 'string') {
      const n = parseInt(v.replace(/[^0-9]/g, ''), 10);
      return isNaN(n) ? null : n;
    }
    return null;
  };

  const name = raw.food_name || raw.name || 'Unknown Food';
  const confidence = toInt(raw.confidence);
  const calories = toInt(raw.calories) ?? 0;

  // Parse alternatives (present only when confidence < 70)
  let alternatives = null;
  if (Array.isArray(raw.alternatives) && raw.alternatives.length > 0) {
    alternatives = raw.alternatives.map(a => ({
      name: a.name || 'Unknown',
      emoji: a.emoji || '🍽️',
      confidence: toInt(a.confidence) ?? 0,
      calories: toInt(a.calories) ?? 0,
    }));
  }

  return {
    name,
    emoji: raw.emoji || '🍽️',
    confidence,
    database_verified: raw.database_verified ?? null,
    category: raw.category || null,
    calories,
    score: toInt(raw.health_score ?? raw.score) ?? 70,
    serving: raw.serving || '1 serving',
    warnings: Array.isArray(raw.warnings) ? raw.warnings : [],
    macros: {
      carbs: toInt(raw.carbohydrates ?? raw.carbs) ?? 0,
      fat: toInt(raw.fat) ?? 0,
      protein: toInt(raw.protein) ?? 0,
    },
    nutrients: raw.nutrients || {},
    ingredients: Array.isArray(raw.ingredients) ? raw.ingredients : null,
    alternatives,
    possible_diabetes_risk: raw.possible_diabetes_risk || null,
    recommendation: raw.recommendation || 'Enjoy in moderation.',
  };
}

// ── Strip markdown fences and extract first JSON object ──────────────────────
function extractJson(text) {
  let t = text.trim();
  if (t.includes('```')) {
    t = t.replace(/```(?:json)?\s*/gi, '').replace(/```/g, '').trim();
  }
  const start = t.indexOf('{');
  const end = t.lastIndexOf('}');
  if (start !== -1 && end !== -1 && end > start) {
    t = t.substring(start, end + 1);
  }
  return t.trim();
}

// ── Main Cloud Function ──────────────────────────────────────────────────────
exports.scanFood = onRequest(
  { secrets: [geminiApiKey], cors: true, timeoutSeconds: 120, memory: '512MiB' },
  async (req, res) => {
    setCorsHeaders(res);

    // Handle CORS preflight
    if (req.method === 'OPTIONS') {
      res.status(204).send('');
      return;
    }

    if (req.method !== 'POST') {
      res.status(405).json({ error: 'Method not allowed. Use POST.' });
      return;
    }

    const { base64Image, mimeType, riskProfile } = req.body || {};

    if (!base64Image) {
      res.status(400).json({ error: 'Missing required field: base64Image' });
      return;
    }

    try {
      const apiKey = geminiApiKey.value();
      if (!apiKey || apiKey === 'YOUR_GEMINI_API_KEY') {
        res.status(500).json({ error: 'Gemini API key not configured. Run: firebase functions:secrets:set GEMINI_API_KEY' });
        return;
      }

      const genAI = new GoogleGenerativeAI(apiKey);
      const model = genAI.getGenerativeModel({ model: 'gemini-2.0-flash' });

      // Strip data-URI prefix if present
      let imageData = base64Image;
      if (imageData.includes(',')) {
        imageData = imageData.split(',')[1];
      }

      const prompt = buildPrompt(riskProfile || {});

      console.log(`[scanFood] Calling Gemini 2.0 Flash Vision...`);

      const result = await model.generateContent([
        { inlineData: { mimeType: mimeType || 'image/jpeg', data: imageData } },
        { text: prompt },
      ]);

      const aiText = result.response.text().trim();
      console.log(`[scanFood] Gemini response length: ${aiText.length} chars`);

      if (!aiText) {
        res.status(502).json({ error: 'Empty response from Gemini. Try again.' });
        return;
      }

      const rawJson = JSON.parse(extractJson(aiText));
      const foodItem = normalize(rawJson, riskProfile || {});

      res.status(200).json({ success: true, data: foodItem });

    } catch (err) {
      console.error('[scanFood] Error:', err.message || err);
      res.status(500).json({ error: `AI scan failed: ${err.message || 'Unknown error'}` });
    }
  }
);
