import express from 'express';
import { supabase } from '../db.js';
import { verifyAuth } from '../middleware/auth.js';
import { validate } from '../middleware/validation.js';
import { schemas } from '../validators/schemas.js';
import { asyncHandler, ApiError } from '../middleware/errorHandler.js';
import { logger } from '../middleware/logger.js';

const router = express.Router();

function shapeTicket(ticket) {
  return {
    ticket_id: ticket.id,
    subject_type: ticket.subject_type,
    booking_id: ticket.booking_id,
    job_id: ticket.job_id,
    category: ticket.category,
    message: ticket.message,
    status: ticket.status,
    admin_note: ticket.admin_note,
    created_at: ticket.created_at,
    resolved_at: ticket.resolved_at,
  };
}

// POST /api/support/tickets
// Report a problem, optionally about a specific booking or job.
router.post(
  '/tickets',
  verifyAuth,
  validate(schemas.createTicket),
  asyncHandler(async (req, res) => {
    const reporterId = req.user.id;
    const { subject_type, booking_id, job_id, category, message } = req.body;

    // You can only raise a ticket about something you were part of.
    if (booking_id) {
      const { data: booking } = await supabase
        .from('booking_requests')
        .select('id, customer_id, provider_id')
        .eq('id', booking_id)
        .maybeSingle();

      if (!booking) {
        throw new ApiError('Booking not found', 404);
      }
      if (booking.customer_id !== reporterId && booking.provider_id !== reporterId) {
        throw new ApiError('That booking is not yours', 403);
      }
    }

    if (job_id) {
      const { data: job } = await supabase
        .from('job_posts')
        .select('id, customer_id')
        .eq('id', job_id)
        .maybeSingle();

      if (!job) {
        throw new ApiError('Job not found', 404);
      }
      if (job.customer_id !== reporterId) {
        // Providers can report a job they made an offer on.
        const { data: offer } = await supabase
          .from('job_offers')
          .select('id')
          .eq('job_id', job_id)
          .eq('provider_id', reporterId)
          .maybeSingle();

        if (!offer) {
          throw new ApiError('That job is not yours', 403);
        }
      }
    }

    const { data, error } = await supabase
      .from('support_tickets')
      .insert([
        {
          reporter_id: reporterId,
          subject_type,
          booking_id: booking_id ?? null,
          job_id: job_id ?? null,
          category,
          message,
        },
      ])
      .select('*');

    if (error) {
      throw new ApiError(`Could not open your ticket: ${error.message}`, 500);
    }

    logger.info('Support ticket opened', { ticketId: data[0].id, category, subject_type });
    res.status(201).json(shapeTicket(data[0]));
  })
);

// GET /api/support/tickets
// The tickets you raised, newest first, so you can see where they got to.
router.get(
  '/tickets',
  verifyAuth,
  asyncHandler(async (req, res) => {
    const { data, error } = await supabase
      .from('support_tickets')
      .select('*')
      .eq('reporter_id', req.user.id)
      .order('created_at', { ascending: false })
      .limit(50);

    if (error) {
      throw new ApiError(`Could not fetch your tickets: ${error.message}`, 500);
    }

    res.json({ tickets: data.map(shapeTicket) });
  })
);

export { shapeTicket };
export default router;
