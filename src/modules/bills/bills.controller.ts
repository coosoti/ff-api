import { Response } from "express";
import { z } from "zod";
import { AuthRequest } from "../../middleware/auth.middleware";
import {
  getBills, getBillById, createBill, updateBill, deleteBill,
  markPaid, markUnpaid, getPaymentHistory, getBillsSummary,
} from "./bills.service";

const CATEGORIES = ["rent", "utilities", "subscription", "insurance", "loan", "other"] as const;
const CYCLES     = ["weekly", "monthly", "quarterly", "annual"] as const;

const BillSchema = z.object({
  name:     z.string().min(1),
  amount:   z.number().positive(),
  category: z.enum(CATEGORIES).default("other"),
  cycle:    z.enum(CYCLES).default("monthly"),
  due_day:  z.number().int().min(1).max(31),
  notes:    z.string().optional(),
});

export async function getBillsHandler(req: AuthRequest, res: Response) {
  try {
    const data = await getBills(req.user!.id);
    return res.json({ success: true, data });
  } catch (err: unknown) {
    return res.status(500).json({ success: false, error: (err as Error).message });
  }
}

export async function getBillsSummaryHandler(req: AuthRequest, res: Response) {
  try {
    const data = await getBillsSummary(req.user!.id);
    return res.json({ success: true, data });
  } catch (err: unknown) {
    return res.status(500).json({ success: false, error: (err as Error).message });
  }
}

export async function getBillByIdHandler(req: AuthRequest, res: Response) {
  try {
    const data = await getBillById(req.user!.id, req.params.id);
    return res.json({ success: true, data });
  } catch (err: unknown) {
    return res.status(404).json({ success: false, error: (err as Error).message });
  }
}

export async function createBillHandler(req: AuthRequest, res: Response) {
  const parsed = BillSchema.safeParse(req.body);
  if (!parsed.success) {
    return res.status(400).json({ success: false, error: parsed.error.errors[0].message });
  }
  try {
    const data = await createBill(req.user!.id, parsed.data);
    return res.status(201).json({ success: true, data });
  } catch (err: unknown) {
    return res.status(400).json({ success: false, error: (err as Error).message });
  }
}

export async function updateBillHandler(req: AuthRequest, res: Response) {
  const parsed = BillSchema.partial().safeParse(req.body);
  if (!parsed.success) {
    return res.status(400).json({ success: false, error: parsed.error.errors[0].message });
  }
  try {
    const data = await updateBill(req.user!.id, req.params.id, parsed.data);
    return res.json({ success: true, data });
  } catch (err: unknown) {
    return res.status(400).json({ success: false, error: (err as Error).message });
  }
}

export async function deleteBillHandler(req: AuthRequest, res: Response) {
  try {
    await deleteBill(req.user!.id, req.params.id);
    return res.json({ success: true, message: "Bill deleted" });
  } catch (err: unknown) {
    return res.status(400).json({ success: false, error: (err as Error).message });
  }
}

export async function markPaidHandler(req: AuthRequest, res: Response) {
  try {
    const data = await markPaid(req.user!.id, req.params.id, req.body.notes);
    return res.json({ success: true, data });
  } catch (err: unknown) {
    return res.status(400).json({ success: false, error: (err as Error).message });
  }
}

export async function markUnpaidHandler(req: AuthRequest, res: Response) {
  try {
    await markUnpaid(req.user!.id, req.params.id);
    return res.json({ success: true, message: "Payment removed for current cycle" });
  } catch (err: unknown) {
    return res.status(400).json({ success: false, error: (err as Error).message });
  }
}

export async function getPaymentHistoryHandler(req: AuthRequest, res: Response) {
  try {
    const data = await getPaymentHistory(req.user!.id, req.params.id);
    return res.json({ success: true, data });
  } catch (err: unknown) {
    return res.status(500).json({ success: false, error: (err as Error).message });
  }
}