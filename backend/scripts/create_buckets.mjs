// Creates the two photo buckets, which is infrastructure rather than schema.
//
// Public: provider work samples and photos on reviews, which sit beside things
// anyone can already see on the map. Private: photos a customer attaches to a
// job, which show their home and are only ever handed out as signed URLs.
//
//   node scripts/create_buckets.mjs

import { supabase } from '../src/db.js';

const BUCKETS = [
  { id: 'public-photos', public: true },
  { id: 'job-photos', public: false },
];

const OPTIONS = {
  fileSizeLimit: 5 * 1024 * 1024,
  allowedMimeTypes: ['image/jpeg', 'image/png', 'image/webp'],
};

for (const bucket of BUCKETS) {
  const { error } = await supabase.storage.createBucket(bucket.id, {
    public: bucket.public,
    ...OPTIONS,
  });

  if (!error) {
    console.log(`created ${bucket.id} (${bucket.public ? 'public' : 'private'})`);
    continue;
  }

  // Already there: make sure its settings still match what the code expects.
  const { error: updateError } = await supabase.storage.updateBucket(bucket.id, {
    public: bucket.public,
    ...OPTIONS,
  });
  console.log(
    updateError
      ? `FAILED ${bucket.id}: ${error.message} / ${updateError.message}`
      : `updated ${bucket.id} (${bucket.public ? 'public' : 'private'})`
  );
}

const { data: buckets } = await supabase.storage.listBuckets();
console.log('buckets now:', (buckets ?? []).map((b) => `${b.name}${b.public ? '' : ' (private)'}`).join(', '));
process.exit(0);
