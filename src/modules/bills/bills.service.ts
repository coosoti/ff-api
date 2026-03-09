import { supabase } from "../../config/database";

// ── Cycle key helpers ─────────────────────────────────────────────────

function cycleKey(cycle: string, date = new Date()): string {
  const y = date.getFullYear();
  const m = String(date.getMonth() + 1).padStart(2, "0");
  if (cycle === "weekly") {
    const start = new Date(date);
    start.setDate(date.getDate() - date.getDay());
    const wm = String(start.getMonth() + 1).padStart(2, "0");
    const wd = String(start.getDate()).padStart(2, "0");
    return `${y}-W${wm}${wd}`;
  }
  if (cycle === "quarterly") {
    const q = Math.ceil((date.getMonth() + 1) / 3);
    return `${y}-Q${q}`;
  }
  if (cycle === "annual") return `${y}`;
  return `${y}-${m}`; // monthly default
}

function nextDueDate(cycle: string, dueDay: number): string {
  const now = new Date();
  const d   = new Date();

  if (cycle === "weekly") {
    const daysUntil = (dueDay - now.getDay() + 7) % 7 || 7;
    d.setDate(now.getDate() + daysUntil);
    return d.toISOString().split("T")[0];
  }

  if (cycle === "monthly") {
    d.setDate(dueDay);
    if (d <= now) d.setMonth(d.getMonth() + 1);
    return d.toISOString().split("T")[0];
  }

  if (cycle === "quarterly") {
    const currentQ = Math.floor(now.getMonth() / 3);
    d.setMonth(currentQ * 3);
    d.setDate(dueDay);
    if (d <= now) d.setMonth(d.getMonth() + 3);
    return d.toISOString().split("T")[0];
  }

  if (cycle === "annual") {
    d.setMonth(0);
    d.setDate(dueDay);
    if (d <= now) d.setFullYear(d.getFullYear() + 1);
    return d.toISOString().split("T")[0];
  }

  return d.toISOString().split("T")[0];
}

// ── Bills CRUD ────────────────────────────────────────────────────────

export async function getBills(userId: string) {
  const { data: bills, error } = await supabase
    .from("bills")
    .select("*")
    .eq("user_id", userId)
    .eq("is_active", true)
    .order("due_day", { ascending: true });

  if (error) throw new Error(error.message);

  // Enrich each bill with current cycle paid status + next due date
  const now   = new Date();
  const enriched = await Promise.all((bills ?? []).map(async (bill) => {
    const key = cycleKey(bill.cycle, now);
    const { data: payment } = await supabase
      .from("bill_payments")
      .select("id, paid_at, amount_paid")
      .eq("bill_id", bill.id)
      .eq("cycle_key", key)
      .maybeSingle();

    return {
      ...bill,
      current_cycle_key: key,
      is_paid:           !!payment,
      paid_at:           payment?.paid_at ?? null,
      next_due_date:     nextDueDate(bill.cycle, bill.due_day),
    };
  }));

  return enriched;
}

export async function getBillById(userId: string, billId: string) {
  const { data, error } = await supabase
    .from("bills")
    .select("*")
    .eq("id", billId)
    .eq("user_id", userId)
    .single();

  if (error || !data) throw new Error("Bill not found");
  return data;
}

export async function createBill(
  userId: string,
  payload: {
    name: string; amount: number; category: string;
    cycle: string; due_day: number; notes?: string;
  }
) {
  const { data, error } = await supabase
    .from("bills")
    .insert({ user_id: userId, ...payload })
    .select()
    .single();

  if (error) throw new Error(error.message);
  return data;
}

export async function updateBill(
  userId: string,
  billId: string,
  fields: Partial<{
    name: string; amount: number; category: string;
    cycle: string; due_day: number; notes: string; is_active: boolean;
  }>
) {
  const { data, error } = await supabase
    .from("bills")
    .update(fields)
    .eq("id", billId)
    .eq("user_id", userId)
    .select()
    .single();

  if (error) throw new Error(error.message);
  if (!data) throw new Error("Bill not found");
  return data;
}

export async function deleteBill(userId: string, billId: string) {
  const { error } = await supabase
    .from("bills")
    .delete()
    .eq("id", billId)
    .eq("user_id", userId);

  if (error) throw new Error(error.message);
}

// ── Pay / Unpay ───────────────────────────────────────────────────────

export async function markPaid(userId: string, billId: string, notes?: string) {
  const bill = await getBillById(userId, billId);
  const key  = cycleKey(bill.cycle);

  // Upsert — idempotent
  const { data, error } = await supabase
    .from("bill_payments")
    .upsert(
      { bill_id: billId, user_id: userId, cycle_key: key, amount_paid: bill.amount, notes: notes ?? null },
      { onConflict: "bill_id,cycle_key" }
    )
    .select()
    .single();

  if (error) throw new Error(error.message);
  return data;
}

export async function markUnpaid(userId: string, billId: string) {
  const bill = await getBillById(userId, billId);
  const key  = cycleKey(bill.cycle);

  const { error } = await supabase
    .from("bill_payments")
    .delete()
    .eq("bill_id", billId)
    .eq("user_id", userId)
    .eq("cycle_key", key);

  if (error) throw new Error(error.message);
}

// ── Payment history ───────────────────────────────────────────────────

export async function getPaymentHistory(userId: string, billId: string) {
  const { data, error } = await supabase
    .from("bill_payments")
    .select("*")
    .eq("bill_id", billId)
    .eq("user_id", userId)
    .order("paid_at", { ascending: false });

  if (error) throw new Error(error.message);
  return data;
}

// ── Monthly summary (for budget integration) ──────────────────────────

export async function getBillsSummary(userId: string) {
  const bills = await getBills(userId);
  const now   = new Date();
  const month = `${now.getFullYear()}-${String(now.getMonth() + 1).padStart(2, "0")}`;

  // Bills active this month
  const monthlyBills = bills.filter((b) =>
    b.cycle === "monthly" ||
    b.cycle === "weekly"  ||
    (b.cycle === "quarterly" && cycleKey("quarterly", now) === b.current_cycle_key) ||
    (b.cycle === "annual"    && cycleKey("annual", now)    === b.current_cycle_key)
  );

  const totalDue    = monthlyBills.reduce((s, b) => s + Number(b.amount), 0);
  const totalPaid   = monthlyBills.filter((b) => b.is_paid).reduce((s, b) => s + Number(b.amount), 0);
  const totalUnpaid = totalDue - totalPaid;
  const overdue     = bills.filter((b) => !b.is_paid && new Date(b.next_due_date) < now);

  return {
    month,
    total_due:    totalDue,
    total_paid:   totalPaid,
    total_unpaid: totalUnpaid,
    overdue_count: overdue.length,
    bills:         bills,
  };
}