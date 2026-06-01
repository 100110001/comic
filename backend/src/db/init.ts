import mysql from "mysql2/promise";
import fs from "fs";
import path from "path";
import dotenv from "dotenv";
dotenv.config();

async function init() {
  const conn = await mysql.createConnection({
    host: process.env.DB_HOST ?? "localhost",
    port: Number(process.env.DB_PORT ?? 3306),
    user: process.env.DB_USER ?? "root",
    password: process.env.DB_PASSWORD,
    multipleStatements: true,
  });

  const sql = fs.readFileSync(path.join(__dirname, "schema.sql"), "utf-8");
  await conn.query(sql);
  await conn.end();

  console.log("Database initialized successfully");
}

init().catch((err) => {
  console.error("Init failed:", err);
  process.exit(1);
});
