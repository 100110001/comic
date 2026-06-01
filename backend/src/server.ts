import dotenv from "dotenv";
dotenv.config();
import app from "./app";
import { db } from "./db/knex";

const PORT = process.env.PORT ?? 8888;

async function start() {
  await db.raw("SELECT 1");
  console.log("Database connected");

  app.listen(PORT, () => {
    console.log(`Server running on http://localhost:${PORT}`);
  });
}

start().catch((err) => {
  console.error("Failed to start:", err);
  process.exit(1);
});
