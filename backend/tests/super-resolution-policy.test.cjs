const { test } = require("node:test");
const assert = require("node:assert/strict");
const {
  SuperResolutionPolicy,
} = require("../dist/services/super-resolution-policy");

test("短暂负载变化不抖动，持续高压力收缩并保持最少两页", () => {
  const policy = new SuperResolutionPolicy();
  for (let i = 0; i < 20; i++) policy.observe(i % 2 ? 95 : 25, 2000, 8000);
  assert.equal(policy.snapshot().lookahead, 4);
  for (let i = 0; i < 20; i++) policy.observe(95, 7200, 8000);
  assert.equal(policy.snapshot().lookahead, 2);
});

test("空闲且处理快时逐步扩大，始终不超过后十页", () => {
  const policy = new SuperResolutionPolicy();
  policy.recordProcessing(1000);
  const windows = [];
  for (let i = 0; i < 30; i++)
    windows.push(policy.observe(25, 2000, 8000).lookahead);
  assert.equal(windows[0], 4);
  assert.equal(windows.at(-1), 10);
  assert(windows.every((value) => value >= 2 && value <= 10));
  assert(
    windows.every(
      (value, index) => index === 0 || value - windows[index - 1] <= 1,
    ),
  );
});

test("处理较慢限制窗口，显存接近满载无需等待多次采样", () => {
  const slow = new SuperResolutionPolicy();
  slow.recordProcessing(20000);
  for (let i = 0; i < 20; i++) slow.observe(10, 1000, 8000);
  assert.equal(slow.snapshot().lookahead, 2);
  const memory = new SuperResolutionPolicy();
  assert.equal(memory.observe(10, 7800, 8000).lookahead, 2);
});
