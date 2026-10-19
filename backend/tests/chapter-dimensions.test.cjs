const { test } = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const fsp = require("node:fs/promises");
const os = require("node:os");
const path = require("node:path");
const vm = require("node:vm");
const { createRequire } = require("node:module");

async function fixture(t, count = 1) {
  const root = await fsp.mkdtemp(path.join(os.tmpdir(), "comic-dimensions-"));
  t.after(() => fsp.rm(root, { recursive: true, force: true }));
  let version = 1700000000;
  async function write(file, width, height) {
    const data = Buffer.alloc(16);
    data.write("GIF89a"); data.writeUInt16LE(width, 6); data.writeUInt16LE(height, 8);
    await fsp.writeFile(file, data);
    await fsp.utimes(file, ++version, version);
  }
  const rows = [];
  for (let i = 0; i < count; i++) {
    const file = path.join(root, `${i}.gif`);
    await write(file, 320, 480);
    rows.push({ id: i + 1, chapter_id: 1, filename: `${i}.gif`, path: file, page_number: i, width: null, height: null });
  }
  const state = { reads: 0, writes: 0, onRead: null, deleted: false };
  const cache = new Map();
  function db(table) {
    let filters = {};
    let update;
    let first = false;
    const query = {
      where(value) { filters = { ...filters, ...value }; return this; },
      whereNull(key) { filters[key] = null; return this; },
      select() { return this; }, orderBy() { return this; },
      first() { first = true; return this; },
      update(value) { update = value; return this; },
      then(resolve, reject) {
        const selected = (table === "chapters" ? [{ id: 1, comic_id: 1 }] : table === "comics" ? [{ id: 1, deleted_at: state.deleted ? "已删除" : null }] : rows)
          .filter(row => Object.entries(filters).every(([key, value]) => row[key] === value));
        let result;
        if (update) {
          selected.forEach(row => Object.assign(row, update));
          state.writes += selected.length;
          result = selected.length;
        } else result = structuredClone(first ? selected[0] : selected);
        return Promise.resolve(result).then(resolve, reject);
      },
    };
    return query;
  }
  let handler;
  const filename = path.resolve(__dirname, "../dist/routes/chapters.js");
  const originalRequire = createRequire(filename);
  const metadata = originalRequire("../utils/image-metadata");
  const module = { exports: {} };
  vm.runInNewContext(fs.readFileSync(filename, "utf8"), {
    module, exports: module.exports, console,
    require(name) {
      if (name === "express") return { Router: () => ({ get(_path, callback) { handler = callback; } }) };
      if (name === "../db/knex") return { db };
      if (name === "../config") return { config: { comicRoot: root } };
      if (name === "../db/redis") return {
        cacheGet: async key => ({ generation: "test", value: cache.get(key) ?? null }),
        cacheSet: async (key, value) => { cache.set(key, structuredClone(value)); },
      };
      if (name === "../utils/image-metadata") return {
        ...metadata,
        readImageDimensions: async file => {
          state.reads++;
          const result = await metadata.readImageDimensions(file);
          if (state.onRead) await state.onRead(file);
          return result;
        },
      };
      return originalRequire(name);
    },
  }, { filename });
  return {
    rows, state, cache, write,
    async request(expectedCode = 0, query = {}) {
      let body;
      const res = { locals: {}, setHeader() {}, status() { return this; }, json(value) { body = value; } };
      await handler({ params: { id: "1" }, query }, res);
      assert.equal(body.code, expectedCode);
      return body.data;
    },
  };
}

test("阅读补齐真实图片尺寸，同名替换绕过旧缓存，未变化不再探测和写入", async t => {
  const h = await fixture(t);
  let data = await h.request();
  assert.equal(data[0].width, 320);
  assert.equal(h.rows[0].height, 480);
  assert.equal(h.state.reads, 1);
  await h.request();
  await h.request();
  assert.equal(h.state.reads, 1);
  assert.equal(h.state.writes, 1);
  const oldUrl = data[0].url;
  await h.write(h.rows[0].path, 640, 960);
  data = await h.request();
  assert.equal(data[0].width, 640);
  assert.equal(h.rows[0].height, 960);
  assert.notEqual(data[0].url, oldUrl);
  assert.equal(h.state.reads, 2);
  assert.equal(h.state.writes, 2);
  await h.request();
  assert.equal(h.state.reads, 2);
});

test("软删除漫画即使章节图片已有缓存也不能继续读取，恢复后可读", async t => {
  const h = await fixture(t);
  await h.request();
  const reads = h.state.reads;
  h.state.deleted = true;
  assert.equal(await h.request(1), null);
  assert.equal(h.state.reads, reads);
  h.state.deleted = false;
  assert.equal((await h.request()).length, 1);
});

test("既有尺寸首次使用会验证文件，但相同尺寸不重复更新数据库", async t => {
  const h = await fixture(t);
  h.rows[0].width = 320; h.rows[0].height = 480;
  const data = await h.request();
  assert.equal(data[0].width, 320);
  assert.equal(h.state.reads, 1);
  assert.equal(h.state.writes, 0);
});

test("读取期间文件变化或数据库路径变化，不回写过期尺寸", async t => {
  const h = await fixture(t);
  h.state.onRead = file => h.write(file, 640, 960);
  let data = await h.request();
  assert.equal(data[0].width, null);
  assert.equal(h.state.writes, 0);
  h.state.onRead = () => { h.rows[0].path += ".moved"; };
  data = await h.request();
  assert.equal(data[0].width, null);
  assert.equal(h.state.writes, 0);
});

test("大章节先返回前十六张尺寸，其余后台补齐，下一次读取获得完整尺寸", async t => {
  const h = await fixture(t, 20);
  let release;
  const gate = new Promise(resolve => { release = resolve; });
  h.state.onRead = async file => {
    if (Number(path.basename(file, ".gif")) >= 16) await gate;
  };
  const first = await h.request();
  assert.equal(first.filter(image => image.width === 320).length, 16);
  release();
  for (let attempt = 0; attempt < 200 && h.rows.some(row => row.width == null); attempt++)
    await new Promise(resolve => setTimeout(resolve, 5));
  assert(h.rows.every(row => row.width === 320));
  const second = await h.request();
  assert(second.every(image => image.width === 320));
  assert.equal(h.state.reads, 20);
});


test("定向补齐只读取请求窗口并写入数据库，不污染整章缓存", async t => {
  const h = await fixture(t, 24);
  const data = await h.request(0, { dimensions: "20,21" });
  assert.deepEqual(data.map(image => image.id), [20, 21]);
  assert.equal(h.state.reads, 2);
  assert.equal(h.rows[19].width, 320);
  assert.equal(h.rows[0].width, null);
  assert.equal((await h.request()).length, 24);
});

test("定向补齐拒绝重复、越界和过大窗口", async t => {
  const h = await fixture(t, 24);
  for (const dimensions of ["1,1", "25", Array.from({ length: 12 }, (_, i) => i + 1).join(",")]) {
    await h.request(1, { dimensions });
  }
  assert.equal(h.state.reads, 0);
});
