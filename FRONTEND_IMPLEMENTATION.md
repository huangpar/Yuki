# Yuki Frontend Implementation - Phase 2 (Auth & Booking)

**Status:** ✅ Complete - Ready for testing

---

## What's Been Built

### Phase 1: Homepage + Map (Completed)
- ✅ Themeable design system (`lib/theme/app_theme.dart`)
- ✅ Map display with provider markers (`lib/screens/home_screen.dart`)
- ✅ Real-time provider updates
- ✅ Empty state with "Request Neighborhood"

### Phase 2: Auth & Booking (NEW - Completed)
- ✅ Sign Up / Sign In screens (`lib/screens/auth_screen.dart`)
- ✅ Booking request flow (`lib/screens/booking_screen.dart`)
- ✅ Navigation integration
- ✅ Error handling

---

## Complete User Flow

```
1. App Launch (SplashScreen)
   ↓ (1 second delay)
   ├─ Initializes Supabase
   └─ Routes to HomeScreen

2. HomeScreen
   ├─ Request location permission
   ├─ Load current location
   ├─ Fetch nearby providers (GET /api/customers/nearby-providers)
   ├─ Display map with provider markers
   ├─ Show horizontal scrolling provider list
   │
   ├─ If providers available:
   │  ├─ Tap provider marker/card
   │  ├─ Show provider details sheet
   │  ├─ Tap "Book Now"
   │  │   ↓
   │  │  AuthScreen (Check auth status)
   │  │  ├─ New users → Sign Up form
   │  │  ├─ Existing users → Sign In form
   │  │  ├─ After auth → BookingScreen
   │  │
   │  └─ BookingScreen
   │     ├─ Select date (DatePicker)
   │     ├─ Select time (TimePicker)
   │     ├─ Choose duration (30min - 4hr)
   │     ├─ Describe work needed
   │     ├─ Show estimated cost
   │     └─ Submit booking
   │
   └─ If no providers:
      ├─ Show "No Providers Yet" message
      └─ "Request Neighborhood" button
         → Track demand for new markets
```

---

## Screens Built

### 1. SplashScreen
- **File:** `lib/main.dart`
- **Purpose:** App initialization, 1-second loading animation
- **Navigation:** Always routes to HomeScreen

### 2. HomeScreen (Provider Discovery)
- **File:** `lib/screens/home_screen.dart`
- **Features:**
  - Live map using Flutter Map + OpenStreetMap
  - Current location marker (blue pin)
  - Provider markers (blue circles with initials)
  - Horizontal scrolling provider list
  - Provider details bottom sheet
  - Real-time subscription to provider status changes
  - Empty state with "Request Neighborhood"
  - Error handling for permissions & network

### 3. AuthScreen (Sign In / Sign Up)
- **File:** `lib/screens/auth_screen.dart`
- **Features:**
  - **Sign Up fields:**
    - Email (validated)
    - Password (8+ chars)
    - First name
    - Last name
    - Phone
  - **Sign In fields:**
    - Email (validated)
    - Password
  - Toggle between modes
  - Password visibility toggle
  - Error messages (user-friendly)
  - Loading state
  - Integration with Supabase auth

### 4. BookingScreen (Request a Service)
- **File:** `lib/screens/booking_screen.dart`
- **Features:**
  - Provider info card with hourly rate
  - Date picker (today + 30 days)
  - Time picker (24-hour)
  - Duration selector (30min - 4hr chips)
  - Work description textarea
  - Real-time estimated cost calculation
  - Submit booking button

---

## Design System Features

### Colors (Themeable)
```dart
AppColors.primary        // #2E7D32 (Yuki green)
AppColors.secondary      // #1976D2 (Professional blue)
AppColors.accent         // #F57C00 (Action orange)
AppColors.error          // #D32F2F (Red)
AppColors.textPrimary    // #212121 (Dark text)
AppColors.textSecondary  // #757575 (Gray text)
AppColors.background     // #FAFAFA (Off-white)
AppColors.surface        // #FFFFFF (White)
```

### Spacing Scale
```dart
xs: 4px, sm: 8px, md: 16px, lg: 24px, xl: 32px, xxl: 48px
```

### Typography
```dart
h1: 32px, bold           // Page titles
h2: 24px, bold           // Section titles
h3: 20px, semi-bold      // Subsection titles
bodyLarge: 16px          // Primary text
bodyMedium: 14px         // Regular text
bodySmall: 12px          // Secondary text
caption: 12px, gray      // Captions
button: 16px, semi-bold  // Button text
```

---

## Navigation Structure

```dart
YukiApp
├─ routes: {
│  '/home': HomeScreen,
│  '/signin': AuthScreen(isSignUp: false),
│  '/signup': AuthScreen(isSignUp: true),
│}
└─ home: SplashScreen
   └─ Navigates to '/home' after 1s
```

**Navigation Flow:**
- HomeScreen → AuthScreen (via Navigator.push)
- AuthScreen → BookingScreen (via Navigator.pushReplacement after auth)
- BookingScreen → Back to HomeScreen (via Navigator.pop)

---

## Backend Integration

### Currently Connected Endpoints

1. **GET /api/customers/nearby-providers**
   - Called from: HomeScreen._fetchNearbyProviders()
   - Params: latitude, longitude, radius (optional), category (optional)
   - Returns: NearbyProvidersResponse with list of providers

