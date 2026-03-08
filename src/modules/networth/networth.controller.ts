import { Response } from "express";
import { z } from "zod";
import { AuthRequest } from "../../middleware/auth.middleware";
import {
  getNetWorthSummary,
  getAssets, createAsset, updateAsset, deleteAsset,
  getLiabilities, createLiability, updateLiability, deleteLiability,
} from "./networth.service";

const ASSET_CATEGORIES     = ["property", "vehicle", "investment", "other"] as const;
const LIABILITY_CATEGORIES = ["loan", "mortgage", "credit_card", "other"] as const;

const AssetSchema = z.object({
  name:     z.string().min(1),
  category: z.enum(ASSET_CATEGORIES).default("other"),
  value:    z.number().min(0),
  notes:    z.string().optional(),
});

const LiabilitySchema = z.object({
  name:          z.string().min(1),
  category:      z.enum(LIABILITY_CATEGORIES).default("other"),
  balance:       z.number().min(0),
  interest_rate: z.number().min(0).max(100).optional(),
  notes:         z.string().optional(),
});

// GET /networth — full summary
export async function getNetWorthHandler(req: AuthRequest, res: Response) {
  try {
    const data = await getNetWorthSummary(req.user!.id);
    return res.json({ success: true, data });
  } catch (err: unknown) {
    return res.status(500).json({ success: false, error: (err as Error).message });
  }
}

// ── Assets ────────────────────────────────────────────────────────────

export async function getAssetsHandler(req: AuthRequest, res: Response) {
  try {
    const data = await getAssets(req.user!.id);
    return res.json({ success: true, data });
  } catch (err: unknown) {
    return res.status(500).json({ success: false, error: (err as Error).message });
  }
}

export async function createAssetHandler(req: AuthRequest, res: Response) {
  const parsed = AssetSchema.safeParse(req.body);
  if (!parsed.success) {
    return res.status(400).json({ success: false, error: parsed.error.errors[0].message });
  }
  try {
    const data = await createAsset(req.user!.id, parsed.data);
    return res.status(201).json({ success: true, data });
  } catch (err: unknown) {
    return res.status(400).json({ success: false, error: (err as Error).message });
  }
}

export async function updateAssetHandler(req: AuthRequest, res: Response) {
  const parsed = AssetSchema.partial().safeParse(req.body);
  if (!parsed.success) {
    return res.status(400).json({ success: false, error: parsed.error.errors[0].message });
  }
  try {
    const data = await updateAsset(req.user!.id, req.params.id, parsed.data);
    return res.json({ success: true, data });
  } catch (err: unknown) {
    return res.status(400).json({ success: false, error: (err as Error).message });
  }
}

export async function deleteAssetHandler(req: AuthRequest, res: Response) {
  try {
    await deleteAsset(req.user!.id, req.params.id);
    return res.json({ success: true, message: "Asset deleted" });
  } catch (err: unknown) {
    return res.status(400).json({ success: false, error: (err as Error).message });
  }
}

// ── Liabilities ───────────────────────────────────────────────────────

export async function getLiabilitiesHandler(req: AuthRequest, res: Response) {
  try {
    const data = await getLiabilities(req.user!.id);
    return res.json({ success: true, data });
  } catch (err: unknown) {
    return res.status(500).json({ success: false, error: (err as Error).message });
  }
}

export async function createLiabilityHandler(req: AuthRequest, res: Response) {
  const parsed = LiabilitySchema.safeParse(req.body);
  if (!parsed.success) {
    return res.status(400).json({ success: false, error: parsed.error.errors[0].message });
  }
  try {
    const data = await createLiability(req.user!.id, parsed.data);
    return res.status(201).json({ success: true, data });
  } catch (err: unknown) {
    return res.status(400).json({ success: false, error: (err as Error).message });
  }
}

export async function updateLiabilityHandler(req: AuthRequest, res: Response) {
  const parsed = LiabilitySchema.partial().safeParse(req.body);
  if (!parsed.success) {
    return res.status(400).json({ success: false, error: parsed.error.errors[0].message });
  }
  try {
    const data = await updateLiability(req.user!.id, req.params.id, parsed.data);
    return res.json({ success: true, data });
  } catch (err: unknown) {
    return res.status(400).json({ success: false, error: (err as Error).message });
  }
}

export async function deleteLiabilityHandler(req: AuthRequest, res: Response) {
  try {
    await deleteLiability(req.user!.id, req.params.id);
    return res.json({ success: true, message: "Liability deleted" });
  } catch (err: unknown) {
    return res.status(400).json({ success: false, error: (err as Error).message });
  }
}