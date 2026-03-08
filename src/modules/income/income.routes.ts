import { Router } from "express";
import { authMiddleware } from "../../middleware/auth.middleware";
import {
  getIncomeHandler,
  createIncomeHandler,
  updateIncomeHandler,
  deleteIncomeHandler,
} from "./income.controller";

const router = Router();

router.use(authMiddleware);

router.get(   "/",    getIncomeHandler);
router.post(  "/",    createIncomeHandler);
router.put(   "/:id", updateIncomeHandler);
router.delete("/:id", deleteIncomeHandler);

export default router;