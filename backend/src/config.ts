import dotenv from "dotenv";
dotenv.config();

function env(key: string): string | undefined {
  return process.env[key];
}

export function validateConfig() {
  const required = [
    "PORT",
    "COMIC_ROOT",
    "DB_HOST",
    "DB_PORT",
    "DB_USER",
    "DB_PASSWORD",
    "DB_NAME",
  ];
  const missing = required.filter((k) => !process.env[k]);
  if (missing.length > 0) {
    throw new Error(`Missing required env vars: ${missing.join(", ")}`);
  }
  const port = parseInt(process.env.PORT!);
  if (isNaN(port))
    throw new Error(`PORT must be a number, got: "${process.env.PORT}"`);
  const dbPort = parseInt(process.env.DB_PORT!);
  if (isNaN(dbPort))
    throw new Error(`DB_PORT must be a number, got: "${process.env.DB_PORT}"`);
}

export const config = {
  port: parseInt(env("PORT") ?? "8888"),
  comicRoot: env("COMIC_ROOT") ?? "",
  db: {
    host: env("DB_HOST") ?? "",
    port: parseInt(env("DB_PORT") ?? "3306"),
    user: env("DB_USER") ?? "",
    password: env("DB_PASSWORD") ?? "",
    name: env("DB_NAME") ?? "",
  },
  redis: {
    host: env("REDIS_HOST") ?? "127.0.0.1",
    port: parseInt(env("REDIS_PORT") ?? "6379"),
  },
};
