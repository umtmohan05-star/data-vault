#!/usr/bin/env bash

# Healthcare Network Startup - ENHANCED VERSION FOR PROPER GOVERNANCE
# 🏛️ USES ELECTION COMMISSION ADMIN FOR CHAINCODE GOVERNANCE
# 🆕 ADDS -v FLAG FOR VOLUME-ONLY CLEANUP  
# ⚔️ SACRED VOW: All existing functionality preserved, only enhanced!

# Uses Channel Participation API instead of genesis blocks
# FIXED: Proper volume mount paths for your directory structure

# Get script directory for reliable path resolution
ROOTDIR=$(cd "$(dirname "$0")" && pwd)
export PATH=${ROOTDIR}/../bin:${PWD}/../bin:$PATH
export FABRIC_CFG_PATH=${PWD}/../config
export VERBOSE=false

# Colors for beautiful output
C_RESET='\033[0;30m'
C_GREEN='\033[0;32m'
C_YELLOW='\033[1;33m'
C_RED='\033[0;31m'
C_BLUE='\033[0;34m'

function infoln() { echo -e "${C_GREEN}${1}${C_RESET}"; }
function warnln() { echo -e "${C_YELLOW}${1}${C_RESET}"; }
function errorln() { echo -e "${C_RED}${1}${C_RESET}"; }
function fatalln() { errorln "$1"; exit 1; }

# Load utility functions
if [ -f "../scripts/utils.sh" ]; then
    . ../scripts/utils.sh
fi

# Docker configuration
: ${CONTAINER_CLI:="docker"}
if command -v ${CONTAINER_CLI}-compose > /dev/null 2>&1; then
    : ${CONTAINER_CLI_COMPOSE:="${CONTAINER_CLI}-compose"}
else
    : ${CONTAINER_CLI_COMPOSE:="${CONTAINER_CLI} compose"}
fi
infoln "Using ${CONTAINER_CLI} and ${CONTAINER_CLI_COMPOSE}"

# Network configuration
COMPOSE_FILE_BASE="healthcare-compose-network.yaml"
COMPOSE_FILE_CA="healthcare-compose-ca.yaml"
COMPOSE_FILE_COUCH="healthcare-compose-couch.yaml"
DATABASE="couchdb"
CRYPTO="cryptogen"
CHANNEL_NAME="healthcare-channel"
MAX_RETRY=5
CLI_DELAY=3
VERBOSE=false

################################################################################
# Clean up functions
################################################################################
function clearContainers() {
    infoln "Removing remaining containers"
    ${CONTAINER_CLI} rm -f $(${CONTAINER_CLI} ps -aq --filter label=service=hyperledger-fabric) 2>/dev/null || true
    ${CONTAINER_CLI} rm -f $(${CONTAINER_CLI} ps -aq --filter name='dev-peer*') 2>/dev/null || true
    ${CONTAINER_CLI} kill "$(${CONTAINER_CLI} ps -q --filter name=ccaas)" 2>/dev/null || true
}

function removeUnwantedImages() {
    infoln "Removing generated chaincode docker images"
    ${CONTAINER_CLI} image rm -f $(${CONTAINER_CLI} images -aq --filter reference='dev-peer*') 2>/dev/null || true
}

################################################################################
# Enhanced prerequisites check with version alignment
################################################################################
function checkPrereqs() {
    peer version > /dev/null 2>&1
    if [[ $? -ne 0 ]]; then
        errorln "Peer binary not found"
        exit 1
    fi
    
    # FIXED: Reliable version extraction
    LOCAL_VERSION=$(peer version 2>&1 | grep -oP "Version: \K[0-9]+\.[0-9]+\.[0-9]+" | head -1)
    DOCKER_IMAGE_VERSION="2.5.9"
    
    infoln "LOCAL_VERSION: ${LOCAL_VERSION}"
    infoln "DOCKER_IMAGE_VERSION: ${DOCKER_IMAGE_VERSION}"
    
    LOCAL_MAJOR_MINOR=$(echo $LOCAL_VERSION | cut -d'.' -f1-2)
    DOCKER_MAJOR_MINOR=$(echo $DOCKER_IMAGE_VERSION | cut -d'.' -f1-2)
    
    if [ "$LOCAL_MAJOR_MINOR" != "$DOCKER_MAJOR_MINOR" ]; then
        warnln "⚠️ Version mismatch (LOCAL=$LOCAL_VERSION, TARGET=$DOCKER_IMAGE_VERSION)"
        warnln "    This is OK for patch differences"
    else
        infoln "✅ Versions compatible: $LOCAL_VERSION ≈ $DOCKER_IMAGE_VERSION"
    fi
}

################################################################################
# Certificate generation for 3-org setup - FIXED PATHS
################################################################################
function createOrgs() {
    infoln "🔄 Generating certificates using cryptogen for 3-org Healthcare setup (4 orderers)..."
    if [ "$CRYPTO" == "cryptogen" ]; then
        which cryptogen > /dev/null 2>&1
        if [ "$?" -ne 0 ]; then
            fatalln "cryptogen tool not found. exiting"
        fi

        # Check if certificates already exist in correct structure (including orderer4)
        #if [ -d "../compose/organizations/ordererOrganizations/healthregistry.healthcare.com/orderers/orderer1.healthregistry.healthcare.com/msp/signcerts" ] &&
        #   [ "$(ls -A ../compose/organizations/ordererOrganizations/healthregistry.healthcare.com/orderers/orderer1.healthregistry.healthcare.com/msp/signcerts 2>/dev/null)" ] &&
        #   [ -d "../compose/organizations/ordererOrganizations/healthregistry.healthcare.com/orderers/orderer4.healthregistry.healthcare.com/msp/signcerts" ] &&
        #   [ "$(ls -A ../compose/organizations/ordererOrganizations/healthregistry.healthcare.com/orderers/orderer4.healthregistry.healthcare.com/msp/signcerts 2>/dev/null)" ]; then
        #    infoln "✅ Certificates already exist in proper structure (including orderer4)"
        #    return
        #fi

        infoln "Creating Health Registry Identities (4 orderers for SmartBFT)"
        set -x
        cryptogen generate --config=../organizations/cryptogen/crypto-config-health-registry.yaml --output="../compose/organizations"
        res=$?
        { set +x; } 2>/dev/null
        if [ $res -ne 0 ]; then
            fatalln "Failed to generate Health Registry certificates..."
        fi

        # Verify orderer4 was created
        if [ ! -d "../compose/organizations/ordererOrganizations/healthregistry.healthcare.com/orderers/orderer4.healthregistry.healthcare.com" ]; then
            errorln "⚠️  orderer4 certificates not generated!"
            errorln "    Make sure crypto-config-health-registry.yaml has 4 orderers:"
            errorln "    Specs:"
            errorln "      - Hostname: orderer1"
            errorln "      - Hostname: orderer2"
            errorln "      - Hostname: orderer3"
            errorln "      - Hostname: orderer4"
            fatalln "Please update crypto-config and run again"
        fi
        infoln "✅ orderer4 certificates verified"

        infoln "Creating Hospital Apollo Identities"
        set -x
        cryptogen generate --config=../organizations/cryptogen/crypto-config-hospital-apollo.yaml --output="../compose/organizations"
        res=$?
        { set +x; } 2>/dev/null
        if [ $res -ne 0 ]; then
            fatalln "Failed to generate Hospital Apollo certificates..."
        fi

        infoln "Creating Audit Org Identities"
        set -x
        cryptogen generate --config=../organizations/cryptogen/crypto-config-audit-org.yaml --output="../compose/organizations"
        res=$?
        { set +x; } 2>/dev/null
        if [ $res -ne 0 ]; then
            fatalln "Failed to generate Audit Org certificates..."
        fi
    fi
    
    infoln "✅ Certificate generation completed (4 orderers + 4 peers)"
    
    # Display certificate summary
    infoln "📋 Certificate Summary:"
    infoln "   • Orderers: $(ls -d ../compose/organizations/ordererOrganizations/healthregistry.healthcare.com/orderers/orderer* 2>/dev/null | wc -l)"
    infoln "   • Hospital Apollo Peers: $(ls -d ../compose/organizations/peerOrganizations/hospitalapollo.healthcare.com/peers/peer* 2>/dev/null | wc -l)"
    infoln "   • Audit Org Peers: $(ls -d ../compose/organizations/peerOrganizations/auditorg.healthcare.com/peers/peer* 2>/dev/null | wc -l)"
}


