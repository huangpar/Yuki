# Location Tracking & Availability API

Real-time provider availability and customer discovery.

---

## Overview

```
Provider Flow:
POST /api/providers/availability/toggle (go online)
  ↓ Location transmitted, 30-min timer starts
POST /api/providers/availability/update-location (every 60 sec)
  ↓ Location updated, broadcast to customers
POST /api/providers/availability/toggle (go offline)
  ↓ Location cleared, hidden from map

Customer Flow:
GET /api/customers/nearby-providers
  ↓ PostGIS geospatial query (5-mile radius)
  ↓ Real-time subscription: see providers appear/disappear
```

---

## 1. Toggle Availability (Go Online)

**Endpoint:** `POST /api/providers/availability/toggle`

Activate "Available Now" status and broadcast location.

**Headers:**
```
Authorization: Bearer {access_token}
```

**Request:**
```json
{
  "available": true,
  "latitude": 47.1234,
  "longitude": -122.4567
}
```

**Response:** `200 OK`
```json
{
  "provider_id": "provider-uuid",
  "available_now": true,
  "latitude": 47.1234,
  "longitude": -122.4567,
  "last_updated": "2026-09-09T10:00:00Z",
  "expires_at": "2026-09-09T10:30:00Z",
  "status": "online"
}
```

**Validation:**
- available: boolean (required)
- latitude: -90 to 90 (required if available=true)
- longitude: -180 to 180 (required if available=true)

**Errors:**
- `400 Bad Request` — Missing location or invalid coordinates
- `401 Unauthorized` — Missing token
- `403 Forbidden` — Not a provider
- `403 Forbidden` (not_verified) — Provider must pass background check first

**What happens:**
1. Verifies provider is verified for work (background check passed)
2. Updates provider_statuses:
   - availability_status: 'online'
   - latitude, longitude: set to provided values
   - last_location_update: now
3. Sets expiration: 30 minutes from now
4. **Auto-broadcast via real-time subscription** — All subscribed customers see provider appear on map
5. Returns expires_at (provider must refresh before this time)

**Important:** Availability expires after 30 minutes if not refreshed. Provider will disappear from all customer maps.

---

## 2. Update Location (While Online)

**Endpoint:** `POST /api/providers/availability/update-location`

Update real-time location every 60 seconds.

**Headers:**
```
Authorization: Bearer {access_token}
Content-Type: application/json
```

**Request:**
```json
{
  "latitude": 47.1250,
  "longitude": -122.4590
}
```

**Response:** `200 OK`
```json
{
  "provider_id": "provider-uuid",
  "latitude": 47.1250,
  "longitude": -122.4590,
  "updated_at": "2026-09-09T10:01:00Z"
}
```

**Validation:**
- latitude: -90 to 90 (required)
- longitude: -180 to 180 (required)

**Rate Limiting:**
- Max 1 update per 30 seconds
- Returns `429 Too Many Requests` if called too frequently
- Response includes `waitSeconds` to retry

**Errors:**
- `400 Bad Request` — Invalid coordinates
- `401 Unauthorized` — Missing token
- `403 Forbidden` — Not a provider
- `404 Not Found` — Provider not found
- `409 Conflict` (not_online) — Provider must be online first
- `429 Too Many Requests` — Rate limit exceeded

**What happens:**
1. Rate limit check (max 1 per 30 sec)
2. Verifies provider is online (availability_status = 'online')
3. Updates provider_statuses:
   - latitude, longitude: new position
   - last_location_update: now
4. **Auto-broadcast via real-time** — All customers subscribed to provider see location update
5. Keeps the 30-minute expiration timer (not reset)

**Best Practice:** Provider app should call this every 60 seconds while "Available Now"

---

## 3. Toggle Availability (Go Offline)

**Endpoint:** `POST /api/providers/availability/toggle`

Deactivate availability and hide from map.

**Headers:**
```
Authorization: Bearer {access_token}
```

**Request:**
```json
{
  "available": false
}
```

**Response:** `200 OK`
```json
{
  "provider_id": "provider-uuid",
  "available_now": false,
  "latitude": null,
  "longitude": null,
  "last_updated": "2026-09-09T10:30:00Z",
  "expires_at": null,
  "status": "offline"
}
```

**What happens:**
1. Updates provider_statuses:
   - availability_status: 'offline'
   - latitude, longitude: null (location cleared)
   - last_location_update: null
2. **Auto-broadcast via real-time** — Provider disappears from all customer maps instantly
3. Returns expires_at: null

---

## 4. Find Nearby Providers

