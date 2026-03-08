import { Router } from "express";
import { authMiddleware } from "../../middleware/auth.middleware";
import {
  getTransactionsHandler,
  createTransactionHandler,
  getTransactionByIdHandler,
  updateTransactionHandler,
  deleteTransactionHandler,
} from "./transactions.controller";

const router = Router();

router.use(authMiddleware);

router.get(   "/",    getTransactionsHandler);
router.post(  "/",    createTransactionHandler);
router.get(   "/:id", getTransactionByIdHandler);
router.put(   "/:id", updateTransactionHandler);
router.delete("/:id", deleteTransactionHandler);

export default router;