-- Provider screens and dual-role accounts
--
-- 1. booking_requests gets the columns the booking API reads and writes, plus
--    expires_at so a request can't be accepted after its 10-minute window.
-- 2. One account can both book and offer services. Every sign-up gets a
--    profiles row; a provider_statuses row means the account has a provider
--    profile. profiles.role only records what the user picked at sign-up.
-- 3. Providers can't write their own provider_statuses row directly, so they
--    can't mark themselves verified; changes go through the API.

alter table public.booking_requests
    add column if not exists provider_id uuid references public.profiles(id) on delete set null,
    add column if not exists service_category text,
    add column if not exists description text,
    add column if not exists address text,
    add column if not exists latitude numeric,
    add column if not exists longitude numeric,
    add column if not exists scheduled_for timestamp with time zone,
    add column if not exists estimated_duration_minutes integer,
    add column if not exists price numeric(10, 2),
    add column if not exists expires_at timestamp with time zone,
    add column if not exists accepted_at timestamp with time zone,
    add column if not exists completed_at timestamp with time zone,
    add column if not exists cancelled_at timestamp with time zone;

update public.booking_requests set status = 'pending_acceptance' where status = 'pending';
alter table public.booking_requests alter column status set default 'pending_acceptance';
alter table public.booking_requests drop constraint if exists booking_requests_status_check;
alter table public.booking_requests add constraint booking_requests_status_check
    check (status in ('pending_acceptance', 'accepted', 'declined', 'completed', 'cancelled'));

create index if not exists booking_provider_status_index
    on public.booking_requests(provider_id, status);

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
    wants_provider boolean;
begin
    wants_provider := coalesce(new.raw_user_meta_data->>'wants_provider', '') = 'true'
        or coalesce(new.raw_user_meta_data->>'role', '') = 'provider';

    insert into public.profiles (id, email, phone, role, first_name, last_name)
    values (
        new.id,
        new.email,
        new.raw_user_meta_data->>'phone',
        case when wants_provider then 'provider' else 'customer' end,
        coalesce(new.raw_user_meta_data->>'first_name', ''),
        coalesce(new.raw_user_meta_data->>'last_name', '')
    );

    if wants_provider then
        insert into public.provider_statuses (id) values (new.id);
    end if;

    return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
    after insert on auth.users
    for each row execute function public.handle_new_user();

-- Accounts created before the trigger existed
insert into public.profiles (id, email, phone, role, first_name, last_name)
select
    u.id,
    u.email,
    u.raw_user_meta_data->>'phone',
    case
        when coalesce(u.raw_user_meta_data->>'wants_provider', '') = 'true'
          or coalesce(u.raw_user_meta_data->>'role', '') = 'provider'
        then 'provider'
        else 'customer'
    end,
    coalesce(u.raw_user_meta_data->>'first_name', ''),
    coalesce(u.raw_user_meta_data->>'last_name', '')
from auth.users u
where not exists (select 1 from public.profiles p where p.id = u.id);

insert into public.provider_statuses (id)
select u.id
from auth.users u
where (coalesce(u.raw_user_meta_data->>'wants_provider', '') = 'true'
       or coalesce(u.raw_user_meta_data->>'role', '') = 'provider')
  and not exists (select 1 from public.provider_statuses s where s.id = u.id);

drop policy if exists "Providers can update their own status" on public.provider_statuses;
