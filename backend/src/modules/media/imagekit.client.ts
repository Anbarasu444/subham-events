import { createHmac, randomUUID } from 'node:crypto';
import { Injectable } from '@nestjs/common';
import { AppConfigService } from '../../config/app-config.service';

/** File attributes reported by ImageKit (files API "details"). */
export interface ImageKitFile {
  fileId: string;
  name: string;
  filePath: string;
  size: number;
  mime: string | null;
  width: number | null;
  height: number | null;
  isPrivateFile: boolean;
}

/** Upload settings the server fixes; signed into the v2 upload token. */
export interface UploadParams {
  fileName: string;
  folder: string;
  /** Upload-time size check (first filter; the server re-verifies). */
  checks: string;
}

/**
 * ImageKit upload API v2: every upload field is signed into a single-use
 * JWT, so the app can't change folder, name, privacy or overwrite settings
 * (ImageKit rejects mismatching fields and reused tokens — verified live).
 */
export interface UploadToken {
  token: string;
  /** Form fields the app must send unchanged next to `file` and `token`. */
  fields: Record<string, string>;
  /** Unix seconds. */
  expire: number;
}

/**
 * The only place that talks to ImageKit (ADR-0007). Abstract so tests use a
 * fake; the real client uses the REST API directly (no SDK dependency).
 */
export abstract class ImageKitClient {
  /** False when the ImageKit settings are missing (media endpoints → 503). */
  abstract get enabled(): boolean;
  abstract get publicKey(): string;
  abstract get rootFolder(): string;
  /** Short-lived, single-use v2 upload token for exactly [params]. */
  abstract uploadToken(params: UploadParams, now?: Date): UploadToken;
  abstract getFile(fileId: string): Promise<ImageKitFile | null>;
  /** The file stored at exactly [filePath] (folder + name), if any. */
  abstract findByPath(filePath: string): Promise<ImageKitFile | null>;
  abstract deleteFile(fileId: string): Promise<void>;
  /** Signed delivery URL for a private file with an ImageKit transformation. */
  abstract signedUrl(
    filePath: string,
    transformation: string,
    expiresAt: Date,
  ): string;
}

export const IMAGEKIT_UPLOAD_URL =
  'https://upload.imagekit.io/api/v2/files/upload';
const API = 'https://api.imagekit.io/v1/files';
/** ImageKit accepts upload signatures that expire within one hour. */
const UPLOAD_AUTH_TTL_SECONDS = 10 * 60;
const REQUEST_TIMEOUT_MS = 10_000;

@Injectable()
export class HttpImageKitClient extends ImageKitClient {
  constructor(private readonly config: AppConfigService) {
    super();
  }

  private get settings() {
    const imageKit = this.config.imageKit;
    if (!imageKit) throw new Error('ImageKit is not configured');
    return imageKit;
  }

  get enabled(): boolean {
    return this.config.imageKit !== null;
  }

  get publicKey(): string {
    return this.settings.publicKey;
  }

  get rootFolder(): string {
    return this.settings.rootFolder;
  }

  uploadToken(params: UploadParams, now = new Date()): UploadToken {
    const iat = Math.floor(now.getTime() / 1000);
    const expire = iat + UPLOAD_AUTH_TTL_SECONDS;
    const fields: Record<string, string> = {
      fileName: params.fileName,
      folder: params.folder,
      isPrivateFile: 'true',
      useUniqueFileName: 'false',
      overwriteFile: 'false',
      checks: params.checks,
    };
    const encode = (value: unknown) =>
      Buffer.from(JSON.stringify(value)).toString('base64url');
    const header = encode({ alg: 'HS256', typ: 'JWT', kid: this.publicKey });
    // jti makes every token unique even for identical fields.
    const payload = encode({ ...fields, iat, exp: expire, jti: randomUUID() });
    const signature = createHmac('sha256', this.settings.privateKey)
      .update(`${header}.${payload}`)
      .digest('base64url');
    return { token: `${header}.${payload}.${signature}`, fields, expire };
  }

  async findByPath(filePath: string): Promise<ImageKitFile | null> {
    const slash = filePath.lastIndexOf('/');
    const folder = filePath.slice(0, slash) || '/';
    const name = filePath.slice(slash + 1);
    const query = new URLSearchParams({
      path: folder,
      searchQuery: `name = "${name}"`,
      limit: '1',
    });
    const response = await fetch(`${API}?${query.toString()}`, {
      headers: { Authorization: this.basicAuth() },
      signal: AbortSignal.timeout(REQUEST_TIMEOUT_MS),
    });
    if (!response.ok) {
      throw new Error(`ImageKit file search failed (${response.status})`);
    }
    const [first] = (await response.json()) as Record<string, unknown>[];
    return first && first.filePath === filePath
      ? this.getFile(String(first.fileId))
      : null;
  }

  async getFile(fileId: string): Promise<ImageKitFile | null> {
    const response = await fetch(
      `${API}/${encodeURIComponent(fileId)}/details`,
      {
        headers: { Authorization: this.basicAuth() },
        signal: AbortSignal.timeout(REQUEST_TIMEOUT_MS),
      },
    );
    if (response.status === 404) return null;
    if (!response.ok) {
      throw new Error(`ImageKit file details failed (${response.status})`);
    }
    const body = (await response.json()) as Record<string, unknown>;
    return {
      fileId: String(body.fileId),
      name: String(body.name),
      filePath: String(body.filePath),
      size: Number(body.size),
      mime: typeof body.mime === 'string' ? body.mime : null,
      width: typeof body.width === 'number' ? body.width : null,
      height: typeof body.height === 'number' ? body.height : null,
      isPrivateFile: body.isPrivateFile === true,
    };
  }

  async deleteFile(fileId: string): Promise<void> {
    const response = await fetch(`${API}/${encodeURIComponent(fileId)}`, {
      method: 'DELETE',
      headers: { Authorization: this.basicAuth() },
      signal: AbortSignal.timeout(REQUEST_TIMEOUT_MS),
    });
    if (!response.ok && response.status !== 404) {
      throw new Error(`ImageKit delete failed (${response.status})`);
    }
  }

  signedUrl(filePath: string, transformation: string, expiresAt: Date): string {
    const endpoint = this.settings.urlEndpoint;
    const path = filePath.startsWith('/') ? filePath.slice(1) : filePath;
    const unsigned = `${endpoint}/${path}?tr=${transformation}`;
    const expiry = Math.floor(expiresAt.getTime() / 1000);
    // ImageKit signs the URL without the endpoint (and its trailing slash)
    // followed by the expiry timestamp.
    const signature = this.hmac(
      `${unsigned.slice(endpoint.length + 1)}${expiry}`,
    );
    return `${unsigned}&ik-t=${expiry}&ik-s=${signature}`;
  }

  private hmac(value: string): string {
    return createHmac('sha1', this.settings.privateKey)
      .update(value)
      .digest('hex');
  }

  private basicAuth(): string {
    return `Basic ${Buffer.from(`${this.settings.privateKey}:`).toString('base64')}`;
  }
}
