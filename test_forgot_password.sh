#!/bin/bash
# Test script for forgot password feature

API_HOST="http://localhost:3000/api"

echo "=== Testing Forgot Password Feature ==="

# Step 1: Register a test user
echo ""
echo "Step 1: Registering a test user..."
REGISTER_RESPONSE=$(curl -s -X POST "$API_HOST/auth/register" \
  -H "Content-Type: application/json" \
  -d '{
    "phone": "+212601234567",
    "password": "TestPassword123",
    "first_name": "Test",
    "last_name": "User",
    "shop_name": "Test Shop",
    "security_question": "What is your pet name?",
    "security_answer": "Fluffy"
  }')

echo "Registration Response: $REGISTER_RESPONSE"
USER_ID=$(echo $REGISTER_RESPONSE | grep -o '"id":[^,}]*' | cut -d: -f2)
echo "User ID: $USER_ID"

# Step 2: Try to login (should work)
echo ""
echo "Step 2: Testing login with new credentials..."
LOGIN_RESPONSE=$(curl -s -X POST "$API_HOST/auth/login" \
  -H "Content-Type: application/json" \
  -d '{
    "phone": "+212601234567",
    "password": "TestPassword123"
  }')

echo "Login Response: $LOGIN_RESPONSE"

# Step 3: Forget password - get security question
echo ""
echo "Step 3: Requesting security question for password recovery..."
FORGOT_RESPONSE=$(curl -s -X GET "$API_HOST/auth/forgot-password/%2B212601234567")

echo "Forgot Password Response: $FORGOT_RESPONSE"

# Step 4: Reset password with security answer
echo ""
echo "Step 4: Resetting password with security answer..."
RESET_RESPONSE=$(curl -s -X POST "$API_HOST/auth/reset-password" \
  -H "Content-Type: application/json" \
  -d '{
    "phone": "+212601234567",
    "security_answer": "fluffy",
    "new_password": "NewPassword456"
  }')

echo "Reset Password Response: $RESET_RESPONSE"

# Step 5: Try to login with old password (should fail)
echo ""
echo "Step 5: Testing login with old password (should fail)..."
OLD_LOGIN_RESPONSE=$(curl -s -X POST "$API_HOST/auth/login" \
  -H "Content-Type: application/json" \
  -d '{
    "phone": "+212601234567",
    "password": "TestPassword123"
  }')

echo "Old Login Response: $OLD_LOGIN_RESPONSE"

# Step 6: Try to login with new password (should succeed)
echo ""
echo "Step 6: Testing login with new password (should succeed)..."
NEW_LOGIN_RESPONSE=$(curl -s -X POST "$API_HOST/auth/login" \
  -H "Content-Type: application/json" \
  -d '{
    "phone": "+212601234567",
    "password": "NewPassword456"
  }')

echo "New Login Response: $NEW_LOGIN_RESPONSE"

echo ""
echo "=== Test Complete ==="
