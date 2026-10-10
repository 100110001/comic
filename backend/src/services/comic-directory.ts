import fs from "node:fs/promises";
import path from "node:path";
import { execFile, spawn } from "node:child_process";
import { promisify } from "node:util";

const execute = promisify(execFile);

function isWithin(root: string, target: string): boolean {
  const relative = path.relative(root, target);
  return (
    relative !== "" &&
    relative !== ".." &&
    !relative.startsWith(`..${path.sep}`) &&
    !path.isAbsolute(relative)
  );
}

export async function resolveComicDirectory(
  comicRoot: string,
  coverPath: string | null,
): Promise<string> {
  if (!comicRoot || !coverPath) throw new Error("漫画原文件目录不可用");
  const root = path.resolve(comicRoot);
  const image = path.resolve(coverPath);
  if (!isWithin(root, image)) throw new Error("漫画原文件路径不在漫画根目录内");
  const parts = path.relative(root, image).split(path.sep);
  if (parts.length < 2) throw new Error("无法确定漫画原文件目录");
  const directory = path.join(root, parts[0]);
  try {
    const realRoot = await fs.realpath(root);
    const realDirectory = await fs.realpath(directory);
    if (!isWithin(realRoot, realDirectory)) {
      throw new Error("漫画原文件目录不在漫画根目录内");
    }
    if (!(await fs.stat(realDirectory)).isDirectory()) {
      throw new Error("漫画原文件目录不存在或不可访问");
    }
    return realDirectory;
  } catch (error) {
    if (error instanceof Error && !("code" in error)) throw error;
    throw new Error("漫画原文件目录不存在或不可访问", { cause: error });
  }
}

export async function openComicDirectory(directory: string): Promise<void> {
  try {
    switch (process.platform) {
      case "win32":
        await new Promise<void>((resolve, reject) => {
          const child = spawn("explorer.exe", [directory], {
            detached: true,
            stdio: "ignore",
          });
          child.once("error", reject);
          child.once("spawn", () => {
            child.unref();
            resolve();
          });
        });
        break;
      case "darwin":
        await execute("open", [directory], { timeout: 10000 });
        break;
      case "linux":
        await execute("xdg-open", [directory], { timeout: 10000 });
        break;
      default:
        throw new Error("unsupported platform");
    }
  } catch (error) {
    throw new Error("无法打开目录，请检查后端电脑的桌面环境和文件管理器", {
      cause: error,
    });
  }
}
