import dotenv from 'dotenv';

dotenv.config();

export const config = {
  server: {
    nodeEnv: process.env.NODE_ENV || 'development',
    port: parseInt(process.env.PORT || '3000', 10),
    logLevel: process.env.LOG_LEVEL || 'info',
  },

  supabase: {
    url: process.env.SUPABASE_URL,
    anonKey: process.env.SUPABASE_ANON_KEY,
    serviceRoleKey: process.env.SUPABASE_SERVICE_ROLE_KEY,
  },

  stripe: {
    secretKey: process.env.STRIPE_SECRET_KEY,
    webhookSecret: process.env.STRIPE_WEBHOOK_SECRET,
    apiVersion: process.env.STRIPE_API_VERSION || '2023-10-16',
  },

  checkr: {
    apiKey: process.env.CHECKR_API_KEY,
    webhookSecret: process.env.CHECKR_WEBHOOK_SECRET,
  },

  jwt: {
    secret: process.env.JWT_SECRET,
    expirySeconds: parseInt(process.env.JWT_EXPIRY || '3600', 10),
  },
};

// Validate required environment variables
const required = [
  'SUPABASE_URL',
  'SUPABASE_ANON_KEY',
  'SUPABASE_SERVICE_ROLE_KEY',
  'STRIPE_SECRET_KEY',
  'STRIPE_WEBHOOK_SECRET',
  'CHECKR_API_KEY',
  'CHECKR_WEBHOOK_SECRET',
];

const missing = required.filter((key) => !process.env[key]);
if (missing.length > 0) {
  console.error('Missing required environment variables:', missing);
  if (config.server.nodeEnv === 'production') {
    process.exit(1);
  }
}

export default config;
