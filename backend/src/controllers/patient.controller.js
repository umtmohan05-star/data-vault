const { getContract } = require('../fabric/network');
const logger = require('../../utils/logger');
const authService = require('../services/auth.service');

// Register a new patient
exports.registerPatient = async (req, res) => {
    try {
        const {
            name,
            dateOfBirth,
            phone,
            aadharNumber,
            fingerprintTemplateID,
            password
        } = req.body;

        // Validate required fields
        if (!name || !dateOfBirth || !phone || !aadharNumber || !password) {
            return res.status(400).json({
                success: false,
                error: 'Missing required fields: name, dateOfBirth, phone, aadharNumber, password'
            });
        }

        logger.info('Registering new patient...');

        // Generate unique patient ID
        const patientID = `P${Math.floor(1000 + Math.random() * 9000)}`;

        // Get contract
        const { contract } = await getContract('hospitalApolloAdmin');

        // Register on blockchain
        await contract.submitTransaction(
            'RegisterPatient',
            patientID,
            name,
            dateOfBirth,
            phone,
            aadharNumber,
            fingerprintTemplateID?.toString() || '0'
        );

        // ✅ FIXED: Register in PostgreSQL with correct parameter format
        await authService.registerPatient({
            patientId: patientID,  // Note: patientId not patientID
            name,
            dateOfBirth,
            phone,
            aadharNumber,
            password,
            fingerprintTemplateId: fingerprintTemplateID || null
        });

        logger.info(`Patient registered successfully: ${patientID}`);

        res.status(201).json({
            success: true,
            message: 'Patient registered successfully',
            data: { patientID }
        });

    } catch (error) {
        logger.error(`Failed to register patient: ${error.message}`);
        res.status(500).json({
            success: false,
            error: 'Failed to register patient',
            details: error.message
        });
    }
};

// Get patient details
exports.getPatient = async (req, res) => {
    try {
        const { patientID } = req.params;

        logger.info(`Fetching patient: ${patientID}`);

        const { contract } = await getContract('admin');

        const result = await contract.evaluateTransaction(
            'GetPatient',
            patientID
        );

        const patient = JSON.parse(result.toString());

        res.status(200).json({
            success: true,
            data: patient
        });

    } catch (error) {
        logger.error(`Failed to get patient: ${error.message}`);
        
        if (error.message.includes('does not exist')) {
            return res.status(404).json({
                success: false,
                error: 'Patient not found',
                details: error.message
            });
        }

        res.status(500).json({
            success: false,
            error: 'Failed to retrieve patient',
            details: error.message
        });
    }
};

// Get audit trail for a patient
exports.getPatientAuditTrail = async (req, res) => {
    try {
        const { patientID } = req.params;

        logger.info(`Fetching audit trail for patient: ${patientID}`);

        const { contract } = await getContract('admin');

        const result = await contract.evaluateTransaction(
            'GetAuditTrail',
            patientID
        );

        const auditTrail = JSON.parse(result.toString());

        res.status(200).json({
            success: true,
            data: auditTrail,
            count: auditTrail.length
        });

    } catch (error) {
        logger.error(`Failed to get audit trail: ${error.message}`);
        res.status(500).json({
            success: false,
            error: 'Failed to retrieve audit trail',
            details: error.message
        });
    }
};

// Get active accesses for a patient
exports.getPatientAccesses = async (req, res) => {
    try {
        const { patientID } = req.params;

        logger.info(`Fetching active accesses for patient: ${patientID}`);

        const { contract } = await getContract('admin');

        const result = await contract.evaluateTransaction(
            'GetActiveAccessesForPatient',
            patientID
        );

        const resultString = result.toString();
        const accesses = resultString ? JSON.parse(resultString) : [];

        res.status(200).json({
            success: true,
            data: accesses,
            count: accesses.length
        });

    } catch (error) {
        logger.error(`Failed to get patient accesses: ${error.message}`);
        res.status(500).json({
            success: false,
            error: 'Failed to retrieve patient accesses',
            details: error.message
        });
    }
};
