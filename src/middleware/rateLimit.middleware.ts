import rateLimit from "express-rate-limit";

export const authRateLimit = rateLimit({
  windowMs: 15 * 60 * 1000,
  max: process.env.NODE_ENV === "development" ? 100 : 10,
  message: { success: false, error: "Too many attempts, please try again later" },
  standardHeaders: true,
  legacyHeaders: false,
});

export const generalRateLimit = rateLimit({
  windowMs: 60 * 1000, // 1 minute
  max: 100,
  message: { success: false, error: "Too many requests" },
  standardHeaders: true,
  legacyHeaders: false,
});