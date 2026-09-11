import express from 'express';
import Stripe from 'stripe';
import { supabase } from '../db.js';
import { verifyAuth, requireRole } from '../middleware/auth.js';
import { validate } from '../middleware/validation.js';
import { schemas } from '../validators/schemas.js';
import { asyncHandler, ApiError } from '../middleware/errorHandler.js';
import { logger } from '../middleware/logger.js';
import config from '../config.js';

const router = express.Router();
const stripe = new Stripe(config.stripe.secretKey);

// POST /api/providers/signup
// Create new provider account
router.post(
  '/signup',
  validate(schemas.signup),
  asyncHandler(async (req, res) => {
    const { email, password, first_name, last_name, phone, role } = req.body;

    // Force role to 'provider' (even if user tries to override)
    if (role !== 'provider') {
      throw new ApiError('Only provider signup allowed on this endpoint', 400, 'invalid_role');
    }

    // Create auth user via Supabase
    const { data: authData, error: authError } = await supabase.auth.signUp({
      email,
      password,
    });

    if (authError) {
      if (authError.message.includes('already registered')) {
        throw new ApiError('Email already registered', 409, 'email_exists');
      }
      throw new ApiError(`Signup failed: ${authError.message}`, 400, 'signup_failed');
    }

    const userId = authData.user.id;

    // Create profile
    const { error: profileError } = await supabase.from('profiles').insert([
      {
        id: userId,
        email,
        phone,
        first_name,
        last_name,
        role: 'provider',
      },
    ]);

    if (profileError) {
      throw new ApiError(`Failed to create profile: ${profileError.message}`, 500);
    }

    // Create provider_statuses record
    const { error: statusError } = await supabase
      .from('provider_statuses')
      .insert([
        {
          id: userId,
          background_check_status: 'not_started',
          is_verified_for_work: false,
          availability_status: 'offline',
        },
      ]);

    if (statusError) {
      throw new ApiError(`Failed to create provider status: ${statusError.message}`, 500);
    }

    logger.info('Provider signup successful', {
      providerId: userId,
      email,
    });

    res.status(201).json({
      id: userId,
      email,
      first_name,
      last_name,
      phone,
      role: 'provider',
      session: {
        access_token: authData.session.access_token,
        refresh_token: authData.session.refresh_token,
        expires_in: 3600,
      },
      next_step: 'profile_setup',
    });
  })
);

// PUT /api/providers/profile
// Update provider profile (services, bio, rate)
router.put(
  '/profile',
  verifyAuth,
  requireRole('provider'),
  validate(schemas.updateProviderProfile),
  asyncHandler(async (req, res) => {
    const providerId = req.user.id;
    const { bio, hourly_rate, categories } = req.body;

    // Update provider profile
    const { data, error } = await supabase
      .from('profiles')
      .update({
        bio,
        hourly_rate,
        categories,
      })
      .eq('id', providerId)
      .select();

    if (error) {
      throw new ApiError(`Failed to update profile: ${error.message}`, 500);
    }

    logger.info('Provider profile updated', {
      providerId,
      categories,
      hourlyRate: hourly_rate,
    });

    res.json({
      id: data[0].id,
      email: data[0].email,
      first_name: data[0].first_name,
      last_name: data[0].last_name,
      bio: data[0].bio,
      hourly_rate: data[0].hourly_rate,
      categories: data[0].categories,
      next_step: 'background_check',
    });
  })
);

// POST /api/providers/enable
// Adds a provider profile to an existing account
router.post(
  '/enable',
  verifyAuth,
  requireRole('customer'),
  asyncHandler(async (req, res) => {
    const providerId = req.user.id;

    const { error } = await supabase
      .from('provider_statuses')
      .upsert({ id: providerId }, { onConflict: 'id', ignoreDuplicates: true });

    if (error) {
      throw new ApiError(`Failed to add provider profile: ${error.message}`, 500);
    }

    logger.info('Provider profile added', { providerId });

    res.status(201).json({ id: providerId, next_step: 'profile_setup' });
  })
);

