import { supabase } from "../../config/database";

// ── US-009: Create a transaction ──────────────────────────────────────

export async function createTransaction(
  userId: string,
  payload: {
    category_id?: string;
    amount: number;
    type: "expense";
    date: string;
    notes?: string;
  }
) {
  const { data, error } = await supabase
    .from("transactions")
    .insert({ user_id: userId, ...payload })
    .select(`
      *,
      category:budget_categories(id, name, type)
    `)
    .single();

  if (error) throw new Error(error.message);
  return data;
}

// ── US-010: Get transactions by month ─────────────────────────────────

export async function getTransactionsByMonth(userId: string, month: string) {
  // month format: "2026-03"
  const startDate = `${month}-01`;
  const endDate = new Date(new Date(startDate).setMonth(new Date(startDate).getMonth() + 1))
    .toISOString()
    .split("T")[0];

  const { data, error } = await supabase
    .from("transactions")
    .select(`
      *,
      category:budget_categories(id, name, type)
    `)
    .eq("user_id", userId)
    .gte("date", startDate)
    .lt("date", endDate)
    .order("date", { ascending: false })
    .order("created_at", { ascending: false });

  if (error) throw new Error(error.message);
  return data;
}

// ── US-010: Get a single transaction ──────────────────────────────────

export async function getTransactionById(userId: string, transactionId: string) {
  const { data, error } = await supabase
    .from("transactions")
    .select(`
      *,
      category:budget_categories(id, name, type)
    `)
    .eq("id", transactionId)
    .eq("user_id", userId)
    .single();

  if (error || !data) throw new Error("Transaction not found");
  return data;
}

// ── US-010: Update a transaction ──────────────────────────────────────

export async function updateTransaction(
  userId: string,
  transactionId: string,
  fields: {
    category_id?: string;
    amount?: number;
    type?: "income" | "expense";
    date?: string;
    notes?: string;
  }
) {
  const { data, error } = await supabase
    .from("transactions")
    .update(fields)
    .eq("id", transactionId)
    .eq("user_id", userId)
    .select(`
      *,
      category:budget_categories(id, name, type)
    `)
    .single();

  if (error) throw new Error(error.message);
  if (!data) throw new Error("Transaction not found");
  return data;
}

// ── US-011: Delete a transaction ──────────────────────────────────────

export async function deleteTransaction(userId: string, transactionId: string) {
  const { error } = await supabase
    .from("transactions")
    .delete()
    .eq("id", transactionId)
    .eq("user_id", userId);

  if (error) throw new Error(error.message);
}

// ── US-010: Get all transactions (with optional month filter) ─────────

export async function getTransactions(userId: string, month?: string) {
  if (month) return getTransactionsByMonth(userId, month);

  const { data, error } = await supabase
    .from("transactions")
    .select(`
      *,
      category:budget_categories(id, name, type)
    `)
    .eq("user_id", userId)
    .order("date", { ascending: false })
    .order("created_at", { ascending: false })
    .limit(100);

  if (error) throw new Error(error.message);
  return data;
}