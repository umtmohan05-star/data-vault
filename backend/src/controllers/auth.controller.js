const authService = require('../services/auth.service');
const logger = require('../../utils/logger.js');

// Login patient
exports.loginPatient = async (req, res) => {
    try {
        const { patientID, password } = req.body;

        if (!patientID || !password) {
            return res.status(400).json({
                success: false,
                error: 'Patient ID and password are required'
            });
        }

        const result = await authService.loginPatient(patientID, password);

        res.json({
            success: true,
            token: result.token,
            patient: result.patient
        });

    } catch (error) {
        logger.error('Patient login error:', error);
        res.status(401).json({
            success: false,
            error: error.message || 'Login failed'
        });
    }
};

// Login doctor
exports.loginDoctor = async (req, res) => {
    try {
        const { doctorID, password } = req.body;

        if (!doctorID || !password) {
            return res.status(400).json({
                success: false,
                error: 'Doctor ID and password are required'
            });
        }

        const result = await authService.loginDoctor(doctorID, password);

        res.json({
            success: true,
            token: result.token,
            doctor: result.doctor
        });

    } catch (error) {
        logger.error('Doctor login error:', error);
        res.status(401).json({
            success: false,
            error: error.message || 'Login failed'
        });
    }
};
