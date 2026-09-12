import crypto from 'crypto';
import config from '../config.js';

// Verify Stripe webhook signature
export function verifyStripeSignature(body, signature) {
  const secret = config.stripe.webhookSecret;

  try {
    const hash = crypto
      .createHmac('sha256', secret)
      .update(body, 'utf8')
      .digest('hex');

    const computedSignature = `t=${Date.now()},v1=${hash}`;

    // Check if signature matches
    const signatureParts = signature.split(',');
    for (const part of signatureParts) {
      if (part.startsWith('v1=')) {
        const providedHash = part.slice(3);
        if (providedHash === hash) {
          return true;
        }
      }
    }

    return false;
  } catch (err) {
    console.error('Error verifying Stripe signature:', err);
    return false;
  }
}

// Verify Checkr webhook signature
export function verifyCheckrSignature(body, signature) {
  const secret = config.checkr.webhookSecret;

  try {
    const hash = crypto
      .createHmac('sha256', secret)
      .update(body, 'utf8')
      .digest('base64');

    return signature === `sha256=${hash}`;
  } catch (err) {
    console.error('Error verifying Checkr signature:', err);
    return false;
  }
}

export default {
  verifyStripeSignature,
  verifyCheckrSignature,
};
