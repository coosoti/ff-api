-- ─────────────────────────────────────────────────────────────────────
-- Income Module
-- Run this in: Supabase Dashboard → SQL Editor → New query → Run
-- ─────────────────────────────────────────────────────────────────────

create table if not exists income (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null references profiles(id) on delete cascade,
  amount      numeric(12, 2) not null check (amount > 0),
  source      text not null,              -- e.g. "Salary", "Freelance", "Dividends"
  month       text not null,              -- format: "2026-03"
  notes       text,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);

-- ── Indexes ───────────────────────────────────────────────────────────
create index if not exists idx_income_user_id
  on income(user_id);

create index if not exists idx_income_user_month
  on income(user_id, month);

-- ── Auto-update updated_at ────────────────────────────────────────────
create or replace trigger income_updated_at
  before update on income
  for each row execute function set_updated_at();s