const { Pool } = require("pg");

const pool = new Pool({
  host: process.env.DATABASE_HOST || "localhost",
  port: process.env.DATABASE_PORT || 5432,
  database: process.env.DATABASE_NAME || "cloudnative",
  user: process.env.DATABASE_USER || "postgres",
  password: process.env.DATABASE_PASSWORD,
});

module.exports = pool;
