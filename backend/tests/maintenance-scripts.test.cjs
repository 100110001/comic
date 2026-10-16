const { test } = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const os = require("node:os");
const path = require("node:path");
const { spawnSync } = require("node:child_process");
const { organizeComic } = require("../dist/scripts/organize");
const { listeningPids } = require("../dist/scripts/kill-port");
const { scanComics } = require("../dist/scripts/scan");
const { resolveComicDirectory } = require("../dist/services/comic-directory");
const vm = require("node:vm");

function fixture(t) {
  const prefix = path.join(os.tmpdir(), "comic-maintenance-");
  const root = fs.mkdtempSync(prefix);
  t.after(() => {
    assert.ok(path.resolve(root).startsWith(path.resolve(prefix)));
    fs.rmSync(root, { recursive: true, force: true });
  });
  return root;
}

test("整理预览不写入，实际执行先展开再归章，重复执行不改变结果", (t) => {
  const root = fixture(t);
  fs.mkdirSync(path.join(root, "original"));
  fs.writeFileSync(path.join(root, "original", "001.jpg"), "image");
  assert.equal(organizeComic(root, true), 0);
  assert.deepEqual(fs.readdirSync(root), ["original"]);
  assert.equal(organizeComic(root, false), 0);
  assert.equal(fs.readFileSync(path.join(root, "第1話", "001.jpg"), "utf8"), "image");
  assert.equal(organizeComic(root, false), 0);
  assert.deepEqual(fs.readdirSync(root), ["第1話"]);
});

test("同名冲突不覆盖，保留 original；已有子目录不归章", (t) => {
  const root = fixture(t);
  fs.mkdirSync(path.join(root, "original"));
  fs.writeFileSync(path.join(root, "original", "001.jpg"), "source");
  fs.writeFileSync(path.join(root, "001.jpg"), "target");
  assert.equal(organizeComic(root, false), 1);
  assert.equal(fs.readFileSync(path.join(root, "original", "001.jpg"), "utf8"), "source");
  assert.equal(fs.readFileSync(path.join(root, "001.jpg"), "utf8"), "target");
  assert.equal(fs.existsSync(path.join(root, "第1話")), false);
});

test("明确指定漫画目录不依赖 COMIC_ROOT，拒绝混用目标和未知参数", (t) => {
  const root = fixture(t);
  fs.writeFileSync(path.join(root, "001.jpg"), "image");
  const run = (args) => spawnSync(process.execPath, [path.join(__dirname, "../dist/scripts/organize.js"), ...args], {
    env: { ...process.env, COMIC_ROOT: path.join(root, "missing") }, encoding: "utf8",
  });
  assert.equal(run(["--comic", root, "--dry-run"]).status, 0);
  assert.equal(run(["--comic", root, "--root", root]).status, 1);
  assert.equal(run(["--comic", root, "--dryrun"]).status, 1);
  assert.deepEqual(fs.readdirSync(root), ["001.jpg"]);
});

test("端口精确匹配、IPv4/IPv6 去重，不匹配远端端口或端口前缀", () => {
  const output = [
    "TCP 0.0.0.0:8888 0.0.0.0:0 LISTENING 101",
    "TCP [::]:8888 [::]:0 LISTENING 101",
    "TCP 0.0.0.0:88880 0.0.0.0:0 LISTENING 102",
    "TCP 127.0.0.1:9000 127.0.0.1:8888 ESTABLISHED 103",
    "UDP 0.0.0.0:8888 *:* 104",
  ].join("\n");
  assert.deepEqual(listeningPids(output, 8888), [101]);
});

test("链接漫画库保留配置路径，图片相对路径与打开目录校验兼容", async (t) => {
  const root = fixture(t);
  const actual = path.join(root, "actual");
  const alias = path.join(root, "alias");
  fs.mkdirSync(path.join(actual, "book"), { recursive: true });
  fs.writeFileSync(path.join(actual, "book", "001.jpg"), "image");
  fs.symlinkSync(actual, alias, process.platform === "win32" ? "junction" : "dir");
  try {
    const comic = scanComics(alias)[0];
    const chapter = comic.chapters[0];
    const image = chapter.images[0];
    assert.equal(comic.path, path.join(alias, "book"));
    assert.equal(chapter.path, path.join(alias, "book"));
    assert.equal(image.path, path.join(alias, "book", "001.jpg"));
    assert.equal(path.relative(alias, image.path), path.join("book", "001.jpg"));
    assert.equal(fs.readFileSync(image.path, "utf8"), "image");
    assert.equal(await resolveComicDirectory(alias, image.path), fs.realpathSync(path.join(actual, "book")));
  } finally {
    fs.unlinkSync(alias);
  }
});

for (const platform of ["linux", "darwin"]) {
  test(`${platform} 运行端口清理入口成功跳过，不执行系统命令`, () => {
    const entry = { exports: {} };
    const fakeProcess = { platform, pid: 12345, exitCode: 0 };
    const messages = [];
    let systemCalls = 0;
    const isolatedRequire = (id) => {
      if (id === "child_process") return { execFileSync() {
        systemCalls++;
        throw new Error("测试不允许执行系统命令");
      } };
      if (id === "../config") return { config: { port: 8888 } };
      throw new Error(`未预期的模块: ${id}`);
    };
    isolatedRequire.main = entry;
    vm.runInNewContext(fs.readFileSync(path.join(__dirname, "../dist/scripts/kill-port.js"), "utf8"), {
      require: isolatedRequire, module: entry, exports: entry.exports, process: fakeProcess,
      console: { log: (message) => messages.push(message), error: (message) => messages.push(message) },
    });
    assert.equal(fakeProcess.exitCode, 0);
    assert.equal(systemCalls, 0);
    assert.ok(messages.some((message) => message.includes("跳过自动端口清理")));
  });
}
