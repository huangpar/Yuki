import express from 'express';
import { supabase } from '../db.js';
import { verifyAuth, requireRole } from '../middleware/auth.js';
import { validate } from '../middleware/validation.js';
import { schemas } from '../validators/schemas.js';
import { asyncHandler, ApiError } from '../middleware/errorHandler.js';
import { logger } from '../middleware/logger.js';
import { signJobPhotos, verifyOwnedPhotos } from '../utils/photos.js';

const router = express.Router();

const DEFAULT_OPEN_HOURS = 24;

// What the customer would pay for an offer: hourly rates are multiplied by the
// job's length, the others are already a total. Yuki doesn't collect any of it.
function offerTotal(offer, durationMinutes) {
  const amount = Number(offer.amount);
  if (offer.rate_type !== 'hourly') return amount;
  return Math.round((amount * durationMinutes * 100) / 60) / 100;
}

function milesBetween(lat1, lon1, lat2, lon2) {
  const toRad = (deg) => (deg * Math.PI) / 180;
  const dLat = toRad(lat2 - lat1);
  const dLon = toRad(lon2 - lon1);
  const a =
    Math.sin(dLat / 2) ** 2 +
    Math.cos(toRad(lat1)) * Math.cos(toRad(lat2)) * Math.sin(dLon / 2) ** 2;
  return 6371 * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a)) * 0.621371;
}

function shapeOffer(offer, durationMinutes) {
  const provider = offer.profiles ?? {};
  return {
    offer_id: offer.id,
    provider: {
      id: offer.provider_id,
      first_name: provider.first_name ?? null,
      last_name: provider.last_name ?? null,
      hourly_rate: provider.hourly_rate ?? null,
      bio: provider.bio ?? null,
    },
    rate_type: offer.rate_type,
    amount: offer.amount === null ? null : Number(offer.amount),
    total_price: offerTotal(offer, durationMinutes),
    message: offer.message,
    status: offer.status,
    created_at: offer.created_at,
  };
}

function shapeJob(job, { offers, distanceMiles } = {}) {
  const expired = job.status === 'open' && new Date(job.expires_at) <= new Date();
  return {
    job_id: job.id,
    customer_id: job.customer_id,
    service_category: job.service_category,
    description: job.description,
    address: job.address,
    latitude: job.latitude === null ? null : Number(job.latitude),
    longitude: job.longitude === null ? null : Number(job.longitude),
    asap: job.asap,
    scheduled_for: job.scheduled_for,
    estimated_duration_minutes: job.estimated_duration_minutes,
    offered_price: Number(job.offered_price),
    status: expired ? 'expired' : job.status,
    booking_id: job.booking_id ?? null,
    created_at: job.created_at,
    expires_at: job.expires_at,
    photos: job.photos ?? [],
    ...(distanceMiles === undefined ? {} : { distance_miles: distanceMiles }),
    ...(offers === undefined
      ? {}
      : { offers: offers.map((o) => shapeOffer(o, job.estimated_duration_minutes)) }),
  };
}

// POST /api/jobs
// Customer posts a job with the price they're willing to pay
router.post(
  '/',
  verifyAuth,
  requireRole('customer'),
  validate(schemas.createJob),
  asyncHandler(async (req, res) => {
    const customerId = req.user.id;
    const { asap, scheduled_for, open_for_hours, photos, ...rest } = req.body;
    const ownPhotos = verifyOwnedPhotos(photos, 'job', customerId) ?? [];

    if (!asap && !scheduled_for) {
      throw new ApiError('Choose ASAP or a time', 400, 'missing_time');
    }

    const now = new Date();
    const { data, error } = await supabase
      .from('job_posts')
      .insert([
        {
          ...rest,
          photos: ownPhotos,
          customer_id: customerId,
          asap: Boolean(asap),
          scheduled_for: asap ? now.toISOString() : scheduled_for,
          created_at: now.toISOString(),
          expires_at: new Date(
            now.getTime() + (open_for_hours ?? DEFAULT_OPEN_HOURS) * 60 * 60 * 1000
          ).toISOString(),
        },
      ])
      .select();

    if (error) {
      throw new ApiError(`Failed to post job: ${error.message}`, 500);
    }

    logger.info('Job posted', { jobId: data[0].id, customerId });
    const [posted] = await signJobPhotos([shapeJob(data[0], { offers: [] })]);
    res.status(201).json(posted);
  })
);

// GET /api/jobs/mine
// A customer's own jobs, newest first, with the offers on each
router.get(
  '/mine',
  verifyAuth,
  requireRole('customer'),
  asyncHandler(async (req, res) => {
    const { data, error } = await supabase
      .from('job_posts')
      .select('*, job_offers(*, profiles!provider_id(first_name, last_name, hourly_rate, bio))')
      .eq('customer_id', req.user.id)
      .order('created_at', { ascending: false });

    if (error) {
      throw new ApiError(`Failed to fetch jobs: ${error.message}`, 500);
    }

    const jobs = await signJobPhotos(
      data.map((job) =>
        shapeJob(job, {
          offers: (job.job_offers ?? []).filter((o) => o.status !== 'withdrawn'),
        })
      )
    );

    res.json({ jobs });
  })
);

