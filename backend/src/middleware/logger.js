import config from '../config.js';

const LOG_LEVELS = {
  debug: 0,
  info: 1,
  warn: 2,
  error: 3,
};

const currentLogLevel = LOG_LEVELS[config.server.logLevel] || LOG_LEVELS.info;

export function logMessage(level, message, data = {}) {
  if (LOG_LEVELS[level] < currentLogLevel) {
    return;
  }

  const timestamp = new Date().toISOString();
  const logEntry = {
    timestamp,
    level,
    message,
    ...data,
  };

  if (config.server.logLevel === 'json' || process.env.LOG_FORMAT === 'json') {
    console.log(JSON.stringify(logEntry));
  } else {
    console.log(`[${timestamp}] ${level.toUpperCase()}: ${message}`, data);
  }
}

export function requestLogger(req, res, next) {
  const startTime = Date.now();

  req.requestId = generateRequestId();

  const originalSend = res.send;
  res.send = function (data) {
    const duration = Date.now() - startTime;
    const level = res.statusCode < 400 ? 'info' : res.statusCode < 500 ? 'warn' : 'error';

    logMessage(level, `${req.method} ${req.path}`, {
      status: res.statusCode,
      duration: `${duration}ms`,
      userId: req.user?.id,
      requestId: req.requestId,
      userAgent: req.headers['user-agent'],
    });

    return originalSend.call(this, data);
  };

  next();
}

function generateRequestId() {
  return `${Date.now()}-${Math.random().toString(36).substr(2, 9)}`;
}

export const logger = {
  debug: (msg, data) => logMessage('debug', msg, data),
  info: (msg, data) => logMessage('info', msg, data),
  warn: (msg, data) => logMessage('warn', msg, data),
  error: (msg, data) => logMessage('error', msg, data),
};

export default { requestLogger, logMessage, logger };
