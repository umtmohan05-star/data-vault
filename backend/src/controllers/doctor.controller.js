const { getContract } = require('../fabric/network');
const logger = require('../../utils/logger');
const authService = require('../services/auth.service');

// Register a new doctor
exports.registerDoctor = async (req, res) => {
    try {
        const { name, licenseNumber, specialization, hospitalName, password } = req.body;

        logger.info('Registering new doctor...');

        const doctorID = `D${Math.floor(1000 + Math.random() * 9000)}`;

        // Register on blockchain
        const { contract } = await getContract('hospitalApolloAdmin');
        await contract.submitTransaction(
            'RegisterDoctor',
            doctorID,
            name,
            licenseNumber,
            specialization,
            hospitalName
        );

        // Register in PostgreSQL
        await authService.registerDoctor({
            doctorId: doctorID,
            name,
            licenseNumber,
            specialization,
            hospitalName,
            password
        });

        logger.info(`Doctor registered successfully: ${doctorID}`);

        res.status(201).json({
            success: true,
            message: 'Doctor registered successfully',
            data: { doctorID }
        });

    } catch (error) {
        logger.error(`Failed to register doctor: ${error.message}`);
        res.status(500).json({
            success: false,
            error: 'Failed to register doctor',
            details: error.message
        });
    }
};

// ✅ NEW: Verify a doctor
exports.verifyDoctor = async (req, res) => {
    try {
        const { doctorID } = req.params;

        logger.info(`Verifying doctor: ${doctorID}`);

        // Connect using AuditOrgAdmin identity (only AuditOrg can verify)
        const { contract } = await getContract('auditOrgAdmin');
        
        await contract.submitTransaction('VerifyDoctor', doctorID);

        logger.info(`Doctor verified successfully: ${doctorID}`);

        res.status(200).json({
            success: true,
            message: 'Doctor verified successfully',
            data: { doctorID, verified: true }
        });

    } catch (error) {
        logger.error(`Failed to verify doctor: ${error.message}`);
        res.status(500).json({
            success: false,
            error: 'Failed to verify doctor',
            details: error.message
        });
    }
};

// Get doctor by ID
exports.getDoctor = async (req, res) => {
    try {
        const { doctorID } = req.params;

        logger.info(`Fetching doctor: ${doctorID}`);

        const { contract } = await getContract('hospitalApolloAdmin');
        const result = await contract.evaluateTransaction('GetDoctor', doctorID);
        const doctor = JSON.parse(result.toString());

        res.status(200).json({
            success: true,
            data: doctor
        });

    } catch (error) {
        logger.error(`Failed to get doctor: ${error.message}`);
        
        if (error.message.includes('does not exist')) {
            return res.status(404).json({
                success: false,
                error: 'Doctor not found',
                details: error.message
            });
        }

        res.status(500).json({
            success: false,
            error: 'Failed to retrieve doctor',
            details: error.message
        });
    }
};

// Get doctor access history
exports.getDoctorAccessHistory = async (req, res) => {
    try {
        const { doctorID } = req.params;

        logger.info(`Fetching access history for doctor: ${doctorID}`);

        const { contract } = await getContract('auditOrgAdmin');
        const result = await contract.evaluateTransaction('GetAuditTrail', doctorID);
        
        const history = JSON.parse(result.toString());

        res.status(200).json({
            success: true,
            data: history,
            count: history.length
        });

    } catch (error) {
        logger.error(`Failed to get doctor history: ${error.message}`);
        res.status(500).json({
            success: false,
            error: 'Failed to retrieve access history',
            details: error.message
        });
    }
};
