import { validateEnv } from './env.validation';

describe('validateEnv', () => {
  const base = { DATABASE_URL: 'postgres://u:p@localhost:5432/db' };

  it('applies defaults and converts types', () => {
    const env = validateEnv({ ...base, PORT: '4000' });
    expect(env.PORT).toBe(4000);
    expect(env.APP_ENV).toBe('local');
    expect(env.LOG_LEVEL).toBe('info');
  });

  it('fails fast when DATABASE_URL is missing', () => {
    expect(() => validateEnv({})).toThrow(/DATABASE_URL/);
  });

  it('rejects unknown environments and invalid ports', () => {
    expect(() => validateEnv({ ...base, APP_ENV: 'dev' })).toThrow(/APP_ENV/);
    expect(() => validateEnv({ ...base, PORT: '70000' })).toThrow(/PORT/);
  });
});
