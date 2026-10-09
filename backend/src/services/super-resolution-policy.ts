import { execFile } from "node:child_process";
import { promisify } from "node:util";

const execute = promisify(execFile);
export interface PrefetchPolicy {
  lookahead: number;
  source: "nvidia" | "fallback";
  reason: string;
  utilization?: number;
  memoryUsedMiB?: number;
  memoryTotalMiB?: number;
  processingMs?: number;
}

/** 只控制前瞻任务数量，不是 GPU 占用上限。指标为整卡负载。 */
export class SuperResolutionPolicy {
  private policy: PrefetchPolicy = {
    lookahead: 4,
    source: "fallback",
    reason: "保守预处理",
  };
  private nextSample = 0;
  private pending?: Promise<PrefetchPolicy>;
  private high = 0;
  private low = 0;
  private processingMs?: number;
  private inferenceDevice?: string;

  setInferenceDevices(names: string[]): void {
    const device =
      names.length === 1 ? names[0].trim().toLowerCase() : undefined;
    if (device === this.inferenceDevice) return;
    this.inferenceDevice = device;
    this.nextSample = 0;
  }

  recordProcessing(milliseconds: number): void {
    this.processingMs =
      this.processingMs === undefined
        ? milliseconds
        : this.processingMs * 0.75 + milliseconds * 0.25;
  }

  snapshot(): PrefetchPolicy {
    return { ...this.policy, processingMs: this.processingMs };
  }

  /** 连续采样后才调整，正常压力每次只增加一页。 */
  observe(
    utilization: number,
    memoryUsedMiB: number,
    memoryTotalMiB: number,
  ): PrefetchPolicy {
    const memory = memoryUsedMiB / memoryTotalMiB;
    const cap =
      this.processingMs === undefined
        ? 6
        : this.processingMs > 12000
          ? 2
          : this.processingMs > 6000
            ? 4
            : this.processingMs > 3000
              ? 6
              : 10;
    let lookahead = Math.min(this.policy.lookahead, cap);
    let reason = "GPU 负载稳定";
    if (utilization >= 90 || memory >= 0.85) {
      this.low = 0;
      if (++this.high >= 2 || memory >= 0.95) {
        lookahead = Math.max(2, lookahead - 2);
        this.high = 0;
      }
      reason = "GPU 压力较高，减少预处理";
    } else if (utilization <= 65 && memory <= 0.75) {
      this.high = 0;
      if (++this.low >= 2) {
        lookahead = Math.min(cap, lookahead + 1);
        this.low = 0;
      }
      reason = "GPU 有余量，逐步增加预处理";
    } else {
      this.high = 0;
      this.low = 0;
    }
    this.policy = {
      lookahead,
      source: "nvidia",
      reason,
      utilization,
      memoryUsedMiB,
      memoryTotalMiB,
    };
    return this.snapshot();
  }

  async read(): Promise<PrefetchPolicy> {
    if (!this.inferenceDevice) {
      this.policy = {
        lookahead: 4,
        source: "fallback",
        reason: "推理设备尚未确认，保守预处理",
      };
      this.high = 0;
      this.low = 0;
      return this.snapshot();
    }
    if (this.pending) return this.pending;
    if (Date.now() < this.nextSample) return this.snapshot();
    this.pending = (async () => {
      try {
        const { stdout } = await execute(
          "nvidia-smi",
          [
            "--query-gpu=name,utilization.gpu,memory.used,memory.total",
            "--format=csv,noheader,nounits",
          ],
          { windowsHide: true, timeout: 2000, maxBuffer: 4096 },
        );
        const lines = stdout.trim().split(/\r?\n/);
        const columns = lines[0].split(",");
        const name = columns.shift()?.trim().toLowerCase();
        const fields = columns.map((value) => Number(value.trim()));
        // 无法明确单卡或指标不受支持时，不猜测正在使用哪张显卡。
        if (
          lines.length !== 1 ||
          name !== this.inferenceDevice ||
          fields.length !== 3 ||
          fields.some((value) => !Number.isFinite(value)) ||
          fields[0] < 0 ||
          fields[0] > 100 ||
          fields[1] < 0 ||
          fields[2] <= 0 ||
          fields[1] > fields[2]
        )
          throw new Error("GPU metrics unavailable");
        this.nextSample = Date.now() + 5000;
        return this.observe(fields[0], fields[1], fields[2]);
      } catch {
        this.high = 0;
        this.low = 0;
        this.policy = {
          lookahead: 4,
          source: "fallback",
          reason: "GPU 指标不可用，使用保守预处理",
        };
        this.nextSample = Date.now() + 30000;
        return this.snapshot();
      }
    })();
    try {
      return await this.pending;
    } finally {
      this.pending = undefined;
    }
  }
}

export const superResolutionPolicy = new SuperResolutionPolicy();
