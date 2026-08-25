// "第N話" 系列按数字排在前面(自然数字排序);"番外編" 等非"第N話"标题排在最后
export function compareChapterTitle(a: string, b: string): number {
  const rankA = a.startsWith("第") ? 0 : 1;
  const rankB = b.startsWith("第") ? 0 : 1;
  if (rankA !== rankB) return rankA - rankB;
  return a.localeCompare(b, undefined, { numeric: true });
}
