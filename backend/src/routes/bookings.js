import express from 'express';
import { supabase } from '../db.js';
import { verifyAuth, requireRole } from '../middleware/auth.js';
import { validate } from '../middleware/validation.js';
import { schemas } from '../validators/schemas.js';
import { asyncHandler, ApiError } from '../middleware/errorHandler.js';
import { logger } from '../middleware/logger.js';

const router = express.Router();

// POST /api/bookings
// Create booking request (customer)
router.post(
  '/',
  verifyAuth,
  requireRole('customer'),
  validate(schemas.createBooking),
  asyncHandler(async (req, res) => {
    const customerId = req.user.id;
    const {
      provider_id,
      service_category,
      description,
      address,
      latitude,
      longitude,
      asap,
      estimated_duration_minutes,
    } = req.body;

    if (provider_id === customerId) {
      throw new ApiError('You can\'t book yourself', 400, 'cannot_book_self');
    }

    if (!asap && !req.body.scheduled_for) {
      throw new ApiError('Choose ASAP or a time', 400, 'missing_time');
    }
    // ASAP uses the server clock so the request is never "in the past" by the time it arrives
    const scheduledFor = asap ? new Date().toISOString() : req.body.scheduled_for;

    const [statusResult, profileResult] = await Promise.all([
      supabase
        .from('provider_statuses')
        .select('is_verified_for_work')
        .eq('id', provider_id)
        .maybeSingle(),
      supabase
        .from('profiles')
        .select('hourly_rate, categories')
        .eq('id', provider_id)
        .maybeSingle(),
    ]);

    const provider = statusResult.data;
    const profile = profileResult.data;

    if (statusResult.error || profileResult.error || !provider || !profile) {
      throw new ApiError('Provider not found', 404);
    }

    if (!provider.is_verified_for_work) {
      throw new ApiError('Provider is not verified', 403, 'provider_not_verified');
    }

    if (profile.hourly_rate === null || !profile.categories?.includes(service_category)) {
      throw new ApiError('This provider doesn\'t offer that service', 400, 'service_not_offered');
    }

    // Price comes from the provider's rate, never from the client
    const price =
      Math.round((Number(profile.hourly_rate) * estimated_duration_minutes * 100) / 60) / 100;

    const createdAt = new Date().toISOString();
    const expiresAt = new Date(Date.now() + 10 * 60 * 1000).toISOString(); // 10 minutes

    const { data: booking, error: bookingError } = await supabase
      .from('booking_requests')
      .insert([
        {
          customer_id: customerId,
          provider_id,
          status: 'pending_acceptance',
          service_category,
          description,
          address,
          latitude,
          longitude,
          scheduled_for: scheduledFor,
          estimated_duration_minutes,
          price,
          created_at: createdAt,
          expires_at: expiresAt,
        },
      ])
      .select();

    if (bookingError) {
      throw new ApiError(`Failed to create booking: ${bookingError.message}`, 500);
    }

    const bookingId = booking[0].id;

    logger.info('Booking request created', {
      bookingId,
      customerId,
      providerId: provider_id,
      price,
      expiresAt,
    });

    // Log audit event
    await supabase.from('audit_logs').insert([
      {
        user_id: customerId,
        event_type: 'booking_requested',
        event_details: {
          booking_id: bookingId,
          provider_id,
          price,
        },
      },
    ]);

    res.status(201).json({
      booking_id: bookingId,
      customer_id: customerId,
      provider_id,
      status: 'pending_acceptance',
      service_category,
      description,
      address,
      latitude,
      longitude,
      scheduled_for: scheduledFor,
      estimated_duration_minutes,
      price,
      created_at: createdAt,
      expires_at: expiresAt,
      next_step: 'waiting_for_provider',
    });
  })
);

