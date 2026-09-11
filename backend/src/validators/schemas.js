// Request validation schemas for Yuki API endpoints

export const schemas = {
  // Authentication schemas
  signup: {
    email: {
      type: 'email',
      required: true,
      sanitize: ['trim', 'lowercase'],
    },
    password: {
      type: 'string',
      required: true,
      minLength: 8,
      custom: (value) => {
        if (!/[A-Z]/.test(value)) return 'Password must contain uppercase letter';
        if (!/[a-z]/.test(value)) return 'Password must contain lowercase letter';
        if (!/[0-9]/.test(value)) return 'Password must contain number';
        return null;
      },
    },
    first_name: {
      type: 'string',
      required: true,
      minLength: 1,
      maxLength: 100,
      sanitize: ['trim'],
    },
    last_name: {
      type: 'string',
      required: true,
      minLength: 1,
      maxLength: 100,
      sanitize: ['trim'],
    },
    phone: {
      type: 'phone',
      required: true,
      sanitize: ['normalizePhone'],
    },
    role: {
      type: 'string',
      required: true,
      enum: ['customer', 'provider'],
      sanitize: ['lowercase'],
    },
  },

  signin: {
    email: {
      type: 'email',
      required: true,
      sanitize: ['trim', 'lowercase'],
    },
    password: {
      type: 'string',
      required: true,
    },
  },

  // Customer schemas
  updateProfile: {
    first_name: {
      type: 'string',
      minLength: 1,
      maxLength: 100,
      sanitize: ['trim'],
    },
    last_name: {
      type: 'string',
      minLength: 1,
      maxLength: 100,
      sanitize: ['trim'],
    },
    phone: {
      type: 'phone',
      sanitize: ['normalizePhone'],
    },
  },

  completeProfile: {
    first_name: {
      type: 'string',
      required: true,
      minLength: 1,
      maxLength: 100,
      sanitize: ['trim'],
    },
    last_name: {
      type: 'string',
      required: true,
      minLength: 1,
      maxLength: 100,
      sanitize: ['trim'],
    },
    phone: {
      type: 'phone',
      required: true,
      sanitize: ['normalizePhone'],
    },
    offer_services: {
      type: 'boolean',
    },
  },

  nearbyProviders: {
    latitude: {
      type: 'number',
      required: true,
      custom: (value) => {
        if (value < -90 || value > 90) return 'Latitude must be between -90 and 90';
        return null;
      },
    },
    longitude: {
      type: 'number',
      required: true,
      custom: (value) => {
        if (value < -180 || value > 180) return 'Longitude must be between -180 and 180';
        return null;
      },
    },
    radius: {
      type: 'integer',
      min: 1,
      max: 50,
      custom: (value) => {
        if (value && !Number.isInteger(value)) return 'Radius must be an integer';
        return null;
      },
    },
    category: {
      type: 'string',
      sanitize: ['lowercase', 'trim'],
    },
  },

  createBooking: {
    provider_id: {
      type: 'uuid',
      required: true,
    },
    service_category: {
      type: 'string',
      required: true,
      minLength: 1,
      maxLength: 50,
      sanitize: ['trim', 'lowercase'],
    },
    description: {
      type: 'string',
      required: true,
      minLength: 10,
      maxLength: 1000,
      sanitize: ['trim'],
    },
    address: {
      type: 'string',
      required: true,
      minLength: 5,
      maxLength: 255,
      sanitize: ['trim'],
    },
    latitude: {
      type: 'number',
      required: true,
      custom: (value) => {
        if (value < -90 || value > 90) return 'Invalid latitude';
        return null;
      },
    },
    longitude: {
      type: 'number',
      required: true,
      custom: (value) => {
        if (value < -180 || value > 180) return 'Invalid longitude';
        return null;
      },
    },
    asap: {
      type: 'boolean',
    },
    scheduled_for: {
      type: 'date',
      custom: (value) => {
        if (new Date(value) < new Date()) return 'Booking must be in the future';
        return null;
      },
    },
    estimated_duration_minutes: {
      type: 'integer',
      required: true,
      min: 15,
      max: 480,
    },
  },

  // Provider schemas
  updateProviderProfile: {
    bio: {
      type: 'string',
      minLength: 0,
      maxLength: 500,
      sanitize: ['trim'],
    },
    hourly_rate: {
      type: 'number',
      min: 10,
      max: 500,
      custom: (value) => {
        if (value && !/^\d+(\.\d{1,2})?$/.test(value.toString())) return 'Rate must have at most 2 decimal places';
        return null;
      },
    },
    categories: {
      type: 'array',
      minItems: 1,
      maxItems: 10,
      custom: (value) => {
        if (!Array.isArray(value)) return 'Categories must be an array';
        if (!value.every((cat) => typeof cat === 'string' && cat.length > 0)) return 'Each category must be a non-empty string';
        return null;
      },
      sanitize: ['lowercase'],
    },
  },

  toggleAvailability: {
    available: {
      type: 'boolean',
      required: true,
    },
    latitude: {
      type: 'number',
      custom: (value) => {
        if (value !== undefined && (value < -90 || value > 90)) return 'Invalid latitude';
        return null;
      },
    },
    longitude: {
      type: 'number',
      custom: (value) => {
        if (value !== undefined && (value < -180 || value > 180)) return 'Invalid longitude';
        return null;
      },
    },
  },

  updateLocation: {
    latitude: {
      type: 'number',
      required: true,
      custom: (value) => {
        if (value < -90 || value > 90) return 'Invalid latitude';
        return null;
      },
    },
    longitude: {
      type: 'number',
      required: true,
      custom: (value) => {
        if (value < -180 || value > 180) return 'Invalid longitude';
        return null;
      },
    },
  },

  acceptBooking: {
    estimated_arrival_minutes: {
      type: 'integer',
      min: 1,
      max: 180,
    },
  },

  completeBooking: {
    actual_duration_minutes: {
      type: 'integer',
      min: 1,
      max: 480,
    },
    notes: {
      type: 'string',
      maxLength: 500,
      sanitize: ['trim'],
    },
  },

  // Payment schemas
  createPaymentIntent: {
    booking_id: {
      type: 'uuid',
      required: true,
    },
    amount: {
      type: 'number',
      required: true,
      min: 0.01,
      custom: (value) => {
        if (!/^\d+(\.\d{1,2})?$/.test(value.toString())) return 'Amount must have at most 2 decimal places';
        return null;
      },
    },
    currency: {
      type: 'string',
      required: true,
      enum: ['usd'],
      sanitize: ['uppercase'],
    },
    idempotency_key: {
      type: 'string',
      required: true,
      minLength: 10,
      maxLength: 255,
      sanitize: ['trim'],
    },
  },

  confirmPayment: {
    payment_intent_id: {
      type: 'string',
      required: true,
      minLength: 10,
      sanitize: ['trim'],
    },
    payment_method_id: {
      type: 'string',
      required: true,
      minLength: 10,
      sanitize: ['trim'],
    },
  },

  // Dispute schemas
  createDispute: {
    booking_id: {
      type: 'uuid',
      required: true,
    },
    reason: {
      type: 'string',
      required: true,
      enum: ['service_not_provided', 'provider_no_show', 'quality_issue', 'safety_concern', 'other'],
      sanitize: ['lowercase'],
    },
    description: {
      type: 'string',
      required: true,
      minLength: 20,
      maxLength: 2000,
      sanitize: ['trim'],
    },
    evidence_urls: {
      type: 'array',
      maxItems: 10,
      custom: (value) => {
        if (!Array.isArray(value)) return 'Evidence must be an array';
        if (!value.every((url) => typeof url === 'string' && /^https?:\/\/.+/.test(url))) {
          return 'Each evidence item must be a valid URL';
        }
        return null;
      },
    },
  },

  providerResponse: {
    message: {
      type: 'string',
      required: true,
      minLength: 10,
      maxLength: 1000,
      sanitize: ['trim'],
    },
  },

  // Background check schemas
  initiateBackgroundCheck: {
    first_name: {
      type: 'string',
      required: true,
      minLength: 1,
      maxLength: 100,
      sanitize: ['trim'],
    },
    last_name: {
      type: 'string',
      required: true,
      minLength: 1,
      maxLength: 100,
      sanitize: ['trim'],
    },
    date_of_birth: {
      type: 'string',
      required: true,
      custom: (value) => {
        if (!/^\d{4}-\d{2}-\d{2}$/.test(value)) return 'Date of birth must be in YYYY-MM-DD format';
        const age = new Date().getFullYear() - new Date(value).getFullYear();
        if (age < 18) return 'Must be at least 18 years old';
        return null;
      },
    },
    ssn: {
      type: 'string',
      required: true,
      custom: (value) => {
        if (!/^\d{3}-\d{2}-\d{4}$/.test(value) && !/^\d{9}$/.test(value)) {
          return 'SSN must be in format XXX-XX-XXXX';
        }
        return null;
      },
    },
    driver_license_number: {
      type: 'string',
      required: true,
      minLength: 5,
      maxLength: 20,
      sanitize: ['trim', 'uppercase'],
    },
    driver_license_state: {
      type: 'string',
      required: true,
      minLength: 2,
      maxLength: 2,
      sanitize: ['uppercase'],
    },
  },

  backgroundCheckDispute: {
    reason: {
      type: 'string',
      required: true,
      minLength: 20,
      maxLength: 1000,
      sanitize: ['trim'],
    },
    evidence_urls: {
      type: 'array',
      maxItems: 5,
      custom: (value) => {
        if (!Array.isArray(value)) return 'Evidence must be an array';
        if (!value.every((url) => typeof url === 'string' && /^https?:\/\/.+/.test(url))) {
          return 'Each evidence item must be a valid URL';
        }
        return null;
      },
    },
  },
};

export default schemas;
