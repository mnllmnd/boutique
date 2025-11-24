#!/usr/bin/env node
/**
 * Test script to verify balance column refactoring
 * 
 * Tests that the 'amount' column always represents remaining balance
 * and never the cumulative total.
 */

const http = require('http');
const baseUrl = 'http://localhost:3000';

// Test data
let testDebtId = null;
let testClientId = null;
let testOwner = 'test-owner';

const tests = [
  { name: 'Create a test client', fn: createTestClient },
  { name: 'Create a new debt with initial amount 100', fn: createInitialDebt },
  { name: 'Verify initial amount equals remaining balance', fn: verifyInitialAmount },
  { name: 'Add 50 to debt (should have remaining = 150)', fn: addAmountToDebt },
  { name: 'Verify amount after addition = 150 (not 100+50)', fn: verifyAmountAfterAddition },
  { name: 'Record payment of 30 (should have remaining = 120)', fn: recordPayment },
  { name: 'Verify amount after payment = 120', fn: verifyAmountAfterPayment },
  { name: 'Try to directly update amount (should fail)', fn: tryDirectAmountUpdate },
  { name: 'Verify amount cannot be manually updated', fn: verifyAmountProtected },
  { name: 'Retrieve debt and confirm total calculations', fn: retrieveDebtDetails },
];

let passCount = 0;
let failCount = 0;

async function httpRequest(method, path, body = null, headers = {}) {
  return new Promise((resolve) => {
    const url = new URL(path, baseUrl);
    
    const options = {
      method,
      hostname: url.hostname,
      port: url.port,
      path: url.pathname + url.search,
      headers: {
        'Content-Type': 'application/json',
        'X-Owner': testOwner,
        ...headers,
      },
      timeout: 5000,
    };
    
    const req = http.request(options, (res) => {
      let data = '';
      res.on('data', chunk => data += chunk);
      res.on('end', () => {
        try {
          const parsed = data ? JSON.parse(data) : null;
          resolve({ status: res.statusCode, body: parsed, raw: data });
        } catch {
          resolve({ status: res.statusCode, body: null, raw: data });
        }
      });
    });
    
    req.on('error', (err) => {
      resolve({ status: 0, body: null, error: err.message });
    });
    
    if (body) {
      req.write(JSON.stringify(body));
    }
    req.end();
  });
}

async function createTestClient() {
  console.log('\n📌 Creating test client...');
  const res = await httpRequest('POST', '/api/clients', {
    name: `Test Client ${Date.now()}`,
    client_number: `TEST-${Date.now()}`,
  });
  
  if (res.status === 201 && res.body && res.body.id) {
    testClientId = res.body.id;
    console.log(`✅ Client created with ID: ${testClientId}`);
    passCount++;
    return true;
  } else {
    console.log(`❌ Failed to create client. Status: ${res.status}`);
    failCount++;
    return false;
  }
}

async function createInitialDebt() {
  console.log('\n💳 Creating initial debt of 100...');
  const res = await httpRequest('POST', '/api/debts', {
    client_id: testClientId,
    amount: 100,
    notes: 'Test debt for balance refactoring',
    type: 'debt',
  });
  
  if (res.status === 201 && res.body && res.body.id) {
    testDebtId = res.body.id;
    console.log(`✅ Debt created with ID: ${testDebtId}`);
    console.log(`   Amount: ${res.body.amount}, Remaining: ${res.body.remaining}`);
    passCount++;
    return true;
  } else {
    console.log(`❌ Failed to create debt. Status: ${res.status}`);
    console.log(`Response:`, res.body);
    failCount++;
    return false;
  }
}

async function verifyInitialAmount() {
  console.log('\n🔍 Verifying initial amount = remaining balance...');
  const res = await httpRequest('GET', `/api/debts/${testDebtId}`);
  
  if (res.status === 200 && res.body) {
    const amount = parseFloat(res.body.amount);
    const remaining = parseFloat(res.body.remaining);
    
    console.log(`   amount: ${amount}, remaining: ${remaining}`);
    
    if (Math.abs(amount - remaining) < 0.01 && Math.abs(amount - 100) < 0.01) {
      console.log(`✅ Initial amount equals remaining balance (both 100)`);
      passCount++;
      return true;
    } else {
      console.log(`❌ Amount mismatch. amount=${amount}, remaining=${remaining}`);
      failCount++;
      return false;
    }
  } else {
    console.log(`❌ Failed to retrieve debt. Status: ${res.status}`);
    failCount++;
    return false;
  }
}

async function addAmountToDebt() {
  console.log('\n➕ Adding 50 to debt...');
  const res = await httpRequest('POST', `/api/debts/${testDebtId}/add`, {
    amount: 50,
    notes: 'Additional amount test',
  });
  
  if (res.status === 201) {
    console.log(`✅ Amount added. New remaining: ${res.body.remaining}`);
    passCount++;
    return true;
  } else {
    console.log(`❌ Failed to add amount. Status: ${res.status}`);
    console.log(`Response:`, res.body);
    failCount++;
    return false;
  }
}

async function verifyAmountAfterAddition() {
  console.log('\n🔍 Verifying amount after addition = 150...');
  const res = await httpRequest('GET', `/api/debts/${testDebtId}`);
  
  if (res.status === 200 && res.body) {
    const amount = parseFloat(res.body.amount);
    const remaining = parseFloat(res.body.remaining);
    const totalDebt = parseFloat(res.body.total_debt);
    
    console.log(`   amount: ${amount}, total_debt: ${totalDebt}, remaining: ${remaining}`);
    
    // amount should equal remaining (150)
    // total_debt should be original 100 + addition 50 = 150
    if (Math.abs(amount - 150) < 0.01 && Math.abs(remaining - 150) < 0.01 && Math.abs(totalDebt - 150) < 0.01) {
      console.log(`✅ Amount correctly updated to 150 (not 100+50 as old logic would do)`);
      passCount++;
      return true;
    } else {
      console.log(`❌ Amount mismatch after addition. amount=${amount}, expected=150`);
      failCount++;
      return false;
    }
  } else {
    console.log(`❌ Failed to retrieve debt. Status: ${res.status}`);
    failCount++;
    return false;
  }
}

