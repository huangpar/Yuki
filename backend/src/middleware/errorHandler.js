import { logMessage } from '../middleware/logger.js';

export function errorHandler(err, req, res, next) {
  const timestamp = new Date().toISOString();
  const requestId = req.requestId || 'unknown';

  // Determine error status code
  let statusCode = err.statusCode || err.status || 500;
  if (statusCode < 400 || statusCode > 599) {
    statusCode = 500;
  }

  // Determine error type
  const errorType = err.type || getErrorType(statusCode);

  // Prepare error response
  const errorResponse = {
    error: errorType,
    message: err.message || 'An unexpected error occurred',
    status: statusCode,
    timestamp,
    request_id: requestId,
  };

  // Include stack trace in development
  if (process.env.NODE_ENV === 'development' && err.stack) {
    errorResponse.stack = err.stack;
  }

  // Log the error
  logMessage('error', `${req.method} ${req.path} - ${statusCode}`, {
    error: err.message,
    type: errorType,
    stack: err.stack,
    requestId,
    userId: req.user?.id,
  });

  res.status(statusCode).json(errorResponse);
}

export function asyncHandler(fn) {
  return (req, res, next) => {
    Promise.resolve(fn(req, res, next)).catch(next);
  };
}

export class ApiError extends Error {
  constructor(message, statusCode = 500, type = null) {
    super(message);
    this.statusCode = statusCode;
    this.type = type || getErrorType(statusCode);
  }
}

function getErrorType(statusCode) {
  const types = {
    400: 'bad_request',
    401: 'unauthorized',
    403: 'forbidden',
    404: 'not_found',
    409: 'conflict',
    429: 'rate_limit_exceeded',
    500: 'internal_server_error',
    502: 'bad_gateway',
    503: 'service_unavailable',
  };
  return types[statusCode] || 'unknown_error';
}

export default { errorHandler, asyncHandler, ApiError };
