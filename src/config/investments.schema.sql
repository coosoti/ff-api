-- ─────────────────────────────────────────────────────────────────────
-- Module 6 — Investments
-- Run this in: Supabase Dashboard → SQL Editor → New query → Run
-- ─────────────────────────────────────────────────────────────────────

create table if not exists investments (
  id              uuid primary key default gen_random_uuid(),
  user_id         uuid not null references profiles(id) on delete cascade,
  name            text not null,                        -- e.g. "Safaricom shares", "MMF"
  type            text not null default 'other',        -- stocks | bonds | mmf | real_estate | crypto | other
  institution     text,                                 -- e.g. "Nabo Capital", "CDSC"
  units           numeric(18, 6),                       -- number of shares/units, optional
  purchase_price  numeric(12, 2),                       -- cost per unit at purchase
  current_price   numeric(12, 2),                       -- current price per unit
  total_invested  numeric(12, 2) not null check (total_invested >= 0),
  current_value   numeric(12, 2) not null check (current_value >= 0),
  purchase_date   date,
  notes           text,
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now()
);

-- ── Indexes ───────────────────────────────────────────────────────────
create index if not exists idx_investments_user_id   on investments(user_id);
create index if not exists idx_investments_user_type on investments(user_id, type);

-- ── Auto-update updated_at ────────────────────────────────────────────
create or replace trigger investments_updated_at
  before update on investments
  for each row execute function set_updated_at();