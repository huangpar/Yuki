# Yuki Payment Architecture & Security Design

**Purpose:** Define how Yuki handles payments securely without storing sensitive card data.

**Framework:** Stripe for all payment processing (PCI-DSS Level 1 compliant).

---

## 1. Payment Flow Architecture

### High-Level Flow

```
Customer → [Request Service] → Provider
   ↓
Booking Confirmed
   ↓
Service Provided
   ↓
Customer → [Pay via Stripe] → Stripe (secure payment processor)
   ↓
Yuki Backend → [Verify payment] → Stripe
   ↓
Provider → [Receive payment] → Stripe Connect Account
   ↓
Provider → [Withdraw funds] → Provider's Bank Account
```

### Key Principle
**Yuki never touches, stores, or processes raw payment data.** Stripe handles all sensitive information.

---

## 2. Technologies & Services

### Payment Processor: Stripe

**Why Stripe:**
- PCI-DSS Level 1 certified (highest security standard)
- Handles all payment card processing
- Built-in fraud detection
- 1099 reporting capabilities
- Webhook support for real-time updates

### Backend: Node.js + Express
- Validates payments
- Manages payment status in Yuki database
- Handles webhook events
- Orchestrates fund distribution

### Frontend: Flutter Mobile App
- Securely collects payment method from Stripe (via Stripe SDK)
- Never directly handles card data
- Shows transaction confirmations

### Database: Supabase (PostgreSQL)
- Stores payment status (pending, completed, disputed)
- Stores transaction records (amounts, dates, parties)
- **NEVER stores:** Card numbers, CVV, full credit card data

---

## 3. Customer Payment Flow (Detailed)

### Step 1: Booking Creation

**Customer selects Provider and initiates booking**

```sql
-- Yuki database (booking_requests table)
INSERT INTO booking_requests (
  customer_id, 
  provider_id, 
  service_description, 
  customer_location, 
  status,  -- 'pending'
  requested_at
) VALUES (...)
```

**Yuki sends back:**
- Booking ID
- Provider name & rate
- Service details
- **Total amount to be charged** (for customer confirmation)

### Step 2: Stripe Payment Sheet (Frontend)

**Customer confirms booking → payment method required**

**Flutter app code (pseudocode):**
```dart
// Never handle card data directly
final paymentSheet = StripePaymentSheet(
  publishableKey: "pk_live_xxx", // public key only
  merchantDisplayName: "Yuki",
  customerId: customer_stripe_id,
  ephemeralKeySecret: generateEphemeralKey(), // temporary, single-use
);

// User selects payment method securely in Stripe's UI
final result = await paymentSheet.presentPaymentOptions();
// Returns: PaymentMethod ID (not card data)
```

**What the customer sees:**
- Secure Stripe payment sheet (Apple Pay, Google Pay, card entry)
- Amount to be charged
- Confirm button

**Customer's card data:**
- Entered directly into Stripe's secure interface
- **Never touches Yuki's servers**
- Tokenized into a `PaymentMethod` ID

### Step 3: Backend Charges Customer

**After customer confirms payment method:**

```javascript
// Node.js backend
const stripe = require("stripe")(process.env.STRIPE_SECRET_KEY);

const paymentIntent = await stripe.paymentIntents.create({
  amount: totalAmountInCents, // $25.00 = 2500
  currency: "usd",
  customer: customerStripeId,
  payment_method: paymentMethodId, // from frontend
  confirm: true,
  description: `Yuki booking #${bookingId}`,
  metadata: {
    bookingId: bookingId,
    customerId: customerId,
    providerId: providerId,
  },
  idempotency_key: `booking-${bookingId}`, // prevent duplicate charges
});

