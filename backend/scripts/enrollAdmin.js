const FabricCAServices = require('fabric-ca-client');
const { Wallets } = require('fabric-network');
const fs = require('fs');
const path = require('path');

async function enrollAdmin(orgName = 'HospitalApollo') {
    try {
        // Load connection profile
        const ccpPath = path.resolve(__dirname, '../config/connection-profile.json');
        const ccp = JSON.parse(fs.readFileSync(ccpPath, 'utf8'));

        // Get CA info
        const caInfo = ccp.certificateAuthorities[`ca.${orgName.toLowerCase()}.healthcare.com`];
        const caTLSCACerts = fs.readFileSync(path.resolve(__dirname, '..', caInfo.tlsCACerts.path), 'utf8');
        const ca = new FabricCAServices(caInfo.url, { trustedRoots: caTLSCACerts, verify: false }, caInfo.caName);

        // Create wallet
        const walletPath = path.join(__dirname, '../wallet');
        const wallet = await Wallets.newFileSystemWallet(walletPath);

        // Check if admin already enrolled
        const identity = await wallet.get('admin');
        if (identity) {
            console.log('✅ Admin identity already exists in wallet');
            return;
        }

        // Enroll admin
        console.log(`🔐 Enrolling admin for ${orgName}...`);
        const enrollment = await ca.enroll({ enrollmentID: 'admin', enrollmentSecret: 'adminpw' });
        
        const orgMSP = orgName === 'HospitalApollo' ? 'HospitalApolloMSP' : 'AuditOrgMSP';
        const x509Identity = {
            credentials: {
                certificate: enrollment.certificate,
                privateKey: enrollment.key.toBytes(),
            },
            mspId: orgMSP,
            type: 'X.509',
        };

        await wallet.put('admin', x509Identity);
        console.log('✅ Successfully enrolled admin and imported into wallet');

    } catch (error) {
        console.error(`❌ Failed to enroll admin: ${error}`);
        process.exit(1);
    }
}

// Run if called directly
if (require.main === module) {
    const org = process.argv[2] || 'HospitalApollo';
    enrollAdmin(org);
}

module.exports = enrollAdmin;
