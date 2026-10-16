import { execFileSync } from "child_process";
import { config } from "../config";

export function listeningPids(output: string, port: number): number[] {
  const pids = new Set<number>();
  for (const line of output.split(/\r?\n/)) {
    const [protocol, local, , state, pidText] = line.trim().split(/\s+/);
    if (protocol !== "TCP" || state !== "LISTENING") continue;
    if (Number(local?.slice(local.lastIndexOf(":") + 1)) !== port) continue;
    const pid = Number(pidText);
    if (Number.isSafeInteger(pid) && pid > 0 && pid !== process.pid)
      pids.add(pid);
  }
  return [...pids];
}

function killPort(port: number) {
  if (!Number.isInteger(port) || port < 1 || port > 65535)
    throw new Error(`端口无效: ${port}`);
  if (process.platform !== "win32") {
    console.log("当前平台跳过自动端口清理；如端口被占用，请手动停止旧服务");
    return;
  }
  const output = execFileSync("netstat", ["-ano"], {
    encoding: "utf8",
  });
  const pids = listeningPids(output, port);
  if (!pids.length) console.log(`端口 ${port} 没有监听进程`);
  for (const pid of pids) {
    console.log(`正在结束端口 ${port} 的监听进程 (pid ${pid})`);
    execFileSync("taskkill", ["/PID", String(pid), "/F"], { stdio: "inherit" });
  }
}

if (require.main === module) {
  try {
    killPort(config.port);
  } catch (err) {
    console.error("端口清理失败:", err);
    process.exitCode = 1;
  }
}
