# Yuki API Specification

**Version:** 1.0  
**Last Updated:** September 8, 2026  
**Base URL:** `https://api.yuki.app/v1` (production) | `http://localhost:3000/v1` (development)

---

## Overview

Yuki's backend provides REST API endpoints for:
- Authentication & user management
- Customer service requests & bookings
- Provider availability & status
- Payment processing
- Dispute resolution
- Webhook handlers (Stripe, Checkr)

**Architecture:**
- **Supabase:** Database, auth, real-time subscriptions
- **Node.js Backend:** Business logic, payments, webhooks, verification
- **Flutter App:** Calls both Supabase and Node backend

---

## Authentication

### Header Format
All requests (except webhooks) require:
```
Authorization: Bearer {supabase_jwt_token}
Content-Type: application/json
```

### Token Acquisition
Token is obtained from Supabase Auth signup/signin and included in all subsequent requests.

### Role-Based Access
- `customer` role: Can create bookings, pay, view own bookings
- `provider` role: Can set availability, accept bookings, view earnings
- `admin` role: Can view all disputes, make final decisions (internal only)

---

## 1. Authentication Endpoints

### POST /auth/signup
Create a new user account.

**Request:**
```json
{
  "email": "john@example.com",
  "password": "secure_password_123",
  "first_name": "John",
  "last_name": "Smith",
  "phone": "+1-206-555-1234",
  "role": "customer" // or "provider"
}
```

**Response:** `201 Created`
```json
{
  "id": "user-uuid",
  "email": "john@example.com",
  "first_name": "John",
  "role": "customer",
  "session": {
    "access_token": "eyJhbGc...",
    "refresh_token": "...",
    "expires_in": 3600
  }
}
```

**Errors:**
- `400 Bad Request` - Missing required fields
- `409 Conflict` - Email already exists

---

### POST /auth/signin
Login to existing account.

**Request:**
```json
{
  "email": "john@example.com",
  "password": "secure_password_123"
}
```

**Response:** `200 OK`
```json
{
  "id": "user-uuid",
  "email": "john@example.com",
  "role": "customer",
  "session": {
    "access_token": "eyJhbGc...",
    "refresh_token": "...",
    "expires_in": 3600
  }
}
```

**Errors:**
- `401 Unauthorized` - Invalid credentials
- `404 Not Found` - User doesn't exist

---

### POST /auth/refresh
Refresh expired access token.

**Request:**
```json
{
  "refresh_token": "..."
}
```

**Response:** `200 OK`
```json
{
  "access_token": "eyJhbGc...",
  "expires_in": 3600
}
```

---

### POST /auth/signout
Logout (invalidates session).

**Request:** (Authorization header required)

**Response:** `200 OK`
```json
{
  "message": "Signed out successfully"
}
```

---

## 2. Customer Endpoints

### GET /customers/profile
Get current customer's profile.

**Request:**
```
GET /customers/profile
Authorization: Bearer {token}
```

**Response:** `200 OK`
```json
{
  "id": "user-uuid",
  "email": "john@example.com",
  "first_name": "John",
  "last_name": "Smith",
  "phone": "+1-206-555-1234",
  "role": "customer",
  "created_at": "2026-09-08T10:00:00Z",
  "updated_at": "2026-09-08T10:00:00Z"
}
```

---

### PUT /customers/profile
Update customer profile.

**Request:**
```json
{
  "first_name": "Jonathan",
  "phone": "+1-206-555-5678"
}
```

**Response:** `200 OK` (updated profile)

---

### GET /customers/nearby-providers
Search for nearby available providers.

**Request:**
```
GET /customers/nearby-providers?latitude=47.1234&longitude=-122.4567&radius=5&category=cleaning
Authorization: Bearer {token}
```

**Query Parameters:**
- `latitude` (required): Customer's latitude
- `longitude` (required): Customer's longitude
- `radius` (optional): Search radius in miles (default: 5)
- `category` (optional): Service category filter (cleaning, repairs, tutoring, etc.)

