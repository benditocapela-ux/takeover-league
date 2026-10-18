'use strict';
// Read-only acceptance test against isolated Supabase TEST. Never uses production.
// Requires four real *TEST-only* users and at least one private goal owned by boxer A.
// No login credentials, tokens, names or private goal contents are logged.
const assert = require('node:assert/strict');

const projectRef = 'cfgdvcccsqwfjajuizsr';
const required = [
  'LEAGUE21_TEST_URL', 'LEAGUE21_TEST_PUBLISHABLE_KEY',
  'LEAGUE21_BOXER_A_EMAIL', 'LEAGUE21_BOXER_A_PASSWORD',
  'LEAGUE21_BOXER_B_EMAIL', 'LEAGUE21_BOXER_B_PASSWORD',
  'LEAGUE21_COACH_EMAIL', 'LEAGUE21_COACH_PASSWORD',
  'LEAGUE21_ADMIN_EMAIL', 'LEAGUE21_ADMIN_PASSWORD'
];
const missing = required.filter(name => !process.env[name]);
if (missing.length) {
  console.error('NOT RUN: Missing TEST-only environment variables: ' + missing.join(', '));
  process.exit(2);
}

const origin = new URL(process.env.LEAGUE21_TEST_URL);
assert.equal(origin.protocol, 'https:', 'TEST endpoint must use HTTPS');
assert.equal(origin.hostname, projectRef + '.supabase.co',
  'HARD STOP: tests must NEVER run against the production project');
assert.equal(origin.pathname, '/', 'TEST URL must be project origin, without a path');
assert.equal(origin.username, '', 'No embedded username in endpoint');
assert.equal(origin.password, '', 'No embedded password in endpoint');
const apiKey = process.env.LEAGUE21_TEST_PUBLISHABLE_KEY;

async function request(path, token, method = 'GET', body) {
  const headers = {apikey: apiKey, Accept: 'application/json'};
  if (token) headers.Authorization = 'Bearer ' + token;
  if (body !== undefined) headers['Content-Type'] = 'application/json';
  const response = await fetch(origin.origin + path, {
    method, headers, body: body === undefined ? undefined : JSON.stringify(body),
    redirect: 'error', signal: AbortSignal.timeout(15000)
  });
  const raw = await response.text();
  let json = null;
  try { json = JSON.parse(raw); } catch {}
  return {ok: response.ok, status: response.status, data: json};
}

async function authenticate(label, role) {
  const email = process.env['LEAGUE21_' + label + '_EMAIL'];
  const password = process.env['LEAGUE21_' + label + '_PASSWORD'];
  const result = await request('/auth/v1/token?grant_type=password', null, 'POST', {email, password});
  assert.equal(result.ok, true, label + ': real Supabase password login failed (' + result.status + ')');
  const token = result.data?.access_token;
  assert.ok(token, label + ': missing access token');
  const user = await request('/auth/v1/user', token);
  assert.equal(user.ok, true, label + ': getUser failed');
  const id = user.data?.id;
  assert.match(id || '', /^[0-9a-f-]{36}$/i, label + ': missing auth user ID');

  const query = new URLSearchParams({select: 'id,role,is_active,auth_user_id',
    auth_user_id: 'eq.' + id});
  const profile = await request('/rest/v1/profiles?' + query, token);
  assert.equal(profile.ok, true, label + ': cannot read own profile');
  assert.equal(profile.data?.length, 1, label + ': exactly one linked profile required');
  assert.equal(profile.data[0].role, role, label + ': unexpected profile role');
  assert.equal(profile.data[0].is_active, true, label + ': linked profile must be active');
  console.log('PASS real login: ' + label + ' (' + role + ')');
  return {token, profileId: profile.data[0].id};
}

async function goals(token, boxerId) {
  const params = new URLSearchParams({select: 'id,boxer_id'});
  if (boxerId) params.set('boxer_id', 'eq.' + boxerId);
  const result = await request('/rest/v1/league_boxer_goals_v21?' + params, token);
  assert.equal(result.ok, true, 'private goals SELECT failed (' + result.status + ')');
  assert.ok(Array.isArray(result.data), 'private goals response must be an array');
  return result.data;
}

async function anonymousPrivacy() {
  for (const table of ['league_boxer_goals_v21', 'point_transactions']) {
    const response = await request('/rest/v1/' + table + '?select=*&limit=1', null);
    assert.ok(!response.ok || (Array.isArray(response.data) && response.data.length === 0),
      'SECURITY FAILURE: anonymous visitor can read private ' + table);
    console.log('PASS anonymous access denied: ' + table);
  }
  for (const table of ['league_public_badges_v21', 'league_public_duel_history_v21']) {
    const response = await request('/rest/v1/' + table + '?select=*&limit=3', null);
    assert.equal(response.ok, true, 'public sanitized ' + table + ' unavailable');
    assert.ok(Array.isArray(response.data));
    for (const row of response.data) {
      const sensitive = ['auth_user_id', 'weight', 'email', 'notes', 'password'];
      assert.ok(sensitive.every(key => !(key in row)),
        'SECURITY FAILURE: private column in public ' + table);
    }
    console.log('PASS public sanitized read: ' + table);
  }
}

async function main() {
  await anonymousPrivacy();
  const a = await authenticate('BOXER_A', 'boxer');
  const b = await authenticate('BOXER_B', 'boxer');
  const coach = await authenticate('COACH', 'coach');
  const admin = await authenticate('ADMIN', 'admin');
  assert.notEqual(a.profileId, b.profileId, 'Two distinct boxer accounts required');

  const aGoals = await goals(a.token);
  assert.ok(aGoals.every(row => row.boxer_id === a.profileId),
    'SECURITY FAILURE: boxer A can read another boxer goals');
  const owned = aGoals.find(row => row.boxer_id === a.profileId);
  assert.ok(owned, 'NOT ACCEPTED: seed one TEST-only goal for boxer A before running');
  const bGoals = await goals(b.token);
  assert.ok(bGoals.every(row => row.boxer_id === b.profileId),
    'SECURITY FAILURE: boxer B can read another boxer goals');
  assert.equal((await goals(b.token, a.profileId)).length, 0,
    'SECURITY FAILURE: boxer B can read boxer A goal by boxer_id');
  assert.equal((await goals(coach.token, a.profileId)).length, 0,
    'SECURITY FAILURE: coach can read boxer A private goal');
  assert.ok((await goals(admin.token, a.profileId)).some(row => row.id === owned.id),
    'Admin cannot read boxer A seeded goal');
  console.log('PASS authenticated RLS: own, foreign, coach and admin goal visibility');

  const progressQuery = new URLSearchParams({select: 'id,goal_id', goal_id: 'eq.' + owned.id});
  const otherProgress = await request(
    '/rest/v1/league_goal_progress_v21?' + progressQuery, b.token);
  assert.equal(otherProgress.ok, true, 'foreign manual progress request failed unexpectedly');
  assert.equal(otherProgress.data?.length, 0,
    'SECURITY FAILURE: another boxer can read private goal progress');
  console.log('PASS foreign private goal progress denied');

  console.log('READ-ONLY TEST ACCEPTED: no training, EXP, user, season or challenge was modified.');
}

main().catch(error => {
  console.error('RELEASE GATE NOT PASSED: ' + error.message);
  process.exitCode = 1;
});
