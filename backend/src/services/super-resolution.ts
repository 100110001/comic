import { spawn, type ChildProcess } from "node:child_process";
import { createHash, randomUUID } from "node:crypto";
import fs from "node:fs/promises";
import path from "node:path";
import { imageSize } from "image-size";
import { config } from "../config";
import { superResolutionPolicy } from "./super-resolution-policy";

export const SUPER_RESOLUTION_WINDOW_SIZE = 11;

export class SuperResolutionError extends Error {}

export interface UpscaleSource {
  id: number;
  path: string;
  version: string;
}
export interface UpscaleJob {
  key: string;
  imageId: number;
  status: "queued" | "running" | "ready" | "failed";
  url?: string;
  error?: string;
}
export interface UpscaleRequestRecord {
  id: number;
  imageId: number;
  filename: string;
  requestedAt: string;
  priority: number;
  status: UpscaleJob["status"] | "submitting";
  kind?: "inference" | "cache" | "shared";
  key?: string;
  originalUrl?: string;
  url?: string;
  width?: number;
  height?: number;
  elapsedMs?: number;
  error?: string;
}
interface RequestRecord extends UpscaleRequestRecord {
  epoch: number;
  time: number;
}

interface Task extends UpscaleJob {
  source: string;
  stamp: string;
  width: number;
  height: number;
  epoch: number;
  priority: number;
  order: number;
}
export interface UpscaleOptions {
  enabled: boolean;
  executable: string;
  modelDir: string;
  cacheDir: string;
  maxBytes: number;
  timeoutMs: number;
  comicRoot: string;
}
function inside(root: string, file: string): boolean {
  const relative = path.relative(root, file);
  return (
    relative !== "" &&
    !relative.startsWith(`..${path.sep}`) &&
    relative !== ".." &&
    !path.isAbsolute(relative)
  );
}
function fileStamp(stat: {
  size: number;
  mtimeMs: number;
  ctimeMs: number;
}): string {
  return `${stat.size}-${stat.mtimeMs}-${stat.ctimeMs}`;
}

/** 单后端进程拥有缓存；发布、文件查找与清理串行；发送期间缓存仍可能被回收。 */
export class SuperResolutionService {
  private jobs = new Map<string, Task>();
  private requests: RequestRecord[] = [];
  private requestCount = 0;
  private queue: Task[] = [];
  private order = 0;
  private epoch = 0;
  private cacheGeneration = randomUUID();
  private initialized?: Promise<void>;
  private modelIdentity?: string;
  private files: Promise<unknown> = Promise.resolve();
  private draining = false;
  private clearing = false;
  private child?: ChildProcess;
  private childDone?: Promise<void>;
  private root = "";
  private cache = "";

  constructor(private readonly options: UpscaleOptions) {}

  private locked<T>(action: () => Promise<T>): Promise<T> {
    const next = this.files.then(action);
    this.files = next.catch(() => {});
    return next;
  }

  private async initialize(): Promise<void> {
    if (!this.options.enabled)
      throw new SuperResolutionError("后端尚未启用超分，请配置 waifu2x 引擎");
    if (!this.initialized) {
      this.initialized = (async () => {
        if (!this.options.comicRoot)
          throw new SuperResolutionError("漫画根目录未配置");
        this.root = await fs.realpath(this.options.comicRoot);
        await fs.access(this.options.executable);
        await fs.mkdir(this.options.cacheDir, { recursive: true });
        this.cache = await fs.realpath(this.options.cacheDir);
        if (this.cache === this.root || inside(this.root, this.cache)) {
          throw new SuperResolutionError("超分缓存必须位于漫画目录之外");
        }
        const hash = createHash("sha256").update(
          "waifu2x:cunet:2x:noise=-1:webp:v1",
        );
        hash.update(await fs.readFile(this.options.executable));
        const names = (await fs.readdir(this.options.modelDir))
          .filter((name) => name.endsWith(".bin") || name.endsWith(".param"))
          .sort();
        if (names.length === 0)
          throw new SuperResolutionError("超分模型文件缺失");
        for (const name of names) {
          hash
            .update(name)
            .update(await fs.readFile(path.join(this.options.modelDir, name)));
        }
        this.modelIdentity = hash.digest("hex");
        await this.locked(async () => {
          for (const name of await fs.readdir(this.cache)) {
            if (/^[a-f0-9]{64}-[a-f0-9-]+\.tmp\.webp$/.test(name)) {
              await fs.rm(path.join(this.cache, name), { force: true });
            }
          }
          await this.prune();
        });
      })().catch((error: unknown) => {
        this.initialized = undefined;
        console.error("[超分] 初始化失败", error);
        throw new SuperResolutionError(
          "超分引擎不可用，请检查后端引擎、模型与缓存配置",
        );
      });
    }
    await this.initialized;
  }

