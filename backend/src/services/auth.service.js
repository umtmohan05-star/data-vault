const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const { Patient } = require('../models/Patient');
const { Doctor } = require('../models/Doctor');

// Generate JWT token
const generateToken = (payload, expiresIn = '24h') => {
    return jwt.sign(payload, process.env.JWT_SECRET || 'your-secret-key', {
        expiresIn
    });
};

// Register a new patient
exports.registerPatient = async (patientData) => {
    const { patientId, name, dateOfBirth, phone, aadharNumber, password, fingerprintTemplateId } = patientData;

    // Hash password
    const passwordHash = await bcrypt.hash(password, 10);

    // Create patient in database
    const patient = await Patient.create({
        patientId,
        name,
        dateOfBirth,
        phone,
        aadharNumber,
        passwordHash,
        fingerprintTemplateId,
        isActive: true
    });

    console.log('✅ Patient created successfully in PostgreSQL');

    return {
        patientId: patient.patientId,
        name: patient.name,
        dateOfBirth: patient.dateOfBirth,
        phone: patient.phone,
        aadharNumber: patient.aadharNumber
    };
};

// Login patient
exports.loginPatient = async (patientId, password) => {
    console.log('🔐 Auth Service: Login attempt for patient:', patientId);

    // Find patient
    const patient = await Patient.findOne({ where: { patientId } });

    if (!patient) {
        console.log('❌ Patient not found:', patientId);
        return {
            success: false,
            error: 'Invalid patient ID or password'
        };
    }

    console.log('✅ Patient found:', patientId);
    console.log('🔑 Comparing passwords...');

    // Compare password
    const isValidPassword = await bcrypt.compare(password, patient.passwordHash);
    
    console.log('🔑 Password valid:', isValidPassword);

    if (!isValidPassword) {
        console.log('❌ Invalid password for patient:', patientId);
        return {
            success: false,
            error: 'Invalid patient ID or password'
        };
    }

    // Update last login
    await patient.update({ lastLogin: new Date() });

    // Generate token
    const token = generateToken({
        patientId: patient.patientId,
        role: 'patient'
    });

    console.log('✅ Login successful, token generated');

    return {
        success: true,
        token,
        patient: {
            patientId: patient.patientId,
            name: patient.name,
            dateOfBirth: patient.dateOfBirth,
            phone: patient.phone,
            aadharNumber: patient.aadharNumber
        }
    };
};

// Register a new doctor
exports.registerDoctor = async (doctorData) => {
    const { doctorId, name, licenseNumber, specialization, hospitalName, password } = doctorData;

    // Hash password
    const passwordHash = await bcrypt.hash(password, 10);

    // Create doctor in database
    const doctor = await Doctor.create({
        doctorId,
        name,
        licenseNumber,
        specialization,
        hospitalName,
        passwordHash,
        isVerified: false,
        isActive: true
    });

    console.log('✅ Doctor created successfully in PostgreSQL');

    return {
        doctorId: doctor.doctorId,
        name: doctor.name,
        licenseNumber: doctor.licenseNumber,
        specialization: doctor.specialization,
        hospitalName: doctor.hospitalName
    };
};

// Login doctor
exports.loginDoctor = async (doctorId, password) => {
    console.log('🔐 Auth Service: Login attempt for doctor:', doctorId);

    // Find doctor
    const doctor = await Doctor.findOne({ where: { doctorId } });

    if (!doctor) {
        console.log('❌ Doctor not found:', doctorId);
        return {
            success: false,
            error: 'Invalid doctor ID or password'
        };
    }

    console.log('✅ Doctor found:', doctorId);
    console.log('🔑 Comparing passwords...');

    // Compare password
    const isValidPassword = await bcrypt.compare(password, doctor.passwordHash);
    
    console.log('🔑 Password valid:', isValidPassword);

    if (!isValidPassword) {
        console.log('❌ Invalid password for doctor:', doctorId);
        return {
            success: false,
            error: 'Invalid doctor ID or password'
        };
    }

    // Update last login
    await doctor.update({ lastLogin: new Date() });

    // Generate token
    const token = generateToken({
        doctorId: doctor.doctorId,
        role: 'doctor'
    });

    console.log('✅ Login successful, token generated');

    return {
        success: true,
        token,
        doctor: {
            doctorId: doctor.doctorId,
            name: doctor.name,
            licenseNumber: doctor.licenseNumber,
            specialization: doctor.specialization,
            hospitalName: doctor.hospitalName,
            isVerified: doctor.isVerified
        }
    };
};
