import { createHmac } from 'node:crypto';
import type { AppConfigService } from '../../config/app-config.service';
import { HttpImageKitClient } from './imagekit.client';

const settings = {
  publicKey: 'public_test',
  privateKey: 'private_secret',
  urlEndpoint: 'https://ik.imagekit.io/demo',
  rootFolder: '/local',
};
const client = new HttpImageKitClient({
  imageKit: settings,
} as unknown as AppConfigService);
const hmac = (value: string) =>
  createHmac('sha1', settings.privateKey).update(value).digest('hex');

describe('HttpImageKitClient', () => {
  it('signs every upload field into a single-use v2 token', () => {
    const now = new Date('2026-10-07T10:00:00Z');
    const params = {
      fileName: 'm1.jpg',
      folder: '/local/event-cover/event/e1',
      checks: '"file.size" <= "5mb"',
    };
    const upload = client.uploadToken(params, now);
    expect(upload.fields).toEqual({
      ...params,
      isPrivateFile: 'true',
      useUniqueFileName: 'false',
      overwriteFile: 'false',
    });
    const [header, payload, signature] = upload.token.split('.');
    expect(
      createHmac('sha256', settings.privateKey)
        .update(`${header}.${payload}`)
        .digest('base64url'),
    ).toBe(signature);
    const head = JSON.parse(
      Buffer.from(header, 'base64url').toString(),
    ) as Record<string, unknown>;
    const body = JSON.parse(
      Buffer.from(payload, 'base64url').toString(),
    ) as Record<string, unknown>;
    expect(head).toMatchObject({ alg: 'HS256', kid: settings.publicKey });
    expect(body).toMatchObject(upload.fields);
    expect((body.exp as number) - (body.iat as number)).toBeLessThanOrEqual(
      3600,
    );
    expect(client.uploadToken(params, now).token).not.toBe(upload.token);
  });

  it('builds signed, transformed URLs without the endpoint in the signature', () => {
    const expiresAt = new Date('2026-10-07T10:15:00Z');
    const url = client.signedUrl('/local/x/y.jpg', 'w-480', expiresAt);
    const expiry = Math.floor(expiresAt.getTime() / 1000);
    expect(url).toBe(
      `https://ik.imagekit.io/demo/local/x/y.jpg?tr=w-480&ik-t=${expiry}&ik-s=${hmac(`local/x/y.jpg?tr=w-480${expiry}`)}`,
    );
  });

  it('is disabled without settings', () => {
    const off = new HttpImageKitClient({
      imageKit: null,
    } as unknown as AppConfigService);
    expect(off.enabled).toBe(false);
  });
});