  private result(task: Task): UpscaleJob {
    return {
      key: task.key,
      imageId: task.imageId,
      status: task.status,
      ...(task.status === "ready" ? { url: this.url(task.key) } : {}),
      ...(task.error ? { error: task.error } : {}),
    };
  }
  private url(key: string): string {
    return `/api/super-resolution/files/${key}?g=${this.cacheGeneration}`;
  }

  async request(source: UpscaleSource, priority: number): Promise<UpscaleJob> {
    const time = Date.now();
    const relative = path.relative(
      path.resolve(this.options.comicRoot || "."),
      path.resolve(source.path),
    );
    const safe =
      this.options.comicRoot &&
      relative &&
      relative !== ".." &&
      !relative.startsWith(`..${path.sep}`) &&
      !path.isAbsolute(relative) &&
      /^\d+-\d+$/.test(source.version);
    const record: RequestRecord = {
      id: ++this.requestCount,
      imageId: source.id,
      filename: path.basename(source.path),
      requestedAt: new Date(time).toISOString(),
      priority,
      status: "submitting",
      epoch: this.epoch,
      time,
      ...(safe
        ? {
            originalUrl: `/static/${relative.split(path.sep).map(encodeURIComponent).join("/")}?v=${source.version}`,
          }
        : {}),
    };
    this.requests.push(record);
    if (this.requests.length > 500) this.requests.shift();
    try {
      const { job, kind } = await this.requestInternal(
        source,
        priority,
        record.epoch,
      );
      if (record.epoch !== this.epoch) return job;
      Object.assign(record, job, { kind, imageId: source.id });
      const task = this.jobs.get(job.key);
      if (task) {
        record.width = task.width;
        record.height = task.height;
      }
      if (job.status === "ready" || job.status === "failed")
        record.elapsedMs = Date.now() - time;
      return { ...job, imageId: source.id };
    } catch (error) {
      if (record.epoch !== this.epoch) throw error;
      record.status = "failed";
      record.error =
        error instanceof SuperResolutionError
          ? error.message
          : "超分提交失败，请检查后端配置";
      record.elapsedMs = Date.now() - time;
      throw error;
    }
  }

  private updateRequests(task: Task): void {
    for (const record of this.requests) {
      if (
        record.key !== task.key ||
        record.epoch !== task.epoch ||
        (record.status !== "queued" && record.status !== "running")
      )
        continue;
      Object.assign(record, this.result(task), { imageId: record.imageId });
      if (task.status === "ready" || task.status === "failed")
        record.elapsedMs = Date.now() - record.time;
    }
  }

  monitor() {
    return {
      enabled: this.options.enabled,
      total: this.requestCount,
      limit: 500,
      prefetch: superResolutionPolicy.snapshot(),
      queued: this.queue.length,
      running: [...this.jobs.values()].filter(
        (task) => task.status === "running",
      ).length,
      requests: this.requests
        .slice()
        .reverse()
        .map((record) => ({
          id: record.id,
          imageId: record.imageId,
          filename: record.filename,
          requestedAt: record.requestedAt,
          priority: record.priority,
          status: record.status,
          kind: record.kind,
          key: record.key,
          originalUrl: record.originalUrl,
          url: record.url,
          width: record.width,
          height: record.height,
          error: record.error,
          elapsedMs: record.elapsedMs ?? Date.now() - record.time,
        })),
    };
  }

