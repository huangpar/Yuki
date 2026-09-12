// Core validation functions
export const validators = {
  // String validations
  isString: (value) => typeof value === 'string',
  isEmail: (value) => /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(value),
  // Runs after the normalizePhone sanitizer, so a valid US number is already "+1XXXXXXXXXX".
  isPhone: (value) => typeof value === 'string' && /^\+1\d{10}$/.test(value),
  isUUID: (value) => /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(value),
  isURL: (value) => {
    try {
      new URL(value);
      return true;
    } catch {
      return false;
    }
  },

  // Numeric validations
  isNumber: (value) => typeof value === 'number' && !isNaN(value),
  isPositive: (value) => validators.isNumber(value) && value > 0,
  isPrice: (value) => {
    if (!validators.isNumber(value)) return false;
    return value > 0 && /^\d+(\.\d{1,2})?$/.test(value.toString());
  },
  isInteger: (value) => Number.isInteger(value),
  isInRange: (value, min, max) => validators.isNumber(value) && value >= min && value <= max,

  // Coordinate validations
  isLatitude: (value) => validators.isInRange(value, -90, 90),
  isLongitude: (value) => validators.isInRange(value, -180, 180),
  isDistance: (value) => validators.isPositive(value) && value <= 1000,

  // Date validations
  isISO8601: (value) => {
    if (!(value instanceof Date || typeof value === 'string')) return false;
    const date = new Date(value);
    return !isNaN(date.getTime()) && value === date.toISOString().split('T')[0] + 'T' + date.toISOString().split('T')[1].substring(0, 8) + 'Z' || value.match(/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z$/);
  },
  isFutureDate: (value) => new Date(value) > new Date(),
  isDateInRange: (value, days) => {
    const date = new Date(value);
    const now = new Date();
    const maxDate = new Date(now.getTime() + days * 24 * 60 * 60 * 1000);
    return date > now && date < maxDate;
  },

  // Array validations
  isArray: (value) => Array.isArray(value),
  isArrayOfStrings: (value) => Array.isArray(value) && value.every((v) => typeof v === 'string'),
  isArrayOfUUIDs: (value) => Array.isArray(value) && value.every((v) => validators.isUUID(v)),
  hasLength: (value, length) => validators.isArray(value) && value.length === length,
  hasMinLength: (value, min) => validators.isArray(value) && value.length >= min,
  hasMaxLength: (value, max) => validators.isArray(value) && value.length <= max,

  // String length validations
  hasStringLength: (value, length) => typeof value === 'string' && value.length === length,
  hasStringMinLength: (value, min) => typeof value === 'string' && value.length >= min,
  hasStringMaxLength: (value, max) => typeof value === 'string' && value.length <= max,

  // Enum/choice validation
  isIn: (value, choices) => choices.includes(value),

  // Object validations
  isObject: (value) => typeof value === 'object' && value !== null && !Array.isArray(value),
  hasProperty: (obj, prop) => obj && typeof obj === 'object' && prop in obj,
};

