import { Router } from "express";
import { authMiddleware } from "../../middleware/auth.middleware";
import {
  getBillsHandler, getBillsSummaryHandler, getBillByIdHandler,
  createBillHandler, updateBillHandler, deleteBillHandler,
  markPaidHandler, markUnpaidHandler, getPaymentHistoryHandler,
} from "./bills.controller";

const router = Router();

router.use(authMiddleware);

router.get(  "/summary",          getBillsSummaryHandler);
router.get(  "/",                 getBillsHandler);
router.post( "/",                 createBillHandler);
router.get(  "/:id",              getBillByIdHandler);
router.put(  "/:id",              updateBillHandler);
router.delete("/:id",             deleteBillHandler);
router.post( "/:id/pay",          markPaidHandler);
router.delete("/:id/pay",         markUnpaidHandler);
router.get(  "/:id/history",      getPaymentHistoryHandler);

export default router;