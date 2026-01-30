const router = require('express').Router();
const controller = require('../controllers/doctor.controller');
const { validate } = require('../../utils/validation');

// Register a new doctor
router.post('/register', validate('registerDoctor'), controller.registerDoctor);

// Get doctor by ID
router.get('/:doctorID', controller.getDoctor);

// Verify a doctor (only AuditOrg)
router.post('/:doctorID/verify', controller.verifyDoctor);

module.exports = router;
