# Yuki UI/UX Mockups

**Version:** 1.0  
**Last Updated:** September 8, 2026  
**Platform:** Flutter Mobile (iOS/Android)  
**Breakpoints:** Mobile-first (375px width)

---

## Overview

This document contains wireframes for key user flows:

**Customer Flows:**
1. Authentication (Signup/Login)
2. Map & Provider Discovery
3. Provider Profile & Booking
4. Payment
5. Active Booking Status
6. Dispute Resolution

**Provider Flows:**
1. Signup & Background Check
2. Profile Setup
3. Availability Toggle
4. Incoming Bookings
5. Complete Booking & Earnings

---

# CUSTOMER FLOWS

## 1. Customer Login Screen

```
┌─────────────────────────────┐
│                             │
│        YUKI 🏠              │
│  Find Services Near You     │
│                             │
├─────────────────────────────┤
│                             │
│  📧 Email                   │
│  ┌───────────────────────┐  │
│  │ john@example.com      │  │
│  └───────────────────────┘  │
│                             │
│  🔑 Password                │
│  ┌───────────────────────┐  │
│  │ ••••••••••••••        │  │
│  └───────────────────────┘  │
│                             │
│  ┌───────────────────────┐  │
│  │   Sign In             │  │
│  └───────────────────────┘  │
│                             │
│  Don't have an account?     │
│  [Sign Up] [Forgot Password]│
│                             │
└─────────────────────────────┘

Key Elements:
• Logo/branding at top
• Email input (prefilled if returning)
• Password input (masked)
• Sign In button (primary action)
• Help links (signup, password reset)
• Selection for Customer/Provider role (if new)
```

**Validation:**
- Email format required
- Password min 8 characters
- Show error toast if login fails

---

## 2. Customer Signup Screen

```
┌─────────────────────────────┐
│  < Back    Create Account   │
├─────────────────────────────┤
│                             │
│  👤 Profile                 │
│  ┌───────────────────────┐  │
│  │ First Name            │  │
│  │ [____________]        │  │
│  └───────────────────────┘  │
│                             │
│  ┌───────────────────────┐  │
│  │ Last Name             │  │
│  │ [____________]        │  │
│  └───────────────────────┘  │
│                             │
│  📧 Email                   │
│  ┌───────────────────────┐  │
│  │ [____________]        │  │
│  └───────────────────────┘  │
│                             │
│  📞 Phone                   │
│  ┌───────────────────────┐  │
│  │ +1 (206) 555-1234    │  │
│  └───────────────────────┘  │
│                             │
│  🔑 Password                │
│  ┌───────────────────────┐  │
│  │ [____________]        │  │
│  └───────────────────────┘  │
│                             │
│  [✓] I agree to Terms      │
│                             │
│  ┌───────────────────────┐  │
│  │   Create Account      │  │
│  └───────────────────────┘  │
│                             │
└─────────────────────────────┘

Key Elements:
• Multi-step: Profile → Address → Role selection
• Real-time email validation
• Phone input with country selector
• Terms checkbox (required)
• Password strength indicator
```

---

## 3. Map & Provider Discovery (HOME SCREEN)

```
┌─────────────────────────────┐
│ YUKI    [Profile] [Menu]    │
├─────────────────────────────┤
│  🔍 Search Services         │
│  ┌───────────────────────┐  │
│  │ What do you need?     │  │
│  └───────────────────────┘  │
│                             │
│  📍 Use My Location [Enable]│
│                             │
├─────────────────────────────┤
│  🗺️  MAP VIEW                │
│  ┌───────────────────────┐  │
│  │                       │  │
│  │    [Map with pins]    │  │
│  │                       │  │
│  │  📍 Jane (4.8★)       │  │
│  │  📍 Bob (4.5★)        │  │
│  │  📍 Sarah (5.0★)      │  │
│  │                       │  │
│  └───────────────────────┘  │
│                             │
├─────────────────────────────┤
│  Nearby Providers            │
│  ┌───────────────────────┐  │
│  │  👤 Jane Doe          │  │
│  │  ⭐ 4.8 (24 reviews)  │  │
│  │  🧹 Cleaning          │  │
│  │  📍 2.3 miles away    │  │
│  │  $45/hr • Available   │  │
│  │  ────────────────────│  │
│  │  [View Profile]      │  │
│  └───────────────────────┘  │
│                             │
│  ┌───────────────────────┐  │
│  │  👤 Bob Smith         │  │
│  │  ⭐ 4.5 (12 reviews)  │  │
│  │  🔧 Repairs           │  │
│  │  📍 3.1 miles away    │  │
│  │  $50/hr • Available   │  │
│  │  ────────────────────│  │
│  │  [View Profile]      │  │
│  └───────────────────────┘  │
│                             │
└─────────────────────────────┘

Key Elements:
• Search bar for service category
• Location permission prompt (once)
• Live map with provider pins
• Provider cards below map (scrollable)
• Each card shows: photo, name, rating, category, distance, rate, availability
• "View Profile" button for each provider
• Bottom navigation: Map | Bookings | Profile
```

