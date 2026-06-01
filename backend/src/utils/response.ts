import type { Response } from "express";

export function ok<T>(res: Response, data: T, extra?: Record<string, unknown>) {
  res.json({ code: 0, message: "success", data, ...extra });
}

export function fail(res: Response, message: string, code = 1, status = 400) {
  res.status(status).json({ code, message, data: null });
}
