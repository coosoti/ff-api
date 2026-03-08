import "dotenv/config";
import express from "express";
import cors from "cors";
import helmet from "helmet";
import { createServer } from "http";
import { Server } from "socket.io";
import { corsOptions } from "./config/cors";
import { generalRateLimit } from "./middleware/rateLimit.middleware";
import authRoutes from "./modules/auth/auth.routes";
import budgetRoutes from "./modules/budget/budget.routes";

const app = express();
const httpServer = createServer(app);

// Socket.io — used by Transactions module for real-time broadcast
export const io = new Server(httpServer, { cors: corsOptions });
io.on("connection", (socket) => {
  socket.on("join", (userId: string) => socket.join(userId));
});

// ── Middleware ────────────────────────────────────────────────────────
app.use(helmet());
app.use(cors(corsOptions));
app.use(express.json());
app.use(generalRateLimit);

// ── Routes ────────────────────────────────────────────────────────────
app.use("/api/v1/auth",   authRoutes);
app.use("/api/v1/budget", budgetRoutes);

// ── Health ────────────────────────────────────────────────────────────
app.get("/health", (_req, res) => {
  res.json({ status: "ok", timestamp: new Date().toISOString() });
});

// ── Start ─────────────────────────────────────────────────────────────
const PORT = Number(process.env.PORT) || 5000;
httpServer.listen(PORT, () => {
  console.log(`🚀 API running on http://localhost:${PORT}`);
});