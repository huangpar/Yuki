import express from 'express';
import { supabase } from '../db.js';
import { verifyAuth, requireAdmin } from '../middleware/auth.js';
import { validate } from '../middleware/validation.js';
import { schemas } from '../validators/schemas.js';
import { asyncHandler, ApiError } from '../middleware/errorHandler.js';
import { logger } from '../middleware/logger.js';
import { shapeTicket } from './support.js';

const router = express.Router();

// Everything here is admin-only.
router.use(verifyAuth, requireAdmin);

// Counting rows without fetching them.
async function countRows(table, apply = (query) => query) {
  const { count, error } = await apply(
    supabase.from(table).select('id', { count: 'exact', head: true })
  );
  if (error) {
    throw new ApiError(`Could not count ${table}: ${error.message}`, 500);
  }
  return count ?? 0;
}

function sinceFor(window) {
  if (window === 'all') return null;
  const days = window === '7d' ? 7 : 30;
  return new Date(Date.now() - days * 24 * 60 * 60 * 1000).toISOString();
}

// GET /api/admin/overview?window=7d|30d|all
// The numbers worth watching: who's here, and how far jobs get.
router.get(
  '/overview',
  asyncHandler(async (req, res) => {
    const window = ['7d', '30d', 'all'].includes(req.query.window) ? req.query.window : '30d';
    const since = sinceFor(window);
    const inWindow = (column) => (query) => (since ? query.gte(column, since) : query);

    const [
      customers,
      providers,
      verifiedProviders,
      availableProviders,
      jobsPosted,
      offersMade,
      jobsAssigned,
      bookingsRequested,
      bookingsAccepted,
      bookingsCompleted,
      bookingsDeclined,
      reviews,
      openTickets,
      newFeedback,
    ] = await Promise.all([
      countRows('profiles', inWindow('created_at')),
      countRows('provider_statuses'),
      countRows('provider_statuses', (q) => q.eq('is_verified_for_work', true)),
      countRows('provider_statuses', (q) => q.gt('available_until', new Date().toISOString())),
      countRows('job_posts', inWindow('created_at')),
      countRows('job_offers', inWindow('created_at')),
      countRows('job_posts', (q) => inWindow('created_at')(q).eq('status', 'assigned')),
      countRows('booking_requests', inWindow('created_at')),
      countRows('booking_requests', (q) =>
        inWindow('created_at')(q).in('status', ['accepted', 'completed'])
      ),
      countRows('booking_requests', (q) => inWindow('created_at')(q).eq('status', 'completed')),
      countRows('booking_requests', (q) => inWindow('created_at')(q).eq('status', 'declined')),
      countRows('reviews', inWindow('created_at')),
      countRows('support_tickets', (q) => q.in('status', ['open', 'in_progress'])),
      countRows('app_feedback', (q) => q.eq('status', 'new')),
    ]);

    // A rate is only meaningful once there's something to divide by.
    const rate = (part, whole) => (whole === 0 ? null : Math.round((part / whole) * 100));

    res.json({
      window,
      people: {
        accounts: customers,
        providers,
        verified_providers: verifiedProviders,
        available_now: availableProviders,
      },
      jobs: {
        posted: jobsPosted,
        offers_made: offersMade,
        assigned: jobsAssigned,
        // How far a posted job gets: did anyone offer, and did the customer pick one.
        match_rate: rate(jobsAssigned, jobsPosted),
      },
      bookings: {
        requested: bookingsRequested,
        accepted: bookingsAccepted,
        completed: bookingsCompleted,
        declined: bookingsDeclined,
        acceptance_rate: rate(bookingsAccepted, bookingsRequested),
        completion_rate: rate(bookingsCompleted, bookingsAccepted),
      },
      reviews: { written: reviews },
      queue: { open_tickets: openTickets, new_feedback: newFeedback },
    });
  })
);

// GET /api/admin/feedback?status=new|read|resolved|all
router.get(
  '/feedback',
  asyncHandler(async (req, res) => {
    const status = req.query.status ?? 'all';

    let query = supabase
      .from('app_feedback')
      .select('*, profiles:user_id(first_name, last_name, email)')
      .order('created_at', { ascending: false })
      .limit(100);

    if (status !== 'all') {
      query = query.eq('status', status);
    }

    const { data, error } = await query;
    if (error) {
      throw new ApiError(`Could not fetch feedback: ${error.message}`, 500);
    }

    res.json({
      feedback: data.map((item) => ({
        feedback_id: item.id,
        category: item.category,
        message: item.message,
        context: item.context,
        status: item.status,
        admin_note: item.admin_note,
        created_at: item.created_at,
        from: item.profiles
          ? {
              name: `${item.profiles.first_name ?? ''} ${item.profiles.last_name ?? ''}`.trim(),
              email: item.profiles.email,
            }
          : null,
      })),
    });
  })
);

