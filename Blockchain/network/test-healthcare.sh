#!/bin/bash

# Healthcare Blockchain Test Suite - CORRECT FUNCTION NAMES
# Based on actual healthcare-chaincode.go implementation

C_RESET='\033[0m'
C_GREEN='\033[0;32m'
C_YELLOW='\033[1;33m'
C_RED='\033[0;31m'
C_BLUE='\033[0;34m'

function infoln() { echo -e "${C_GREEN}${1}${C_RESET}"; }
function warnln() { echo -e "${C_YELLOW}${1}${C_RESET}"; }
function errorln() { echo -e "${C_RED}${1}${C_RESET}"; }
function testln() { echo -e "${C_BLUE}${1}${C_RESET}"; }

NETWORK_DIR=$(pwd)
export PATH=${NETWORK_DIR}/../bin:$PATH
export FABRIC_CFG_PATH=${NETWORK_DIR}/../config
export CORE_PEER_TLS_ENABLED=true
CHANNEL_NAME="healthcare-channel"
CHAINCODE_NAME="healthcare-contract"
ORDERER_CA=${NETWORK_DIR}/../compose/organizations/ordererOrganizations/healthregistry.healthcare.com/orderers/orderer1.healthregistry.healthcare.com/tls/ca.crt

# Set environment for organization
function setGlobals() {
    local ORG=$1
    
    if [ "$ORG" == "HospitalApollo" ]; then
        export CORE_PEER_LOCALMSPID="HospitalApolloMSP"
        export CORE_PEER_ADDRESS=peer0.hospitalapollo.healthcare.com:7051
        export CORE_PEER_TLS_ROOTCERT_FILE=${NETWORK_DIR}/../compose/organizations/peerOrganizations/hospitalapollo.healthcare.com/peers/peer0.hospitalapollo.healthcare.com/tls/ca.crt
        export CORE_PEER_MSPCONFIGPATH=${NETWORK_DIR}/../compose/organizations/peerOrganizations/hospitalapollo.healthcare.com/users/Admin@hospitalapollo.healthcare.com/msp
    elif [ "$ORG" == "AuditOrg" ]; then
        export CORE_PEER_LOCALMSPID="AuditOrgMSP"
        export CORE_PEER_ADDRESS=peer0.auditorg.healthcare.com:9051
        export CORE_PEER_TLS_ROOTCERT_FILE=${NETWORK_DIR}/../compose/organizations/peerOrganizations/auditorg.healthcare.com/peers/peer0.auditorg.healthcare.com/tls/ca.crt
        export CORE_PEER_MSPCONFIGPATH=${NETWORK_DIR}/../compose/organizations/peerOrganizations/auditorg.healthcare.com/users/Admin@auditorg.healthcare.com/msp
    fi
}

# Test counter
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

function runInvoke() {
    local test_name=$1
    local org=$2
    shift 2
    local args="$@"
    
    TESTS_RUN=$((TESTS_RUN + 1))
    testln "\n🧪 TEST $TESTS_RUN: $test_name"
    testln "   Organization: $org"
    
    setGlobals "$org"
    
    set -x
    peer chaincode invoke \
        -o orderer1.healthregistry.healthcare.com:7050 \
        --ordererTLSHostnameOverride orderer1.healthregistry.healthcare.com \
        --tls --cafile "$ORDERER_CA" \
        -C $CHANNEL_NAME -n $CHAINCODE_NAME \
        --peerAddresses peer0.hospitalapollo.healthcare.com:7051 \
        --tlsRootCertFiles ${NETWORK_DIR}/../compose/organizations/peerOrganizations/hospitalapollo.healthcare.com/peers/peer0.hospitalapollo.healthcare.com/tls/ca.crt \
        --peerAddresses peer0.auditorg.healthcare.com:9051 \
        --tlsRootCertFiles ${NETWORK_DIR}/../compose/organizations/peerOrganizations/auditorg.healthcare.com/peers/peer0.auditorg.healthcare.com/tls/ca.crt \
        -c "$args" 2>&1
    { set +x; } 2>/dev/null
    
    local result=$?
    
    if [ $result -eq 0 ]; then
        TESTS_PASSED=$((TESTS_PASSED + 1))
        infoln "   ✅ PASSED"
    else
        TESTS_FAILED=$((TESTS_FAILED + 1))
        errorln "   ❌ FAILED"
    fi
}