**Real-Time Updates:**
- Providers appearing/disappearing as they go online/offline
- Distance updating as customer moves
- Ratings updating as reviews come in

---

## 4. Provider Profile & Details Screen

```
┌─────────────────────────────┐
│ < Back       Jane Doe       │
├─────────────────────────────┤
│  👤 [Profile Photo]         │
│  Large cover image          │
│                             │
├─────────────────────────────┤
│  📋 Jane Doe                │
│  ⭐ 4.8 (24 reviews)        │
│  📍 2.3 miles away          │
│  ✓ Verified Provider        │
│                             │
│  About                      │
│  Professional house cleaner │
│  with 5+ years experience. │
│  Specialize in deep cleans.│
│                             │
│  Services                   │
│  🧹 House Cleaning ($45/hr) │
│  🏠 Move-Out Cleaning ($60) │
│  🪟 Window Cleaning ($35)   │
│                             │
│  Response Time              │
│  Usually responds in 5 min  │
│                             │
│  Reviews (24)               │
│  ⭐⭐⭐⭐⭐ "Excellent work!" │
│  "Did a great job, very    │
│   professional and quick"  │
│   - Sarah M., 2 days ago   │
│                             │
│  ⭐⭐⭐⭐☆ "Good cleaning"  │
│  "Very thorough, came back │
│   for a missed spot"       │
│   - Tom J., 1 week ago     │
│                             │
├─────────────────────────────┤
│  ┌───────────────────────┐  │
│  │  🔔 MESSAGE           │  │
│  │  📅 BOOK SERVICE      │  │
│  └───────────────────────┘  │
│                             │
└─────────────────────────────┘

Key Elements:
• Large profile photo at top
• Name, rating, distance, verification badge
• Bio/about section
• Services offered (scrollable list)
• Response time
• Recent reviews (scrollable)
• Action buttons: Message, Book Service
```

---

## 5. Booking Request Screen

```
┌─────────────────────────────┐
│ < Back    Book Service      │
├─────────────────────────────┤
│  📍 Service Location        │
│  123 Main St, Sumner WA     │
│  [Change Location]          │
│                             │
│  📅 When?                   │
│  ┌───────────────────────┐  │
│  │ Today, Sep 8, 2 PM    │  │
│  │ [Change Date/Time]    │  │
│  └───────────────────────┘  │
│                             │
│  ⏱️  How Long?              │
│  ┌───────────────────────┐  │
│  │ 3 hours               │  │
│  │ [Adjust Duration]     │  │
│  └───────────────────────┘  │
│                             │
│  📝 What Do You Need?       │
│  ┌───────────────────────┐  │
│  │ House cleaning for    │  │
│  │ 3 hours - kitchen,    │  │
│  │ living room, bathroom │  │
│  │                       │  │
│  │ Any special requests? │  │
│  └───────────────────────┘  │
│                             │
│  💰 Estimated Price         │
│  $45/hr × 3 hours = $135    │
│                             │
│  Service Fee                │
│  $13.50 (10%)               │
│                             │
│  ━━━━━━━━━━━━━━━━━━━━━━━  │
│  Total                      │
│  $148.50                    │
│                             │
├─────────────────────────────┤
│  ┌───────────────────────┐  │
│  │   CONFIRM & PAY       │  │
│  └───────────────────────┘  │
│                             │
└─────────────────────────────┘

Key Elements:
• Service location (with ability to change)
• Date/time selector
• Duration selector (default based on service)
• Description text area
• Price breakdown:
  - Base price (rate × duration)
  - Yuki fee (10%)
  - Total
• Confirm button
• Validation: Date must be in future, required description
```

