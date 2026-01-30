const express = require('express');
const router = express.Router();
const authController = require('../controllers/auth.controller');
const { validate } = require('../../utils/validation');

// Login routes with validation
router.post('/login/patient', validate('loginPatient'), authController.loginPatient);
router.post('/login/doctor', validate('loginDoctor'), authController.loginDoctor);

module.exports = router;
