import { Router } from "express";
import { authMiddleware } from "../../middleware/auth.middleware";
import {
  getIncomeExpenseHandler,
  getSpendingHandler,
  getBudgetHandler,
  getSavingsHandler,
  getNetworthHandler,
  getFullReportHandler,
} from "./analytics.controller";

const router = Router();

router.use(authMiddleware);

router.get("/income-expense", getIncomeExpenseHandler);  // ?months=12
router.get("/spending",       getSpendingHandler);       // ?months=12
router.get("/budget",         getBudgetHandler);         // ?months=12
router.get("/savings",        getSavingsHandler);
router.get("/networth",       getNetworthHandler);
router.get("/report",         getFullReportHandler);     // ?months=12 — used for PDF

export default router;