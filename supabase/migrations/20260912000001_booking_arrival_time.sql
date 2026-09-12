-- Arrival time on accepted bookings
--
-- A provider can accept a new request while earlier jobs are still ahead of
-- them, so "accepted" alone doesn't tell the customer when to expect them.
-- The provider picks an arrival time when accepting and the customer sees it.

alter table public.booking_requests
    add column if not exists estimated_arrival_at timestamp with time zone;