---

## 6. Payment Screen (Stripe Integration)

```
┌─────────────────────────────┐
│ < Back    Payment           │
├─────────────────────────────┤
│  💳 Payment Method          │
│                             │
│  ┌───────────────────────┐  │
│  │  [Visa ending 4242]   │  │
│  │  Exp: 12/25           │  │
│  │  ────────────────────│  │
│  │  [Use This Card]      │  │
│  └───────────────────────┘  │
│                             │
│  [+ Add New Payment Method] │
│                             │
├─────────────────────────────┤
│  Order Summary              │
│  🧹 House Cleaning          │
│  Today, 2:00 PM             │
│  3 hours                    │
│                             │
│  Subtotal        $135.00    │
│  Yuki Fee        $13.50     │
│  ─────────────────────────  │
│  Total           $148.50    │
│                             │
│  📍 123 Main St, Sumner WA  │
│                             │
├─────────────────────────────┤
│  ☑ I agree to Terms of      │
│    Service and authorize    │
│    this charge              │
│                             │
│  ┌───────────────────────┐  │
│  │   CHARGE MY CARD      │  │
│  └───────────────────────┘  │
│                             │
└─────────────────────────────┘

Key Elements:
• Display saved payment methods
• Option to add new card (Stripe Secure)
• Order summary review
• Terms acknowledgment checkbox
• Pay button
• Secure badge/messaging
```

**After Payment:**
```
┌─────────────────────────────┐
│       ✓ Payment Successful! │
├─────────────────────────────┤
│                             │
│  $148.50 charged to Visa    │
│  ending in 4242             │
│                             │
│  Booking Confirmed!         │
│  Reference: #BOK-230908-001 │
│                             │
│  Jane Doe is looking at     │
│  your request and will      │
│  accept within 10 minutes   │
│                             │
├─────────────────────────────┤
│  ┌───────────────────────┐  │
│  │  VIEW BOOKING         │  │
│  │  BACK TO HOME         │  │
│  └───────────────────────┘  │
│                             │
└─────────────────────────────┘
```

---

## 7. Active Booking Status Screen

```
┌─────────────────────────────┐
│        Active Booking       │
├─────────────────────────────┤
│  Provider: Jane Doe         │
│  Cleaning - Today, 2:00 PM  │
│  Reference: #BOK-001        │
│                             │
│  STATUS: ACCEPTED ✓         │
│                             │
├─────────────────────────────┤
│  📍 LOCATION TRACKING       │
│  ┌───────────────────────┐  │
│  │  [Map showing route]  │  │
│  │   Jane is 8 min away  │  │
│  │   📍 Current location │  │
│  │   🏠 Your location    │  │
│  └───────────────────────┘  │
│                             │
│  Estimated Arrival: 1:52 PM │
│                             │
├─────────────────────────────┤
│  📞 MESSAGE                 │
│  ┌───────────────────────┐  │
│  │ Jane: On my way! Will │  │
│  │ be there in 8 minutes │  │
│  │ 1:45 PM               │  │
│  │                       │  │
│  │ You: Great, thanks!   │  │
│  │ See you soon          │  │
│  │ 1:42 PM               │  │
│  └───────────────────────┘  │
│  [Type message]             │
│                             │
├─────────────────────────────┤
│  SERVICE DETAILS            │
│  🧹 House Cleaning          │
│  Duration: 3 hours          │
│  Location: 123 Main St      │
│  Price: $148.50             │
│                             │
│  ☎️  [Call Jane]             │
│  [Cancel Service]           │
│                             │
└─────────────────────────────┘

Key Elements:
• Live location tracking map
• Estimated arrival time
• Message thread with provider
• Service details summary
• Call button (direct call)
• Cancel option (if provider hasn't arrived)
```

