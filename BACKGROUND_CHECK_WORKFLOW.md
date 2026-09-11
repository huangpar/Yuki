# Yuki Background Check Workflow & FCRA Compliance

**Purpose:** Define how Yuki vets providers safely, legally, and fairly.

**Regulatory Framework:** Fair Credit Reporting Act (FCRA) + Washington State Fair Hiring Practices

**Third-Party Service:** Checkr (background screening company)

---

## 1. Why Background Checks Matter for Yuki

### For Customers
- Peace of mind that providers entering their homes are vetted
- Reduces risk of theft, fraud, or harm
- Establishes trust in the platform

### For Yuki
- Legal liability protection (negligent hiring claims)
- Reduces fraud and criminal activity on platform
- Competitive advantage (verified providers)
- Insurance requirements (most policies require checks)

### For Providers
- Fair, transparent vetting process
- Right to dispute inaccurate results
- Access to dispute resolution
- Clear criteria for acceptance/rejection

---

## 2. FCRA Compliance Requirements

### What is the FCRA?
The Fair Credit Reporting Act is a federal law protecting individuals from unfair, inaccurate, or incomplete information in background checks.

### Yuki's Key Obligations

**1. Clear Disclosure (Before Check)**
- Inform Provider that a background check will be conducted
- Explain what information will be checked
- Get written consent (in-app checkbox)
- List the purpose: "To verify provider eligibility and ensure customer safety"

**2. Accuracy**
- Use reputable, certified background check provider (Checkr)
- Only consider information relevant to the role
- Don't use outdated information (7-year rule)
- Verify results before making decisions

**3. Adverse Action Notice (If Rejected)**
- Notify provider within **5 business days** if background check results lead to rejection
- Provide:
  - Copy of background report
  - Copy of FCRA rights document
  - Reason for rejection
  - Appeal process
- **Tone:** Professional, non-judgmental

**4. Right to Dispute**
- Provider must have **30+ days** to dispute inaccurate information
- Must reinvestigate provider's claim
- Update results if dispute is valid
- Notify provider of outcome

**5. Timing Rules**
- Can't use background info older than 7 years (with exceptions for felonies)
- Report updates should reflect current status
- Disputes must be investigated within 30 days

---

## 3. Provider Background Check Process

### Phase 1: Signup & Disclosure

**Step 1: Provider Enters Basic Info**
- Name, email, phone, address
- Service area preference
- Service categories (cleaning, repairs, tutoring, etc.)

**Step 2: Disclosure & Consent**

Display in-app:

```
🛡️ Provider Verification

To keep Yuki safe for customers, all providers must pass a background check.

We will check:
✓ Criminal history (7-year lookback)
✓ Sex offender registry
✓ Fraud/sanctions databases
✓ Identity verification

This check is required to use Yuki.
By proceeding, you consent to this background check.

[I Understand & Agree] [Cancel]
```

**What gets stored:** Consent timestamp, consent version

### Phase 2: Identity Verification

**Step 3: Government ID Verification**

