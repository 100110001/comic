const { test } = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const vm = require("node:vm");

function fixture({ comics = [], chapters = [], images = [], fail } = {}) {
  const state = structuredClone({ comics, chapters, images });
  const calls = [];
  const reads = [];
  const dimensions = new Map();
  const logs = [];
  let active = 0;
  let maxActive = 0;
  let closed = 0;
  let nextId = 10000;
  async function run(sql, params = []) {
    calls.push({ sql, params: [...params] });
    if (fail?.(sql, params, calls)) throw new Error("数据库失败");
    if (sql === "SELECT id, cover_path, author FROM comics WHERE title = ?") {
      return [state.comics.filter(c => c.title.toLowerCase() === params[0].toLowerCase()).map(c => ({ ...c }))];
    }
    if (sql === "SELECT id, title, author FROM comics") return [structuredClone(state.comics)];
    if (sql.startsWith("SELECT id, comic_id, title, sort_order FROM chapters")) {
      return [structuredClone(state.chapters.filter(c => params.includes(c.comic_id)))];
    }
    if (sql.includes("FROM images INNER JOIN chapters")) {
      const chapterFilter = sql.includes("AND images.chapter_id");
      const comicIds = chapterFilter ? params.slice(0, -1) : params;
      const ids = new Set(state.chapters.filter(c => comicIds.includes(c.comic_id)).map(c => c.id));
      return [structuredClone(state.images.filter(i => ids.has(i.chapter_id) && (!chapterFilter || i.chapter_id === params.at(-1))))];
    }
    if (sql.startsWith("INSERT INTO comics")) {
      const id = nextId++;
      state.comics.push({ id, title: params[0], author: params[1], cover_path: params[2], created_at: "新记录" });
      return [{ insertId: id }];
    }
    if (sql.startsWith("UPDATE comics")) {
      state.comics.find(c => c.id === params[1]).cover_path = params[0];
      return [{}];
    }
    if (sql.startsWith("INSERT INTO chapters")) {
      const id = nextId++;
      state.chapters.push({ id, comic_id: params[0], title: params[1], sort_order: params[2] });
      return [{ insertId: id }];
    }
    if (sql.startsWith("INSERT INTO images")) {
      assert.equal(params.length % 6, 0);
      assert(params.length / 6 <= 200);
      for (let p = 0; p < params.length; p += 6) {
        const [chapter_id, filename, imagePath, page_number, width, height] = params.slice(p, p + 6);
        assert(!state.images.some(i => i.chapter_id === chapter_id && i.filename === filename), "不得重复插入已有图片");
        state.images.push({ id: nextId++, chapter_id, filename, path: imagePath, page_number, width, height });
      }
      return [{}];
    }
    if (sql.startsWith("UPDATE images SET") || sql.startsWith("UPDATE chapters SET")) {
      const table = sql.startsWith("UPDATE images") ? "images" : "chapters";
      const columns = [...sql.matchAll(/(\w+) = CASE id/g)].map(m => m[1]);
      const count = params.length / (columns.length * 2 + 1);
      assert(Number.isInteger(count) && count > 0 && count <= 200);
      const ids = params.slice(-count);
      columns.forEach((column, c) => {
        for (let i = 0; i < count; i++) {
          const offset = c * count * 2 + i * 2;
          assert.equal(params[offset], ids[i]);
          const row = state[table].find(r => r.id === ids[i]);
          assert(row, "只能更新已有主键");
          row[column] = params[offset + 1];
        }
      });
      return [{}];
    }
    throw new Error("未处理 SQL: " + sql);
  }
  const conn = { execute: run, query: run, end: async () => { closed++; } };
  const module = { exports: {} };
  const filename = path.resolve(__dirname, "../dist/scripts/seed.js");
  vm.runInNewContext(fs.readFileSync(filename, "utf8"), {
    module, exports: module.exports, process: { env: {} },
    console: { log: text => logs.push(text) },
    require(name) {
      if (name === "mysql2/promise") return { createConnection: async () => conn };
      if (name === "dotenv") return { config() {} };
      if (name === "../utils/progress") return { progress() {}, done: text => logs.push(text) };
      if (name === "../utils/image-metadata") return { readImageDimensions: async imagePath => {
        reads.push(imagePath);
        maxActive = Math.max(maxActive, ++active);
        await Promise.resolve();
        active--;
        const result = dimensions.get(imagePath);
        if (result === null) throw new Error("无法读取尺寸");
        return result ?? { width: 800, height: 1200 };
      } };
      throw new Error("意外依赖: " + name);
    },
  }, { filename });
  return {
    state, calls, reads, dimensions, logs,
    seed: module.exports.seed,
    get closed() { return closed; },
    get maxActive() { return maxActive; },
    writes: () => calls.filter(c => /^(INSERT|UPDATE)/.test(c.sql)),
  };
}