**After Service Completion:**
```
┌─────────────────────────────┐
│   ✓ Service Completed       │
├─────────────────────────────┤
│  Jane finished at 5:12 PM   │
│                             │
│  How was your experience?   │
│  ⭐⭐⭐⭐⭐ [Rate Now]        │
│                             │
│  ┌───────────────────────┐  │
│  │ Leave a review (opt)  │  │
│  │ [Great work! Very     │  │
│  │  professional and     │  │
│  │  thorough]            │  │
│  └───────────────────────┘  │
│                             │
│  Payment Status             │
│  $148.50 held for 48 hours  │
│  until 2026-09-10, 5:12 PM  │
│                             │
│  If there's an issue,       │
│  [File a Dispute]           │
│                             │
│  ┌───────────────────────┐  │
│  │   SUBMIT REVIEW       │  │
│  └───────────────────────┘  │
│                             │
└─────────────────────────────┘
```

---

## 8. Dispute Filing Screen

```
┌─────────────────────────────┐
│ < Back    File a Dispute    │
├─────────────────────────────┤
│  Booking: #BOK-001          │
│  Jane Doe - Cleaning        │
│  Date: Sep 8, 2:00 PM       │
│                             │
│  ⚠️  Dispute Deadline        │
│  You have until Sep 10,     │
│  5:12 PM to file            │
│                             │
├─────────────────────────────┤
│  What's the issue?          │
│  ○ Service not provided     │
│  ○ Provider didn't show     │
│  ○ Poor quality work        │
│  ○ Safety concern           │
│  ○ Other                    │
│                             │
│  Describe the issue         │
│  ┌───────────────────────┐  │
│  │ Jane didn't complete  │  │
│  │ the agreed-upon tasks.│  │
│  │ The bathrooms weren't │  │
│  │ cleaned at all.       │  │
│  └───────────────────────┘  │
│                             │
│  Attach Evidence (photos)   │
│  [📸 Add Photo] [Remove]    │
│  ┌───────────────────────┐  │
│  │  [photo1.jpg] ✓       │  │
│  │  [photo2.jpg] ✓       │  │
│  └───────────────────────┘  │
│                             │
├─────────────────────────────┤
│  ┌───────────────────────┐  │
│  │  SUBMIT DISPUTE       │  │
│  └───────────────────────┘  │
│                             │
└─────────────────────────────┘

Key Elements:
• Booking reference
• Countdown timer to deadline
• Issue category selection
• Text description area
• Photo upload (evidence)
• Submit button
```

**After Dispute Filed:**
```
┌─────────────────────────────┐
│  ✓ Dispute Submitted        │
├─────────────────────────────┤
│  Reference: #DSP-001        │
│  Status: Under Review       │
│                             │
│  We'll investigate within   │
│  5-7 business days.         │
│                             │
│  Timeline:                  │
│  1. We review your evidence │
│  2. Provider responds       │
│  3. We make a decision      │
│  4. You're notified         │
│                             │
│  You can check status:      │
│  [View Dispute Status]      │
│                             │
└─────────────────────────────┘
```

---

# PROVIDER FLOWS

## 1. Provider Signup Screen

```
┌─────────────────────────────┐
│  < Back    Become a Provider│
├─────────────────────────────┤
│                             │
│  👤 Profile                 │
│  ┌───────────────────────┐  │
│  │ First Name            │  │
│  │ [____________]        │  │
│  └───────────────────────┘  │
│                             │
│  📧 Email                   │
│  ┌───────────────────────┐  │
│  │ [____________]        │  │
│  └───────────────────────┘  │
│                             │
│  📞 Phone                   │
│  ┌───────────────────────┐  │
│  │ +1 (206) 555-9999     │  │
│  └───────────────────────┘  │
│                             │
│  🔑 Password                │
│  ┌───────────────────────┐  │
│  │ [____________]        │  │
│  └───────────────────────┘  │
│                             │
│  Services You Offer         │
│  ☑ Cleaning                 │
│  ☑ Organizing               │
│  ☐ Repairs                  │
│  ☐ Tutoring                 │
│                             │
│  ┌───────────────────────┐  │
│  │  NEXT                 │  │
│  └───────────────────────┘  │
│                             │
└─────────────────────────────┘

Step 2 of 3: Background Check & Stripe
```

