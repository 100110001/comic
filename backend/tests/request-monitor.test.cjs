const assert = require("node:assert/strict");
const { EventEmitter } = require("node:events");
const { test } = require("node:test");
const {
  observeRequests,
  requestSnapshot,
} = require("../dist/services/request-monitor");

test("请求记录循环覆盖后仍按完成顺序倒排，累计统计和既有快照不受淘汰影响", () => {
  assert.deepEqual(requestSnapshot().records, []);
  let retained;
  for (let id = 1; id <= 1001; id++) {
    const response = Object.assign(new EventEmitter(), {
      writableFinished: true,
      statusCode: 200,
      locals: {},
      getHeader: () => "10",
    });
    observeRequests(
      { path: `/api/comics/${id}`, method: "GET" },
      response,
      () => {},
    );
    response.emit("finish");
    response.emit("close");
    if ([1, 499, 500, 501, 1000, 1001].includes(id)) {
      const snapshot = requestSnapshot();
      assert.deepEqual(
        snapshot.records.map((entry) => entry.id),
        Array.from({ length: Math.min(id, 500) }, (_, index) => id - index),
      );
      assert.equal(snapshot.total, id);
      assert.equal(snapshot.totals.api.requests, id);
      assert.equal(snapshot.totals.api.bytes, id * 10);
      if (id === 500) retained = snapshot.records;
    }
  }
  assert.equal(retained.length, 500);
  assert.equal(retained[0].id, 500);
  assert.equal(retained[499].id, 1);
});
