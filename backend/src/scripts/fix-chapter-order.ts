import { db } from "../db/knex";
import { compareChapterTitle } from "../utils/chapterSort";

async function main() {
  const comics = await db("comics").select("id", "cover_path");

  let comicsFixed = 0;
  let chaptersFixed = 0;

  for (const comic of comics) {
    const chapters = await db("chapters")
      .select("id", "title", "sort_order")
      .where({ comic_id: comic.id });

    const sorted = [...chapters].sort((a, b) => compareChapterTitle(a.title, b.title));

    for (let i = 0; i < sorted.length; i++) {
      const chapter = sorted[i]!;
      if (chapter.sort_order !== i) {
        await db("chapters").where({ id: chapter.id }).update({ sort_order: i });
        chaptersFixed++;
      }
    }

    const firstChapter = sorted[0];
    if (firstChapter) {
      const firstImage = await db("images")
        .select("path")
        .where({ chapter_id: firstChapter.id })
        .orderBy("page_number")
        .first();

      if (firstImage && firstImage.path !== comic.cover_path) {
        await db("comics")
          .where({ id: comic.id })
          .update({ cover_path: firstImage.path });
        comicsFixed++;
      }
    }
  }

  console.log(
    `修复完成: ${chaptersFixed} 个章节的排序, ${comicsFixed} 个漫画的封面`,
  );
  await db.destroy();
}

main().catch((err) => {
  console.error("修复失败:", err);
  process.exit(1);
});
