import { supabase } from "../../config/database";

// ── Get all savings goals ─────────────────────────────────────────────

export async function getSavingsGoals(userId: string) {
  const { data, error } = await supabase
    .from("savings_goals")
    .select("*")
    .eq("user_id", userId)
    .order("is_completed", { ascending: true })
    .order("created_at", { ascending: false });

  if (error) throw new Error(error.message);
  return data;
}

// ── Get a single savings goal ─────────────────────────────────────────

export async function getSavingsGoalById(userId: string, goalId: string) {
  const { data, error } = await supabase
    .from("savings_goals")
    .select("*")
    .eq("id", goalId)
    .eq("user_id", userId)
    .single();

  if (error || !data) throw new Error("Savings goal not found");
  return data;
}

// ── Create a savings goal ─────────────────────────────────────────────

export async function createSavingsGoal(
  userId: string,
  payload: {
    name: string;
    target_amount: number;
    current_amount?: number;
    target_date?: string;
    notes?: string;
  }
) {
  const { data, error } = await supabase
    .from("savings_goals")
    .insert({ user_id: userId, ...payload })
    .select()
    .single();

  if (error) throw new Error(error.message);
  return data;
}

// ── Update a savings goal ─────────────────────────────────────────────

export async function updateSavingsGoal(
  userId: string,
  goalId: string,
  fields: Partial<{
    name: string;
    target_amount: number;
    current_amount: number;
    target_date: string;
    notes: string;
    is_completed: boolean;
  }>
) {
  const { data, error } = await supabase
    .from("savings_goals")
    .update(fields)
    .eq("id", goalId)
    .eq("user_id", userId)
    .select()
    .single();

  if (error) throw new Error(error.message);
  if (!data) throw new Error("Savings goal not found");
  return data;
}

// ── Top up a savings goal (add funds) ────────────────────────────────

export async function topUpSavingsGoal(userId: string, goalId: string, amount: number) {
  // Fetch current amount first
  const goal = await getSavingsGoalById(userId, goalId);
  const newAmount = Number(goal.current_amount) + amount;
  const isCompleted = newAmount >= Number(goal.target_amount);

  return updateSavingsGoal(userId, goalId, {
    current_amount: newAmount,
    is_completed: isCompleted,
  });
}

// ── Delete a savings goal ─────────────────────────────────────────────

export async function deleteSavingsGoal(userId: string, goalId: string) {
  const { error } = await supabase
    .from("savings_goals")
    .delete()
    .eq("id", goalId)
    .eq("user_id", userId);

  if (error) throw new Error(error.message);
}