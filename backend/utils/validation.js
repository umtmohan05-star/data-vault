const Joi = require('joi');
const logger = require('./logger');

// Validation schemas
const schemas = {
    registerPatient: Joi.object({
        name: Joi.string().required(),
        dateOfBirth: Joi.string().required(),
        phone: Joi.string().required(),
        aadharNumber: Joi.string().length(12).required(),
        password: Joi.string().min(8).required(),
        fingerprintTemplateID: Joi.number().required()
    }),

    registerDoctor: Joi.object({
        name: Joi.string().required(),
        licenseNumber: Joi.string().required(),
        specialization: Joi.string().required(),
        hospitalName: Joi.string().required(),
        password: Joi.string().min(8).required()
    }),

    loginPatient: Joi.object({
        patientId: Joi.string().required(), // This is what we expect
        password: Joi.string().required()
    }),

    loginDoctor: Joi.object({
        doctorId: Joi.string().required(),
        password: Joi.string().required()
    }),

    grantAccess: Joi.object({
        patientID: Joi.string().required(),
        doctorID: Joi.string().required(),
        durationHours: Joi.number().integer().min(1).required(),
        purpose: Joi.string().required()
    }),

    revokeAccess: Joi.object({
        accessKey: Joi.string().required()
    })
};

// Validation middleware
const validate = (schemaName) => {
    return (req, res, next) => {
        const schema = schemas[schemaName];
        
        if (!schema) {
            logger.error(`Validation schema '${schemaName}' not found`);
            return res.status(500).json({
                success: false,
                error: 'Internal validation error'
            });
        }

        const { error, value } = schema.validate(req.body, {
            abortEarly: false, // Get all errors, not just the first
            stripUnknown: true  // Remove unknown fields
        });

        if (error) {
            const errorDetails = error.details.map(detail => ({
                field: detail.path.join('.'),
                message: detail.message
            }));

            logger.error(`Validation failed for ${schemaName}:`, errorDetails);

            return res.status(400).json({
                success: false,
                error: 'Validation error',
                details: errorDetails
            });
        }

        // Replace req.body with validated and sanitized value
        req.body = value;
        next();
    };
};

module.exports = { validate };
