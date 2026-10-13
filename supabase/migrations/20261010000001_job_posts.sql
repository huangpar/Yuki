-- Job posts and provider offers
--
-- The other direction of the marketplace: a customer posts a job with the price
-- they're willing to pay, and verified providers nearby either take that price or
-- counter with a flat or hourly rate. Yuki doesn't process payments, so these
-- amounts are only what the two of them agree to settle directly.

create table if not exists public.job_posts (
    id uuid primary key default gen_random_uuid(),
    customer_id uuid not null references public.profiles(id) on delete cascade,
    service_category text not null,
    description text not null,
    address text not null,
    latitude numeric not null,
    longitude numeric not null,
    asap boolean not null default false,
    scheduled_for timestamp with time zone,
    estimated_duration_minutes integer not null,
    offered_price numeric(10, 2) not null,
    status text not null default 'open'
        check (status in ('open', 'assigned', 'cancelled', 'expired')),
    booking_id uuid references public.booking_requests(id) on delete set null,
    created_at timestamp with time zone not null default now(),
    expires_at timestamp with time zone not null default now() + interval '24 hours'
);

create index if not exists job_posts_open_index on public.job_posts(status, expires_at);
create index if not exists job_posts_customer_index on public.job_posts(customer_id, created_at desc);

create table if not exists public.job_offers (
    id uuid primary key default gen_random_uuid(),
    job_id uuid not null references public.job_posts(id) on delete cascade,
    provider_id uuid not null references public.profiles(id) on delete cascade,
    -- 'listed' takes the customer's price, 'flat' is a total for the job, 'hourly' is per hour
    rate_type text not null check (rate_type in ('listed', 'flat', 'hourly')),
    amount numeric(10, 2) not null,
    message text,
    status text not null default 'pending'
        check (status in ('pending', 'accepted', 'declined', 'withdrawn')),
    created_at timestamp with time zone not null default now(),
    unique (job_id, provider_id)
);

create index if not exists job_offers_job_index on public.job_offers(job_id, status);
create index if not exists job_offers_provider_index on public.job_offers(provider_id, created_at desc);

-- Same as the other tables: no direct access, everything goes through the API.
alter table public.job_posts enable row level security;
alter table public.job_offers enable row level security;
