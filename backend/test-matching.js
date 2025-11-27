// Test du système de matching automatique
// À exécuter après le démarrage du backend

const http = require('http');
const api = 'http://localhost:3000/api';
const owner = '+237600000000';

const headers = {
  'Content-Type': 'application/json',
  'x-owner': owner
};

async function test(name, method, path, body) {
  return new Promise((resolve) => {
    const url = new URL(`${api}${path}`);
    const options = {
      hostname: url.hostname,
      port: url.port,
      path: url.pathname + url.search,
      method: method,
      headers: headers,
    };

    const req = http.request(options, (res) => {
      let data = '';
      res.on('data', (chunk) => { data += chunk; });
      res.on('end', () => {
        console.log(`\n✅ ${name}`);
        console.log(`   Status: ${res.statusCode}`);
        try {
          const json = JSON.parse(data);
          console.log(`   Response:`, JSON.stringify(json, null, 2));
        } catch {
          console.log(`   Response: ${data}`);
        }
        resolve();
      });
    });

    req.on('error', (e) => {
      console.error(`\n❌ ${name}`, e.message);
      resolve();
    });

    if (body) req.write(JSON.stringify(body));
    req.end();
  });
}

async function runTests() {
  console.log('🧪 Test du Système de Matching Automatique\n');
  console.log(`Owner: ${owner}\n`);

  // Test 1: Créer un client
  await test(
    'Test 1: Créer un client "Jean" avec numéro +237123456789',
    'POST',
    '/clients',
    {
      client_number: '+237 123 456 789',
      name: 'Jean Dupont'
    }
  );

  // Test 2: Créer une dette avec le MÊME numéro (format différent)
  await test(
    'Test 2: Créer une dette avec le même numéro (format: +237-123-456-789)',
    'POST',
    '/debts',
    {
      client_number: '+237-123-456-789',
      amount: 5000,
      type: 'debt',
      notes: 'Test matching automatique'
    }
  );

  // Test 3: Créer un autre client
  await test(
    'Test 3: Créer un nouveau client "Marie" avec numéro +237999888777',
    'POST',
    '/clients',
    {
      client_number: '+237 999 888 777',
      name: 'Marie Durand'
    }
  );

  // Test 4: Créer un emprunt avec le numéro de Marie
  await test(
    'Test 4: Créer un emprunt avec le numéro de Marie (format: 237999888777)',
    'POST',
    '/debts/loans',
    {
      client_number: '237999888777',
      amount: 3000,
      notes: 'Emprunt test'
    }
  );

  // Test 5: Lister les clients
  await test(
    'Test 5: Lister tous les clients',
    'GET',
    '/clients',
    null
  );

  // Test 6: Lister les dettes
  await test(
    'Test 6: Lister toutes les dettes',
    'GET',
    '/debts',
    null
  );

  console.log('\n✨ Tests complétés!\n');
  console.log('📊 Résultats attendus:');
  console.log('   - Test 1: Nouveau client créé (status 201)');
  console.log('   - Test 2: Client matché automatiquement (matching.existed = true)');
  console.log('   - Test 3: Nouveau client créé (status 201)');
  console.log('   - Test 4: Client matché automatiquement (matching.existed = true)');
  console.log('   - Test 5: 2 clients affichés (Jean et Marie)');
  console.log('   - Test 6: 2 dettes affichées (1 prêt, 1 emprunt)');
}

runTests().catch(console.error);
