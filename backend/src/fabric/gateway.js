const { Gateway, Wallets } = require('fabric-network');
const path = require('path');
const fs = require('fs');
require('dotenv').config();

class FabricGateway {
    constructor() {
        this.gateway = null;
        this.network = null;
        this.contract = null;
    }

    async connect(identityLabel = 'admin') {
        try {
            // Load connection profile
            const ccpPath = path.resolve(__dirname, '../../config/connection-profile.json');
            if (!fs.existsSync(ccpPath)) {
                throw new Error('Connection profile not found');
            }
            const ccp = JSON.parse(fs.readFileSync(ccpPath, 'utf8'));

            // Setup wallet
            const walletPath = path.join(__dirname, '../../wallet');
            const wallet = await Wallets.newFileSystemWallet(walletPath);

            // Check identity
            const identity = await wallet.get(identityLabel);
            if (!identity) {
                throw new Error(`Identity "${identityLabel}" not found in wallet. Run enrollAdmin.js first.`);
            }

            // Connect to gateway
            this.gateway = new Gateway();
            await this.gateway.connect(ccp, {
                wallet,
                identity: identityLabel,
                discovery: { enabled: true, asLocalhost: true }
            });

            // Get network and contract
            const channelName = process.env.CHANNEL_NAME || 'healthcare-channel';
            this.network = await this.gateway.getNetwork(channelName);
            
            const contractName = process.env.CHAINCODE_NAME || 'healthcare-contract';
            this.contract = this.network.getContract(contractName);

            console.log(`✅ Connected to Fabric network: ${channelName}`);
            return this;

        } catch (error) {
            console.error(`❌ Failed to connect to Fabric: ${error.message}`);
            throw error;
        }
    }

    async disconnect() {
        if (this.gateway) {
            await this.gateway.disconnect();
            this.gateway = null;
            this.network = null;
            this.contract = null;
        }
    }

    getContract() {
        if (!this.contract) {
            throw new Error('Not connected to Fabric network');
        }
        return this.contract;
    }

    getNetwork() {
        if (!this.network) {
            throw new Error('Not connected to Fabric network');
        }
        return this.network;
    }
}

module.exports = FabricGateway;
