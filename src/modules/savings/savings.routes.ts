import { Router } from "express";
import { authMiddleware } from "../../middleware/auth.middleware";
import {
  getSavingsGoalsHandler,
  getSavingsGoalByIdHandler,
  createSavingsGoalHandler,
  updateSavingsGoalHandler,
  topUpSavingsGoalHandler,
  deleteSavingsGoalHandler,
} from "./savings.controller";

const router = Router();

router.use(authMiddleware);

router.get(   "/",           getSavingsGoalsHandler);
router.post(  "/",           createSavingsGoalHandler);
router.get(   "/:id",        getSavingsGoalByIdHandler);
router.put(   "/:id",        updateSavingsGoalHandler);
router.post(  "/:id/topup",  topUpSavingsGoalHandler);
router.delete("/:id",        deleteSavingsGoalHandler);

export default router;