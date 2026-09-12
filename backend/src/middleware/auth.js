import { supabase, supabaseAnon } from '../db.js';

export async function verifyAuth(req, res, next) {
  try {
    const authHeader = req.headers.authorization;
    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      return res.status(401).json({
        error: 'unauthorized',
        message: 'Missing or invalid authorization header',
      });
    }

    const token = authHeader.slice(7);

    // Verify token with Supabase
    const {
      data: { user },
      error,
    } = await supabaseAnon.auth.getUser(token);

    if (error || !user) {
      return res.status(401).json({
        error: 'unauthorized',
        message: 'Invalid or expired token',
      });
    }

    req.user = user;
    next();
  } catch (err) {
    return res.status(401).json({
      error: 'unauthorized',
      message: 'Token verification failed',
    });
  }
}

export async function verifyWebhook(req, res, next) {
  // Webhooks don't require auth (they have their own signature verification)
  next();
}

// Every account can book. 'provider' means the account has added a provider profile.
export function requireRole(role) {
  return async (req, res, next) => {
    try {
      const userId = req.user?.id;
      if (!userId) {
        return res.status(401).json({
          error: 'unauthorized',
          message: 'User not authenticated',
        });
      }

      // Service role because RLS hides these rows from the anon client; the user is already verified above.
      const table = role === 'provider' ? 'provider_statuses' : 'profiles';
      const { data, error } = await supabase
        .from(table)
        .select('id')
        .eq('id', userId)
        .maybeSingle();

      if (error) {
        return res.status(500).json({
          error: 'internal_server_error',
          message: 'Role verification failed',
        });
      }

      if (!data) {
        return res.status(403).json(
          role === 'provider'
            ? { error: 'not_a_provider', message: 'Add a provider profile to use provider features' }
            : { error: 'forbidden', message: 'User profile not found' }
        );
      }

      next();
    } catch (err) {
      return res.status(403).json({
        error: 'forbidden',
        message: 'Role verification failed',
      });
    }
  };
}

export default { verifyAuth, verifyWebhook, requireRole };
