import express from 'express';
import { supabase } from '../db.js';
import { verifyAuth } from '../middleware/auth.js';
import { validate } from '../middleware/validation.js';
import { schemas } from '../validators/schemas.js';
import { asyncHandler, ApiError } from '../middleware/errorHandler.js';
import { logger } from '../middleware/logger.js';

const router = express.Router();

// Keeps the running totals on profiles in step with the reviews themselves.
async function refreshRating(subjectId) {
  const { data, error } = await supabase
    .from('reviews')
    .select('rating')
    .eq('subject_id', subjectId);

  if (error) {
    throw new ApiError(`Failed to update rating: ${error.message}`, 500);
  }

  const total = data.reduce((sum, review) => sum + review.rating, 0);
  await supabase
    .from('profiles')
    .update({ rating_total: total, rating_count: data.length })
    .eq('id', subjectId);

  return { total, count: data.length };
}

function shapeReview(review) {
  const reviewer = review.profiles ?? {};
  const first = reviewer.first_name ?? '';
  const last = reviewer.last_name ?? '';
  const name = [first, last ? `${last[0]}.` : ''].filter(Boolean).join(' ');
  return {
    review_id: review.id,
    booking_id: review.booking_id,
    reviewer_name: name || 'Someone',
    reviewer_role: review.reviewer_role,
    rating: review.rating,
    comment: review.comment,
    created_at: review.created_at,
  };
}

// POST /api/reviews
// Rate the other side of a completed booking. Posting again updates your review.
router.post(
  '/',
  verifyAuth,
  validate(schemas.createReview),
  asyncHandler(async (req, res) => {
    const userId = req.user.id;
    const { booking_id, rating, comment } = req.body;

    const { data: booking, error } = await supabase
      .from('booking_requests')
      .select('id, customer_id, provider_id, status')
      .eq('id', booking_id)
      .maybeSingle();

    if (error || !booking) {
      throw new ApiError('Booking not found', 404);
    }

    const isCustomer = booking.customer_id === userId;
    const isProvider = booking.provider_id === userId;
    if (!isCustomer && !isProvider) {
      throw new ApiError('Unauthorized', 403);
    }
    if (booking.status !== 'completed') {
      throw new ApiError('You can review once the job is marked complete', 409, 'not_completed');
    }

    const subjectId = isCustomer ? booking.provider_id : booking.customer_id;
    if (!subjectId) {
      throw new ApiError('Nobody to review on this booking', 409, 'no_subject');
    }

    const now = new Date().toISOString();
    const { data: saved, error: saveError } = await supabase
      .from('reviews')
      .upsert(
        [
          {
            booking_id,
            reviewer_id: userId,
            subject_id: subjectId,
            reviewer_role: isCustomer ? 'customer' : 'provider',
            rating,
            comment: comment ?? null,
            updated_at: now,
          },
        ],
        { onConflict: 'booking_id,reviewer_id' }
      )
      .select('*, profiles!reviewer_id(first_name, last_name)');

    if (saveError) {
      throw new ApiError(`Failed to save review: ${saveError.message}`, 500);
    }

    const totals = await refreshRating(subjectId);
    logger.info('Review saved', { bookingId: booking_id, reviewerId: userId, rating });

    res.status(201).json({
      ...shapeReview(saved[0]),
      subject_rating: totals.count === 0 ? null : totals.total / totals.count,
      subject_review_count: totals.count,
    });
  })
);

// GET /api/reviews/for/:profile_id
// Reviews written about someone, newest first.
// Public, like the map itself: people compare providers before they sign up,
// and reviewer names are already shortened to a first name and an initial.
router.get(
  '/for/:profile_id',
  asyncHandler(async (req, res) => {
    const { profile_id } = req.params;

    const [reviewsResult, profileResult] = await Promise.all([
      supabase
        .from('reviews')
        .select('*, profiles!reviewer_id(first_name, last_name)')
        .eq('subject_id', profile_id)
        .order('created_at', { ascending: false })
        .limit(50),
      supabase
        .from('profiles')
        .select('rating_total, rating_count, external_reviews_url')
        .eq('id', profile_id)
        .maybeSingle(),
    ]);

    if (reviewsResult.error) {
      throw new ApiError(`Failed to fetch reviews: ${reviewsResult.error.message}`, 500);
    }

    const profile = profileResult.data ?? { rating_total: 0, rating_count: 0 };
    res.json({
      reviews: reviewsResult.data.map(shapeReview),
      rating: profile.rating_count === 0 ? null : profile.rating_total / profile.rating_count,
      review_count: profile.rating_count,
      external_reviews_url: profile.external_reviews_url ?? null,
    });
  })
);

export default router;
