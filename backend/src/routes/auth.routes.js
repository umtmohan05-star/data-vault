const router = require('express').Router();
const controller = require('../controllers/auth.controller');
const { validate } = require('../../utils/validation');

// Patient login
router.post('/login/patient', validate('loginPatient'), controller.loginPatient);

// Doctor login
router.post('/login/doctor', validate('loginDoctor'), controller.loginDoctor);

module.exports = router;
