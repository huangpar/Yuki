import { createClient } from '@supabase/supabase-js';
import config from './config.js';

// Service role client (can bypass RLS for server operations)
export const supabase = createClient(
  config.supabase.url,
  config.supabase.serviceRoleKey,
  {
    auth: {
      autoRefreshToken: false,
      persistSession: false,
    },
  }
);

// Anon client (respects RLS policies, for testing)
export const supabaseAnon = createClient(
  config.supabase.url,
  config.supabase.anonKey,
  {
    auth: {
      autoRefreshToken: false,
      persistSession: false,
    },
  }
);

// Helper: Insert audit log
export async function logAuditEvent(userId, eventType, eventDetails = {}) {
  try {
    const { error } = await supabase
      .from('audit_logs')
      .insert([
        {
          user_id: userId,
          event_type: eventType,
          event_details: eventDetails,
          created_at: new Date().toISOString(),
        },
      ]);

    if (error) {
      console.error('Failed to log audit event:', error);
    }
  } catch (err) {
    console.error('Error logging audit event:', err);
  }
}

// Helper: Get user by ID
export async function getUserById(userId) {
  const { data, error } = await supabase
    .from('profiles')
    .select('*')
    .eq('id', userId)
    .single();

  if (error) {
    throw new Error(`User not found: ${error.message}`);
  }

  return data;
}

// Helper: Get provider status
export async function getProviderStatus(providerId) {
  const { data, error } = await supabase
    .from('provider_statuses')
    .select('*')
    .eq('id', providerId)
    .single();

  if (error) {
    return null;
  }

  return data;
}


// Helper: Get booking by ID
export async function getBookingById(bookingId) {
  const { data, error } = await supabase
    .from('booking_requests')
    .select('*')
    .eq('id', bookingId)
    .single();

  if (error) {
    return null;
  }

  return data;
}

// Helper: Create payment record
export async function createPayment(customerId, bookingId, paymentIntentId, amount) {
  const { data, error } = await supabase
    .from('payments')
    .insert([
      {
        customer_id: customerId,
        booking_id: bookingId,
        payment_intent_id: paymentIntentId,
        amount,
        status: 'requires_payment_method',
        currency: 'usd',
        created_at: new Date().toISOString(),
      },
    ])
    .select();

  if (error) {
    throw new Error(`Failed to create payment: ${error.message}`);
  }

  return data[0];
}

// Helper: Update payment status
export async function updatePaymentStatus(paymentIntentId, status, chargeId = null) {
  const updateData = {
    status,
    confirmed_at: status === 'succeeded' ? new Date().toISOString() : null,
  };

  if (chargeId) {
    updateData.charge_id = chargeId;
  }

  const { data, error } = await supabase
    .from('payments')
    .update(updateData)
    .eq('payment_intent_id', paymentIntentId)
    .select();

  if (error) {
    throw new Error(`Failed to update payment: ${error.message}`);
  }

  return data[0];
}

// Helper: Get payment by intent ID
export async function getPaymentByIntentId(paymentIntentId) {
  const { data, error } = await supabase
    .from('payments')
    .select('*')
    .eq('payment_intent_id', paymentIntentId)
    .single();

  if (error) {
    return null;
  }

  return data;
}

export default supabase;
