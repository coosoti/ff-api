-- ─────────────────────────────────────────────────────────────────────
-- Module 5 — Net Worth
-- Run this in: Supabase Dashboard → SQL Editor → New query → Run
-- ─────────────────────────────────────────────────────────────────────

create table if not exists assets (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null references profiles(id) on delete cascade,
  name        text not null,                          -- e.g. "Land in Kiambu", "Toyota Fielder"
  category    text not null default 'other',          -- property | vehicle | investment | other
  value       numeric(12, 2) not null check (value >= 0),
  notes       text,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);

create table if not exists liabilities (
  id              uuid primary key default gen_random_uuid(),
  user_id         uuid not null references profiles(id) on delete cascade,
  name            text not null,                      -- e.g. "NCBA Car Loan", "KCB Credit Card"
  category        text not null default 'other',      -- loan | mortgage | credit_card | other
  balance         numeric(12, 2) not null check (balance >= 0),
  interest_rate   numeric(5, 2),                      -- annual %, optional
  notes           text,
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now()
);

-- ── Indexes ───────────────────────────────────────────────────────────
create index if not exists idx_assets_user_id       on assets(user_id);
create index if not exists idx_liabilities_user_id  on liabilities(user_id);

-- ── Auto-update updated_at ────────────────────────────────────────────
create or replace trigger assets_updated_at
  before update on assets
  for each row execute function set_updated_at();

create or replace trigger liabilities_updated_at
  before update on liabilities
  for each row execute function set_updated_at();