// Log payment in Yuki database
await db.insert("payments", {
  booking_id: bookingId,
  stripe_payment_intent_id: paymentIntent.id,
  amount: totalAmountInCents,
  status: paymentIntent.status, // "succeeded" or "requires_action"
  customer_id: customerId,
  provider_id: providerId,
  created_at: new Date(),
});
```

**Key Security Practices:**
- `idempotency_key` prevents duplicate charges if request is retried
- `metadata` ties payment to booking for tracking
- `confirm: true` immediately charges (no second step)
- **Only Stripe secret key is on server** (never public key, never card data)

### Step 4: Stripe Webhook Confirmation

**Stripe sends webhook to Yuki after payment processes:**

```javascript
// Node.js endpoint: POST /webhooks/stripe
app.post("/webhooks/stripe", bodyParser.raw({type: 'application/json'}), async (req, res) => {
  const sig = req.headers['stripe-signature'];
  
  // Verify webhook is actually from Stripe
  let event;
  try {
    event = stripe.webhooks.constructEvent(
      req.body, 
      sig, 
      process.env.STRIPE_WEBHOOK_SECRET
    );
  } catch (err) {
    console.error('Webhook signature verification failed');
    return res.status(400).send('Webhook Error');
  }

  // Handle payment success
  if (event.type === 'payment_intent.succeeded') {
    const paymentIntent = event.data.object;
    
    // Update payment status in Yuki database
    await db.update("payments", 
      {booking_id: paymentIntent.metadata.bookingId}, 
      {status: 'succeeded', stripe_charge_id: paymentIntent.charges.data[0].id}
    );
    
    // Update booking status to 'accepted' (provider can now act)
    await db.update("booking_requests",
      {id: paymentIntent.metadata.bookingId},
      {status: 'accepted', payment_confirmed_at: new Date()}
    );
    
    // Notify both parties via real-time update
    await supabase.from('payments').on('*', 
      payload => {
        // Real-time notification to app
      }
    ).subscribe();
  }

  // Handle payment failure
  if (event.type === 'payment_intent.payment_failed') {
    const paymentIntent = event.data.object;
    
    await db.update("payments",
      {booking_id: paymentIntent.metadata.bookingId},
      {status: 'failed', failure_reason: paymentIntent.last_payment_error.message}
    );
    
    // Notify customer of failure
    sendNotification(paymentIntent.metadata.customerId, 
      "Payment failed. Please try again or choose another payment method.");
  }

  res.json({received: true});
});
```

**Webhook Security:**
- Stripe signs all webhooks with a secret key
- We verify the signature before processing
- Prevents fake webhooks from unauthorized parties
- Webhook endpoint is **HTTPS only** (Stripe enforces this)

### Step 5: Service Completion & Payout

**After service is completed (within 48 hours):**

1. **Customer confirms service completion** in app
2. **Dispute window opens** (48 hours for customer to report issues)
3. **After dispute window closes,** funds are released to Provider

```javascript
// After 48-hour dispute window
const transfer = await stripe.transfers.create({
  amount: providerEarningsInCents, // e.g., $22.50 (after 10% Yuki fee)
  currency: "usd",
  destination: providerStripeAccountId, // Stripe Connect account
  source_transaction: paymentIntent.charges.data[0].id, // link to original charge
  description: `Yuki booking #${bookingId} payout`,
  metadata: {
    bookingId: bookingId,
    customerId: customerId,
  },
});

// Log transfer in database
await db.insert("transfers", {
  booking_id: bookingId,
  stripe_transfer_id: transfer.id,
  amount: providerEarningsInCents,
  provider_id: providerId,
  status: transfer.status, // "pending" → "in_transit" → "paid"
  created_at: new Date(),
});
```

**Provider Receives Funds:**
- Automatically deposited to their bank account (1-2 business days)
- Stripe handles all payout logistics
- Yuki only triggers the transfer, doesn't handle funds

---

## 4. Provider Stripe Connect Setup

### Prerequisites
Providers must complete Stripe Connect onboarding:

**During Provider Onboarding:**
1. Collect legal name, SSN, bank account
2. Redirect to Stripe Connect onboarding flow
3. Provider completes identity verification with Stripe
4. Upon completion, receive `stripe_account_id`
5. Store in Yuki database

```javascript
// Step 1: Create Stripe Connected Account
const account = await stripe.accounts.create({
  type: 'express', // simplified experience for service providers
  country: 'US',
  email: providerEmail,
  capabilities: {
    transfers: {requested: true},
  },
});

