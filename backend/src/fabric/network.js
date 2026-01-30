const FabricGateway = require('./gateway');

// Singleton instance
let gatewayInstance = null;

async function getContract(identity = 'admin') {
    if (!gatewayInstance) {
        gatewayInstance = new FabricGateway();
        await gatewayInstance.connect(identity);
    }
    
    return {
        contract: gatewayInstance.getContract(),
        network: gatewayInstance.getNetwork(),
        gateway: gatewayInstance
    };
}

async function disconnectGateway() {
    if (gatewayInstance) {
        await gatewayInstance.disconnect();
        gatewayInstance = null;
    }
}

module.exports = { getContract, disconnectGateway };
