import { Router } from "express";
import { authMiddleware } from "../../middleware/auth.middleware";
import {
  getCategoriesHandler,
  createCategoryHandler,
  updateCategoryHandler,
  deleteCategoryHandler,
  recalculateHandler,
  getSummaryHandler,
} from "./budget.controller";

const router = Router();

// All budget routes are protected
router.use(authMiddleware);

router.get(   "/categories",      getCategoriesHandler);
router.post(  "/categories",      createCategoryHandler);
router.put(   "/categories/:id",  updateCategoryHandler);
router.delete("/categories/:id",  deleteCategoryHandler);
router.post(  "/recalculate",     recalculateHandler);
router.get(   "/summary",         getSummaryHandler);

export default router;