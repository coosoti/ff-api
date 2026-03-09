-- ─────────────────────────────────────────────────────────────────────
-- Module 7 — IPP Pension
-- Run this in: Supabase Dashboard → SQL Editor → New query → Run
-- ─────────────────────────────────────────────────────────────────────

-- Core pension account (one per user, can have multiple if needed)
create table if not exists pension_accounts (
  id                  uuid primary key default gen_random_uuid(),
  user_id             uuid not null references profiles(id) on delete cascade,
  provider            text not null,                   -- e.g. "Jubilee", "ICEA Lion", "Sanlam"
  scheme_name         text not null,                   -- e.g. "Individual Pension Plan"
  total_value         numeric(12, 2) not null default 0 check (total_value >= 0),
  retirement_age      int not null default 60,
  date_of_birth       date,
  notes               text,
  created_at          timestamptz not null default now(),
  updated_at          timestamptz not null default now()
);

-- Fund allocations within a pension account
create table if not exists pension_funds (
  id              uuid primary key default gen_random_uuid(),
  account_id      uuid not null references pension_accounts(id) on delete cascade,
  user_id         uuid not null references profiles(id) on delete cascade,
  name            text not null,                       -- e.g. "Money Market Fund", "Equity Fund"
  allocation_pct  numeric(5, 2) not null check (allocation_pct >= 0 and allocation_pct <= 100),
  current_value   numeric(12, 2) not null default 0 check (current_value >= 0),
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now()
);

-- Withdrawal history
create table if not exists pension_withdrawals (
  id          uuid primary key default gen_random_uuid(),
  account_id  uuid not null references pension_accounts(id) on delete cascade,
  user_id     uuid not null references profiles(id) on delete cascade,
  amount      numeric(12, 2) not null check (amount > 0),
  reason      text,                                    -- e.g. "Partial withdrawal", "Retirement"
  date        date not null,
  notes       text,
  created_at  timestamptz not null default now()
);

-- ── Indexes ───────────────────────────────────────────────────────────
create index if not exists idx_pension_accounts_user_id    on pension_accounts(user_id);
create index if not exists idx_pension_funds_account_id    on pension_funds(account_id);
create index if not exists idx_pension_funds_user_id       on pension_funds(user_id);
create index if not exists idx_pension_withdrawals_user_id on pension_withdrawals(user_id);
create index if not exists idx_pension_withdrawals_account on pension_withdrawals(account_id);

-- ── Auto-update updated_at ────────────────────────────────────────────
create or replace trigger pension_accounts_updated_at
  before update on pension_accounts
  for each row execute function set_updated_at();

create or replace trigger pension_funds_updated_at
  before update on pension_funds
  for each row execute function set_updated_at();