async function recordPayment() {
  console.log('\n💰 Recording payment of 30...');
  const res = await httpRequest('POST', `/api/debts/${testDebtId}/pay`, {
    amount: 30,
    notes: 'Test payment',
  });
  
  if (res.status === 201) {
    console.log(`✅ Payment recorded. New remaining: ${res.body.remaining}`);
    passCount++;
    return true;
  } else {
    console.log(`❌ Failed to record payment. Status: ${res.status}`);
    console.log(`Response:`, res.body);
    failCount++;
    return false;
  }
}

async function verifyAmountAfterPayment() {
  console.log('\n🔍 Verifying amount after payment = 120...');
  const res = await httpRequest('GET', `/api/debts/${testDebtId}`);
  
  if (res.status === 200 && res.body) {
    const amount = parseFloat(res.body.amount);
    const remaining = parseFloat(res.body.remaining);
    const totalPaid = parseFloat(res.body.total_paid);
    
    console.log(`   amount: ${amount}, total_paid: ${totalPaid}, remaining: ${remaining}`);
    
    // amount should equal remaining (150 - 30 = 120)
    if (Math.abs(amount - 120) < 0.01 && Math.abs(remaining - 120) < 0.01) {
      console.log(`✅ Amount correctly updated to 120 after payment`);
      passCount++;
      return true;
    } else {
      console.log(`❌ Amount mismatch after payment. amount=${amount}, expected=120`);
      failCount++;
      return false;
    }
  } else {
    console.log(`❌ Failed to retrieve debt. Status: ${res.status}`);
    failCount++;
    return false;
  }
}

async function tryDirectAmountUpdate() {
  console.log('\n🚫 Attempting direct amount update (should fail)...');
  const res = await httpRequest('PUT', `/api/debts/${testDebtId}`, {
    amount: 999,
  });
  
  if (res.status === 400) {
    console.log(`✅ Direct update correctly rejected with 400`);
    console.log(`   Error: ${res.body.error}`);
    passCount++;
    return true;
  } else {
    console.log(`❌ Direct update was not rejected. Status: ${res.status}`);
    failCount++;
    return false;
  }
}

async function verifyAmountProtected() {
  console.log('\n🔍 Verifying amount is still 120 (protected)...');
  const res = await httpRequest('GET', `/api/debts/${testDebtId}`);
  
  if (res.status === 200 && res.body) {
    const amount = parseFloat(res.body.amount);
    
    if (Math.abs(amount - 120) < 0.01) {
      console.log(`✅ Amount is protected and unchanged (still 120)`);
      passCount++;
      return true;
    } else {
      console.log(`❌ Amount was modified despite protection. amount=${amount}, expected=120`);
      failCount++;
      return false;
    }
  } else {
    console.log(`❌ Failed to retrieve debt. Status: ${res.status}`);
    failCount++;
    return false;
  }
}

async function retrieveDebtDetails() {
  console.log('\n📊 Retrieving full debt details...');
  const res = await httpRequest('GET', `/api/debts/${testDebtId}`);
  
  if (res.status === 200 && res.body) {
    console.log(`
   Debt Summary:
   - Original Amount: ${res.body.original_amount || 'N/A'}
   - Current Amount: ${res.body.amount}
   - Total Debt: ${res.body.total_debt}
   - Total Additions: ${res.body.total_additions}
   - Total Paid: ${res.body.total_paid}
   - Remaining: ${res.body.remaining}
   - Paid Status: ${res.body.paid}
    `);
    
    // Verify calculation: remaining = total_debt - total_paid
    const calculated = Math.abs((parseFloat(res.body.total_debt) - parseFloat(res.body.total_paid)) - parseFloat(res.body.remaining)) < 0.01;
    
    if (calculated && Math.abs(parseFloat(res.body.amount) - parseFloat(res.body.remaining)) < 0.01) {
      console.log(`✅ All calculations are consistent`);
      passCount++;
      return true;
    } else {
      console.log(`❌ Calculation inconsistency detected`);
      failCount++;
      return false;
    }
  } else {
    console.log(`❌ Failed to retrieve debt. Status: ${res.status}`);
    failCount++;
    return false;
  }
}

async function runTests() {
  console.log('🧪 Balance Column Refactoring Test Suite');
  console.log('═'.repeat(60));
  console.log(`Server: ${baseUrl}`);
  console.log(`Test Owner: ${testOwner}`);
  console.log('═'.repeat(60));
  
  for (const test of tests) {
    try {
      await test.fn();
    } catch (err) {
      console.error(`❌ Test error: ${err.message}`);
      failCount++;
    }
  }
  
  console.log('\n' + '═'.repeat(60));
  console.log(`📈 Test Results: ${passCount} passed, ${failCount} failed`);
  console.log('═'.repeat(60));
  
  if (failCount === 0) {
    console.log('\n✅ All tests passed! Balance refactoring is working correctly.');
    process.exit(0);
  } else {
    console.log(`\n❌ ${failCount} test(s) failed.`);
    process.exit(1);
  }
}

runTests().catch(err => {
  console.error('Fatal error:', err);
  process.exit(1);
});
