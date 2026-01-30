#!/bin/bash

# ============================================================================
# HEALTHCARE SETUP-ENV
# ============================================================================

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

function infoln() { echo -e "${GREEN}${1}${NC}"; }
function warnln() { echo -e "${YELLOW}${1}${NC}"; }
function blueln() { echo -e "${BLUE}${1}${NC}"; }

infoln "🏥 Setting up Healthcare Fabric environment..."

# Add ALL hostnames
HOSTS=(
    "orderer1.healthregistry.healthcare.com"
    "orderer2.healthregistry.healthcare.com"
    "orderer3.healthregistry.healthcare.com"
    "orderer4.healthregistry.healthcare.com"
    "peer0.hospitalapollo.healthcare.com"
    "peer1.hospitalapollo.healthcare.com"
    "peer0.auditorg.healthcare.com"
    "peer1.auditorg.healthcare.com"
)

for HOST in "${HOSTS[@]}"; do
    if ! grep -q "$HOST" /etc/hosts 2>/dev/null; then
        warnln "Adding $HOST to /etc/hosts"
        echo "127.0.0.1 $HOST" | sudo tee -a /etc/hosts >/dev/null
    fi
done

export FABRIC_CFG_PATH=${PWD}/../config
export CORE_PEER_TLS_ENABLED=true

################################################################################
# HEALTH REGISTRY ADMIN (DEFAULT)
################################################################################
function setHealthRegistryEnv() {
    infoln "🏛️ Setting Health Registry Admin environment"
    
    export CORE_PEER_LOCALMSPID="HealthRegistryMSP"
    export CORE_PEER_TLS_ROOTCERT_FILE=${PWD}/../compose/organizations/ordererOrganizations/healthregistry.healthcare.com/orderers/orderer1.healthregistry.healthcare.com/tls/ca.crt
    export CORE_PEER_MSPCONFIGPATH=${PWD}/../compose/organizations/ordererOrganizations/healthregistry.healthcare.com/users/Admin@healthregistry.healthcare.com/msp
    export CORE_PEER_ADDRESS=orderer1.healthregistry.healthcare.com:7050
    
    export ORDERER_CA=${PWD}/../compose/organizations/ordererOrganizations/healthregistry.healthcare.com/orderers/orderer1.healthregistry.healthcare.com/tls/ca.crt
    export ORDERER_ADMIN_TLS_SIGN_CERT=${PWD}/../compose/organizations/ordererOrganizations/healthregistry.healthcare.com/orderers/orderer1.healthregistry.healthcare.com/tls/server.crt
    export ORDERER_ADMIN_TLS_PRIVATE_KEY=${PWD}/../compose/organizations/ordererOrganizations/healthregistry.healthcare.com/orderers/orderer1.healthregistry.healthcare.com/tls/server.key
    
    blueln "✅ Health Registry Admin active (orderer1)"
}

################################################################################
# HOSPITAL APOLLO (can switch between peer0 and peer1)
################################################################################
function setHospitalApolloEnv() {
    local PEER_NUM=${1:-0}
    infoln "🏥 Setting Hospital Apollo peer${PEER_NUM} environment"
    
    export CORE_PEER_LOCALMSPID="HospitalApolloMSP"
    export CORE_PEER_TLS_ROOTCERT_FILE=${PWD}/../compose/organizations/peerOrganizations/hospitalapollo.healthcare.com/peers/peer${PEER_NUM}.hospitalapollo.healthcare.com/tls/ca.crt
    export CORE_PEER_MSPCONFIGPATH=${PWD}/../compose/organizations/peerOrganizations/hospitalapollo.healthcare.com/users/Admin@hospitalapollo.healthcare.com/msp
    
    if [ "$PEER_NUM" -eq 0 ]; then
        export CORE_PEER_ADDRESS=peer0.hospitalapollo.healthcare.com:7051
    else
        export CORE_PEER_ADDRESS=peer1.hospitalapollo.healthcare.com:8051
    fi
    
    blueln "✅ Hospital Apollo peer${PEER_NUM} active"
}

################################################################################
# AUDIT ORG (can switch between peer0 and peer1)
################################################################################
function setAuditOrgEnv() {
    local PEER_NUM=${1:-0}
    infoln "🔍 Setting Audit Org peer${PEER_NUM} environment"
    
    export CORE_PEER_LOCALMSPID="AuditOrgMSP"
    export CORE_PEER_TLS_ROOTCERT_FILE=${PWD}/../compose/organizations/peerOrganizations/auditorg.healthcare.com/peers/peer${PEER_NUM}.auditorg.healthcare.com/tls/ca.crt
    export CORE_PEER_MSPCONFIGPATH=${PWD}/../compose/organizations/peerOrganizations/auditorg.healthcare.com/users/Admin@auditorg.healthcare.com/msp
    
    if [ "$PEER_NUM" -eq 0 ]; then
        export CORE_PEER_ADDRESS=peer0.auditorg.healthcare.com:9051
    else
        export CORE_PEER_ADDRESS=peer1.auditorg.healthcare.com:10051
    fi
    
    blueln "✅ Audit Org peer${PEER_NUM} active"
}

# Default to Health Registry
setHealthRegistryEnv

infoln "✅ Healthcare environment configured"
blueln "🎯 HEALTHCARE ARCHITECTURE:"
blueln "   4 Orderers (SmartBFT cluster)"
blueln "   4 Peers (2 per org)"
infoln ""
infoln "🔄 Switch organizations:"
infoln "   setHospitalApolloEnv 0   # peer0"
infoln "   setHospitalApolloEnv 1   # peer1"
infoln "   setAuditOrgEnv 0         # peer0"
infoln "   setAuditOrgEnv 1         # peer1"