**Endpoint:** `GET /api/customers/nearby-providers`

Find available providers within radius using geospatial query.

**Headers:**
```
Authorization: Bearer {access_token}
```

**Query Parameters:**
```
GET /api/customers/nearby-providers?latitude=47.1234&longitude=-122.4567&radius=5&category=cleaning
```

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `latitude` | number | Yes | Customer's latitude (-90 to 90) |
| `longitude` | number | Yes | Customer's longitude (-180 to 180) |
| `radius` | integer | No | Search radius in miles (default: 5, max: 50) |
| `category` | string | No | Filter by service category (e.g., "cleaning") |

**Response:** `200 OK`
```json
{
  "providers": [
    {
      "id": "provider-uuid",
      "first_name": "Jane",
      "last_name": "Doe",
      "email": "jane@example.com",
      "phone": "+1-206-555-1234",
      "hourly_rate": 45.00,
      "bio": "Professional house cleaner with 5+ years experience",
      "categories": ["cleaning", "organizing"],
      "latitude": 47.1250,
      "longitude": -122.4590,
      "distance_miles": 2.3,
      "available_now": true
    }
  ],
  "count": 5,
  "search_center": {
    "latitude": 47.1234,
    "longitude": -122.4567,
    "radius_miles": 5
  }
}
```

**Validation:**
- latitude: -90 to 90 (required)
- longitude: -180 to 180 (required)
- radius: 1-50 miles (optional)
- category: lowercase string (optional)

**Errors:**
- `400 Bad Request` — Invalid coordinates or radius
- `401 Unauthorized` — Missing token
- `403 Forbidden` — Not a customer

**What happens:**
1. Filters provider_statuses for verified + online providers
2. **Client-side distance calculation** (Haversine formula):
   - Calculates distance from customer to each provider
   - Keeps only providers within radius
3. Sorts by distance (closest first)
4. Filters by category if specified
5. Returns provider list with distance

**Performance Notes:**
- Query returns all online verified providers, then filters client-side
- For production with 1000+ providers, consider server-side PostGIS filtering
- Currently uses Haversine algorithm (accurate to ~0.5% for distances <100 miles)

---

## Real-Time Subscriptions

### For Customers (see providers appear/disappear)

```javascript
// Example: Flutter/JavaScript
const subscription = supabase
  .channel('provider_statuses')
  .on(
    'postgres_changes',
    {
      event: '*',
      schema: 'public',
      table: 'provider_statuses',
      filter: 'is_verified_for_work=eq.true'
    },
    (payload) => {
      console.log('Provider updated:', payload);
      // Re-query nearby providers or update map in real-time
      // If provider went offline, remove from map
      // If provider moved, update position
    }
  )
  .subscribe();
```

### For Providers (see when bookings arrive)

```javascript
const subscription = supabase
  .channel(`provider_${provider_id}`)
  .on(
    'postgres_changes',
    {
      event: 'INSERT',
      schema: 'public',
      table: 'booking_requests',
      filter: `provider_id=eq.${provider_id}`
    },
    (payload) => {
      console.log('New booking request!', payload.new);
      // Show notification to provider
    }
  )
  .subscribe();
```

---

## Timeline & Expiration

```
10:00 AM
  ↓
Provider calls POST /toggle with available=true
  ↓
Expiration set to 10:30 AM (30 min)
Broadcast to all customers
Providers appears on all maps within 5 miles
  ↓
10:01 AM
  ↓
Provider app calls POST /update-location
  ↓
Location updated on map
(Expiration still 10:30 AM - not reset)
  ↓
... (repeat every 60 sec)
  ↓
10:29 AM
  ↓
Provider app calls POST /update-location again
  ↓
Keeps expiration at 10:30 AM
  ↓
10:30 AM
  ↓
**EXPIRATION** - Provider auto-disappears from all maps
(Requires calling POST /toggle again to come back online)
```

---

## Provider App Implementation (Pseudo-code)