  private async requestInternal(
    source: UpscaleSource,
    priority: number,
    requestedEpoch: number,
  ): Promise<{ job: UpscaleJob; kind: "cache" | "shared" | "inference" }> {
    await this.initialize();
    if (this.clearing || requestedEpoch !== this.epoch)
      throw new SuperResolutionError("正在清理超分缓存，请稍后重试");
    const resolved = await fs.realpath(source.path);
    if (!inside(this.root, resolved))
      throw new SuperResolutionError("图片不在漫画目录内");
    if (
      ![".jpg", ".jpeg", ".png", ".webp"].includes(
        path.extname(resolved).toLowerCase(),
      )
    ) {
      throw new SuperResolutionError("此图片格式暂不支持超分");
    }
    const stat = await fs.stat(resolved);
    if (
      !stat.isFile() ||
      source.version !== `${stat.size}-${Math.trunc(stat.mtimeMs)}`
    ) {
      throw new SuperResolutionError("原图版本已变化，请重新加载章节");
    }
    const dimensions = imageSize(resolved);
    const width = dimensions.width ?? 0;
    const height = dimensions.height ?? 0;
    if (width <= 0 || height <= 0 || width * height > 20_000_000) {
      throw new SuperResolutionError("图片过大或尺寸无效，继续使用原图");
    }
    if (requestedEpoch !== this.epoch)
      throw new SuperResolutionError("缓存已清理，请重试");
    const stamp = fileStamp(stat);
    const key = createHash("sha256")
      .update(JSON.stringify([resolved, stamp, this.modelIdentity]))
      .digest("hex");
    const existing = this.jobs.get(key);
    if (
      existing &&
      (existing.status === "queued" || existing.status === "running")
    ) {
      existing.priority = Math.min(existing.priority, priority);
      existing.order = ++this.order;
      return { job: this.result(existing), kind: "shared" };
    }
    const task: Task = {
      key,
      imageId: source.id,
      status: "queued",
      source: resolved,
      stamp,
      width,
      height,
      epoch: this.epoch,
      priority,
      order: ++this.order,
    };
    const cached = await this.locked(async () => {
      const target = path.join(this.cache, `${key}.webp`);
      try {
        const cachedStat = await fs.stat(target);
        if (!cachedStat.isFile() || cachedStat.size === 0) return false;
        const now = new Date();
        await fs.utimes(target, now, now);
        return true;
      } catch {
        return false;
      }
    });
    // 文件检查期间其他请求可能已提交同键任务。
    if (this.clearing || task.epoch !== this.epoch)
      throw new SuperResolutionError("缓存已清理，请重试");
    const concurrent = this.jobs.get(key);
    if (
      concurrent &&
      (concurrent.status === "queued" || concurrent.status === "running")
    ) {
      concurrent.priority = Math.min(concurrent.priority, priority);
      concurrent.order = ++this.order;
      return { job: this.result(concurrent), kind: "shared" };
    }
    if (cached) task.status = "ready";
    else if (this.queue.length >= 64)
      throw new SuperResolutionError("超分队列已满，请稍后重试");
    // 终态记录不无限累积，运行中的任务保留。
    for (const [oldKey, oldTask] of this.jobs) {
      if (this.jobs.size < 128) break;
      if (oldTask.status === "ready" || oldTask.status === "failed")
        this.jobs.delete(oldKey);
    }
    this.jobs.set(key, task);
    if (!cached) {
      this.queue.push(task);
      setImmediate(() => {
        void this.drain();
      });
    }
    return { job: this.result(task), kind: cached ? "cache" : "inference" };
  }

  status(keys: string[]): UpscaleJob[] {
    return keys.map((key) => {
      const task = this.jobs.get(key);
      return task
        ? this.result(task)
        : {
            key,
            imageId: 0,
            status: "failed",
            error: "任务已失效，请重试",
          };
    });
  }

