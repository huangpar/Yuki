# Yuki - Privacy Policy

**Effective Date: September 8, 2026**
**Last Updated: September 8, 2026**

## 1. Introduction & Commitment to Privacy

Yuki ("we," "us," "our," or "Company") is committed to protecting your privacy. This Privacy Policy explains how we collect, use, disclose, and safeguard your information when you use our Service.

**Service:** Yuki is a services marketplace platform operating in Sumner and Auburn, Washington.

**Data Controller:** [Your Business Legal Name]  
**Contact:** [privacy@yuki.app]

Please read this policy carefully. If you do not agree with our practices, please do not use Yuki.

## 2. Information We Collect

### 2.1 Information You Provide Directly

#### Account Registration
- Name (legal name)
- Email address
- Phone number
- Password (hashed, not stored in plain text)
- Role (Customer or Provider)
- Address (service area verification)

#### For Providers Only
- Government-issued ID (for identity verification)
- Social Security Number (for tax reporting and background checks)
- Bank account information (via Stripe Connect)
- Service descriptions and availability schedule
- Photo/profile picture (optional)
- Business license information (if applicable)

#### For Customers Only
- Payment method information (credit/debit card - **processed by Stripe, not stored by Yuki**)
- Billing address
- Service request details

#### Communication
- Messages between Customers and Providers (stored for dispute resolution)
- Support tickets and correspondence with Yuki
- Feedback and reviews

### 2.2 Information Collected Automatically

#### Location Data
- **For Providers:** Real-time GPS location when "Available Now" is activated
  - Used to: Display nearby Providers to Customers within 5-mile radius
  - Retention: Deleted when Provider goes offline
  - Frequency: Updated every 60 seconds while available
- **For Customers:** Location when requesting service
  - Used to: Show nearby available Providers
  - Retention: Deleted 48 hours after service completion
  - **You can deny location permission—Yuki will show only nearby Providers**

#### Device Information
- Device type, operating system, and version
- Mobile device ID (IDFA on iOS, Android Advertising ID on Android)
- IP address
- App version
- Crash reports and error logs

#### Usage Information
- Features accessed
- Services viewed and booked
- Pages viewed and time spent
- Searches performed
- Ratings and reviews submitted
- Transaction history (dates, amounts, Providers used)

#### Cookies & Similar Technologies
- Analytics cookies (Google Analytics) - tracks behavior to improve Yuki
- Session cookies - keep you logged in
- Preference cookies - remember your settings
- **You can control cookies** via browser settings (cookies prevent auto-logout)

### 2.3 Information from Third Parties

#### Background Check Service (Checkr)
- Criminal history
- Sex offender registry status
- Driving record (if Provider)
- Fraud and sanctions databases
- **Used only for** Provider verification before account activation
- **Stored for** 7 years (compliance requirement)

#### Payment Processor (Stripe)
- Transaction confirmations
- Fraud detection signals
- Payment success/failure status
- **Yuki never sees:** Full credit card numbers (tokenized by Stripe)

#### Public Records
- Licensing verification (if applicable)
- Court records (background check)

## 3. How We Use Your Information

### For All Users
- **Account management** - verify identity, manage access
- **Service delivery** - facilitate bookings, payments, communication
- **Legal compliance** - tax reporting (1099s for Providers), fraud prevention
- **Customer support** - respond to inquiries
- **Safety & security** - detect fraud, prevent illegal activity
- **Communication** - send account updates, policy changes, promotions (opt-out available)
- **Analytics** - improve app features and performance (anonymized data only)
- **Dispute resolution** - review complaints and refund requests

### For Providers Specifically
- **Background verification** - ensure safety and compliance
- **Location tracking** - show your availability to Customers
- **Payment processing** - transfer earnings to your bank account
- **Tax reporting** - generate 1099 forms
- **Compliance** - verify ongoing eligibility to provide services

### For Customers Specifically
- **Provider matching** - show nearby available Providers
- **Booking management** - create and track service requests
- **Payment processing** - charge for services completed
- **Service quality** - collect feedback and reviews

## 4. Data Sharing & Disclosure

### We Do NOT Sell Your Data

**Yuki does not sell, rent, or trade your personal data to third parties for marketing purposes.**

### Data Shared With Third Parties (Required for Service)

#### Stripe (Payment Processing)
- **Shares:** Name, email, phone, billing address, payment method, transaction history
- **Purpose:** Payment processing, fraud detection, 1099 reporting
- **Protection:** PCI-DSS Level 1 compliance; encrypted transmission
- **Your rights:** Stripe's Privacy Policy covers their processing

#### Checkr (Background Checks) - *Providers Only*
- **Shares:** Name, SSN, address, ID information
- **Purpose:** Background verification
- **Protection:** FCRA-compliant processing
- **Your rights:** Right to dispute adverse decisions; see Section 7

