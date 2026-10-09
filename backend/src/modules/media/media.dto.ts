import {
  IsIn,
  IsInt,
  IsString,
  IsUUID,
  Matches,
  Max,
  Min,
} from 'class-validator';

/** Event cover photos (M10 answer: max 5 MB). */
export const COVER_MAX_BYTES = 5 * 1024 * 1024;

export const IMAGE_TYPES = {
  'image/jpeg': 'jpg',
  'image/png': 'png',
  'image/webp': 'webp',
  'image/heic': 'heic',
  'image/heif': 'heif',
} as const;
export type ImageType = keyof typeof IMAGE_TYPES;

export class CreateUploadDto {
  @IsIn(['EVENT_COVER', 'USER_PHOTO'])
  kind: 'EVENT_COVER' | 'USER_PHOTO';

  /** The event the cover is for, or the caller's own user id (M21). */
  @IsUUID()
  ownerId: string;

  @IsIn(Object.keys(IMAGE_TYPES))
  contentType: ImageType;

  /** Size the app is about to upload (re-checked after upload). */
  @IsInt()
  @Min(1)
  @Max(COVER_MAX_BYTES)
  sizeBytes: number;
}

export class CompleteUploadDto {
  @IsString()
  @Matches(/^[A-Za-z0-9_-]{8,64}$/, { message: 'fileId is not valid' })
  fileId: string;
}

export interface UploadIntentDto {
  mediaId: string;
  /** ImageKit upload API v2. */
  uploadUrl: string;
  /** Single-use JWT signing every field below (expires in 10 minutes). */
  token: string;
  /** Send unchanged as form fields next to `file` and `token`. */
  fields: Record<string, string>;
  /** Unix seconds. */
  expire: number;
  maxBytes: number;
}

/** Signed, resized URLs for a cover (originals are never served). */
export interface CoverDto {
  mediaId: string;
  url: string;
  thumbnailUrl: string;
  expiresAt: string;
}