// PATCH /api/admin/feedback/:feedback_id
router.patch(
  '/feedback/:feedback_id',
  validate(schemas.updateFeedback),
  asyncHandler(async (req, res) => {
    const { status, admin_note } = req.body;

    const { data, error } = await supabase
      .from('app_feedback')
      .update({
        ...(status === undefined ? {} : { status }),
        ...(admin_note === undefined ? {} : { admin_note }),
        updated_at: new Date().toISOString(),
      })
      .eq('id', req.params.feedback_id)
      .select('id, status, admin_note');

    if (error || !data?.length) {
      throw new ApiError('Feedback not found', 404);
    }

    logger.info('Feedback updated', { feedbackId: req.params.feedback_id, status });
    res.json(data[0]);
  })
);

// GET /api/admin/tickets?status=open|in_progress|resolved|closed|all
router.get(
  '/tickets',
  asyncHandler(async (req, res) => {
    const status = req.query.status ?? 'open';

    let query = supabase
      .from('support_tickets')
      .select('*, profiles:reporter_id(first_name, last_name, email)')
      .order('created_at', { ascending: false })
      .limit(100);

    if (status !== 'all') {
      query = query.eq('status', status);
    }

    const { data, error } = await query;
    if (error) {
      throw new ApiError(`Could not fetch tickets: ${error.message}`, 500);
    }

    res.json({
      tickets: data.map((ticket) => ({
        ...shapeTicket(ticket),
        reporter: ticket.profiles
          ? {
              name: `${ticket.profiles.first_name ?? ''} ${ticket.profiles.last_name ?? ''}`.trim(),
              email: ticket.profiles.email,
            }
          : null,
      })),
    });
  })
);

// PATCH /api/admin/tickets/:ticket_id
router.patch(
  '/tickets/:ticket_id',
  validate(schemas.updateTicket),
  asyncHandler(async (req, res) => {
    const { status, admin_note } = req.body;
    const settled = status === 'resolved' || status === 'closed';

    const { data, error } = await supabase
      .from('support_tickets')
      .update({
        ...(status === undefined ? {} : { status }),
        ...(admin_note === undefined ? {} : { admin_note }),
        ...(status === undefined ? {} : { resolved_at: settled ? new Date().toISOString() : null }),
        updated_at: new Date().toISOString(),
      })
      .eq('id', req.params.ticket_id)
      .select('*');

    if (error || !data?.length) {
      throw new ApiError('Ticket not found', 404);
    }

    logger.info('Ticket updated', { ticketId: req.params.ticket_id, status });
    res.json(shapeTicket(data[0]));
  })
);

// GET /api/admin/providers?verified=false|true|all
// The verification queue: who is waiting, and who has been approved.
router.get(
  '/providers',
  asyncHandler(async (req, res) => {
    const verified = req.query.verified ?? 'false';

    let query = supabase
      .from('provider_statuses')
      .select('id, is_verified_for_work, availability_status, available_until, profiles:id(*)')
      .limit(100);

    if (verified !== 'all') {
      query = query.eq('is_verified_for_work', verified === 'true');
    }

    const { data, error } = await query;
    if (error) {
      throw new ApiError(`Could not fetch providers: ${error.message}`, 500);
    }

    res.json({
      providers: data.map((row) => {
        const profile = row.profiles ?? {};
        return {
          id: row.id,
          first_name: profile.first_name,
          last_name: profile.last_name,
          email: profile.email,
          phone: profile.phone,
          hourly_rate: profile.hourly_rate,
          categories: profile.categories ?? [],
          bio: profile.bio,
          rating: profile.rating_count ? profile.rating_total / profile.rating_count : null,
          review_count: profile.rating_count ?? 0,
          is_verified_for_work: row.is_verified_for_work,
          available_until: row.available_until,
          joined_at: profile.created_at,
        };
      }),
    });
  })
);

// POST /api/admin/providers/:provider_id/verification
// Approve a provider to take work, or take that back.
router.post(
  '/providers/:provider_id/verification',
  validate(schemas.setVerification),
  asyncHandler(async (req, res) => {
    const { verified } = req.body;
    const { provider_id } = req.params;

    const update = { is_verified_for_work: verified };
    // Someone who is no longer approved shouldn't stay on the map.
    if (!verified) {
      update.availability_status = 'offline';
      update.available_until = null;
    }

    const { data, error } = await supabase
      .from('provider_statuses')
      .update(update)
      .eq('id', provider_id)
      .select('id, is_verified_for_work');

    if (error || !data?.length) {
      throw new ApiError('Provider not found', 404);
    }

    await supabase.from('audit_logs').insert([
      {
        user_id: req.user.id,
        event_type: verified ? 'provider_verified' : 'provider_unverified',
        event_details: { provider_id },
      },
    ]);

    logger.info('Provider verification changed', { providerId: provider_id, verified });
    res.json(data[0]);
  })
);

export default router;
