import { Response } from "express";
import { z } from "zod";
import { AuthRequest } from "../../middleware/auth.middleware";
import { io } from "../../server";
import {
  createTransaction,
  getTransactions,
  getTransactionById,
  updateTransaction,
  deleteTransaction,
} from "./transactions.service";

const TransactionSchema = z.object({
  category_id:  z.string().uuid().optional(),
  amount:       z.number().positive(),
  type:         z.enum(["income", "expense"]),
  date:         z.string().regex(/^\d{4}-\d{2}-\d{2}$/, "date must be YYYY-MM-DD"),
  notes:        z.string().optional(),
});

const UpdateTransactionSchema = TransactionSchema.partial();

// GET /transactions?month=2026-03
export async function getTransactionsHandler(req: AuthRequest, res: Response) {
  const month = req.query.month as string | undefined;

  if (month && !/^\d{4}-\d{2}$/.test(month)) {
    return res.status(400).json({ success: false, error: "month must be YYYY-MM" });
  }

  try {
    const data = await getTransactions(req.user!.id, month);
    return res.json({ success: true, data });
  } catch (err: unknown) {
    return res.status(500).json({ success: false, error: (err as Error).message });
  }
}

// POST /transactions — US-009
export async function createTransactionHandler(req: AuthRequest, res: Response) {
  const parsed = TransactionSchema.safeParse(req.body);
  if (!parsed.success) {
    return res.status(400).json({ success: false, error: parsed.error.errors[0].message });
  }

  try {
    const data = await createTransaction(req.user!.id, parsed.data);

    // Real-time broadcast to all of this user's open sessions (US-009)
    io.to(req.user!.id).emit("transaction:created", data);

    return res.status(201).json({ success: true, data });
  } catch (err: unknown) {
    return res.status(400).json({ success: false, error: (err as Error).message });
  }
}

// GET /transactions/:id
export async function getTransactionByIdHandler(req: AuthRequest, res: Response) {
  try {
    const data = await getTransactionById(req.user!.id, req.params.id);
    return res.json({ success: true, data });
  } catch (err: unknown) {
    return res.status(404).json({ success: false, error: (err as Error).message });
  }
}

// PUT /transactions/:id — US-010
export async function updateTransactionHandler(req: AuthRequest, res: Response) {
  const parsed = UpdateTransactionSchema.safeParse(req.body);
  if (!parsed.success) {
    return res.status(400).json({ success: false, error: parsed.error.errors[0].message });
  }

  try {
    const data = await updateTransaction(req.user!.id, req.params.id, parsed.data);

    // Broadcast update
    io.to(req.user!.id).emit("transaction:updated", data);

    return res.json({ success: true, data });
  } catch (err: unknown) {
    return res.status(400).json({ success: false, error: (err as Error).message });
  }
}

// DELETE /transactions/:id — US-011
export async function deleteTransactionHandler(req: AuthRequest, res: Response) {
  try {
    await deleteTransaction(req.user!.id, req.params.id);

    // Broadcast deletion
    io.to(req.user!.id).emit("transaction:deleted", { id: req.params.id });

    return res.json({ success: true, message: "Transaction deleted" });
  } catch (err: unknown) {
    return res.status(400).json({ success: false, error: (err as Error).message });
  }
}