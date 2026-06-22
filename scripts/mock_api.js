const http = require('http');

const PORT = 5001;

const server = http.createServer((req, res) => {
  // CORS Headers
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'POST, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type, Authorization');

  if (req.method === 'OPTIONS') {
    res.writeHead(204);
    res.end();
    return;
  }

  // Expecting POST /scanFood or POST /nutri-ai-scanner/us-central1/scanFood
  if (req.method === 'POST') {
    let body = '';
    req.on('data', chunk => {
      body += chunk.toString();
    });

    req.on('end', () => {
      // Simulate real AI processing latency: 50ms to 300ms
      const delay = Math.floor(Math.random() * (300 - 50 + 1)) + 50;

      setTimeout(() => {
        res.writeHead(200, { 'Content-Type': 'application/json' });
        res.end(JSON.stringify({
          success: true,
          data: {
            id: 'mock_' + Date.now(),
            name: 'Pepperoni Pizza',
            emoji: '🍕',
            calories: 290,
            score: 45,
            serving: '1 slice (100g)',
            warnings: ['High Sodium', 'High Calorie'],
            macros: { carbs: 32, fat: 12, protein: 13 },
            nutrients: { sodium: 640, sugar: 3, fiber: 2, cholesterol: 22, vitaminA: 4, calcium: 100 },
            recommendation: 'High in saturated fat and sodium. Swap with a whole grain base or load with veggie toppings.',
            timestamp: new Date().toISOString()
          }
        }));
      }, delay);
    });
  } else {
    res.writeHead(404, { 'Content-Type': 'text/plain' });
    res.end('Not Found');
  }
});

server.listen(PORT, () => {
  console.log(`🚀 Mock API Server running at http://localhost:${PORT}`);
  console.log(`👉 Target URL for load test: http://localhost:${PORT}/scanFood`);
});
