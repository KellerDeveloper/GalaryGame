-- GalaryGame cloud leaderboard (opt-in, scores only — no photos, no PII beyond
-- a self-chosen display name).
--
-- Apply with either:
--   * Supabase MCP  → apply_migration(name: "leaderboard", query: <this file>)
--   * Supabase CLI  → supabase db push
--   * SQL editor in the dashboard

create table if not exists public.leaderboard (
    id           uuid primary key default gen_random_uuid(),
    player_id    uuid not null unique,
    display_name text not null check (char_length(display_name) between 1 and 40),
    xp           integer not null default 0 check (xp >= 0),
    dos_score    integer not null default 0 check (dos_score between 0 and 100),
    updated_at   timestamptz not null default now()
);

create index if not exists leaderboard_xp_idx on public.leaderboard (xp desc);

alter table public.leaderboard enable row level security;

-- Anyone (anon key) may read the leaderboard to render the top list.
drop policy if exists "leaderboard_read" on public.leaderboard;
create policy "leaderboard_read"
    on public.leaderboard for select
    using (true);

-- The client upserts its own row. Since there is no auth user, the client is
-- trusted to send its own player_id; rows are still uniquely keyed by player_id.
-- (Tighten to authenticated users with `auth.uid()` if/when accounts are added.)
drop policy if exists "leaderboard_insert" on public.leaderboard;
create policy "leaderboard_insert"
    on public.leaderboard for insert
    with check (true);

drop policy if exists "leaderboard_update" on public.leaderboard;
create policy "leaderboard_update"
    on public.leaderboard for update
    using (true)
    with check (true);
