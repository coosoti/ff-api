import { supabase } from "../../config/database";

// ── Get all investments ───────────────────────────────────────────────

export async function getInvestments(userId: string) {
  const { data, error } = await supabase
    .from("investments")
    .select("*")
    .eq("user_id", userId)
    .order("created_at", { ascending: false });

  if (error) throw new Error(error.message);
  return data;
}

// ── Get a single investment ───────────────────────────────────────────

export async function getInvestmentById(userId: string, investmentId: string) {
  const { data, error } = await supabase
    .from("investments")
    .select("*")
    .eq("id", investmentId)
    .eq("user_id", userId)
    .single();

  if (error || !data) throw new Error("Investment not found");
  return data;
}

// ── Create an investment ──────────────────────────────────────────────

export async function createInvestment(
  userId: string,
  payload: {
    name: string;
    type: string;
    institution?: string;
    units?: number;
    purchase_price?: number;
    current_price?: number;
    total_invested: number;
    current_value: number;
    purchase_date?: string;
    notes?: string;
  }
) {
  const { data, error } = await supabase
    .from("investments")
    .insert({ user_id: userId, ...payload })
    .select()
    .single();

  if (error) throw new Error(error.message);
  return data;
}

// ── Update an investment ──────────────────────────────────────────────

export async function updateInvestment(
  userId: string,
  investmentId: string,
  fields: Partial<{
    name: string;
    type: string;
    institution: string;
    units: number;
    purchase_price: number;
    current_price: number;
    total_invested: number;
    current_value: number;
    purchase_date: string;
    notes: string;
  }>
) {
  const { data, error } = await supabase
    .from("investments")
    .update(fields)
    .eq("id", investmentId)
    .eq("user_id", userId)
    .select()
    .single();

  if (error) throw new Error(error.message);
  if (!data) throw new Error("Investment not found");
  return data;
}

// ── Delete an investment ──────────────────────────────────────────────

export async function deleteInvestment(userId: string, investmentId: string) {
  const { error } = await supabase
    .from("investments")
    .delete()
    .eq("id", investmentId)
    .eq("user_id", userId);

  if (error) throw new Error(error.message);
}

// ── Portfolio summary ─────────────────────────────────────────────────

export async function getPortfolioSummary(userId: string) {
  const { data, error } = await supabase
    .from("investments")
    .select("*")
    .eq("user_id", userId);

  if (error) throw new Error(error.message);

  const investments = data ?? [];

  const totalInvested    = investments.reduce((s, i) => s + Number(i.total_invested), 0);
  const totalCurrentValue = investments.reduce((s, i) => s + Number(i.current_value), 0);
  const totalGainLoss    = totalCurrentValue - totalInvested;
  const gainLossPct      = totalInvested > 0 ? (totalGainLoss / totalInvested) * 100 : 0;

  // Group by type
  const byType: Record<string, { total_invested: number; current_value: number; count: number }> = {};
  for (const inv of investments) {
    if (!byType[inv.type]) byType[inv.type] = { total_invested: 0, current_value: 0, count: 0 };
    byType[inv.type].total_invested  += Number(inv.total_invested);
    byType[inv.type].current_value   += Number(inv.current_value);
    byType[inv.type].count           += 1;
  }

  return {
    total_invested:     totalInvested,
    total_current_value: totalCurrentValue,
    total_gain_loss:    totalGainLoss,
    gain_loss_pct:      Math.round(gainLossPct * 100) / 100,
    by_type:            byType,
    investments,
  };
}