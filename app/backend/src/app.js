require("dotenv").config();

const express = require("express");
const pool = require("./db");

const app = express();

app.disable("x-powered-by");
app.use(express.json());

app.get("/health", (req, res) => {
  res.status(200).json({
    status: "UP",
    service: "backend",
  });
});

app.get("/ready", async (req, res) => {
  try {
    await pool.query("SELECT 1");

    res.status(200).json({
      status: "READY",
      service: "backend",
      database: "UP",
    });
  } catch (error) {
    console.error("Database readiness check failed:", error.message);

    res.status(503).json({
      status: "NOT_READY",
      service: "backend",
      database: "DOWN",
    });
  }
});

module.exports = app;