Provider uploads:
- Government-issued ID (driver's license, passport)
- Proof of residence (utility bill, lease)
- Verification of identity (Checkr handles this)

```json
{
  "first_name": "John",
  "last_name": "Smith",
  "date_of_birth": "1990-01-15",
  "ssn": "xxx-xx-1234", // partial display only
  "email": "john@example.com",
  "phone": "+1-206-555-1234",
  "address": {
    "street": "123 Main St",
    "city": "Sumner",
    "state": "WA",
    "zip": "98390"
  },
  "id_type": "drivers_license",
  "id_state": "WA",
  "id_number": "xxxxxxx1234"
}
```

**Checkr sends verification link to provider's email.**

### Phase 3: Checkr Background Check

**Step 4: Initiate Checkr Package**

```javascript
// Node.js backend: Create Checkr candidate
const checkr = require('checkr')(process.env.CHECKR_API_KEY);

const candidate = await checkr.candidates.create({
  first_name: provider.first_name,
  last_name: provider.last_name,
  email: provider.email,
  phone: provider.phone,
  date_of_birth: provider.dob,
  ssn: provider.ssn,
  driver_license_number: provider.dl_number,
  driver_license_state: provider.dl_state,
  // ... other fields
  custom_id: provider_id, // link to Yuki provider
});

// Store Checkr candidate ID in Yuki database
await db.update("provider_statuses", {id: provider_id}, {
  checkr_candidate_id: candidate.id,
  background_check_status: 'pending',
  background_check_started_at: new Date(),
});

// Send provider email: "Click to complete verification"
```

**What Checkr checks:**
- Criminal history (7 years for misdemeanors, unlimited for felonies)
- Sex offender registry (national + state databases)
- OFAC/Sanctions lists (fraud/financial crimes)
- Driving record (if relevant)
- Civil judgments (lawsuits, collections)
- Employment verification (optional - Yuki doesn't use)

**Timeline:** 1-3 business days for report completion

### Phase 4: Checkr Report Completion

**Step 5: Checkr Webhook Notification**

When Checkr completes the report:

```javascript
// POST /webhooks/checkr
app.post('/webhooks/checkr', async (req, res) => {
  const event = req.body;
  
  if (event.type === 'report.completed') {
    const report = event.data.object;
    const providerId = report.custom_id; // Yuki provider ID
    
    // Determine result
    const backgroundStatus = report.result === 'clear' ? 'clear' : 'failed';
    
    // Store result in database
    await db.update("provider_statuses", {id: providerId}, {
      checkr_candidate_id: report.candidate_id,
      background_check_status: backgroundStatus,
      background_check_completed_at: new Date(),
      background_check_details: {
        report_id: report.id,
        result: report.result, // clear, consider, suspended, adverse
        packages: report.packages, // which screenings were included
        consider_reasons: report.consider_reasons, // if applicable
      },
    });
    
    // Notify provider
    if (backgroundStatus === 'clear') {
      // Activation email (see Phase 5)
      sendActivationEmail(providerId);
    } else {
      // Adverse action notice (see Phase 6)
      sendAdverseActionNotice(providerId);
    }
  }
  
  res.json({received: true});
});
```

---

## 4. Approval & Activation (Clear Reports)

### Phase 5: Provider Approval

**If Result = "Clear":**

```javascript
// Update provider status
await db.update("provider_statuses", {id: providerId}, {
  is_verified_for_work: true,
  verification_completed_at: new Date(),
  verification_status: 'approved',
});

// Send approval email to provider
const email = {
  to: provider.email,
  subject: "✅ Your Yuki Provider Profile is Approved!",
  template: 'provider_approved',
  data: {
    provider_name: provider.first_name,
    next_step: "Set up your availability and start accepting bookings",
    action_url: "https://yuki.app/provider/setup-availability"
  }
};

await emailService.send(email);
```

**What provider sees in app:**
- ✅ "Background check passed"
- "You're approved to accept services!"
- Button: "Set Up Your Availability"
- Link: "View your background check results"

**Provider can now:**
- Activate "Available Now" status
- Start accepting customer requests
- Withdraw earnings

---

## 5. Rejection & Adverse Action (Unfavorable Reports)

### Phase 6: Adverse Action Notice

**If Result = "Consider" or "Adverse":**

Yuki MUST notify provider within **5 business days** with:
1. Copy of the background report
2. FCRA rights notice
3. Reason for rejection
4. How to dispute

```javascript
// Send adverse action notice
const adverseNotice = {
  to: provider.email,
  subject: "Your Yuki Provider Background Check - Action Required",
  template: 'adverse_action_notice',
  data: {
    provider_name: provider.first_name,
    reason: backgroundCheckDetails.consider_reasons[0],
    // e.g., "Misdemeanor conviction from 2019"
    
    report_excerpt: backgroundCheckDetails.findings,
    // Summary of concerning findings
    
    rights_link: "https://yuki.app/provider/fcra-rights",
    dispute_link: "https://yuki.app/provider/dispute-background-check",
    support_email: "support@yuki.app",
    dispute_deadline: addDays(new Date(), 30),
  }
};

await emailService.send(adverseNotice);

// Log the notice
await db.insert("adverse_actions", {
  provider_id: providerId,
  reason: backgroundCheckDetails.consider_reasons,
  notice_sent_at: new Date(),
  dispute_deadline: addDays(new Date(), 30),
  status: 'pending_response',
});
```

**What provider sees in app:**
- ⚠️ "Background check requires review"
- Reason (e.g., "Misdemeanor conviction found")
- "You have 30 days to dispute this decision"
- Button: "View my background report"
- Button: "File a dispute"

### Important: Don't Blacklist Automatically

**Yuki's Approach:**
- Don't auto-reject based solely on report findings
- Review each case individually
- Consider:
  - Severity of finding (felony vs misdemeanor)
  - Time elapsed (recent vs old)
  - Relevance to role (theft conviction = concerning, old parking ticket = irrelevant)
  - Rehabilitation evidence (if provider provides it)

**Example Decision Tree:**

```
Finding: Misdemeanor theft conviction from 2015 (8 years ago)

Yuki's Review:
✓ Type: Theft (relevant to home services)
✓ Age: 8 years old (outside 7-year FCRA window, but still noted)
✓ Pattern: Single incident or multiple convictions?
✓ Rehabilitation: Any evidence of rehabilitation?

Decision Options:
1. CLEAR: If single incident, long time ago → approve with monitoring
2. REJECT: If repeated fraud/theft pattern → adverse action
3. REVIEW: If borderline → request additional evidence from provider

Approach: Bias toward opportunity + monitoring (fair chance hiring)
```

---

## 6. Dispute Process (Provider Rights)

### Phase 7: Provider Initiates Dispute

**Provider clicks "File a Dispute":**

```html
<!-- In-app dispute form -->
<form>
  <h3>Dispute Your Background Check Results</h3>
  
  <p>You have 30 days from the notice to dispute inaccuracies.</p>
  
  <textarea 
    placeholder="Explain why the information is inaccurate or needs correction..."
    maxlength="2000"
  />
  
  <file-upload label="Upload evidence (optional)" />
  
  <button>Submit Dispute</button>
</form>
```

**What gets stored:**

```javascript
await db.insert("disputes", {
  provider_id: providerId,
  adverse_action_id: adverseActionId,
  dispute_reason: "The theft conviction listed is for my brother, not me. We have the same name.",
  evidence_urls: ["url_to_court_document.pdf"],
  status: 'submitted',
  submitted_at: new Date(),
  deadline: new Date(30 * 24 * 60 * 60 * 1000), // 30 days
});

// Notify Yuki support
notifySupport({
  type: 'background_check_dispute_filed',
  provider_id: providerId,
  priority: 'high',
});
```

### Phase 8: Yuki Investigates Dispute

**Yuki support team reviews:**
1. Read provider's explanation
2. Review provided evidence
3. **Contact Checkr to reinvestigate** (if needed)
4. Make determination

```javascript
// If dispute is valid:
const updatedReport = await checkr.candidates.retrieve(
  candidate.id,
  {include_all_findings: true}
);

// If Checkr confirms inaccuracy:
await db.update("provider_statuses", {id: providerId}, {
  background_check_status: 'clear', // Updated to clear
  background_check_details: {
    ...oldDetails,
    dispute_resolved: true,
    dispute_outcome: 'inaccuracy_corrected',
    corrected_at: new Date(),
  },
});

// Notify provider
sendEmail({
  to: provider.email,
  subject: "✅ Your Dispute Was Successful!",
  body: "We've investigated and corrected the inaccuracy. You're now approved.",
});

// Activate account
await db.update("provider_statuses", {id: providerId}, {
  is_verified_for_work: true,
});
```

**Timeline:**
- Yuki investigates: 5-10 business days
- Checkr reinvestigates: 3-5 business days
- Total: 10-15 business days
- Provider notified of outcome

---

## 7. Database Schema

```sql
-- Provider Statuses (with background check fields)
CREATE TABLE provider_statuses (
  id UUID PRIMARY KEY REFERENCES profiles(id),
  
  -- Background check tracking
  checkr_candidate_id TEXT UNIQUE,
  background_check_status TEXT CHECK (background_check_status IN (
    'not_started',
    'pending',
    'clear',
    'failed',
    'under_review',
    'disputed'
  )),
  background_check_started_at TIMESTAMP,
  background_check_completed_at TIMESTAMP,
  background_check_expires_at TIMESTAMP, -- re-check annually
  
  -- Findings detail
  background_check_details JSONB, -- {report_id, result, consider_reasons, ...}
  
  -- Verification status
  is_verified_for_work BOOLEAN DEFAULT false,
  verification_completed_at TIMESTAMP,
  verification_status TEXT, -- 'approved' or 'rejected'
  
  -- Soft suspension (for re-check or review)
  suspended_reason TEXT,
  suspended_at TIMESTAMP,
  suspended_until TIMESTAMP
);

-- Adverse Actions (FCRA notifications)
CREATE TABLE adverse_actions (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  provider_id UUID NOT NULL REFERENCES provider_statuses(id),
  reason TEXT[] NOT NULL, -- array of reasons
  notice_sent_at TIMESTAMP NOT NULL,
  dispute_deadline TIMESTAMP NOT NULL,
  status TEXT CHECK (status IN ('pending_response', 'disputed', 'resolved', 'expired')),
  created_at TIMESTAMP DEFAULT NOW()
);

-- Disputes
CREATE TABLE disputes (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  provider_id UUID NOT NULL REFERENCES provider_statuses(id),
  adverse_action_id UUID NOT NULL REFERENCES adverse_actions(id),
  dispute_reason TEXT NOT NULL,
  evidence_urls TEXT[],
  status TEXT CHECK (status IN ('submitted', 'investigating', 'resolved')),
  submitted_at TIMESTAMP NOT NULL,
  resolved_at TIMESTAMP,
  outcome TEXT, -- 'upheld', 'inaccuracy_corrected', 'withdrawn'
  outcome_explanation TEXT,
  created_at TIMESTAMP DEFAULT NOW()
);

-- Audit log (for compliance)
CREATE TABLE background_check_audit_log (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  provider_id UUID NOT NULL REFERENCES provider_statuses(id),
  event_type TEXT NOT NULL,
  -- 'consent_given', 'check_started', 'report_received', 'adverse_notice_sent',
  -- 'dispute_filed', 'dispute_resolved', 'provider_activated'
  event_details JSONB,
  created_at TIMESTAMP DEFAULT NOW()
);

-- Indexes for fast queries
CREATE INDEX idx_background_check_status ON provider_statuses(background_check_status);
CREATE INDEX idx_adverse_actions_deadline ON adverse_actions(dispute_deadline);
CREATE INDEX idx_disputes_status ON disputes(status);
```

---

## 8. Timeline & Milestones

```
Day 1: Provider Signs Up
  ↓ Provides consent + ID
Day 2-3: Checkr processes check
  ↓ 1-3 business days
Day 4-5: Result received
  ↓
  ├─→ Clear: Immediate activation ✅
  │
  └─→ Concerns: Adverse action notice sent ⚠️
      ↓ 5 business days (FCRA requirement)
      30-day dispute window opens
      ↓
      Provider may dispute (optional)
      ↓ Yuki investigates (10-15 days)
      ↓
      Final decision: Approved or Rejected

Total time to activation (if clear): 3-5 business days
Total time if disputed: 15-20 business days
```

---

## 9. Re-Checking & Expiration

### Annual Re-Checks

Yuki should conduct annual re-checks for active providers:

```javascript
// Run monthly: Check for providers needing re-check
const providersNeedingRecheck = await db.query(`
  SELECT id FROM provider_statuses
  WHERE background_check_expires_at < NOW()
  AND is_verified_for_work = true
`);

for (const provider of providersNeedingRecheck) {
  // Initiate new Checkr report
  const newReport = await checkr.candidates.create({
    ...providerInfo,
    custom_id: provider.id,
  });
  
  // Notify provider
  sendEmail({
    to: provider.email,
    subject: "Annual Background Check Due",
    body: "Your provider verification expires on [date]. We're conducting an annual re-check.",
  });
}
```

**Re-check Frequency:** Annual (yearly)  
**Cost:** ~$25-50 per re-check (negotiated with Checkr)

---

## 10. Compliance Checklist

### Before Going Live

- [ ] Checkr account created and API integrated
- [ ] Disclosure language reviewed by lawyer
- [ ] FCRA rights document drafted
- [ ] Adverse action notice template finalized
- [ ] Dispute process clearly documented
- [ ] Database schema created and tested
- [ ] Webhooks configured (IP whitelist, signature verification)
- [ ] Email templates drafted and tested
- [ ] Support team trained on dispute process
- [ ] Retention policy set (7 years for records)
- [ ] Privacy policy updated (mentions Checkr, FCRA)
- [ ] Terms of Service updated (background check requirement)
- [ ] Incident response plan (if data breach occurs)

### Ongoing

- [ ] Monthly audit of adverse actions and disputes
- [ ] Quarterly compliance review
- [ ] Annual background check re-verification
- [ ] Maintain detailed audit log for regulatory review
- [ ] Track dispute outcomes and identify patterns

---

## 11. Checkr Integration Details

### API Credentials

```bash
# .env file (NEVER commit)
CHECKR_API_KEY=sk_test_xxxxx
CHECKR_WEBHOOK_SECRET=whsec_xxxxx
```

### Sample Webhook Payload

```json
{
  "id": "evt_1234567890",
  "type": "report.completed",
  "data": {
    "object": {
      "id": "rpt_1234567890",
      "candidate_id": "cand_1234567890",
      "custom_id": "provider-uuid-here",
      "status": "completed",
      "result": "clear", // or "consider", "suspended", "adverse"
      "packages": ["criminal_check", "ofac_check"],
      "consider_reasons": [
        "Misdemeanor conviction: Theft, 2019"
      ],
      "completed_at": "2026-09-10T14:30:00Z"
    }
  }
}
```

### Test Mode

Use test API key during development:
```bash
CHECKR_API_KEY=sk_test_xxxxx # for sandbox
CHECKR_API_KEY=sk_live_xxxxx # for production
```

Test candidates always return results instantly (no waiting 1-3 days).

---

## 12. Cost Analysis

### Checkr Pricing (Estimated)

| Service | Cost | Frequency |
|---------|------|-----------|
| Initial background check | $25-50 | Per provider |
| Annual re-check | $15-30 | Yearly |
| Dispute reinvestigation | $0 | Included |
| API access | $0 | Included |

**First-year cost (100 providers):** $2,500 - $5,000  
**Annual cost (100 providers):** $1,500 - $3,000  

---

## 13. Incident Response

### If Checkr Data is Breached
1. Notify all affected providers within 24 hours
2. Offer credit monitoring (if PII exposed)
3. Document incident for regulatory records
4. Consult with lawyer

### If Provider Disputes Inaccuracy
1. Review their evidence
2. Contact Checkr for reinvestigation
3. Respond within 30 days (FCRA requirement)
4. If corrected, approve immediately
5. If upheld, explain decision clearly

### If Provider Files Complaint with FTC
1. Cooperate fully
2. Provide all records and communications
3. Consult with lawyer immediately

---

## Summary

Yuki's background check process is:
1. **Transparent:** Clear disclosure before check
2. **Fair:** Individual review, bias toward opportunity
3. **Compliant:** Follows FCRA + Washington State laws
4. **Reversible:** Robust dispute process
5. **Documented:** Full audit trail for regulatory review

This approach protects customers, respects providers, and shields Yuki from liability.

---

## Next Steps

1. Set up Checkr account (checkr.com)
2. Negotiate rates (mention volume expectations)
3. Review legal templates with lawyer
4. Implement in backend (Node.js)
5. Test with sandbox account
6. Deploy with monitoring

---

**Month 1 Completion:** Tasks #14 (Legal), #12 (Payment), #15 (Background Checks) ✅

You now have a complete, compliant foundation for Yuki.
