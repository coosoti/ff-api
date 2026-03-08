import { Response } from "express";
import { z } from "zod";
import { AuthRequest } from "../../middleware/auth.middleware";
import {
  getSavingsGoals,
  getSavingsGoalById,
  createSavingsGoal,
  updateSavingsGoal,
  topUpSavingsGoal,
  deleteSavingsGoal,
} from "./savings.service";

const SavingsGoalSchema = z.object({
  name:           z.string().min(1),
  target_amount:  z.number().positive(),
  current_amount: z.number().min(0).optional(),
  target_date:    z.string().regex(/^\d{4}-\d{2}-\d{2}$/, "target_date must be YYYY-MM-DD").optional(),
  notes:          z.string().optional(),
});

const UpdateSavingsGoalSchema = SavingsGoalSchema.partial().extend({
  is_completed: z.boolean().optional(),
});

const TopUpSchema = z.object({
  amount: z.number().positive(),
});

// GET /savings
export async function getSavingsGoalsHandler(req: AuthRequest, res: Response) {
  try {
    const data = await getSavingsGoals(req.user!.id);
    return res.json({ success: true, data });
  } catch (err: unknown) {
    return res.status(500).json({ success: false, error: (err as Error).message });
  }
}

// GET /savings/:id
export async function getSavingsGoalByIdHandler(req: AuthRequest, res: Response) {
  try {
    const data = await getSavingsGoalById(req.user!.id, req.params.id);
    return res.json({ success: true, data });
  } catch (err: unknown) {
    return res.status(404).json({ success: false, error: (err as Error).message });
  }
}

// POST /savings
export async function createSavingsGoalHandler(req: AuthRequest, res: Response) {
  const parsed = SavingsGoalSchema.safeParse(req.body);
  if (!parsed.success) {
    return res.status(400).json({ success: false, error: parsed.error.errors[0].message });
  }

  try {
    const data = await createSavingsGoal(req.user!.id, parsed.data);
    return res.status(201).json({ success: true, data });
  } catch (err: unknown) {
    return res.status(400).json({ success: false, error: (err as Error).message });
  }
}

// PUT /savings/:id
export async function updateSavingsGoalHandler(req: AuthRequest, res: Response) {
  const parsed = UpdateSavingsGoalSchema.safeParse(req.body);
  if (!parsed.success) {
    return res.status(400).json({ success: false, error: parsed.error.errors[0].message });
  }

  try {
    const data = await updateSavingsGoal(req.user!.id, req.params.id, parsed.data);
    return res.json({ success: true, data });
  } catch (err: unknown) {
    return res.status(400).json({ success: false, error: (err as Error).message });
  }
}

// POST /savings/:id/topup
export async function topUpSavingsGoalHandler(req: AuthRequest, res: Response) {
  const parsed = TopUpSchema.safeParse(req.body);
  if (!parsed.success) {
    return res.status(400).json({ success: false, error: parsed.error.errors[0].message });
  }

  try {
    const data = await topUpSavingsGoal(req.user!.id, req.params.id, parsed.data.amount);
    return res.json({ success: true, data });
  } catch (err: unknown) {
    return res.status(400).json({ success: false, error: (err as Error).message });
  }
}

// DELETE /savings/:id
export async function deleteSavingsGoalHandler(req: AuthRequest, res: Response) {
  try {
    await deleteSavingsGoal(req.user!.id, req.params.id);
    return res.json({ success: true, message: "Savings goal deleted" });
  } catch (err: unknown) {
    return res.status(400).json({ success: false, error: (err as Error).message });
  }
}