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

  describe('ImageKit', () => {
    const imageKit = {
      IMAGEKIT_PUBLIC_KEY: 'public_abc123',
      IMAGEKIT_PRIVATE_KEY: 'private_def456',
      IMAGEKIT_URL_ENDPOINT: 'https://ik.imagekit.io/demo',
      MEDIA_ROOT_FOLDER: '/local',
    };

    it('accepts the three keys (folder optional) or none', () => {
      expect(() => validateEnv({ ...base, ...imageKit })).not.toThrow();
      const noFolder: Record<string, string> = { ...imageKit };
      delete noFolder.MEDIA_ROOT_FOLDER;
      expect(() => validateEnv({ ...base, ...noFolder })).not.toThrow();
      expect(() => validateEnv(base)).not.toThrow();
    });

    it('rejects a partial set without echoing values', () => {
      const partial: Record<string, string> = { ...imageKit };
      delete partial.IMAGEKIT_PRIVATE_KEY;
      expect(() => validateEnv({ ...base, ...partial })).toThrow(
        /set all of IMAGEKIT_PUBLIC_KEY/,
      );
    });

    it('rejects malformed values without echoing them', () => {
      const run = () =>
        validateEnv({
          ...base,
          ...imageKit,
          IMAGEKIT_PRIVATE_KEY: 'oops-secret',
        });
      expect(run).toThrow(/IMAGEKIT_PRIVATE_KEY must start with private_/);
      expect(run).not.toThrow(/oops-secret/);
      expect(() =>
        validateEnv({
          ...base,
          ...imageKit,
          IMAGEKIT_URL_ENDPOINT: 'https://ik.imagekit.io/demo/',
        }),
      ).toThrow(/IMAGEKIT_URL_ENDPOINT/);
      expect(() =>
        validateEnv({ ...base, ...imageKit, MEDIA_ROOT_FOLDER: 'local' }),
      ).toThrow(/MEDIA_ROOT_FOLDER/);
    });
  });
});
