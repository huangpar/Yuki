-- Availability expiry
--
-- Providers going "Available Now" get a 30-minute window. Once available_until
-- passes they stop appearing in customer searches until they toggle back on.
-- Location updates deliberately do NOT extend this window.

alter table public.provider_statuses
    add column if not exists available_until timestamp with time zone;

create index if not exists provider_available_until_index
    on public.provider_statuses(available_until);
