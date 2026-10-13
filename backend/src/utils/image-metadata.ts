import fs from "node:fs/promises";
import { imageSize } from "image-size";

/** 有界异步读取，避免大章节把所有文件句柄和数据库连接同时占满。 */
export async function mapImages<T, R>(
  items: T[],
  read: (item: T) => Promise<R>,
): Promise<R[]> {
  const results = new Array<R>(items.length);
  let next = 0;
  await Promise.all(
    Array.from({ length: Math.min(4, items.length) }, async () => {
      while (next < items.length) {
        const index = next++;
        results[index] = await read(items[index]!);
      }
    }),
  );
  return results;
}

/** 常见图片只读首个 4 KiB；较长的 JPEG 元数据按需扩展，最多 512 KiB。 */
export async function readImageDimensions(filePath: string) {
  const file = await fs.open(filePath, "r");
  try {
    const before = await file.stat();
    const limit = Math.min(before.size, 512 * 1024);
    if (!before.isFile() || limit === 0) throw new Error("图片文件为空");
    const buffer = Buffer.alloc(limit);
    let loaded = 0;
    let target = Math.min(4096, limit);
    while (loaded < limit) {
      const { bytesRead } = await file.read(
        buffer,
        loaded,
        target - loaded,
        loaded,
      );
      if (bytesRead === 0) throw new Error("图片读取不完整");
      loaded += bytesRead;
      if (loaded < target) continue;
      try {
        const dimensions = imageSize(buffer.subarray(0, loaded));
        if (!dimensions.width || !dimensions.height)
          throw new Error("图片尺寸无效");
        const after = await file.stat();
        if (
          before.size !== after.size ||
          before.mtimeMs !== after.mtimeMs ||
          before.ctimeMs !== after.ctimeMs
        )
          throw new Error("读取期间图片已变化");
        return {
          width: dimensions.width,
          height: dimensions.height,
          size: before.size,
          mtimeMs: before.mtimeMs,
        };
      } catch (error) {
        if (loaded === limit) throw error;
        target = Math.min(target * 4, limit);
      }
    }
    throw new Error("无法读取图片尺寸");
  } finally {
    await file.close();
  }
}

export function imagePathUrl(relativePath: string): string {
  return `/static/${relativePath.replace(/\\/g, "/").split("/").map(encodeURIComponent).join("/")}`;
}