// GET /api/jobs/open
// Open jobs near a provider, newest first
router.get(
  '/open',
  verifyAuth,
  requireRole('provider'),
  asyncHandler(async (req, res) => {
    const providerId = req.user.id;
    const latitude = parseFloat(req.query.latitude);
    const longitude = parseFloat(req.query.longitude);
    const radius = parseInt(req.query.radius || 5, 10);

    if (isNaN(latitude) || isNaN(longitude)) {
      throw new ApiError('Location required', 400, 'missing_location');
    }

    const { data, error } = await supabase
      .from('job_posts')
      .select('*, job_offers(id, provider_id, rate_type, amount, message, status, created_at)')
      .eq('status', 'open')
      .gt('expires_at', new Date().toISOString())
      .neq('customer_id', providerId)
      .order('created_at', { ascending: false });

    if (error) {
      throw new ApiError(`Failed to fetch jobs: ${error.message}`, 500);
    }

    const jobs = data
      .map((job) => ({
        job,
        distance: milesBetween(latitude, longitude, Number(job.latitude), Number(job.longitude)),
      }))
      .filter(({ distance }) => distance <= radius)
      .map(({ job, distance }) => {
        const mine = (job.job_offers ?? []).find(
          (o) => o.provider_id === providerId && o.status !== 'withdrawn'
        );
        return {
          ...shapeJob(job, { distanceMiles: Math.round(distance * 10) / 10 }),
          offer_count: (job.job_offers ?? []).filter((o) => o.status === 'pending').length,
          my_offer: mine ? shapeOffer(mine, job.estimated_duration_minutes) : null,
        };
      });

    const withPhotos = await signJobPhotos(jobs);

    logger.info('Open jobs searched', { providerId, radius, resultsCount: jobs.length });
    res.json({ jobs: withPhotos, count: withPhotos.length });
  })
);

// GET /api/jobs/offers/mine
// A provider's own offers, newest first
router.get(
  '/offers/mine',
  verifyAuth,
  requireRole('provider'),
  asyncHandler(async (req, res) => {
    const { data, error } = await supabase
      .from('job_offers')
      .select('*, job_posts(*)')
      .eq('provider_id', req.user.id)
      .neq('status', 'withdrawn')
      .order('created_at', { ascending: false });

    if (error) {
      throw new ApiError(`Failed to fetch offers: ${error.message}`, 500);
    }

    const offers = data.map((offer) => ({
      ...shapeOffer(offer, offer.job_posts?.estimated_duration_minutes ?? 60),
      job: offer.job_posts ? shapeJob(offer.job_posts) : null,
    }));
    const signed = await signJobPhotos(
      offers.filter((o) => o.job).map((o) => o.job)
    );
    const jobById = new Map(signed.map((job) => [job.job_id, job]));

    res.json({
      offers: offers.map((offer) => ({
        ...offer,
        job: offer.job ? jobById.get(offer.job.job_id) : null,
      })),
    });
  })
);

// POST /api/jobs/offers/:offer_id/accept
// Customer accepts an offer, which becomes a booking and closes the job
router.post(
  '/offers/:offer_id/accept',
  verifyAuth,
  requireRole('customer'),
  asyncHandler(async (req, res) => {
    const customerId = req.user.id;
    const { offer_id } = req.params;

    const { data: offer, error: offerError } = await supabase
      .from('job_offers')
      .select('*, job_posts(*)')
      .eq('id', offer_id)
      .maybeSingle();

    if (offerError || !offer || !offer.job_posts) {
      throw new ApiError('Offer not found', 404);
    }

    const job = offer.job_posts;
    if (job.customer_id !== customerId) {
      throw new ApiError('Unauthorized', 403);
    }
    if (job.status !== 'open') {
      throw new ApiError('This job is no longer open', 409, 'job_closed');
    }
    if (new Date(job.expires_at) <= new Date()) {
      throw new ApiError('This job post has expired', 409, 'job_expired');
    }
    if (offer.status !== 'pending') {
      throw new ApiError('That offer is no longer available', 409, 'offer_unavailable');
    }

    const now = new Date().toISOString();
    const price = offerTotal(offer, job.estimated_duration_minutes);

    const { data: booking, error: bookingError } = await supabase
      .from('booking_requests')
      .insert([
        {
          customer_id: customerId,
          provider_id: offer.provider_id,
          status: 'accepted',
          service_category: job.service_category,
          description: job.description,
          address: job.address,
          latitude: job.latitude,
          longitude: job.longitude,
          scheduled_for: job.asap ? now : job.scheduled_for,
          estimated_duration_minutes: job.estimated_duration_minutes,
          price,
          created_at: now,
          accepted_at: now,
        },
      ])
      .select();

    if (bookingError) {
      throw new ApiError(`Failed to create booking: ${bookingError.message}`, 500);
    }

    const bookingId = booking[0].id;

    await supabase.from('job_offers').update({ status: 'accepted' }).eq('id', offer_id);
    await supabase
      .from('job_offers')
      .update({ status: 'declined' })
      .eq('job_id', job.id)
      .eq('status', 'pending')
      .neq('id', offer_id);
    const { error: jobError } = await supabase
      .from('job_posts')
      .update({ status: 'assigned', booking_id: bookingId })
      .eq('id', job.id);

    if (jobError) {
      throw new ApiError(`Failed to close job: ${jobError.message}`, 500);
    }

    logger.info('Job offer accepted', { jobId: job.id, offerId: offer_id, bookingId, price });
    res.json({ job_id: job.id, offer_id, booking_id: bookingId, price, status: 'assigned' });
  })
);

