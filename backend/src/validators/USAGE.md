# Input Validation & Sanitization - Usage Guide

## Overview

Yuki's validation system protects against:
- SQL injection
- XSS attacks
- Invalid data types
- Out-of-range values
- Malformed requests

All validation happens **before** data reaches the database.

---

## Basic Usage

### 1. Express Middleware (Recommended)

Use validation middleware on your routes:

```javascript
import { validateBody, validateQuery } from './middleware/validation.js';
import { schemas } from './validators/schemas.js';

// Signup endpoint
app.post('/api/auth/signup',
  validateBody(schemas.signup),
  async (req, res) => {
    const { email, password, first_name, last_name, phone, role } = req.body;
    // Data is already validated and sanitized
  }
);

// Search nearby providers
app.get('/api/customers/nearby-providers',
  validateQuery(schemas.nearbyProviders),
  async (req, res) => {
    const { latitude, longitude, radius, category } = req.query;
    // Query parameters are validated
  }
);

// Booking with path params + body
app.post('/api/bookings/:booking_id/accept',
  validateParams({ booking_id: { type: 'uuid', required: true } }),
  validateBody(schemas.acceptBooking),
  async (req, res) => {
    const { booking_id } = req.params;
    const { estimated_arrival_minutes } = req.body;
  }
);
```

### 2. Manual Validation

Validate data manually when needed:

```javascript
import { validateObject, sanitizeObject } from './validators/index.js';
import { schemas } from './validators/schemas.js';

// Sanitize and validate
const sanitized = sanitizeObject(userData, schemas.signup);
const validation = validateObject(sanitized, schemas.signup);

if (!validation.isValid) {
  return res.status(400).json({
    error: 'validation_error',
    errors: validation.errors,
  });
}

// Proceed with validated data
```

### 3. Individual Field Validation

Validate single fields:

```javascript
import { validateField } from './validators/index.js';

const result = validateField(email, { type: 'email', required: true }, 'email');

if (!result.isValid) {
  console.error('Invalid email:', result.getErrors('email'));
}
```

---

## Available Validators

### String Validators

```javascript
validators.isString(value)           // Is a string
validators.isEmail(value)            // Valid email format
validators.isPhone(value)            // E.164 phone format: +1XXXXXXXXXX
validators.isURL(value)              // Valid URL
validators.isUUID(value)             // UUID v4 format
```

### Numeric Validators

```javascript
validators.isNumber(value)           // Is a number
validators.isInteger(value)          // Is an integer
validators.isPositive(value)         // Is positive
validators.isPrice(value)            // Decimal with max 2 places
validators.isInRange(value, min, max) // Within range
```

### Coordinate Validators

```javascript
validators.isLatitude(value)         // -90 to 90
validators.isLongitude(value)        // -180 to 180
validators.isDistance(value)         // Positive, <= 1000 miles
```

### Date Validators

```javascript
validators.isISO8601(value)          // ISO 8601 format
validators.isFutureDate(value)       // After now
validators.isDateInRange(value, days) // Within X days
```

### Array Validators

```javascript
validators.isArray(value)            // Is array
validators.isArrayOfStrings(value)   // Array of strings
validators.isArrayOfUUIDs(value)     // Array of UUIDs
validators.hasLength(value, length)  // Exact length
validators.hasMinLength(value, min)  // Min length
validators.hasMaxLength(value, max)  // Max length
```

### Enum Validators

```javascript
validators.isIn(value, choices)      // One of choices
```

---

## Available Sanitizers

### String Sanitizers

```javascript
sanitizers.trim(value)               // Remove whitespace
sanitizers.lowercase(value)          // Convert to lowercase
sanitizers.uppercase(value)          // Convert to uppercase
sanitizers.escapeHTML(value)         // Escape HTML chars (<>&"')
sanitizers.removeWhitespace(value)   // Remove all whitespace
```

### Format Sanitizers

```javascript
sanitizers.normalizePhone(value)     // Convert to E.164: +1XXXXXXXXXX
sanitizers.toNumber(value)           // Convert to number
sanitizers.toBoolean(value)          // Convert to boolean
sanitizers.toInteger(value)          // Convert to integer
```

---

## Schema Definition

Schemas define validation and sanitization rules:

```javascript
const userSchema = {
  email: {
    type: 'email',                   // Validation type
    required: true,                  // Must be present
    sanitize: ['trim', 'lowercase'], // Applied in order
  },
  
  password: {
    type: 'string',
    required: true,
    minLength: 8,
    maxLength: 128,
    custom: (value) => {             // Custom validation
      if (!/[A-Z]/.test(value)) {
        return 'Must contain uppercase letter';
      }
      return null; // null = valid
    },
  },

  age: {
    type: 'integer',
    min: 18,
    max: 150,
  },

  categories: {
    type: 'array',
    minItems: 1,
    maxItems: 5,
    sanitize: ['lowercase'],
  },
};
```

### Schema Options

| Option | Type | Description |
|--------|------|-------------|
| `type` | string | Validation type (string, email, number, uuid, date, array, etc.) |
| `required` | boolean | Field must be present and not empty |
| `minLength` | number | Minimum string length |
| `maxLength` | number | Maximum string length |
| `minItems` | number | Minimum array length |
| `maxItems` | number | Maximum array length |
| `min` | number | Minimum numeric value |
| `max` | number | Maximum numeric value |
| `enum` | array | Allowed values |
| `pattern` | string | Regex pattern to match |
| `patternMessage` | string | Error message for pattern failure |
| `custom` | function | Custom validation function |
| `sanitize` | string\|array | Sanitizer name(s) to apply |

