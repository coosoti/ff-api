import { supabase } from "../../config/database";

// ── Assets ────────────────────────────────────────────────────────────

export async function getAssets(userId: string) {
  const { data, error } = await supabase
    .from("assets")
    .select("*")
    .eq("user_id", userId)
    .order("created_at", { ascending: false });

  if (error) throw new Error(error.message);
  return data;
}

export async function createAsset(
  userId: string,
  payload: { name: string; category: string; value: number; notes?: string }
) {
  const { data, error } = await supabase
    .from("assets")
    .insert({ user_id: userId, ...payload })
    .select()
    .single();

  if (error) throw new Error(error.message);
  return data;
}

export async function updateAsset(
  userId: string,
  assetId: string,
  fields: Partial<{ name: string; category: string; value: number; notes: string }>
) {
  const { data, error } = await supabase
    .from("assets")
    .update(fields)
    .eq("id", assetId)
    .eq("user_id", userId)
    .select()
    .single();

  if (error) throw new Error(error.message);
  if (!data) throw new Error("Asset not found");
  return data;
}

export async function deleteAsset(userId: string, assetId: string) {
  const { error } = await supabase
    .from("assets")
    .delete()
    .eq("id", assetId)
    .eq("user_id", userId);

  if (error) throw new Error(error.message);
}

// ── Liabilities ───────────────────────────────────────────────────────

export async function getLiabilities(userId: string) {
  const { data, error } = await supabase
    .from("liabilities")
    .select("*")
    .eq("user_id", userId)
    .order("created_at", { ascending: false });

  if (error) throw new Error(error.message);
  return data;
}

export async function createLiability(
  userId: string,
  payload: { name: string; category: string; balance: number; interest_rate?: number; notes?: string }
) {
  const { data, error } = await supabase
    .from("liabilities")
    .insert({ user_id: userId, ...payload })
    .select()
    .single();

  if (error) throw new Error(error.message);
  return data;
}

export async function updateLiability(
  userId: string,
  liabilityId: string,
  fields: Partial<{ name: string; category: string; balance: number; interest_rate: number; notes: string }>
) {
  const { data, error } = await supabase
    .from("liabilities")
    .update(fields)
    .eq("id", liabilityId)
    .eq("user_id", userId)
    .select()
    .single();

  if (error) throw new Error(error.message);
  if (!data) throw new Error("Liability not found");
  return data;
}

export async function deleteLiability(userId: string, liabilityId: string) {
  const { error } = await supabase
    .from("liabilities")
    .delete()
    .eq("id", liabilityId)
    .eq("user_id", userId);

  if (error) throw new Error(error.message);
}

// ── Net Worth Summary ─────────────────────────────────────────────────

export async function getNetWorthSummary(userId: string) {
  // 1. Manual assets
  const { data: assets, error: assetsError } = await supabase
    .from("assets")
    .select("*")
    .eq("user_id", userId);

  if (assetsError) throw new Error(assetsError.message);

  // 2. Manual liabilities
  const { data: liabilities, error: liabError } = await supabase
    .from("liabilities")
    .select("*")
    .eq("user_id", userId);

  if (liabError) throw new Error(liabError.message);

  // 3. Auto: savings goals current amounts
  const { data: savingsGoals } = await supabase
    .from("savings_goals")
    .select("id, name, current_amount")
    .eq("user_id", userId);

  const savingsTotal = (savingsGoals ?? []).reduce((s, g) => s + Number(g.current_amount), 0);

  // 4. Auto: cash = all-time income − all-time expenses − savings contributions
  const { data: incomeRows } = await supabase
    .from("income")
    .select("amount")
    .eq("user_id", userId);

  const totalIncome = (incomeRows ?? []).reduce((s, r) => s + Number(r.amount), 0);

  const { data: txRows } = await supabase
    .from("transactions")
    .select("amount")
    .eq("user_id", userId);

  const totalExpenses = (txRows ?? []).reduce((s, r) => s + Number(r.amount), 0);

  // Savings contributions = sum of current_amount across all goals
  // (what has actually been set aside, not just the target)
  const savingsContributions = savingsTotal;

  const cashBalance = Math.max(totalIncome - totalExpenses - savingsContributions, 0);

  // 5. Auto: investments current value
  const { data: investmentRows } = await supabase
    .from("investments")
    .select("id, name, type, current_value, total_invested")
    .eq("user_id", userId);

  const investmentsTotal = (investmentRows ?? []).reduce((s, i) => s + Number(i.current_value), 0);

  // 6. Auto: pension accounts total value
  const { data: pensionRows } = await supabase
    .from("pension_accounts")
    .select("id, provider, scheme_name, total_value")
    .eq("user_id", userId);

  const pensionTotal = (pensionRows ?? []).reduce((s, p) => s + Number(p.total_value), 0);

  // 7. Totals
  const manualAssetsTotal      = (assets ?? []).reduce((s, a) => s + Number(a.value), 0);
  const manualLiabilitiesTotal = (liabilities ?? []).reduce((s, l) => s + Number(l.balance), 0);
  const totalAssets             = cashBalance + savingsTotal + manualAssetsTotal + investmentsTotal + pensionTotal;
  const netWorth                = totalAssets - manualLiabilitiesTotal;

  return {
    net_worth:         netWorth,
    total_assets:      totalAssets,
    total_liabilities: manualLiabilitiesTotal,
    breakdown: {
      cash:        cashBalance,
      savings:     savingsTotal,
      assets:      manualAssetsTotal,
      investments: investmentsTotal,
      pension:     pensionTotal,
    },
    assets:        assets ?? [],
    liabilities:   liabilities ?? [],
    savings_goals: savingsGoals ?? [],
    investments:   investmentRows ?? [],
    pension:       pensionRows ?? [],
  };
}