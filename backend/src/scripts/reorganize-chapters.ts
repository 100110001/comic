import fs from "fs";
import path from "path";

import { config } from "../config";
const COMIC_ROOT = config.comicRoot;
const CHAPTER_NAME = "第1話";
const IMAGE_EXTS = new Set([".jpg", ".jpeg", ".png", ".webp", ".gif", ".avif"]);

function isImage(name: string): boolean {
  return IMAGE_EXTS.has(path.extname(name).toLowerCase());
}

function main() {
  const comicNames = fs
    .readdirSync(COMIC_ROOT, { withFileTypes: true })
    .filter((e) => e.isDirectory() && !e.name.startsWith("."))
    .map((e) => e.name);

  let movedComics = 0;
  let movedImages = 0;

  for (const comicName of comicNames) {
    const comicPath = path.join(COMIC_ROOT, comicName);
    const entries = fs.readdirSync(comicPath, { withFileTypes: true });

    const rootImages = entries.filter((e) => e.isFile() && isImage(e.name));
    const subDirs = entries.filter((e) => e.isDirectory());

    if (rootImages.length === 0) continue; // 没有根目录图片,跳过
    if (subDirs.length > 0) {
      console.log(`跳过(已有子文件夹,需人工确认): ${comicName}`);
      continue;
    }

    const chapterPath = path.join(comicPath, CHAPTER_NAME);
    fs.mkdirSync(chapterPath, { recursive: true });

    for (const img of rootImages) {
      fs.renameSync(path.join(comicPath, img.name), path.join(chapterPath, img.name));
    }

    console.log(`✔ ${comicName}  →  ${CHAPTER_NAME}  (${rootImages.length} 张)`);
    movedComics++;
    movedImages += rootImages.length;
  }

  console.log("\n─────────────────────────────");
  console.log(`处理完成: ${movedComics} 个文件夹, 共移动 ${movedImages} 张图片`);
}

main();
