#!/bin/bash

# ============================================================================
# HEALTHCARE BLOCKCHAIN API TEST SCRIPT
# ============================================================================
# This script tests all API endpoints with realistic data
# ============================================================================

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# API Configuration
API_URL="http://localhost:3000/api/v1"
HEALTH_URL="http://localhost:3000/health"

# Test counters
TESTS_PASSED=0
TESTS_FAILED=0

# Function to print colored output
print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_header() {
    echo ""
    echo -e "${BLUE}================================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}================================================${NC}"
}

# Function to test an API endpoint
test_api() {
    local test_name="$1"
    local method="$2"
    local endpoint="$3"
    local data="$4"
    local expected_success="$5"

    print_info "Testing: $test_name"
    
    if [ "$method" = "GET" ]; then
        response=$(curl -s -w "\n%{http_code}" "$endpoint")
    else
        response=$(curl -s -w "\n%{http_code}" -X "$method" "$endpoint" \
            -H "Content-Type: application/json" \
            -d "$data")
    fi
    
    http_code=$(echo "$response" | tail -n 1)
    body=$(echo "$response" | sed '$d')
    
    # Pretty print JSON response
    echo "$body" | jq '.' 2>/dev/null || echo "$body"
    
    if [ "$http_code" -ge 200 ] && [ "$http_code" -lt 300 ]; then
        print_success "$test_name - HTTP $http_code"
        TESTS_PASSED=$((TESTS_PASSED + 1))
        echo "$body"
        return 0
    else
        print_error "$test_name - HTTP $http_code"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        echo "$body"
        return 1
    fi
}

# ============================================================================
# START TESTS
# ============================================================================

print_header "HEALTHCARE BLOCKCHAIN API TESTS"
print_info "Testing API at: $API_URL"
print_info "Started at: $(date)"
echo ""

# ============================================================================
# TEST 1: Health Check
# ============================================================================
print_header "TEST 1: Health Check"
test_api "Health Check" "GET" "$HEALTH_URL" "" true

# ============================================================================
# TEST 2: Register Patient
# ============================================================================
print_header "TEST 2: Register Patient"

PATIENT_DATA='{
  "name": "John Doe",
  "dateOfBirth": "1990-01-15",
  "phone": "+919876543210",
  "aadharNumber": "123456789012",
  "password": "SecurePassword123!",
  "fingerprintTemplateID": 1234
}'

PATIENT_RESPONSE=$(curl -s -X POST "$API_URL/patients/register" \
    -H "Content-Type: application/json" \
    -d "$PATIENT_DATA")

echo "$PATIENT_RESPONSE" | jq '.'

# Extract patient ID
PATIENT_ID=$(echo "$PATIENT_RESPONSE" | jq -r '.data.patientID // empty')

if [ -n "$PATIENT_ID" ]; then
    print_success "Patient registered with ID: $PATIENT_ID"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    print_error "Failed to register patient"
    TESTS_FAILED=$((TESTS_FAILED + 1))
fi

# ============================================================================
# TEST 3: Register Another Patient
# ============================================================================
print_header "TEST 3: Register Another Patient"

PATIENT2_DATA='{
  "name": "Jane Smith",
  "dateOfBirth": "1985-05-20",
  "phone": "+919876543211",
  "aadharNumber": "987654321098",
  "password": "JaneSecure456!",
  "fingerprintTemplateID": 5678
}'

PATIENT2_RESPONSE=$(curl -s -X POST "$API_URL/patients/register" \
    -H "Content-Type: application/json" \
    -d "$PATIENT2_DATA")

echo "$PATIENT2_RESPONSE" | jq '.'

PATIENT2_ID=$(echo "$PATIENT2_RESPONSE" | jq -r '.data.patientID // empty')

if [ -n "$PATIENT2_ID" ]; then
    print_success "Second patient registered with ID: $PATIENT2_ID"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    print_error "Failed to register second patient"
    TESTS_FAILED=$((TESTS_FAILED + 1))
fi

# ============================================================================
# TEST 4: Register Doctor
# ============================================================================
print_header "TEST 4: Register Doctor"

DOCTOR_DATA='{
  "name": "Dr. Sarah Wilson",
  "licenseNumber": "MED123456",
  "specialization": "Cardiology",
  "hospitalName": "Apollo Hospital",
  "password": "DoctorSecure789!"
}'

DOCTOR_RESPONSE=$(curl -s -X POST "$API_URL/doctors/register" \
    -H "Content-Type: application/json" \
    -d "$DOCTOR_DATA")

echo "$DOCTOR_RESPONSE" | jq '.'

DOCTOR_ID=$(echo "$DOCTOR_RESPONSE" | jq -r '.data.doctorID // empty')

if [ -n "$DOCTOR_ID" ]; then
    print_success "Doctor registered with ID: $DOCTOR_ID"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    print_error "Failed to register doctor"
    TESTS_FAILED=$((TESTS_FAILED + 1))
fi

# ============================================================================
# TEST 5: Login Patient
# ============================================================================
print_header "TEST 5: Login Patient"

