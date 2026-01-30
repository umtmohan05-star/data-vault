const { Wallets } = require('fabric-network');
const fs = require('fs');
const path = require('path');

async function importAdminIdentity(orgName, mspId, identityLabel) {
    try {
        console.log(`\n🔐 Importing ${identityLabel} identity...`);

        // Path to the admin credentials
        const credPath = path.join(__dirname, 
            `../../Blockchain/compose/organizations/peerOrganizations/${orgName}/users/Admin@${orgName}/msp`
        );

        console.log(`📂 Certificate path: ${credPath}`);

        // Verify path exists
        if (!fs.existsSync(credPath)) {
            throw new Error(`Admin credentials not found at: ${credPath}`);
        }

        // Read certificate
        const certPath = path.join(credPath, `signcerts/Admin@${orgName}-cert.pem`);
        if (!fs.existsSync(certPath)) {
            throw new Error(`Certificate not found at: ${certPath}`);
        }
        const certificate = fs.readFileSync(certPath, 'utf8');
        console.log('✅ Certificate loaded');

        // Read private key
        const keyPath = path.join(credPath, 'keystore');
        const keyFiles = fs.readdirSync(keyPath);
        if (keyFiles.length === 0) {
            throw new Error(`No private key found in: ${keyPath}`);
        }
        const privateKey = fs.readFileSync(path.join(keyPath, keyFiles[0]), 'utf8');
        console.log('✅ Private key loaded');

        // Create wallet
        const walletPath = path.join(__dirname, '../wallet');
        const wallet = await Wallets.newFileSystemWallet(walletPath);

        // Check if identity already exists
        const identityExists = await wallet.get(identityLabel);
        if (identityExists) {
            console.log(`⚠️  ${identityLabel} already exists, removing old identity...`);
            await wallet.remove(identityLabel);
        }

        // Create identity
        const identity = {
            credentials: {
                certificate: certificate,
                privateKey: privateKey,
            },
            mspId: mspId,
            type: 'X.509',
        };

        // Import to wallet
        await wallet.put(identityLabel, identity);
        
        console.log(`✅ ${identityLabel} identity imported successfully!`);
        console.log(`🔑 MSP ID: ${mspId}`);

    } catch (error) {
        console.error(`❌ Failed to import ${identityLabel}:`, error.message);
        throw error;
    }
}

async function setupAllAdmins() {
    console.log('╔═══════════════════════════════════════════════════════╗');
    console.log('║  HEALTHCARE BLOCKCHAIN - ADMIN IDENTITY SETUP        ║');
    console.log('╚═══════════════════════════════════════════════════════╝');

    try {
        // Import Hospital Apollo Admin (primary for patient/doctor registration)
        await importAdminIdentity(
            'hospitalapollo.healthcare.com',
            'HospitalApolloMSP',
            'hospitalApolloAdmin'
        );

        // Import generic 'admin' for backward compatibility
        await importAdminIdentity(
            'hospitalapollo.healthcare.com',
            'HospitalApolloMSP',
            'admin'
        );

        // Import Audit Org Admin (for audit trail queries)
        await importAdminIdentity(
            'auditorg.healthcare.com',
            'AuditOrgMSP',
            'auditOrgAdmin'
        );

        // Import Health Registry Admin (for orderer operations)
        const healthRegistryCredPath = path.join(__dirname,
            '../../Blockchain/compose/organizations/ordererOrganizations/healthregistry.healthcare.com/users/Admin@healthregistry.healthcare.com/msp'
        );

        if (fs.existsSync(healthRegistryCredPath)) {
            console.log(`\n🔐 Importing healthRegistryAdmin identity...`);
            const certPath = path.join(healthRegistryCredPath, 'signcerts/Admin@healthregistry.healthcare.com-cert.pem');
            const certificate = fs.readFileSync(certPath, 'utf8');
            
            const keyPath = path.join(healthRegistryCredPath, 'keystore');
            const keyFiles = fs.readdirSync(keyPath);
            const privateKey = fs.readFileSync(path.join(keyPath, keyFiles[0]), 'utf8');

            const walletPath = path.join(__dirname, '../wallet');
            const wallet = await Wallets.newFileSystemWallet(walletPath);

            const identityExists = await wallet.get('healthRegistryAdmin');
            if (identityExists) {
                await wallet.remove('healthRegistryAdmin');
            }

            await wallet.put('healthRegistryAdmin', {
                credentials: { certificate, privateKey },
                mspId: 'HealthRegistryMSP',
                type: 'X.509',
            });

            console.log('✅ healthRegistryAdmin imported successfully!');
        }

        console.log('\n╔═══════════════════════════════════════════════════════╗');
        console.log('║  ✅ ALL ADMIN IDENTITIES IMPORTED SUCCESSFULLY!      ║');
        console.log('╚═══════════════════════════════════════════════════════╝');
        console.log('\n📁 Wallet location:', path.join(__dirname, '../wallet'));
        console.log('\n🎯 Imported identities:');
        console.log('   • hospitalApolloAdmin (HospitalApolloMSP) - Primary');
        console.log('   • admin (HospitalApolloMSP) - Alias');
        console.log('   • auditOrgAdmin (AuditOrgMSP)');
        console.log('   • healthRegistryAdmin (HealthRegistryMSP)');
        console.log('\n✨ You can now start the backend server!');
        console.log('   Run: npm start\n');

    } catch (error) {
        console.error('\n❌ Setup failed:', error.message);
        console.error('\n💡 Make sure the Fabric network is running:');
        console.error('   cd Blockchain/network && ./network-up.sh\n');
        process.exit(1);
    }
}

setupAllAdmins();
