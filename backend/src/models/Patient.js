const { DataTypes } = require('sequelize');
const sequelize = require('../config/database');
const bcrypt = require('bcryptjs');

const Patient = sequelize.define('Patient', {
    patientId: {
        type: DataTypes.STRING(20),
        primaryKey: true,
        field: 'patient_id'
    },
    name: {
        type: DataTypes.STRING(255),
        allowNull: false,
        validate: {
            notEmpty: { msg: 'Name cannot be empty' }
        }
    },
    dateOfBirth: {
        type: DataTypes.DATEONLY,
        allowNull: false,
        field: 'date_of_birth',
        validate: {
            isDate: { msg: 'Invalid date format' }
        }
    },
    phone: {
        type: DataTypes.STRING(20),
        allowNull: false,
        validate: {
            notEmpty: { msg: 'Phone cannot be empty' }
        }
    },
    aadharNumber: {
        type: DataTypes.STRING(12),
        allowNull: false,
        unique: true,
        field: 'aadhar_number',
        validate: {
            len: {
                args: [12, 12],
                msg: 'Aadhar number must be exactly 12 digits'
            }
        }
    },
    passwordHash: {
        type: DataTypes.STRING(255),
        allowNull: false,
        field: 'password_hash',
        validate: {
            notEmpty: { msg: 'Password hash cannot be empty' }
        }
    },
    fingerprintTemplateId: {
        type: DataTypes.INTEGER,
        allowNull: true,  // ✅ FIXED: Make it explicitly nullable
        field: 'fingerprint_template_id'
    },
    isActive: {
        type: DataTypes.BOOLEAN,
        defaultValue: true,
        field: 'is_active'
    },
    lastLogin: {
        type: DataTypes.DATE,
        allowNull: true,  // ✅ FIXED: Make it explicitly nullable
        field: 'last_login'
    },
    createdAt: {  // ✅ ADDED: Explicit definition
        type: DataTypes.DATE,
        field: 'created_at',
        allowNull: false,
        defaultValue: DataTypes.NOW
    },
    updatedAt: {  // ✅ ADDED: Explicit definition
        type: DataTypes.DATE,
        field: 'updated_at',
        allowNull: false,
        defaultValue: DataTypes.NOW
    }
}, {
    tableName: 'patients',
    underscored: true,
    timestamps: true,
    createdAt: 'createdAt',  // ✅ FIXED: Use the field name we defined above
    updatedAt: 'updatedAt',  // ✅ FIXED: Use the field name we defined above
    validate: {
        // Custom table-level validations can go here
    }
});

// Hash password before saving
Patient.beforeCreate(async (patient) => {
    if (patient.passwordHash) {
        patient.passwordHash = await bcrypt.hash(patient.passwordHash, 10);
    }
});

// Method to compare passwords
Patient.prototype.comparePassword = async function(password) {
    return bcrypt.compare(password, this.passwordHash);
};

module.exports = Patient;
