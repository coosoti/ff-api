import request from "supertest";
import express from "express";
import cors from "cors";
import authRoutes from "./auth.routes";

// Minimal Express app for testing — no socket.io needed
const app = express();
app.use(express.json());
app.use(cors());
app.use("/api/v1/auth", authRoutes);

const TEST_EMAIL = `test-${Date.now()}@example.com`;
const TEST_PASSWORD = "Test@1234";
let accessToken = "";
let refreshToken = "";

describe("Module 1 — Authentication", () => {

  // ── US-001 ────────────────────────────────────────────────────────
  describe("POST /api/v1/auth/register", () => {
    it("registers a new user and returns tokens + user", async () => {
      const res = await request(app).post("/api/v1/auth/register").send({
        email: TEST_EMAIL,
        password: TEST_PASSWORD,
        name: "Test User",
        monthly_income: 100000,
        dependents: 0,
      });

      expect(res.status).toBe(201);
      expect(res.body.success).toBe(true);
      expect(res.body.data.accessToken).toBeDefined();
      expect(res.body.data.refreshToken).toBeDefined();
      expect(res.body.data.user.email).toBe(TEST_EMAIL);

      accessToken = res.body.data.accessToken;
      refreshToken = res.body.data.refreshToken;
    });

    it("rejects duplicate email", async () => {
      const res = await request(app).post("/api/v1/auth/register").send({
        email: TEST_EMAIL,
        password: TEST_PASSWORD,
        name: "Dupe",
        monthly_income: 50000,
      });
      expect(res.status).toBe(400);
      expect(res.body.success).toBe(false);
    });

    it("rejects missing fields", async () => {
      const res = await request(app).post("/api/v1/auth/register").send({
        email: "nope",
        password: "short",
      });
      expect(res.status).toBe(400);
      expect(res.body.success).toBe(false);
    });
  });

  // ── US-002 ────────────────────────────────────────────────────────
  describe("POST /api/v1/auth/login", () => {
    it("logs in with correct credentials", async () => {
      const res = await request(app).post("/api/v1/auth/login").send({
        email: TEST_EMAIL,
        password: TEST_PASSWORD,
      });

      expect(res.status).toBe(200);
      expect(res.body.data.accessToken).toBeDefined();
      accessToken = res.body.data.accessToken;
      refreshToken = res.body.data.refreshToken;
    });

    it("rejects wrong password", async () => {
      const res = await request(app).post("/api/v1/auth/login").send({
        email: TEST_EMAIL,
        password: "WrongPass@99",
      });
      expect(res.status).toBe(401);
    });
  });

  // ── US-003 ────────────────────────────────────────────────────────
  describe("POST /api/v1/auth/refresh", () => {
    it("returns new tokens from a valid refresh token", async () => {
      const res = await request(app).post("/api/v1/auth/refresh").send({ refreshToken });
      expect(res.status).toBe(200);
      expect(res.body.data.accessToken).toBeDefined();
    });

    it("rejects an invalid refresh token", async () => {
      const res = await request(app).post("/api/v1/auth/refresh").send({ refreshToken: "bad.token.here" });
      expect(res.status).toBe(401);
    });
  });

  // ── US-004 ────────────────────────────────────────────────────────
  describe("POST /api/v1/auth/forgot-password", () => {
    it("always returns 200 regardless of whether email exists", async () => {
      const res = await request(app).post("/api/v1/auth/forgot-password").send({ email: TEST_EMAIL });
      expect(res.status).toBe(200);
      expect(res.body.success).toBe(true);
    });

    it("always returns 200 for unknown email (no enumeration)", async () => {
      const res = await request(app).post("/api/v1/auth/forgot-password").send({ email: "nobody@nowhere.com" });
      expect(res.status).toBe(200);
    });
  });

  // ── GET /auth/me ──────────────────────────────────────────────────
  describe("GET /api/v1/auth/me", () => {
    it("returns the current user profile", async () => {
      const res = await request(app)
        .get("/api/v1/auth/me")
        .set("Authorization", `Bearer ${accessToken}`);

      expect(res.status).toBe(200);
      expect(res.body.data.email).toBe(TEST_EMAIL);
    });

    it("rejects requests without a token", async () => {
      const res = await request(app).get("/api/v1/auth/me");
      expect(res.status).toBe(401);
    });
  });
});