-- ─────────────────────────────────────────────────────────────────────
-- Module 4 — Savings Goals
-- Run this in: Supabase Dashboard → SQL Editor → New query → Run
-- ─────────────────────────────────────────────────────────────────────

create table if not exists savings_goals (
  id              uuid primary key default gen_random_uuid(),
  user_id         uuid not null references profiles(id) on delete cascade,
  name            text not null,
  target_amount   numeric(12, 2) not null check (target_amount > 0),
  current_amount  numeric(12, 2) not null default 0 check (current_amount >= 0),
  target_date     date,
  notes           text,
  is_completed    boolean not null default false,
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now()
);

-- ── Indexes ───────────────────────────────────────────────────────────
create index if not exists idx_savings_goals_user_id
  on savings_goals(user_id);

create index if not exists idx_savings_goals_user_completed
  on savings_goals(user_id, is_completed);

-- ── Auto-update updated_at ────────────────────────────────────────────
create or replace trigger savings_goals_updated_at
  before update on savings_goals
  for each row execute function set_updated_at();