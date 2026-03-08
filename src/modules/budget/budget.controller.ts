import { Response } from "express";
import { z } from "zod";
import { AuthRequest } from "../../middleware/auth.middleware";
import {
  getCategories,
  createCategory,
  updateCategory,
  deleteCategory,
  recalculateBudget,
  getBudgetSummary,
} from "./budget.service";

const CategorySchema = z.object({
  name:             z.string().min(1),
  type:             z.enum(["needs", "wants", "savings"]),
  budgeted_amount:  z.number().min(0),
});

const UpdateCategorySchema = CategorySchema.partial();

const RecalculateSchema = z.object({
  monthly_income: z.number().positive(),
});

// GET /budget/categories
export async function getCategoriesHandler(req: AuthRequest, res: Response) {
  try {
    const data = await getCategories(req.user!.id);
    return res.json({ success: true, data });
  } catch (err: unknown) {
    return res.status(500).json({ success: false, error: (err as Error).message });
  }
}

// POST /budget/categories
export async function createCategoryHandler(req: AuthRequest, res: Response) {
  const parsed = CategorySchema.safeParse(req.body);
  if (!parsed.success) {
    return res.status(400).json({ success: false, error: parsed.error.errors[0].message });
  }

  try {
    const { name, type, budgeted_amount } = parsed.data;
    const data = await createCategory(req.user!.id, name, type, budgeted_amount);
    return res.status(201).json({ success: true, data });
  } catch (err: unknown) {
    return res.status(400).json({ success: false, error: (err as Error).message });
  }
}

// PUT /budget/categories/:id
export async function updateCategoryHandler(req: AuthRequest, res: Response) {
  const parsed = UpdateCategorySchema.safeParse(req.body);
  if (!parsed.success) {
    return res.status(400).json({ success: false, error: parsed.error.errors[0].message });
  }

  try {
    const data = await updateCategory(req.user!.id, req.params.id, parsed.data);
    return res.json({ success: true, data });
  } catch (err: unknown) {
    return res.status(400).json({ success: false, error: (err as Error).message });
  }
}

// DELETE /budget/categories/:id
export async function deleteCategoryHandler(req: AuthRequest, res: Response) {
  try {
    await deleteCategory(req.user!.id, req.params.id);
    return res.json({ success: true, message: "Category deleted" });
  } catch (err: unknown) {
    return res.status(400).json({ success: false, error: (err as Error).message });
  }
}

// POST /budget/recalculate
export async function recalculateHandler(req: AuthRequest, res: Response) {
  const parsed = RecalculateSchema.safeParse(req.body);
  if (!parsed.success) {
    return res.status(400).json({ success: false, error: "monthly_income must be a positive number" });
  }

  try {
    const data = await recalculateBudget(req.user!.id, parsed.data.monthly_income);
    return res.json({ success: true, data });
  } catch (err: unknown) {
    return res.status(400).json({ success: false, error: (err as Error).message });
  }
}

// GET /budget/summary?month=2026-03
export async function getSummaryHandler(req: AuthRequest, res: Response) {
  const month = (req.query.month as string) || new Date().toISOString().slice(0, 7);

  if (!/^\d{4}-\d{2}$/.test(month)) {
    return res.status(400).json({ success: false, error: "month must be in format YYYY-MM" });
  }

  try {
    const data = await getBudgetSummary(req.user!.id, month);
    return res.json({ success: true, data });
  } catch (err: unknown) {
    return res.status(500).json({ success: false, error: (err as Error).message });
  }
}