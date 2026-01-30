#!/bin/bash

API_BASE="http://localhost:3000/api/v1"

echo "🧪 HEALTHCARE BLOCKCHAIN API TESTS"
echo "===================================="
echo ""

# Test 1: Register Patient
echo "📝 TEST 1: Register Patient P001"
curl -X POST "$API_BASE/patients/register" \
  -H "Content-Type: application/json" \
  -d '{
    "patientID": "P001",
    "name": "John Doe",
    "dateOfBirth": "1990-01-15",
    "phone": "5551234567",
    "aadharNumber": "123456789012",
    "fingerprintTemplateID": 101
  }' | jq .
echo ""
echo "⏳ Waiting 3 seconds..."
sleep 3

# Test 2: Get Patient
echo "🔍 TEST 2: Get Patient P001"
curl -X GET "$API_BASE/patients/P001" | jq .
echo ""
sleep 2

# Test 3: Register Doctor
echo "📝 TEST 3: Register Doctor D001"
curl -X POST "$API_BASE/doctors/register" \
  -H "Content-Type: application/json" \
  -d '{
    "doctorID": "D001",
    "name": "Dr. Sarah Smith",
    "licenseNumber": "LIC123456",
    "specialization": "Cardiology",
    "hospitalName": "Apollo Hospital"
  }' | jq .
echo ""
echo "⏳ Waiting 3 seconds..."
sleep 3

# Test 4: Get Doctor
echo "🔍 TEST 4: Get Doctor D001"
curl -X GET "$API_BASE/doctors/D001" | jq .
echo ""
sleep 2

# Test 5: Grant Access
echo "📝 TEST 5: Grant Access to Doctor"
ACCESS_RESPONSE=$(curl -s -X POST "$API_BASE/access/grant" \
  -H "Content-Type: application/json" \
  -d '{
    "patientID": "P001",
    "doctorID": "D001",
    "durationHours": 24,
    "purpose": "Annual health checkup"
  }')
echo "$ACCESS_RESPONSE" | jq .
ACCESS_KEY=$(echo "$ACCESS_RESPONSE" | jq -r '.data.accessKey')
echo ""
echo "⏳ Waiting 3 seconds..."
sleep 3

# Test 6: Check Access Validity
echo "🔍 TEST 6: Check Access Validity"
curl -X GET "$API_BASE/access/$ACCESS_KEY/validity" | jq .
echo ""
sleep 2

# Test 7: Get Patient Accesses
echo "🔍 TEST 7: Get Patient Active Accesses"
curl -X GET "$API_BASE/patients/P001/accesses" | jq .
echo ""
sleep 2

# Test 8: Get Audit Trail
echo "🔍 TEST 8: Get Patient Audit Trail"
curl -X GET "$API_BASE/patients/P001/audit" | jq .
echo ""
sleep 2

# Test 9: Register Second Patient
echo "📝 TEST 9: Register Patient P002"
curl -X POST "$API_BASE/patients/register" \
  -H "Content-Type: application/json" \
  -d '{
    "patientID": "P002",
    "name": "Jane Smith",
    "dateOfBirth": "1985-05-20",
    "phone": "5559876543",
    "aadharNumber": "987654321098",
    "fingerprintTemplateID": 102
  }' | jq .
echo ""
echo "⏳ Waiting 3 seconds..."
sleep 3

# Test 10: Revoke Access
echo "📝 TEST 10: Revoke Access"
curl -X DELETE "$API_BASE/access/$ACCESS_KEY" | jq .
echo ""

echo ""
echo "✅ ALL TESTS COMPLETED!"
echo "===================================="
