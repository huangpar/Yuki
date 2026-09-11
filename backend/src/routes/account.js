import express from 'express';
import { supabase } from '../db.js';
import { verifyAuth, requireRole } from '../middleware/auth.js';
import { validate } from '../middleware/validation.js';
import { schemas } from '../validators/schemas.js';
import { asyncHandler, ApiError } from '../middleware/errorHandler.js';
import { logger } from '../middleware/logger.js';

const router = express.Router();

async function loadAccount(userId) {
  const [profileResult, providerResult] = await Promise.all([
    supabase
      .from('profiles')
      .select('first_name, last_name, email, phone')
      .eq('id', userId)
      .single(),
    supabase.from('provider_statuses').select('id').eq('id', userId).maybeSingle(),
  ]);

  if (profileResult.error) {
    throw new ApiError('Profile not found', 404);
  }

  return {
    id: userId,
    ...profileResult.data,
    is_provider: Boolean(providerResult.data),
  };
}

// GET /api/me
router.get(
  '/',
  verifyAuth,
  requireRole('customer'),
  asyncHandler(async (req, res) => {
    res.json(await loadAccount(req.user.id));
  })
);

// PUT /api/me
// Fills in what sign-in didn't provide (Google and Apple don't share a phone number)
// and optionally adds a provider profile to the account.
router.put(
  '/',
  verifyAuth,
  requireRole('customer'),
  validate(schemas.completeProfile),
  asyncHandler(async (req, res) => {
    const userId = req.user.id;
    const { first_name, last_name, phone, offer_services } = req.body;

    const { error } = await supabase
      .from('profiles')
      .update({ first_name, last_name, phone })
      .eq('id', userId);

    if (error) {
      throw new ApiError(`Failed to update profile: ${error.message}`, 500);
    }

    if (offer_services) {
      const { error: providerError } = await supabase
        .from('provider_statuses')
        .upsert({ id: userId }, { onConflict: 'id', ignoreDuplicates: true });

      if (providerError) {
        throw new ApiError(`Failed to add provider profile: ${providerError.message}`, 500);
      }
    }

    logger.info('Profile completed', { userId, offerServices: Boolean(offer_services) });

    res.json(await loadAccount(userId));
  })
);

export default router;
