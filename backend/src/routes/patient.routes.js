const router = require('express').Router();
const controller = require('../controllers/patient.controller');
const { validate } = require('../../utils/validation');

// Register a new patient
router.post('/register', validate('registerPatient'), controller.registerPatient);

// Get patient by ID
router.get('/:patientID', controller.getPatient);

// Get patient audit trail
router.get('/:patientID/audit', controller.getPatientAuditTrail);

// Get patient active accesses
router.get('/:patientID/accesses', controller.getPatientAccesses);

module.exports = router;
