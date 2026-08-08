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

  // 对已存在的旧表补充新增的唯一约束（schema.sql 的 CREATE TABLE 只对全新库生效）
  await ensureUniqueKey(conn, "comics", "uq_comics_title_author", "title, author");
  await ensureUniqueKey(
    conn,
    "chapters",
    "uq_chapters_comic_title",
    "comic_id, title",
  );
  await ensureUniqueKey(
    conn,
    "images",
    "uq_images_chapter_filename",
    "chapter_id, filename",
  );

  await conn.end();

  console.log("Database initialized successfully");
}

async function ensureUniqueKey(
  conn: mysql.Connection,
  table: string,
  indexName: string,
  columns: string,
) {
  const [rows] = await conn.execute(
    "SELECT COUNT(*) AS cnt FROM information_schema.STATISTICS WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = ? AND INDEX_NAME = ?",
    [table, indexName],
  );
  const exists = Number((rows as mysql.RowDataPacket[])[0]!.cnt) > 0;
  if (exists) return;

  await conn.query(
    `ALTER TABLE \`${table}\` ADD UNIQUE KEY \`${indexName}\` (${columns})`,
  );
  console.log(`Added unique key ${indexName} on ${table}`);
}

init().catch((err) => {
  console.error("Init failed:", err);
  process.exit(1);
});