#### Supabase (Database Host)
- **Shares:** All encrypted user data
- **Purpose:** Data storage and retrieval
- **Protection:** Encrypted at rest and in transit
- **Location:** US-based servers

#### Google Analytics
- **Shares:** Anonymized usage data (no PII)
- **Purpose:** App analytics and improvement
- **Protection:** Data is aggregated and anonymized
- **Opt-out:** Disable analytics in app settings

### Data Shared Between Users
- **Customers see:** Provider name, profile picture, ratings, response time
- **Providers see:** Customer name, location, service request details, rating
- **Messages:** Stored and visible to both parties for 90 days

### Legal Obligations
We may disclose your information if required by law:
- Law enforcement requests (with warrant)
- Court orders
- Government investigations
- Prevention of fraud or criminal activity
- Enforcement of these Terms

**We will notify you of legal requests unless legally prohibited.**

## 5. Data Retention

| Data Type | Retention Period | Reason |
|---|---|---|
| Account information | Duration of account + 1 year | Tax, audit, compliance |
| Payment records | 7 years | Tax reporting, dispute resolution |
| Location data (active) | While available | Real-time matching |
| Location data (historical) | 48 hours after service | Dispute resolution |
| Messages | 90 days | Dispute resolution |
| Background checks | 7 years | FCRA compliance |
| Support tickets | 2 years | Legal protection |
| Cookies | Session duration | User preference |
| Server logs | 30 days | Security monitoring |
| Analytics data | 13 months | Google's retention |

**After retention period:** Data is securely deleted or anonymized.

**Your right to deletion:** Submit a "data deletion request" in Settings → Privacy. Yuki will delete non-essential data within 30 days, except where legally required to retain (tax records, dispute records, legal holds).

## 6. Data Security

### How We Protect Your Data
- **Encryption:** All data transmitted via HTTPS (TLS 1.3)
- **Password security:** Passwords are hashed using bcrypt (one-way encryption)
- **Payment security:** Handled by PCI-DSS Level 1 compliant Stripe
- **Access controls:** Only authorized employees access your data
- **Background checks:** Not stored locally; accessed from Checkr's servers
- **Regular audits:** Quarterly security reviews

### What We Don't Do
- We don't store full credit card numbers (Stripe handles that)
- We don't store passwords in plaintext
- We don't share unencrypted data with third parties
- We don't have direct access to background check records (access via Checkr API only)

### Your Responsibility
- Keep your password secure and unique
- Don't share your login credentials
- Enable two-factor authentication (coming soon)
- Report suspicious account activity immediately

### Data Breach Notification
If your data is compromised, Yuki will notify you within **30 days** via email with:
- What data was involved
- Likely impact
- Steps we're taking to fix it
- Resources available to you (credit monitoring, etc.)

## 7. Your Privacy Rights

### Access Your Data
- **Right:** View, download, or export your personal data
- **How:** Settings → Privacy → Download My Data
- **Timeline:** Within 30 days

### Correct Your Data
- **Right:** Update or correct inaccurate information
- **How:** Update your profile or contact support
- **Timeline:** Changes reflected within 24 hours

### Delete Your Data
- **Right:** Request deletion of non-essential data
- **How:** Settings → Privacy → Delete My Account
- **Timeline:** Within 30 days
- **Exceptions:** Tax records, dispute records, legal holds

### Restrict Processing
- **Right:** Limit how we use your data
- **How:** Contact privacy@yuki.app
- **Example:** "Only use my data for service delivery, not analytics"

### Data Portability
- **Right:** Receive your data in portable format (JSON/CSV)
- **How:** Settings → Privacy → Export Data
- **Timeline:** Within 30 days

### Opt-Out of Marketing
- **Right:** Stop receiving promotional emails
- **How:** Click "Unsubscribe" on any marketing email
- **Timeline:** Immediate
- **Note:** You will still receive service updates and legal notices

### Background Check Dispute (FCRA)
**For Providers:** If you're rejected or restricted due to a background check:
- **Right:** Review the findings and dispute inaccuracies
- **How:** Contact Checkr directly via Yuki's app (link provided)
- **Timeline:** Checkr has 5 business days to investigate
- **Outcome:** Yuki will reconsider your account status with updated results

## 8. Location Data Specifics

### Provider Location Tracking

**When you mark "Available Now":**
- Your real-time GPS location is transmitted to Yuki every 60 seconds
- Location is visible ONLY to Customers searching within 5 miles
- Location is NOT stored permanently
- Location is deleted when you go offline

**You can control this:**
- Turn off "Available Now" at any time (location transmission stops immediately)
- Deny location permission in device settings (Yuki will not function for Providers without location)
- Request location history deletion (see Data Access section)

**Privacy note:** Your home/personal address is NOT visible to Customers. Only general service area and real-time proximity appear.

### Customer Location Privacy

**When you request a service:**
- Your location is visible ONLY to the Provider you book
- Location is shared 15 minutes before Provider arrives (pickup/arrival)
- Location is deleted 48 hours after service completion
- You can share a different location (e.g., workplace instead of home)

