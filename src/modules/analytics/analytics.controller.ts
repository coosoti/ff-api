import { Response } from "express";
import { AuthRequest } from "../../middleware/auth.middleware";
import {
  getIncomeExpenseTrend,
  getSpendingByCategory,
  getBudgetPerformance,
  getSavingsProgress,
  getNetworthSnapshot,
  getFullReport,
} from "./analytics.service";

function parseMonths(query: unknown): number {
  const m = Number(query);
  return [3, 6, 12].includes(m) ? m : 12;
}

export async function getIncomeExpenseHandler(req: AuthRequest, res: Response) {
  try {
    const data = await getIncomeExpenseTrend(req.user!.id, parseMonths(req.query.months));
    return res.json({ success: true, data });
  } catch (err: unknown) {
    return res.status(500).json({ success: false, error: (err as Error).message });
  }
}

export async function getSpendingHandler(req: AuthRequest, res: Response) {
  try {
    const data = await getSpendingByCategory(req.user!.id, parseMonths(req.query.months));
    return res.json({ success: true, data });
  } catch (err: unknown) {
    return res.status(500).json({ success: false, error: (err as Error).message });
  }
}

export async function getBudgetHandler(req: AuthRequest, res: Response) {
  try {
    const data = await getBudgetPerformance(req.user!.id, parseMonths(req.query.months));
    return res.json({ success: true, data });
  } catch (err: unknown) {
    return res.status(500).json({ success: false, error: (err as Error).message });
  }
}

export async function getSavingsHandler(req: AuthRequest, res: Response) {
  try {
    const data = await getSavingsProgress(req.user!.id);
    return res.json({ success: true, data });
  } catch (err: unknown) {
    return res.status(500).json({ success: false, error: (err as Error).message });
  }
}

export async function getNetworthHandler(req: AuthRequest, res: Response) {
  try {
    const data = await getNetworthSnapshot(req.user!.id);
    return res.json({ success: true, data });
  } catch (err: unknown) {
    return res.status(500).json({ success: false, error: (err as Error).message });
  }
}

export async function getFullReportHandler(req: AuthRequest, res: Response) {
  try {
    const data = await getFullReport(req.user!.id, parseMonths(req.query.months));
    return res.json({ success: true, data });
  } catch (err: unknown) {
    return res.status(500).json({ success: false, error: (err as Error).message });
  }
}