2. **Real-time Subscription**
   - Listens to: provider_statuses table changes
   - Filter: is_verified_for_work = true
   - Called from: HomeScreen._subscribeToProviderUpdates()

3. **Auth Service**
   - signUp() - Called from AuthScreen
   - signIn() - Called from AuthScreen
   - Uses Supabase auth, validates JWT tokens

### To Be Connected (Next Phase)

1. **POST /api/customers/bookings**
   - Receives: provider_id, date, time, duration, description
   - Returns: booking_id, estimated_cost, status

2. **POST /api/customers/payments**
   - Stripe payment processing
   - Card details (tokenized by Stripe)
   - Booking amount

---

## State Management

Current approach: **StatefulWidget**
- Simple local state for each screen
- No external state management (Redux, Riverpod, Provider)
- Can upgrade later if needed

**For Future Scaling:**
```dart
// Option 1: Provider package (already in pubspec.yaml)
// Option 2: Riverpod
// Option 3: BLoC
// Option 4: GetX
```

---

## Error Handling

### Auth Errors
- "Already registered" → "Email already in use"
- "Invalid login credentials" → "Invalid email or password"
- "Email not confirmed" → "Please verify your email"
- Network errors → User-friendly messages

### Location Errors
- Permission denied → Show settings redirect
- Location service disabled → Show user-friendly message
- Network error → Show retry button

### Booking Errors
- Invalid date/time → Disable submit button
- Network error → Show error message

---

## Validation Rules

### Email
```dart
Pattern: ^[^@]+@[^@]+\.[^@]+$
```

### Password
```dart
Sign Up: minimum 8 characters
Sign In: no requirements (backend validates)
```

### Phone
```dart
Minimum 10 digits (after removing non-digits)
```

### Booking
```dart
Date: Today + 1 to 30 days
Duration: Required, 30min - 4hr
```

---

## Testing Checklist

### Functional Testing
- [ ] HomeScreen loads without login
- [ ] Providers display on map correctly
- [ ] Tap provider shows details sheet
- [ ] "Book Now" navigates to auth
- [ ] Sign Up creates account
- [ ] Sign In authenticates user
- [ ] After auth, redirects to BookingScreen
- [ ] Date picker shows correct date range
- [ ] Time picker selects valid times
- [ ] Duration selection updates cost
- [ ] Submit booking shows confirmation

### Edge Cases
- [ ] No providers in area → Shows empty state
- [ ] Location permission denied → Shows error
- [ ] Network error → Shows retry button
- [ ] Sign up with existing email → Shows error
- [ ] Sign in with wrong password → Shows error
- [ ] Fast double-taps don't duplicate navigation

### UI/UX
- [ ] All text is readable (contrast & size)
- [ ] Buttons are easily tappable (48px minimum)
- [ ] No layout overflow on small screens
- [ ] Loading states show spinners
- [ ] Error messages are clear
- [ ] Form validation happens before submit

---

## Files & Structure

```
lib/
├── main.dart                          // App entry, routing
├── theme/
│   └── app_theme.dart               // Design system (colors, spacing, typography)
├── models/
│   └── nearby_provider_model.dart    // API models (NearbyProvider, etc.)
├── screens/
│   ├── home_screen.dart             // Provider discovery map
│   ├── auth_screen.dart             // Sign in / Sign up
│   ├── booking_screen.dart          // Request booking
│   └── (more screens to come)
└── services/
    └── supabase_service.dart        // Backend API calls & auth
```

---

## What's NOT Yet Built

1. **Payment Screen**
   - Stripe card input
   - Payment processing
   - Receipt/confirmation

2. **Booking Status**
   - Live booking updates
   - Provider acceptance/rejection
   - Completion & review

3. **Provider Onboarding**
   - Profile setup
   - Background check initiation
   - Availability management
   - Earnings dashboard

4. **User Profiles**
   - Edit profile
   - Saved addresses
   - Booking history
   - Ratings & reviews

5. **Notifications**
   - Push notifications
   - Real-time updates
   - In-app messaging

6. **Communication**
   - Message provider
   - Chat history
   - Call integration

---

## How to Run

1. **Install dependencies:**
   ```bash
   flutter pub get
   ```

2. **Set up .env file:**
   ```bash
   cp .env.example .env
   # Add SUPABASE_URL and SUPABASE_ANON_KEY
   ```

3. **Make sure backend is running:**
   ```bash
   cd backend
   npm run dev
   ```

4. **Run the app:**
   ```bash
   flutter run
   ```

---

## Performance Considerations

- **Map rendering:** Limits markers to 50 providers (can increase)
- **Real-time updates:** Debounced to reduce rebuild cycles
- **Image loading:** Uses placeholder until loaded
- **Location:** Fetches once on app start, refreshes on home return

---

## Security Notes

- ✅ Passwords sent via secure Supabase auth
- ✅ JWT tokens stored by Supabase SDK
- ✅ API calls include Authorization header
- ✅ No sensitive data in logs
- ⚠️ TODO: Add certificate pinning for production
- ⚠️ TODO: Add app signing for Android/iOS

---

## Next Steps

1. **Test all screens locally** with backend running
2. **Connect payment processing** (Stripe)
3. **Build booking status screen** (real-time updates)
4. **Add provider onboarding flow**
5. **Implement push notifications**
6. **Add user profile screens**
7. **UI refinements** based on user feedback
8. **App store submission** (iOS & Android)