## 9. Children's Privacy

Yuki is **NOT intended for users under 18 years old**. We do not knowingly collect information from children. If we discover we've collected data from someone under 18, we will delete it immediately.

**Guardians:** If your child has created an account, please contact us to have it removed.

## 10. Third-Party Links & Services

Yuki may link to external websites (e.g., Stripe, Checkr). We are NOT responsible for their privacy practices. Review their policies before sharing information:
- **Stripe Privacy Policy:** stripe.com/privacy
- **Checkr Privacy Policy:** checkr.com/privacy
- **Google Analytics Privacy:** policies.google.com/privacy

## 11. International Data Transfers

Yuki operates in the United States (Washington state). Your data is stored on US servers. If you access Yuki from outside the US, you consent to data being transferred to and processed in the US under US laws.

**EU Users (GDPR):** We comply with GDPR requirements including data processing agreements. Your legal basis for processing is "contract performance" (service delivery) and "legitimate interests" (fraud prevention, compliance).

## 12. Your State-Specific Rights

### California (CCPA & CPRA)
You have the right to:
- Know what personal information is collected
- Delete personal information
- Opt-out of data sales (we don't sell data, so this doesn't apply)
- Correct inaccurate information
- Limit use of sensitive information
- Non-discrimination for exercising rights

**To exercise:** Contact privacy@yuki.app with "CCPA Request" in subject line. We'll respond within 45 days.

### Washington Privacy Act (WPA)
Similar rights to CCPA. Contact privacy@yuki.app to exercise your rights.

### Other States
Yuki complies with all applicable state privacy laws. Contact us to exercise your rights under your state's law.

## 13. Cookies & Tracking

### Types of Cookies Yuki Uses

| Cookie | Purpose | Duration | Opt-Out |
|---|---|---|---|
| Session Cookie | Keep you logged in | Session (24 hours) | Clear cookies to log out |
| Analytics (Google) | Track app usage and improvements | 13 months | Settings → Analytics |
| Preference Cookie | Remember your settings | 1 year | Clear browser cookies |
| Fraud Prevention | Detect unauthorized access | Session | N/A (security essential) |

### Third-Party Cookies
- **Google Analytics** - tracks general usage (aggregated, not personally identifying)
- **Stripe** - fraud detection cookies

### Opt-Out
- Disable analytics in app Settings
- Clear cookies in your browser
- Opt-out of Google Analytics: tools.google.com/dlpage/gaoptout

**Note:** Clearing cookies may cause you to be logged out and affect Yuki's functionality.

## 14. Policy Changes

Yuki may update this Privacy Policy at any time. Changes are effective when posted. For material changes (how we use data, retention periods, sharing practices), we'll:
1. Email you **30 days before** the change
2. Post a notice in-app
3. Require your consent (if required by law)

Your continued use after changes means you accept the new policy.

## 15. Contact & Complaints

### Questions About Privacy
**Email:** privacy@yuki.app  
**Mailing Address:** [Your Business Address, Sumner, WA]  
**Phone:** [Support Number]  
**Response time:** Within 10 business days

### File a Complaint
If you believe Yuki has violated your privacy rights:

1. **Contact Yuki first:** privacy@yuki.app (we'll respond within 30 days)
2. **File with your state:** Attorneys General in your state can investigate
3. **California residents:** California Attorney General, atg.ca.gov

### GDPR Complaints (EU Users)
File with your local Data Protection Authority if we don't resolve your concern.

## 16. Automated Decision-Making & Profiling

### Background Check Decisions
Yuki uses automated tools (Checkr's algorithms) to assess background check results. These are NOT fully automated decisions—a human reviews and approves rejections.

**Your right:** Request human review of any background check decision. Contact support@yuki.app with "Background Check Appeal" in the subject line.

### Payment Fraud Detection
Yuki uses Stripe's automated fraud detection. If a transaction is flagged:
1. You'll be notified
2. Your account may be temporarily frozen
3. You can contact support to dispute

### Provider Recommendations
Yuki does not use algorithmic profiling or automated pricing decisions. Customers choose Providers manually based on ratings and availability.

## 17. Compliance Certifications

- **PCI-DSS Level 1** (Stripe, payment processing)
- **FCRA Compliant** (background checks via Checkr)
- **GDPR Compliant** (EU data protection)
- **CCPA Compliant** (California privacy)
- **SOC 2 Type II** (Supabase, data hosting)

## 18. Your Acknowledgment

By using Yuki, you acknowledge:
1. You've read and understand this Privacy Policy
2. You consent to data collection and processing as described
3. You understand your rights and how to exercise them
4. You accept data transfers and third-party processing

---

## Questions?

**We're here to help:** privacy@yuki.app

Yuki takes privacy seriously. If something isn't clear, ask us before using the Service.

---

**Last updated:** September 8, 2026  
**Effective:** Immediately upon acceptance
