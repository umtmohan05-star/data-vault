const { DataTypes } = require('sequelize');
const sequelize = require('../config/database');
const bcrypt = require('bcryptjs');

const Doctor = sequelize.define('Doctor', {
    doctorId: {
        type: DataTypes.STRING(20),
        primaryKey: true,
        field: 'doctor_id'
    },
    name: {
        type: DataTypes.STRING(255),
        allowNull: false,
        validate: {
            notEmpty: { msg: 'Name cannot be empty' }
        }
    },
    licenseNumber: {
        type: DataTypes.STRING(50),
        allowNull: false,
        unique: true,
        field: 'license_number',
        validate: {
            notEmpty: { msg: 'License number cannot be empty' }
        }
    },
    specialization: {
        type: DataTypes.STRING(100),
        allowNull: false,
        validate: {
            notEmpty: { msg: 'Specialization cannot be empty' }
        }
    },
    hospitalName: {
        type: DataTypes.STRING(255),
        allowNull: false,
        field: 'hospital_name',
        validate: {
            notEmpty: { msg: 'Hospital name cannot be empty' }
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
    isVerified: {
        type: DataTypes.BOOLEAN,
        defaultValue: false,
        field: 'is_verified'
    },
    verifiedAt: {
        type: DataTypes.DATE,
        allowNull: true,  // ✅ FIXED: Make it explicitly nullable
        field: 'verified_at'
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
    tableName: 'doctors',
    underscored: true,
    timestamps: true,
    createdAt: 'createdAt',  // ✅ FIXED: Use the field name we defined above
    updatedAt: 'updatedAt',  // ✅ FIXED: Use the field name we defined above
});

// Hash password before saving
Doctor.beforeCreate(async (doctor) => {
    if (doctor.passwordHash) {
        doctor.passwordHash = await bcrypt.hash(doctor.passwordHash, 10);
    }
});

// Method to compare passwords
Doctor.prototype.comparePassword = async function(password) {
    return bcrypt.compare(password, this.passwordHash);
};

module.exports = Doctor;
