import { supabase } from "../../config/database";

// ── Helpers ───────────────────────────────────────────────────────────

function monthsBack(n: number): string {
  const d = new Date();
  d.setMonth(d.getMonth() - n + 1);
  return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, "0")}`;
}

function currentMonth(): string {
  const d = new Date();
  return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, "0")}`;
}

function allMonthsInRange(from: string, to: string): string[] {
  const months: string[] = [];
  const [fy, fm] = from.split("-").map(Number);
  const [ty, tm] = to.split("-").map(Number);
  let y = fy, m = fm;
  while (y < ty || (y === ty && m <= tm)) {
    months.push(`${y}-${String(m).padStart(2, "0")}`);
    m++;
    if (m > 12) { m = 1; y++; }
  }
  return months;
}

// ── 1. Income vs Expenses trend ───────────────────────────────────────

export async function getIncomeExpenseTrend(userId: string, months = 12) {
  const from = monthsBack(months);
  const to   = currentMonth();
  const range = allMonthsInRange(from, to);

  const [{ data: incomeRows }, { data: txRows }] = await Promise.all([
    supabase.from("income").select("amount, month").eq("user_id", userId).gte("month", from).lte("month", to),
    supabase.from("transactions").select("amount, date").eq("user_id", userId),
  ]);

  // Aggregate income by month
  const incomeByMonth: Record<string, number> = {};
  for (const r of incomeRows ?? []) {
    incomeByMonth[r.month] = (incomeByMonth[r.month] ?? 0) + Number(r.amount);
  }

  // Aggregate expenses by month
  const expenseByMonth: Record<string, number> = {};
  for (const r of txRows ?? []) {
    const month = r.date.slice(0, 7);
    if (month >= from && month <= to) {
      expenseByMonth[month] = (expenseByMonth[month] ?? 0) + Number(r.amount);
    }
  }

  const trend = range.map((month) => ({
    month,
    income:   Math.round(incomeByMonth[month]  ?? 0),
    expenses: Math.round(expenseByMonth[month] ?? 0),
    savings:  Math.round((incomeByMonth[month] ?? 0) - (expenseByMonth[month] ?? 0)),
  }));

  const totalIncome   = trend.reduce((s, r) => s + r.income, 0);
  const totalExpenses = trend.reduce((s, r) => s + r.expenses, 0);
  const avgSavings    = trend.length > 0 ? Math.round((totalIncome - totalExpenses) / trend.length) : 0;

  return { trend, totalIncome, totalExpenses, avgSavings };
}

// ── 2. Spending by category ───────────────────────────────────────────

export async function getSpendingByCategory(userId: string, months = 12) {
  const from = monthsBack(months);
  const to   = currentMonth();

  const { data: txRows } = await supabase
    .from("transactions")
    .select("amount, date, category_id, budget_categories(name, type)")
    .eq("user_id", userId);

  const byCategory: Record<string, { name: string; type: string; total: number; count: number }> = {};
  let grandTotal = 0;

  for (const tx of txRows ?? []) {
    const month = tx.date.slice(0, 7);
    if (month < from || month > to) continue;
    const amount = Number(tx.amount);
    grandTotal += amount;
    const cat: any = tx.budget_categories;
    const key  = tx.category_id ?? "uncategorised";
    const name = cat?.name ?? "Uncategorised";
    const type = cat?.type ?? "other";
    if (!byCategory[key]) byCategory[key] = { name, type, total: 0, count: 0 };
    byCategory[key].total  += amount;
    byCategory[key].count  += 1;
  }

  const categories = Object.entries(byCategory)
    .map(([id, v]) => ({ id, ...v, pct: grandTotal > 0 ? Math.round((v.total / grandTotal) * 100) : 0 }))
    .sort((a, b) => b.total - a.total);

  return { categories, grandTotal };
}

// ── 3. Budget performance ─────────────────────────────────────────────

