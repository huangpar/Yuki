# Booking Flow API

Complete flow from service request → acceptance → completion → payment.

---

## Overview

```
CUSTOMER FLOW:
POST /api/customers/bookings (create request)
  ↓ Expires in 10 minutes if not accepted
  ↓ Broadcast to provider via real-time
  
GET /api/customers/bookings (view bookings)

PROVIDER FLOW:
GET /api/providers/bookings (see incoming requests)

POST /api/bookings/:booking_id/accept (accept)
  ↓ Notify customer
  
OR

POST /api/bookings/:booking_id/decline (decline)
  ↓ Return to available
  
COMPLETION:
POST /api/bookings/:booking_id/complete (mark done)
  ↓ Trigger payment hold (48 hours)
  ↓ Start dispute window
```

---

## Booking Statuses

```
pending_acceptance
  ↓ Expires in 10 minutes (auto-cancel)
  ↓ Provider must accept/decline
  
accepted
  ↓ Provider en route or at location
  ↓ Can be completed
  
completed
  ↓ Service finished
  ↓ Payment held for 48 hours (dispute window)
  ↓ After 48h, payment released to provider
  
declined
  ↓ Provider rejected request
  ↓ Customer can rebook with different provider

cancelled
  ↓ Customer cancelled before acceptance
```

---

## 1. Create Booking Request

**Endpoint:** `POST /api/customers/bookings`

Customer requests a service from a provider.

**Headers:**
```
Authorization: Bearer {access_token}
```

**Request:**
```json
{
  "provider_id": "provider-uuid",
  "service_category": "cleaning",
  "description": "House cleaning for 3 hours - kitchen, living room, bathroom",
  "address": "123 Main St, Sumner, WA 98390",
  "latitude": 47.1234,
  "longitude": -122.4567,
  "scheduled_for": "2026-09-09T14:00:00Z",
  "estimated_duration_minutes": 180,
  "requested_price": 135.00
}
```

**Response:** `201 Created`
```json
{
  "booking_id": "booking-uuid",
  "customer_id": "customer-uuid",
  "provider_id": "provider-uuid",
  "status": "pending_acceptance",
  "service_category": "cleaning",
  "description": "House cleaning for 3 hours...",
  "address": "123 Main St, Sumner, WA 98390",
  "latitude": 47.1234,
  "longitude": -122.4567,
  "scheduled_for": "2026-09-09T14:00:00Z",
  "estimated_duration_minutes": 180,
  "price": 135.00,
  "created_at": "2026-09-09T10:00:00Z",
  "expires_at": "2026-09-09T10:10:00Z",
  "next_step": "waiting_for_provider"
}
```

**Validation:**
- provider_id: valid UUID
- service_category: lowercase, 1-50 chars
- description: 10-1000 chars, trimmed
- address: 5-255 chars
- latitude/longitude: valid coordinates
- scheduled_for: future date/time (ISO 8601)
- estimated_duration_minutes: 15-480 minutes
- requested_price: positive, 2 decimals max

**Errors:**
- `400 Bad Request` — Validation failed
- `401 Unauthorized` — Missing token
- `403 Forbidden` — Not a customer
- `404 Not Found` — Provider not found
- `403 Forbidden` (provider_not_verified) — Provider must be verified

**What happens:**
1. Creates booking_requests record with status: 'pending_acceptance'
2. Sets expiration to 10 minutes from now
3. **Real-time broadcast** — Provider is notified (can see new booking)
4. Customer can cancel anytime before acceptance
5. If provider doesn't accept in 10 min, booking auto-expires

---

## 2. List Customer Bookings

**Endpoint:** `GET /api/customers/bookings`

Get customer's booking history and active bookings.

**Headers:**
```
Authorization: Bearer {access_token}
```

**Query Parameters:**
```
GET /api/customers/bookings?status=accepted&limit=20&offset=0
```

| Parameter | Type | Description |
|-----------|------|-------------|
| `status` | string | Filter: pending_acceptance, accepted, completed, declined |
| `limit` | integer | Max results (default: 20, max: 100) |
| `offset` | integer | Pagination offset (default: 0) |

**Response:** `200 OK`
```json
{
  "bookings": [
    {
      "booking_id": "booking-uuid",
      "customer_id": "customer-uuid",
      "provider": {
        "id": "provider-uuid",
        "first_name": "Jane",
        "last_name": "Doe",
        "hourly_rate": 45.00
      },
      "status": "accepted",
      "service_category": "cleaning",
      "description": "House cleaning...",
      "address": "123 Main St, Sumner, WA 98390",
      "scheduled_for": "2026-09-09T14:00:00Z",
      "estimated_duration_minutes": 180,
      "price": 135.00,
      "created_at": "2026-09-09T10:00:00Z",
      "accepted_at": "2026-09-09T10:05:00Z",
      "completed_at": null,
      "cancelled_at": null
    }
  ],
  "total": 5,
  "limit": 20,
  "offset": 0
}
```

**Errors:**
- `401 Unauthorized` — Missing token
- `403 Forbidden` — Not a customer

---

## 3. List Provider Bookings

