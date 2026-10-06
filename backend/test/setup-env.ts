// ConfigModule validates the environment when AppModule is imported,
// so test variables must exist before any test file loads.
process.env.DATABASE_URL ??= 'postgres://test:test@127.0.0.1:1/test';
process.env.APP_ENV = 'staging'; // JSON logs, no pretty transport in tests
process.env.NODE_ENV = 'test';
process.env.LOG_LEVEL = 'error';
