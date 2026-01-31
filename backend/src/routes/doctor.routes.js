const router = require('express').Router();
const controller = require('../controllers/doctor.controller');
const { validate } = require('../../utils/validation');

// Register a new doctor
router.post('/register', validate('registerDoctor'), controller.registerDoctor);

// ✅ NEW: Verify a doctor (only AuditOrg)
router.put('/:doctorID/verify', controller.verifyDoctor);

// Get doctor by ID
router.get('/:doctorID', controller.getDoctor);

// Get doctor access history
router.get('/:doctorID/history', controller.getDoctorAccessHistory);

module.exports = router;