function book(count, chapterCount = 1) {
  return { title: "漫画", author: null, path: "/book", name: "漫画",
    chapters: Array.from({ length: chapterCount }, (_, c) => ({
      name: "第" + c + "章", path: "/book/" + c,
      images: Array.from({ length: count }, (_, i) => ({ filename: i + ".jpg", path: "/book/" + c + "/" + i + ".jpg" })),
    })),
  };
}

test("401 张新图片分三批写入空尺寸，重导入零写入且不读取尺寸", async () => {
  const h = fixture();
  const input = book(401);
  await h.seed([input]);
  assert.equal(h.state.images.length, 401);
  assert.equal(h.writes().filter(c => c.sql.startsWith("INSERT INTO images")).length, 3);
  assert.equal(h.writes().filter(c => c.sql.startsWith("UPDATE images")).length, 0);
  assert(h.state.images.every(i => i.width === null && i.height === null));
  assert.equal(h.reads.length, 0);
  h.state.images[0].width = 800;
  h.state.images[0].height = 1200;
  assert.match(h.logs.at(-1), /新增漫画: 1  新增章节: 1  新增图片: 401/);
  const before = structuredClone(h.state);
  h.calls.length = 0; h.reads.length = 0;
  await h.seed([input]);
  assert.equal(h.writes().length, 0);
  assert.equal(h.reads.length, 0);
  assert.equal(h.maxActive, 0);
  assert.equal(input.chapters[0].images[0].width, 800);
  assert.equal(input.chapters[0].images[0].height, 1200);
  assert.equal(input.chapters[0].images[1].width, null);
  assert.deepEqual(h.state, before);
  assert.equal(h.closed, 2);
});

test("图片按漫画集中查询，保留缺失索引、ID与入库时间，NULL尺寸不重复写", async () => {
  const h = fixture();
  const input = book(2, 3);
  h.dimensions.set("/book/1/1.jpg", null);
  await h.seed([input]);
  h.state.comics.push({ id: 99, title: "磁盘缺失", author: null });
  h.state.images.push({ id: 88, chapter_id: h.state.chapters[0].id, filename: "旧.jpg", path: "/missing", page_number: 9 });
  const before = structuredClone(h.state);
  h.calls.length = 0; h.reads.length = 0;
  await h.seed([input]);
  assert.equal(h.calls.filter(c => c.sql.includes("FROM images INNER JOIN chapters")).length, 1);
  assert.equal(h.writes().length, 0);
  assert.equal(h.reads.length, 0);
  assert.deepEqual(h.state, before);
  assert(h.logs.some(log => log.includes("[missing]") && log.includes("磁盘缺失")));
});

