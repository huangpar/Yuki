import express from 'express';
import config from './config.js';
import { requestLogger, logger } from './middleware/logger.js';
import { errorHandler } from './middleware/errorHandler.js';
import { verifyAuth, verifyWebhook } from './middleware/auth.js';
import { verifyStripeSignature, verifyCheckrSignature } from './utils/signatures.js';
import { handleStripeWebhook } from './webhooks/stripe.js';
import { handleCheckrWebhook } from './webhooks/checkr.js';
import providersRouter from './routes/providers.js';
import locationsRouter from './routes/locations.js';
import bookingsRouter from './routes/bookings.js';
import accountRouter from './routes/account.js';

const app = express();

// Raw body middleware for webhook signature verification
app.use('/webhooks/stripe', express.raw({ type: 'application/json' }));
app.use('/webhooks/checkr', express.raw({ type: 'application/json' }));

// JSON parsing for all other routes
app.use(express.json());

// CORS middleware
app.use((req, res, next) => {
  res.header('Access-Control-Allow-Origin', '*');
  res.header('Access-Control-Allow-Methods', 'GET, POST, PUT, DELETE, OPTIONS');
  res.header('Access-Control-Allow-Headers', 'Content-Type, Authorization');

  if (req.method === 'OPTIONS') {
    return res.sendStatus(200);
  }

  next();
});

// Request logging
app.use(requestLogger);

// Health check endpoint
app.get('/health', (req, res) => {
  res.json({
    status: 'ok',
    timestamp: new Date().toISOString(),
    uptime: process.uptime(),
  });
});

// Stripe webhook endpoint
app.post('/webhooks/stripe', verifyWebhook, (req, res, next) => {
  const signature = req.headers['stripe-signature'];
  const body = req.body.toString('utf-8');

  if (!signature || !verifyStripeSignature(body, signature)) {
    logger.warn('Invalid Stripe signature');
    return res.status(401).json({
      error: 'invalid_signature',
      message: 'Webhook signature verification failed',
    });
  }

  // Parse JSON after signature verification
  const event = JSON.parse(body);
  req.body = event;

  handleStripeWebhook(req, res, next);
});

// Checkr webhook endpoint
app.post('/webhooks/checkr', verifyWebhook, (req, res, next) => {
  const signature = req.headers['x-checkr-signature'];
  const body = req.body.toString('utf-8');

  if (!signature || !verifyCheckrSignature(body, signature)) {
    logger.warn('Invalid Checkr signature');
    return res.status(401).json({
      error: 'invalid_signature',
      message: 'Webhook signature verification failed',
    });
  }

  // Parse JSON after signature verification
  const event = JSON.parse(body);
  req.body = event;

  handleCheckrWebhook(req, res, next);
});

// API Routes
app.use('/api', locationsRouter);
app.use('/api/bookings', bookingsRouter);
app.use('/api/providers', providersRouter);
app.use('/api/me', accountRouter);

// 404 handler
app.use((req, res) => {
  res.status(404).json({
    error: 'not_found',
    message: `Route not found: ${req.method} ${req.path}`,
    status: 404,
    timestamp: new Date().toISOString(),
  });
});

// Error handler (must be last)
app.use(errorHandler);

// Start server
const PORT = config.server.port;

const server = app.listen(PORT, () => {
  logger.info(`Yuki backend server started`, {
    port: PORT,
    environment: config.server.nodeEnv,
  });
});

// Graceful shutdown
process.on('SIGTERM', () => {
  logger.info('SIGTERM received, shutting down gracefully');
  server.close(() => {
    logger.info('Server closed');
    process.exit(0);
  });
});

process.on('SIGINT', () => {
  logger.info('SIGINT received, shutting down gracefully');
  server.close(() => {
    logger.info('Server closed');
    process.exit(0);
  });
});

export default app;
