import { Router } from "express";
import { authMiddleware } from "../../middleware/auth.middleware";
import {
  getNetWorthHandler,
  getAssetsHandler, createAssetHandler, updateAssetHandler, deleteAssetHandler,
  getLiabilitiesHandler, createLiabilityHandler, updateLiabilityHandler, deleteLiabilityHandler,
} from "./networth.controller";

const router = Router();

router.use(authMiddleware);

// Summary
router.get("/", getNetWorthHandler);

// Assets
router.get(   "/assets",     getAssetsHandler);
router.post(  "/assets",     createAssetHandler);
router.put(   "/assets/:id", updateAssetHandler);
router.delete("/assets/:id", deleteAssetHandler);

// Liabilities
router.get(   "/liabilities",     getLiabilitiesHandler);
router.post(  "/liabilities",     createLiabilityHandler);
router.put(   "/liabilities/:id", updateLiabilityHandler);
router.delete("/liabilities/:id", deleteLiabilityHandler);

export default router;