import express from 'express';
import { verifyAuth } from '../middleware/auth.js';
import { asyncHandler, ApiError } from '../middleware/errorHandler.js';
import { logger } from '../middleware/logger.js';

const router = express.Router();

// Photon needs no signup but has patchy US house numbers. Set MAPBOX_TOKEN in
// .env for proper address coverage; the app doesn't change either way.
const MAPBOX_TOKEN = process.env.MAPBOX_TOKEN;
const SUGGESTION_LIMIT = 5;

function mapboxUrl(query, latitude, longitude) {
  const params = new URLSearchParams({
    access_token: MAPBOX_TOKEN,
    autocomplete: 'true',
    country: 'us',
    types: 'address,poi',
    limit: String(SUGGESTION_LIMIT),
  });
  if (latitude !== null && longitude !== null) {
    params.set('proximity', `${longitude},${latitude}`);
  }
  return `https://api.mapbox.com/geocoding/v5/mapbox.places/${encodeURIComponent(query)}.json?${params}`;
}

function photonUrl(query, latitude, longitude) {
  const params = new URLSearchParams({ q: query, limit: String(SUGGESTION_LIMIT) });
  if (latitude !== null && longitude !== null) {
    params.set('lat', String(latitude));
    params.set('lon', String(longitude));
  }
  return `https://photon.komoot.io/api/?${params}`;
}

function fromMapbox(body) {
  return (body.features ?? []).map((feature) => ({
    label: feature.place_name,
    latitude: feature.center?.[1] ?? null,
    longitude: feature.center?.[0] ?? null,
  }));
}

function fromPhoton(body) {
  return (body.features ?? []).map((feature) => {
    const p = feature.properties ?? {};
    const street = [p.housenumber, p.street ?? p.name].filter(Boolean).join(' ');
    const label = [street || p.name, p.city ?? p.county, p.state, p.postcode]
      .filter(Boolean)
      .join(', ');
    return {
      label,
      latitude: feature.geometry?.coordinates?.[1] ?? null,
      longitude: feature.geometry?.coordinates?.[0] ?? null,
    };
  });
}

// GET /api/places/suggest?q=&latitude=&longitude=
// Address suggestions as someone types, biased toward where they are.
router.get(
  '/suggest',
  verifyAuth,
  asyncHandler(async (req, res) => {
    const query = (req.query.q ?? '').toString().trim();
    if (query.length < 3) {
      return res.json({ suggestions: [] });
    }

    const latitude = req.query.latitude ? parseFloat(req.query.latitude) : null;
    const longitude = req.query.longitude ? parseFloat(req.query.longitude) : null;
    const useMapbox = Boolean(MAPBOX_TOKEN);
    const url = useMapbox
      ? mapboxUrl(query, latitude, longitude)
      : photonUrl(query, latitude, longitude);

    let body;
    try {
      const response = await fetch(url, { signal: AbortSignal.timeout(6000) });
      if (!response.ok) {
        throw new Error(`geocoder returned ${response.status}`);
      }
      body = await response.json();
    } catch (err) {
      logger.warn('Address lookup failed', { error: err.message, source: useMapbox ? 'mapbox' : 'photon' });
      throw new ApiError('Address lookup is unavailable right now', 503, 'geocoder_unavailable');
    }

    const suggestions = (useMapbox ? fromMapbox(body) : fromPhoton(body))
      .filter((s) => s.label && s.latitude !== null && s.longitude !== null)
      .slice(0, SUGGESTION_LIMIT);

    res.json({ suggestions });
  })
);

export default router;
