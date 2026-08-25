import fs from "fs";
import path from "path";

import { config } from "../config";

const ORIGINAL_DIR = "original";

function main() {
  const comicRoot = config.comicRoot;
  if (!comicRoot || !fs.existsSync(comicRoot)) {
    console.error(`COMIC_ROOT 不存在: ${comicRoot}`);
    process.exit(1);
  }

  // 可选参数：漫画目录（含 original）或库根目录（批量处理其下所有漫画）；
  // 缺省时扫描 COMIC_ROOT 下全部漫画目录
  const targetArg = process.argv[2];
  let targets: string[];
  if (targetArg) {
    const resolved = path.resolve(targetArg);
    if (!fs.existsSync(resolved) || !fs.statSync(resolved).isDirectory()) {
      console.error(`目标不存在或不是目录: ${resolved}`);
      process.exit(1);
    }
    targets = fs.existsSync(path.join(resolved, ORIGINAL_DIR))
      ? [resolved]
      : fs
          .readdirSync(resolved, { withFileTypes: true })
          .filter((e) => e.isDirectory() && !e.name.startsWith("."))
          .map((e) => path.join(resolved, e.name));
  } else {
    targets = fs
      .readdirSync(comicRoot, { withFileTypes: true })
      .filter((e) => e.isDirectory() && !e.name.startsWith("."))
      .map((e) => path.join(comicRoot, e.name));
  }

  let processed = 0;
  let movedEntries = 0;
  let collisions = 0;
  let skipped = 0;

  for (const comicPath of targets) {
    const comicName = path.basename(comicPath);
    if (!fs.existsSync(comicPath) || !fs.statSync(comicPath).isDirectory()) {
      console.log(`跳过(目录不存在): ${comicPath}`);
      skipped++;
      continue;
    }

    const originalPath = path.join(comicPath, ORIGINAL_DIR);
    if (!fs.existsSync(originalPath)) {
      skipped++;
      continue;
    }

    const entries = fs.readdirSync(originalPath, { withFileTypes: true });
    for (const entry of entries) {
      const from = path.join(originalPath, entry.name);
      const to = path.join(comicPath, entry.name);
      if (fs.existsSync(to)) {
        console.log(`冲突(目标已存在,跳过): ${comicName} / ${entry.name}`);
        collisions++;
        continue;
      }
      fs.renameSync(from, to);
      movedEntries++;
    }

    const remaining = fs.readdirSync(originalPath);
    if (remaining.length === 0) {
      fs.rmdirSync(originalPath);
      console.log(`✔ ${comicName} → 上移 ${entries.length} 项, 已删除 original`);
      processed++;
    } else {
      console.log(
        `⚠ ${comicName} → original 仍有 ${remaining.length} 项(冲突), 保留 original`,
      );
    }
  }

  console.log("\n─────────────────────────────");
  console.log(
    `处理完成: ${processed} 个目录, 移动 ${movedEntries} 项, 冲突 ${collisions} 项, 跳过 ${skipped} 个`,
  );
}

main();