if [ -n "$PATIENT_ID" ]; then
    LOGIN_DATA=$(cat <<EOF
{
  "patientID": "$PATIENT_ID",
  "password": "SecurePassword123!"
}
EOF
)

    LOGIN_RESPONSE=$(curl -s -X POST "$API_URL/auth/login/patient" \
        -H "Content-Type: application/json" \
        -d "$LOGIN_DATA")

    echo "$LOGIN_RESPONSE" | jq '.'

    PATIENT_TOKEN=$(echo "$LOGIN_RESPONSE" | jq -r '.token // empty')

    if [ -n "$PATIENT_TOKEN" ]; then
        print_success "Patient logged in successfully"
        print_info "Token: ${PATIENT_TOKEN:0:50}..."
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        print_error "Patient login failed"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
else
    print_warning "Skipping patient login test (no patient ID)"
fi

# ============================================================================
# TEST 6: Login Patient with Wrong Password
# ============================================================================
print_header "TEST 6: Login Patient with Wrong Password (Should Fail)"

if [ -n "$PATIENT_ID" ]; then
    WRONG_LOGIN_DATA=$(cat <<EOF
{
  "patientID": "$PATIENT_ID",
  "password": "WrongPassword123!"
}
EOF
)

    WRONG_LOGIN_RESPONSE=$(curl -s -X POST "$API_URL/auth/login/patient" \
        -H "Content-Type: application/json" \
        -d "$WRONG_LOGIN_DATA")

    echo "$WRONG_LOGIN_RESPONSE" | jq '.'

    if echo "$WRONG_LOGIN_RESPONSE" | grep -q "Invalid credentials"; then
        print_success "Correctly rejected wrong password"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        print_error "Should have rejected wrong password"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
else
    print_warning "Skipping wrong password test (no patient ID)"
fi

# ============================================================================
# TEST 7: Login Doctor
# ============================================================================
print_header "TEST 7: Login Doctor"

if [ -n "$DOCTOR_ID" ]; then
    DOCTOR_LOGIN_DATA=$(cat <<EOF
{
  "doctorID": "$DOCTOR_ID",
  "password": "DoctorSecure789!"
}
EOF
)

    DOCTOR_LOGIN_RESPONSE=$(curl -s -X POST "$API_URL/auth/login/doctor" \
        -H "Content-Type: application/json" \
        -d "$DOCTOR_LOGIN_DATA")

    echo "$DOCTOR_LOGIN_RESPONSE" | jq '.'

    DOCTOR_TOKEN=$(echo "$DOCTOR_LOGIN_RESPONSE" | jq -r '.token // empty')

    if [ -n "$DOCTOR_TOKEN" ]; then
        print_success "Doctor logged in successfully"
        print_info "Token: ${DOCTOR_TOKEN:0:50}..."
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        print_error "Doctor login failed"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
else
    print_warning "Skipping doctor login test (no doctor ID)"
fi

# ============================================================================
# TEST 8: Get Patient Details
# ============================================================================
print_header "TEST 8: Get Patient Details"

if [ -n "$PATIENT_ID" ]; then
    GET_PATIENT_RESPONSE=$(curl -s -X GET "$API_URL/patients/$PATIENT_ID")
    
    echo "$GET_PATIENT_RESPONSE" | jq '.'
    
    if echo "$GET_PATIENT_RESPONSE" | jq -e '.success == true' > /dev/null; then
        print_success "Retrieved patient details"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        print_error "Failed to retrieve patient details"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
else
    print_warning "Skipping get patient test (no patient ID)"
fi

# ============================================================================
# TEST 9: Get Doctor Details
# ============================================================================
print_header "TEST 9: Get Doctor Details"

if [ -n "$DOCTOR_ID" ]; then
    GET_DOCTOR_RESPONSE=$(curl -s -X GET "$API_URL/doctors/$DOCTOR_ID")
    
    echo "$GET_DOCTOR_RESPONSE" | jq '.'
    
    if echo "$GET_DOCTOR_RESPONSE" | jq -e '.success == true' > /dev/null; then
        print_success "Retrieved doctor details"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        print_error "Failed to retrieve doctor details"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
else
    print_warning "Skipping get doctor test (no doctor ID)"
fi

# ============================================================================
# TEST SUMMARY
# ============================================================================
print_header "TEST SUMMARY"

TOTAL_TESTS=$((TESTS_PASSED + TESTS_FAILED))

echo ""
print_info "Total Tests: $TOTAL_TESTS"
print_success "Passed: $TESTS_PASSED"
print_error "Failed: $TESTS_FAILED"
echo ""

if [ $TESTS_FAILED -eq 0 ]; then
    print_success "🎉 ALL TESTS PASSED!"
    echo ""
    print_info "Summary of Generated IDs:"
    [ -n "$PATIENT_ID" ] && echo "  Patient 1 ID: $PATIENT_ID"
    [ -n "$PATIENT2_ID" ] && echo "  Patient 2 ID: $PATIENT2_ID"
    [ -n "$DOCTOR_ID" ] && echo "  Doctor ID: $DOCTOR_ID"
    [ -n "$PATIENT_TOKEN" ] && echo "  Patient Token: ${PATIENT_TOKEN:0:30}..."
    [ -n "$DOCTOR_TOKEN" ] && echo "  Doctor Token: ${DOCTOR_TOKEN:0:30}..."
    echo ""
    exit 0
else
    print_error "⚠️  SOME TESTS FAILED"
    echo ""
    exit 1
fi