// Store account ID
await db.update("provider_statuses", {id: providerId}, {
  stripe_account_id: account.id,
  stripe_onboarding_complete: false,
});

// Step 2: Generate Onboarding Link
const onboardingLink = await stripe.accountLinks.create({
  account: account.id,
  type: 'account_onboarding',
  refresh_url: `https://yuki.app/provider/stripe-refresh`,
  return_url: `https://yuki.app/provider/stripe-complete`,
});

// Redirect provider to Stripe for ID verification & bank setup
// App shows: app.stripe.com/...
```

**Upon Completion:**
- Stripe sends webhook confirming identity & payout methods verified
- Yuki marks provider as `stripe_onboarding_complete: true`
- Provider can now accept payments

### Important: Account Restrictions
- **Age verification:** Must be 18+
- **Bank account:** Must be in provider's name
- **Identity verification:** Government ID required
- **No high-risk industries:** Yuki only allows general service work

---

## 5. Dispute & Refund Process

### Customer Initiates Dispute

**Customer reports issue within 48 hours of service completion:**

```javascript
// Customer files dispute
await db.insert("disputes", {
  booking_id: bookingId,
  customer_id: customerId,
  provider_id: providerId,
  reason: "Service not completed / Low quality / No-show",
  description: "Provider did not show up at agreed time",
  evidence: ["photo_url_1", "photo_url_2"], // optional evidence
  status: "open", // Yuki reviews
  created_at: new Date(),
});

// Notify Yuki support team for manual review
sendNotificationToSupport({
  bookingId: bookingId,
  type: "dispute_filed",
  priority: "high", // depends on dispute reason
});
```

### Yuki Support Reviews Dispute

**Yuki team evaluates within 5 business days:**

1. **Review evidence** from both parties
2. **Make decision:** Full refund, partial refund, or deny
3. **Update database**

```javascript
// Decision recorded
await db.update("disputes", {id: disputeId}, {
  status: "resolved",
  decision: "full_refund", // or "partial_refund" or "denied"
  decision_reason: "Provider did not arrive at service location",
  decision_by: supportStaffName,
  decided_at: new Date(),
});
```

### Refund Mechanics

**If full refund approved:**

```javascript
const refund = await stripe.refunds.create({
  charge: stripeChargeId, // original charge
  reason: 'customer_request', // Stripe reason code
  metadata: {
    disputeId: disputeId,
    decision: 'full_refund',
  },
});

// Update payment status
await db.update("payments", {stripe_charge_id: stripeChargeId}, {
  status: "refunded",
  refund_id: refund.id,
  refunded_at: new Date(),
});

// Cancel/reverse provider transfer
if (transfer exists) {
  await stripe.transfers.createReversal(transferId, {
    metadata: {disputeId: disputeId},
  });
}

// Notify both parties
sendNotification(customerId, "Refund approved and processed.");
sendNotification(providerId, "Disputed transaction reversed. Funds returned to customer.");
```

**If partial refund approved:**

```javascript
// Example: 50% refund for low-quality work
const refundAmount = originalAmount * 0.5;
const refund = await stripe.refunds.create({
  charge: stripeChargeId,
  amount: refundAmount, // only partial
  reason: 'partial_refund_for_poor_service',
  metadata: {disputeId: disputeId},
});

// Provider keeps partial payment
// Update provider transfer to reduced amount
```

---

## 6. Database Schema (Payments-Related Tables)

```sql
-- Payments Table
CREATE TABLE payments (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  booking_id UUID NOT NULL REFERENCES booking_requests(id),
  customer_id UUID NOT NULL REFERENCES profiles(id),
  provider_id UUID NOT NULL REFERENCES profiles(id),
  
  -- Stripe references
  stripe_payment_intent_id TEXT NOT NULL UNIQUE,
  stripe_charge_id TEXT,
  stripe_customer_id TEXT,
  
  amount_cents INTEGER NOT NULL, -- $25.00 = 2500
  status TEXT NOT NULL CHECK (status IN ('pending', 'succeeded', 'failed', 'refunded')),
  failure_reason TEXT,
  
  -- Tracking
  created_at TIMESTAMP DEFAULT NOW(),
  completed_at TIMESTAMP,
  refunded_at TIMESTAMP,
  
  metadata JSONB -- custom data
);

