import fs from 'fs';
import path from 'path';

const COMIC_ROOT = 'E:\\comic';
const IMAGE_EXTS = new Set(['.jpg', '.jpeg', '.png', '.webp', '.gif', '.avif']);

interface ImageFile {
  filename: string;
  path: string;
}

interface Chapter {
  name: string;
  path: string;
  images: ImageFile[];
}

interface Comic {
  name: string;
  path: string;
  chapters: Chapter[];
}

function collectImages(dir: string): ImageFile[] {
  return fs.readdirSync(dir).sort()
    .filter(f => {
      const fullPath = path.join(dir, f);
      return fs.statSync(fullPath).isFile() && IMAGE_EXTS.has(path.extname(f).toLowerCase());
    })
    .map(f => ({ filename: f, path: path.join(dir, f) }));
}

function scanComics(root: string): Comic[] {
  const comics: Comic[] = [];

  for (const comicName of fs.readdirSync(root)) {
    if (comicName.startsWith('.')) continue;
    const comicPath = path.join(root, comicName);
    if (!fs.statSync(comicPath).isDirectory()) continue;

    const comic: Comic = { name: comicName, path: comicPath, chapters: [] };
    const entries = fs.readdirSync(comicPath);

    // 检测漫画根目录是否直接含有图片（无章节层）
    const rootImages = collectImages(comicPath);
    if (rootImages.length > 0) {
      comic.chapters.push({ name: '默认', path: comicPath, images: rootImages });
    }

    for (const chapterName of entries) {
      const chapterPath = path.join(comicPath, chapterName);
      if (!fs.statSync(chapterPath).isDirectory()) continue;

      const images = collectImages(chapterPath);
      if (images.length > 0) {
        comic.chapters.push({ name: chapterName, path: chapterPath, images });
      }
    }

    if (comic.chapters.length > 0) {
      comics.push(comic);
    }
  }

  return comics;
}

function printTree(comics: Comic[]) {
  let totalChapters = 0;
  let totalImages = 0;

  for (const comic of comics) {
    console.log(`\n📚 ${comic.name}`);
    for (const chapter of comic.chapters) {
      console.log(`  📂 ${chapter.name}  (${chapter.images.length} 张)`);
      totalChapters++;
      totalImages += chapter.images.length;
    }
  }

  console.log(`\n─────────────────────────────`);
  console.log(`漫画: ${comics.length}  章节: ${totalChapters}  图片: ${totalImages}`);
}

const OUTPUT = path.join(__dirname, '../../data/scan.json');

const comics = scanComics(COMIC_ROOT);
printTree(comics);

fs.mkdirSync(path.dirname(OUTPUT), { recursive: true });
fs.writeFileSync(OUTPUT, JSON.stringify(comics, null, 2), 'utf-8');
console.log(`\n已保存到 ${OUTPUT}`);
