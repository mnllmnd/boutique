#!/usr/bin/env node
/**
 * Test script to verify backend endpoints are working
 */
const http = require('http');

const baseUrl = 'http://localhost:3000';
const endpoints = [
  { method: 'GET', path: '/api/auth/health', name: 'Auth Health Check' },
  { method: 'GET', path: '/api/auth/debug/schema', name: 'Database Schema Check' },
  { method: 'GET', path: '/api/auth/guests', name: 'List Guests' },
  { method: 'POST', path: '/api/auth/create-guest', name: 'Create Guest (should fail with 500 if DB ok)' },
];

async function testEndpoint(method, path) {
  return new Promise((resolve) => {
    const url = new URL(path, baseUrl);
    
    console.log(`\n🔧 Testing: ${method} ${path}`);
    console.log('─'.repeat(60));
    
    const options = {
      method,
      hostname: url.hostname,
      port: url.port,
      path: url.pathname + url.search,
      timeout: 5000,
    };
    
    const req = http.request(options, (res) => {
      let data = '';
      
      res.on('data', chunk => data += chunk);
      res.on('end', () => {
        console.log(`Status: ${res.statusCode}`);
        console.log(`Headers: ${JSON.stringify(res.headers, null, 2)}`);
        try {
          if (data) {
            console.log(`Body: ${JSON.stringify(JSON.parse(data), null, 2)}`);
          }
        } catch {
          console.log(`Body: ${data}`);
        }
        resolve({ status: res.statusCode, ok: res.statusCode >= 200 && res.statusCode < 300 });
      });
    });
    
    req.on('error', (err) => {
      console.error(`❌ Error: ${err.message}`);
      resolve({ status: 0, ok: false });
    });
    
    req.on('timeout', () => {
      console.error('❌ Timeout - server not responding');
      req.destroy();
      resolve({ status: 0, ok: false });
    });
    
    if (method === 'POST') {
      req.write('{}');
    }
    
    req.end();
  });
}

async function runTests() {
  console.log('🚀 Starting Backend Diagnostics');
  console.log('═'.repeat(60));
  console.log(`Testing server: ${baseUrl}\n`);
  
  let results = [];
  
  for (const { method, path, name } of endpoints) {
    const result = await testEndpoint(method, path);
    results.push({ name, ...result });
    await new Promise(r => setTimeout(r, 500)); // 500ms delay between requests
  }
  
  console.log('\n\n' + '═'.repeat(60));
  console.log('📊 Test Summary');
  console.log('═'.repeat(60));
  
  for (const { name, ok, status } of results) {
    const icon = ok ? '✅' : '❌';
    console.log(`${icon} ${name}: ${status}`);
  }
  
  const allPassed = results.every(r => r.ok);
  console.log('\n' + (allPassed ? '✅ All tests passed!' : '❌ Some tests failed'));
}

runTests().catch(console.error);
