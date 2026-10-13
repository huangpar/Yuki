import { randomUUID } from 'crypto';
import { supabase } from '../db.js';
import { ApiError } from '../middleware/errorHandler.js';

// Where each kind of photo lives, and how many of them one thing can carry.
// Profile and review photos sit beside things anyone can already see, so they
// live in the public bucket. A job photo shows someone's home, so it stays
// private and is only ever handed out as a short-lived signed URL.
export const PHOTO_KINDS = {
  profile: { bucket: 'public-photos', max: 6 },
  review: { bucket: 'public-photos', max: 3 },
  job: { bucket: 'job-photos', max: 4 },
};

export const PHOTO_CONTENT_TYPES = ['image/jpeg', 'image/png', 'image/webp'];

const EXTENSIONS = {
  'image/jpeg': 'jpg',
  'image/png': 'png',
  'image/webp': 'webp',
};

const SIGNED_URL_SECONDS = 60 * 60;

// Paths are "<kind>/<owner id>/<random>.<ext>", which is what lets us check that
// someone is only ever attaching photos they uploaded themselves.
export function photoPath(kind, userId, contentType) {
  return `${kind}/${userId}/${randomUUID()}.${EXTENSIONS[contentType]}`;
}

export function isOwnPhotoPath(path, kind, userId) {
  return typeof path === 'string' && path.startsWith(`${kind}/${userId}/`);
}

// Rejects anything the caller didn't upload, so one person's photos can't be
// attached to another's profile, job, or review.
export function verifyOwnedPhotos(photos, kind, userId) {
  if (photos === undefined) return undefined;
  if (!Array.isArray(photos)) {
    throw new ApiError('Photos must be a list', 400, 'invalid_photos');
  }
  const { max } = PHOTO_KINDS[kind];
  if (photos.length > max) {
    throw new ApiError(`Up to ${max} photos`, 400, 'too_many_photos');
  }
  for (const path of photos) {
    if (!isOwnPhotoPath(path, kind, userId)) {
      throw new ApiError('That photo was not uploaded by you', 400, 'invalid_photos');
    }
  }
  return photos;
}

export function publicPhotoUrls(paths) {
  if (!paths?.length) return [];
  const bucket = supabase.storage.from('public-photos');
  return paths.map((path) => bucket.getPublicUrl(path).data.publicUrl);
}

// Signs every job photo across a set of rows in one call, then hands each row
// back its own URLs in the order they were stored.
export async function signJobPhotos(rows, key = 'photos') {
  const paths = [...new Set(rows.flatMap((row) => row[key] ?? []))];
  if (!paths.length) return rows;

  const { data, error } = await supabase.storage
    .from('job-photos')
    .createSignedUrls(paths, SIGNED_URL_SECONDS);

  if (error) {
    // A missing photo shouldn't take the whole list down.
    return rows.map((row) => ({ ...row, [key]: [] }));
  }

  const urlByPath = new Map(
    data.filter((item) => item.signedUrl).map((item) => [item.path, item.signedUrl])
  );

  return rows.map((row) => ({
    ...row,
    [key]: (row[key] ?? []).map((path) => urlByPath.get(path)).filter(Boolean),
  }));
}