**Response:** `200 OK`
```json
{
  "providers": [
    {
      "id": "provider-uuid",
      "first_name": "Jane",
      "last_name": "Doe",
      "rating": 4.8,
      "review_count": 24,
      "categories": ["cleaning", "organizing"],
      "distance_miles": 2.3,
      "hourly_rate": 45,
      "available_now": true,
      "response_time_minutes": 15,
      "photo_url": "https://..."
    }
  ],
  "count": 5
}
```

**Errors:**
- `400 Bad Request` - Missing lat/long
- `401 Unauthorized` - Not authenticated

---

### POST /customers/bookings
Create a new booking request.

**Request:**
```json
{
  "provider_id": "provider-uuid",
  "service_category": "cleaning",
  "description": "House cleaning for 3 hours",
  "address": "123 Main St, Sumner, WA 98390",
  "latitude": 47.1234,
  "longitude": -122.4567,
  "scheduled_for": "2026-09-08T14:00:00Z",
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
  "description": "House cleaning for 3 hours",
  "address": "123 Main St, Sumner, WA 98390",
  "latitude": 47.1234,
  "longitude": -122.4567,
  "scheduled_for": "2026-09-08T14:00:00Z",
  "estimated_duration_minutes": 180,
  "price": 135.00,
  "created_at": "2026-09-08T13:30:00Z",
  "expires_at": "2026-09-08T13:40:00Z"
}
```

**Errors:**
- `400 Bad Request` - Invalid data
- `402 Payment Required` - Payment method invalid
- `404 Not Found` - Provider not found
- `409 Conflict` - Provider not available

---

### GET /customers/bookings
List customer's bookings.

**Request:**
```
GET /customers/bookings?status=active&limit=20&offset=0
Authorization: Bearer {token}
```

**Query Parameters:**
- `status` (optional): `active`, `completed`, `cancelled`
- `limit` (optional): Max results (default: 20)
- `offset` (optional): Pagination offset (default: 0)

**Response:** `200 OK`
```json
{
  "bookings": [
    {
      "booking_id": "booking-uuid",
      "provider": {
        "id": "provider-uuid",
        "first_name": "Jane",
        "rating": 4.8
      },
      "status": "accepted",
      "service_category": "cleaning",
      "scheduled_for": "2026-09-08T14:00:00Z",
      "price": 135.00,
      "created_at": "2026-09-08T13:30:00Z"
    }
  ],
  "total": 5,
  "limit": 20,
  "offset": 0
}
```

---

### GET /customers/bookings/:booking_id
Get booking details.

**Request:**
```
GET /customers/bookings/booking-uuid
Authorization: Bearer {token}
```

**Response:** `200 OK` (full booking object with messages, location tracking)

---

### POST /customers/bookings/:booking_id/cancel
Cancel a booking (before provider accepts).

**Request:**
```json
{
  "reason": "Found another provider"
}
```

**Response:** `200 OK`
```json
{
  "booking_id": "booking-uuid",
  "status": "cancelled",
  "cancelled_at": "2026-09-08T13:35:00Z"
}
```

**Errors:**
- `409 Conflict` - Booking already accepted/completed

---

## 3. Provider Endpoints

### GET /providers/profile
Get current provider's profile.

**Request:**
```
GET /providers/profile
Authorization: Bearer {token}
```

**Response:** `200 OK`
```json
{
  "id": "provider-uuid",
  "email": "jane@example.com",
  "first_name": "Jane",
  "last_name": "Doe",
  "phone": "+1-206-555-9999",
  "role": "provider",
  "categories": ["cleaning", "organizing"],
  "bio": "Professional house cleaner with 5 years experience",
  "hourly_rate": 45.00,
  "rating": 4.8,
  "review_count": 24,
  "is_verified_for_work": true,
  "background_check_status": "clear",
  "stripe_connect_account_id": "acct_xxx",
  "availability_status": "offline",
  "created_at": "2026-09-08T10:00:00Z"
}
```

---

### PUT /providers/profile
Update provider profile.

**Request:**
```json
{
  "bio": "Professional organizer",
  "hourly_rate": 50.00,
  "categories": ["organizing", "cleaning"]
}
```

**Response:** `200 OK` (updated profile)

---

