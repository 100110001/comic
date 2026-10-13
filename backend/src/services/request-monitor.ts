import type { RequestHandler } from "express";

export type RequestCategory = "api" | "image" | "upscale";
type CacheOutcome = "hit" | "miss" | "unavailable" | "unused";
interface RecordEntry {
  id: number;
  category: RequestCategory;
  method: string;
  path: string;
  status: number;
  aborted: boolean;
  requestedAt: string;
  elapsedMs: number;
  bytes: number | null;
  cache: CacheOutcome;
}
const startedAt = new Date().toISOString();
const records: RecordEntry[] = [];
let sequence = 0;
const totals = Object.fromEntries(
  (["api", "image", "upscale"] as const).map((category) => [
    category,
    {
      requests: 0,
      failed: 0,
      notModified: 0,
      bytes: 0,
      unknownBytes: 0,
      elapsedMs: 0,
      hit: 0,
      miss: 0,
      unavailable: 0,
      unused: 0,
    },
  ]),
) as Record<
  RequestCategory,
  {
    requests: number;
    failed: number;
    notModified: number;
    bytes: number;
    unknownBytes: number;
    elapsedMs: number;
  } & Record<CacheOutcome, number>
>;

export const observeRequests: RequestHandler = (req, res, next) => {
  const requestPath = req.path;
  if (
    /^\/api\/(?:admin(?:\/|$)|health$|super-resolution\/(?:monitor|policy|jobs)$)/.test(
      requestPath,
    ) &&
    req.method === "GET"
  )
    return next();
  const category: RequestCategory | undefined = requestPath.startsWith(
    "/static/",
  )
    ? "image"
    : requestPath.startsWith("/api/super-resolution/")
      ? "upscale"
      : requestPath.startsWith("/api/")
        ? "api"
        : undefined;
  if (!category) return next();
  const started = performance.now();
  const requestedAt = new Date().toISOString();
  let settled = false;
  const finish = () => {
    if (settled) return;
    settled = true;
    res.off("finish", finish);
    res.off("close", finish);
    const aborted = !res.writableFinished;
    const status = aborted ? 0 : res.statusCode;
    const length = res.getHeader("content-length");
    const bytes = aborted
      ? null
      : req.method === "HEAD" || status === 304 || status === 204
        ? 0
        : length !== undefined && Number.isFinite(Number(length))
          ? Number(length)
          : null;
    const candidate = res.locals.cacheOutcome;
    const cache: CacheOutcome =
      candidate === "hit" || candidate === "miss" || candidate === "unavailable"
        ? candidate
        : "unused";
    const entry: RecordEntry = {
      id: ++sequence,
      category,
      method: req.method,
      path: requestPath.slice(0, 512),
      status,
      aborted,
      requestedAt,
      elapsedMs: Math.round(performance.now() - started),
      bytes,
      cache,
    };
    records.unshift(entry);
    if (records.length > 500) records.pop();
    const total = totals[category];
    total.requests++;
    if (aborted || status >= 400) total.failed++;
    if (status === 304) total.notModified++;
    total.bytes += bytes ?? 0;
    if (bytes === null) total.unknownBytes++;
    total.elapsedMs += entry.elapsedMs;
    total[cache]++;
  };
  res.once("finish", finish);
  res.once("close", finish);
  next();
};

export function requestSnapshot() {
  return {
    startedAt,
    limit: 500,
    total: sequence,
    totals,
    records: records.slice(),
  };
}
