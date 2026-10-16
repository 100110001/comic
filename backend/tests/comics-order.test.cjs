const { test } = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const vm = require("node:vm");
const { createRequire } = require("node:module");
const knex = require("knex");

// 使用真实查询构造器编译 SQL，拦截执行，测试不访问业务数据库或 Redis。
function routeFixture() {
  const builder = knex({ client: "mysql2" });
  const queries = [];
  const handlers = [];
  const identities = [];
  const db = (table) => {
    const query = builder(table);
    query.then = (resolve, reject) => {
      const sql = query.toSQL();
      queries.push(sql);
      const result = sql.sql.includes("count(distinct")
        ? { total: 12 }
        : [{ id: 4 }, { id: 3 }];
      return Promise.resolve(result).then(resolve, reject);
    };
    return query;
  };
  db.raw = builder.raw.bind(builder);
  const router = {
    get: (route, ...middleware) => {
      if (route === "/") handlers.push(...middleware);
    },
    post() {}, put() {}, delete() {},
  };
  const filename = path.resolve(__dirname, "../dist/routes/comics.js");
  const originalRequire = createRequire(filename);
  const module = { exports: {} };
  vm.runInNewContext(fs.readFileSync(filename, "utf8"), {
    exports: module.exports,
    module,
    require: (name) => {
      if (name === "express") return { Router: () => router };
      if (name === "../db/knex") return { db };
      if (name === "../db/redis") return {};
      if (name === "../config") return { config: {} };
      if (name === "../services/comic-directory") return {};
      if (name === "../middleware/api-cache") return {
        cacheResponse: (identity) => (req, _res, next) => {
          identities.push(JSON.stringify(identity(req)));
          next();
        },
      };
      return originalRequire(name);
    },
  }, { filename });
  return {
    queries,
    identities,
    async request(query) {
      let body;
      const req = { query };
      const res = { json(value) { body = value; }, status() { return this; } };
      handlers[0](req, res, () => {});
      await handlers[1](req, res);
      assert.equal(body.code, 0);
      return queries.at(-1);
    },
  };
}

test("最近入库按时间与 ID 降序，保留过滤及分页，缓存身份隔离", async () => {
  const route = routeFixture();
  const query = await route.request({ sort: "recent", keyword: "漫画", pageOffset: "2", pageSize: "2" });
  assert.match(query.sql, /order by `comics`\.`created_at` desc, `comics`\.`id` desc/);
  assert.match(query.sql, /where `comics`\.`title` like \? or `comics`\.`author` like \?/);
  assert.deepEqual(query.bindings, ["%漫画%", "%漫画%", 2, 2]);
  const recentIdentity = route.identities.at(-1);
  const title = await route.request({ keyword: "漫画", pageOffset: "2", pageSize: "2" });
  assert.match(title.sql, /order by `comics`\.`title` asc/);
  assert.notEqual(route.identities.at(-1), recentIdentity);
  const random = await route.request({ random: "1", seed: "123", sort: "recent" });
  assert.match(random.sql, /order by RAND\(\?\)/);
  assert.doesNotMatch(random.sql, /`created_at` desc/);
});
