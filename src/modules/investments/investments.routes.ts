import { Router } from "express";
import { authMiddleware } from "../../middleware/auth.middleware";
import {
  getPortfolioHandler,
  getInvestmentsHandler,
  getInvestmentByIdHandler,
  createInvestmentHandler,
  updateInvestmentHandler,
  deleteInvestmentHandler,
} from "./investments.controller";

const router = Router();

router.use(authMiddleware);

router.get(   "/portfolio", getPortfolioHandler);
router.get(   "/",          getInvestmentsHandler);
router.post(  "/",          createInvestmentHandler);
router.get(   "/:id",       getInvestmentByIdHandler);
router.put(   "/:id",       updateInvestmentHandler);
router.delete("/:id",       deleteInvestmentHandler);

export default router;