---

## Real-World Examples

### Signup Endpoint

```javascript
import express from 'express';
import { validateBody } from './middleware/validation.js';
import { schemas } from './validators/schemas.js';

const app = express();

app.post('/api/auth/signup', 
  validateBody(schemas.signup),
  async (req, res, next) => {
    try {
      // Data is already validated and sanitized:
      // - email: trimmed, lowercase, valid format
      // - password: checked for complexity
      // - names: trimmed
      // - phone: normalized to +1XXXXXXXXXX
      // - role: lowercase, validated to 'customer' or 'provider'
      
      const user = await createUser(req.body);
      res.status(201).json(user);
    } catch (err) {
      next(err);
    }
  }
);
```

### Search with Pagination

```javascript
app.get('/api/customers/nearby-providers',
  validateQuery({
    latitude: {
      type: 'number',
      required: true,
      custom: (v) => v < -90 || v > 90 ? 'Invalid latitude' : null,
    },
    longitude: {
      type: 'number',
      required: true,
      custom: (v) => v < -180 || v > 180 ? 'Invalid longitude' : null,
    },
    radius: {
      type: 'integer',
      min: 1,
      max: 50,
    },
    limit: {
      type: 'integer',
      min: 1,
      max: 100,
    },
    offset: {
      type: 'integer',
      min: 0,
    },
  }),
  async (req, res, next) => {
    const { latitude, longitude, radius = 5, limit = 20, offset = 0 } = req.query;
    // All parameters validated and normalized
    const providers = await searchProviders({ latitude, longitude, radius, limit, offset });
    res.json(providers);
  }
);
```

### Payment with Idempotency

```javascript
app.post('/api/payments/intent',
  validateBody({
    booking_id: { type: 'uuid', required: true },
    amount: {
      type: 'number',
      required: true,
      min: 0.01,
      custom: (v) => {
        // Ensure 2 decimal places max
        if (!/^\d+(\.\d{1,2})?$/.test(v.toString())) {
          return 'Amount must have at most 2 decimal places';
        }
        return null;
      },
    },
    idempotency_key: {
      type: 'string',
      required: true,
      minLength: 10,
      maxLength: 255,
      sanitize: ['trim'],
    },
  }),
  async (req, res, next) => {
    const { booking_id, amount, idempotency_key } = req.body;
    
    // Check for duplicate with same idempotency key
    const existing = await getPaymentByIdempotencyKey(idempotency_key);
    if (existing) {
      return res.json(existing);
    }
    
    const paymentIntent = await createPaymentIntent({ booking_id, amount });
    res.status(201).json(paymentIntent);
  }
);
```

### Dispute Filing (Complex)

```javascript
app.post('/api/disputes',
  validateBody(schemas.createDispute),
  async (req, res, next) => {
    try {
      const { booking_id, reason, description, evidence_urls } = req.body;
      
      // Check if booking exists and is owned by customer
      const booking = await getBooking(booking_id);
      if (!booking || booking.customer_id !== req.user.id) {
        return res.status(404).json({ error: 'Booking not found' });
      }
      
      // Check if within 48-hour window
      const hoursAgo = (new Date() - booking.completed_at) / (1000 * 60 * 60);
      if (hoursAgo > 48) {
        return res.status(409).json({
          error: 'dispute_deadline_passed',
          message: 'Disputes must be filed within 48 hours',
        });
      }
      
      // Data already validated:
      // - booking_id: valid UUID
      // - reason: one of approved values
      // - description: 20-2000 chars, trimmed
      // - evidence_urls: valid URLs, max 10
      
      const dispute = await createDispute({
        booking_id,
        customer_id: req.user.id,
        reason,
        description,
        evidence_urls,
      });
      
      res.status(201).json(dispute);
    } catch (err) {
      next(err);
    }
  }
);
```

---

## Error Responses

When validation fails, requests get a 400 response:

```json
{
  "error": "validation_error",
  "message": "Request validation failed",
  "status": 400,
  "timestamp": "2026-09-08T13:40:00Z",
  "errors": {
    "email": [
      "Must be a valid email"
    ],
    "password": [
      "Must be at least 8 characters",
      "Must contain uppercase letter"
    ],
    "phone": [
      "Must be a valid phone"
    ]
  }
}
```

---

## Best Practices

1. **Always validate at API boundaries** — Never trust user input
2. **Sanitize before validation** — Clean data first, then validate
3. **Use pre-defined schemas** — Reuse schemas across endpoints
4. **Validate combined data** — Check cross-field constraints in `custom`
5. **Clear error messages** — Help developers debug
6. **Type hints in code** — Document what data looks like after validation
7. **Log validation failures** — Track attack patterns
8. **Test edge cases** — Empty strings, very long inputs, special chars

---

## Security Checklist

- [x] All email inputs validated
- [x] All passwords checked for complexity
- [x] All UUIDs validated
- [x] All coordinates validated (lat/lon bounds)
- [x] All prices rounded to 2 decimals
- [x] All URLs validated
- [x] All arrays bounded (min/max length)
- [x] All strings escaped/trimmed
- [x] All enums checked against allowed values
- [x] All phone numbers normalized

