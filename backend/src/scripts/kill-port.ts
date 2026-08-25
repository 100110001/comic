import { execSync } from "child_process";
import { config } from "../config";

function killPort(port: number) {
  let output: string;
  try {
    output = execSync(`netstat -ano | findstr :${port}`).toString();
  } catch {
    return; // 端口没被占用
  }

  const pids = new Set(
    output
      .split("\n")
      .filter((line) => line.includes("LISTENING"))
      .map((line) => line.trim().split(/\s+/).pop())
      .filter((pid): pid is string => !!pid && pid !== "0"),
  );

  for (const pid of pids) {
    if (pid === String(process.pid)) continue;
    console.log(`[kill-port] 端口 ${port} 被旧进程 (pid ${pid}) 占用，正在结束`);
    try {
      execSync(`taskkill /PID ${pid} /F`);
    } catch (err) {
      console.warn(`[kill-port] 结束 pid ${pid} 失败:`, (err as Error).message);
    }
  }
}

killPort(config.port);