export async function getBudgetPerformance(userId: string, months = 12) {
  const from = monthsBack(months);
  const to   = currentMonth();
  const range = allMonthsInRange(from, to);

  const [{ data: categories }, { data: txRows }, { data: incomeRows }] = await Promise.all([
    supabase.from("budget_categories").select("*").eq("user_id", userId),
    supabase.from("transactions").select("amount, date, category_id").eq("user_id", userId),
    supabase.from("income").select("amount, month").eq("user_id", userId).gte("month", from).lte("month", to),
  ]);

  const totalBudgeted = (categories ?? []).reduce((s, c) => s + Number(c.budgeted_amount), 0);
  const totalIncome   = (incomeRows ?? []).reduce((s, r) => s + Number(r.amount), 0);
  const avgMonthlyIncome = range.length > 0 ? totalIncome / range.length : 0;

  // Actual spending per category
  const actualByCategory: Record<string, number> = {};
  for (const tx of txRows ?? []) {
    const month = tx.date.slice(0, 7);
    if (month < from || month > to) continue;
    const key = tx.category_id ?? "uncategorised";
    actualByCategory[key] = (actualByCategory[key] ?? 0) + Number(tx.amount);
  }

  const performance = (categories ?? []).map((c) => {
    const actual    = actualByCategory[c.id] ?? 0;
    const budgeted  = Number(c.budgeted_amount) * range.length; // total across period
    const variance  = budgeted - actual;
    return {
      id:       c.id,
      name:     c.name,
      type:     c.type,
      budgeted: Math.round(budgeted),
      actual:   Math.round(actual),
      variance: Math.round(variance),
      is_over:  actual > budgeted,
    };
  }).sort((a, b) => a.variance - b.variance); // worst first

  const totalActual = performance.reduce((s, c) => s + c.actual, 0);

  return {
    performance,
    summary: {
      total_budgeted:       Math.round(totalBudgeted * range.length),
      total_actual:         Math.round(totalActual),
      total_variance:       Math.round(totalBudgeted * range.length - totalActual),
      avg_monthly_income:   Math.round(avgMonthlyIncome),
      months:               range.length,
    },
  };
}

// ── 4. Savings progress ───────────────────────────────────────────────

export async function getSavingsProgress(userId: string) {
  const { data: goals } = await supabase
    .from("savings_goals")
    .select("*")
    .eq("user_id", userId)
    .order("created_at", { ascending: true });

  const list = (goals ?? []).map((g) => {
    const target  = Number(g.target_amount);
    const current = Number(g.current_amount);
    const pct     = target > 0 ? Math.min(Math.round((current / target) * 100), 100) : 0;
    let monthsLeft: number | null = null;
    if (g.target_date) {
      const diff = new Date(g.target_date).getTime() - Date.now();
      monthsLeft = Math.max(Math.ceil(diff / (1000 * 60 * 60 * 24 * 30)), 0);
    }
    return {
      id:           g.id,
      name:         g.name,
      target:       target,
      current:      current,
      remaining:    Math.max(target - current, 0),
      pct,
      is_completed: g.is_completed,
      target_date:  g.target_date,
      months_left:  monthsLeft,
    };
  });

  const totalTarget  = list.reduce((s, g) => s + g.target, 0);
  const totalCurrent = list.reduce((s, g) => s + g.current, 0);
  const completed    = list.filter((g) => g.is_completed).length;

  return {
    goals: list,
    summary: {
      total_target:  totalTarget,
      total_current: totalCurrent,
      overall_pct:   totalTarget > 0 ? Math.round((totalCurrent / totalTarget) * 100) : 0,
      completed,
      active:        list.length - completed,
    },
  };
}

// ── 5. Net worth snapshot (point-in-time from current data) ───────────

export async function getNetworthSnapshot(userId: string) {
  // We don't store historical net worth so we return a single current snapshot
  // plus a 12-month income/expense derived cash trend for context
  const trend = await getIncomeExpenseTrend(userId, 12);

  const [
    { data: assets },
    { data: liabilities },
    { data: savings },
    { data: investments },
    { data: pension },
  ] = await Promise.all([
    supabase.from("assets").select("value").eq("user_id", userId),
    supabase.from("liabilities").select("balance").eq("user_id", userId),
    supabase.from("savings_goals").select("current_amount").eq("user_id", userId),
    supabase.from("investments").select("current_value").eq("user_id", userId),
    supabase.from("pension_accounts").select("total_value").eq("user_id", userId),
  ]);

  const totalAssets =
    (assets ?? []).reduce((s, a) => s + Number(a.value), 0) +
    (savings ?? []).reduce((s, g) => s + Number(g.current_amount), 0) +
    (investments ?? []).reduce((s, i) => s + Number(i.current_value), 0) +
    (pension ?? []).reduce((s, p) => s + Number(p.total_value), 0);

  const totalLiabilities = (liabilities ?? []).reduce((s, l) => s + Number(l.balance), 0);
  const netWorth = totalAssets - totalLiabilities;

  return {
    net_worth:         Math.round(netWorth),
    total_assets:      Math.round(totalAssets),
    total_liabilities: Math.round(totalLiabilities),
    cash_trend:        trend.trend,
  };
}

// ── Full report (all sections combined) ──────────────────────────────

export async function getFullReport(userId: string, months = 12) {
  const [incomeExpense, spending, budget, savings, networth] = await Promise.all([
    getIncomeExpenseTrend(userId, months),
    getSpendingByCategory(userId, months),
    getBudgetPerformance(userId, months),
    getSavingsProgress(userId),
    getNetworthSnapshot(userId),
  ]);

  return { incomeExpense, spending, budget, savings, networth, generated_at: new Date().toISOString(), months };
}