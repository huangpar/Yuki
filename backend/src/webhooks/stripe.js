import { updatePaymentStatus, getPaymentByIntentId, logAuditEvent } from '../db.js';
import { logger } from '../middleware/logger.js';
import { ApiError, asyncHandler } from '../middleware/errorHandler.js';

export const handleStripeWebhook = asyncHandler(async (req, res) => {
  const event = req.body;

  logger.info('Stripe webhook received', {
    eventId: event.id,
    eventType: event.type,
  });

  try {
    switch (event.type) {
      case 'payment_intent.succeeded':
        await handlePaymentSucceeded(event.data.object);
        break;

      case 'charge.refunded':
        await handleChargeRefunded(event.data.object);
        break;

      case 'charge.dispute.created':
        await handleChargeDispute(event.data.object);
        break;

      default:
        logger.debug(`Unhandled Stripe event type: ${event.type}`);
    }

    res.json({ received: true });
  } catch (err) {
    logger.error('Error processing Stripe webhook', {
      eventId: event.id,
      error: err.message,
    });

    // Always return 200 to prevent Stripe retry
    res.json({ received: true, error: err.message });
  }
});

async function handlePaymentSucceeded(paymentIntent) {
  const { id: paymentIntentId, client_secret: clientSecret, charges } = paymentIntent;

  const chargeId = charges?.data?.[0]?.id;
  if (!chargeId) {
    throw new Error('No charge found in payment intent');
  }

  // Update payment in database
  const payment = await updatePaymentStatus(paymentIntentId, 'succeeded', chargeId);

  if (!payment) {
    throw new Error(`Payment not found: ${paymentIntentId}`);
  }

  logger.info('Payment succeeded', {
    paymentIntentId,
    chargeId,
    amount: payment.amount,
  });

  // Log audit event
  await logAuditEvent(payment.customer_id, 'payment_succeeded', {
    paymentIntentId,
    chargeId,
    amount: payment.amount,
  });
}

async function handleChargeRefunded(charge) {
  const { payment_intent: paymentIntentId, amount_refunded: refundAmount } = charge;

  if (!paymentIntentId) {
    return;
  }

  const payment = await getPaymentByIntentId(paymentIntentId);
  if (!payment) {
    logger.warn('Refund received for unknown payment', { paymentIntentId });
    return;
  }

  await updatePaymentStatus(paymentIntentId, 'refunded');

  logger.info('Charge refunded', {
    paymentIntentId,
    refundAmount,
  });

  await logAuditEvent(payment.customer_id, 'payment_refunded', {
    paymentIntentId,
    refundAmount,
  });
}

async function handleChargeDispute(chargeData) {
  const { payment_intent: paymentIntentId, id: chargeId } = chargeData;

  if (!paymentIntentId) {
    return;
  }

  const payment = await getPaymentByIntentId(paymentIntentId);
  if (!payment) {
    logger.warn('Dispute created for unknown payment', { paymentIntentId });
    return;
  }

  logger.warn('Charge dispute created', {
    paymentIntentId,
    chargeId,
  });

  await logAuditEvent(payment.customer_id, 'chargeback_filed', {
    paymentIntentId,
    chargeId,
  });
}

export default { handleStripeWebhook };
