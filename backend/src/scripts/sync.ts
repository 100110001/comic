import { scan } from "./scan";
import { seed } from "./seed";
import { clearCache } from "./clear-cache";

async function main() {
  if (process.argv.length > 2)
    throw new Error("用法: comics:sync（不接受参数）");
  const comics = scan();
  await seed(comics);
  await clearCache(true);
}

void main().catch((err) => {
  console.error("同步失败:", err);
  process.exitCode = 1;
});
