import express from 'express';
import { supabase } from '../db.js';
import { verifyAuth } from '../middleware/auth.js';
import { validate } from '../middleware/validation.js';
import { schemas } from '../validators/schemas.js';
import { asyncHandler, ApiError } from '../middleware/errorHandler.js';
import { logger } from '../middleware/logger.js';

const router = express.Router();

// POST /api/feedback
// Someone's thoughts about Yuki itself. Not about another person - that's a
// review - and not about one job going wrong - that's a support ticket.
router.post(
  '/',
  verifyAuth,
  validate(schemas.createFeedback),
  asyncHandler(async (req, res) => {
    const { category, message, context } = req.body;

    const { data, error } = await supabase
      .from('app_feedback')
      .insert([
        {
          user_id: req.user.id,
          category,
          message,
          context: context ?? null,
        },
      ])
      .select('id, category, status, created_at');

    if (error) {
      throw new ApiError(`Could not send your feedback: ${error.message}`, 500);
    }

    logger.info('Feedback received', { feedbackId: data[0].id, category });
    res.status(201).json(data[0]);
  })
);

export default router;
