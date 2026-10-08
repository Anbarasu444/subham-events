import { Injectable } from '@nestjs/common';
import { DataSource, In, IsNull, type EntityManager } from 'typeorm';
import type { CoverDto } from './media.dto';
import { MediaEntity } from './media.entity';
import { ImageKitClient } from './imagekit.client';

/** Event media is private: signed URLs live 15 minutes (§2). */
export const PRIVATE_URL_TTL_MS = 15 * 60 * 1000;
/** Resized variants only — originals are never served (§4). */
// md-false: never serve photo metadata (EXIF/GPS) — §4.
const COVER = 'w-1200,q-80,f-auto,md-false';
const THUMBNAIL = 'w-480,q-70,f-auto,md-false';

/** Builds signed cover URLs for events, one query per list. */
@Injectable()
export class CoverUrlService {
  constructor(
    private readonly dataSource: DataSource,
    private readonly imageKit: ImageKitClient,
  ) {}

  /** [mediaIds] = events' cover ids; result keyed by media id. */
  async forMedia(
    mediaIds: (string | null)[],
    now = new Date(),
    manager?: EntityManager,
  ): Promise<Map<string, CoverDto>> {
    const ids = [...new Set(mediaIds.filter((id): id is string => !!id))];
    const result = new Map<string, CoverDto>();
    if (ids.length === 0 || !this.imageKit.enabled) return result;
    const rows = await (manager ?? this.dataSource.manager)
      .getRepository(MediaEntity)
      .findBy({ id: In(ids), status: 'READY', deletedAt: IsNull() });
    const expiresAt = new Date(now.getTime() + PRIVATE_URL_TTL_MS);
    for (const media of rows) {
      if (!media.filePath) continue;
      result.set(media.id, {
        mediaId: media.id,
        url: this.imageKit.signedUrl(media.filePath, COVER, expiresAt),
        thumbnailUrl: this.imageKit.signedUrl(
          media.filePath,
          THUMBNAIL,
          expiresAt,
        ),
        expiresAt: expiresAt.toISOString(),
      });
    }
    return result;
  }
}
