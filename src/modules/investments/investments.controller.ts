import { Response } from "express";
import { z } from "zod";
import { AuthRequest } from "../../middleware/auth.middleware";
import {
  getInvestments,
  getInvestmentById,
  createInvestment,
  updateInvestment,
  deleteInvestment,
  getPortfolioSummary,
} from "./investments.service";

const INVESTMENT_TYPES = ["stocks", "bonds", "mmf", "real_estate", "crypto", "other"] as const;

const InvestmentSchema = z.object({
  name:           z.string().min(1),
  type:           z.enum(INVESTMENT_TYPES).default("other"),
  institution:    z.string().optional(),
  units:          z.number().positive().optional(),
  purchase_price: z.number().min(0).optional(),
  current_price:  z.number().min(0).optional(),
  total_invested: z.number().min(0),
  current_value:  z.number().min(0),
  purchase_date:  z.string().regex(/^\d{4}-\d{2}-\d{2}$/).optional(),
  notes:          z.string().optional(),
});

// GET /investments/portfolio
export async function getPortfolioHandler(req: AuthRequest, res: Response) {
  try {
    const data = await getPortfolioSummary(req.user!.id);
    return res.json({ success: true, data });
  } catch (err: unknown) {
    return res.status(500).json({ success: false, error: (err as Error).message });
  }
}

// GET /investments
export async function getInvestmentsHandler(req: AuthRequest, res: Response) {
  try {
    const data = await getInvestments(req.user!.id);
    return res.json({ success: true, data });
  } catch (err: unknown) {
    return res.status(500).json({ success: false, error: (err as Error).message });
  }
}

// GET /investments/:id
export async function getInvestmentByIdHandler(req: AuthRequest, res: Response) {
  try {
    const data = await getInvestmentById(req.user!.id, req.params.id);
    return res.json({ success: true, data });
  } catch (err: unknown) {
    return res.status(404).json({ success: false, error: (err as Error).message });
  }
}

// POST /investments
export async function createInvestmentHandler(req: AuthRequest, res: Response) {
  const parsed = InvestmentSchema.safeParse(req.body);
  if (!parsed.success) {
    return res.status(400).json({ success: false, error: parsed.error.errors[0].message });
  }
  try {
    const data = await createInvestment(req.user!.id, parsed.data);
    return res.status(201).json({ success: true, data });
  } catch (err: unknown) {
    return res.status(400).json({ success: false, error: (err as Error).message });
  }
}

// PUT /investments/:id
export async function updateInvestmentHandler(req: AuthRequest, res: Response) {
  const parsed = InvestmentSchema.partial().safeParse(req.body);
  if (!parsed.success) {
    return res.status(400).json({ success: false, error: parsed.error.errors[0].message });
  }
  try {
    const data = await updateInvestment(req.user!.id, req.params.id, parsed.data);
    return res.json({ success: true, data });
  } catch (err: unknown) {
    return res.status(400).json({ success: false, error: (err as Error).message });
  }
}

// DELETE /investments/:id
export async function deleteInvestmentHandler(req: AuthRequest, res: Response) {
  try {
    await deleteInvestment(req.user!.id, req.params.id);
    return res.json({ success: true, message: "Investment deleted" });
  } catch (err: unknown) {
    return res.status(400).json({ success: false, error: (err as Error).message });
  }
}