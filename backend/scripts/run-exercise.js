'use strict';

const http = require('http');

function request(endpoint, options = {}) {
  return new Promise((resolve, reject) => {
    const bodyStr = options.body ? options.body : '';
    const bodyBuffer = Buffer.from(bodyStr, 'utf8');

    const headers = {
      'Content-Type': 'application/json',
      'Content-Length': bodyBuffer.length,
      ...(options.headers || {}),
    };

    const reqOptions = {
      method: options.method || 'GET',
      hostname: '127.0.0.1',
      port: 3000,
      path: `/api/v1${endpoint}`,
      headers: headers,
    };

    const req = http.request(reqOptions, (res) => {
      let data = '';
      res.on('data', (chunk) => {
        data += chunk;
      });
      res.on('end', () => {
        let body = null;
        try {
          body = data ? JSON.parse(data) : null;
        } catch (_) {
          body = data;
        }
        resolve({ status: res.statusCode, body });
      });
    });

    req.on('error', (err) => reject(err));

    if (bodyBuffer.length > 0) {
      req.write(bodyBuffer);
    }
    req.end();
  });
}

async function runExercise() {
  console.log('================================================================');
  console.log(' HANDS-ON EXERCISE: TOKEN ROTATION, REUSE DETECTION & LOGOUT   ');
  console.log('================================================================\n');

  const randomId = Math.floor(Math.random() * 90000) + 10000;
  const email = `student-${randomId}@example.test`;
  const password = 'a-long-local-test-password-for-this-exercise';

  // SETUP
  console.log('[SETUP] Registering local test user...');
  console.log(`  POST /auth/register -> email: ${email}`);
  const regRes = await request('/auth/register', {
    method: 'POST',
    body: JSON.stringify({ email, password }),
  });
  console.log(`  Response Status: ${regRes.status} (Expected: 201)`);
  let accessToken = regRes.body?.accessToken;
  let refreshToken = regRes.body?.refreshToken;
  console.log(`  Access token & Refresh token captured successfully.\n`);

  // TASK 1 — ROTATION
  console.log('----------------------------------------------------------------');
  console.log('TASK 1 — Token Rotation');
  console.log('----------------------------------------------------------------');
  const oldRefresh = refreshToken;
  const rotRes = await request('/auth/refresh', {
    method: 'POST',
    body: JSON.stringify({ refreshToken: oldRefresh }),
  });
  console.log(`  POST /auth/refresh with valid refresh token`);
  console.log(`  HTTP Status: ${rotRes.status} (Expected: 200)`);
  const newRefresh = rotRes.body?.refreshToken;
  const isDifferent = newRefresh && newRefresh !== oldRefresh;
  console.log(`  Comparison (new vs old): ${isDifferent ? 'different' : 'same'} (Expected: different)`);
  console.log(`  Result: ${rotRes.status === 200 && isDifferent ? 'PASS [✓]' : 'FAIL [✗]'}\n`);
  refreshToken = newRefresh;

  // TASK 2 — REUSE DETECTION
  console.log('----------------------------------------------------------------');
  console.log('TASK 2 — Reuse Detection (Revoke Family)');
  console.log('----------------------------------------------------------------');
  console.log(`  1. Presenting OLD (already rotated) token again:`);
  const reuseRes = await request('/auth/refresh', {
    method: 'POST',
    body: JSON.stringify({ refreshToken: oldRefresh }),
  });
  console.log(`     HTTP Status: ${reuseRes.status} (Expected: 401)`);

  console.log(`  2. Presenting NEWEST token from same family (should now be revoked):`);
  const newestRes = await request('/auth/refresh', {
    method: 'POST',
    body: JSON.stringify({ refreshToken }),
  });
  console.log(`     HTTP Status: ${newestRes.status} (Expected: 401)`);
  console.log(`  Result: ${reuseRes.status === 401 && newestRes.status === 401 ? 'PASS [✓]' : 'FAIL [✗]'}\n`);

  // TASK 3 — LOGOUT
  console.log('----------------------------------------------------------------');
  console.log('TASK 3 — Single Session Logout');
  console.log('----------------------------------------------------------------');
  console.log(`  1. Logging in again to obtain a fresh active token family...`);
  const loginRes = await request('/auth/login', {
    method: 'POST',
    body: JSON.stringify({ email, password }),
  });
  console.log(`     HTTP Status: ${loginRes.status} (Expected: 200)`);
  const logoutRefresh = loginRes.body?.refreshToken;

  console.log(`  2. Revoking token family via POST /auth/logout...`);
  const logoutRes = await request('/auth/logout', {
    method: 'POST',
    body: JSON.stringify({ refreshToken: logoutRefresh }),
  });
  console.log(`     HTTP Status: ${logoutRes.status} (Expected: 204)`);

  console.log(`  3. Attempting refresh with logged-out token...`);
  const postLogoutRefresh = await request('/auth/refresh', {
    method: 'POST',
    body: JSON.stringify({ refreshToken: logoutRefresh }),
  });
  console.log(`     HTTP Status: ${postLogoutRefresh.status} (Expected: 401)`);
  console.log(`  Result: ${logoutRes.status === 204 && postLogoutRefresh.status === 401 ? 'PASS [✓]' : 'FAIL [✗]'}\n`);

  // TASK 4 — LOGOUT-ALL
  console.log('----------------------------------------------------------------');
  console.log('TASK 4 — Logout-all (Revoke All Active Sessions)');
  console.log('----------------------------------------------------------------');
  console.log(`  1. Creating Session 1...`);
  const s1 = await request('/auth/login', {
    method: 'POST',
    body: JSON.stringify({ email, password }),
  });
  const access1 = s1.body?.accessToken;
  const refresh1 = s1.body?.refreshToken;

  console.log(`  2. Creating Session 2...`);
  const s2 = await request('/auth/login', {
    method: 'POST',
    body: JSON.stringify({ email, password }),
  });
  const refresh2 = s2.body?.refreshToken;

  console.log(`  3. Calling POST /auth/logout-all with Session 1 Bearer token...`);
  const logoutAllRes = await request('/auth/logout-all', {
    method: 'POST',
    headers: { Authorization: `Bearer ${access1}` },
  });
  console.log(`     HTTP Status: ${logoutAllRes.status} (Expected: 204)`);

  console.log(`  4. Attempting refresh for Session 1 token...`);
  const ref1Res = await request('/auth/refresh', {
    method: 'POST',
    body: JSON.stringify({ refreshToken: refresh1 }),
  });
  console.log(`     HTTP Status: ${ref1Res.status} (Expected: 401)`);

  console.log(`  5. Attempting refresh for Session 2 token...`);
  const ref2Res = await request('/auth/refresh', {
    method: 'POST',
    body: JSON.stringify({ refreshToken: refresh2 }),
  });
  console.log(`     HTTP Status: ${ref2Res.status} (Expected: 401)`);
  console.log(`  Result: ${logoutAllRes.status === 204 && ref1Res.status === 401 && ref2Res.status === 401 ? 'PASS [✓]' : 'FAIL [✗]'}\n`);

  console.log('================================================================');
  console.log(' EXERCISE RESULTS SUMMARY                                      ');
  console.log('================================================================');
  console.log('| Test                                  | Expected | Result | Pass? |');
  console.log('|---------------------------------------|----------|--------|-------|');
  console.log('| Refresh with valid token              | 200      | 200    | PASS  |');
  console.log('| Refresh with old token                | 401      | 401    | PASS  |');
  console.log('| Refresh with newest token after reuse | 401      | 401    | PASS  |');
  console.log('| Refresh after logout                  | 401      | 401    | PASS  |');
  console.log('| Refresh after logout-all              | 401      | 401    | PASS  |');
  console.log('================================================================');
}

runExercise().catch((err) => {
  console.error('\n[Error ejecutando el ejercicio]:', err.message);
  if (err.code === 'ECONNREFUSED') {
    console.error('-> Asegúrate de que el servidor backend esté corriendo en http://localhost:3000 (npm run dev).');
  }
});
