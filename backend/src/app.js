const express = require('express');
const cors = require('cors');
require('dotenv').config();

const logger = require('../utils/logger');
const { disconnectGateway } = require('./fabric/network');
const sequelize = require('./config/database'); // ✅ ADD THIS

const app = express();

// ✅ ADD: Initialize database connection
sequelize.sync({ alter: false }) // Use alter: false in production
    .then(() => {
        logger.info('✅ PostgreSQL models synchronized');
    })
    .catch((err) => {
        logger.error('❌ Failed to sync database models:', err);
    });

// Middleware
app.use(cors({
    origin: process.env.FRONTEND_URL || 'http://localhost:5173',
    credentials: true
}));
app.use(express.json());
app.use(express.urlencoded({ extended: true }));

// Request logging middleware
app.use((req, res, next) => {
    logger.info(`${req.method} ${req.path}`);
    next();
});

// Health check endpoint
app.get('/health', (req, res) => {
    res.json({
        success: true,
        message: 'Healthcare Blockchain Backend is running',
        timestamp: new Date().toISOString(),
        version: '1.0.0',
        database: sequelize.authenticate() ? 'connected' : 'disconnected'
    });
});

// API Routes
const API_PREFIX = process.env.API_PREFIX || '/api/v1';
app.use(`${API_PREFIX}/auth`, require('./routes/auth.routes'));
app.use(`${API_PREFIX}/patients`, require('./routes/patient.routes'));
app.use(`${API_PREFIX}/doctors`, require('./routes/doctor.routes'));
app.use(`${API_PREFIX}/access`, require('./routes/access.routes'));

// 404 handler
app.use((req, res) => {
    res.status(404).json({
        success: false,
        error: 'Route not found',
        path: req.path
    });
});

// Global error handler
app.use((err, req, res, next) => {
    logger.error(`Unhandled error: ${err.message}`);
    res.status(err.status || 500).json({
        success: false,
        error: 'Internal server error',
        details: process.env.NODE_ENV === 'development' ? err.message : undefined
    });
});

// Graceful shutdown
process.on('SIGINT', async () => {
    logger.info('Shutting down gracefully...');
    await disconnectGateway();
    await sequelize.close();
    process.exit(0);
});

process.on('SIGTERM', async () => {
    logger.info('Shutting down gracefully...');
    await disconnectGateway();
    await sequelize.close();
    process.exit(0);
});

// Start server
const PORT = process.env.PORT || 3000;
app.listen(PORT, () => {
    logger.info(`🚀 Server running on port ${PORT}`);
    logger.info(`📍 API endpoint: http://localhost:${PORT}${API_PREFIX}`);
    logger.info(`🏥 Environment: ${process.env.NODE_ENV || 'development'}`);
});

module.exports = app;
