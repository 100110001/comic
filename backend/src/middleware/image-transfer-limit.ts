import type { RequestHandler } from "express";

/** 原图传输共享额度；等待期间不进入静态文件处理，不提前打开文件。 */
export function imageTransferLimit({
  concurrency = 1,
  maxQueued = 256,
  waitMs = 60_000,
  transferMs = 120_000,
} = {}): RequestHandler {
  if (
    ![concurrency, maxQueued, waitMs, transferMs].every(
      (value) => Number.isSafeInteger(value) && value > 0,
    )
  ) {
    throw new Error("图片传输额度与超时必须为正整数");
  }
  let active = 0;
  const waiting = new Set<() => void>();

  function drain() {
    while (active < concurrency && waiting.size > 0) {
      const start = waiting.values().next().value!;
      waiting.delete(start);
      start();
    }
  }

  return (req, res, next) => {
    if (res.destroyed || req.aborted) return;
    const unavailable = () => {
      res.setHeader("Retry-After", "1");
      res.setHeader("Cache-Control", "no-store");
      res.status(503).json({ code: 503, message: "图片加载繁忙，请稍后重试" });
    };
    if (active >= concurrency && waiting.size >= maxQueued) {
      unavailable();
      return;
    }

    let started = false;
    let settled = false;
    let timer: ReturnType<typeof setTimeout> | undefined;

    function release() {
      if (settled) return;
      settled = true;
      clearTimeout(timer);
      res.off("finish", release);
      res.off("close", release);
      waiting.delete(start);
      if (started) active--;
      drain();
    }

    function start() {
      if (settled) return;
      clearTimeout(timer);
      if (res.destroyed || req.aborted) {
        release();
        return;
      }
      started = true;
      active++;
      // 慢连接也不能永久占住所有后续图片的额度。
      timer = setTimeout(() => res.destroy(), transferMs);
      timer.unref();
      next();
    }

    res.once("finish", release);
    res.once("close", release);
    if (active < concurrency) {
      start();
    } else {
      waiting.add(start);
      timer = setTimeout(() => {
        release();
        if (!res.destroyed) unavailable();
      }, waitMs);
      timer.unref();
    }
  };
}
