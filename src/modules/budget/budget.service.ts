import { supabase } from "../../config/database";

// ── US-005: Get all categories for a user ─────────────────────────────

export async function getCategories(userId: string) {
  const { data, error } = await supabase
    .from("budget_categories")
    .select("*")
    .eq("user_id", userId)
    .order("type")
    .order("name");

  if (error) throw new Error(error.message);
  return data;
}

// ── US-007: Create a custom category ─────────────────────────────────

export async function createCategory(
  userId: string,
  name: string,
  type: "needs" | "wants" | "savings",
  budgeted_amount: number
) {
  const { data, error } = await supabase
    .from("budget_categories")
    .insert({ user_id: userId, name, type, budgeted_amount, is_default: false })
    .select()
    .single();

  if (error) throw new Error(error.message);
  return data;
}

// ── US-007: Update a category ─────────────────────────────────────────

export async function updateCategory(
  userId: string,
  categoryId: string,
  fields: { name?: string; type?: "needs" | "wants" | "savings"; budgeted_amount?: number }
) {
  const { data, error } = await supabase
    .from("budget_categories")
    .update(fields)
    .eq("id", categoryId)
    .eq("user_id", userId) // prevents updating another user's category
    .select()
    .single();

  if (error) throw new Error(error.message);
  if (!data) throw new Error("Category not found");
  return data;
}

// ── US-007: Delete a custom category ─────────────────────────────────

export async function deleteCategory(userId: string, categoryId: string) {
  // Prevent deleting default categories
  const { data: existing } = await supabase
    .from("budget_categories")
    .select("is_default")
    .eq("id", categoryId)
    .eq("user_id", userId)
    .single();

  if (!existing) throw new Error("Category not found");
  if (existing.is_default) throw new Error("Cannot delete a default category");

  const { error } = await supabase
    .from("budget_categories")
    .delete()
    .eq("id", categoryId)
    .eq("user_id", userId);

  if (error) throw new Error(error.message);
}

// ── US-006: Recalculate 50/30/20 based on new income ─────────────────

export async function recalculateBudget(userId: string, monthlyIncome: number) {
  if (monthlyIncome <= 0) throw new Error("Monthly income must be greater than 0");

  // Only recalculate default categories — custom ones are preserved
  const { data: defaults, error } = await supabase
    .from("budget_categories")
    .select("id, name, type")
    .eq("user_id", userId)
    .eq("is_default", true);

  if (error) throw new Error(error.message);
  if (!defaults?.length) throw new Error("No default categories found");

  // Weights per category name
  const WEIGHTS: Record<string, number> = {
    "Housing": 0.25, "Food": 0.10, "Transport": 0.06,
    "Utilities": 0.04, "Healthcare": 0.02, "Insurance": 0.02,
    "Education": 0.01, "Entertainment": 0.10, "Dining": 0.12,
    "Personal Care": 0.08, "Emergency Fund": 0.10, "Investments": 0.10,
  };

  const updates = defaults.map((cat) => ({
    id: cat.id,
    budgeted_amount: Math.round(monthlyIncome * (WEIGHTS[cat.name] ?? 0)),
  }));

  // Update each default category
  for (const update of updates) {
    const { error: updateError } = await supabase
      .from("budget_categories")
      .update({ budgeted_amount: update.budgeted_amount })
      .eq("id", update.id)
      .eq("user_id", userId);

    if (updateError) throw new Error(updateError.message);
  }

  // Also update monthly_income on the profile
  await supabase
    .from("profiles")
    .update({ monthly_income: monthlyIncome })
    .eq("id", userId);

  return getCategories(userId);
}

// ── US-008: Monthly budget summary ───────────────────────────────────

export async function getBudgetSummary(userId: string, month: string) {
  const startDate = `${month}-01`;
  const endDate = new Date(new Date(startDate).setMonth(new Date(startDate).getMonth() + 1))
    .toISOString()
    .split("T")[0];

  // Get all categories
  const { data: categories, error: catError } = await supabase
    .from("budget_categories")
    .select("*")
    .eq("user_id", userId);

  if (catError) throw new Error(catError.message);

  // Get all transactions for the month
  const { data: transactions, error: txError } = await supabase
    .from("transactions")
    .select("category_id, amount, type")
    .eq("user_id", userId)
    .gte("date", startDate)
    .lt("date", endDate);

  if (txError) throw new Error(txError.message);

  // Sum actual spend per category (expenses only)
  const actuals: Record<string, number> = {};
  for (const tx of transactions ?? []) {
    actuals[tx.category_id] = (actuals[tx.category_id] ?? 0) + Number(tx.amount);
  }

  // Get total income from income table for this month
  const { data: incomeRows, error: incomeError } = await supabase
    .from("income")
    .select("amount")
    .eq("user_id", userId)
    .eq("month", month);

  console.log("[budget summary] userId:", userId, "month:", month);
  console.log("[budget summary] incomeRows:", incomeRows, "error:", incomeError);

  let totalIncomeThisMonth = (incomeRows ?? []).reduce((sum, r) => sum + Number(r.amount), 0);
  console.log("[budget summary] totalIncomeThisMonth:", totalIncomeThisMonth);

  // Fall back to profile monthly_income if no income logged yet
  if (totalIncomeThisMonth === 0) {
    const { data: profile } = await supabase
      .from("profiles")
      .select("monthly_income")
      .eq("id", userId)
      .single();
    totalIncomeThisMonth = Number(profile?.monthly_income ?? 0);
  }

  // Build summary rows
  const rows = (categories ?? []).map((cat) => ({
    ...cat,
    actual_amount: actuals[cat.id] ?? 0,
    remaining: cat.budgeted_amount - (actuals[cat.id] ?? 0),
    is_over: (actuals[cat.id] ?? 0) > cat.budgeted_amount,
  }));

  // Totals by type
  const summary = {
    month,
    total_income: totalIncomeThisMonth,
    categories: rows,
    totals: {
      needs:   { budgeted: 0, actual: 0, target: Math.round(totalIncomeThisMonth * 0.5) },
      wants:   { budgeted: 0, actual: 0, target: Math.round(totalIncomeThisMonth * 0.3) },
      savings: { budgeted: 0, actual: 0, target: Math.round(totalIncomeThisMonth * 0.2) },
    },
  };

  for (const row of rows) {
    const t = row.type as "needs" | "wants" | "savings";
    summary.totals[t].budgeted += Number(row.budgeted_amount);
    summary.totals[t].actual   += row.actual_amount;
  }

  return summary;
}