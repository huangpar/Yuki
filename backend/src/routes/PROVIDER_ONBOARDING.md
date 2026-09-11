# Provider Onboarding API Endpoints

Complete flow for provider signup through verification.

---

## Overview

Provider onboarding is a multi-step process:

```
1. POST /api/providers/signup
   ↓ Creates user + profile
2. PUT /api/providers/profile
   ↓ Sets services/bio/rate
3. POST /api/providers/background-checks/initiate
   ↓ Starts Checkr verification
4. POST /api/providers/stripe-connect/url
   ↓ Gets Stripe Connect onboarding link
5. GET /api/providers/verification-status
   ↓ Check overall progress
```

---

## 1. Provider Signup

**Endpoint:** `POST /api/providers/signup`

Create a new provider account.

**Request:**
```json
{
  "email": "jane@example.com",
  "password": "SecurePassword123",
  "first_name": "Jane",
  "last_name": "Doe",
  "phone": "+1-206-555-1234",
  "role": "provider"
}
```

**Response:** `201 Created`
```json
{
  "id": "provider-uuid",
  "email": "jane@example.com",
  "first_name": "Jane",
  "last_name": "Doe",
  "phone": "+1-206-555-1234",
  "role": "provider",
  "session": {
    "access_token": "eyJhbGc...",
    "refresh_token": "...",
    "expires_in": 3600
  },
  "next_step": "profile_setup"
}
```

**Validation:**
- Email: valid format, unique
- Password: min 8 chars, requires uppercase + lowercase + number
- Phone: valid E.164 format
- Role: forced to "provider"

**Errors:**
- `400 Bad Request` — Validation failed
- `409 Conflict` — Email already registered

**What happens:**
- Creates Supabase Auth user
- Creates profiles record
- Creates provider_statuses record (background_check_status: not_started)
- Returns session token (provider is logged in)

---

## 2. Update Provider Profile

**Endpoint:** `PUT /api/providers/profile`

Set services offered, bio, and hourly rate.

**Headers:**
```
Authorization: Bearer {access_token}
```

**Request:**
```json
{
  "bio": "Professional house cleaner with 5+ years experience",
  "hourly_rate": 45.00,
  "categories": ["cleaning", "organizing"]
}
```

**Response:** `200 OK`
```json
{
  "id": "provider-uuid",
  "email": "jane@example.com",
  "first_name": "Jane",
  "last_name": "Doe",
  "bio": "Professional house cleaner with 5+ years experience",
  "hourly_rate": 45.00,
  "categories": ["cleaning", "organizing"],
  "next_step": "background_check"
}
```

**Validation:**
- Bio: 0-500 characters, trimmed
- Hourly rate: $10-$500, max 2 decimals
- Categories: 1-10 items, lowercase

**Errors:**
- `400 Bad Request` — Validation failed
- `401 Unauthorized` — Missing token
- `403 Forbidden` — Not a provider

**What happens:**
- Updates profiles table with bio, hourly_rate, categories
- Provider can now accept bookings at specified rate

---

## 3. Initiate Background Check

**Endpoint:** `POST /api/providers/background-checks/initiate`

Start background check via Checkr.

**Headers:**
```
Authorization: Bearer {access_token}
```

**Request:**
```json
{
  "first_name": "Jane",
  "last_name": "Doe",
  "date_of_birth": "1990-01-15",
  "ssn": "123-45-6789",
  "driver_license_number": "WA1234567",
  "driver_license_state": "WA"
}
```

**Response:** `201 Created`
```json
{
  "check_id": "cand_abc123xyz",
  "report_id": "rpt_abc123xyz",
  "status": "pending",
  "initiated_at": "2026-09-09T10:00:00Z",
  "expected_completion": "2026-09-12T10:00:00Z",
  "next_step": "stripe_connect"
}
```

**Validation:**
- first_name, last_name: 1-100 chars
- date_of_birth: YYYY-MM-DD format, must be 18+
- ssn: XXX-XX-XXXX format
- driver_license: valid format for state

**Errors:**
- `400 Bad Request` — Validation failed
- `401 Unauthorized` — Missing token
- `403 Forbidden` — Not a provider
- `500 Internal Server Error` — Checkr API error

**What happens:**
1. Creates Checkr candidate with provider's info
2. Creates Checkr report (standard_v2 package)
3. Updates provider_statuses:
   - background_check_status: 'pending'
   - checkr_candidate_id: (Checkr ID)
4. Logs audit event
5. Checkr will later webhook when report completes

**Note:** Checkr will send webhook to POST /webhooks/checkr when:
- Report completes (clear, consider, or adverse)
- Then Yuki creates adverse action notice if needed

---

## 4. Get Stripe Connect Onboarding URL

**Endpoint:** `POST /api/providers/stripe-connect/url`

