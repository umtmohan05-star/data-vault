const router = require('express').Router();
const controller = require('../controllers/access.controller');
const { validate } = require('../../utils/validation');

// Grant access to a doctor
router.post('/grant', validate('grantAccess'), controller.grantAccess);

// Revoke access
router.delete('/:accessKey', controller.revokeAccess);

// Check access validity
router.get('/:accessKey/validity', controller.checkAccessValidity);

// Get active accesses for a patient
router.get('/patient/:patientID', controller.getActiveAccesses);

module.exports = router;
