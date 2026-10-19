const { test } = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const vm = require("node:vm");
const { createRequire } = require("node:module");
const knex = require("knex");

// 使用真实查询构造器和路由回调，执行仅返回夹具数据。
function fixture(moduleName) {
  const builder = knex({ client: "mysql2" });
  const queries = [];
  const handlers = new Map();
  const db = table => {
    const query = builder(table);
    query.then = (resolve, reject) => {
      const sql = query.toSQL();
      queries.push(sql);
      const result = sql.method === "first" ? undefined :
        sql.sql.includes("`deleted_at` is not null") ? [{ id: 99 }] : [];
      return Promise.resolve(result).then(resolve, reject);
    };
    return query;
  };
  db.raw = builder.raw.bind(builder);
  const router = Object.fromEntries(["get", "post", "put", "delete"].map(method => [
    method, (route, ...callbacks) => handlers.set(`${method} ${route}`, callbacks),
  ]));
  const filename = path.resolve(__dirname, `../dist/routes/${moduleName}.js`);
  const originalRequire = createRequire(filename);
  const module = { exports: {} };
  vm.runInNewContext(fs.readFileSync(filename, "utf8"), {
    exports: module.exports, module, console,
    require(name) {
      if (name === "express") return { Router: () => router };
      if (name === "../db/knex") return { db };
      if (name === "../db/redis") return { invalidateApiCache: async () => {} };
      if (name === "../config") return { config: {} };
      if (name === "../services/comic-directory") return {};
      if (name === "../middleware/api-cache") return { cacheResponse: () => (_req, _res, next) => next() };
      if (name === "./comics") return { comicQuery: () => db("comics").whereNull("comics.deleted_at") };
      return originalRequire(name);
    },
  }, { filename });
  return {
    queries,
    async request(key, body = {}) {
      let response, status = 200;
      const req = { params: { id: "99" }, query: {}, body };
      const res = {
        setHeader() {},
        status(value) { status = value; return this; },
        json(value) { response = value; },
      };
      const callbacks = handlers.get(key);
      assert(callbacks, key);
      for (const callback of callbacks) await callback(req, res, () => {});
      return { response, status };
    },
  };
}

test("旧详情、打开目录、收藏与进度入口拒绝软删除漫画且不写数据", async () => {
  const h = fixture("comics");
  for (const key of ["get /:id", "post /:id/open-directory", "post /:id/favorite", "delete /:id/favorite", "put /:id/progress"]) {
    h.queries.length = 0;
    const result = await h.request(key, { chapterId: 1, pageNumber: 2 });
    assert.equal(result.status, 404, key);
    assert.equal(h.queries.length, 1, key);
    assert.match(h.queries[0].sql, /`(?:comics\.)?deleted_at` is null|`comics`\.`deleted_at` is null/);
    assert(!h.queries.some(q => /^(insert|update|delete)/i.test(q.sql)));
  }
  h.queries.length = 0;
  assert.equal((await h.request("get /random")).status, 200);
  assert.match(h.queries[0].sql, /`comics`\.`deleted_at` is null/);
});

test("最近阅读隐藏删除漫画并附带删除 ID，收藏查询保持过滤", async () => {
  const h = fixture("mine");
  const result = await h.request("get /recent");
  assert.equal(result.status, 200);
  assert.deepEqual(Array.from(result.response.deletedComicIds), [99]);
  assert.match(h.queries[0].sql, /`c`\.`deleted_at` is null/);
  await h.request("get /favorites");
  assert.match(h.queries.at(-1).sql, /`comics`\.`deleted_at` is null/);
});

test("作者作品数只统计可见漫画，LEFT JOIN 保留零作品的收藏作者", async () => {
  const h = fixture("favorite-authors");
  await h.request("get /");
  assert.match(h.queries[0].sql, /left join `comics` as `c` on `c`\.`author` = `fa`\.`author` and `c`\.`deleted_at` is null/);
  assert.doesNotMatch(h.queries[0].sql, /where/);
});

test("旧数据库幂等补充软删除字段，迁移失败也释放连接", async () => {
  const columns = new Set();
  const statements = [];
  let closed = 0;
  let fail = false;
  const filename = path.resolve(__dirname, "../dist/db/init.js");
  const module = { exports: {} };
  const conn = {
    async query(sql) {
      statements.push(sql);
      if (fail) throw new Error("迁移失败");
      const match = sql.match(/ADD COLUMN (\w+)/);
      if (match) columns.add(match[1]);
      return [[]];
    },
    async execute(sql, params) {
      return [[{ cnt: sql.includes("COLUMNS") ? Number(columns.has(params[0])) : 1 }]];
    },
    async end() { closed++; },
  };
  const isolatedRequire = name => {
    if (name === "mysql2/promise") return { createConnection: async () => conn };
    if (name === "dotenv") return { config() {} };
    if (name === "fs") return { readFileSync: () => fs.readFileSync(path.resolve(__dirname, "../src/db/schema.sql"), "utf8") };
    if (name === "path") return path;
    throw new Error(name);
  };
  vm.runInNewContext(fs.readFileSync(filename, "utf8"), {
    exports: module.exports, module, __dirname: path.dirname(filename),
    process: { env: {} }, console: { log() {} }, require: isolatedRequire,
  }, { filename });
  await module.exports.init();
  await module.exports.init();
  assert.deepEqual([...columns].sort(), ["deleted_at", "source_root"]);
  assert.equal(statements.filter(sql => sql.includes("ADD COLUMN")).length, 2);
  assert(!statements.some(sql => sql.replace(/--[^\n]*/g, "").split(";").some(statement => /^\s*(DROP|TRUNCATE|DELETE)\b/i.test(statement))));
  fail = true;
  await assert.rejects(module.exports.init(), /迁移失败/);
  assert.equal(closed, 3);
});
