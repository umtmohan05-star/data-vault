const { Sequelize } = require('sequelize');
const path = require('path');
require('dotenv').config({ path: path.join(__dirname, '../.env') });

async function cleanupDatabase() {
    console.log('╔═══════════════════════════════════════════════════════╗');
    console.log('║  DATABASE CLEANUP - Remove Test Data                 ║');
    console.log('╚═══════════════════════════════════════════════════════╝\n');

    const sequelize = new Sequelize(
        // Prefer DB_* env vars; fall back to older POSTGRES_* names for compatibility
        process.env.DB_NAME || process.env.POSTGRES_DB || 'healthcare_auth',
        process.env.DB_USER || process.env.POSTGRES_USER || 'healthcare_admin',
        process.env.DB_PASSWORD || process.env.POSTGRES_PASSWORD || 'SecurePassword123!',
        {
            host: process.env.DB_HOST || process.env.POSTGRES_HOST || 'localhost',
            port: process.env.DB_PORT || process.env.POSTGRES_PORT || 5432,
            dialect: 'postgres',
            logging: false
        }
    );

    try {
        // Test connection
        await sequelize.authenticate();
        console.log('✅ Connected to PostgreSQL\n');

        // Delete all patients (RETURNING * to count deleted rows reliably without assuming column names)
        const [deletedPatients] = await sequelize.query('DELETE FROM patients RETURNING *');
        console.log(`🗑️  Deleted ${deletedPatients.length || 0} patients`);

        // Delete all doctors (RETURNING * to count deleted rows reliably without assuming column names)
        const [deletedDoctors] = await sequelize.query('DELETE FROM doctors RETURNING *');
        console.log(`🗑️  Deleted ${deletedDoctors.length || 0} doctors`);

        // Delete all refresh tokens (RETURNING * to count deleted rows reliably without assuming column names)
        const [deletedTokens] = await sequelize.query('DELETE FROM refresh_tokens RETURNING *');
        console.log(`🗑️  Deleted ${deletedTokens.length || 0} refresh tokens`);

        // Delete all login history (RETURNING * to count deleted rows reliably without assuming column names)
        const [deletedHistory] = await sequelize.query('DELETE FROM login_history RETURNING *');
        console.log(`🗑️  Deleted ${deletedHistory.length || 0} login history records`);

        console.log('\n✅ Database cleanup completed successfully!\n');

    } catch (error) {
        console.error('❌ Cleanup failed:', error.message);
        console.error('🔧 Tip: check database credentials in your .env (DB_USER, DB_PASSWORD, DB_HOST, DB_NAME) and ensure Postgres is reachable.');
        process.exit(1);
    } finally {
        await sequelize.close();
    }
}

cleanupDatabase();
