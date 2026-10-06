/** Port used by the health module so it can be tested without PostgreSQL. */
export abstract class DatabaseHealth {
  /** Resolves true when the database answers within the timeout. */
  abstract isReady(timeoutMs: number): Promise<boolean>;
}
