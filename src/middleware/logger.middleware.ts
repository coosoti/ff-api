import { Request, Response, NextFunction } from "express";

export function requestLogger(req: Request, res: Response, next: NextFunction) {
  const start = Date.now();

  res.on("finish", () => {
    const duration = Date.now() - start;
    const color =
      res.statusCode >= 500 ? "\x1b[31m" :  // red
      res.statusCode >= 400 ? "\x1b[33m" :  // yellow
      res.statusCode >= 300 ? "\x1b[36m" :  // cyan
      "\x1b[32m";                            // green
    const reset = "\x1b[0m";

    console.log(
      `${color}${res.statusCode}${reset} ${req.method} ${req.originalUrl} — ${duration}ms`
    );
  });

  next();
}