-- Transfers Table (Provider Payouts)
CREATE TABLE transfers (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  booking_id UUID NOT NULL REFERENCES booking_requests(id),
  payment_id UUID NOT NULL REFERENCES payments(id),
  provider_id UUID NOT NULL REFERENCES profiles(id),
  
  -- Stripe references
  stripe_transfer_id TEXT NOT NULL UNIQUE,
  stripe_account_id TEXT NOT NULL,
  
  amount_cents INTEGER NOT NULL, -- after Yuki fees
  yuki_fee_cents INTEGER NOT NULL,
  status TEXT NOT NULL CHECK (status IN ('pending', 'in_transit', 'paid', 'failed')),
  
  -- Tracking
  created_at TIMESTAMP DEFAULT NOW(),
  paid_at TIMESTAMP,
  
  FOREIGN KEY (stripe_account_id) REFERENCES provider_statuses(stripe_account_id)
);

-- Disputes Table
CREATE TABLE disputes (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  booking_id UUID NOT NULL REFERENCES booking_requests(id),
  payment_id UUID NOT NULL REFERENCES payments(id),
  customer_id UUID NOT NULL REFERENCES profiles(id),
  provider_id UUID NOT NULL REFERENCES profiles(id),
  
  reason TEXT NOT NULL,
  description TEXT NOT NULL,
  evidence TEXT[], -- array of attachment URLs
  
  status TEXT NOT NULL CHECK (status IN ('open', 'under_review', 'resolved')),
  decision TEXT CHECK (decision IN ('full_refund', 'partial_refund', 'denied')),
  decision_reason TEXT,
  decision_by TEXT, -- support staff member
  
  created_at TIMESTAMP DEFAULT NOW(),
  decided_at TIMESTAMP
);

-- Indexes for fast queries
CREATE INDEX idx_payments_booking ON payments(booking_id);
CREATE INDEX idx_payments_customer ON payments(customer_id);
CREATE INDEX idx_payments_status ON payments(status);
CREATE INDEX idx_transfers_provider ON transfers(provider_id);
CREATE INDEX idx_disputes_booking ON disputes(booking_id);
CREATE INDEX idx_disputes_status ON disputes(status);
```

---

## 7. Fee Structure & Calculations

### Customer Pays
- **Service amount:** $X.XX (set by Provider)
- **Yuki fee:** 10% of service amount
- **Total charged:** Service + Fee

**Example:** $25 service
```
Service:    $25.00
Yuki fee:   $2.50 (10%)
Total:      $27.50 (charged to customer)
```

### Provider Receives
- **Gross amount charged to customer:** $27.50
- **Minus Yuki fee (10%):** -$2.50
- **Provider receives:** $25.00
- **Plus Stripe processing fee:** -$0.74 (2.9% + $0.30)
- **Provider nets:** $24.26

**Provider can see:**
- Gross amount due
- Breakdown of fees
- Net amount they'll receive
- **Before** they accept the booking

### Fee Transparency
Display in app:
```
Service:           $25.00
Yuki platform fee: -$2.50  (10%)
Processing fee:    -$0.74  (2.9% + $0.30)
Provider receives: $21.76