### POST /providers/availability/toggle
Toggle "Available Now" status.

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
  "last_updated": "2026-09-08T13:40:00Z",
  "expires_at": "2026-09-08T14:10:00Z"
}
```

**Rules:**
- Availability lasts 30 minutes
- Provider must refresh to stay available
- Location required when going online
- Status automatically expires if not refreshed

---

### POST /providers/availability/update-location
Update provider's real-time location (while available).

**Request:**
```json
{
  "latitude": 47.1235,
  "longitude": -122.4568
}
```

**Response:** `200 OK`
```json
{
  "provider_id": "provider-uuid",
  "latitude": 47.1235,
  "longitude": -122.4568,
  "last_updated": "2026-09-08T13:42:00Z"
}
```

**Rate Limit:** Once per 30 seconds

---

### GET /providers/bookings
List provider's bookings.

**Request:**
```
GET /providers/bookings?status=pending&limit=20
Authorization: Bearer {token}
```

**Query Parameters:**
- `status` (optional): `pending_acceptance`, `accepted`, `in_progress`, `completed`
- `limit` (optional): Default 20

**Response:** `200 OK`
```json
{
  "bookings": [
    {
      "booking_id": "booking-uuid",
      "customer": {
        "id": "customer-uuid",
        "first_name": "John",
        "rating": 4.5
      },
      "status": "pending_acceptance",
      "service_category": "cleaning",
      "address": "123 Main St, Sumner, WA",
      "scheduled_for": "2026-09-08T14:00:00Z",
      "price": 135.00,
      "created_at": "2026-09-08T13:30:00Z",
      "expires_at": "2026-09-08T13:40:00Z"
    }
  ],
  "total": 3
}
```

---

### POST /providers/bookings/:booking_id/accept
Accept a booking request.

**Request:**
```json
{
  "estimated_arrival_minutes": 15
}
```

**Response:** `200 OK`
```json
{
  "booking_id": "booking-uuid",
  "status": "accepted",
  "provider_id": "provider-uuid",
  "customer_contact": {
    "phone": "+1-206-555-1234",
    "address": "123 Main St, Sumner, WA"
  },
  "estimated_arrival_minutes": 15,
  "accepted_at": "2026-09-08T13:35:00Z"
}
```

**Errors:**
- `409 Conflict` - Already accepted or expired
- `410 Gone` - Booking was cancelled

---

### POST /providers/bookings/:booking_id/complete
Mark booking as completed.

**Request:**
```json
{
  "actual_duration_minutes": 165,
  "notes": "Cleaned kitchen and living room"
}
```

**Response:** `200 OK`
```json
{
  "booking_id": "booking-uuid",
  "status": "completed",
  "completed_at": "2026-09-08T15:45:00Z",
  "payment_status": "pending",
  "payment_released_at": "2026-09-09T15:45:00Z"
}
```

**Note:** Payment held for 48-hour dispute window before releasing to provider.

---

### GET /providers/earnings
Get provider's earnings summary.

**Request:**
```
GET /providers/earnings?period=month
Authorization: Bearer {token}
```

**Query Parameters:**
- `period` (optional): `week`, `month`, `all` (default: month)

**Response:** `200 OK`
```json
{
  "period": "month",
  "start_date": "2026-09-01",
  "end_date": "2026-09-30",
  "total_bookings": 12,
  "total_earnings": 540.00,
  "yuki_fees": 54.00,
  "net_earnings": 486.00,
  "pending_payment": 135.00,
  "available_balance": 351.00,
  "breakdown": [
    {
      "date": "2026-09-08",
      "bookings": 1,
      "gross": 135.00,
      "yuki_fee": 13.50,
      "net": 121.50
    }
  ]
}
```

---

### POST /providers/withdrawals
Request earnings withdrawal.

**Request:**
```json
{
  "amount": 300.00
}
```

**Response:** `201 Created`
```json
{
  "withdrawal_id": "withdrawal-uuid",
  "amount": 300.00,
  "status": "pending",
  "requested_at": "2026-09-08T15:00:00Z",
  "expected_arrival": "2026-09-10T00:00:00Z"
}
```

**Errors:**
- `400 Bad Request` - Amount exceeds available balance
- `402 Payment Required` - Stripe Connect account not set up

---

## 4. Payment Endpoints

### POST /payments/intent
Create a payment intent (Stripe).

**Request:**
```json
{
  "booking_id": "booking-uuid",
  "amount": 135.00,
  "currency": "usd",
  "customer_id": "customer-uuid",
  "idempotency_key": "unique-key-abc123"
}
```

**Response:** `201 Created`
```json
{
  "payment_intent_id": "pi_xxx",
  "client_secret": "pi_xxx_secret_yyy",
  "status": "requires_payment_method",
  "amount": 135.00,
  "booking_id": "booking-uuid"
}
```

**Idempotency:** `idempotency_key` prevents duplicate charges on retry.

---

### POST /payments/confirm
Confirm payment after customer enters card details.

**Request:**
```json
{
  "payment_intent_id": "pi_xxx",
  "payment_method_id": "pm_xxx"
}
```

**Response:** `200 OK`
```json
{
  "payment_intent_id": "pi_xxx",
  "status": "succeeded",
  "charge_id": "ch_xxx",
  "amount": 135.00,
  "booking_id": "booking-uuid",
  "confirmed_at": "2026-09-08T13:35:00Z"
}
```

**Errors:**
- `402 Payment Required` - Card declined
- `409 Conflict` - Payment already confirmed

---

### GET /payments/history
Get customer's payment history.

**Request:**
```
GET /payments/history?limit=20&offset=0
Authorization: Bearer {token}
```

**Response:** `200 OK`
```json
{
  "payments": [
    {
      "payment_id": "ch_xxx",
      "booking_id": "booking-uuid",
      "provider": {
        "first_name": "Jane"
      },
      "amount": 135.00,
      "status": "succeeded",
      "created_at": "2026-09-08T13:35:00Z"
    }
  ],
  "total": 12
}
```

---

## 5. Dispute Endpoints

### POST /disputes/create
Customer files a dispute (within 48 hours of booking completion).

**Request:**
```json
{
  "booking_id": "booking-uuid",
  "reason": "service_not_provided", // or "provider_no_show", "quality_issue", "safety_concern", "other"
  "description": "The provider did not complete the agreed upon tasks",
  "evidence_urls": ["https://...image1.jpg", "https://...image2.jpg"]
}
```

**Response:** `201 Created`
```json
{
  "dispute_id": "dispute-uuid",
  "booking_id": "booking-uuid",
  "status": "open",
  "reason": "service_not_provided",
  "created_at": "2026-09-08T16:00:00Z",
  "deadline": "2026-09-10T15:45:00Z"
}
```

**Errors:**
- `409 Conflict` - Outside 48-hour window
- `410 Gone` - Booking not found

---

### GET /disputes/:dispute_id
Get dispute details.

**Request:**
```
GET /disputes/dispute-uuid
Authorization: Bearer {token}
```

**Response:** `200 OK`
```json
{
  "dispute_id": "dispute-uuid",
  "booking_id": "booking-uuid",
  "customer_id": "customer-uuid",
  "provider_id": "provider-uuid",
  "status": "open", // or "reviewing", "resolved"
  "reason": "service_not_provided",
  "description": "...",
  "evidence_urls": [],
  "created_at": "2026-09-08T16:00:00Z",
  "deadline": "2026-09-10T15:45:00Z",
  "provider_response": {
    "message": "Customer was not home when I arrived",
    "submitted_at": "2026-09-08T16:30:00Z"
  },
  "resolution": null
}
```

---

### POST /disputes/:dispute_id/provider-response
Provider responds to dispute.

**Request:**
```json
{
  "message": "Customer was not home when I arrived"
}
```

**Response:** `200 OK` (updated dispute)

---

### POST /disputes/:dispute_id/submit-evidence
Add evidence to dispute (customer or provider).

**Request:**
```json
{
  "evidence_type": "photo", // or "message", "timestamp_proof"
  "evidence_urls": ["https://...image.jpg"]
}
```

**Response:** `200 OK`

---

### GET /disputes
List disputes (admin only).

**Request:**
```
GET /disputes?status=open&limit=50
Authorization: Bearer {admin_token}
```

**Response:** `200 OK` (list of disputes with evidence)

---

### POST /disputes/:dispute_id/resolve
Resolve dispute (admin only).

**Request:**
```json
{
  "decision": "full_refund", // or "partial_refund", "deny", "no_fault"
  "refund_amount": 135.00,
  "reasoning": "Evidence supports customer claim that service was not provided"
}
```

**Response:** `200 OK`
```json
{
  "dispute_id": "dispute-uuid",
  "status": "resolved",
  "decision": "full_refund",
  "refund_amount": 135.00,
  "refund_status": "processing",
  "resolved_at": "2026-09-09T10:00:00Z"
}
```

---

## 6. Background Check Endpoints

### POST /background-checks/initiate
Start background check for new provider (after signup).

**Request:**
```json
{
  "first_name": "Jane",
  "last_name": "Doe",
  "date_of_birth": "1990-01-15",
  "ssn": "xxx-xx-1234",
  "driver_license_number": "WDOE1234567",
  "driver_license_state": "WA"
}
```

**Response:** `201 Created`
```json
{
  "check_id": "check-uuid",
  "checkr_candidate_id": "cand_xxx",
  "status": "pending",
  "initiated_at": "2026-09-08T13:40:00Z",
  "expected_completion": "2026-09-10T18:00:00Z"
}
```

---

### GET /background-checks/:check_id
Get background check status.

**Request:**
```
GET /background-checks/check-uuid
Authorization: Bearer {token}
```

**Response:** `200 OK`
```json
{
  "check_id": "check-uuid",
  "status": "completed", // or "pending", "failed"
  "result": "clear", // or "consider", "adverse"
  "completed_at": "2026-09-10T14:30:00Z",
  "provider_status": "approved", // or "under_review", "rejected"
  "consider_reasons": [],
  "dispute_available": false
}
```

---

### POST /background-checks/:check_id/dispute
Provider disputes background check results.

**Request:**
```json
{
  "reason": "The conviction listed is for my brother, not me",
  "evidence_urls": ["https://...court_document.pdf"]
}
```

**Response:** `201 Created`
```json
{
  "dispute_id": "dispute-uuid",
  "check_id": "check-uuid",
  "status": "submitted",
  "submitted_at": "2026-09-10T15:00:00Z",
  "deadline": "2026-10-10T15:00:00Z"
}
```

---

## 7. Webhook Endpoints

### POST /webhooks/stripe
Stripe payment events.

**Webhook Events Handled:**
- `payment_intent.succeeded` — Charge successful
- `charge.refunded` — Refund processed
- `charge.dispute.created` — Chargeback filed

**Request:** (Stripe sends this; no auth header)
```json
{
  "id": "evt_xxx",
  "type": "payment_intent.succeeded",
  "data": {
    "object": {
      "id": "pi_xxx",
      "amount": 13500,
      "client_secret": "pi_xxx_secret_yyy"
    }
  }
}
```

**Processing:**
1. Verify webhook signature (using `STRIPE_WEBHOOK_SECRET`)
2. Log event in audit log
3. Update payment status in database
4. Trigger provider payout if applicable

**Response:** `200 OK`
```json
{
  "received": true
}
```

---

### POST /webhooks/checkr
Checkr background check events.

**Webhook Events Handled:**
- `report.completed` — Background check finished

**Request:** (Checkr sends this)
```json
{
  "type": "report.completed",
  "data": {
    "object": {
      "id": "rpt_xxx",
      "candidate_id": "cand_xxx",
      "custom_id": "provider-uuid",
      "status": "completed",
      "result": "clear"
    }
  }
}
```

**Processing:**
1. Verify webhook signature (using `CHECKR_WEBHOOK_SECRET`)
2. Update provider background check status
3. If clear: send approval email
4. If adverse: send adverse action notice
5. Log event in audit log

**Response:** `200 OK`
```json
{
  "received": true
}
```

---

## 8. Real-Time Subscriptions (Supabase)

For live features (provider availability updates, booking status changes), use Supabase real-time subscriptions instead of polling.

### Subscribe to Provider Availability
```javascript
// Listen for provider location updates
const subscription = supabase
  .channel('provider_statuses')
  .on(
    'postgres_changes',
    {
      event: '*',
      schema: 'public',
      table: 'provider_statuses',
      filter: `is_verified_for_work=eq.true`
    },
    (payload) => {
      console.log('Provider updated:', payload);
      // Update nearby providers list on map
    }
  )
  .subscribe();
