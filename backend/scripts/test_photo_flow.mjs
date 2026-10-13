// Dev helper: uploads real bytes through the signed-URL flow and checks every
// place a photo is meant to show up, plus that you can't attach someone else's.
//
//   node scripts/test_photo_flow.mjs <customer-email> <provider-email>

import { createClient } from '@supabase/supabase-js';
import config from '../src/config.js';

const [customerEmail, providerEmail] = process.argv.slice(2);
if (!customerEmail || !providerEmail) {
  console.error('usage: node scripts/test_photo_flow.mjs <customer-email> <provider-email>');
  process.exit(1);
}

const API = 'http://localhost:3000/api';
const admin = createClient(config.supabase.url, config.supabase.serviceRoleKey, {
  auth: { persistSession: false, autoRefreshToken: false },
});

// A 1x1 PNG, which is all the bytes this needs to be a real image.
const PNG = Buffer.from(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==',
  'base64'
);

async function tokenFor(email) {
  const link = await admin.auth.admin.generateLink({ type: 'magiclink', email });
  if (link.error) throw new Error(`generateLink(${email}): ${link.error.message}`);
  const anon = createClient(config.supabase.url, config.supabase.anonKey, {
    auth: { persistSession: false, autoRefreshToken: false },
  });
  const session = await anon.auth.verifyOtp({
    type: 'magiclink',
    token_hash: link.data.properties.hashed_token,
  });
  if (session.error) throw new Error(`verifyOtp(${email}): ${session.error.message}`);
  return session.data.session.access_token;
}

async function call(method, path, token, body) {
  const res = await fetch(`${API}${path}`, {
    method,
    headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${token}` },
    body: body === undefined ? undefined : JSON.stringify(body),
  });
  const text = await res.text();
  if (!res.ok) throw new Error(`${method} ${path} -> ${res.status} ${text}`);
  return text ? JSON.parse(text) : null;
}

// What the app does: ask for a one-shot URL, then PUT the bytes at it.
async function uploadPhoto(kind, token) {
  const signed = await call('POST', '/uploads/photo', token, {
    kind,
    content_type: 'image/png',
  });
  const put = await fetch(signed.upload_url, {
    method: 'PUT',
    headers: { 'Content-Type': 'image/png' },
    body: PNG,
  });
  if (!put.ok) throw new Error(`upload PUT -> ${put.status} ${await put.text()}`);
  return signed.path;
}

async function reachable(url) {
  const res = await fetch(url);
  return `${res.status} ${res.headers.get('content-type') ?? ''}`.trim();
}

const customer = await tokenFor(customerEmail);
const provider = await tokenFor(providerEmail);

console.log('1. Provider uploads a work photo and saves it to their profile');
const profilePhoto = await uploadPhoto('profile', provider);
const account = await call('GET', '/providers/me', provider);
await call('PUT', '/providers/profile', provider, {
  hourly_rate: account.hourly_rate,
  categories: account.categories,
  bio: account.bio ?? '',
  external_reviews_url: account.external_reviews_url ?? '',
  photos: [profilePhoto],
});
const saved = await call('GET', '/providers/me', provider);
console.log(`   profile has ${saved.photos.length} photo(s)`);
console.log(`   the URL serves: ${await reachable(saved.photos[0])}`);

console.log('\n2. It shows on their card on the map');
// The map only lists providers who are available, so put them on it and then
// put things back, rather than skipping the check when nobody happens to be on.
const wasAvailable = saved.available_until && new Date(saved.available_until) > new Date();
if (!wasAvailable) {
  await call('POST', '/providers/availability/toggle', provider, {
    available: true,
    latitude: 47.2032,
    longitude: -122.2401,
  });
}
const nearby = await fetch(
  `${API}/customers/nearby-providers?latitude=47.2032&longitude=-122.2401&radius=25`
).then((r) => r.json());
const onMap = nearby.providers.find((p) => p.id === account.id);
console.log(`   ${onMap ? `${onMap.photos.length} photo(s) on the card` : 'provider not on the map'}`);
if (!wasAvailable) {
  await call('POST', '/providers/availability/toggle', provider, { available: false });
  console.log('   (availability put back to off)');
}

console.log('\n3. Customer posts a job with a photo');
const jobPhoto = await uploadPhoto('job', customer);
const job = await call('POST', '/jobs', customer, {
  service_category: account.categories[0],
  description: 'Photo flow test - please ignore.',
  address: '123 Main St, Sumner, WA 98390',
  latitude: 47.2032,
  longitude: -122.2401,
  estimated_duration_minutes: 60,
  offered_price: 60,
  open_for_hours: 24,
  asap: true,
  photos: [jobPhoto],
});
console.log(`   posted ${job.job_id} with ${job.photos.length} photo(s)`);
const mine = await call('GET', '/jobs/mine', customer);
const myJob = mine.jobs.find((j) => j.job_id === job.job_id);
const url = myJob.photos[0] ?? '';
console.log(`   my jobs returns a ${url.includes('token=') ? 'signed' : 'PLAIN'} URL`);
console.log(`   the URL serves: ${await reachable(url)}`);

console.log('\n4. A job photo is not public without its signature');
const bare = url.split('?')[0];
console.log(`   unsigned URL serves: ${await reachable(bare)} (should be 400 or 404)`);

console.log('\n5. Providers browsing open jobs see it too');
const open = await call(
  'GET',
  '/jobs/open?latitude=47.2032&longitude=-122.2401&radius=25',
  provider
);
const seen = open.jobs.find((j) => j.job_id === job.job_id);
console.log(`   ${seen ? `${seen.photos.length} photo(s) visible to the provider` : 'job not in the feed'}`);

console.log('\n6. You cannot attach someone else\'s photo');
try {
  await call('POST', '/jobs', customer, {
    service_category: account.categories[0],
    description: 'Should never be created - borrowed photo.',
    address: '123 Main St, Sumner, WA 98390',
    latitude: 47.2032,
    longitude: -122.2401,
    estimated_duration_minutes: 60,
    offered_price: 60,
    open_for_hours: 24,
    asap: true,
    photos: [profilePhoto],
  });
  console.log('   PROBLEM: it was allowed');
} catch (err) {
  console.log(`   refused: ${String(err.message).includes('invalid_photos') ? 'invalid_photos' : err.message.slice(0, 80)}`);
}

console.log('\n7. Over the limit is refused');
try {
  const many = await Promise.all([1, 2, 3, 4, 5].map(() => uploadPhoto('job', customer)));
  await call('POST', '/jobs', customer, {
    service_category: account.categories[0],
    description: 'Should never be created - too many photos.',
    address: '123 Main St, Sumner, WA 98390',
    latitude: 47.2032,
    longitude: -122.2401,
    estimated_duration_minutes: 60,
    offered_price: 60,
    open_for_hours: 24,
    asap: true,
    photos: many,
  });
  console.log('   PROBLEM: it was allowed');
} catch (err) {
  console.log(`   refused: ${String(err.message).slice(-60)}`);
}

console.log('\n8. Tidying up the test job');
await call('POST', `/jobs/${job.job_id}/cancel`, customer, {});
console.log('   cancelled');

console.log('\ndone.');
process.exit(0);
