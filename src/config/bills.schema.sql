-- ─────────────────────────────────────────────────────────────────────
-- Module 9 — Recurring Bills & Subscriptions
-- Run this in: Supabase Dashboard → SQL Editor → New query → Run
-- ─────────────────────────────────────────────────────────────────────

create table if not exists bills (
  id              uuid primary key default gen_random_uuid(),
  user_id         uuid not null references profiles(id) on delete cascade,
  name            text not null,
  amount          numeric(12, 2) not null check (amount > 0),
  category        text not null default 'other',       -- rent | utilities | subscription | insurance | loan | other
  cycle           text not null default 'monthly',     -- weekly | monthly | quarterly | annual
  due_day         int not null check (due_day >= 1 and due_day <= 31), -- day of month/week the bill is due
  is_active       boolean not null default true,
  notes           text,
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now()
);

-- Payment log — one row per cycle paid
create table if not exists bill_payments (
  id          uuid primary key default gen_random_uuid(),
  bill_id     uuid not null references bills(id) on delete cascade,
  user_id     uuid not null references profiles(id) on delete cascade,
  cycle_key   text not null,                           -- e.g. "2026-03" for monthly, "2026-W11" for weekly
  amount_paid numeric(12, 2) not null,
  paid_at     timestamptz not null default now(),
  notes       text,
  unique(bill_id, cycle_key)                           -- one payment per bill per cycle
);

-- ── Indexes ───────────────────────────────────────────────────────────
create index if not exists idx_bills_user_id         on bills(user_id);
create index if not exists idx_bill_payments_bill_id on bill_payments(bill_id);
create index if not exists idx_bill_payments_user_id on bill_payments(user_id);
create index if not exists idx_bill_payments_cycle   on bill_payments(user_id, cycle_key);

-- ── Auto-update updated_at ────────────────────────────────────────────
create or replace trigger bills_updated_at
  before update on bills
  for each row execute function set_updated_at();