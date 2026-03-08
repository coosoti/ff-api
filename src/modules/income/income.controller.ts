import { Response } from "express";
import { z } from "zod";
import { AuthRequest } from "../../middleware/auth.middleware";
import {
  getIncomeByMonth,
  getMonthlyTotal,
  createIncome,
  updateIncome,
  deleteIncome,
} from "./income.service";

const IncomeSchema = z.object({
  amount:  z.number().positive(),
  source:  z.string().min(1),
  month:   z.string().regex(/^\d{4}-\d{2}$/, "month must be YYYY-MM"),
  notes:   z.string().optional(),
});

const UpdateIncomeSchema = IncomeSchema.omit({ month: true }).partial();

// GET /income?month=2026-03
export async function getIncomeHandler(req: AuthRequest, res: Response) {
  const month = (req.query.month as string) || new Date().toISOString().slice(0, 7);

  if (!/^\d{4}-\d{2}$/.test(month)) {
    return res.status(400).json({ success: false, error: "month must be YYYY-MM" });
  }

  try {
    const entries = await getIncomeByMonth(req.user!.id, month);
    const total   = await getMonthlyTotal(req.user!.id, month);
    return res.json({ success: true, data: { entries, total, month } });
  } catch (err: unknown) {
    return res.status(500).json({ success: false, error: (err as Error).message });
  }
}

// POST /income
export async function createIncomeHandler(req: AuthRequest, res: Response) {
  const parsed = IncomeSchema.safeParse(req.body);
  if (!parsed.success) {
    return res.status(400).json({ success: false, error: parsed.error.errors[0].message });
  }

  try {
    const data = await createIncome(req.user!.id, parsed.data);
    return res.status(201).json({ success: true, data });
  } catch (err: unknown) {
    return res.status(400).json({ success: false, error: (err as Error).message });
  }
}

// PUT /income/:id
export async function updateIncomeHandler(req: AuthRequest, res: Response) {
  const parsed = UpdateIncomeSchema.safeParse(req.body);
  if (!parsed.success) {
    return res.status(400).json({ success: false, error: parsed.error.errors[0].message });
  }

  try {
    const data = await updateIncome(req.user!.id, req.params.id, parsed.data);
    return res.json({ success: true, data });
  } catch (err: unknown) {
    return res.status(400).json({ success: false, error: (err as Error).message });
  }
}

// DELETE /income/:id
export async function deleteIncomeHandler(req: AuthRequest, res: Response) {
  try {
    await deleteIncome(req.user!.id, req.params.id);
    return res.json({ success: true, message: "Income entry deleted" });
  } catch (err: unknown) {
    return res.status(400).json({ success: false, error: (err as Error).message });
  }
}