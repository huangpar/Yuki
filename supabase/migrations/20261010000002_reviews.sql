-- Ratings and reviews, both directions
--
-- After a booking is completed, each side can rate the other once. Running totals
-- live on profiles so the map can show a star average without counting rows every
-- time. external_reviews_url is a provider's own Google or Yelp listing: we link
-- out to it rather than copying reviews, which those services don't permit.

create table if not exists public.reviews (
    id uuid primary key default gen_random_uuid(),
    booking_id uuid not null references public.booking_requests(id) on delete cascade,
    reviewer_id uuid not null references public.profiles(id) on delete cascade,
    subject_id uuid not null references public.profiles(id) on delete cascade,
    reviewer_role text not null check (reviewer_role in ('customer', 'provider')),
    rating smallint not null check (rating between 1 and 5),
    comment text,
    created_at timestamp with time zone not null default now(),
    updated_at timestamp with time zone not null default now(),
    unique (booking_id, reviewer_id)
);

create index if not exists reviews_subject_index on public.reviews(subject_id, created_at desc);
create index if not exists reviews_reviewer_index on public.reviews(reviewer_id, created_at desc);

alter table public.profiles
    add column if not exists rating_total integer not null default 0,
    add column if not exists rating_count integer not null default 0,
    add column if not exists external_reviews_url text;

alter table public.reviews enable row level security;
