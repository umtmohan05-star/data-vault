const { getContract } = require('../fabric/network');
const logger = require('../../utils/logger');

// Grant access to a doctor
exports.grantAccess = async (req, res) => {
    try {
        const {
            patientID,
            doctorID,
            durationHours,
            purpose
        } = req.body;

        logger.info(`Granting access: Patient ${patientID} to Doctor ${doctorID}`);

        const { contract } = await getContract('admin');

        const result = await contract.submitTransaction(
            'GrantAccess',
            patientID,
            doctorID,
            durationHours.toString(),
            purpose
        );

        const accessKey = result.toString();

        logger.info(`Access granted successfully: ${accessKey}`);

        res.status(201).json({
            success: true,
            message: 'Access granted successfully',
            data: {
                accessKey,
                patientID,
                doctorID,
                durationHours,
                purpose
            }
        });

    } catch (error) {
        logger.error(`Failed to grant access: ${error.message}`);
        res.status(500).json({
            success: false,
            error: 'Failed to grant access',
            details: error.message
        });
    }
};

// Revoke access
exports.revokeAccess = async (req, res) => {
    try {
        const { accessKey } = req.params;

        logger.info(`Revoking access: ${accessKey}`);

        const { contract } = await getContract('admin');

        await contract.submitTransaction(
            'RevokeAccess',
            accessKey
        );

        logger.info(`Access revoked successfully: ${accessKey}`);

        res.status(200).json({
            success: true,
            message: 'Access revoked successfully',
            data: { accessKey, revoked: true }
        });

    } catch (error) {
        logger.error(`Failed to revoke access: ${error.message}`);
        
        if (error.message.includes('not found')) {
            return res.status(404).json({
                success: false,
                error: 'Access key not found',
                details: error.message
            });
        }

        res.status(500).json({
            success: false,
            error: 'Failed to revoke access',
            details: error.message
        });
    }
};

// Check access validity
exports.checkAccessValidity = async (req, res) => {
    try {
        const { accessKey } = req.params;

        logger.info(`Checking access validity: ${accessKey}`);

        const { contract } = await getContract('admin');

        const result = await contract.evaluateTransaction(
            'CheckAccessValidity',
            accessKey
        );

        const validity = JSON.parse(result.toString());

        res.status(200).json({
            success: true,
            data: validity
        });

    } catch (error) {
        logger.error(`Failed to check access validity: ${error.message}`);
        res.status(500).json({
            success: false,
            error: 'Failed to check access validity',
            details: error.message
        });
    }
};

// Get active accesses for a patient
exports.getActiveAccesses = async (req, res) => {
    try {
        const { patientID } = req.params;

        logger.info(`Fetching active accesses for patient: ${patientID}`);

        const { contract } = await getContract('admin');

        const result = await contract.evaluateTransaction(
            'GetActiveAccessesForPatient',
            patientID
        );

        const accesses = JSON.parse(result.toString());

        res.status(200).json({
            success: true,
            data: accesses,
            count: accesses.length
        });

    } catch (error) {
        logger.error(`Failed to get active accesses: ${error.message}`);
        res.status(500).json({
            success: false,
            error: 'Failed to retrieve active accesses',
            details: error.message
        });
    }
};
