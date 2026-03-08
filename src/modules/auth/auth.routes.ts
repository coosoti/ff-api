import { Router } from "express";
import { authMiddleware } from "../../middleware/auth.middleware";
import { authRateLimit } from "../../middleware/rateLimit.middleware";
import {
  register,
  login,
  refresh,
  forgotPasswordHandler,
  me,
} from "./auth.controller";

const router = Router();

router.post("/register",         authRateLimit, register);
router.post("/login",            authRateLimit, login);
router.post("/refresh",          refresh);
router.post("/forgot-password",  authRateLimit, forgotPasswordHandler);
router.get( "/me",               authMiddleware, me);

export default router;