```javascript
// When user taps "Go Available Now"
async function goAvailable() {
  const location = await getDeviceLocation();
  
  const response = await fetch('/api/providers/availability/toggle', {
    method: 'POST',
    headers: { 'Authorization': `Bearer ${token}` },
    body: JSON.stringify({
      available: true,
      latitude: location.lat,
      longitude: location.lon
    })
  });
  
  const data = await response.json();
  expirationTime = new Date(data.expires_at);
  
  // Start location update timer
  startLocationUpdateTimer();
}

// Every 60 seconds (while available)
async function updateLocation() {
  const location = await getDeviceLocation();
  
  try {
    await fetch('/api/providers/availability/update-location', {
      method: 'POST',
      headers: { 'Authorization': `Bearer ${token}` },
      body: JSON.stringify({
        latitude: location.lat,
        longitude: location.lon
      })
    });
  } catch (err) {
    if (err.status === 429) {
      // Rate limited, retry after delay
      console.log('Rate limited, wait before retry');
    }
  }
}

// Refresh before expiration (5 min before timeout)
async function refreshAvailability() {
  const location = await getDeviceLocation();
  
  // Re-toggle to reset timer
  await fetch('/api/providers/availability/toggle', {
    method: 'POST',
    headers: { 'Authorization': `Bearer ${token}` },
    body: JSON.stringify({
      available: true,
      latitude: location.lat,
      longitude: location.lon
    })
  });
}

// When user taps "Go Offline"
async function goOffline() {
  await fetch('/api/providers/availability/toggle', {
    method: 'POST',
    headers: { 'Authorization': `Bearer ${token}` },
    body: JSON.stringify({ available: false })
  });
  
  stopLocationUpdateTimer();
}
```

---

## Customer App Implementation (Pseudo-code)

```javascript
// On map screen load
async function loadNearbyProviders() {
  const location = await getDeviceLocation();
  
  const response = await fetch(
    `/api/customers/nearby-providers?latitude=${location.lat}&longitude=${location.lon}&radius=5`,
    { headers: { 'Authorization': `Bearer ${token}` } }
  );
  
  const data = await response.json();
  
  // Plot providers on map
  data.providers.forEach(provider => {
    addMarkerToMap(provider);
  });
  
  // Subscribe to real-time updates
  subscribeToProviderUpdates();
}

// Real-time subscription
function subscribeToProviderUpdates() {
  supabase
    .channel('provider_locations')
    .on('postgres_changes', 
      { event: '*', table: 'provider_statuses' },
      (payload) => {
        if (payload.new.availability_status === 'online') {
          // Provider came online or moved
          updateMarkerOnMap(payload.new);
        } else if (payload.new.availability_status === 'offline') {
          // Provider went offline
          removeMarkerFromMap(payload.new.id);
        }
      }
    )
    .subscribe();
}
```

---

## Testing with cURL

### Provider: Go Online
```bash
curl -X POST http://localhost:3000/api/providers/availability/toggle \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "available": true,
    "latitude": 47.1234,
    "longitude": -122.4567
  }'
```

### Provider: Update Location
```bash
curl -X POST http://localhost:3000/api/providers/availability/update-location \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "latitude": 47.1250,
    "longitude": -122.4590
  }'
```

### Provider: Go Offline
```bash
curl -X POST http://localhost:3000/api/providers/availability/toggle \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{ "available": false }'
```

### Customer: Find Nearby Providers
```bash
curl "http://localhost:3000/api/customers/nearby-providers?latitude=47.1234&longitude=-122.4567&radius=5" \
  -H "Authorization: Bearer YOUR_TOKEN"
```

---

## Security & Privacy

✅ **Location Privacy:**
- Only active provider location sent (never stored)
- Deleted when provider goes offline
- Only visible to searching customers within range
- Never shared in user profiles

✅ **Authentication:**
- All endpoints require valid JWT token
- Role-based access (provider/customer only)

✅ **Rate Limiting:**
- Location updates: max 1 per 30 seconds per provider
- Returns `429` with wait time if exceeded

✅ **Data Validation:**
- All coordinates validated for valid ranges
- Invalid locations rejected with 400 error

---

## Performance Considerations

**Current Implementation:**
- Uses client-side Haversine distance calculation
- Filters all online providers, then limits by radius
- Suitable for up to 1000 concurrent providers

**For Scaling (1000+ concurrent providers):**
- Implement server-side PostGIS geospatial indexing
- Use spatial index for O(log n) lookups
- Return only providers within radius from server

**Current Query Cost:**
- 1 database query (all online providers)
- Client-side calculation (linear time)
- Response time: ~100-200ms for typical provider counts

---

## Error Handling

Common errors and how to handle:

| Status | Error | Meaning | Retry? |
|--------|-------|---------|--------|
| 400 | validation_error | Bad coordinates | No, fix request |
| 401 | unauthorized | Missing/invalid token | Refresh token |
| 403 | not_verified | Background check required | No, wait for approval |
| 409 | not_online | Must be online | Retry after going online |
| 429 | rate_limit | Too frequent updates | Yes, after waitSeconds |
| 500 | internal_server_error | Server issue | Yes, exponential backoff |