// GET /api/providers/me
router.get(
  '/me',
  verifyAuth,
  requireRole('provider'),
  asyncHandler(async (req, res) => {
    const providerId = req.user.id;

    const [profileResult, statusResult] = await Promise.all([
      supabase
        .from('profiles')
        .select('first_name, last_name, email, phone, hourly_rate, bio, categories')
        .eq('id', providerId)
        .single(),
      supabase
        .from('provider_statuses')
        .select('is_verified_for_work, availability_status, available_until')
        .eq('id', providerId)
        .single(),
    ]);

    if (profileResult.error || statusResult.error) {
      throw new ApiError('Provider not found', 404);
    }

    const status = statusResult.data;
    const availableNow =
      status.availability_status === 'online' &&
      status.available_until !== null &&
      new Date(status.available_until) > new Date();

    res.json({
      id: providerId,
      ...profileResult.data,
      is_verified_for_work: status.is_verified_for_work,
      available_now: availableNow,
      available_until: availableNow ? status.available_until : null,
    });
  })
);

// POST /api/providers/background-checks/initiate
// Start background check via Checkr
router.post(
  '/background-checks/initiate',
  verifyAuth,
  requireRole('provider'),
  validate(schemas.initiateBackgroundCheck),
  asyncHandler(async (req, res) => {
    const providerId = req.user.id;
    const {
      first_name,
      last_name,
      date_of_birth,
      ssn,
      driver_license_number,
      driver_license_state,
    } = req.body;

    // Check if already initiated
    const { data: existing } = await supabase
      .from('provider_statuses')
      .select('background_check_status, checkr_candidate_id')
      .eq('id', providerId)
      .single();

    if (existing?.checkr_candidate_id) {
      // Already initiated, return existing status
      return res.json({
        status: 'already_initiated',
        check_id: existing.checkr_candidate_id,
        background_check_status: existing.background_check_status,
      });
    }

    // Create Checkr candidate
    let checkrCandidate;
    try {
      checkrCandidate = await fetch('https://api.checkr.com/v1/candidates', {
        method: 'POST',
        headers: {
          Authorization: `Basic ${Buffer.from(`${config.checkr.apiKey}:`).toString('base64')}`,
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        body: new URLSearchParams({
          first_name,
          last_name,
          date_of_birth,
          ssn,
          driver_license_number,
          driver_license_state,
          custom_id: providerId,
        }),
      }).then((r) => r.json());

      if (checkrCandidate.error) {
        throw new Error(checkrCandidate.error_description || 'Checkr API error');
      }
    } catch (err) {
      logger.error('Checkr candidate creation failed', {
        error: err.message,
        providerId,
      });
      throw new ApiError(`Failed to initiate background check: ${err.message}`, 500);
    }

    const candidateId = checkrCandidate.id;

    // Create default report (Checkr will auto-run)
    let report;
    try {
      report = await fetch(`https://api.checkr.com/v1/candidates/${candidateId}/reports`, {
        method: 'POST',
        headers: {
          Authorization: `Basic ${Buffer.from(`${config.checkr.apiKey}:`).toString('base64')}`,
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        body: new URLSearchParams({
          package_slug: 'standard_v2',
        }),
      }).then((r) => r.json());

      if (report.error) {
        throw new Error(report.error_description || 'Checkr report creation failed');
      }
    } catch (err) {
      logger.error('Checkr report creation failed', {
        error: err.message,
        providerId,
      });
      throw new ApiError(`Failed to create background check report: ${err.message}`, 500);
    }

    // Update provider status
    const { error: updateError } = await supabase
      .from('provider_statuses')
      .update({
        checkr_candidate_id: candidateId,
        background_check_status: 'pending',
        background_check_started_at: new Date().toISOString(),
      })
      .eq('id', providerId);

    if (updateError) {
      throw new ApiError(`Failed to save check status: ${updateError.message}`, 500);
    }

    // Log audit event
    await supabase.from('background_check_audit_log').insert([
      {
        provider_id: providerId,
        event_type: 'check_started',
        event_details: {
          checkr_candidate_id: candidateId,
          report_id: report.id,
        },
      },
    ]);

    logger.info('Background check initiated', {
      providerId,
      candidateId,
      reportId: report.id,
    });

    res.status(201).json({
      check_id: candidateId,
      report_id: report.id,
      status: 'pending',
      initiated_at: new Date().toISOString(),
      expected_completion: new Date(Date.now() + 3 * 24 * 60 * 60 * 1000).toISOString(),
      next_step: 'stripe_connect',
    });
  })
);

// POST /api/providers/stripe-connect/url
// Get Stripe Connect onboarding URL
router.post(
  '/stripe-connect/url',
  verifyAuth,
  requireRole('provider'),
  asyncHandler(async (req, res) => {
    const providerId = req.user.id;

    // Get provider details
    const { data: provider, error: getError } = await supabase
      .from('profiles')
      .select('email, first_name, last_name, stripe_connect_account_id')
      .eq('id', providerId)
      .single();

    if (getError) {
      throw new ApiError('Provider not found', 404);
    }

    // Create or retrieve Stripe Connect account
    let accountId = provider.stripe_connect_account_id;

    if (!accountId) {
      // Create new connected account
      try {
        const account = await stripe.accounts.create({
          type: 'express',
          country: 'US',
          email: provider.email,
          capabilities: {
            card_payments: { requested: true },
            transfers: { requested: true },
          },
          business_profile: {
            name: `${provider.first_name} ${provider.last_name}`,
            mcc: '7361', // Employment agencies
            url: 'https://yuki.app',
          },
        });

        accountId = account.id;

        // Save account ID
        const { error: updateError } = await supabase
          .from('profiles')
          .update({ stripe_connect_account_id: accountId })
          .eq('id', providerId);

        if (updateError) {
          logger.warn('Failed to save Stripe account ID', {
            providerId,
            error: updateError.message,
          });
        }
      } catch (err) {
        logger.error('Failed to create Stripe Connect account', {
          error: err.message,
          providerId,
        });
        throw new ApiError(`Failed to create payment account: ${err.message}`, 500);
      }
    }

    // Generate onboarding link
    try {
      const link = await stripe.accountLinks.create({
        account: accountId,
        type: 'account_onboarding',
        return_url: 'https://yuki.app/provider/stripe-complete',
        refresh_url: 'https://yuki.app/provider/stripe-refresh',
      });

      logger.info('Stripe Connect onboarding URL generated', {
        providerId,
        accountId,
      });

      res.json({
        onboarding_url: link.url,
        account_id: accountId,
        expires_at: new Date(Date.now() + 24 * 60 * 60 * 1000).toISOString(),
      });
    } catch (err) {
      logger.error('Failed to create Stripe onboarding link', {
        error: err.message,
        providerId,
      });
      throw new ApiError(`Failed to generate onboarding link: ${err.message}`, 500);
    }
  })
);

// GET /api/providers/verification-status
// Check provider verification progress
router.get(
  '/verification-status',
  verifyAuth,
  requireRole('provider'),
  asyncHandler(async (req, res) => {
    const providerId = req.user.id;

    // Get provider status
    const { data: status, error: statusError } = await supabase
      .from('provider_statuses')
      .select('background_check_status, is_verified_for_work, checkr_candidate_id, stripe_connect_account_id, verification_status')
      .eq('id', providerId)
      .single();

    if (statusError) {
      throw new ApiError('Provider status not found', 404);
    }

    // Get profile for Stripe account ID
    const { data: profile } = await supabase
      .from('profiles')
      .select('stripe_connect_account_id')
      .eq('id', providerId)
      .single();

    // Check Stripe account status if connected
    let stripeStatus = 'not_started';
    if (profile?.stripe_connect_account_id) {
      try {
        const account = await stripe.accounts.retrieve(profile.stripe_connect_account_id);
        if (account.charges_enabled) {
          stripeStatus = 'complete';
        } else if (account.details_submitted) {
          stripeStatus = 'pending_review';
        } else {
          stripeStatus = 'incomplete';
        }
      } catch (err) {
        logger.warn('Failed to check Stripe account status', {
          error: err.message,
          providerId,
        });
      }
    }

    // Determine overall verification status
    const isFullyVerified =
      status.background_check_status === 'clear' &&
      status.is_verified_for_work &&
      stripeStatus === 'complete';

    // Determine next step
    let nextStep = null;
    if (status.background_check_status === 'not_started') {
      nextStep = 'background_check';
    } else if (status.background_check_status === 'pending') {
      nextStep = 'background_check_pending';
    } else if (status.background_check_status === 'clear' && stripeStatus === 'not_started') {
      nextStep = 'stripe_connect';
    } else if (stripeStatus !== 'complete') {
      nextStep = 'stripe_connect_pending';
    } else if (!isFullyVerified) {
      nextStep = 'profile_review';
    } else {
      nextStep = 'ready_to_work';
    }

    logger.info('Verification status checked', {
      providerId,
      backgroundCheckStatus: status.background_check_status,
      stripeStatus,
    });

    res.json({
      is_verified: isFullyVerified,
      background_check: {
        status: status.background_check_status,
        is_verified: status.is_verified_for_work,
      },
      stripe_connect: {
        status: stripeStatus,
        account_id: profile?.stripe_connect_account_id || null,
      },
      next_step: nextStep,
      can_go_online: isFullyVerified,
    });
  })
);

export default router;
