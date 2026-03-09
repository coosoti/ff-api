import { Response } from "express";
import { z } from "zod";
import { AuthRequest } from "../../middleware/auth.middleware";
import {
  getAccounts, getAccountById, createAccount, updateAccount, deleteAccount,
  getFunds, upsertFunds,
  getWithdrawals, createWithdrawal, deleteWithdrawal,
  getProjection,
} from "./pension.service";

// ── Schemas ───────────────────────────────────────────────────────────

const AccountSchema = z.object({
  provider:       z.string().min(1),
  scheme_name:    z.string().min(1),
  total_value:    z.number().min(0),
  retirement_age: z.number().int().min(50).max(75).default(60),
  date_of_birth:  z.string().regex(/^\d{4}-\d{2}-\d{2}$/).optional(),
  notes:          z.string().optional(),
});

const FundsSchema = z.object({
  funds: z.array(z.object({
    name:           z.string().min(1),
    allocation_pct: z.number().min(0).max(100),
    current_value:  z.number().min(0),
  })).min(1),
});

const WithdrawalSchema = z.object({
  amount: z.number().positive(),
  reason: z.string().optional(),
  date:   z.string().regex(/^\d{4}-\d{2}-\d{2}/),
  notes:  z.string().optional(),
});

// ── Accounts ──────────────────────────────────────────────────────────

export async function getAccountsHandler(req: AuthRequest, res: Response) {
  try {
    const data = await getAccounts(req.user!.id);
    return res.json({ success: true, data });
  } catch (err: unknown) {
    return res.status(500).json({ success: false, error: (err as Error).message });
  }
}

export async function getAccountByIdHandler(req: AuthRequest, res: Response) {
  try {
    const data = await getAccountById(req.user!.id, req.params.accountId);
    return res.json({ success: true, data });
  } catch (err: unknown) {
    return res.status(404).json({ success: false, error: (err as Error).message });
  }
}

export async function createAccountHandler(req: AuthRequest, res: Response) {
  const parsed = AccountSchema.safeParse(req.body);
  if (!parsed.success) {
    return res.status(400).json({ success: false, error: parsed.error.errors[0].message });
  }
  try {
    const data = await createAccount(req.user!.id, parsed.data);
    return res.status(201).json({ success: true, data });
  } catch (err: unknown) {
    return res.status(400).json({ success: false, error: (err as Error).message });
  }
}

export async function updateAccountHandler(req: AuthRequest, res: Response) {
  const parsed = AccountSchema.partial().safeParse(req.body);
  if (!parsed.success) {
    return res.status(400).json({ success: false, error: parsed.error.errors[0].message });
  }
  try {
    const data = await updateAccount(req.user!.id, req.params.accountId, parsed.data);
    return res.json({ success: true, data });
  } catch (err: unknown) {
    return res.status(400).json({ success: false, error: (err as Error).message });
  }
}

export async function deleteAccountHandler(req: AuthRequest, res: Response) {
  try {
    await deleteAccount(req.user!.id, req.params.accountId);
    return res.json({ success: true, message: "Pension account deleted" });
  } catch (err: unknown) {
    return res.status(400).json({ success: false, error: (err as Error).message });
  }
}

// ── Funds ─────────────────────────────────────────────────────────────

export async function getFundsHandler(req: AuthRequest, res: Response) {
  try {
    const data = await getFunds(req.user!.id, req.params.accountId);
    return res.json({ success: true, data });
  } catch (err: unknown) {
    return res.status(500).json({ success: false, error: (err as Error).message });
  }
}

export async function upsertFundsHandler(req: AuthRequest, res: Response) {
  const parsed = FundsSchema.safeParse(req.body);
  if (!parsed.success) {
    return res.status(400).json({ success: false, error: parsed.error.errors[0].message });
  }
  try {
    const data = await upsertFunds(req.user!.id, req.params.accountId, parsed.data.funds);
    return res.json({ success: true, data });
  } catch (err: unknown) {
    return res.status(400).json({ success: false, error: (err as Error).message });
  }
}

// ── Withdrawals ───────────────────────────────────────────────────────

export async function getWithdrawalsHandler(req: AuthRequest, res: Response) {
  try {
    const data = await getWithdrawals(req.user!.id, req.params.accountId);
    return res.json({ success: true, data });
  } catch (err: unknown) {
    return res.status(500).json({ success: false, error: (err as Error).message });
  }
}

export async function createWithdrawalHandler(req: AuthRequest, res: Response) {
  const parsed = WithdrawalSchema.safeParse(req.body);
  if (!parsed.success) {
    return res.status(400).json({ success: false, error: parsed.error.errors[0].message });
  }
  try {
    const data = await createWithdrawal(req.user!.id, req.params.accountId, parsed.data);
    return res.status(201).json({ success: true, data });
  } catch (err: unknown) {
    return res.status(400).json({ success: false, error: (err as Error).message });
  }
}

export async function deleteWithdrawalHandler(req: AuthRequest, res: Response) {
  try {
    await deleteWithdrawal(req.user!.id, req.params.withdrawalId);
    return res.json({ success: true, message: "Withdrawal deleted and amount restored" });
  } catch (err: unknown) {
    return res.status(400).json({ success: false, error: (err as Error).message });
  }
}

// ── Projection ────────────────────────────────────────────────────────

export async function getProjectionHandler(req: AuthRequest, res: Response) {
  try {
    const data = await getProjection(req.user!.id, req.params.accountId);
    return res.json({ success: true, data });
  } catch (err: unknown) {
    return res.status(500).json({ success: false, error: (err as Error).message });
  }
}