Generate Stripe Connect onboarding link for provider payouts.

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
  "onboarding_url": "https://connect.stripe.com/onboarding/xxxxx",
  "account_id": "acct_xxxxx",
  "expires_at": "2026-09-10T10:00:00Z"
}
```

**Errors:**
- `401 Unauthorized` — Missing token
- `403 Forbidden` — Not a provider
- `404 Not Found` — Provider not found
- `500 Internal Server Error` — Stripe API error

**What happens:**
1. Creates Stripe Express account (if not already created)
2. Stores account ID in profiles.stripe_connect_account_id
3. Generates Stripe Connect onboarding link
4. Link valid for 24 hours

**After Provider Completes Onboarding:**
- Provider redirects to https://yuki.app/provider/stripe-complete
- Stripe account becomes enabled for charges
- Provider can now receive payouts

---

## 5. Check Verification Status

**Endpoint:** `GET /api/providers/verification-status`

Check provider's overall verification progress.

**Headers:**
```
Authorization: Bearer {access_token}
```

**Request:**
```
GET /api/providers/verification-status
```

**Response:** `200 OK`
```json
{
  "is_verified": false,
  "background_check": {
    "status": "pending",
    "is_verified": false
  },
  "stripe_connect": {
    "status": "incomplete",
    "account_id": "acct_xxxxx"
  },
  "next_step": "background_check_pending",
  "can_go_online": false
}
```

**Statuses:**

Background Check:
- `not_started` — Not initiated
- `pending` — Waiting for Checkr report
- `clear` — Passed verification
- `failed` — Did not pass

Stripe Connect:
- `not_started` — Not initiated
- `incomplete` — Started but not completed
- `pending_review` — Stripe reviewing
- `complete` — Ready for payouts

**Next Steps:**
- `background_check` — Provider needs to start check
- `background_check_pending` — Waiting for results
- `stripe_connect` — Start Stripe onboarding
- `stripe_connect_pending` — Waiting for completion
- `profile_review` — Additional review needed
- `ready_to_work` — Fully verified, can go online

**Errors:**
- `401 Unauthorized` — Missing token
- `403 Forbidden` — Not a provider
- `404 Not Found` — Provider not found

**What this endpoint does:**
1. Retrieves background_check_status from provider_statuses
2. Queries Stripe to check account status (charges_enabled)
3. Returns overall is_verified (both check AND Stripe done)
4. Returns can_go_online (true only if fully verified)

---

## Status Transitions

### Happy Path
```
signup (role: provider)
  ↓
profile_setup (bio, hourly_rate, categories)
  ↓
background_check_initiate (Checkr created)
  ↓
[Waiting 1-3 days for Checkr]
  ↓
[Checkr webhook: report.completed with result: clear]
  ↓
stripe_connect_url (Stripe account created)
  ↓
[Provider opens onboarding link, completes Stripe]
  ↓
[Stripe redirect: https://yuki.app/provider/stripe-complete]
  ↓
can_go_online: true ✅
  ↓
Provider can activate "Available Now" and start accepting bookings
```

### Adverse Path (Background Check Failed)
```
[Checkr webhook: report.completed with result: consider/adverse]
  ↓
[Yuki creates adverse_actions record]
  ↓
[Yuki sends provider adverse action notice email]
  ↓
Provider has 30 days to dispute or appeal
  ↓
[If dispute resolved in provider's favor]
  ↓
[Proceed with Stripe Connect setup]
```

---

## Error Handling

All errors follow standard format:

```json
{
  "error": "error_type",
  "message": "Human-readable error message",
  "status": 400,
  "timestamp": "2026-09-09T10:00:00Z",
  "request_id": "req_12345"
}
```

**Common error types:**
- `validation_error` — Input validation failed
- `unauthorized` — Missing/invalid auth token
- `forbidden` — Insufficient permissions
- `not_found` — Resource not found
- `email_exists` — Email already registered
- `invalid_role` — Role must be 'provider'
- `signup_failed` — Auth user creation failed

---

## Testing with cURL

### 1. Signup
```bash
curl -X POST http://localhost:3000/api/providers/signup \
  -H "Content-Type: application/json" \
  -d '{
    "email": "test@example.com",
    "password": "Password123",
    "first_name": "Test",
    "last_name": "Provider",
    "phone": "+12065551234",
    "role": "provider"
  }'
```

### 2. Update Profile
```bash
curl -X PUT http://localhost:3000/api/providers/profile \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -d '{
    "bio": "Professional cleaner",
    "hourly_rate": 45,
    "categories": ["cleaning"]
  }'
```

### 3. Initiate Background Check
```bash
curl -X POST http://localhost:3000/api/providers/background-checks/initiate \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -d '{
    "first_name": "Test",
    "last_name": "Provider",
    "date_of_birth": "1990-01-15",
    "ssn": "123-45-6789",
    "driver_license_number": "TESTLIC123",
    "driver_license_state": "WA"
  }'
```

### 4. Get Stripe Onboarding URL
```bash
curl -X POST http://localhost:3000/api/providers/stripe-connect/url \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -d '{}'
```

### 5. Check Verification Status
```bash
curl -X GET http://localhost:3000/api/providers/verification-status \
  -H "Authorization: Bearer YOUR_TOKEN"
```

---

## Database Schema

**Affected Tables:**

- `profiles` — Stores first_name, last_name, email, phone, bio, hourly_rate, categories, stripe_connect_account_id
- `provider_statuses` — Stores background_check_status, checkr_candidate_id, is_verified_for_work, stripe account state
- `background_check_audit_log` — Logs each verification event
- `adverse_actions` — Created if background check has concerns

---

## Security Notes

1. **Password Hashing** — Handled by Supabase Auth (bcrypt)
2. **PII Protection** — SSN and ID numbers sent directly to Checkr (never stored in Yuki)
3. **Webhook Verification** — Checkr/Stripe webhooks verified before processing
4. **JWT Validation** — All protected endpoints verify auth token
5. **Role-Based Access** — Only providers can access these endpoints

---

## Monitoring & Logging

Each endpoint logs:
- Provider ID
- Event type
- Timestamps
- API call results
- Errors

Useful for:
- Debugging onboarding issues
- Tracking verification progress
- Detecting fraud/abuse
- Compliance audits

