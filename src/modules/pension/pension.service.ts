import { supabase } from "../../config/database";

// ── Pension Accounts ──────────────────────────────────────────────────

export async function getAccounts(userId: string) {
  const { data, error } = await supabase
    .from("pension_accounts")
    .select("*")
    .eq("user_id", userId)
    .order("created_at", { ascending: false });

  if (error) throw new Error(error.message);
  return data;
}

export async function getAccountById(userId: string, accountId: string) {
  const { data, error } = await supabase
    .from("pension_accounts")
    .select("*")
    .eq("id", accountId)
    .eq("user_id", userId)
    .single();

  if (error || !data) throw new Error("Pension account not found");
  return data;
}

export async function createAccount(
  userId: string,
  payload: {
    provider: string;
    scheme_name: string;
    total_value: number;
    retirement_age?: number;
    date_of_birth?: string;
    notes?: string;
  }
) {
  const { data, error } = await supabase
    .from("pension_accounts")
    .insert({ user_id: userId, ...payload })
    .select()
    .single();

  if (error) throw new Error(error.message);
  return data;
}

export async function updateAccount(
  userId: string,
  accountId: string,
  fields: Partial<{
    provider: string;
    scheme_name: string;
    total_value: number;
    retirement_age: number;
    date_of_birth: string;
    notes: string;
  }>
) {
  const { data, error } = await supabase
    .from("pension_accounts")
    .update(fields)
    .eq("id", accountId)
    .eq("user_id", userId)
    .select()
    .single();

  if (error) throw new Error(error.message);
  if (!data) throw new Error("Pension account not found");
  return data;
}

export async function deleteAccount(userId: string, accountId: string) {
  const { error } = await supabase
    .from("pension_accounts")
    .delete()
    .eq("id", accountId)
    .eq("user_id", userId);

  if (error) throw new Error(error.message);
}

// ── Fund Allocations ──────────────────────────────────────────────────

export async function getFunds(userId: string, accountId: string) {
  const { data, error } = await supabase
    .from("pension_funds")
    .select("*")
    .eq("account_id", accountId)
    .eq("user_id", userId)
    .order("allocation_pct", { ascending: false });

  if (error) throw new Error(error.message);
  return data;
}

export async function upsertFunds(
  userId: string,
  accountId: string,
  funds: { name: string; allocation_pct: number; current_value: number }[]
) {
  // Validate allocations sum to ~100
  const total = funds.reduce((s, f) => s + f.allocation_pct, 0);
  if (Math.abs(total - 100) > 0.1) {
    throw new Error(`Fund allocations must sum to 100% (currently ${total}%)`);
  }

  // Delete existing funds for this account then re-insert
  await supabase.from("pension_funds").delete().eq("account_id", accountId).eq("user_id", userId);

  const rows = funds.map((f) => ({ ...f, account_id: accountId, user_id: userId }));
  const { data, error } = await supabase.from("pension_funds").insert(rows).select();

  if (error) throw new Error(error.message);
  return data;
}

// ── Withdrawals ───────────────────────────────────────────────────────

export async function getWithdrawals(userId: string, accountId: string) {
  const { data, error } = await supabase
    .from("pension_withdrawals")
    .select("*")
    .eq("account_id", accountId)
    .eq("user_id", userId)
    .order("date", { ascending: false });

  if (error) throw new Error(error.message);
  return data;
}

export async function createWithdrawal(
  userId: string,
  accountId: string,
  payload: { amount: number; reason?: string; date: string; notes?: string }
) {
  // Deduct from account total_value
  const account = await getAccountById(userId, accountId);
  const newValue = Number(account.total_value) - payload.amount;
  if (newValue < 0) throw new Error("Withdrawal exceeds current pension value");

  const { data, error } = await supabase
    .from("pension_withdrawals")
    .insert({ user_id: userId, account_id: accountId, ...payload })
    .select()
    .single();

  if (error) throw new Error(error.message);

  // Update account total_value
  await supabase
    .from("pension_accounts")
    .update({ total_value: newValue })
    .eq("id", accountId)
    .eq("user_id", userId);

  return data;
}

export async function deleteWithdrawal(userId: string, withdrawalId: string) {
  // Restore amount to account total_value
  const { data: w, error: we } = await supabase
    .from("pension_withdrawals")
    .select("*")
    .eq("id", withdrawalId)
    .eq("user_id", userId)
    .single();

  if (we || !w) throw new Error("Withdrawal not found");

  const account = await getAccountById(userId, w.account_id);
  await supabase
    .from("pension_accounts")
    .update({ total_value: Number(account.total_value) + Number(w.amount) })
    .eq("id", w.account_id)
    .eq("user_id", userId);

  const { error } = await supabase
    .from("pension_withdrawals")
    .delete()
    .eq("id", withdrawalId)
    .eq("user_id", userId);

  if (error) throw new Error(error.message);
}

// ── Projection ────────────────────────────────────────────────────────

export async function getProjection(userId: string, accountId: string) {
  const account = await getAccountById(userId, accountId);

  const currentValue  = Number(account.total_value);
  const retirementAge = account.retirement_age ?? 60;

  // Years to retirement (requires date_of_birth)
  let yearsToRetirement = 20; // fallback
  if (account.date_of_birth) {
    const dob         = new Date(account.date_of_birth);
    const today       = new Date();
    const currentAge  = today.getFullYear() - dob.getFullYear();
    yearsToRetirement = Math.max(retirementAge - currentAge, 0);
  }

  // Project at 3 growth rates
  const project = (rate: number) =>
    Math.round(currentValue * Math.pow(1 + rate, yearsToRetirement));

  return {
    account_id:          accountId,
    current_value:       currentValue,
    years_to_retirement: yearsToRetirement,
    retirement_age:      retirementAge,
    projections: {
      conservative: { rate: 0.06, value: project(0.06) },
      moderate:     { rate: 0.09, value: project(0.09) },
      aggressive:   { rate: 0.12, value: project(0.12) },
    },
  };
}