// GET /api/customers/bookings
// List customer's bookings
router.get(
  '/customers/bookings',
  verifyAuth,
  requireRole('customer'),
  asyncHandler(async (req, res) => {
    const customerId = req.user.id;
    const { status } = req.query;
    const limit = parseInt(req.query.limit || 20, 10);
    const offset = parseInt(req.query.offset || 0, 10);

    let query = supabase
      .from('booking_requests')
      .select(
        `
        id,
        customer_id,
        provider_id,
        status,
        service_category,
        description,
        address,
        scheduled_for,
        estimated_duration_minutes,
        price,
        created_at,
        expires_at,
        accepted_at,
        completed_at,
        cancelled_at,
        profiles!provider_id (
          first_name,
          last_name,
          hourly_rate
        )
      `
      )
      .eq('customer_id', customerId)
      .order('created_at', { ascending: false })
      .range(offset, offset + limit - 1);

    if (status) {
      query = query.eq('status', status);
    }

    const { data: bookings, error, count } = await query;

    if (error) {
      throw new ApiError(`Failed to fetch bookings: ${error.message}`, 500);
    }

    logger.info('Customer bookings listed', {
      customerId,
      count: bookings.length,
      status,
    });

    res.json({
      bookings: bookings.map((b) => ({
        booking_id: b.id,
        customer_id: b.customer_id,
        provider: {
          id: b.provider_id,
          first_name: b.profiles?.first_name ?? null,
          last_name: b.profiles?.last_name ?? null,
          hourly_rate: b.profiles?.hourly_rate ?? null,
        },
        status: b.status,
        service_category: b.service_category,
        description: b.description,
        address: b.address,
        scheduled_for: b.scheduled_for,
        estimated_duration_minutes: b.estimated_duration_minutes,
        price: b.price,
        created_at: b.created_at,
        expires_at: b.expires_at,
        accepted_at: b.accepted_at,
        completed_at: b.completed_at,
        cancelled_at: b.cancelled_at,
      })),
      total: count,
      limit: parseInt(limit),
      offset: parseInt(offset),
    });
  })
);

// GET /api/providers/bookings
// List provider's bookings
router.get(
  '/providers/bookings',
  verifyAuth,
  requireRole('provider'),
  asyncHandler(async (req, res) => {
    const providerId = req.user.id;
    const { status } = req.query;
    const limit = parseInt(req.query.limit || 20, 10);
    const offset = parseInt(req.query.offset || 0, 10);

    let query = supabase
      .from('booking_requests')
      .select(
        `
        id,
        customer_id,
        provider_id,
        status,
        service_category,
        description,
        address,
        latitude,
        longitude,
        scheduled_for,
        estimated_duration_minutes,
        price,
        created_at,
        expires_at,
        accepted_at,
        completed_at,
        cancelled_at,
        profiles!customer_id (
          first_name,
          last_name,
          email,
          phone
        )
      `
      )
      .eq('provider_id', providerId)
      .order('created_at', { ascending: false })
      .range(offset, offset + limit - 1);

    if (status) {
      query = query.eq('status', status);
    }

    // Expired requests can no longer be accepted
    if (status === 'pending_acceptance') {
      query = query.gt('expires_at', new Date().toISOString());
    }

    const { data: bookings, error, count } = await query;

    if (error) {
      throw new ApiError(`Failed to fetch bookings: ${error.message}`, 500);
    }

    logger.info('Provider bookings listed', {
      providerId,
      count: bookings.length,
      status,
    });

    res.json({
      bookings: bookings.map((b) => ({
        booking_id: b.id,
        customer: {
          id: b.customer_id,
          first_name: b.profiles?.first_name ?? null,
          last_name: b.profiles?.last_name ?? null,
          email: b.profiles?.email ?? null,
          phone: b.profiles?.phone ?? null,
        },
        status: b.status,
        service_category: b.service_category,
        description: b.description,
        address: b.address,
        latitude: b.latitude,
        longitude: b.longitude,
        scheduled_for: b.scheduled_for,
        estimated_duration_minutes: b.estimated_duration_minutes,
        price: b.price,
        created_at: b.created_at,
        expires_at: b.expires_at,
        accepted_at: b.accepted_at,
        completed_at: b.completed_at,
        cancelled_at: b.cancelled_at,
      })),
      total: count,
      limit: parseInt(limit),
      offset: parseInt(offset),
    });
  })
);

