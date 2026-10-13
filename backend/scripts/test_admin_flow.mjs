// Dev helper: walks the admin surface end to end - feedback in and worked,
// a ticket raised and answered, the verification queue, and the numbers.
// Also checks that someone who isn't an admin gets nothing.
//
//   node scripts/test_admin_flow.mjs <admin-email> <other-email>

import { createClient } from '@supabase/supabase-js';
import config from '../src/config.js';

const [adminEmail, otherEmail] = process.argv.slice(2);
if (!adminEmail || !otherEmail) {
  console.error('usage: node scripts/test_admin_flow.mjs <admin-email> <other-email>');
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

// Admin is granted by hand on purpose, so this only ever reads it.
const { data: adminProfile } = await admin
  .from('profiles')
  .select('id, is_admin')
  .eq('email', adminEmail)
  .maybeSingle();

if (!adminProfile?.is_admin) {
  console.error(
    `${adminEmail} is not an admin yet. Run this in the SQL editor first:\n\n` +
      `  update public.profiles set is_admin = true where email = '${adminEmail}';\n`
  );
  process.exit(1);
}

const adminToken = await tokenFor(adminEmail);
const otherToken = await tokenFor(otherEmail);

console.log('1. Someone who is not an admin gets nothing');
try {
  await call('GET', '/admin/overview', otherToken);
  console.log('   PROBLEM: they got in');
} catch (err) {
  console.log(`   ${String(err.message).includes('403') ? 'refused with 403' : err.message}`);
}

console.log('\n2. The numbers load');
const overview = await call('GET', '/admin/overview?window=all', adminToken);
console.log(
  `   ${overview.people.accounts} accounts, ${overview.people.providers} providers ` +
    `(${overview.people.verified_providers} verified, ${overview.people.available_now} available)`
);
console.log(
  `   jobs: ${overview.jobs.posted} posted, ${overview.jobs.offers_made} offers, ` +
    `${overview.jobs.assigned} matched (${overview.jobs.match_rate ?? '-'}%)`
);
console.log(
  `   bookings: ${overview.bookings.requested} requested, ${overview.bookings.accepted} accepted ` +
    `(${overview.bookings.acceptance_rate ?? '-'}%), ${overview.bookings.completed} completed ` +
    `(${overview.bookings.completion_rate ?? '-'}%)`
);

console.log('\n3. Someone sends feedback about Yuki');
await call('POST', '/feedback', otherToken, {
  category: 'idea',
  message: 'Admin flow test - a category for snow removal would be useful.',
  context: 'the map',
});
const inbox = await call('GET', '/admin/feedback?status=new', adminToken);
const mine = inbox.feedback.find((f) => f.message.startsWith('Admin flow test'));
console.log(`   ${mine ? `in the inbox from ${mine.from?.email ?? 'someone'}` : 'MISSING'}`);

console.log('\n4. Working it through the inbox');
await call('PATCH', `/admin/feedback/${mine.feedback_id}`, adminToken, { status: 'read' });
const resolved = await call('PATCH', `/admin/feedback/${mine.feedback_id}`, adminToken, {
  status: 'resolved',
  admin_note: 'Added to the list.',
});
console.log(`   status is now ${resolved.status}`);

console.log('\n5. Someone reports a problem on their own booking');
const bookings = await call('GET', '/bookings/customers/bookings', otherToken);
const booking = bookings.bookings[0];
if (!booking) {
  console.log('   no bookings for that account - skipping the ticket checks');
  process.exit(0);
}
const ticket = await call('POST', '/support/tickets', otherToken, {
  subject_type: 'booking',
  booking_id: booking.booking_id,
  category: 'no_show',
  message: 'Admin flow test - nobody turned up for this one.',
});
console.log(`   ticket ${ticket.ticket_id} opened, status ${ticket.status}`);

console.log('\n6. It lands in the admin queue, gets a reply, and resolves');
const queue = await call('GET', '/admin/tickets?status=open', adminToken);
const queued = queue.tickets.find((t) => t.ticket_id === ticket.ticket_id);
console.log(`   ${queued ? `queued, reported by ${queued.reporter?.email ?? 'someone'}` : 'MISSING'}`);
await call('PATCH', `/admin/tickets/${ticket.ticket_id}`, adminToken, { status: 'in_progress' });
const worked = await call('PATCH', `/admin/tickets/${ticket.ticket_id}`, adminToken, {
  status: 'resolved',
  admin_note: 'Spoke to both sides. Sorted.',
});
console.log(`   status ${worked.status}, resolved_at ${worked.resolved_at ? 'set' : 'MISSING'}`);

console.log('\n7. The reporter sees the reply on their own report');
const theirs = await call('GET', '/support/tickets', otherToken);
const back = theirs.tickets.find((t) => t.ticket_id === ticket.ticket_id);
console.log(`   "${back?.admin_note ?? 'MISSING'}" (${back?.status})`);

console.log('\n8. You cannot report a problem on a booking that is not yours');
const otherBookings = await call('GET', '/bookings/providers/bookings?status=completed', adminToken);
const notTheirs = otherBookings.bookings.find(
  (b) => !bookings.bookings.some((own) => own.booking_id === b.booking_id)
);
if (!notTheirs) {
  console.log('   no booking to try that with - skipped');
} else {
  try {
    await call('POST', '/support/tickets', otherToken, {
      subject_type: 'booking',
      booking_id: notTheirs.booking_id,
      category: 'other',
      message: 'Should never be created - not my booking.',
    });
    console.log('   PROBLEM: it was allowed');
  } catch (err) {
    console.log(`   ${String(err.message).includes('403') ? 'refused with 403' : err.message}`);
  }
}

console.log('\n9. The verification queue');
const nameOf = (p) => `${p.first_name ?? ''} ${p.last_name ?? ''}`.trim() || p.email || p.id;
const waiting = await call('GET', '/admin/providers?verified=false', adminToken);
console.log(
  `   ${waiting.providers.length} waiting: ${waiting.providers.map(nameOf).join(', ') || 'nobody'}`
);

const candidate = waiting.providers[0];
if (candidate) {
  await call('POST', `/admin/providers/${candidate.id}/verification`, adminToken, {
    verified: true,
  });
  const approved = await call('GET', '/admin/providers?verified=true', adminToken);
  const now = approved.providers.find((p) => p.id === candidate.id);
  console.log(`   approved ${nameOf(candidate)}: ${now ? 'shows as approved' : 'MISSING'}`);

  // Put them back the way they were, since this is someone's real account.
  await call('POST', `/admin/providers/${candidate.id}/verification`, adminToken, {
    verified: false,
  });
  console.log(`   restored ${nameOf(candidate)} to waiting`);
}

console.log('\ndone.');
process.exit(0);