---

## 2. Background Check Status Screen

```
┌─────────────────────────────┐
│    Provider Verification    │
├─────────────────────────────┤
│                             │
│  ⏳ Background Check         │
│  Status: In Progress        │
│  Started: Sep 8, 2026       │
│  Expected: Sep 10, 2026     │
│                             │
│  What we're checking:       │
│  ✓ Criminal history         │
│  ✓ Sex offender registry    │
│  ✓ Fraud/sanctions lists    │
│  ⏳ Identity verification    │
│                             │
│  You'll be able to accept   │
│  bookings once approved.    │
│                             │
│  Already approved?          │
│  [Contact Support]          │
│                             │
├─────────────────────────────┤
│  📝 IMPORTANT               │
│  Your background check is   │
│  required by law. You have  │
│  30 days to dispute any     │
│  inaccuracies. See Privacy  │
│  Policy for details.        │
│                             │
└─────────────────────────────┘

If Approved:
┌─────────────────────────────┐
│  ✓ Background Check Passed! │
├─────────────────────────────┤
│  You're verified to provide │
│  services on Yuki.          │
│                             │
│  Next: Set up Stripe        │
│  Connect for payments.      │
│                             │
│  ┌───────────────────────┐  │
│  │  CONNECT STRIPE       │  │
│  └───────────────────────┘  │
│                             │
└─────────────────────────────┘

If Rejected:
┌─────────────────────────────┐
│  ⚠️  Background Check Issue  │
├─────────────────────────────┤
│  Your background check      │
│  shows a concern that needs │
│  review.                    │
│                             │
│  Reason:                    │
│  Misdemeanor conviction     │
│  from 2019                  │
│                             │
│  What now?                  │
│  You have 30 days to        │
│  dispute this finding if    │
│  it's inaccurate.           │
│                             │
│  [View Full Report]         │
│  [File a Dispute]           │
│                             │
│  Questions?                 │
│  [Contact Support]          │
│                             │
└─────────────────────────────┘
```

---

## 3. Provider Profile Setup

```
┌─────────────────────────────┐
│ < Back    Your Profile      │
├─────────────────────────────┤
│  [Change Photo]             │
│  📷 [Add Profile Picture]   │
│                             │
├─────────────────────────────┤
│  👤 Jane Doe                │
│  ✓ Verified Provider        │
│                             │
│  Bio                        │
│  ┌───────────────────────┐  │
│  │ Professional house    │  │
│  │ cleaner with 5+ years │  │
│  │ experience. Specialize│  │
│  │ in deep cleaning.     │  │
│  └───────────────────────┘  │
│                             │
│  Services                   │
│  🧹 House Cleaning          │
│     Hourly Rate: $45/hr     │
│                             │
│  🏠 Move-Out Cleaning       │
│     Flat Rate: $60/service  │
│     [Add More Services]     │
│                             │
│  Availability               │
│  ⏰ Typically available:     │
│     Mon-Fri 9 AM - 6 PM     │
│     Weekends: Case by case  │
│                             │
│  Response Time              │
│  Usually responds in        │
│  [5 minutes ▼]              │
│                             │
│  ✓ Verified & Background    │
│    Check Passed             │
│                             │
│  Connected to Stripe        │
│  Stripe Account: ••••5678   │
│  [Update Bank Info]         │
│                             │
├─────────────────────────────┤
│  ┌───────────────────────┐  │
│  │   SAVE CHANGES        │  │
│  └───────────────────────┘  │
│                             │
└─────────────────────────────┘

Key Elements:
• Profile photo upload
• Bio text area
• Services list (add/edit)
• Availability schedule
• Response time preference
• Verification badge
• Stripe connection status
• Save button
```

---

## 4. Availability Toggle (MAIN SCREEN)

