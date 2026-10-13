import express from 'express';
import { supabase } from '../db.js';
import { verifyAuth } from '../middleware/auth.js';
import { asyncHandler, ApiError } from '../middleware/errorHandler.js';
import { logger } from '../middleware/logger.js';
import { PHOTO_KINDS, PHOTO_CONTENT_TYPES, photoPath } from '../utils/photos.js';

const router = express.Router();

// POST /api/uploads/photo
// Hands back a one-shot URL the app uploads the image straight to, so photo
// bytes never travel through this server and no storage key ships in the app.
// The caller then sends the returned path along with the profile, job, or review.
router.post(
  '/photo',
  verifyAuth,
  asyncHandler(async (req, res) => {
    const userId = req.user.id;
    const { kind, content_type: contentType } = req.body;

    const config = PHOTO_KINDS[kind];
    if (!config) {
      throw new ApiError('Unknown photo kind', 400, 'invalid_kind');
    }
    if (!PHOTO_CONTENT_TYPES.includes(contentType)) {
      throw new ApiError('Photos must be a JPEG, PNG, or WebP', 400, 'invalid_content_type');
    }

    const path = photoPath(kind, userId, contentType);
    const { data, error } = await supabase.storage
      .from(config.bucket)
      .createSignedUploadUrl(path);

    if (error) {
      throw new ApiError(`Could not start the upload: ${error.message}`, 500);
    }

    logger.info('Photo upload signed', { userId, kind });

    res.status(201).json({
      path,
      upload_url: data.signedUrl,
      token: data.token,
      max_photos: config.max,
    });
  })
);

export default router;
