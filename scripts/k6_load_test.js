import http from 'k6/http';
import { check, sleep } from 'k6';

// ─── k6 Options for Baseline/Load Testing ────────────────────────────────────
export const options = {
  vus: 100,             // 100 virtual users (concurrent)
  duration: '1m',       // Run continuously for 1 minute
  thresholds: {
    // Alert thresholds:
    http_req_failed: ['rate<0.01'],    // less than 1% of requests should fail
    http_req_duration: ['p(95)<1500'],  // 95% of requests must complete under 1500ms
  },
};

// ─── Target Endpoint Configuration ──────────────────────────────────────────
// Default to the Local Firebase Functions emulator URL.
// Can be overridden via command line: k6 run -e TARGET_URL=https://your-live-url/ ...
const TARGET_URL = __ENV.TARGET_URL || 'http://localhost:5001/nutri-ai-scanner/us-central1/scanFood';

// A lightweight 1x1 blank JPEG base64 string to keep payload overhead small
const DUMMY_BASE64_IMAGE = '/9j/4AAQSkZJRgABAQEASABIAAD/2wBDAP//////////////////////////////////////////////////////////////////////////////////////wgALCAABAAEBAREA/8QAFBABAAAAAAAAAAAAAAAAAAAAAP/aAAgBAQABPxA=';

export default function () {
  const payload = JSON.stringify({
    base64Image: DUMMY_BASE64_IMAGE,
    mimeType: 'image/jpeg',
    riskProfile: {
      diabetes: 12,
      heart: 28,
      obesity: 8,
      bp: 15
    }
  });

  const params = {
    headers: {
      'Content-Type': 'application/json',
    },
  };

  // Perform the POST request
  const response = http.post(TARGET_URL, payload, params);

  // Validate the response
  check(response, {
    'status is 200': (r) => r.status === 200,
    'has JSON response': (r) => {
      try {
        const body = JSON.parse(r.body);
        return body.success === true || body.error !== undefined;
      } catch (e) {
        return false;
      }
    }
  });

  // Brief pause (100ms) between iterations for each Virtual User to pace request rate
  sleep(0.1);
}