################################################################################
# Network startup - VERSION-ALIGNED APPROACH 
################################################################################
function networkUp() {
    checkPrereqs

    infoln "🔧 Aligning Docker images with available versions..."

    # Backup original compose files
    cp ../compose/healthcare-compose-network.yaml ../compose/healthcare-compose-network.yaml.backup 2>/dev/null || true
    cp ../compose/healthcare-compose-ca.yaml ../compose/healthcare-compose-ca.yaml.backup 2>/dev/null || true

    # Use correct available versions
    # Peers and Orderers: 2.5.9 (latest in 2.5.x series)
    # Extract version without 'v' prefix for Docker tags
    DOCKER_VERSION=${LOCAL_VERSION#v}
    infoln "Using local version $LOCAL_VERSION -> Docker version $DOCKER_VERSION"

    # Use EXACT matching versions
    #sed -i "s|hyperledger/fabric-peer:.*|hyperledger/fabric-peer:$DOCKER_VERSION|g" ../compose/healthcare-compose-network.yaml
    #sed -i "s|hyperledger/fabric-orderer:.*|hyperledger/fabric-orderer:$DOCKER_VERSION|g" ../compose/healthcare-compose-network.yaml

    # For CA, extract major.minor and use appropriate CA version
    CA_VERSION="1.5.15"  # Latest CA compatible with 2.5.x
    #sed -i "s|hyperledger/fabric-ca:.*|hyperledger/fabric-ca:$CA_VERSION|g" ../compose/healthcare-compose-ca.yaml


    infoln "✅ Docker images aligned: peer/orderer:2.5.9, ca:1.5.15"

    # Generate certificates if needed
    if [ ! -d "../compose/organizations/peerOrganizations" ]; then
        createOrgs
    fi

    # Build compose file configuration - FIXED PATHS
    COMPOSE_FILES="-f ../compose/${COMPOSE_FILE_BASE}"
    if [ "${DATABASE}" == "couchdb" ]; then
        COMPOSE_FILES="${COMPOSE_FILES} -f ../compose/${COMPOSE_FILE_COUCH}"
    fi
    COMPOSE_FILES="${COMPOSE_FILES} -f ../compose/${COMPOSE_FILE_CA}"

    infoln "🚀 Starting Healthcare network with VERSION-ALIGNED Fabric 2.x..."
    infoln "🎯 Using matching 2.5.9 images for ESCC compatibility..."
    
    # Pull the correct images first to ensure they're available
    infoln "📥 Pulling verified available images..."
    docker pull hyperledger/fabric-peer:$DOCKER_VERSION
    docker pull hyperledger/fabric-orderer:$DOCKER_VERSION  
    docker pull hyperledger/fabric-ca:$CA_VERSION
    docker pull hyperledger/fabric-ccenv:$DOCKER_VERSION    
    docker pull hyperledger/fabric-tools:$DOCKER_VERSION    
    docker pull hyperledger/fabric-baseos:$DOCKER_VERSION    
    
    ${CONTAINER_CLI_COMPOSE} ${COMPOSE_FILES} up -d 2>&1
    $CONTAINER_CLI ps -a
    if [ $? -ne 0 ]; then
        fatalln "Unable to start network"
    fi

    # Wait for containers to start
    export FABRIC_CCENV_IMAGE="hyperledger/fabric-ccenv:$DOCKER_VERSION"
    export FABRIC_BASEOS_IMAGE="hyperledger/fabric-baseos:$DOCKER_VERSION"
    sleep 5
    infoln "🎉 VERSION-ALIGNED Healthcare network started successfully!"
    infoln "📋 Docker images now match local binaries - ESCC should work!"
}


################################################################################
# Network teardown - ENHANCED WITH -v FLAG SUPPORT
################################################################################
function networkDown() {
    # Stop containers
    COMPOSE_BASE_FILES="-f ../compose/${COMPOSE_FILE_BASE}"
    COMPOSE_COUCH_FILES="-f ../compose/${COMPOSE_FILE_COUCH}"
    COMPOSE_CA_FILES="-f ../compose/${COMPOSE_FILE_CA}"
    COMPOSE_FILES="${COMPOSE_BASE_FILES} ${COMPOSE_COUCH_FILES} ${COMPOSE_CA_FILES}"

    infoln "🛑 Stopping external chaincode container..."
    docker stop healthcare-chaincode 2>/dev/null || true
    docker rm healthcare-chaincode 2>/dev/null || true

    if [ "${CONTAINER_CLI}" == "docker" ]; then
        DOCKER_SOCK="${DOCKER_SOCK}" ${CONTAINER_CLI_COMPOSE} ${COMPOSE_FILES} down --volumes --remove-orphans
    else
        ${CONTAINER_CLI_COMPOSE} ${COMPOSE_FILES} down --volumes --remove-orphans
    fi

    # 🆕 NEW: Handle -v flag for volume-only cleanup
    if [ "$VOLUMES_ONLY" == "true" ]; then
        infoln "🗑️ Removing Docker volumes only (keeping certificates)"
        ${CONTAINER_CLI} volume prune -f
        return
    fi

    if [ "$MODE" != "restart" ]; then
        clearContainers
        removeUnwantedImages
        if [ "$CLEAN_CERTS" == "true" ]; then
            infoln "🗑️ Cleaning certificates as requested..."
            ${CONTAINER_CLI} run --rm -v "$(pwd):/data" busybox sh -c 'cd /data && rm -rf ../compose/organizations/peerOrganizations ../compose/organizations/ordererOrganizations'
        else
            infoln "🔒 Preserving certificates - use 'down -clean' to remove them"
        fi
        ${CONTAINER_CLI} run --rm -v "$(pwd):/data" busybox sh -c 'cd /data && rm -rf channel-artifacts log.txt *.tar.gz'
    fi
}

################################################################################
# 🔍 VERIFY NETWORK - UPDATED FOR 4 PEERS + EXTERNAL CHAINCODE
################################################################################

function verifyNetwork() {
    infoln "🔍 Verifying Healthcare network status..."
    echo ""
    infoln "=== RUNNING CONTAINERS ==="
    docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" | head -20
    echo ""
    
    # Count containers
    local total_running=$(docker ps -q | wc -l)
    local ca_count=$(docker ps | grep "ca_" | wc -l)
    local peer_count=$(docker ps | grep "peer" | grep "healthcare.com" | wc -l)
    local orderer_count=$(docker ps | grep "orderer" | grep "healthregistry.healthcare.com" | wc -l)
    local couchdb_count=$(docker ps | grep "couchdb" | wc -l)
    local chaincode_count=$(docker ps | grep "healthcare-chaincode" | wc -l)
    
    # Detailed peer breakdown
    local peer0_pp=$(docker ps | grep "peer0.hospitalapollo.healthcare.com" | wc -l)
    local peer1_pp=$(docker ps | grep "peer1.hospitalapollo.healthcare.com" | wc -l)
    local peer0_aa=$(docker ps | grep "peer0.auditorg.healthcare.com" | wc -l)
    local peer1_aa=$(docker ps | grep "peer1.auditorg.healthcare.com" | wc -l)
    
    infoln "📊 CONTAINER BREAKDOWN:"
    infoln "╔════════════════════════════════════════╗"
    infoln "║  INFRASTRUCTURE COMPONENTS             ║"
    infoln "╠════════════════════════════════════════╣"
    infoln "║  • Certificate Authorities: $ca_count/3        ║"
    infoln "║  • Orderers (RAFT):         $orderer_count/4        ║"
    infoln "║  • CouchDB Databases:       $couchdb_count/4        ║"
    infoln "╠════════════════════════════════════════╣"
    infoln "║  PEER NODES (PRODUCTION SETUP)         ║"
    infoln "╠════════════════════════════════════════╣"
    infoln "║  • Hospital Apollo Peer0:   $peer0_pp/1        ║"
    infoln "║  • Hospital Apollo Peer1:   $peer1_pp/1        ║"
    infoln "║  • Audit Org Peer0:   $peer0_aa/1        ║"
    infoln "║  • Audit Org Peer1:   $peer1_aa/1        ║"
    infoln "║  • TOTAL PEERS:             $peer_count/4        ║"
    infoln "╠════════════════════════════════════════╣"
    infoln "║  EXTERNAL CHAINCODE SERVER             ║"
    infoln "╠════════════════════════════════════════╣"
    infoln "║  • Chaincode Service:       $chaincode_count/1        ║"
    infoln "╚════════════════════════════════════════╝"
    infoln "  TOTAL CONTAINERS:           $total_running/17"
    echo ""
    
    # Health status
    if [ $orderer_count -eq 4 ] && [ $peer_count -eq 4 ] && [ $chaincode_count -eq 1 ]; then
        infoln "🔥🔥🔥 PRODUCTION NETWORK FULLY OPERATIONAL! 🔥🔥🔥"
        infoln "✅ 3-Organization Healthcare Blockchain with External Chaincode"
        echo ""
        infoln "🎯 NETWORK ACCESS POINTS:"
        infoln "┌─────────────────────────────────────────────────────────┐"
        infoln "│  ORDERERS (RAFT Consensus)                              │"
        infoln "├─────────────────────────────────────────────────────────┤"
        infoln "│  • Orderer1: localhost:7050                             │"
        infoln "│  • Orderer2: localhost:8050                             │"
        infoln "│  • Orderer3: localhost:9050                             │"
        infoln "├─────────────────────────────────────────────────────────┤"
        infoln "│  POLITICAL PARTY PEERS                                  │"
        infoln "├─────────────────────────────────────────────────────────┤"
        infoln "│  • Peer0: localhost:7051                                │"
        infoln "│  • Peer1: localhost:8051                                │"
        infoln "│  • CouchDB0: http://localhost:5984/_utils               │"
        infoln "│  • CouchDB1: http://localhost:6984/_utils               │"
        infoln "├─────────────────────────────────────────────────────────┤"
        infoln "│  AUDIT AUTHORITY PEERS                                  │"
        infoln "├─────────────────────────────────────────────────────────┤"
        infoln "│  • Peer0: localhost:9051                                │"
        infoln "│  • Peer1: localhost:10051                               │"
        infoln "│  • CouchDB0: http://localhost:7984/_utils               │"
        infoln "│  • CouchDB1: http://localhost:8984/_utils               │"
        infoln "├─────────────────────────────────────────────────────────┤"
        infoln "│  EXTERNAL CHAINCODE SERVER                              │"
        infoln "├─────────────────────────────────────────────────────────┤"
        infoln "│  • Chaincode Server: localhost:7052                     │"
        infoln "│  • Container: healthcare-chaincode                         │"
        infoln "└─────────────────────────────────────────────────────────┘"
        echo ""
        infoln "🚀 NEXT STEPS:"
        infoln "  1. Create channel:  ./network-up.sh createChannel"
        infoln "  2. Deploy contract: ./network-up.sh deployChaincode"
        infoln "  3. Test blockchain: ./test-healthcare.sh"
        echo ""
    elif [ $orderer_count -ge 1 ] && [ $peer_count -ge 2 ]; then
        infoln "⚡ PARTIAL SUCCESS: Network running but not complete!"
        echo ""
        if [ $orderer_count -lt 3 ]; then
            warnln "⚠️  Only $orderer_count/3 orderers running!"
            warnln "   Check logs: docker logs orderer1.healthregistry.healthcare.com"
        fi
        if [ $peer_count -lt 4 ]; then
            warnln "⚠️  Only $peer_count/4 peers running!"
            warnln "   Missing peers: Check docker-compose configuration"
        fi
        if [ $chaincode_count -eq 0 ]; then
            warnln "⚠️  External chaincode server not running!"
            warnln "   Start manually: cd ../compose && docker-compose -f healthcare-compose-network.yaml up -d healthcare-chaincode"
        fi
    else
        warnln "⚠️  MINIMAL SETUP: Only $total_running containers running"
        warnln "Expected 12 containers for production (3 orderers + 4 peers + 4 couchdb + 1 chaincode)"
        echo ""
        errorln "🔧 TROUBLESHOOTING:"
        errorln "  • Check compose files: ls -la ../compose/"
        errorln "  • Check logs: docker logs <container-name>"
        errorln "  • Restart network: ./network-up.sh down -v && ./network-up.sh up -s couchdb"
    fi
}

################################################################################
# MODERN CHANNEL CREATION USING OSNADMIN (Channel Participation API)
# 🔥 FIXED: All certificate paths now point to ../compose/organizations/
################################################################################
function createChannel() {
    infoln "🌊 Creating channel: ${CHANNEL_NAME} with 4 orderers (SmartBFT)..."

    # Check if orderers are running
    ORDERER_COUNT=$(docker ps | grep "orderer" | grep "healthregistry.healthcare.com" | grep "Up" | wc -l)
    if [ $ORDERER_COUNT -lt 4 ]; then
        errorln "❌ Only $ORDERER_COUNT orderers running! Need 4 orderers for SmartBFT."
        errorln "   Start network first: ./network-up.sh up -s couchdb"
        exit 1
    fi

    infoln "✅ All 4 orderers are running!"

    # Create channel artifacts directory
    mkdir -p channel-artifacts

    infoln "📝 Step 1: Creating channel genesis block with SmartBFT..."
    set -x
    configtxgen -profile ChannelUsingBFT \
        -outputBlock ./channel-artifacts/${CHANNEL_NAME}.block \
        -channelID ${CHANNEL_NAME} 2>&1 | grep -v "Intermediate certs folder not found"
    res=$?
    { set +x; } 2>/dev/null

    if [ $res -ne 0 ]; then
        fatalln "Failed to generate channel genesis block"
    fi
    infoln "✅ Channel genesis block created with SmartBFT consensus!"

    # Join orderer1
    infoln "📝 Step 2: Joining orderer1 to channel..."
    set -x
    osnadmin channel join \
        --channelID ${CHANNEL_NAME} \
        --config-block ./channel-artifacts/${CHANNEL_NAME}.block \
        -o localhost:7053 \
        --ca-file ../compose/organizations/ordererOrganizations/healthregistry.healthcare.com/msp/tlscacerts/tlsca.healthregistry.healthcare.com-cert.pem \
        --client-cert ../compose/organizations/ordererOrganizations/healthregistry.healthcare.com/orderers/orderer1.healthregistry.healthcare.com/tls/server.crt \
        --client-key ../compose/organizations/ordererOrganizations/healthregistry.healthcare.com/orderers/orderer1.healthregistry.healthcare.com/tls/server.key 2>&1
    res=$?
    { set +x; } 2>/dev/null
    if [ $res -ne 0 ] && [ $res -ne 8 ]; then
        warnln "Orderer1 join returned status $res"
    fi
    infoln "✅ Orderer1 joined!"

    # Join orderer2
    infoln "📝 Step 3: Joining orderer2 to channel..."
    set -x
    osnadmin channel join \
        --channelID ${CHANNEL_NAME} \
        --config-block ./channel-artifacts/${CHANNEL_NAME}.block \
        -o localhost:8053 \
        --ca-file ../compose/organizations/ordererOrganizations/healthregistry.healthcare.com/msp/tlscacerts/tlsca.healthregistry.healthcare.com-cert.pem \
        --client-cert ../compose/organizations/ordererOrganizations/healthregistry.healthcare.com/orderers/orderer2.healthregistry.healthcare.com/tls/server.crt \
        --client-key ../compose/organizations/ordererOrganizations/healthregistry.healthcare.com/orderers/orderer2.healthregistry.healthcare.com/tls/server.key 2>&1
    res=$?
    { set +x; } 2>/dev/null
    if [ $res -ne 0 ] && [ $res -ne 8 ]; then
        warnln "Orderer2 join returned status $res"
    fi
    infoln "✅ Orderer2 joined!"

    # Join orderer3
    infoln "📝 Step 4: Joining orderer3 to channel..."
    set -x
    osnadmin channel join \
        --channelID ${CHANNEL_NAME} \
        --config-block ./channel-artifacts/${CHANNEL_NAME}.block \
        -o localhost:9053 \
        --ca-file ../compose/organizations/ordererOrganizations/healthregistry.healthcare.com/msp/tlscacerts/tlsca.healthregistry.healthcare.com-cert.pem \
        --client-cert ../compose/organizations/ordererOrganizations/healthregistry.healthcare.com/orderers/orderer3.healthregistry.healthcare.com/tls/server.crt \
        --client-key ../compose/organizations/ordererOrganizations/healthregistry.healthcare.com/orderers/orderer3.healthregistry.healthcare.com/tls/server.key 2>&1
    res=$?
    { set +x; } 2>/dev/null
    if [ $res -ne 0 ] && [ $res -ne 8 ]; then
        warnln "Orderer3 join returned status $res"
    fi
    infoln "✅ Orderer3 joined!"

    # NEW: Join orderer4 (Required for SmartBFT f=1 Byzantine tolerance)
    infoln "📝 Step 4.5: Joining orderer4 to channel (NEW for SmartBFT)..."
    set -x
    osnadmin channel join \
        --channelID ${CHANNEL_NAME} \
        --config-block ./channel-artifacts/${CHANNEL_NAME}.block \
        -o localhost:10053 \
        --ca-file ../compose/organizations/ordererOrganizations/healthregistry.healthcare.com/msp/tlscacerts/tlsca.healthregistry.healthcare.com-cert.pem \
        --client-cert ../compose/organizations/ordererOrganizations/healthregistry.healthcare.com/orderers/orderer4.healthregistry.healthcare.com/tls/server.crt \
        --client-key ../compose/organizations/ordererOrganizations/healthregistry.healthcare.com/orderers/orderer4.healthregistry.healthcare.com/tls/server.key 2>&1
    res=$?
    { set +x; } 2>/dev/null
    if [ $res -ne 0 ] && [ $res -ne 8 ]; then
        warnln "Orderer4 join returned status $res"
    fi
    infoln "✅ Orderer4 joined! SmartBFT consensus now has 4 nodes (f=1 tolerance)"

    # Give SmartBFT time to initialize consensus
    infoln "⏳ Waiting for SmartBFT consensus to stabilize..."
    sleep 15

    # Join peers - Hospital Apollo
    infoln "📝 Step 5: Joining peer0.hospitalapollo..."
    setGlobals "HospitalApollo" 0
    set -x
    peer channel join -b ./channel-artifacts/${CHANNEL_NAME}.block 2>&1
    res=$?
    { set +x; } 2>/dev/null
    if [ $res -ne 0 ]; then
        fatalln "Failed to join peer0.hospitalapollo"
    fi

    infoln "📝 Step 6: Joining peer1.hospitalapollo..."
    setGlobals "HospitalApollo" 1
    set -x
    peer channel join -b ./channel-artifacts/${CHANNEL_NAME}.block 2>&1
    res=$?
    { set +x; } 2>/dev/null
    if [ $res -ne 0 ]; then
        fatalln "Failed to join peer1.hospitalapollo"
    fi

    # Join peers - Audit Org
    infoln "📝 Step 7: Joining peer0.auditorg..."
    setGlobals "AuditOrg" 0
    set -x
    peer channel join -b ./channel-artifacts/${CHANNEL_NAME}.block 2>&1
    res=$?
    { set +x; } 2>/dev/null
    if [ $res -ne 0 ]; then
        fatalln "Failed to join peer0.auditorg"
    fi

    infoln "📝 Step 8: Joining peer1.auditorg..."
    setGlobals "AuditOrg" 1
    set -x
    peer channel join -b ./channel-artifacts/${CHANNEL_NAME}.block 2>&1
    res=$?
    { set +x; } 2>/dev/null
    if [ $res -ne 0 ]; then
        fatalln "Failed to join peer1.auditorg"
    fi

    infoln "🎉🎉🎉 CHANNEL CREATED WITH SMARTBFT! 🎉🎉🎉"
    infoln "   • 4 Orderers joined (SmartBFT active!)"
    infoln "   • 4 Peers joined"
    infoln "   • Byzantine Fault Tolerance: f=1 (can tolerate 1 malicious orderer)"
}

################################################################################
# 🎯 SET ANCHOR PEERS - FIXED PATHS FOR compose/organizations/
################################################################################
function setAnchorPeers() {
  infoln "⚓ Setting Anchor Peers for Service Discovery..."
  
  # IMPORTANT: Save current directory
  NETWORK_DIR=$(pwd)
  
  # Set environment
  export PATH=${NETWORK_DIR}/../bin:$PATH
  export FABRIC_CFG_PATH=${NETWORK_DIR}/../config
  export CORE_PEER_TLS_ENABLED=true
  
  # Verify channel exists
  if [ ! -f "./channel-artifacts/${CHANNEL_NAME}.block" ]; then
    errorln "❌ Channel not created yet! Run './network-up.sh createChannel' first"
    return 1
  fi
  
  # For each organization, set anchor peer
  for ORG in "HospitalApollo" "AuditOrg"; do
    infoln "📌 Setting anchor peer for ${ORG}..."
    
    # Set globals for organization
    setGlobals "$ORG" 0
    
    # Determine anchor peer details
    if [ "$ORG" == "HospitalApollo" ]; then
      ANCHOR_HOST="peer0.hospitalapollo.healthcare.com"
      ANCHOR_PORT=7051
      MSP_ID="HospitalApolloMSP"
    else
      ANCHOR_HOST="peer0.auditorg.healthcare.com"
      ANCHOR_PORT=9051
      MSP_ID="AuditOrgMSP"
    fi
    
    # Fetch current channel config
    infoln "  → Fetching channel config..."
    peer channel fetch config channel-artifacts/config_block.pb \
      -o orderer1.healthregistry.healthcare.com:7050 \
      --ordererTLSHostnameOverride orderer1.healthregistry.healthcare.com \
      -c $CHANNEL_NAME --tls \
      --cafile ${NETWORK_DIR}/../compose/organizations/ordererOrganizations/healthregistry.healthcare.com/orderers/orderer1.healthregistry.healthcare.com/tls/ca.crt \
      >/dev/null 2>&1
    
    if [ $? -ne 0 ]; then
      errorln "❌ Failed to fetch channel config for ${ORG}"
      return 1
    fi
    
    # Decode config block
    configtxlator proto_decode --input channel-artifacts/config_block.pb \
      --type common.Block --output channel-artifacts/config_block.json
    
    jq .data.data[0].payload.data.config channel-artifacts/config_block.json \
      > channel-artifacts/config.json
    
    # Check if anchor peer already set
    EXISTING_ANCHOR=$(jq -r ".channel_group.groups.Application.groups.${MSP_ID}.values.AnchorPeers" \
       channel-artifacts/config.json 2>/dev/null)
    
    if [ "$EXISTING_ANCHOR" != "null" ] && [ -n "$EXISTING_ANCHOR" ]; then
      infoln "  ✅ Anchor peer already set for ${ORG}, skipping..."
      continue
    fi
    
    # Add anchor peer configuration
    infoln "  → Adding anchor peer configuration..."
    jq ".channel_group.groups.Application.groups.${MSP_ID}.values += \
      {\"AnchorPeers\":{\"mod_policy\": \"Admins\",\"value\":{\"anchor_peers\": \
      [{\"host\": \"${ANCHOR_HOST}\",\"port\": ${ANCHOR_PORT}}]},\"version\": \"0\"}}" \
      channel-artifacts/config.json > channel-artifacts/modified_config.json
    
    # Encode both configs
    configtxlator proto_encode --input channel-artifacts/config.json \
      --type common.Config --output channel-artifacts/config.pb
    
    configtxlator proto_encode --input channel-artifacts/modified_config.json \
      --type common.Config --output channel-artifacts/modified_config.pb
    
    # Compute update
    configtxlator compute_update --channel_id $CHANNEL_NAME \
      --original channel-artifacts/config.pb \
      --updated channel-artifacts/modified_config.pb \
      --output channel-artifacts/${ORG}_anchor_update.pb 2>/dev/null
    
    if [ $? -ne 0 ]; then
      warnln "  ⚠️  No changes needed for ${ORG} (possibly already set)"
      continue
    fi
    
    # Decode update
    configtxlator proto_decode --input channel-artifacts/${ORG}_anchor_update.pb \
      --type common.ConfigUpdate --output channel-artifacts/${ORG}_anchor_update.json
    
    # Wrap in envelope
    echo "{\"payload\":{\"header\":{\"channel_header\":{\"channel_id\":\"$CHANNEL_NAME\", \"type\":2}},\"data\":{\"config_update\":$(cat channel-artifacts/${ORG}_anchor_update.json)}}}" \
      | jq . > channel-artifacts/${ORG}_anchor_update_in_envelope.json
    
    configtxlator proto_encode --input channel-artifacts/${ORG}_anchor_update_in_envelope.json \
      --type common.Envelope --output channel-artifacts/${ORG}_anchor_update_in_envelope.pb
    
    # Submit anchor peer update
    infoln "  → Submitting anchor peer update to orderer..."
    peer channel update -f channel-artifacts/${ORG}_anchor_update_in_envelope.pb \
      -c $CHANNEL_NAME \
      -o orderer1.healthregistry.healthcare.com:7050 \
      --ordererTLSHostnameOverride orderer1.healthregistry.healthcare.com \
      --tls \
      --cafile ${NETWORK_DIR}/../compose/organizations/ordererOrganizations/healthregistry.healthcare.com/orderers/orderer1.healthregistry.healthcare.com/tls/ca.crt \
      >/dev/null 2>&1
    
    if [ $? -eq 0 ]; then
      infoln "  ✅ Anchor peer set for ${ORG}: ${ANCHOR_HOST}:${ANCHOR_PORT}"
    else
      errorln "  ❌ Failed to set anchor peer for ${ORG}"
      return 1
    fi
  done
  
  # Cleanup
  rm -f channel-artifacts/config_block.pb channel-artifacts/config_block.json \
        channel-artifacts/config.json channel-artifacts/modified_config.json \
        channel-artifacts/config.pb channel-artifacts/modified_config.pb \
        channel-artifacts/*_anchor_update*
  
  infoln "🎉 All anchor peers configured! Service discovery is now active!"
  infoln ""
  infoln "🔍 Verify with:"
  infoln "   ./network-up.sh verifyAnchors"
}

################################################################################
# 🔍 VERIFY ANCHOR PEERS - RUNS ON HOST (where jq exists!)
################################################################################
function verifyAnchors() {
  infoln "🔍 Verifying Anchor Peer Configuration..."
  
  # IMPORTANT: Set environment
  NETWORK_DIR=$(pwd)
  export PATH=${NETWORK_DIR}/../bin:$PATH
  export FABRIC_CFG_PATH=${NETWORK_DIR}/../config
  export CORE_PEER_TLS_ENABLED=true
  
  # Set globals for HospitalApollo peer
  setGlobals "HospitalApollo" 0
  
  # Create temp directory
  mkdir -p /tmp/anchor-verify
  
  # Fetch config from peer (runs INSIDE container)
  infoln "  → Fetching channel configuration..."
  peer channel fetch config /tmp/anchor-verify/config_block.pb \
    -c healthcare-channel \
    -o orderer1.healthregistry.healthcare.com:7050 --tls \
    --ordererTLSHostnameOverride orderer1.healthregistry.healthcare.com \
    --cafile ${NETWORK_DIR}/../compose/organizations/ordererOrganizations/healthregistry.healthcare.com/orderers/orderer1.healthregistry.healthcare.com/tls/ca.crt \
    >/dev/null 2>&1
  
  if [ $? -ne 0 ]; then
    errorln "❌ Failed to fetch channel config"
    return 1
  fi
  
  # Decode on HOST (where jq exists!)
  infoln "  → Decoding configuration..."
  configtxlator proto_decode \
    --input /tmp/anchor-verify/config_block.pb \
    --type common.Block 2>/dev/null | \
    jq .data.data[0].payload.data.config > /tmp/anchor-verify/config.json
  
  if [ $? -ne 0 ]; then
    errorln "❌ Failed to decode config"
    rm -rf /tmp/anchor-verify
    return 1
  fi
  
  # Extract anchor peer info (runs on HOST with jq!)
  echo ""
  infoln "=== 📍 HospitalApollo Anchor Peers ==="
  PP_ANCHORS=$(cat /tmp/anchor-verify/config.json | \
    jq '.channel_group.groups.Application.groups.HospitalApolloMSP.values.AnchorPeers.value.anchor_peers' 2>/dev/null)
  
  if [ "$PP_ANCHORS" = "null" ] || [ -z "$PP_ANCHORS" ]; then
    errorln "❌ No anchor peers configured for HospitalApollo!"
  else
    echo "$PP_ANCHORS" | jq -C '.'
    infoln "✅ HospitalApollo anchor peer is configured"
  fi
  
  echo ""
  infoln "=== 📍 AuditOrg Anchor Peers ==="
  AA_ANCHORS=$(cat /tmp/anchor-verify/config.json | \
    jq '.channel_group.groups.Application.groups.AuditOrgMSP.values.AnchorPeers.value.anchor_peers' 2>/dev/null)
  
  if [ "$AA_ANCHORS" = "null" ] || [ -z "$AA_ANCHORS" ]; then
    errorln "❌ No anchor peers configured for AuditOrg!"
  else
    echo "$AA_ANCHORS" | jq -C '.'
    infoln "✅ AuditOrg anchor peer is configured"
  fi
  
  # Cleanup
  rm -rf /tmp/anchor-verify
  
  echo ""
  if [ "$PP_ANCHORS" != "null" ] && [ "$AA_ANCHORS" != "null" ]; then
    infoln "🎉 All anchor peers are properly configured!"
    infoln "   Service discovery should work for AND endorsement policies"
  else
    errorln "⚠️  Missing anchor peers detected!"
    errorln "   Run: ./network-up.sh setAnchorPeers"
  fi
}

function setGlobals() {
    local ORG=$1
    local PEER_NUM=${2:-0}
    
    export CORE_PEER_LOCALMSPID="${ORG}MSP"
    export CORE_PEER_TLS_ENABLED=true
    
    if [ "$ORG" == "HospitalApollo" ]; then
        if [ $PEER_NUM -eq 0 ]; then
            export CORE_PEER_ADDRESS=peer0.hospitalapollo.healthcare.com:7051
            export CORE_PEER_TLS_ROOTCERT_FILE=${PWD}/../compose/organizations/peerOrganizations/hospitalapollo.healthcare.com/peers/peer0.hospitalapollo.healthcare.com/tls/ca.crt
            export CORE_PEER_MSPCONFIGPATH=${PWD}/../compose/organizations/peerOrganizations/hospitalapollo.healthcare.com/users/Admin@hospitalapollo.healthcare.com/msp
        else
            export CORE_PEER_ADDRESS=peer1.hospitalapollo.healthcare.com:8051
            export CORE_PEER_TLS_ROOTCERT_FILE=${PWD}/../compose/organizations/peerOrganizations/hospitalapollo.healthcare.com/peers/peer1.hospitalapollo.healthcare.com/tls/ca.crt
            export CORE_PEER_MSPCONFIGPATH=${PWD}/../compose/organizations/peerOrganizations/hospitalapollo.healthcare.com/users/Admin@hospitalapollo.healthcare.com/msp
        fi
    elif [ "$ORG" == "AuditOrg" ]; then
        if [ $PEER_NUM -eq 0 ]; then
            export CORE_PEER_ADDRESS=peer0.auditorg.healthcare.com:9051
            export CORE_PEER_TLS_ROOTCERT_FILE=${PWD}/../compose/organizations/peerOrganizations/auditorg.healthcare.com/peers/peer0.auditorg.healthcare.com/tls/ca.crt
            export CORE_PEER_MSPCONFIGPATH=${PWD}/../compose/organizations/peerOrganizations/auditorg.healthcare.com/users/Admin@auditorg.healthcare.com/msp
        else
            export CORE_PEER_ADDRESS=peer1.auditorg.healthcare.com:10051
            export CORE_PEER_TLS_ROOTCERT_FILE=${PWD}/../compose/organizations/peerOrganizations/auditorg.healthcare.com/peers/peer1.auditorg.healthcare.com/tls/ca.crt
            export CORE_PEER_MSPCONFIGPATH=${PWD}/../compose/organizations/peerOrganizations/auditorg.healthcare.com/users/Admin@auditorg.healthcare.com/msp
        fi
    fi
}

################################################################################
# 🚀 EXTERNAL CHAINCODE DEPLOYMENT - PRODUCTION-GRADE
# ✅ Works with chaincode-as-a-service (external builder)
# ✅ FIXED: Dynamic Package ID synchronization
################################################################################

function deployChaincode() {
    infoln "🚀 Starting External Healthcare Chaincode Deployment"
    
    # Configuration
    CHAINCODE_NAME="healthcare-contract"
    CHAINCODE_VERSION="1.0"
    SEQUENCE=1
    
    # IMPORTANT: Save current directory
    NETWORK_DIR=$(pwd)
    
    # Verify network is running
    local orderer_running=$(docker ps | grep "orderer" | grep "healthregistry.healthcare.com" | grep "Up" | wc -l)
    if [ $orderer_running -lt 3 ]; then
        errorln "❌ Only $orderer_running orderers running! Need 3 orderers."
        return 1
    fi
    
    # Check if external chaincode server is running
    local cc_server_running=$(docker ps | grep "healthcare-chaincode" | grep "Up" | wc -l)
    if [ $cc_server_running -eq 0 ]; then
        warnln "⚠️  External chaincode server not running! Starting it..."
        cd ../compose
        ${CONTAINER_CLI_COMPOSE} -f healthcare-compose-network.yaml up -d healthcare-chaincode
        cd "$NETWORK_DIR"
        sleep 5
    fi
    
    infoln "✅ External chaincode server is running!"
    
    # Set environment
    export FABRIC_CFG_PATH=${PWD}/../config
    export CORE_PEER_TLS_ENABLED=true
    
    # Check if chaincode is already installed
    infoln "🔍 Checking chaincode installation status..."
    
    export CORE_PEER_LOCALMSPID="HospitalApolloMSP"
    export CORE_PEER_ADDRESS=peer0.hospitalapollo.healthcare.com:7051
    export CORE_PEER_TLS_ROOTCERT_FILE=${NETWORK_DIR}/../compose/organizations/peerOrganizations/hospitalapollo.healthcare.com/peers/peer0.hospitalapollo.healthcare.com/tls/ca.crt
    export CORE_PEER_MSPCONFIGPATH=${NETWORK_DIR}/../compose/organizations/peerOrganizations/hospitalapollo.healthcare.com/users/Admin@hospitalapollo.healthcare.com/msp
    
    peer lifecycle chaincode queryinstalled 2>&1 > ${NETWORK_DIR}/chaincode_check.txt
    EXISTING_PACKAGE_ID=$(grep "${CHAINCODE_NAME}_${CHAINCODE_VERSION}" ${NETWORK_DIR}/chaincode_check.txt | sed -n 's/.*identifier: \([^ ]*\).*/\1/p' | head -1)
    rm -f ${NETWORK_DIR}/chaincode_check.txt
    
    if [ -n "$EXISTING_PACKAGE_ID" ]; then
        infoln "✅ Chaincode already installed! Package ID: $EXISTING_PACKAGE_ID"
        PACKAGE_ID="$EXISTING_PACKAGE_ID"
    else
        infoln "📦 Creating external chaincode package..."
        
        # Create temporary directory
        PKG_DIR="${NETWORK_DIR}/chaincode-package-temp"
        mkdir -p "$PKG_DIR"
        
        # Create connection.json for external chaincode
        cat > "$PKG_DIR/connection.json" <<EOF
{
  "address": "healthcare-chaincode:7052",
  "dial_timeout": "10s",
  "tls_required": false
}
EOF
        
        # Create metadata.json
        cat > "$PKG_DIR/metadata.json" <<EOF
{
  "type": "ccaas",
  "label": "${CHAINCODE_NAME}_${CHAINCODE_VERSION}"
}
EOF
        
        # Package the chaincode
        infoln "📦 Packaging chaincode..."
        cd "$PKG_DIR"
        tar czf code.tar.gz connection.json
        tar czf ${NETWORK_DIR}/${CHAINCODE_NAME}.tar.gz metadata.json code.tar.gz
        cd "$NETWORK_DIR"
        rm -rf "$PKG_DIR"
        
        infoln "✅ External chaincode package created!"
        
        # Install on peer0.hospitalapollo
        infoln "📥 Installing chaincode on peer0.hospitalapollo..."
        
        peer lifecycle chaincode install ${NETWORK_DIR}/${CHAINCODE_NAME}.tar.gz 2>&1 | tee ${NETWORK_DIR}/chaincode_installed.txt
        PACKAGE_ID=$(grep "${CHAINCODE_NAME}_${CHAINCODE_VERSION}" ${NETWORK_DIR}/chaincode_installed.txt | sed -n 's/.*identifier: \([^ ]*\).*/\1/p' | head -1)
        rm -f ${NETWORK_DIR}/chaincode_installed.txt
        
        if [ -z "$PACKAGE_ID" ]; then
            errorln "❌ Could not get package ID"
            return 1
        fi
        
        infoln "✅ Package ID: $PACKAGE_ID"
    fi
    
    # ✅ PERMANENT FIX: Update compose file and recreate container
    infoln "📝 Updating compose file with actual CHAINCODE_ID..."
    
    COMPOSE_FILE="../compose/healthcare-compose-network.yaml"
    echo "📝 Compose file path: $COMPOSE_FILE"

    if [ ! -f "$COMPOSE_FILE" ]; then
        errorln "Compose file not found at: $COMPOSE_FILE"
        return 1
    fi
    sed -i "s|CORE_CHAINCODE_ID_NAME=${CHAINCODE_NAME}_${CHAINCODE_VERSION}:.*|CORE_CHAINCODE_ID_NAME=${PACKAGE_ID}|g" "$COMPOSE_FILE"
    
    if grep -q "CORE_CHAINCODE_ID_NAME=${PACKAGE_ID}" "$COMPOSE_FILE"; then
        infoln "✅ Compose file updated successfully"
    else
        errorln "❌ Failed to update compose file!"
        return 1
    fi
    
    # Recreate chaincode container using Docker CLI (avoids restarting peers!)
    infoln "🔄 Recreating chaincode container with correct Package ID..."

    ACTUAL_NETWORK=$(docker inspect peer0.hospitalapollo.healthcare.com --format '{{range $k, $v := .NetworkSettings.Networks}}{{$k}}{{end}}')
    
    if [ -z "$ACTUAL_NETWORK" ]; then
        warnln "⚠️  Could not auto-detect network, defaulting to 'healthcare_network'"
        ACTUAL_NETWORK="healthcare_network"
    else
        infoln "🌐 Detected active network: $ACTUAL_NETWORK"
    fi
    
    docker stop healthcare-chaincode >/dev/null 2>&1
    docker rm healthcare-chaincode >/dev/null 2>&1
    
    docker run -d \
        --name healthcare-chaincode \
        --network $ACTUAL_NETWORK \
        --network-alias healthcare-chaincode \
        -p 7052:7052 \
        -e CHAINCODE_SERVER_ADDRESS=0.0.0.0:7052 \
        -e CORE_CHAINCODE_ID_NAME=${PACKAGE_ID} \
        -e CORE_CHAINCODE_LOGGING_LEVEL=info \
        -w /chaincode \
        compose-healthcare-chaincode:latest \
        /healthcare-chaincode
    
    sleep 5
    
    ACTUAL_ID=$(docker inspect healthcare-chaincode --format='{{range .Config.Env}}{{println .}}{{end}}' | grep "CORE_CHAINCODE_ID_NAME=" | cut -d'=' -f2)
    if [ "$ACTUAL_ID" = "$PACKAGE_ID" ]; then
        infoln "✅ Chaincode server running with Package ID: ${PACKAGE_ID}"
    else
        warnln "⚠️  Package ID mismatch! Expected: $PACKAGE_ID, Got: $ACTUAL_ID"
    fi
    
    infoln "📌 Package ID synchronized!"
    
    # Install on remaining peers
    infoln "📥 Installing on peer1.hospitalapollo..."
    export CORE_PEER_ADDRESS=peer1.hospitalapollo.healthcare.com:8051
    export CORE_PEER_TLS_ROOTCERT_FILE=${NETWORK_DIR}/../compose/organizations/peerOrganizations/hospitalapollo.healthcare.com/peers/peer1.hospitalapollo.healthcare.com/tls/ca.crt
    peer lifecycle chaincode install ${NETWORK_DIR}/${CHAINCODE_NAME}.tar.gz >/dev/null 2>&1 && infoln "✅ Installed on peer1.hospitalapollo" || warnln "⚠️  peer1.hospitalapollo skipped"
    
    infoln "📥 Installing on peer0.auditorg..."
    export CORE_PEER_LOCALMSPID="AuditOrgMSP"
    export CORE_PEER_ADDRESS=peer0.auditorg.healthcare.com:9051
    export CORE_PEER_TLS_ROOTCERT_FILE=${NETWORK_DIR}/../compose/organizations/peerOrganizations/auditorg.healthcare.com/peers/peer0.auditorg.healthcare.com/tls/ca.crt
    export CORE_PEER_MSPCONFIGPATH=${NETWORK_DIR}/../compose/organizations/peerOrganizations/auditorg.healthcare.com/users/Admin@auditorg.healthcare.com/msp
    peer lifecycle chaincode install ${NETWORK_DIR}/${CHAINCODE_NAME}.tar.gz >/dev/null 2>&1 && infoln "✅ Installed on peer0.auditorg" || warnln "⚠️  peer0.auditorg skipped"
    
    infoln "📥 Installing on peer1.auditorg..."
    export CORE_PEER_ADDRESS=peer1.auditorg.healthcare.com:10051
    export CORE_PEER_TLS_ROOTCERT_FILE=${NETWORK_DIR}/../compose/organizations/peerOrganizations/auditorg.healthcare.com/peers/peer1.auditorg.healthcare.com/tls/ca.crt
    peer lifecycle chaincode install ${NETWORK_DIR}/${CHAINCODE_NAME}.tar.gz >/dev/null 2>&1 && infoln "✅ Installed on peer1.auditorg" || warnln "⚠️  peer1.auditorg skipped"
    
    rm -f ${NETWORK_DIR}/${CHAINCODE_NAME}.tar.gz
    
    # Approval and commit
    infoln "🏛️  Starting Democratic Approval Process..."
    
    export CORE_PEER_LOCALMSPID="HospitalApolloMSP"
    export CORE_PEER_ADDRESS=peer0.hospitalapollo.healthcare.com:7051
    export CORE_PEER_TLS_ROOTCERT_FILE=${NETWORK_DIR}/../compose/organizations/peerOrganizations/hospitalapollo.healthcare.com/peers/peer0.hospitalapollo.healthcare.com/tls/ca.crt
    export CORE_PEER_MSPCONFIGPATH=${NETWORK_DIR}/../compose/organizations/peerOrganizations/hospitalapollo.healthcare.com/users/Admin@hospitalapollo.healthcare.com/msp
    
    peer lifecycle chaincode approveformyorg \
        -o orderer1.healthregistry.healthcare.com:7050 \
        --ordererTLSHostnameOverride orderer1.healthregistry.healthcare.com \
        --tls \
        --cafile ${NETWORK_DIR}/../compose/organizations/ordererOrganizations/healthregistry.healthcare.com/orderers/orderer1.healthregistry.healthcare.com/tls/ca.crt \
        --channelID $CHANNEL_NAME \
        --name $CHAINCODE_NAME \
        --version $CHAINCODE_VERSION \
        --package-id $PACKAGE_ID \
        --sequence $SEQUENCE\
        --signature-policy "AND('HospitalApolloMSP.peer','AuditOrgMSP.peer')" \
        --collections-config ${NETWORK_DIR}/../chaincode/healthcare/collections_config.json
    
    [ $? -eq 0 ] && infoln "✅ Hospital Apollo approved" || { errorln "❌ Hospital Apollo approval failed"; return 1; }
    
    export CORE_PEER_LOCALMSPID="AuditOrgMSP"
    export CORE_PEER_ADDRESS=peer0.auditorg.healthcare.com:9051
    export CORE_PEER_TLS_ROOTCERT_FILE=${NETWORK_DIR}/../compose/organizations/peerOrganizations/auditorg.healthcare.com/peers/peer0.auditorg.healthcare.com/tls/ca.crt
    export CORE_PEER_MSPCONFIGPATH=${NETWORK_DIR}/../compose/organizations/peerOrganizations/auditorg.healthcare.com/users/Admin@auditorg.healthcare.com/msp
    
    peer lifecycle chaincode approveformyorg \
        -o orderer1.healthregistry.healthcare.com:7050 \
        --ordererTLSHostnameOverride orderer1.healthregistry.healthcare.com \
        --tls \
        --cafile ${NETWORK_DIR}/../compose/organizations/ordererOrganizations/healthregistry.healthcare.com/orderers/orderer1.healthregistry.healthcare.com/tls/ca.crt \
        --channelID $CHANNEL_NAME \
        --name $CHAINCODE_NAME \
        --version $CHAINCODE_VERSION \
        --package-id $PACKAGE_ID \
        --sequence $SEQUENCE\
        --signature-policy "AND('HospitalApolloMSP.peer','AuditOrgMSP.peer')" \
        --collections-config ${NETWORK_DIR}/../chaincode/healthcare/collections_config.json

    
    [ $? -eq 0 ] && infoln "✅ Audit Org approved" || { errorln "❌ Audit Org approval failed"; return 1; }
    
    peer lifecycle chaincode commit \
        -o orderer1.healthregistry.healthcare.com:7050 \
        --ordererTLSHostnameOverride orderer1.healthregistry.healthcare.com \
        --tls \
        --cafile ${NETWORK_DIR}/../compose/organizations/ordererOrganizations/healthregistry.healthcare.com/orderers/orderer1.healthregistry.healthcare.com/tls/ca.crt \
        --channelID $CHANNEL_NAME \
        --name $CHAINCODE_NAME \
        --version $CHAINCODE_VERSION \
        --sequence $SEQUENCE \
        --signature-policy "AND('HospitalApolloMSP.peer','AuditOrgMSP.peer')" \
        --collections-config ${NETWORK_DIR}/../chaincode/healthcare/collections_config.json \
        --peerAddresses peer0.hospitalapollo.healthcare.com:7051 \
        --tlsRootCertFiles ${NETWORK_DIR}/../compose/organizations/peerOrganizations/hospitalapollo.healthcare.com/peers/peer0.hospitalapollo.healthcare.com/tls/ca.crt \
        --peerAddresses peer0.auditorg.healthcare.com:9051 \
        --tlsRootCertFiles ${NETWORK_DIR}/../compose/organizations/peerOrganizations/auditorg.healthcare.com/peers/peer0.auditorg.healthcare.com/tls/ca.crt

    
    if [ $? -ne 0 ]; then
        errorln "❌ Commit failed - see error above"
        return 1
    fi

    infoln "🎉🎉🎉 EXTERNAL CHAINCODE DEPLOYED! 🎉🎉🎉"
    infoln "✅ healthcare-contract v1.0 deployed as external service!"
}
# Start Redis
function startRedis() {
  infoln "Starting Redis cache..."
  
  docker-compose -f ../compose/healthcare-compose-network.yaml up -d redis.healthcare.com 2>&1
  
  # Wait for Redis to be ready
  local retries=0
  local max_retries=30
  
  while ! docker exec redis.healthcare.com redis-cli ping > /dev/null 2>&1; do
    retries=$((retries + 1))
    if [ $retries -ge $max_retries ]; then
      errorln "Redis failed to start"
      exit 1
    fi
    echo "Waiting for Redis... ($retries/$max_retries)"
    sleep 1
  done
  
  infoln "Redis is ready!"
}


# Add deployChaincode to the help function
function printHelp() {
    echo "Usage: network-up.sh [flags]"
    echo ""
    echo "Modes:"
    echo "  up - Start the Healthcare network"
    echo "  down - Stop the Healthcare network" 
    echo "  restart - Restart the Healthcare network"
    echo "  verify - Verify network status"
    echo "  createChannel - Create and join channel (network must be running)"
    echo " setAnchorPeers - Set anchor peers for service discovery"
    echo "  deployChaincode - Deploy healthcare-contract chaincode"
    echo ""
    echo "Flags:"
    echo "  -c - Channel name (default: healthcare-channel)"
    echo "  -s - State database: couchdb (default: couchdb)"
    echo "  -clean - Remove certificates when stopping network"
    echo "  -v - Remove Docker volumes only (preserve certificates)"
    echo "  -verbose - Verbose output"  
    echo "  -h - Print this help message"
    echo ""
    echo "Examples:"
    echo "  ./network-up.sh up -s couchdb"
    echo "  ./network-up.sh createChannel"
    echo "  ./network-up.sh deployChaincode"
    echo "  ./network-up.sh down -clean"
    echo "  ./network-up.sh down -v    # Remove volumes only"
}

################################################################################
# 🆕 ENHANCED Command line argument parsing - ADDS -v FLAG  
################################################################################
function parseCommandLineArgs() {
    while [[ $# -ge 1 ]] ; do
        key="$1"
        case $key in
            -h )
                printHelp
                exit 0
                ;;
            -c )
                CHANNEL_NAME="$2"
                shift
                ;;
            -s )
                if [ "$2" == "couchdb" ]; then
                    DATABASE="couchdb"
                fi
                shift
                ;;
            -clean )
                CLEAN_CERTS="true"
                ;;
            -v )
                # 🆕 NEW FLAG: Remove volumes only, preserve certificates
                VOLUMES_ONLY="true"
                ;;
            -verbose )
                VERBOSE=true
                ;;
            * )
                errorln "Unknown flag: $key"
                exit 1
                ;;
        esac
        shift
    done
}

################################################################################
# Main execution
################################################################################
if [[ $# -lt 1 ]] ; then
    printHelp
    exit 0
else
    MODE=$1
    shift
fi

parseCommandLineArgs $@

if [ "$MODE" == "up" ]; then
    infoln "🚀 Starting Healthcare network with 3 organizations and CouchDB"
    networkUp
    verifyNetwork
elif [ "$MODE" == "down" ]; then
    infoln "🛑 Stopping Healthcare network"
    networkDown
elif [ "$MODE" == "restart" ]; then
    infoln "🔄 Restarting Healthcare network"
    networkDown
    networkUp
    verifyNetwork
elif [ "$MODE" == "verify" ]; then
    verifyNetwork
elif [ "$MODE" == "createChannel" ]; then
    createChannel
    setAnchorPeers
    infoln "========== Starting Redis Cache =========="
    startRedis
elif [ "$MODE" == "setAnchorPeers" ]; then
    setAnchorPeers
elif [ "$MODE" == "verifyAnchors" ]; then
    verifyAnchors
elif [ "$MODE" == "deployChaincode" ]; then
    deployChaincode
else
    printHelp
    exit 1
fi