// GET /api/bookings/:booking_id
// Get booking details (both customer and provider can view)
router.get(
  '/:booking_id',
  verifyAuth,
  asyncHandler(async (req, res) => {
    const userId = req.user.id;
    const { booking_id } = req.params;

    const { data: booking, error } = await supabase
      .from('booking_requests')
      .select(
        `
        id,
        customer_id,
        provider_id,
        status,
        service_category,
        description,
        address,
        latitude,
        longitude,
        scheduled_for,
        estimated_duration_minutes,
        price,
        created_at,
        expires_at,
        accepted_at,
        completed_at,
        cancelled_at
      `
      )
      .eq('id', booking_id)
      .single();

    if (error || !booking) {
      throw new ApiError('Booking not found', 404);
    }

    // Verify user is customer or provider for this booking
    if (userId !== booking.customer_id && userId !== booking.provider_id) {
      throw new ApiError('Unauthorized', 403);
    }

    logger.info('Booking details retrieved', {
      bookingId: booking_id,
      userId,
    });

    res.json({
      booking_id: booking.id,
      customer_id: booking.customer_id,
      provider_id: booking.provider_id,
      status: booking.status,
      service_category: booking.service_category,
      description: booking.description,
      address: booking.address,
      latitude: booking.latitude,
      longitude: booking.longitude,
      scheduled_for: booking.scheduled_for,
      estimated_duration_minutes: booking.estimated_duration_minutes,
      price: booking.price,
      created_at: booking.created_at,
      expires_at: booking.expires_at,
      accepted_at: booking.accepted_at,
      completed_at: booking.completed_at,
      cancelled_at: booking.cancelled_at,
    });
  })
);

// POST /api/bookings/:booking_id/accept
// Provider accepts booking
router.post(
  '/:booking_id/accept',
  verifyAuth,
  requireRole('provider'),
  validate(schemas.acceptBooking),
  asyncHandler(async (req, res) => {
    const providerId = req.user.id;
    const { booking_id } = req.params;
    const { estimated_arrival_minutes } = req.body;

    // Get booking
    const { data: booking, error: getError } = await supabase
      .from('booking_requests')
      .select('id, provider_id, status, customer_id, price, expires_at')
      .eq('id', booking_id)
      .single();

    if (getError || !booking) {
      throw new ApiError('Booking not found', 404);
    }

    // Verify provider
    if (booking.provider_id !== providerId) {
      throw new ApiError('Unauthorized', 403);
    }

    // Check status
    if (booking.status !== 'pending_acceptance') {
      throw new ApiError('Booking is no longer pending', 409, 'invalid_status');
    }

    if (booking.expires_at && new Date(booking.expires_at) <= new Date()) {
      throw new ApiError('This request has expired', 409, 'booking_expired');
    }

    // Update booking
    const { data: updated, error: updateError } = await supabase
      .from('booking_requests')
      .update({
        status: 'accepted',
        accepted_at: new Date().toISOString(),
      })
      .eq('id', booking_id)
      .select();

    if (updateError) {
      throw new ApiError(`Failed to accept booking: ${updateError.message}`, 500);
    }

    logger.info('Booking accepted', {
      bookingId: booking_id,
      providerId,
      estimatedArrival: estimated_arrival_minutes,
    });

    // Log audit event
    await supabase.from('audit_logs').insert([
      {
        user_id: providerId,
        event_type: 'booking_accepted',
        event_details: {
          booking_id,
          customer_id: booking.customer_id,
          estimated_arrival_minutes,
        },
      },
    ]);

    res.json({
      booking_id,
      status: 'accepted',
      accepted_at: new Date().toISOString(),
      estimated_arrival_minutes,
      next_step: 'en_route',
    });
  })
);

