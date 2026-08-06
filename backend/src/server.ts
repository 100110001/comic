import { config, validateConfig } from "./config";
import app from "./app";
import { db } from "./db/knex";
import { redis } from "./db/redis";

process.on("uncaughtException", (err) =>
  console.error("[uncaughtException]", err),
);
process.on("unhandledRejection", (err) =>
  console.error("[unhandledRejection]", err),
);

try {
  validateConfig();
} catch (err) {
  console.error("[Config Error]", (err as Error).message);
  process.exit(1);
}

async function start() {
  await db.raw("SELECT 1");
  console.log("Database connected");

  try {
    await redis.connect();
    console.log("Redis connected");
    await redis.flushdb();
    console.log("Redis cache cleared");
  } catch {
    console.warn("Redis unavailable — caching disabled");
  }

  app.listen(config.port, () => {
    console.log(
      `Server running on http://localhost:${config.port} (pid ${process.pid}, started ${new Date().toISOString()})`,
    );
  });
}

start().catch((err) => {
  console.error("Failed to start:", err);
  process.exit(1);
});