// Sanitization functions
export const sanitizers = {
  trim: (value) => (typeof value === 'string' ? value.trim() : value),
  lowercase: (value) => (typeof value === 'string' ? value.toLowerCase() : value),
  uppercase: (value) => (typeof value === 'string' ? value.toUpperCase() : value),

  // Remove dangerous characters
  escapeHTML: (value) => {
    if (typeof value !== 'string') return value;
    const map = {
      '&': '&amp;',
      '<': '&lt;',
      '>': '&gt;',
      '"': '&quot;',
      "'": '&#039;',
    };
    return value.replace(/[&<>"']/g, (char) => map[char]);
  },

  // Remove whitespace
  removeWhitespace: (value) => (typeof value === 'string' ? value.replace(/\s/g, '') : value),

  // Normalize phone number
  normalizePhone: (value) => {
    if (typeof value !== 'string') return value;
    const digits = value.replace(/\D/g, '');
    if (digits.length === 10) return `+1${digits}`;
    if (digits.length === 11 && digits[0] === '1') return `+${digits}`;
    return `+${digits}`;
  },

  // Convert to number
  toNumber: (value) => {
    const num = Number(value);
    return isNaN(num) ? value : num;
  },

  // Convert to boolean
  toBoolean: (value) => {
    if (typeof value === 'boolean') return value;
    if (typeof value === 'string') return value.toLowerCase() === 'true';
    return Boolean(value);
  },

  // Convert to integer
  toInteger: (value) => {
    const num = parseInt(value, 10);
    return isNaN(num) ? value : num;
  },
};

// Validation result class
export class ValidationResult {
  constructor() {
    this.errors = {};
    this.isValid = true;
  }

  addError(field, message) {
    if (!this.errors[field]) {
      this.errors[field] = [];
    }
    this.errors[field].push(message);
    this.isValid = false;
  }

  hasError(field) {
    return field in this.errors && this.errors[field].length > 0;
  }

  getErrors(field) {
    return this.errors[field] || [];
  }

  toJSON() {
    return {
      valid: this.isValid,
      errors: this.errors,
    };
  }
}

// Validate a field
export function validateField(value, rules, fieldName = 'field') {
  const result = new ValidationResult();

  if (!rules) return result;

  if (value === undefined || value === null || value === '') {
    if (rules.required) {
      result.addError(fieldName, 'This field is required');
    }
    return result;
  }

  // Type validation
  if (rules.type) {
    const typeMap = {
      string: validators.isString,
      number: validators.isNumber,
      integer: validators.isInteger,
      boolean: (v) => typeof v === 'boolean',
      array: validators.isArray,
      object: validators.isObject,
      email: validators.isEmail,
      phone: validators.isPhone,
      uuid: validators.isUUID,
      url: validators.isURL,
      date: validators.isISO8601,
    };

    const typeValidator = typeMap[rules.type];
    if (typeValidator && !typeValidator(value)) {
      result.addError(fieldName, `Must be a valid ${rules.type}`);
      return result;
    }
  }

  // Length validations
  if (rules.minLength && !validators.hasStringMinLength(value, rules.minLength)) {
    result.addError(fieldName, `Must be at least ${rules.minLength} characters`);
  }
  if (rules.maxLength && !validators.hasStringMaxLength(value, rules.maxLength)) {
    result.addError(fieldName, `Must be at most ${rules.maxLength} characters`);
  }

  // Array length validations
  if (rules.minItems && !validators.hasMinLength(value, rules.minItems)) {
    result.addError(fieldName, `Must have at least ${rules.minItems} items`);
  }
  if (rules.maxItems && !validators.hasMaxLength(value, rules.maxItems)) {
    result.addError(fieldName, `Must have at most ${rules.maxItems} items`);
  }

  // Numeric validations
  if (rules.min !== undefined && !validators.isInRange(value, rules.min, Infinity)) {
    result.addError(fieldName, `Must be at least ${rules.min}`);
  }
  if (rules.max !== undefined && !validators.isInRange(value, -Infinity, rules.max)) {
    result.addError(fieldName, `Must be at most ${rules.max}`);
  }

  // Enum validation
  if (rules.enum && !validators.isIn(value, rules.enum)) {
    result.addError(fieldName, `Must be one of: ${rules.enum.join(', ')}`);
  }

  // Pattern validation
  if (rules.pattern && !new RegExp(rules.pattern).test(value)) {
    result.addError(fieldName, rules.patternMessage || 'Invalid format');
  }

  // Custom validation
  if (rules.custom && typeof rules.custom === 'function') {
    const customError = rules.custom(value);
    if (customError) {
      result.addError(fieldName, customError);
    }
  }

  return result;
}

// Validate an object against a schema
export function validateObject(obj, schema) {
  const result = new ValidationResult();

  if (!schema || !obj) {
    result.isValid = true;
    return result;
  }

  Object.entries(schema).forEach(([fieldName, rules]) => {
    const fieldValue = obj[fieldName];
    const fieldResult = validateField(fieldValue, rules, fieldName);

    if (!fieldResult.isValid) {
      Object.entries(fieldResult.errors).forEach(([key, messages]) => {
        messages.forEach((msg) => result.addError(key, msg));
      });
    }
  });

  return result;
}

// Sanitize an object
export function sanitizeObject(obj, schema) {
  if (!obj || !schema) return obj;

  const sanitized = { ...obj };

  Object.entries(schema).forEach(([fieldName, rules]) => {
    if (!(fieldName in sanitized)) return;

    let value = sanitized[fieldName];

    // Apply sanitizers in order
    if (rules.sanitize) {
      if (Array.isArray(rules.sanitize)) {
        rules.sanitize.forEach((sanitizer) => {
          if (typeof sanitizer === 'string' && sanitizers[sanitizer]) {
            value = sanitizers[sanitizer](value);
          } else if (typeof sanitizer === 'function') {
            value = sanitizer(value);
          }
        });
      } else if (typeof rules.sanitize === 'string' && sanitizers[rules.sanitize]) {
        value = sanitizers[rules.sanitize](value);
      }
    }

    sanitized[fieldName] = value;
  });

  return sanitized;
}

export default {
  validators,
  sanitizers,
  ValidationResult,
  validateField,
  validateObject,
  sanitizeObject,
};
