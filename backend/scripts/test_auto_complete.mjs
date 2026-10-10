// Dev helper: proves a job nobody closed out settles itself once it is well past
// its expected end, which is what keeps reviews from being blocked forever.
//
//   node scripts/test_auto_complete.mjs <customer-email> <provider-email>

import { createClient } from '@supabase/supabase-js';
import config from '../src/config.js';

const [customerEmail, providerEmail] = process.argv.slice(2);
if (!customerEmail || !providerEmail) {
  console.error('usage: node scripts/test_auto_complete.mjs <customer-email> <provider-email>');
  process.exit(1);
}

const API = 'http://localhost:3000/api';
const admin = createClient(config.supabase.url, config.supabase.serviceRoleKey, {
  auth: { persistSession: false, autoRefreshToken: false },
});

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

const iso = (date) => `${date.toISOString().slice(0, 19)}Z`;
const hoursAgo = (hours) => new Date(Date.now() - hours * 60 * 60 * 1000);

const customer = await tokenFor(customerEmail);
const provider = await tokenFor(providerEmail);
const providerAccount = await call('GET', '/providers/me', provider);

console.log('1. Customer books, provider accepts, then both walk away');
const booking = await call('POST', '/bookings', customer, {
  provider_id: providerAccount.id,
  service_category: providerAccount.categories[0],
  description: 'Auto-complete safety net test.',
  address: '123 Main St, Sumner, WA 98390',
  latitude: 47.2032,
  longitude: -122.2401,
  estimated_duration_minutes: 90,
  asap: true,
});
const bookingId = booking.booking_id;
await call('POST', `/bookings/${bookingId}/accept`, provider, {
  estimated_arrival_at: iso(new Date(Date.now() + 30 * 60 * 1000)),
});
console.log(`   ${bookingId} is accepted`);

console.log('\n2. A job that ended an hour ago is left alone');
await admin
  .from('booking_requests')
  .update({ scheduled_for: hoursAgo(3).toISOString(), estimated_arrival_at: hoursAgo(3).toISOString() })
  .eq('id', bookingId);
let list = await call('GET', '/bookings/customers/bookings', customer);
let row = list.bookings.find((b) => b.booking_id === bookingId);
console.log(`   status ${row.status} ${row.status === 'accepted' ? '(correct, still live)' : '(PROBLEM: settled too early)'}`);

console.log('\n3. Reviewing it is still refused');
try {
  await call('POST', '/reviews', customer, { booking_id: bookingId, rating: 5 });
  console.log('   PROBLEM: it was allowed');
} catch {
  console.log('   blocked as expected');
}

console.log('\n4. Now the same job is two days past its end');
await admin
  .from('booking_requests')
  .update({ scheduled_for: hoursAgo(48).toISOString(), estimated_arrival_at: hoursAgo(48).toISOString() })
  .eq('id', bookingId);
list = await call('GET', '/bookings/customers/bookings', customer);
row = list.bookings.find((b) => b.booking_id === bookingId);
console.log(`   status ${row.status} ${row.status === 'completed' ? '(settled itself)' : '(PROBLEM: still open)'}`);

console.log('\n5. Both sides can review it now');
const review = await call('POST', '/reviews', customer, {
  booking_id: bookingId,
  rating: 5,
  comment: 'Settled automatically, reviewed afterwards.',
});
console.log(`   customer review saved, provider now ${review.subject_rating}`);
const theirs = await call('POST', '/reviews', provider, { booking_id: bookingId, rating: 5 });
console.log(`   provider review saved, customer now ${theirs.subject_rating}`);

console.log('\n6. The provider\'s own list settles their side too');
const theirList = await call('GET', '/bookings/providers/bookings?status=completed', provider);
console.log(
  `   ${theirList.bookings.some((b) => b.booking_id === bookingId) ? 'shows as completed' : 'MISSING'}`
);

console.log('\ndone.');
process.exit(0);
