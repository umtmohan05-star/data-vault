const authService = require('../services/auth.service');
const logger = require('../../utils/logger');

// Patient login
exports.loginPatient = async (req, res) => {
    try {
        const { patientId, password } = req.body;

        logger.info(`Patient login attempt: ${patientId}`);
        console.log('📥 Login request body:', { patientId, passwordProvided: !!password });

        if (!patientId || !password) {
            logger.error('Missing patientId or password');
            return res.status(400).json({
                success: false,
                error: 'Patient ID and password are required'
            });
        }

        const result = await authService.loginPatient(patientId, password);

        if (!result.success) {
            logger.error(`Login failed for patient ${patientId}: ${result.error}`);
            return res.status(401).json({
                success: false,
                error: result.error
            });
        }

        logger.info(`Patient logged in successfully: ${patientId}`);

        res.status(200).json({
            success: true,
            token: result.token,
            patient: result.patient
        });

    } catch (error) {
        logger.error(`Patient login error: ${error.message}`);
        console.error('Full error:', error);
        res.status(500).json({
            success: false,
            error: 'Login failed',
            details: error.message
        });
    }
};

// Doctor login
exports.loginDoctor = async (req, res) => {
    try {
        const { doctorId, password } = req.body;

        logger.info(`Doctor login attempt: ${doctorId}`);
        console.log('📥 Login request body:', { doctorId, passwordProvided: !!password });

        if (!doctorId || !password) {
            logger.error('Missing doctorId or password');
            return res.status(400).json({
                success: false,
                error: 'Doctor ID and password are required'
            });
        }

        const result = await authService.loginDoctor(doctorId, password);

        if (!result.success) {
            logger.error(`Login failed for doctor ${doctorId}: ${result.error}`);
            return res.status(401).json({
                success: false,
                error: result.error
            });
        }

        logger.info(`Doctor logged in successfully: ${doctorId}`);

        res.status(200).json({
            success: true,
            token: result.token,
            doctor: result.doctor
        });

    } catch (error) {
        logger.error(`Doctor login error: ${error.message}`);
        console.error('Full error:', error);
        res.status(500).json({
            success: false,
            error: 'Login failed',
            details: error.message
        });
    }
};
