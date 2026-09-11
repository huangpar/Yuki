# Yuki Database Setup Guide

## Overview
This document guides you through setting up the Yuki database schema securely and professionally.

## Prerequisites
- Supabase account with "Yuki" project created
- Access to SQL Editor in Supabase dashboard

## Database Architecture

### Tables Created:
1. **profiles** - User information (extends auth.users)
2. **provider_statuses** - Real-time provider availability and verification
3. **booking_requests** - Customer service requests
4. **audit_logs** - Security and compliance logging

### Security Features:
- ✅ Row Level Security (RLS) enabled on all tables
- ✅ PostGIS integration for geospatial queries
- ✅ Automatic profile creation on auth signup
- ✅ Audit logging for compliance
- ✅ Spatial indexes for performance
- ✅ Proper foreign key constraints

## Setup Instructions

### Step 1: Execute the Migration
1. Go to your Yuki Supabase project dashboard
2. Click "SQL Editor" in the left sidebar
3. Click "+ New Query"
4. Copy the entire contents of: `supabase/migrations/20260908000001_initial_schema.sql`
5. Paste into the SQL editor
6. Click "Run" button
7. Confirm when prompted

### Step 2: Verify Tables Created
After successful execution, you should see these tables in the Supabase dashboard:
- `public.profiles`
- `public.provider_statuses`
- `public.booking_requests`
- `public.audit_logs`

### Step 3: Test RLS Policies
1. Go to the "Authentication" tab in Supabase
2. Create a test customer user
3. Create a test provider user
4. Verify each user can only see their own data

## Database Schema

### profiles
```
- id (uuid, PK) - References auth.users
- email (text, unique)
- phone (text)
- role (text) - 'customer' or 'provider'
- first_name (text)
- last_name (text)
- created_at (timestamp)
- updated_at (timestamp)
```

### provider_statuses
```
- id (uuid, PK) - References profiles
- is_available (boolean)
- location (geography Point) - PostGIS location data
- stripe_account_id (text)
- stripe_onboarding_complete (boolean)
- checkr_candidate_id (text)
- background_check_status (text)
- is_verified_for_work (boolean)
- last_heartbeat (timestamp)
```

### booking_requests
```
- id (uuid, PK)
- customer_id (uuid, FK) - Customer who made request
- provider_id (uuid, FK) - Provider assigned (nullable)
- service_description (text)
- customer_location (geography Point)
- status (text) - 'pending', 'accepted', 'completed', 'cancelled'
- requested_at (timestamp)
- accepted_at (timestamp)
- completed_at (timestamp)
- created_at (timestamp)
- updated_at (timestamp)
```

### audit_logs
```
- id (uuid, PK)
- user_id (uuid, FK)
- action (text)
- resource_type (text)
- resource_id (text)
- details (jsonb)
- ip_address (inet)
- user_agent (text)
- created_at (timestamp)
```

## Key Features

### Automatic Profile Creation
When a user signs up through Auth, the `handle_new_user()` trigger automatically:
- Creates a profile with their email and name
- If role is 'provider', creates provider_statuses record

### Geospatial Queries
The `get_nearby_providers()` function finds all available providers within a radius:
```sql
select * from get_nearby_providers(longitude, latitude, radius_meters);
```

### Real-Time Updates
Enabled for:
- provider_statuses - When providers go online/offline
- booking_requests - When booking status changes

### Row Level Security
- Customers can only see their own bookings
- Providers can only see bookings assigned to them
- Only verified available providers are visible to customers
- Audit logs are currently admin-only

## Migration Safety

This migration includes:
- Safe index creation (using `if not exists`)
- Atomic operations (all-or-nothing)
- No data loss (existing data preserved)
- Rollback-safe (can be reverted if needed)

## Next Steps

1. ✅ Execute migration (you're here)
2. ➡️ Set up input validation layer (Task #9)
3. ➡️ Configure error handling & logging (Task #10)
4. ➡️ Implement rate limiting (Task #11)
5. ➡️ Set up payment handling (Task #12)

## Troubleshooting

### Issue: "Extension 'postgis' already exists"
This is fine - the migration uses `create extension if not exists`

### Issue: "Function already exists"
If you run the migration twice, it will recreate functions. This is safe.

### Issue: Trigger not firing
- Verify the trigger was created: `select * from information_schema.triggers where table_name = 'users';`
- Ensure it's in the `auth` schema (not `public`)

## Security Checklist
- [x] RLS policies implemented
- [x] Input validation needed (Task #9)
- [x] Error handling needed (Task #10)
- [x] Audit logging implemented
- [ ] Rate limiting needed (Task #11)
- [ ] Payment handling needs (Task #12)
- [ ] Terms of Service needed (Task #14)
- [ ] Background check flow needed (Task #15)

## Support
For issues or questions about the schema, refer to the specific tasks in the project todo list.