```
┌─────────────────────────────┐
│  YUKI    [Profile] [Menu]   │
├─────────────────────────────┤
│  👤 Jane Doe                │
│  ⭐ 4.8 (24 reviews)        │
│  💰 $45/hr Cleaning         │
│                             │
├─────────────────────────────┤
│  🔴 STATUS: OFFLINE         │
│                             │
│  ┌───────────────────────┐  │
│  │  GO AVAILABLE NOW     │  │
│  │  (30 min timer)       │  │
│  └───────────────────────┘  │
│                             │
│  When available, customers  │
│  within 5 miles will see    │
│  your location.             │
│                             │
├─────────────────────────────┤
│  📊 Today's Earnings        │
│  Bookings: 0                │
│  Earnings: $0.00            │
│  Pending: $0.00             │
│                             │
├─────────────────────────────┤
│  Incoming Requests          │
│  (You have no active        │
│  bookings at this time)     │
│                             │
│  💡 Tip: Go "Available Now" │
│  to start receiving requests│
│                             │
└─────────────────────────────┘

When ONLINE:
┌─────────────────────────────┐
│  🟢 AVAILABLE NOW           │
│  [Timer: 28 min remaining]  │
│                             │
│  ┌───────────────────────┐  │
│  │   EXTEND 30 MIN       │  │
│  │   GO OFFLINE          │  │
│  └───────────────────────┘  │
│                             │
│  Location: Sumner, WA       │
│  Distance: ± 5 miles        │
│                             │
│  📊 Today's Earnings        │
│  Bookings: 1                │
│  Earnings: $148.50          │
│  Pending: $0.00             │
│                             │
│  Incoming Requests          │
│  New Request!               │
│  🏠 House Cleaning          │
│  📍 2.3 miles away          │
│  ⏰ Today, 2:00 PM          │
│  💰 $148.50 (3 hours)       │
│  [Accept] [Decline]        │
│                             │
└─────────────────────────────┘

Key Elements:
• Large status toggle (GO AVAILABLE NOW / GO OFFLINE)
• Timer when online (counts down)
• Extend availability button
• Current location
• Today's earnings summary
• Incoming booking requests (with quick accept/decline)
• Location refreshes every 60 seconds when online
```

---

## 5. Incoming Booking Request (POPUP/NOTIFICATION)

```
┌─────────────────────────────┐
│  🔔 NEW BOOKING REQUEST     │
├─────────────────────────────┤
│  👤 John Smith              │
│  ⭐ 4.5 (8 reviews)         │
│                             │
│  Service: Cleaning          │
│  Date: Today, 2:00 PM       │
│  Duration: 3 hours          │
│  📍 123 Main St, Sumner     │
│  Distance: 2.3 miles        │
│  💰 $135 + Stripe fee       │
│                             │
│  Description:               │
│  "House cleaning for 3 hrs, │
│   kitchen, living room,     │
│   bathroom"                 │
│                             │
│  Customer Rating:           │
│  Very responsive, friendly  │
│                             │
├─────────────────────────────┤
│  ⏱️  EXPIRES IN 10 MINUTES   │
│                             │
│  ┌───────────────────────┐  │
│  │   ACCEPT              │  │
│  │   DECLINE             │  │
│  └───────────────────────┘  │
│                             │
└─────────────────────────────┘

Key Elements:
• Customer name and rating
• Service details
• Distance to customer
• Estimated payment
• Customer feedback
• Countdown timer (booking expires in 10 min)
• Quick accept/decline buttons
• No auto-close (provider must respond)
```

---

## 6. Accepted Booking - In Progress

