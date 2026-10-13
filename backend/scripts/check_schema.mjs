// Dev helper: says which migrations have actually landed.
import { supabase } from '../src/db.js';

async function has(table, column) {
  const { error } = await supabase.from(table).select(column).limit(1);
  return error ? `MISSING (${error.message.slice(0, 60)})` : 'ok';
}

async function tableExists(table) {
  const { error } = await supabase.from(table).select('id').limit(1);
  return error ? `MISSING (${error.message.slice(0, 60)})` : 'ok';
}

console.log('profiles.photos          ', await has('profiles', 'photos'));
console.log('job_posts.photos         ', await has('job_posts', 'photos'));
console.log('reviews.photos           ', await has('reviews', 'photos'));
console.log('profiles.is_admin        ', await has('profiles', 'is_admin'));
console.log('app_feedback             ', await tableExists('app_feedback'));
console.log('support_tickets          ', await tableExists('support_tickets'));

const { data: buckets } = await supabase.storage.listBuckets();
console.log('buckets                  ', (buckets ?? []).map((b) => b.name).join(', ') || 'none');

const { data: admins } = await supabase.from('profiles').select('email, is_admin').eq('is_admin', true);
console.log('admins                   ', (admins ?? []).map((a) => a.email).join(', ') || 'nobody yet');
process.exit(0);
