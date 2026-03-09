import { Router } from "express";
import { authMiddleware } from "../../middleware/auth.middleware";
import {
  getAccountsHandler, getAccountByIdHandler, createAccountHandler,
  updateAccountHandler, deleteAccountHandler,
  getFundsHandler, upsertFundsHandler,
  getWithdrawalsHandler, createWithdrawalHandler, deleteWithdrawalHandler,
  getProjectionHandler,
} from "./pension.controller";

const router = Router();

router.use(authMiddleware);

// Accounts
router.get(   "/",                        getAccountsHandler);
router.post(  "/",                        createAccountHandler);
router.get(   "/:accountId",              getAccountByIdHandler);
router.put(   "/:accountId",              updateAccountHandler);
router.delete("/:accountId",              deleteAccountHandler);

// Fund allocations
router.get(  "/:accountId/funds",         getFundsHandler);
router.put(  "/:accountId/funds",         upsertFundsHandler);

// Withdrawals
router.get(   "/:accountId/withdrawals",              getWithdrawalsHandler);
router.post(  "/:accountId/withdrawals",              createWithdrawalHandler);
router.delete("/:accountId/withdrawals/:withdrawalId", deleteWithdrawalHandler);

// Projection
router.get(  "/:accountId/projection",    getProjectionHandler);

export default router;