import { supabase } from "../../config/database";

// ── Get all income entries for a month ────────────────────────────────

export async function getIncomeByMonth(userId: string, month: string) {
  const { data, error } = await supabase
    .from("income")
    .select("*")
    .eq("user_id", userId)
    .eq("month", month)
    .order("created_at", { ascending: false });

  if (error) throw new Error(error.message);
  return data;
}

// ── Get total income for a month ──────────────────────────────────────

export async function getMonthlyTotal(userId: string, month: string) {
  const { data, error } = await supabase
    .from("income")
    .select("amount")
    .eq("user_id", userId)
    .eq("month", month);

  if (error) throw new Error(error.message);

  const total = (data ?? []).reduce((sum, row) => sum + Number(row.amount), 0);

  // Fall back to profile monthly_income if nothing logged yet
  if (total === 0) {
    const { data: profile } = await supabase
      .from("profiles")
      .select("monthly_income")
      .eq("id", userId)
      .single();
    return Number(profile?.monthly_income ?? 0);
  }

  return total;
}

// ── Add an income entry ───────────────────────────────────────────────

export async function createIncome(
  userId: string,
  payload: { amount: number; source: string; month: string; notes?: string }
) {
  const { data, error } = await supabase
    .from("income")
    .insert({ user_id: userId, ...payload })
    .select()
    .single();

  if (error) throw new Error(error.message);
  return data;
}

// ── Update an income entry ────────────────────────────────────────────

export async function updateIncome(
  userId: string,
  incomeId: string,
  fields: Partial<{ amount: number; source: string; notes: string }>
) {
  const { data, error } = await supabase
    .from("income")
    .update(fields)
    .eq("id", incomeId)
    .eq("user_id", userId)
    .select()
    .single();

  if (error) throw new Error(error.message);
  if (!data) throw new Error("Income entry not found");
  return data;
}

// ── Delete an income entry ────────────────────────────────────────────

export async function deleteIncome(userId: string, incomeId: string) {
  const { error } = await supabase
    .from("income")
    .delete()
    .eq("id", incomeId)
    .eq("user_id", userId);

  if (error) throw new Error(error.message);
}