// POST /api/bookings/:booking_id/decline
// Provider declines booking
router.post(
  '/:booking_id/decline',
  verifyAuth,
  requireRole('provider'),
  asyncHandler(async (req, res) => {
    const providerId = req.user.id;
    const { booking_id } = req.params;

    // Get booking
    const { data: booking, error: getError } = await supabase
      .from('booking_requests')
      .select('id, provider_id, status, customer_id')
      .eq('id', booking_id)
      .single();

    if (getError || !booking) {
      throw new ApiError('Booking not found', 404);
    }

    // Verify provider
    if (booking.provider_id !== providerId) {
      throw new ApiError('Unauthorized', 403);
    }

    // Check status
    if (booking.status !== 'pending_acceptance') {
      throw new ApiError('Booking is no longer pending', 409, 'invalid_status');
    }

    // Update booking
    const { error: updateError } = await supabase
      .from('booking_requests')
      .update({
        status: 'declined',
        cancelled_at: new Date().toISOString(),
      })
      .eq('id', booking_id);

    if (updateError) {
      throw new ApiError(`Failed to decline booking: ${updateError.message}`, 500);
    }

    logger.info('Booking declined', {
      bookingId: booking_id,
      providerId,
    });

    // Log audit event
    await supabase.from('audit_logs').insert([
      {
        user_id: providerId,
        event_type: 'booking_declined',
        event_details: {
          booking_id,
          customer_id: booking.customer_id,
        },
      },
    ]);

    res.json({
      booking_id,
      status: 'declined',
      cancelled_at: new Date().toISOString(),
      next_step: 'available_for_other_bookings',
    });
  })
);

// POST /api/bookings/:booking_id/complete
// Mark booking as completed (after service provided)
router.post(
  '/:booking_id/complete',
  verifyAuth,
  requireRole('provider'),
  validate(schemas.completeBooking),
  asyncHandler(async (req, res) => {
    const providerId = req.user.id;
    const { booking_id } = req.params;
    const { actual_duration_minutes, notes } = req.body;

    // Get booking
    const { data: booking, error: getError } = await supabase
      .from('booking_requests')
      .select('id, provider_id, status, customer_id, price')
      .eq('id', booking_id)
      .single();

    if (getError || !booking) {
      throw new ApiError('Booking not found', 404);
    }

    // Verify provider
    if (booking.provider_id !== providerId) {
      throw new ApiError('Unauthorized', 403);
    }

    // Check status
    if (booking.status !== 'accepted') {
      throw new ApiError('Booking must be accepted before completion', 409, 'invalid_status');
    }

    // Update booking
    const completedAt = new Date().toISOString();
    const disputeDeadline = new Date(Date.now() + 48 * 60 * 60 * 1000).toISOString();

    const { error: updateError } = await supabase
      .from('booking_requests')
      .update({
        status: 'completed',
        completed_at: completedAt,
      })
      .eq('id', booking_id);

    if (updateError) {
      throw new ApiError(`Failed to complete booking: ${updateError.message}`, 500);
    }

    logger.info('Booking completed', {
      bookingId: booking_id,
      providerId,
      actualDuration: actual_duration_minutes,
      price: booking.price,
      disputeDeadline,
    });

    // Log audit event
    await supabase.from('audit_logs').insert([
      {
        user_id: providerId,
        event_type: 'booking_completed',
        event_details: {
          booking_id,
          customer_id: booking.customer_id,
          actual_duration_minutes,
          notes,
          price: booking.price,
        },
      },
    ]);

    res.json({
      booking_id,
      status: 'completed',
      completed_at: completedAt,
      actual_duration_minutes,
      notes,
      payment_status: 'pending',
      payment_released_at: disputeDeadline,
      next_step: 'waiting_for_payment_release',
    });
  })
);

export default router;
