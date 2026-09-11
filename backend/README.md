# Yuki Backend API Server

Node.js/Express backend for the Yuki services marketplace platform.

## Quick Start

### Prerequisites
- Node.js 18+
- npm or yarn

### Installation

```bash
npm install
```

### Configuration

Create a `.env` file based on `.env.example`:

```bash
cp .env.example .env
```

Fill in your credentials:
- Supabase URL and keys
- Stripe API keys and webhook secret
- Checkr API key and webhook secret

### Running

**Development (with auto-reload):**
```bash
npm run dev
```

**Production:**
```bash
npm start
```

The server will start on `http://localhost:3000` (configurable via `PORT` env var).

## API Structure

### Health Check
```
GET /health
→ 200 OK { status: "ok", uptime: ... }
```

### Webhooks

#### Stripe Webhooks
```
POST /webhooks/stripe
Headers: stripe-signature: t=...,v1=...

Handles:
- payment_intent.succeeded
- charge.refunded
- charge.dispute.created
```

#### Checkr Webhooks
```
POST /webhooks/checkr
Headers: x-checkr-signature: sha256=...

Handles:
- report.completed
```

### Protected Endpoints (Example)
```
GET /api/profile
Headers: Authorization: Bearer {supabase_jwt_token}
→ 200 OK { id, email, role, ... }
```

## Architecture

```
src/
├── index.js              # Express app, routes, middleware setup
├── config.js             # Environment configuration
├── db.js                 # Supabase client & database helpers
├── middleware/
│   ├── auth.js          # JWT verification & role checks
│   ├── errorHandler.js  # Error handling & async wrapper
│   └── logger.js        # Request/response logging
├── webhooks/
│   ├── stripe.js        # Stripe event handlers
│   └── checkr.js        # Checkr event handlers
└── utils/
    └── signatures.js    # Webhook signature verification
```

## Security

### Webhook Signature Verification
All webhooks are verified using HMAC signatures before processing:
- **Stripe:** `stripe-signature` header with SHA-256
- **Checkr:** `x-checkr-signature` header with SHA-256

Unverified webhooks are rejected with `401 Unauthorized`.

### Authentication
Protected routes require Supabase JWT token in `Authorization: Bearer` header.

Token is verified with Supabase Auth service.

### Database
- Uses Supabase service role key for server operations
- Row-Level Security (RLS) policies enforce data access
- Audit logging for sensitive operations

## Environment Variables

```
NODE_ENV              # development, production
PORT                  # Server port (default: 3000)
LOG_LEVEL             # debug, info, warn, error
SUPABASE_URL          # Supabase project URL
SUPABASE_ANON_KEY     # Anonymous key (for client)
SUPABASE_SERVICE_ROLE_KEY  # Service role (for server - secret!)
STRIPE_SECRET_KEY     # Stripe secret key
STRIPE_WEBHOOK_SECRET # Stripe webhook signing secret
CHECKR_API_KEY        # Checkr API key
CHECKR_WEBHOOK_SECRET # Checkr webhook signing secret
```

## Database Helpers

The `db.js` file provides helper functions:

```javascript
import { 
  getUserById,
  getProviderStatus,
  updateProviderAvailability,
  getBookingById,
  createPayment,
  updatePaymentStatus,
  logAuditEvent,
} from './db.js';
```

## Error Handling

All errors follow a standard format:

```json
{
  "error": "error_type",
  "message": "Human-readable error message",
  "status": 400,
  "timestamp": "2026-09-08T13:40:00Z",
  "request_id": "req_123456"
}
```

Common status codes:
- `200` - Success
- `400` - Bad request
- `401` - Unauthorized
- `403` - Forbidden
- `404` - Not found
- `409` - Conflict
- `500` - Server error

## Logging

Logs are structured JSON format (configurable):

```json
{
  "timestamp": "2026-09-08T13:40:00Z",
  "level": "info",
  "message": "Payment succeeded",
  "paymentIntentId": "pi_xxx",
  "amount": 135.00
}
```

Log levels: `debug`, `info`, `warn`, `error`

Configure with `LOG_LEVEL` environment variable.

## Testing

Run tests with:
```bash
npm test
```

Tests use Node's built-in test runner (Node 18+).

## Deployment

### Environment Setup
1. Set all environment variables on your hosting platform
2. Ensure Supabase database migrations have been run
3. Configure Stripe and Checkr webhook URLs to point to your deployment

### Webhook URLs
After deploying, configure these webhooks:

**Stripe:** https://your-domain.com/webhooks/stripe
**Checkr:** https://your-domain.com/webhooks/checkr

### Monitoring
- Monitor error logs for webhook processing failures
- Track payment success rate (target: >99%)
- Monitor webhook delivery latency
- Alert on repeated failed signature verifications

## Development

### Adding New Webhook Events

1. Handle event in webhook handler (stripe.js or checkr.js)
2. Update database with new status
3. Log audit event
4. Test with webhook signature

### Adding Protected Routes

```javascript
import { verifyAuth, requireRole } from './middleware/auth.js';

app.post('/api/endpoint', 
  verifyAuth,
  requireRole('provider'),
  async (req, res) => {
    // Your handler
  }
);
```

## Troubleshooting

### Webhook signature verification fails
- Verify webhook secret is correct in `.env`
- Check that raw request body is used (not parsed JSON)
- Ensure timestamp in signature is recent (within 5 minutes for Stripe)

### Database connection errors
- Verify Supabase URL and keys are correct
- Check network connectivity to Supabase
- Ensure service role key is being used for server operations

### Payment webhook not processing
- Check Stripe webhook configuration
- Verify payment exists in database before processing
- Check logs for specific error message

## Support

For issues or questions:
1. Check logs for error details
2. Verify webhook signatures in test mode
3. Check Stripe/Checkr dashboards for webhook delivery status
4. Review database state with Supabase studio

---

**Last Updated:** September 8, 2026  
**Version:** 1.0.0
