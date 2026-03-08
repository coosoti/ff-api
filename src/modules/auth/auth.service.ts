import jwt from "jsonwebtoken";
import { supabase } from "../../config/database";

const DEFAULT_CATEGORIES = [
  // Needs — 50%
  { name: "Housing",       type: "needs",   weight: 0.25 },
  { name: "Food",          type: "needs",   weight: 0.10 },
  { name: "Transport",     type: "needs",   weight: 0.06 },
  { name: "Utilities",     type: "needs",   weight: 0.04 },
  { name: "Healthcare",    type: "needs",   weight: 0.02 },
  { name: "Insurance",     type: "needs",   weight: 0.02 },
  { name: "Education",     type: "needs",   weight: 0.01 },
  // Wants — 30%
  { name: "Entertainment", type: "wants",   weight: 0.10 },
  { name: "Dining",        type: "wants",   weight: 0.12 },
  { name: "Personal Care", type: "wants",   weight: 0.08 },
  // Savings — 20%
  { name: "Emergency Fund",type: "savings", weight: 0.10 },
  { name: "Investments",   type: "savings", weight: 0.10 },
];

function signTokens(userId: string, email: string) {
  const accessToken = jwt.sign(
    { id: userId, email },
    process.env.JWT_SECRET!,
    { expiresIn: (process.env.JWT_EXPIRES_IN || "15m") as jwt.SignOptions["expiresIn"] }
  );
  const refreshToken = jwt.sign(
    { id: userId, email },
    process.env.JWT_SECRET!,
    { expiresIn: (process.env.JWT_REFRESH_EXPIRES_IN || "7d") as jwt.SignOptions["expiresIn"] }
  );
  return { accessToken, refreshToken };
}

// ── US-001: Register ──────────────────────────────────────────────────

export async function registerUser(
  email: string,
  password: string,
  name: string,
  monthlyIncome: number,
  dependents: number
) {
  // 1. Create Supabase auth user
  const { data: authData, error: authError } = await supabase.auth.admin.createUser({
    email,
    password,
    email_confirm: true,
    user_metadata: { name, monthly_income: monthlyIncome, dependents },
  });

  if (authError || !authData.user) {
    const msg = authError?.message ?? "Registration failed";
    throw new Error(msg.includes("already") ? "Email already registered" : msg);
  }

  const userId = authData.user.id;

  // 2. Insert profile
  const { error: profileError } = await supabase.from("profiles").insert({
    id: userId,
    email,
    name,
    monthly_income: monthlyIncome,
    dependents,
  });

  if (profileError) {
    await supabase.auth.admin.deleteUser(userId); // rollback orphan
    throw new Error(profileError.message);
  }

  // 3. Seed 12 default budget categories (US-005)
  const categories = DEFAULT_CATEGORIES.map((c) => ({
    user_id: userId,
    name: c.name,
    type: c.type,
    budgeted_amount: Math.round(monthlyIncome * c.weight),
    is_default: true,
  }));

  const { error: catError } = await supabase.from("budget_categories").insert(categories);
  if (catError) throw new Error(catError.message);

  // 4. Sign and return tokens
  const tokens = signTokens(userId, email);
  return {
    user: { id: userId, email, name, monthly_income: monthlyIncome, dependents },
    ...tokens,
  };
}

// ── US-002: Login ─────────────────────────────────────────────────────

export async function loginUser(email: string, password: string) {
  const { data, error } = await supabase.auth.signInWithPassword({ email, password });

  if (error || !data.session || !data.user) {
    throw new Error("Invalid email or password");
  }

  const { data: profile } = await supabase
    .from("profiles")
    .select("*")
    .eq("id", data.user.id)
    .single();

  const tokens = signTokens(data.user.id, email);
  return { user: profile, ...tokens };
}

// ── US-003: Refresh token ─────────────────────────────────────────────

export async function refreshTokens(token: string) {
  try {
    const decoded = jwt.verify(token, process.env.JWT_SECRET!) as { id: string; email: string };
    return signTokens(decoded.id, decoded.email);
  } catch {
    throw new Error("Invalid or expired refresh token");
  }
}

// ── US-004: Forgot password ───────────────────────────────────────────

export async function forgotPassword(email: string) {
  await supabase.auth.resetPasswordForEmail(email, {
    redirectTo: `${process.env.CLIENT_URL}/reset-password`,
  });
  // Always resolves — never reveal whether email exists
}

// ── Get current user (GET /auth/me) ───────────────────────────────────

export async function getMe(userId: string) {
  const { data, error } = await supabase
    .from("profiles")
    .select("*")
    .eq("id", userId)
    .single();

  if (error || !data) throw new Error("User not found");
  return data;
}