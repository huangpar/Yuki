import { validateObject, sanitizeObject } from '../validators/index.js';
import { ApiError } from './errorHandler.js';

// Middleware factory for validating request body
export function validateBody(schema) {
  return (req, res, next) => {
    // Sanitize request body
    req.body = sanitizeObject(req.body, schema);

    // Validate request body
    const result = validateObject(req.body, schema);

    if (!result.isValid) {
      return res.status(400).json({
        error: 'validation_error',
        message: 'Request validation failed',
        status: 400,
        timestamp: new Date().toISOString(),
        errors: result.errors,
      });
    }

    next();
  };
}

// Middleware factory for validating query parameters
export function validateQuery(schema) {
  return (req, res, next) => {
    // Parse and sanitize query
    const query = sanitizeObject(req.query, schema);

    // Validate query
    const result = validateObject(query, schema);

    if (!result.isValid) {
      return res.status(400).json({
        error: 'validation_error',
        message: 'Query parameter validation failed',
        status: 400,
        timestamp: new Date().toISOString(),
        errors: result.errors,
      });
    }

    req.query = query;
    next();
  };
}

// Middleware factory for validating path parameters
export function validateParams(schema) {
  return (req, res, next) => {
    // Sanitize params
    const params = sanitizeObject(req.params, schema);

    // Validate params
    const result = validateObject(params, schema);

    if (!result.isValid) {
      return res.status(400).json({
        error: 'validation_error',
        message: 'Path parameter validation failed',
        status: 400,
        timestamp: new Date().toISOString(),
        errors: result.errors,
      });
    }

    req.params = params;
    next();
  };
}

// Combine multiple validators
export function validate(bodySchema = null, querySchema = null, paramsSchema = null) {
  return (req, res, next) => {
    const errors = {};

    // Validate body
    if (bodySchema) {
      req.body = sanitizeObject(req.body, bodySchema);
      const bodyResult = validateObject(req.body, bodySchema);
      if (!bodyResult.isValid) {
        Object.assign(errors, bodyResult.errors);
      }
    }

    // Validate query
    if (querySchema) {
      req.query = sanitizeObject(req.query, querySchema);
      const queryResult = validateObject(req.query, querySchema);
      if (!queryResult.isValid) {
        Object.assign(errors, queryResult.errors);
      }
    }

    // Validate params
    if (paramsSchema) {
      req.params = sanitizeObject(req.params, paramsSchema);
      const paramsResult = validateObject(req.params, paramsSchema);
      if (!paramsResult.isValid) {
        Object.assign(errors, paramsResult.errors);
      }
    }

    // Return errors if any
    if (Object.keys(errors).length > 0) {
      return res.status(400).json({
        error: 'validation_error',
        message: 'Request validation failed',
        status: 400,
        timestamp: new Date().toISOString(),
        errors,
      });
    }

    next();
  };
}

export default {
  validateBody,
  validateQuery,
  validateParams,
  validate,
};
