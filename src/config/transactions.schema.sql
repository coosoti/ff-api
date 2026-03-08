-- ─────────────────────────────────────────────────────────────────────
-- Module 3 — Transactions
-- Run this in: Supabase Dashboard → SQL Editor → New query → Run
-- ─────────────────────────────────────────────────────────────────────

create table if not exists transactions (
  id           uuid primary key default gen_random_uuid(),
  user_id      uuid not null references profiles(id) on delete cascade,
  category_id  uuid references budget_categories(id) on delete set null,
  amount       numeric(12, 2) not null check (amount > 0),
  type         text not null check (type in ('income', 'expense')),
  date         date not null default current_date,
  notes        text,
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now()
);

-- ── Indexes ───────────────────────────────────────────────────────────
create index if not exists idx_transactions_user_id
  on transactions(user_id);

create index if not exists idx_transactions_user_date
  on transactions(user_id, date desc);

create index if not exists idx_transactions_category_id
  on transactions(category_id);

-- ── Auto-update updated_at ────────────────────────────────────────────
create or replace trigger transactions_updated_at
  before update on transactions
  for each row execute function set_updated_at();