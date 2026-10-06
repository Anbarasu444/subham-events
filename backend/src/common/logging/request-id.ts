import { randomUUID } from 'node:crypto';
import type { IncomingMessage, ServerResponse } from 'node:http';

export const REQUEST_ID_HEADER = 'x-request-id';

const VALID_REQUEST_ID = /^[A-Za-z0-9-]{8,128}$/;

/**
 * Reuses a well-formed incoming X-Request-Id or generates a UUID, and echoes it
 * on the response so clients and logs share one correlation id.
 */
export function resolveRequestId(
  req: IncomingMessage,
  res: ServerResponse,
): string {
  const incoming = req.headers[REQUEST_ID_HEADER];
  const candidate = Array.isArray(incoming) ? incoming[0] : incoming;
  const id =
    candidate && VALID_REQUEST_ID.test(candidate) ? candidate : randomUUID();
  res.setHeader('X-Request-Id', id);
  return id;
}

/** Reads the request id assigned by pino-http (`req.id`). */
export function getRequestId(req: unknown): string | undefined {
  const id = (req as { id?: unknown }).id;
  return typeof id === 'string' ? id : undefined;
}
