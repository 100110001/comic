const { test } = require("node:test");
const assert = require("node:assert/strict");
const { once } = require("node:events");
const http = require("node:http");
const { mkdtemp, writeFile, rm } = require("node:fs/promises");
const { tmpdir } = require("node:os");
const path = require("node:path");
const express = require("express");
const {
  imageTransferLimit,
} = require("../dist/middleware/image-transfer-limit");

async function until(predicate) {
  const deadline = Date.now() + 3000;
  while (!predicate()) {
    assert(Date.now() < deadline, "等待请求状态超时");
    await new Promise((resolve) => setTimeout(resolve, 5));
  }
}

async function listen(t, app) {
  const server = app.listen(0, "127.0.0.1");
  await once(server, "listening");
  t.after(async () => {
    server.closeAllConnections();
    await new Promise((resolve) => server.close(resolve));
  });
  return `http://127.0.0.1:${server.address().port}`;
}

async function controlled(t, options) {
  const app = express();
  const arrived = [];
  const entered = new Map();
  app.use("/static", (req, _res, next) => {
    arrived.push(req.path);
    next();
  });
  app.use("/static", imageTransferLimit(options), (req, res) => {
    entered.set(req.path, res);
  });
  app.get("/api/health", (_req, res) => res.send("ok"));
  const base = await listen(t, app);
  return {
    arrived,
    entered,
    base,
    get: (id, init) => fetch(`${base}/static/${id}`, init),
  };
}

test("原图串行且按到达顺序继续，普通 API 不等待", async (t) => {
  const h = await controlled(t);
  const first = h.get("a");
  await until(() => h.entered.has("/a"));
  const second = h.get("b");
  await until(() => h.arrived.length === 2);
  const third = h.get("c");
  await until(() => h.arrived.length === 3);
  assert.equal(h.entered.size, 1);
  assert.equal(await (await fetch(`${h.base}/api/health`)).text(), "ok");
  h.entered.get("/a").end("a");
  assert.equal(await (await first).text(), "a");
  await until(() => h.entered.has("/b"));
  assert.equal(h.entered.size, 2);
  h.entered.get("/b").status(500).end("error");
  assert.equal((await second).status, 500);
  await until(() => h.entered.has("/c"));
  h.entered.get("/c").end("c");
  assert.equal(await (await third).text(), "c");
});

test("可配置两张并发且不会启动第三张", async (t) => {
  const h = await controlled(t, { concurrency: 2 });
  const requests = [h.get("a")];
  await until(() => h.entered.has("/a"));
  requests.push(h.get("b"));
  await until(() => h.entered.has("/b"));
  requests.push(h.get("c"));
  await until(() => h.arrived.length === 3);
  assert.equal(h.entered.size, 2);
  h.entered.get("/a").end();
  await until(() => h.entered.has("/c"));
  h.entered.get("/b").end();
  h.entered.get("/c").end();
  await Promise.all(requests);
});

test("取消等待者不打开文件，取消活动传输继续下一张", async (t) => {
  const h = await controlled(t, { maxQueued: 1 });
  const active = new AbortController();
  const first = assert.rejects(h.get("a", { signal: active.signal }));
  await until(() => h.entered.has("/a"));
  const queued = new AbortController();
  const second = assert.rejects(h.get("b", { signal: queued.signal }));
  await until(() => h.arrived.length === 2);
  queued.abort();
  await second;
  // 让服务端处理连接关闭事件。
  await new Promise((resolve) => setTimeout(resolve, 30));
  const third = h.get("c");
  await until(() => h.arrived.length === 3);
  active.abort();
  await first;
  await until(() => h.entered.has("/c"));
  assert.equal(h.entered.has("/b"), false);
  h.entered.get("/c").end("c");
  assert.equal(await (await third).text(), "c");
});

test("队列满载与等待超时返回不缓存的 503，不进入静态处理", async (t) => {
  const h = await controlled(t, { maxQueued: 1, waitMs: 100 });
  const first = h.get("a");
  await until(() => h.entered.has("/a"));
  const second = h.get("b");
  await until(() => h.arrived.length === 2);
  const full = await h.get("c");
  assert.equal(full.status, 503);
  assert.equal(full.headers.get("retry-after"), "1");
  assert.equal(full.headers.get("cache-control"), "no-store");
  assert.equal((await second).status, 503);
  assert.equal(h.entered.size, 1);
  h.entered.get("/a").end();
  await first;
  const retry = h.get("b");
  await until(() => h.entered.has("/b"));
  h.entered.get("/b").end();
  assert.equal((await retry).status, 200);
});

test("活动传输超时断开并释放额度", async (t) => {
  const h = await controlled(t, { transferMs: 150 });
  const first = assert.rejects(h.get("a"));
  await until(() => h.entered.has("/a"));
  const second = h.get("b");
  await first;
  await until(() => h.entered.has("/b"));
  h.entered.get("/b").end();
  assert.equal((await second).status, 200);
});

test("真实静态文件成功、304、404均释放额度并保留缓存语义", async (t) => {
  const directory = await mkdtemp(path.join(tmpdir(), "comic-image-limit-"));
  t.after(() => rm(directory, { recursive: true, force: true }));
  await writeFile(path.join(directory, "page.jpg"), Buffer.alloc(1024, 7));
  const app = express();
  app.use(
    "/static",
    imageTransferLimit(),
    express.static(directory, { maxAge: "1h" }),
  );
  const base = await listen(t, app);
  const image = await fetch(`${base}/static/page.jpg`);
  assert.equal(image.status, 200);
  assert.match(image.headers.get("cache-control"), /max-age=3600/);
  assert.equal((await image.arrayBuffer()).byteLength, 1024);
  const cached = await new Promise((resolve, reject) => {
    http
      .get(
        `${base}/static/page.jpg`,
        {
          headers: { "If-None-Match": image.headers.get("etag") },
        },
        (res) => {
          res.resume();
          res.on("end", () => resolve(res.statusCode));
        },
      )
      .on("error", reject);
  });
  assert.equal(cached, 304);
  assert.equal((await fetch(`${base}/static/missing.jpg`)).status, 404);
  assert.equal((await fetch(`${base}/static/page.jpg`)).status, 200);
});
