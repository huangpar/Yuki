import express from 'express';
import { supabase } from '../db.js';
import { verifyAuth, requireRole } from '../middleware/auth.js';
import { validate, validateQuery, validateBody } from '../middleware/validation.js';
import { schemas } from '../validators/schemas.js';
import { asyncHandler, ApiError } from '../middleware/errorHandler.js';
import { logger } from '../middleware/logger.js';

const router = express.Router();

// Rate limiting: store last update time per provider
const lastLocationUpdate = new Map();
const LOCATION_UPDATE_COOLDOWN_MS = 30 * 1000; // 30 seconds

// POST /api/providers/availability/toggle
// Go "Available Now" or offline
router.post(
  '/providers/availability/toggle',
  verifyAuth,
  requireRole('provider'),
  validate(schemas.toggleAvailability),
  asyncHandler(async (req, res) => {
    const providerId = req.user.id;
    const { available, latitude, longitude } = req.body;

    // If going online, require location
    if (available && (latitude === undefined || longitude === undefined)) {
      throw new ApiError('Location required when going online', 400, 'missing_location');
    }

    // Check provider is verified
    const { data: provider, error: getError } = await supabase
      .from('provider_statuses')
      .select('is_verified_for_work')
      .eq('id', providerId)
      .single();

    if (getError) {
      throw new ApiError('Provider not found', 404);
    }

    if (!provider.is_verified_for_work) {
      throw new ApiError(
        'Provider must pass background check before going online',
        403,
        'not_verified'
      );
    }

    // Update availability
    const newStatus = available ? 'online' : 'offline';
    const expiresAt = available
      ? new Date(Date.now() + 30 * 60 * 1000).toISOString() // 30 minutes
      : null;

    const updateData = {
      availability_status: newStatus,
      available_until: expiresAt,
      last_heartbeat: new Date().toISOString(),
    };

    if (available) {
      updateData.latitude = latitude;
      updateData.longitude = longitude;
    } else {
      // Clear location when going offline
      updateData.latitude = null;
      updateData.longitude = null;
    }

    const { data, error } = await supabase
      .from('provider_statuses')
      .update(updateData)
      .eq('id', providerId)
      .select();

    if (error) {
      throw new ApiError(`Failed to update availability: ${error.message}`, 500);
    }

    logger.info('Provider availability toggled', {
      providerId,
      available,
      latitude,
      longitude,
      expiresAt,
    });

    // Broadcast to all customers via real-time
    // (Supabase auto-broadcasts changes to subscribed clients)

    res.json({
      provider_id: providerId,
      available_now: available,
      latitude: available ? latitude : null,
      longitude: available ? longitude : null,
      last_updated: new Date().toISOString(),
      expires_at: expiresAt,
      status: newStatus,
    });
  })
);

// POST /api/providers/availability/update-location
// Update real-time location (while available)
// Rate limited: max 1 update per 30 seconds
router.post(
  '/providers/availability/update-location',
  verifyAuth,
  requireRole('provider'),
  validate(schemas.updateLocation),
  asyncHandler(async (req, res) => {
    const providerId = req.user.id;
    const { latitude, longitude } = req.body;

    // Rate limiting
    const lastUpdate = lastLocationUpdate.get(providerId);
    const now = Date.now();

    if (lastUpdate && now - lastUpdate < LOCATION_UPDATE_COOLDOWN_MS) {
      const waitSeconds = Math.ceil((LOCATION_UPDATE_COOLDOWN_MS - (now - lastUpdate)) / 1000);
      throw new ApiError(`Rate limited. Try again in ${waitSeconds}s`, 429, 'rate_limit');
    }

    // Check if provider is online
    const { data: status, error: getError } = await supabase
      .from('provider_statuses')
      .select('availability_status, available_until')
      .eq('id', providerId)
      .single();

    if (getError) {
      throw new ApiError('Provider not found', 404);
    }

    if (status.availability_status !== 'online') {
      throw new ApiError('Provider must be online to update location', 409, 'not_online');
    }

    if (!status.available_until || new Date(status.available_until) <= new Date()) {
      throw new ApiError(
        'Availability expired. Go available again to resume.',
        409,
        'availability_expired'
      );
    }

    // Update location
    const { data, error } = await supabase
      .from('provider_statuses')
      .update({
        latitude,
        longitude,
        last_heartbeat: new Date().toISOString(),
      })
      .eq('id', providerId)
      .select();

    if (error) {
      throw new ApiError(`Failed to update location: ${error.message}`, 500);
    }

    // Update rate limit tracker
    lastLocationUpdate.set(providerId, now);

    logger.debug('Provider location updated', {
      providerId,
      latitude,
      longitude,
    });

    // Broadcast to customers via real-time
    // (Supabase auto-broadcasts changes)

    res.json({
      provider_id: providerId,
      latitude,
      longitude,
      updated_at: new Date().toISOString(),
    });
  })
);

