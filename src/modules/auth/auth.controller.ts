import { Request, Response } from "express";
import { z } from "zod";
import { AuthRequest } from "../../middleware/auth.middleware";
import {
  registerUser,
  loginUser,
  refreshTokens,
  forgotPassword,
  getMe,
} from "./auth.service";

const RegisterSchema = z.object({
  email:          z.string().email(),
  password:       z.string().min(8, "Password must be at least 8 characters"),
  name:           z.string().min(2),
  monthly_income: z.number().positive(),
  dependents:     z.number().int().min(0).default(0),
});

const LoginSchema = z.object({
  email:    z.string().email(),
  password: z.string().min(1),
});

const RefreshSchema = z.object({
  refreshToken: z.string().min(1),
});

const ForgotSchema = z.object({
  email: z.string().email(),
});

export async function register(req: Request, res: Response) {
  const parsed = RegisterSchema.safeParse(req.body);
  if (!parsed.success) {
    return res.status(400).json({ success: false, error: parsed.error.errors[0].message });
  }

  try {
    const { email, password, name, monthly_income, dependents } = parsed.data;
    const result = await registerUser(email, password, name, monthly_income, dependents);
    return res.status(201).json({ success: true, data: result });
  } catch (err: unknown) {
    return res.status(400).json({ success: false, error: (err as Error).message });
  }
}

export async function login(req: Request, res: Response) {
  const parsed = LoginSchema.safeParse(req.body);
  if (!parsed.success) {
    return res.status(400).json({ success: false, error: parsed.error.errors[0].message });
  }

  try {
    const result = await loginUser(parsed.data.email, parsed.data.password);
    return res.json({ success: true, data: result });
  } catch (err: unknown) {
    return res.status(401).json({ success: false, error: (err as Error).message });
  }
}

export async function refresh(req: Request, res: Response) {
  const parsed = RefreshSchema.safeParse(req.body);
  if (!parsed.success) {
    return res.status(400).json({ success: false, error: "refreshToken is required" });
  }

  try {
    const tokens = await refreshTokens(parsed.data.refreshToken);
    return res.json({ success: true, data: tokens });
  } catch (err: unknown) {
    return res.status(401).json({ success: false, error: (err as Error).message });
  }
}

export async function forgotPasswordHandler(req: Request, res: Response) {
  const parsed = ForgotSchema.safeParse(req.body);
  if (!parsed.success) {
    return res.status(400).json({ success: false, error: "Valid email is required" });
  }

  await forgotPassword(parsed.data.email);
  // Always 200 — never reveal if email exists
  return res.json({ success: true, message: "If that email exists, a reset link has been sent" });
}

export async function me(req: AuthRequest, res: Response) {
  try {
    const user = await getMe(req.user!.id);
    return res.json({ success: true, data: user });
  } catch (err: unknown) {
    return res.status(404).json({ success: false, error: (err as Error).message });
  }
}