export function bar(current: number, total: number, width = 30): string {
  const pct = total === 0 ? 1 : current / total;
  const filled = Math.round(pct * width);
  const empty = width - filled;
  return `[${'█'.repeat(filled)}${'░'.repeat(empty)}] ${(pct * 100).toFixed(1)}%`;
}

export function progress(label: string, current: number, total: number, detail = '') {
  const line = `\r${label} ${bar(current, total)} ${current}/${total}  ${detail}`;
  process.stdout.write(line.padEnd(100));
}

export function done(msg: string) {
  process.stdout.write('\n');
  console.log(msg);
}
