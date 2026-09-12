-- Enable required extensions
create extension if not exists postgis;
create extension if not exists "uuid-ossp";

-- 1. PROFILES TABLE - Extends auth.users with app-specific fields
create table if not exists public.profiles (
    id uuid primary key references auth.users(id) on delete cascade,
    email text unique not null,
    phone text,
    role text not null check (role in ('customer', 'provider')),
    first_name text not null,
    last_name text not null,
    created_at timestamp with time zone default now() not null,
    updated_at timestamp with time zone default now() not null
);

-- 2. PROVIDER_STATUSES TABLE - Real-time location and verification tracking
create table if not exists public.provider_statuses (
    id uuid primary key references public.profiles(id) on delete cascade,
    is_available boolean default false not null,
    location geography(Point, 4326),
    stripe_account_id text,
    stripe_onboarding_complete boolean default false not null,
    checkr_candidate_id text,
    background_check_status text default 'not_started'::text not null
        check (background_check_status in ('not_started', 'pending', 'clear', 'failed')),
    is_verified_for_work boolean default false not null,
    last_heartbeat timestamp with time zone default now() not null
);

-- Create spatial index for fast proximity searches
create index if not exists provider_location_geo_index
    on public.provider_statuses using gist(location);

-- Create index for status lookups
create index if not exists provider_availability_index
    on public.provider_statuses(is_available, is_verified_for_work);

-- 3. BOOKING_REQUESTS TABLE - Customer service requests
create table if not exists public.booking_requests (
    id uuid primary key default uuid_generate_v4(),
    customer_id uuid not null references public.profiles(id) on delete cascade,
    provider_id uuid references public.profiles(id) on delete set null,
    service_description text not null,
    customer_location geography(Point, 4326) not null,
    status text default 'pending'::text not null
        check (status in ('pending', 'accepted', 'completed', 'cancelled')),
    requested_at timestamp with time zone default now() not null,
    accepted_at timestamp with time zone,
    completed_at timestamp with time zone,
    created_at timestamp with time zone default now() not null,
    updated_at timestamp with time zone default now() not null
);

-- Create indexes for booking queries
create index if not exists booking_customer_index on public.booking_requests(customer_id);
create index if not exists booking_provider_index on public.booking_requests(provider_id);
create index if not exists booking_status_index on public.booking_requests(status);

-- 4. AUDIT LOG TABLE - Security and compliance logging
create table if not exists public.audit_logs (
    id uuid primary key default uuid_generate_v4(),
    user_id uuid references public.profiles(id) on delete set null,
    action text not null,
    resource_type text not null,
    resource_id text,
    details jsonb,
    ip_address inet,
    user_agent text,
    created_at timestamp with time zone default now() not null
);

-- Create index for audit queries
create index if not exists audit_user_index on public.audit_logs(user_id);
create index if not exists audit_action_index on public.audit_logs(action);
create index if not exists audit_created_index on public.audit_logs(created_at desc);

-- 5. TRIGGER - Automatically create profile on new auth user
create or replace function public.handle_new_user()
returns trigger as $$
begin
    insert into public.profiles (id, email, phone, role, first_name, last_name)
    values (
        new.id,
        new.email,
        new.phone,
        coalesce(new.raw_user_meta_data->>'role', 'customer'),
        coalesce(new.raw_user_meta_data->>'first_name', 'User'),
        coalesce(new.raw_user_meta_data->>'last_name', 'Temporary')
    );

    -- If provider role, also create provider_statuses record
    if (new.raw_user_meta_data->>'role') = 'provider' then
        insert into public.provider_statuses (id) values (new.id);
    end if;

    return new;
end;
$$ language plpgsql security definer;

-- Drop trigger if it exists to avoid conflicts
drop trigger if exists on_auth_user_created on auth.users;

-- Create trigger for new auth users
create trigger on_auth_user_created
    after insert on auth.users
    for each row execute function public.handle_new_user();

-- 6. ENABLE ROW LEVEL SECURITY (RLS)
alter table public.profiles enable row level security;
alter table public.provider_statuses enable row level security;
alter table public.booking_requests enable row level security;
alter table public.audit_logs enable row level security;

-- RLS POLICIES FOR PROFILES
create policy "Public profiles are viewable by everyone"
    on public.profiles for select
    using (true);

create policy "Users can only update their own profile"
    on public.profiles for update
    using (auth.uid() = id);

create policy "Users can only insert their own profile (via trigger)"
    on public.profiles for insert
    with check (auth.uid() = id);

-- RLS POLICIES FOR PROVIDER_STATUSES
create policy "Available verified providers are viewable by customers"
    on public.provider_statuses for select
    using (is_available = true and is_verified_for_work = true);

create policy "Providers can view their own status"
    on public.provider_statuses for select
    using (auth.uid() = id);

create policy "Providers can update their own status"
    on public.provider_statuses for update
    using (auth.uid() = id);

-- RLS POLICIES FOR BOOKING_REQUESTS
create policy "Users can view their own bookings"
    on public.booking_requests for select
    using (auth.uid() = customer_id or auth.uid() = provider_id);

create policy "Customers can create bookings"
    on public.booking_requests for insert
    with check (auth.uid() = customer_id);

create policy "Providers can update bookings assigned to them"
    on public.booking_requests for update
    using (auth.uid() = provider_id);

-- RLS POLICIES FOR AUDIT_LOGS (Admins only - to be implemented)
create policy "Audit logs are admin-only"
    on public.audit_logs for select
    using (false); -- Disable for now, will enable admin role later

-- 7. ENABLE REALTIME BROADCASTS
alter publication supabase_realtime add table public.provider_statuses;
alter publication supabase_realtime add table public.booking_requests;
alter table public.provider_statuses replica identity full;
alter table public.booking_requests replica identity full;

-- 8. DATABASE FUNCTIONS

-- Function: Get nearby available providers within 5 miles (8046 meters)
create or replace function public.get_nearby_providers(
    client_long double precision,
    client_lat double precision,
    radius_meters double precision default 8046
)
returns table (
    provider_id uuid,
    first_name text,
    last_name text,
    distance_meters double precision
) as $$
begin
    return query
    select
        p.id,
        p.first_name,
        p.last_name,
        st_distance(ps.location, st_setsrid(st_point(client_long, client_lat), 4326)::geography)::double precision
    from public.provider_statuses ps
    join public.profiles p on ps.id = p.id
    where ps.is_available = true
        and ps.is_verified_for_work = true
        and ps.location is not null
        and st_dwithin(
            ps.location,
            st_setsrid(st_point(client_long, client_lat), 4326)::geography,
            radius_meters
        )
    order by distance_meters asc;
end;
$$ language plpgsql stable;

-- Function: Log audit events
create or replace function public.log_audit_event(
    p_action text,
    p_resource_type text,
    p_resource_id text default null,
    p_details jsonb default null
)
returns uuid as $$
declare
    v_log_id uuid;
begin
    insert into public.audit_logs (user_id, action, resource_type, resource_id, details)
    values (auth.uid(), p_action, p_resource_type, p_resource_id, p_details)
    returning id into v_log_id;
    return v_log_id;
end;
$$ language plpgsql security definer;

-- Grant execute permissions for functions
grant execute on function public.get_nearby_providers to authenticated;
grant execute on function public.log_audit_event to authenticated;