```
┌─────────────────────────────┐
│      Your Active Job        │
├─────────────────────────────┤
│  👤 John Smith              │
│  Reference: #BOK-001        │
│  Cleaning                   │
│                             │
│  STATUS: ACCEPTED ✓         │
│  ⏰ Starts: 2:00 PM         │
│                             │
├─────────────────────────────┤
│  📍 DIRECTIONS               │
│  123 Main St, Sumner, WA    │
│  2.3 miles away             │
│  ETA: 2:00 PM               │
│                             │
│  [Open in Maps]             │
│                             │
├─────────────────────────────┤
│  💬 MESSAGE                 │
│  ┌───────────────────────┐  │
│  │ You: On my way!       │  │
│  │ Will be there in 15   │  │
│  │ min                   │  │
│  │ 1:45 PM               │  │
│  │                       │  │
│  │ John: Great, thanks!  │  │
│  │ See you soon          │  │
│  │ 1:42 PM               │  │
│  └───────────────────────┘  │
│  [Type message]             │
│                             │
├─────────────────────────────┤
│  SERVICE DETAILS            │
│  Duration: 3 hours          │
│  Expected End: 5:00 PM      │
│  Rate: $45/hr               │
│  Earnings: $135             │
│                             │
│  ☎️  [Call Customer]         │
│  [Cancel Job]               │
│                             │
└─────────────────────────────┘

When Arriving:
┌─────────────────────────────┐
│  ✓ Arrived                  │
│                             │
│  ┌───────────────────────┐  │
│  │  START SERVICE        │  │
│  │  CANCEL JOB           │  │
│  └───────────────────────┘  │
│                             │
└─────────────────────────────┘

After START is tapped:
┌─────────────────────────────┐
│  🟢 SERVICE IN PROGRESS     │
│  Started: 2:00 PM           │
│  Elapsed: 45 minutes        │
│                             │
│  Estimated End: 5:00 PM     │
│                             │
│  Current Earnings          │
│  $45/hr × 0.75 hrs = $33.75│
│                             │
│  [Complete Service]         │
│                             │
└─────────────────────────────┘
```

---

## 7. Complete Booking & Get Paid

```
┌─────────────────────────────┐
│       Service Complete      │
├─────────────────────────────┤
│  ✓ You finished at 5:12 PM  │
│                             │
│  Actual Duration:           │
│  3 hours 12 minutes         │
│                             │
│  Earnings Calculation:      │
│  $45/hr × 3.2 hrs = $144    │
│  Yuki Fee (10%):   $14.40   │
│  Your Payout:      $129.60  │
│                             │
├─────────────────────────────┤
│  Payment Status             │
│  💳 Customer charged:       │
│     $148.50                 │
│                             │
│  ⏳ Payment on hold for:     │
│     48 hours (dispute       │
│     window)                 │
│                             │
│  Expected delivery:         │
│  Sep 10, 2026 @ 5:12 PM    │
│                             │
├─────────────────────────────┤
│  Next Steps:                │
│  1. Wait 48 hours           │
│  2. $ transferred to Stripe │
│  3. Withdraw to your bank   │
│                             │
│  [View Earnings]            │
│                             │
└─────────────────────────────┘
```

---

## 8. Earnings & Withdrawal Dashboard

```
┌─────────────────────────────┐
│    Your Earnings            │
├─────────────────────────────┤
│  This Month                 │
│  Bookings: 12               │
│  Gross Earnings: $540.00    │
│  Yuki Fees: $54.00          │
│  Net Earnings: $486.00      │
│                             │
├─────────────────────────────┤
│  Balance Summary            │
│  ✓ Available: $351.00       │
│    (Ready to withdraw)      │
│                             │
│  ⏳ Pending: $135.00         │
│    (48-hour dispute window) │
│                             │
│  💳 Processing: $0.00       │
│                             │
├─────────────────────────────┤
│  ┌───────────────────────┐  │
│  │  WITHDRAW $351.00     │  │
│  └───────────────────────┘  │
│                             │
├─────────────────────────────┤
│  Recent Earnings            │
│  ┌───────────────────────┐  │
│  │ Sep 8                 │  │
│  │ House Cleaning        │  │
│  │ John Smith            │  │
│  │ 3 hrs @ $45 = $144    │  │
│  │ - $14.40 (fee)        │  │
│  │ = $129.60 net         │  │
│  │ Status: ⏳ Pending     │  │
│  └───────────────────────┘  │
│                             │
│  ┌───────────────────────┐  │
│  │ Sep 6                 │  │
│  │ Move-Out Cleaning     │  │
│  │ Sarah M.              │  │
│  │ Flat $60 - $6 (fee)   │  │
│  │ = $54 net             │  │
│  │ Status: ✓ Completed   │  │
│  └───────────────────────┘  │
│                             │
└─────────────────────────────┘

Withdrawal Flow:
┌─────────────────────────────┐
│ < Back    Withdraw          │
├─────────────────────────────┤
│  Available Balance          │
│  $351.00                    │
│                             │
│  Amount to Withdraw         │
│  ┌───────────────────────┐  │
│  │ $ 351.00              │  │
│  │ [Full] [Custom]       │  │
│  └───────────────────────┘  │
│                             │
│  Bank Account               │
│  Stripe Account: ••••5678   │
│  Wells Fargo Checking       │
│  [Change Bank Account]      │
│                             │
│  Transfer Fee: $0           │
│  Amount to Transfer: $351   │
│                             │
│  Expected Arrival:          │
│  1-2 business days          │
│                             │
│  ┌───────────────────────┐  │
│  │  CONFIRM WITHDRAWAL   │  │
│  └───────────────────────┘  │
│                             │
└─────────────────────────────┘

After Confirmation:
┌─────────────────────────────┐
│  ✓ Withdrawal Submitted     │
│  Reference: #WTH-001        │
│                             │
│  Amount: $351.00            │
│  Status: Processing         │
│  Expected: 1-2 business     │
│  days to your account       │
│                             │
│  You'll get a notification  │
│  when the transfer arrives. │
│                             │
│  Questions? [Contact Support]
│                             │
└─────────────────────────────┘
```

