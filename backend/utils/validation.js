const Joi = require('joi');

const schemas = {
    // ✅ FIXED: Removed patientID (auto-generated), added password, made fingerprintTemplateID optional
    registerPatient: Joi.object({
        name: Joi.string().required().min(2).max(100),
        dateOfBirth: Joi.string().required().pattern(/^\d{4}-\d{2}-\d{2}$/),
        phone: Joi.string().required().min(10).max(20),
        aadharNumber: Joi.string().required().length(12).pattern(/^[0-9]+$/),
        password: Joi.string().required().min(8).max(100),
        fingerprintTemplateID: Joi.number().optional().integer().positive()
    }),

    // ✅ FIXED: Removed doctorID (auto-generated), added password
    registerDoctor: Joi.object({
        name: Joi.string().required().min(2).max(100),
        licenseNumber: Joi.string().required().min(5).max(50),
        specialization: Joi.string().required().min(2).max(100),
        hospitalName: Joi.string().required().min(2).max(200),
        password: Joi.string().required().min(8).max(100)
    }),

    // Login validation schemas
    loginPatient: Joi.object({
        patientID: Joi.string().required().min(3).max(50),
        password: Joi.string().required()
    }),

    loginDoctor: Joi.object({
        doctorID: Joi.string().required().min(3).max(50),
        password: Joi.string().required()
    }),

    grantAccess: Joi.object({
        patientID: Joi.string().required(),
        doctorID: Joi.string().required(),
        durationHours: Joi.number().required().integer().min(1).max(720),
        purpose: Joi.string().required().min(5).max(500)
    }),

    revokeAccess: Joi.object({
        accessKey: Joi.string().required()
    })
};

function validate(schema) {
    return (req, res, next) => {
        const { error } = schemas[schema].validate(req.body);
        if (error) {
            return res.status(400).json({
                success: false,
                error: 'Validation error',
                details: error.details.map(d => d.message)
            });
        }
        next();
    };
}

module.exports = { validate, schemas };