// GET /api/customers/nearby-providers
// Find nearby available providers using PostGIS
// Public endpoint: accessible without authentication (for homepage)
router.get(
  '/customers/nearby-providers',
  asyncHandler(async (req, res) => {
    // Convert query params from strings to proper types
    const latitude = parseFloat(req.query.latitude);
    const longitude = parseFloat(req.query.longitude);
    const radius = parseInt(req.query.radius || 5, 10);
    const { category } = req.query;

    // Basic validation
    if (isNaN(latitude) || latitude < -90 || latitude > 90) {
      throw new ApiError('Invalid latitude', 400, 'invalid_latitude');
    }
    if (isNaN(longitude) || longitude < -180 || longitude > 180) {
      throw new ApiError('Invalid longitude', 400, 'invalid_longitude');
    }
    if (isNaN(radius) || radius < 1 || radius > 50) {
      throw new ApiError('Invalid radius', 400, 'invalid_radius');
    }

    // Convert radius to meters
    const radiusMeters = radius * 1609.34; // miles to meters

    // Build the query
    let query = supabase.from('provider_statuses').select(
      `
      id,
      latitude,
      longitude,
      availability_status,
      profiles:id (
        first_name,
        last_name,
        email,
        phone,
        hourly_rate,
        bio,
        categories
      )
    `
    );

    // Filter by verified, online, and not yet expired
    query = query
      .eq('is_verified_for_work', true)
      .eq('availability_status', 'online')
      .gt('available_until', new Date().toISOString());

    // Execute query to get all online providers
    const { data: allProviders, error: dbError } = await query;

    if (dbError) {
      throw new ApiError(`Database query failed: ${dbError.message}`, 500);
    }

    // Client-side filtering: distance calculation
    const nearbyProviders = allProviders
      .filter((provider) => {
        if (!provider.latitude || !provider.longitude) return false;

        // Haversine distance calculation
        const lat1 = parseFloat(latitude);
        const lon1 = parseFloat(longitude);
        const lat2 = provider.latitude;
        const lon2 = provider.longitude;

        const R = 6371; // Earth's radius in km
        const dLat = ((lat2 - lat1) * Math.PI) / 180;
        const dLon = ((lon2 - lon1) * Math.PI) / 180;
        const a =
          Math.sin(dLat / 2) * Math.sin(dLat / 2) +
          Math.cos((lat1 * Math.PI) / 180) *
            Math.cos((lat2 * Math.PI) / 180) *
            Math.sin(dLon / 2) *
            Math.sin(dLon / 2);
        const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
        const distance = R * c; // in km

        return distance <= radius;
      })
      .map((provider) => {
        // Calculate distance for display
        const lat1 = parseFloat(latitude);
        const lon1 = parseFloat(longitude);
        const lat2 = provider.latitude;
        const lon2 = provider.longitude;

        const R = 6371;
        const dLat = ((lat2 - lat1) * Math.PI) / 180;
        const dLon = ((lon2 - lon1) * Math.PI) / 180;
        const a =
          Math.sin(dLat / 2) * Math.sin(dLat / 2) +
          Math.cos((lat1 * Math.PI) / 180) *
            Math.cos((lat2 * Math.PI) / 180) *
            Math.sin(dLon / 2) *
            Math.sin(dLon / 2);
        const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
        const distanceKm = R * c;
        const distanceMiles = distanceKm * 0.621371;

        const profile = provider.profiles;

        // Filter by category if specified
        if (category && (!profile.categories || !profile.categories.includes(category))) {
          return null;
        }

        return {
          id: provider.id,
          first_name: profile.first_name,
          last_name: profile.last_name,
          email: profile.email,
          phone: profile.phone,
          hourly_rate: profile.hourly_rate,
          bio: profile.bio,
          categories: profile.categories,
          latitude: provider.latitude,
          longitude: provider.longitude,
          distance_miles: Math.round(distanceMiles * 10) / 10, // 1 decimal
          available_now: true,
        };
      })
      .filter((p) => p !== null)
      .sort((a, b) => a.distance_miles - b.distance_miles);

    logger.info('Nearby providers searched', {
      latitude,
      longitude,
      radius,
      resultsCount: nearbyProviders.length,
    });

    res.json({
      providers: nearbyProviders,
      count: nearbyProviders.length,
      search_center: {
        latitude: parseFloat(latitude),
        longitude: parseFloat(longitude),
        radius_miles: radius,
      },
    });
  })
);

export default router;
