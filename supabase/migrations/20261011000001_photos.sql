-- Photos on provider profiles, job posts, and reviews
--
-- Each table keeps an array of storage paths rather than URLs, so the bucket can
-- move or a path can be re-signed without rewriting rows.
--
-- The two buckets these paths live in are created by
-- backend/scripts/create_buckets.mjs, not here: inserting into storage.buckets
-- from the SQL editor takes the whole migration down with it when it fails, and
-- the storage API is the supported way to make one anyway.

alter table public.profiles
    add column if not exists photos text[] not null default '{}';

alter table public.job_posts
    add column if not exists photos text[] not null default '{}';

alter table public.reviews
    add column if not exists photos text[] not null default '{}';