**Endpoint:** `GET /api/providers/bookings`

Get provider's bookings (incoming requests + active jobs).

**Headers:**
```
Authorization: Bearer {access_token}
```

**Query Parameters:**
```
GET /api/providers/bookings?status=pending_acceptance&limit=20
```

**Response:** `200 OK`
```json
{
  "bookings": [
    {
      "booking_id": "booking-uuid",
      "customer": {
        "id": "customer-uuid",
        "first_name": "John",
        "last_name": "Smith",
        "email": "john@example.com",
        "phone": "+1-206-555-1234"
      },
      "status": "pending_acceptance",
      "service_category": "cleaning",
      "description": "House cleaning for 3 hours...",
      "address": "123 Main St, Sumner, WA 98390",
      "latitude": 47.1234,
      "longitude": -122.4567,
      "scheduled_for": "2026-09-09T14:00:00Z",
      "estimated_duration_minutes": 180,
      "price": 135.00,
      "created_at": "2026-09-09T10:00:00Z",
      "accepted_at": null,
      "completed_at": null,
      "cancelled_at": null
    }
  ],
  "total": 2,
  "limit": 20,
  "offset": 0
}
```

**Includes:**
- Incoming requests (pending_acceptance) - expire in 10 min
- Accepted bookings (en route/at location)
- Completed bookings (for review/ratings)
- Declined bookings (declined requests)

---

## 4. Get Booking Details

**Endpoint:** `GET /api/bookings/:booking_id`

Get full booking details (customer or provider can view).

**Headers:**
```
Authorization: Bearer {access_token}
```

**Request:**
```
GET /api/bookings/booking-uuid
```

**Response:** `200 OK`
```json
{
  "booking_id": "booking-uuid",
  "customer_id": "customer-uuid",
  "provider_id": "provider-uuid",
  "status": "accepted",
  "service_category": "cleaning",
  "description": "House cleaning for 3 hours...",
  "address": "123 Main St, Sumner, WA 98390",
  "latitude": 47.1234,
  "longitude": -122.4567,
  "scheduled_for": "2026-09-09T14:00:00Z",
  "estimated_duration_minutes": 180,
  "price": 135.00,
  "created_at": "2026-09-09T10:00:00Z",
  "accepted_at": "2026-09-09T10:05:00Z",
  "completed_at": null,
  "cancelled_at": null
}
```

**Errors:**
- `401 Unauthorized` — Missing token
- `403 Forbidden` — Not customer or provider for this booking
- `404 Not Found` — Booking not found

---

## 5. Provider Accepts Booking

**Endpoint:** `POST /api/bookings/:booking_id/accept`

Provider accepts a booking request.

**Headers:**
```
Authorization: Bearer {access_token}
```

**Request:**
```json
{
  "estimated_arrival_at": "2026-09-09T11:30:00Z"
}
```

**Response:** `200 OK`
```json
{
  "booking_id": "booking-uuid",
  "status": "accepted",
  "accepted_at": "2026-09-09T10:05:00Z",
  "estimated_arrival_at": "2026-09-09T11:30:00Z",
  "next_step": "en_route"
}
```

**Validation:**
- estimated_arrival_at: required, `YYYY-MM-DDTHH:MM:SSZ`, not in the past (5 minutes of slack for clock drift)

A provider can accept a request while other accepted jobs are still ahead of them. The arrival time is how the customer knows when to expect them; it's returned as `estimated_arrival_at` on every booking read.

**Errors:**
- `401 Unauthorized` — Missing token
- `403 Forbidden` — Not provider for this booking
- `404 Not Found` — Booking not found
- `409 Conflict` (invalid_status) — Booking no longer pending (already accepted/declined/expired)

**What happens:**
1. Updates booking_requests:
   - status: 'accepted'
   - accepted_at: now
   - estimated_arrival_at: from the request
2. **Real-time broadcast** — Customer is notified (provider accepted)
3. Customer can now see provider's ETA
4. Booking cannot be declined after acceptance

---

## 6. Provider Declines Booking

**Endpoint:** `POST /api/bookings/:booking_id/decline`

Provider declines a booking request.

**Headers:**
```
Authorization: Bearer {access_token}
```

**Request:**
```json
{}
```

**Response:** `200 OK`
```json
{
  "booking_id": "booking-uuid",
  "status": "declined",
  "cancelled_at": "2026-09-09T10:03:00Z",
  "next_step": "available_for_other_bookings"
}
```

**Errors:**
- `401 Unauthorized` — Missing token
- `403 Forbidden` — Not provider for this booking
- `404 Not Found` — Booking not found
- `409 Conflict` (invalid_status) — Booking no longer pending

**What happens:**
1. Updates booking_requests:
   - status: 'declined'
   - cancelled_at: now
2. **Real-time broadcast** — Customer is notified (provider declined)
3. Customer must request from different provider
4. Provider returns to available for other bookings

---

## 7. Mark Booking Complete

**Endpoint:** `POST /api/bookings/:booking_id/complete`

Provider marks service as completed (after work finished).

**Headers:**
```
Authorization: Bearer {access_token}
```