  private async runEngine(task: Task, output: string): Promise<void> {
    const child = spawn(
      this.options.executable,
      [
        "-i",
        task.source,
        "-o",
        output,
        "-s",
        "2",
        "-n",
        "-1",
        "-m",
        this.options.modelDir,
        "-t",
        "256",
        "-f",
        "webp",
      ],
      { shell: false, windowsHide: true, stdio: ["ignore", "ignore", "pipe"] },
    );
    const devices = new Map<number, string>();
    let stderr = "";
    child.stderr?.setEncoding("utf8");
    child.stderr?.on("data", (chunk: string) => {
      stderr += chunk;
      const lines = stderr.split(/\r?\n/);
      stderr = lines.pop()!.slice(-4096);
      for (const line of lines) {
        const match = /^\[(\d+) ([^\]]+)\]/.exec(line);
        if (match) devices.set(Number(match[1]), match[2]);
      }
    });
    this.child = child;
    this.childDone = new Promise<void>((resolve, reject) => {
      let timedOut = false;
      const timer = setTimeout(() => {
        timedOut = true;
        child.kill();
      }, this.options.timeoutMs);
      child.once("error", (error) => {
        clearTimeout(timer);
        reject(error);
      });
      child.once("close", (code) => {
        clearTimeout(timer);
        if (timedOut) reject(new SuperResolutionError("超分处理超时"));
        else if (code !== 0)
          reject(new SuperResolutionError("超分处理失败，请检查显卡驱动"));
        else resolve();
      });
    });
    try {
      await this.childDone;
    } finally {
      superResolutionPolicy.setInferenceDevices([...devices.values()]);
      this.child = undefined;
      this.childDone = undefined;
    }
  }

  private async drain(): Promise<void> {
    if (this.draining || this.clearing) return;
    this.draining = true;
    try {
      while (this.queue.length && !this.clearing) {
        this.queue.sort((a, b) => a.priority - b.priority || b.order - a.order);
        const task = this.queue.shift()!;
        if (task.epoch !== this.epoch) continue;
        task.status = "running";
        this.updateRequests(task);
        const temporary = path.join(
          this.cache,
          `${task.key}-${randomUUID()}.tmp.webp`,
        );
        try {
          const started = Date.now();
          await this.runEngine(task, temporary);
          superResolutionPolicy.recordProcessing(Date.now() - started);
          const dimensions = imageSize(temporary);
          if (
            dimensions.width !== task.width * 2 ||
            dimensions.height !== task.height * 2
          ) {
            throw new SuperResolutionError("超分输出尺寸异常");
          }
          const stat = await fs.stat(task.source);
          if (fileStamp(stat) !== task.stamp)
            throw new SuperResolutionError("原图已变化，请重新加载章节");
          await this.locked(async () => {
            if (task.epoch !== this.epoch) return;
            if ((await fs.stat(temporary)).size > this.options.maxBytes) {
              throw new SuperResolutionError("此图片超出超分缓存容量限制");
            }
            await fs.rename(
              temporary,
              path.join(this.cache, `${task.key}.webp`),
            );
            await this.prune(task.key);
            task.status = "ready";
          });
        } catch (error) {
          if (task.epoch === this.epoch) {
            task.status = "failed";
            task.error =
              error instanceof SuperResolutionError
                ? error.message
                : "超分处理失败，请检查后端配置";
            console.error("[超分] 任务失败", task.key, error);
          }
        } finally {
          this.updateRequests(task);
          await fs.rm(temporary, { force: true }).catch(() => {});
        }
      }
    } finally {
      this.draining = false;
      if (this.queue.length && !this.clearing)
        setImmediate(() => {
          void this.drain();
        });
    }
  }

  private async prune(protectedKey?: string): Promise<void> {
    const entries = await fs.readdir(this.cache);
    const files = await Promise.all(
      entries
        .filter((name) => /^[a-f0-9]{64}\.webp$/.test(name))
        .map(async (name) => {
          const file = path.join(this.cache, name);
          const stat = await fs.stat(file);
          return { file, name, size: stat.size, time: stat.mtimeMs };
        }),
    );
    let total = files.reduce((sum, file) => sum + file.size, 0);
    for (const file of files.sort((a, b) => a.time - b.time)) {
      if (total <= this.options.maxBytes) break;
      if (file.name === `${protectedKey}.webp`) continue;
      await fs.rm(file.file, { force: true });
      total -= file.size;
      const task = this.jobs.get(file.name.slice(0, 64));
      if (task) {
        task.status = "failed";
        task.error = "超分缓存已回收，请重试";
      }
    }
  }

  async file(key: string): Promise<string> {
    await this.initialize();
    if (!/^[a-f0-9]{64}$/.test(key))
      throw new SuperResolutionError("无效缓存标识");
    return this.locked(async () => {
      const file = path.join(this.cache, `${key}.webp`);
      const stat = await fs.stat(file);
      if (!stat.isFile()) throw new SuperResolutionError("超分缓存不存在");
      const now = new Date();
      await fs.utimes(file, now, now);
      return file;
    });
  }

  async clear(): Promise<void> {
    await this.initialize();
    if (this.clearing) throw new SuperResolutionError("正在清理缓存");
    this.clearing = true;
    for (const record of this.requests) {
      if (["submitting", "queued", "running"].includes(record.status)) {
        record.status = "failed";
        record.error = "超分缓存已清理，任务已取消";
        record.elapsedMs = Date.now() - record.time;
      }
    }
    ++this.epoch;
    this.cacheGeneration = randomUUID();
    this.queue = [];
    this.jobs.clear();
    const done = this.childDone;
    this.child?.kill();
    try {
      await done?.catch(() => {});
      await this.locked(async () => {
        for (const name of await fs.readdir(this.cache)) {
          if (/^[a-f0-9]{64}(?:-[a-f0-9-]+\.tmp)?\.webp$/.test(name)) {
            await fs.rm(path.join(this.cache, name), { force: true });
          }
        }
      });
    } finally {
      this.clearing = false;
    }
  }
}

export const superResolution = new SuperResolutionService({
  ...config.superResolution,
  comicRoot: config.comicRoot,
});
