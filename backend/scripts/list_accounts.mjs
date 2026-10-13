// Dev helper: who's in the local database, and what they can do.
import { supabase } from '../src/db.js';

const { data: profiles, error } = await supabase
  .from('profiles')
  .select('id, first_name, last_name, email, hourly_rate, categories, rating_total, rating_count')
  .order('email');
if (error) throw error;

const { data: statuses } = await supabase
  .from('provider_statuses')
  .select('id, is_verified_for_work, is_available, available_until');
const byId = new Map((statuses ?? []).map((s) => [s.id, s]));

for (const p of profiles) {
  const s = byId.get(p.id);
  console.log([
    p.email,
    `${p.first_name} ${p.last_name}`.trim() || '(no name)',
    s ? `provider(verified=${s.is_verified_for_work}, available=${s.is_available})` : 'customer only',
    p.hourly_rate ? `$${p.hourly_rate}/hr` : '',
    `reviews=${p.rating_count}`,
    p.id,
  ].filter(Boolean).join(' | '));
}
process.exit(0);