**Request:**
```json
{
  "actual_duration_minutes": 165,
  "notes": "Cleaned kitchen and living room thoroughly"
}
```

**Response:** `200 OK`
```json
{
  "booking_id": "booking-uuid",
  "status": "completed",
  "completed_at": "2026-09-09T15:45:00Z",
  "actual_duration_minutes": 165,
  "notes": "Cleaned kitchen and living room thoroughly",
  "payment_status": "pending",
  "payment_released_at": "2026-09-11T15:45:00Z",
  "next_step": "waiting_for_payment_release"
}
```

**Validation:**
- actual_duration_minutes: 1-480 minutes
- notes: 0-500 chars (optional)

**Errors:**
- `401 Unauthorized` — Missing token
- `403 Forbidden` — Not provider for this booking
- `404 Not Found` — Booking not found
- `409 Conflict` (invalid_status) — Booking must be accepted first

**What happens:**
1. Updates booking_requests:
   - status: 'completed'
   - completed_at: now
2. **Real-time broadcast** — Customer is notified (service complete)
3. Triggers payment processing:
   - Payment held for 48 hours (dispute window)
   - After 48h, payment released to provider via transfer
4. Customer can file dispute within 48 hours
5. After 48h, provider can withdraw payment

---

## Payment Timeline

```
Booking Created
  ↓
Service Completed
  ↓
payment_status: pending
payment_released_at: 48 hours from now
  ↓
Dispute Window Open (48 hours)
  ↓ Customer can file dispute
Customer Files Dispute (optional)
  ↓
48 Hours Pass
  ↓
payment_status: released
  ↓
Transfer initiated to provider
  ↓ (1-2 business days)
Provider receives payment
```

---

## Real-Time Notifications

### For Providers (new bookings)

```javascript
// Subscribe to incoming booking requests
const subscription = supabase
  .channel(`provider_${provider_id}:bookings`)
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
      // Provider can tap to view details and accept/decline
    }
  )
  .subscribe();
```

### For Customers (booking status updates)

```javascript
// Subscribe to booking status changes
const subscription = supabase
  .channel(`booking_${booking_id}:status`)
  .on(
    'postgres_changes',
    {
      event: 'UPDATE',
      schema: 'public',
      table: 'booking_requests',
      filter: `id=eq.${booking_id}`
    },
    (payload) => {
      const newStatus = payload.new.status;
      if (newStatus === 'accepted') {
        console.log('Provider accepted! ETA:', payload.new.accepted_at);
      } else if (newStatus === 'declined') {
        console.log('Provider declined, find another provider');
      } else if (newStatus === 'completed') {
        console.log('Service complete! Rate the provider');
      }
    }
  )
  .subscribe();
```

---

## Testing with cURL

### Create Booking
```bash
curl -X POST http://localhost:3000/api/customers/bookings \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "provider_id": "provider-uuid",
    "service_category": "cleaning",
    "description": "House cleaning",
    "address": "123 Main St",
    "latitude": 47.1234,
    "longitude": -122.4567,
    "scheduled_for": "2026-09-09T14:00:00Z",
    "estimated_duration_minutes": 180,
    "requested_price": 135.00
  }'
```

### List Customer Bookings
```bash
curl "http://localhost:3000/api/customers/bookings?status=accepted" \
  -H "Authorization: Bearer YOUR_TOKEN"
```

### List Provider Bookings
```bash
curl "http://localhost:3000/api/providers/bookings?status=pending_acceptance" \
  -H "Authorization: Bearer YOUR_TOKEN"
```

### Get Booking Details
```bash
curl "http://localhost:3000/api/bookings/booking-uuid" \
  -H "Authorization: Bearer YOUR_TOKEN"
```

### Accept Booking
```bash
curl -X POST "http://localhost:3000/api/bookings/booking-uuid/accept" \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{ "estimated_arrival_at": "2026-09-09T11:30:00Z" }'
```

### Decline Booking
```bash
curl -X POST "http://localhost:3000/api/bookings/booking-uuid/decline" \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{}'
```

### Complete Booking
```bash
curl -X POST "http://localhost:3000/api/bookings/booking-uuid/complete" \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "actual_duration_minutes": 165,
    "notes": "Job completed successfully"
  }'
```

---

## Audit Trail

All booking events are logged:
- `booking_requested` — Customer creates request
- `booking_accepted` — Provider accepts
- `booking_declined` — Provider declines
- `booking_completed` — Service marked done

Audit logs used for:
- Compliance tracking
- Dispute resolution
- Fraud detection
- Performance analytics

---

## Error Handling

Common errors and responses:

| Status | Error | Meaning | Action |
|--------|-------|---------|--------|
| 400 | validation_error | Invalid input | Fix data and retry |
| 401 | unauthorized | Missing token | Refresh auth token |
| 403 | forbidden | Not authorized for booking | Check booking ownership |
| 403 | provider_not_verified | Provider not verified | Wait for background check |
| 404 | not_found | Booking doesn't exist | Use correct booking ID |
| 409 | invalid_status | Wrong booking status | Check current status first |
| 500 | internal_server_error | Server issue | Retry with backoff |

