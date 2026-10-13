// Dev helper: walks a booking all the way to reviews on both sides, through the
// real API, so the whole chain gets exercised without waiting on email codes.
//
//   node scripts/test_review_flow.mjs <customer-email> <provider-email> [accepted]
//
// Pass "accepted" to stop once the job is accepted, which leaves a job sitting in
// the provider's view with Mark complete still to press. Pass "customer" to have
// the customer be the one who closes the job out.

import { createClient } from '@supabase/supabase-js';
import config from '../src/config.js';

const [customerEmail, providerEmail, stage] = process.argv.slice(2);
if (!customerEmail || !providerEmail) {
  console.error('usage: node scripts/test_review_flow.mjs <customer-email> <provider-email>');
  process.exit(1);
}

const API = 'http://localhost:3000/api';
const admin = createClient(config.supabase.url, config.supabase.serviceRoleKey, {
  auth: { persistSession: false, autoRefreshToken: false },
});

// A session for an existing account, minted through the admin API: no email round trip.
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
    headers: {
      'Content-Type': 'application/json',
      ...(token ? { Authorization: `Bearer ${token}` } : {}),
    },
    body: body === undefined ? undefined : JSON.stringify(body),
  });
  const text = await res.text();
  let data;
  try {
    data = JSON.parse(text);
  } catch {
    data = text;
  }
  if (!res.ok) throw new Error(`${method} ${path} -> ${res.status} ${text}`);
  return data;
}

const iso = (date) => `${date.toISOString().slice(0, 19)}Z`;
const step = (n, message) => console.log(`\n${n}. ${message}`);

const customer = await tokenFor(customerEmail);
const provider = await tokenFor(providerEmail);
console.log(`signed in: customer=${customerEmail} provider=${providerEmail}`);

const providerAccount = await call('GET', '/providers/me', provider);
const providerId = providerAccount.id;
const category = providerAccount.categories[0];
console.log(
  `provider: ${providerAccount.first_name} ${providerAccount.last_name}, ` +
    `$${providerAccount.hourly_rate}/hr, offers ${providerAccount.categories.join(', ')}, ` +
    `rating=${providerAccount.rating ?? 'none'} (${providerAccount.review_count})`
);

step(1, 'Customer sends an ASAP request');
const booking = await call('POST', '/bookings', customer, {
  provider_id: providerId,
  service_category: category,
  description: 'End-to-end test of the review flow.',
  address: '123 Main St, Sumner, WA 98390',
  latitude: 47.2032,
  longitude: -122.2401,
  estimated_duration_minutes: 90,
  asap: true,
});
const bookingId = booking.booking_id;
console.log(`   booking ${bookingId}, price $${booking.price}, status ${booking.status}`);

step(2, 'It shows up in the provider\'s incoming requests');
const pending = await call('GET', '/bookings/providers/bookings?status=pending_acceptance', provider);
console.log(`   ${pending.bookings.some((b) => b.booking_id === bookingId) ? 'found it' : 'MISSING'}`);

step(3, 'Provider accepts with an arrival time');
const arriving = new Date(Date.now() + 30 * 60 * 1000);
await call('POST', `/bookings/${bookingId}/accept`, provider, {
  estimated_arrival_at: iso(arriving),
});
console.log(`   accepted, arriving ${arriving.toLocaleTimeString()}`);

if (stage === 'accepted') {
  console.log(`\nstopping here: booking ${bookingId} is accepted and waiting on Mark complete.`);
  process.exit(0);
}

step(4, 'Reviewing before completion is refused');
try {
  await call('POST', '/reviews', customer, { booking_id: bookingId, rating: 5 });
  console.log('   PROBLEM: it was allowed');
} catch (err) {
  console.log(`   blocked as expected: ${String(err.message).slice(-120)}`);
}

const closedByCustomer = stage === 'customer';
step(5, `${closedByCustomer ? 'Customer' : 'Provider'} marks the job complete`);
const completed = await call(
  'POST',
  `/bookings/${bookingId}/complete`,
  closedByCustomer ? customer : provider,
  {}
);
console.log(`   status ${completed.status}`);

step(6, 'Provider rates the customer 4 stars');
const providerReview = await call('POST', '/reviews', provider, {
  booking_id: bookingId,
  rating: 4,
  comment: 'Clear instructions, easy to work with.',
});
console.log(
  `   customer now ${providerReview.subject_rating} across ${providerReview.subject_review_count}`
);

step(7, 'Customer rates the provider 5 stars');
const customerReview = await call('POST', '/reviews', customer, {
  booking_id: bookingId,
  rating: 5,
  comment: 'On time and thorough. Would book again.',
});
console.log(
  `   provider now ${customerReview.subject_rating} across ${customerReview.subject_review_count}`
);

step(8, 'Re-rating replaces the review instead of adding one');
const redone = await call('POST', '/reviews', customer, {
  booking_id: bookingId,
  rating: 3,
  comment: 'Changed my mind: good, not perfect.',
});
console.log(
  `   provider now ${redone.subject_rating} across ${redone.subject_review_count} review(s), ` +
    `was ${customerReview.subject_review_count} before re-rating ` +
    `(${redone.subject_review_count === customerReview.subject_review_count ? 'unchanged, correct' : 'PROBLEM: it added one'})`
);

step(9, 'The provider\'s reviews page');
const summary = await call('GET', `/reviews/for/${providerId}`, customer);
console.log(
  `   rating ${summary.rating}, ${summary.review_count} review(s), ` +
    `external link ${summary.external_reviews_url ?? 'none'}`
);
for (const review of summary.reviews) {
  console.log(`   - ${review.reviewer_name} (${review.reviewer_role}) ${review.rating}star: ${review.comment}`);
}

step(10, 'The map shows the star average');
const nearby = await call(
  'GET',
  '/customers/nearby-providers?latitude=47.2032&longitude=-122.2401&radius=25'
);
const onMap = nearby.providers.find((p) => p.id === providerId);
console.log(
  onMap
    ? `   ${onMap.first_name}: rating ${onMap.rating}, ${onMap.review_count} review(s)`
    : '   provider is not on the map right now (not available) - skipped'
);

step(11, 'Both booking lists remember who rated what');
const mine = await call('GET', '/bookings/customers/bookings', customer);
const mineRow = mine.bookings.find((b) => b.booking_id === bookingId);
console.log(`   customer list: my_rating=${mineRow?.my_rating}`);
const theirs = await call('GET', '/bookings/providers/bookings?status=completed', provider);
const theirsRow = theirs.bookings.find((b) => b.booking_id === bookingId);
console.log(`   provider list: my_rating=${theirsRow?.my_rating}`);

console.log(`\ndone. booking ${bookingId} is completed and reviewed by both sides.`);
process.exit(0);
