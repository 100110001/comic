import fs from "node:fs";
import path from "node:path";
import { parseArgs } from "node:util";
import { config } from "../config";

const IMAGE_EXTS = new Set([".jpg", ".jpeg", ".png", ".webp", ".gif", ".avif"]);
const CHAPTER = "第1話";
const entryKey = (name: string) =>
  process.platform === "win32" ? name.toLowerCase() : name;

function directory(target: string): string {
  if (!target) throw new Error("请设置 COMIC_ROOT 或指定 --root / --comic");
  const resolved = path.resolve(target);
  const stat = fs.lstatSync(resolved);
  if (stat.isSymbolicLink() || !stat.isDirectory())
    throw new Error(`目标不是普通目录: ${resolved}`);
  return fs.realpathSync(resolved);
}

export function organizeComic(target: string, dryRun: boolean): number {
  const comic = directory(target);
  const entries = new Map(
    fs
      .readdirSync(comic, { withFileTypes: true })
      .map((e) => [entryKey(e.name), e]),
  );
  if ([...entries.values()].some((e) => e.isSymbolicLink()))
    throw new Error(`目录含符号链接，未整理: ${comic}`);
  let conflicts = 0;
  const original = entries.get("original");
  const originalPath = path.join(comic, "original");
  if (original) {
    if (!original.isDirectory())
      throw new Error(`original 不是目录: ${originalPath}`);
    const children = fs.readdirSync(originalPath, { withFileTypes: true });
    if (children.some((e) => e.isSymbolicLink()))
      throw new Error(`original 含符号链接，未整理: ${comic}`);
    for (const entry of children) {
      if (
        entries.has(entryKey(entry.name)) ||
        fs.existsSync(path.join(comic, entry.name))
      ) {
        console.warn(
          `冲突，保留原文件: ${path.join(originalPath, entry.name)}`,
        );
        conflicts++;
        continue;
      }
      console.log(
        `${dryRun ? "[预览] " : ""}上移: ${path.join(originalPath, entry.name)} → ${path.join(comic, entry.name)}`,
      );
      if (!dryRun)
        fs.renameSync(
          path.join(originalPath, entry.name),
          path.join(comic, entry.name),
        );
      entries.set(entryKey(entry.name), entry);
    }
    if (conflicts === 0) {
      console.log(`${dryRun ? "[预览] " : ""}删除空目录: ${originalPath}`);
      if (!dryRun) fs.rmdirSync(originalPath);
      entries.delete("original");
    }
  }
  const images = [...entries.values()].filter(
    (e) => e.isFile() && IMAGE_EXTS.has(path.extname(e.name).toLowerCase()),
  );
  if (images.length) {
    if (
      [...entries.values()].some((e) => e.isDirectory()) ||
      entries.has(CHAPTER)
    ) {
      console.log(`已有章节或同名目标，跳过根目录图片: ${comic}`);
    } else {
      const chapter = path.join(comic, CHAPTER);
      console.log(
        `${dryRun ? "[预览] " : ""}归入章节: ${comic} → ${CHAPTER} (${images.length} 张)`,
      );
      if (!dryRun) {
        fs.mkdirSync(chapter);
        for (const image of images)
          fs.renameSync(
            path.join(comic, image.name),
            path.join(chapter, image.name),
          );
      }
    }
  }
  return conflicts;
}

function main() {
  const { values } = parseArgs({
    options: {
      root: { type: "string" },
      comic: { type: "string" },
      "dry-run": { type: "boolean", default: false },
      help: { type: "boolean", default: false },
    },
  });
  if (values.help) {
    console.log(
      "用法: comics:organize [--root <漫画库> | --comic <漫画目录>] [--dry-run]\n默认使用 COMIC_ROOT；先展开 original，再将无子目录的根图片归入第1話。不会同步数据库。",
    );
    return;
  }
  if (values.root !== undefined && values.comic !== undefined)
    throw new Error("--root 与 --comic 不能同时使用");
  const root = directory(values.comic ?? values.root ?? config.comicRoot);
  const targets =
    values.comic !== undefined
      ? [root]
      : fs
          .readdirSync(root, { withFileTypes: true })
          .filter(
            (e) =>
              e.isDirectory() && !e.isSymbolicLink() && !e.name.startsWith("."),
          )
          .map((e) => path.join(root, e.name));
  let issues = 0;
  for (const target of targets) {
    try {
      issues += organizeComic(target, values["dry-run"]);
    } catch (err) {
      console.error(`整理失败: ${target}`, err);
      issues++;
    }
  }
  console.log(
    `${values["dry-run"] ? "预览" : "整理"}完成: ${targets.length} 个漫画目录，${issues} 项冲突或错误`,
  );
  if (issues) process.exitCode = 1;
}

if (require.main === module) {
  try {
    main();
  } catch (err) {
    console.error("整理失败:", err);
    process.exitCode = 1;
  }
}