You will be charged: $27.50
```

---

## 8. Security Best Practices

### Server-Side
✅ **DO:**
- Use Stripe secret key (server-side only, never expose)
- Verify webhook signatures
- Use idempotency keys for all API calls
- Log all payment events (for audit)
- Validate all customer inputs server-side
- Use HTTPS everywhere
- Rate-limit payment endpoints

❌ **DON'T:**
- Store credit card numbers (even encrypted)
- Store CVV/CVC codes
- Log sensitive payment data
- Share Stripe secret key in code/git
- Process payments on mobile (always use server)
- Trust client-side payment validation

### Frontend
✅ **DO:**
- Use Stripe's official SDK
- Show payment sheet for secure card entry
- Request card data ONLY through Stripe UI
- Store only PaymentMethod IDs (tokens)
- Implement SSL/HTTPS

❌ **DON'T:**
- Build custom card input fields
- Store card numbers locally
- Request full card data from users
- Use third-party payment libraries (unofficial)

### Environment Variables (Server)
```bash
# .env (NEVER commit this file)
STRIPE_SECRET_KEY=sk_live_...
STRIPE_WEBHOOK_SECRET=whsec_...
STRIPE_PUBLISHABLE_KEY=pk_live_...
```

### Webhook Verification
Always verify webhook signatures:
```javascript
const sig = req.headers['stripe-signature'];
const event = stripe.webhooks.constructEvent(
  req.body,
  sig,
  process.env.STRIPE_WEBHOOK_SECRET
);
```

---

## 9. Testing Payments Safely

### Stripe Test Mode

**Use test keys during development:**
```bash
STRIPE_SECRET_KEY=sk_test_...
STRIPE_PUBLISHABLE_KEY=pk_test_...
```

**Test cards (always decline on live):**
- Visa Success: `4242 4242 4242 4242`
- Visa Decline: `4000 0000 0000 0002`
- Amex: `3782 822463 10005`

**Never use real cards in development.**

### Testing Webhooks Locally
Use Stripe CLI to forward webhooks:
```bash
stripe listen --forward-to localhost:3000/webhooks/stripe
stripe trigger payment_intent.succeeded
```

---

## 10. Compliance & Certification

### PCI-DSS Compliance
- ✅ Yuki is Level 1 PCI-DSS compliant (via Stripe)
- ✅ No payment card data stored by Yuki
- ✅ All transmission encrypted (HTTPS)
- ✅ Annual security audit required

### Stripe Compliance
- ✅ Stripe is PCI-DSS Level 1 certified
- ✅ ISO 27001 certified
- ✅ SOC 2 Type II compliant
- ✅ Covered by PCI Safe Harbor

### Documentation Required
- Payment processing procedures (this document)
- Regular security audits (quarterly)
- Incident response plan
- Webhook logging & monitoring

---

## 11. Incident Response

### If Payment Processing Fails
1. Check Stripe status page (stripe.com/status)
2. Retry failed payments within 24 hours
3. Notify customers of delays
4. After 24 hours, refund and cancel booking

### If Stripe Account Is Compromised
1. Immediately deactivate secret key
2. Generate new keys
3. Update environment variables
4. Rotate access tokens
5. Contact Stripe support

### If Webhook Delivery Fails
- Stripe retries webhooks for 3 days
- Manually check payment status if webhook fails
- Implement fallback: query Stripe API for pending transactions
- Update manual records

---

## 12. Monitoring & Alerts

### Metrics to Track
- Payment success rate (target: >99%)
- Average payment processing time
- Dispute rate (target: <1%)
- Failed webhook deliveries
- Customer refund requests

### Alert Thresholds
- ⚠️ Success rate < 95%: Investigate
- ⚠️ Dispute rate > 2%: Review provider quality
- ⚠️ Failed webhooks: Manual retry required
- 🚨 Stripe account locked: Urgent action

---

## 13. Timeline for Implementation

**Month 1** (Current): Architecture & design (this document)  
**Month 2**: Backend Stripe integration & webhooks  
**Month 3**: Frontend payment UI & testing  
**Month 4**: Live deployment with monitoring  

---

## Summary

Yuki's payment architecture is **simple, secure, and proven:**
1. Customer → Stripe (payment)
2. Stripe → Yuki (webhook confirmation)
3. Yuki → Provider (transfer after dispute window)
4. **Zero payment card data stored by Yuki**
5. **Full PCI-DSS compliance**
6. **Built-in fraud detection**
7. **Dispute resolution framework**

This design prioritizes customer safety, provider trust, and Yuki's legal protection.

---

**Next Steps:**
- Review with a tax professional (1099 reporting)
- Consult with a lawyer (Stripe ToS compliance)
- Set up Stripe sandbox account
- Begin backend implementation in Month 2
