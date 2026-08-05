import { createHash } from "node:crypto";

/**
 * Minimal structured logger. Never pass secrets, tokens or PII bodies to
 * these helpers — callers are responsible for redacting before logging.
 */

/**
 * Apple's `sub` claim is a stable per-user identifier and therefore PII.
 * Never log it raw: hash it to a short, non-reversible fingerprint that is
 * still useful for correlating log lines about the same user.
 */
export function hashAppleSub(appleSub: string): string {
  return createHash("sha256").update(appleSub).digest("hex").slice(0, 12);
}
export interface LogContext {
  requestId?: string;
  /** Short SHA-256 fingerprint of appleSub — never the raw value. See hashAppleSub. */
  appleSubHash?: string;
  operation: string;
  [key: string]: unknown;
}

function emit(level: "info" | "warn" | "error", message: string, context: LogContext): void {
  // A single JSON line per event keeps this greppable in CloudWatch Logs
  // without pulling in a logging dependency for a stack this size.
  console.log(
    JSON.stringify({
      level,
      message,
      ...context,
      timestamp: new Date().toISOString(),
    })
  );
}

export const logger = {
  info: (message: string, context: LogContext) => emit("info", message, context),
  warn: (message: string, context: LogContext) => emit("warn", message, context),
  error: (message: string, context: LogContext) => emit("error", message, context),
};
