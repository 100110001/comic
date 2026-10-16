import fs from "fs";
import path from "path";
import { progress, done } from "../utils/progress";
import { compareChapterTitle } from "../utils/chapterSort";

import { config } from "../config";
const COMIC_ROOT = config.comicRoot;
const IMAGE_EXTS = new Set([".jpg", ".jpeg", ".png", ".webp", ".gif", ".avif"]);

interface ImageFile {
  filename: string;
  path: string;
  width?: number | null;
  height?: number | null;
}

interface Chapter {
  name: string;
  path: string;
  images: ImageFile[];
}

export interface Comic {
  name: string; // 原始文件夹名
  title: string; // 解析后的漫画名
  author: string | null;
  path: string;
  chapters: Chapter[];
}

// "[作者] 漫画名" → { author, title }
function parseFolderName(name: string): {
  author: string | null;
  title: string;
} {
  const match = name.match(/^\[([^\]]+)\]\s*(.+)$/);
  if (match) return { author: match[1]!.trim(), title: match[2]!.trim() };
  return { author: null, title: name.trim() };
}

function collectImages(dir: string): ImageFile[] {
  return fs
    .readdirSync(dir)
    .filter((f) => IMAGE_EXTS.has(path.extname(f).toLowerCase()))
    .sort()
    .filter((f) => fs.statSync(path.join(dir, f)).isFile())
    .map((f) => {
      const fullPath = path.join(dir, f);
      return { filename: f, path: fullPath, width: null, height: null };
    });
}

export function scanComics(root: string): Comic[] {
  if (!root || !fs.statSync(root).isDirectory()) {
    throw new Error(`漫画库目录无效: ${root || "未设置 COMIC_ROOT"}`);
  }
  // 入库路径保留配置入口，确保与静态 URL 及目录归属校验使用同一个根目录。
  root = path.resolve(root);
  const comics: Comic[] = [];
  const allDirs = fs
    .readdirSync(root)
    .filter(
      (n) =>
        !n.startsWith(".") && fs.statSync(path.join(root, n)).isDirectory(),
    );
  const total = allDirs.length;

  for (let i = 0; i < allDirs.length; i++) {
    const comicName = allDirs[i]!;
    progress("扫描", i + 1, total, comicName.slice(0, 40));

    const comicPath = path.join(root, comicName);
    const { author, title } = parseFolderName(comicName);
    const comic: Comic = {
      name: comicName,
      title,
      author,
      path: comicPath,
      chapters: [],
    };
    const entries = fs.readdirSync(comicPath).sort(compareChapterTitle);

    const rootImages = collectImages(comicPath);
    if (rootImages.length > 0) {
      comic.chapters.push({
        name: "默认",
        path: comicPath,
        images: rootImages,
      });
    }

    for (const chapterName of entries) {
      const chapterPath = path.join(comicPath, chapterName);
      if (!fs.statSync(chapterPath).isDirectory()) continue;
      const images = collectImages(chapterPath);
      if (images.length > 0) {
        comic.chapters.push({ name: chapterName, path: chapterPath, images });
      }
    }

    if (comic.chapters.length > 0) comics.push(comic);
  }

  return comics;
}

function printTree(comics: Comic[]) {
  let totalChapters = 0;
  let totalImages = 0;

  for (const comic of comics) {
    const authorTag = comic.author ? ` (${comic.author})` : "";
    console.log(`\n📚 ${comic.title}${authorTag}`);
    for (const chapter of comic.chapters) {
      console.log(`  📂 ${chapter.name}  (${chapter.images.length} 张)`);
      totalChapters++;
      totalImages += chapter.images.length;
    }
  }

  console.log(`\n─────────────────────────────`);
  console.log(
    `漫画: ${comics.length}  章节: ${totalChapters}  图片: ${totalImages}`,
  );
}

const OUTPUT = path.join(__dirname, "../../data/scan.json");

export function saveScan(comics: Comic[]) {
  fs.mkdirSync(path.dirname(OUTPUT), { recursive: true });
  fs.writeFileSync(OUTPUT, JSON.stringify(comics, null, 2), "utf-8");
}

export function scan() {
  const comics = scanComics(COMIC_ROOT);
  done("扫描完成");
  printTree(comics);

  saveScan(comics);
  console.log(`已保存到 ${OUTPUT}`);
  return comics;
}

if (require.main === module) {
  try {
    scan();
  } catch (err) {
    console.error("扫描失败:", err);
    process.exitCode = 1;
  }
}