test("路径变化清空尺寸，页码重排保留已知尺寸，章节重排只写变化项", async () => {
  const h = fixture();
  const input = book(3, 3);
  await h.seed([input]);
  h.state.images.forEach(image => { image.width = 800; image.height = 1200; });
  const ids = h.state.images.map(i => i.id);
  const firstChapter = h.state.chapters[0].id;
  input.chapters[0].images.reverse();
  input.chapters[0].images[1].path = "/new-path.jpg";
  h.dimensions.set("/book/0/2.jpg", { width: 600, height: 900 });
  h.dimensions.set("/new-path.jpg", null);
  [input.chapters[0], input.chapters[1]] = [input.chapters[1], input.chapters[0]];
  h.calls.length = 0;
  await h.seed([input]);
  assert.equal(h.writes().filter(c => c.sql.startsWith("INSERT")).length, 0);
  const updates = h.writes().filter(c => c.sql.startsWith("UPDATE images"));
  assert.equal(updates.length, 1);
  assert.equal(updates[0].params.length / 9, 3);
  const rows = h.state.images.filter(i => i.chapter_id === firstChapter);
  assert.deepEqual(rows.map(i => i.page_number), [2, 1, 0]);
  assert.equal(rows[1].path, "/new-path.jpg");
  assert.equal(rows[1].width, null);
  assert.equal(rows[1].height, null);
  assert.equal(rows[2].width, 800);
  assert.equal(rows[2].height, 1200);
  assert.equal(h.reads.length, 0);
  assert.deepEqual(h.state.images.map(i => i.id), ids);
  const chapterUpdate = h.writes().find(c => c.sql.startsWith("UPDATE chapters"));
  assert.equal(chapterUpdate.params.length / 3, 2);
  assert.deepEqual(h.state.chapters.map(c => c.sort_order), [1, 0, 2]);
});

test("401 条变化图片的 CASE 批次正确覆盖尾批，字符串不拼入 SQL", async () => {
  const h = fixture();
  const input = book(401);
  await h.seed([input]);
  input.chapters[0].images.forEach((img, i) => { img.path = "/new/'中文?/" + i; });
  h.calls.length = 0;
  await h.seed([input]);
  const updates = h.writes().filter(c => c.sql.startsWith("UPDATE images"));
  assert.deepEqual(updates.map(c => c.params.length / 9), [200, 200, 1]);
  assert(updates.every(c => !c.sql.includes("中文")));
  assert.deepEqual(h.state.images.map(i => i.path), input.chapters[0].images.map(i => i.path));
});

test("重复已有章节后一次读取前次写入，同名图片不重复插入", async () => {
  const h = fixture();
  const input = book(1);
  await h.seed([input]);
  input.chapters[0].images.push({ filename: "新增.jpg", path: "/first.jpg" });
  input.chapters.push({ name: "第0章", path: "/second", images: [{ filename: "新增.jpg", path: "/second.jpg" }] });
  h.calls.length = 0;
  await h.seed([input]);
  assert.equal(h.state.images.length, 2);
  const row = h.state.images.find(i => i.filename === "新增.jpg");
  assert.equal(row.path, "/second.jpg");
  assert.equal(row.page_number, 0);
  assert.equal(h.state.chapters[0].sort_order, 1);
  assert.equal(h.calls.filter(c => c.sql.includes("FROM images INNER JOIN chapters")).length, 2);
});

test("批次失败停止并关闭连接，成功批次保留且全程不探测图片", async () => {
  let inserts = 0;
  const h = fixture({ fail: sql => sql.startsWith("INSERT INTO images") && ++inserts === 2 });
  await assert.rejects(h.seed([book(401)]), /数据库失败/);
  assert.equal(h.state.images.length, 200);
  assert.equal(h.reads.length, 0);
  assert.equal(h.closed, 1);
  assert(!h.logs.some(log => log.includes("导入完成")));
});

test("章节和图片按二十本分组查询，重复漫画仍能看到前次写入", async () => {
  const h = fixture();
  const inputs = Array.from({length: 41}, (_, i) => ({...book(1), title: `漫画${i}`}));
  await h.seed(inputs);
  assert.equal(h.state.images.length, 41);
  assert.equal(h.calls.filter(c => c.sql.includes("FROM images INNER JOIN chapters")).length, 3);
  assert.equal(h.calls.filter(c => c.sql.startsWith("SELECT id, comic_id")).length, 3);
  h.calls.length = 0;
  await h.seed(inputs);
  assert.equal(h.writes().length, 0);
  const duplicate = structuredClone(inputs[0]);
  duplicate.chapters[0].images[0].path = "/changed.jpg";
  await h.seed([inputs[0], duplicate]);
  assert.equal(h.state.images.length, 41);
  assert.equal(h.state.images[0].path, "/changed.jpg");
});