// POST /api/jobs/offers/:offer_id/decline
router.post(
  '/offers/:offer_id/decline',
  verifyAuth,
  requireRole('customer'),
  asyncHandler(async (req, res) => {
    const { offer_id } = req.params;

    const { data: offer, error } = await supabase
      .from('job_offers')
      .select('id, status, job_posts(customer_id)')
      .eq('id', offer_id)
      .maybeSingle();

    if (error || !offer || !offer.job_posts) {
      throw new ApiError('Offer not found', 404);
    }
    if (offer.job_posts.customer_id !== req.user.id) {
      throw new ApiError('Unauthorized', 403);
    }
    if (offer.status !== 'pending') {
      throw new ApiError('That offer is no longer pending', 409, 'offer_unavailable');
    }

    await supabase.from('job_offers').update({ status: 'declined' }).eq('id', offer_id);
    res.json({ offer_id, status: 'declined' });
  })
);

// POST /api/jobs/:job_id/cancel
router.post(
  '/:job_id/cancel',
  verifyAuth,
  requireRole('customer'),
  asyncHandler(async (req, res) => {
    const { job_id } = req.params;

    const { data: job, error } = await supabase
      .from('job_posts')
      .select('id, customer_id, status')
      .eq('id', job_id)
      .maybeSingle();

    if (error || !job) {
      throw new ApiError('Job not found', 404);
    }
    if (job.customer_id !== req.user.id) {
      throw new ApiError('Unauthorized', 403);
    }
    if (job.status !== 'open') {
      throw new ApiError('This job is no longer open', 409, 'job_closed');
    }

    await supabase.from('job_posts').update({ status: 'cancelled' }).eq('id', job_id);
    await supabase
      .from('job_offers')
      .update({ status: 'declined' })
      .eq('job_id', job_id)
      .eq('status', 'pending');

    logger.info('Job cancelled', { jobId: job_id, customerId: req.user.id });
    res.json({ job_id, status: 'cancelled' });
  })
);

// POST /api/jobs/:job_id/offers
// Provider takes the listed price or counters with a flat or hourly rate
router.post(
  '/:job_id/offers',
  verifyAuth,
  requireRole('provider'),
  validate(schemas.createOffer),
  asyncHandler(async (req, res) => {
    const providerId = req.user.id;
    const { job_id } = req.params;
    const { rate_type, message } = req.body;

    const { data: status, error: statusError } = await supabase
      .from('provider_statuses')
      .select('is_verified_for_work')
      .eq('id', providerId)
      .maybeSingle();

    if (statusError || !status) {
      throw new ApiError('Provider not found', 404);
    }
    if (!status.is_verified_for_work) {
      throw new ApiError('Provider must pass background check first', 403, 'not_verified');
    }

    const { data: job, error: jobError } = await supabase
      .from('job_posts')
      .select('*')
      .eq('id', job_id)
      .maybeSingle();

    if (jobError || !job) {
      throw new ApiError('Job not found', 404);
    }
    if (job.customer_id === providerId) {
      throw new ApiError('You can\'t offer on your own job', 400, 'own_job');
    }
    if (job.status !== 'open' || new Date(job.expires_at) <= new Date()) {
      throw new ApiError('This job is no longer open', 409, 'job_closed');
    }

    const amount = rate_type === 'listed' ? Number(job.offered_price) : Number(req.body.amount);
    if (!(amount > 0)) {
      throw new ApiError('Enter the rate you\'re offering', 400, 'missing_amount');
    }

    // One live offer per provider per job: a new one replaces the old.
    const { data, error } = await supabase
      .from('job_offers')
      .upsert(
        [{ job_id, provider_id: providerId, rate_type, amount, message: message ?? null, status: 'pending' }],
        { onConflict: 'job_id,provider_id' }
      )
      .select('*, profiles!provider_id(first_name, last_name, hourly_rate, bio)');

    if (error) {
      throw new ApiError(`Failed to send offer: ${error.message}`, 500);
    }

    logger.info('Job offer sent', { jobId: job_id, providerId, rateType: rate_type, amount });
    res.status(201).json(shapeOffer(data[0], job.estimated_duration_minutes));
  })
);

export default router;