```

### Subscribe to Booking Status Changes
```javascript
const subscription = supabase
  .channel(`booking_${booking_id}`)
  .on(
    'postgres_changes',
    {
      event: 'UPDATE',
      schema: 'public',
      table: 'booking_requests',
      filter: `id=eq.${booking_id}`
    },
    (payload) => {
      console.log('Booking updated:', payload.new);
    }
  )
  .subscribe();
```

---

## 9. Error Responses

All errors follow this format:

**4xx Client Errors:**
```json
{
  "error": "invalid_request",
  "message": "Missing required field: latitude",
  "status": 400,
  "timestamp": "2026-09-08T13:40:00Z"
}
```

**5xx Server Errors:**
```json
{
  "error": "internal_server_error",
  "message": "Database connection failed",
  "status": 500,
  "timestamp": "2026-09-08T13:40:00Z",
  "request_id": "req_xxx"
}
```

**Common Status Codes:**
- `200 OK` — Success
- `201 Created` — Resource created
- `400 Bad Request` — Invalid input
- `401 Unauthorized` — Not authenticated
- `402 Payment Required` — Payment issue
- `403 Forbidden` — Insufficient permissions
- `404 Not Found` — Resource doesn't exist
- `409 Conflict` — State conflict (e.g., already accepted)
- `429 Too Many Requests` — Rate limit exceeded
- `500 Internal Server Error` — Server issue

---

## 10. Rate Limiting

**Global Limits:**
- 100 requests per minute (per user)
- 1000 requests per hour (per user)

**Endpoint-Specific Limits:**
- Location updates: 1 per 30 seconds
- Availability toggle: 1 per 5 minutes
- Create booking: 5 per 10 minutes
- Dispute creation: 1 per dispute (48-hour window)

**Headers:**
```
X-RateLimit-Limit: 100
X-RateLimit-Remaining: 87
X-RateLimit-Reset: 1694183440
```

**Over Limit Response:** `429 Too Many Requests`
```json
{
  "error": "rate_limit_exceeded",
  "message": "Too many requests. Try again in 30 seconds.",
  "retry_after": 30
}
```

---

## 11. Implementation Notes

### Idempotency
All payment and critical operations support idempotency keys:
```
Idempotency-Key: unique-request-id-abc123
```

If the same request is sent twice with the same key, the server returns the same response without creating duplicates.

### Pagination
List endpoints support `limit` and `offset`:
- `limit`: 1-100 (default: 20)
- `offset`: 0+ (default: 0)

Response includes:
```json
{
  "data": [...],
  "total": 150,
  "limit": 20,
  "offset": 0
}
```

### Timestamps
All timestamps are ISO 8601 format (UTC):
```
2026-09-08T13:40:00Z
```

### Field Validation
- Email: RFC 5322 compliant
- Phone: E.164 format (+1-206-555-1234)
- Prices: Positive decimal, 2 places (135.00)
- Coordinates: Lat -90 to 90, Lon -180 to 180

---

## 12. Security Headers

All responses include:
```
X-Content-Type-Options: nosniff
X-Frame-Options: DENY
X-XSS-Protection: 1; mode=block
Strict-Transport-Security: max-age=31536000; includeSubDomains
Content-Security-Policy: default-src 'self'
```

---

## 13. CORS

Allowed Origins:
- `https://yuki.app`
- `https://*.yuki.app`
- `http://localhost:3000` (development only)

---

## Summary

| Category | Endpoint Count |
|----------|-----------------|
| Auth | 4 |
| Customer | 8 |
| Provider | 10 |
| Payment | 3 |
| Dispute | 6 |
| Background Check | 3 |
| Webhooks | 2 |
| **Total** | **36** |

---

**Next Steps:**
1. Implement in Node.js/Express
2. Add OpenAPI/Swagger documentation
3. Create SDK wrapper for Flutter
4. Test with Postman/Insomnia
5. Deploy to staging environment

