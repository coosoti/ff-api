-- ─────────────────────────────────────────────────────────────────────
-- Module 1 — Authentication
-- Run this in: Supabase Dashboard → SQL Editor → New query → Run
-- ─────────────────────────────────────────────────────────────────────

-- profiles — one row per user, mirrors Supabase auth.users
create table if not exists profiles (
  id              uuid primary key references auth.users(id) on delete cascade,
  email           text not null unique,
  name            text not null,
  monthly_income  numeric(12, 2) not null default 0,
  dependents      int not null default 0,
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now()
);

-- budget_categories — seeded automatically on register (US-005)
-- Full schema added in Module 2; created here so register doesn't break
create table if not exists budget_categories (
  id               uuid primary key default gen_random_uuid(),
  user_id          uuid not null references profiles(id) on delete cascade,
  name             text not null,
  type             text not null check (type in ('needs', 'wants', 'savings')),
  budgeted_amount  numeric(12, 2) not null default 0,
  is_default       boolean not null default false,
  created_at       timestamptz not null default now(),
  updated_at       timestamptz not null default now()
);

-- ── Indexes ───────────────────────────────────────────────────────────
-- Supabase does not auto-index foreign keys
create index if not exists idx_budget_categories_user_id
  on budget_categories(user_id);

-- Fast email lookup on login
create index if not exists idx_profiles_email
  on profiles(lower(email));

-- ── Row Level Security ────────────────────────────────────────────────
alter table profiles enable row level security;
alter table budget_categories enable row level security;

-- Profiles: user can only select/update their own row
create policy "profiles: select own"
  on profiles for select
  using (auth.uid() = id);

create policy "profiles: insert own"
  on profiles for insert
  with check (auth.uid() = id);

create policy "profiles: update own"
  on profiles for update
  using (auth.uid() = id)
  with check (auth.uid() = id);

-- Budget categories: user can only touch their own rows
create policy "budget_categories: select own"
  on budget_categories for select
  using (auth.uid() = user_id);

create policy "budget_categories: insert own"
  on budget_categories for insert
  with check (auth.uid() = user_id);

create policy "budget_categories: update own"
  on budget_categories for update
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

create policy "budget_categories: delete own"
  on budget_categories for delete
  using (auth.uid() = user_id);

-- ── Auto-update updated_at ────────────────────────────────────────────
create or replace function set_updated_at()
returns trigger language plpgsql as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create or replace trigger profiles_updated_at
  before update on profiles
  for each row execute function set_updated_at();

create or replace trigger budget_categories_updated_at
  before update on budget_categories
  for each row execute function set_updated_at();