---

## 9. Notifications & Status Updates

```
Push Notifications:

CUSTOMER:
✓ "John accepted your booking! He's on his way."
✓ "Your service is complete. Rate John now."
✓ "Payment released to provider. Thank you!"
⚠️ "Your booking expires in 2 minutes"
⚠️ "Your dispute has been resolved. Tap to view"

PROVIDER:
✓ "New booking request! $135 for 3 hours"
✓ "Customer rated you 5 stars!"
✓ "Withdrawal of $351 completed! Check your bank."
⏰ "Your availability expires in 5 minutes"
⚠️ "New dispute filed for booking #001"
```

---

## Navigation Structure

### Customer Bottom Navigation
```
[Home]    [Bookings]    [Messages]    [Profile]
  🏠         📅           💬            👤
```

### Provider Bottom Navigation
```
[Available]    [Bookings]    [Earnings]    [Profile]
   🟢             📅          💰           👤
```

---

## Color Scheme

```
Primary:     #2E7D32 (Yuki Green - trust, growth)
Secondary:   #1976D2 (Professional Blue)
Accent:      #F57C00 (Action Orange)
Success:     #388E3C (Green checkmarks)
Warning:     #FBC02D (Yellow alerts)
Error:       #D32F2F (Red errors)
Neutral:     #757575 (Gray text)
Background:  #FAFAFA (Off-white)
```

---

## Typography

```
Headers:     Poppins Bold (24px)
Titles:      Poppins SemiBold (18px)
Body:        Inter Regular (14px)
Small:       Inter Regular (12px)
Button Text: Poppins SemiBold (16px)
```

---

## Key UX Principles

1. **Clarity:** Show status at a glance (colors, icons, labels)
2. **Speed:** Minimize taps to complete actions (3 taps max)
3. **Safety:** Confirm destructive actions (cancel, dispute)
4. **Feedback:** Show loading states, error messages, success confirmations
5. **Accessibility:** Proper contrast, readable fonts, touch targets (44px min)
6. **Trust:** Show verification badges, ratings, security info
7. **Transparency:** Show pricing breakdowns, timelines, terms

---

## Accessibility Requirements

- [ ] WCAG 2.1 AA compliance
- [ ] Minimum touch target size: 44x44 points
- [ ] Text contrast ratio: 4.5:1
- [ ] All images have alt text
- [ ] Form labels associated with inputs
- [ ] Screen reader support (iOS/Android)
- [ ] No color-only information (use icons too)

---

## Next Steps

1. **Create high-fidelity designs** in Figma/Adobe XD
2. **Prototype interactions** (transitions, animations)
3. **User test** mockups with actual users
4. **Iterate** based on feedback
5. **Handoff to developers** with design system

