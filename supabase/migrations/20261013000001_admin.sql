-- Admin: who gets in, feedback about Yuki, and support tickets
--
-- is_admin is set by hand in the dashboard, the same way is_verified_for_work
-- has been: there's no route that grants it, so nobody can promote themselves.
--
-- Two separate inboxes on purpose. Feedback is about Yuki ("the map is slow",
-- "add a category for snow removal") and belongs to nobody in particular. A
-- support ticket is about one booking or job that went wrong, so it carries
-- what it's about and gets worked to a resolution.

alter table public.profiles
    add column if not exists is_admin boolean not null default false;

create table if not exists public.app_feedback (
    id uuid primary key default gen_random_uuid(),
    user_id uuid references public.profiles(id) on delete set null,
    category text not null check (category in ('idea', 'problem', 'praise', 'other')),
    message text not null,
    -- What the sender was looking at, so a vague report is still actionable.
    context text,
    status text not null default 'new' check (status in ('new', 'read', 'resolved')),
    admin_note text,
    created_at timestamp with time zone not null default now(),
    updated_at timestamp with time zone not null default now()
);

create index if not exists app_feedback_status_index
    on public.app_feedback(status, created_at desc);

create table if not exists public.support_tickets (
    id uuid primary key default gen_random_uuid(),
    reporter_id uuid not null references public.profiles(id) on delete cascade,
    -- What went wrong, and which booking or job it happened on.
    subject_type text not null check (subject_type in ('booking', 'job', 'account', 'other')),
    booking_id uuid references public.booking_requests(id) on delete set null,
    job_id uuid references public.job_posts(id) on delete set null,
    category text not null check (
        category in ('no_show', 'quality', 'payment', 'safety', 'account', 'other')
    ),
    message text not null,
    status text not null default 'open' check (
        status in ('open', 'in_progress', 'resolved', 'closed')
    ),
    admin_note text,
    resolved_at timestamp with time zone,
    created_at timestamp with time zone not null default now(),
    updated_at timestamp with time zone not null default now()
);

create index if not exists support_tickets_status_index
    on public.support_tickets(status, created_at desc);
create index if not exists support_tickets_reporter_index
    on public.support_tickets(reporter_id, created_at desc);

alter table public.app_feedback enable row level security;
alter table public.support_tickets enable row level security;