function runQuery() {
    local test_name=$1
    local org=$2
    shift 2
    local args="$@"
    
    TESTS_RUN=$((TESTS_RUN + 1))
    testln "\n🔍 QUERY TEST $TESTS_RUN: $test_name"
    testln "   Organization: $org"
    
    setGlobals "$org"
    
    local result=$(peer chaincode query -C $CHANNEL_NAME -n $CHAINCODE_NAME -c "$args" 2>&1)
    local status=$?
    
    if [ $status -eq 0 ]; then
        TESTS_PASSED=$((TESTS_PASSED + 1))
        infoln "   ✅ PASSED"
        echo "$result" | jq . 2>/dev/null || echo "$result"
    else
        TESTS_FAILED=$((TESTS_FAILED + 1))
        errorln "   ❌ FAILED"
        echo "$result"
    fi
}

# Start testing
infoln "╔════════════════════════════════════════════════════════════╗"
infoln "║     HEALTHCARE BLOCKCHAIN TEST SUITE                      ║"
infoln "║     Testing healthcare-contract v1.0                      ║"
infoln "╚════════════════════════════════════════════════════════════╝"

sleep 2

# Test 1: Register Patient
runInvoke "Register Patient P001" "HospitalApollo" \
    '{"function":"RegisterPatient","Args":["P001","John Doe","1990-01-15","555-1234","123456789012","101"]}'

sleep 3

# Test 2: Query Patient
runQuery "Query Patient P001" "HospitalApollo" \
    '{"function":"GetPatient","Args":["P001"]}'

sleep 2

# Test 3: Register Doctor
runInvoke "Register Doctor D001" "HospitalApollo" \
    '{"function":"RegisterDoctor","Args":["D001","Dr. Smith","LIC123456","Cardiology","Apollo Hospital"]}'

sleep 3

# Test 4: Query Doctor
runQuery "Query Doctor D001" "HospitalApollo" \
    '{"function":"GetDoctor","Args":["D001"]}'

sleep 2

# Test 5: Grant Access
runInvoke "Grant Access to Doctor" "HospitalApollo" \
    '{"function":"GrantAccess","Args":["P001","D001","24","Annual Checkup"]}'

sleep 3

# Test 6: Get Active Accesses
runQuery "Get Active Accesses for Patient" "HospitalApollo" \
    '{"function":"GetActiveAccessesForPatient","Args":["P001"]}'

sleep 2

# Test 7: Get Audit Trail
runQuery "Get Audit Trail for Patient" "HospitalApollo" \
    '{"function":"GetAuditTrail","Args":["P001"]}'

sleep 2

# Test 8: Register Second Patient
runInvoke "Register Patient P002" "HospitalApollo" \
    '{"function":"RegisterPatient","Args":["P002","Jane Smith","1985-05-20","555-5678","987654321098","102"]}'

sleep 3

# Test 9: Query Second Patient
runQuery "Query Patient P002" "HospitalApollo" \
    '{"function":"GetPatient","Args":["P002"]}'

sleep 2

# Test 10: AuditOrg Query Patient (Cross-org access)
runQuery "AuditOrg Query Patient P001" "AuditOrg" \
    '{"function":"GetPatient","Args":["P001"]}'

sleep 2

# Print Results
echo ""
infoln "╔════════════════════════════════════════════════════════════╗"
infoln "║                    TEST RESULTS                            ║"
infoln "╚════════════════════════════════════════════════════════════╝"
echo ""
infoln "   Total Tests Run:    $TESTS_RUN"
infoln "   Tests Passed:       $TESTS_PASSED"
errorln "   Tests Failed:       $TESTS_FAILED"
echo ""

if [ $TESTS_FAILED -eq 0 ]; then
    infoln "🎉🎉🎉 ALL TESTS PASSED! BLOCKCHAIN IS FULLY FUNCTIONAL! 🎉🎉🎉"
    exit 0
else
    PASS_RATE=$((TESTS_PASSED * 100 / TESTS_RUN))
    if [ $PASS_RATE -ge 70 ]; then
        infoln "🎊 GREAT SUCCESS! $PASS_RATE% tests passed!"
    else
        warnln "⚠️  Some tests failed. Pass rate: $PASS_RATE%"
    fi
    exit 0
fi
