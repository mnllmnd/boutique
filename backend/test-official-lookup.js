// Test du Lookup Annuaire Officiel
// Teste que les noms des propriétaires sont trouvés automatiquement

const http = require('http');
const api = 'http://localhost:3000/api';
const ownerA = '+237600000001';  // Jean (propriétaire A)
const ownerB = '+237600000002';  // Moi (propriétaire B)

const headers = (owner) => ({
  'Content-Type': 'application/json',
  'x-owner': owner
});

async function test(name, method, path, body, owner = ownerA) {
  return new Promise((resolve) => {
    const url = new URL(`${api}${path}`);
    const options = {
      hostname: url.hostname,
      port: url.port,
      path: url.pathname + url.search,
      method: method,
      headers: headers(owner),
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
  console.log('🧪 Test du Lookup Annuaire Officiel\n');
  console.log(`Owner A (Jean): ${ownerA}`);
  console.log(`Owner B (Moi):  ${ownerB}\n`);
  
  console.log('⚠️  IMPORTANT: Assurez-vous que:\n');
  console.log('1. La table owners contient:');
  console.log(`   - ${ownerA} avec shop_name="Boutique Jean" ou first_name="Jean"`);
  console.log(`   - ${ownerB} avec shop_name="Ma Boutique" ou first_name="Votre Nom"`);
  console.log('\n2. Exécutez ce SQL avant de lancer les tests:');
  console.log(`   INSERT INTO owners (phone, shop_name, first_name, last_name) VALUES\n` +
              `   ('${ownerA}', 'Boutique Jean', 'Jean', 'Dupont'),\n` +
              `   ('${ownerB}', 'Ma Boutique', 'Moi', 'User');\n`);
  console.log('═'.repeat(60) + '\n');

  // Test 1: Jean crée un client avec mon numéro
  await test(
    'Test 1: Jean crée un contact avec mon numéro',
    'POST',
    '/clients',
    {
      client_number: ownerB,
      name: 'Mon Client'
    },
    ownerA  // ← Jean (propriétaire A)
  );

  // Test 2: Jean crée une dette avec mon numéro (test lookup)
  await test(
    'Test 2: Jean crée une dette avec mon numéro',
    'POST',
    '/debts',
    {
      client_number: ownerB,
      amount: 5000,
      type: 'debt',
      notes: 'Test lookup officiel'
    },
    ownerA  // ← Jean
  );

  // Test 3: Je liste mes dettes (vérifier lookup du créancier)
  await test(
    'Test 3: Je liste mes dettes (vérifier lookup de Jean)',
    'GET',
    '/debts',
    null,
    ownerB  // ← Moi
  );

  // Test 4: Vérifier que le client créé par Jean a mon nom officiel
  await test(
    'Test 4: Jean liste ses clients (voir mon nom)',
    'GET',
    '/clients',
    null,
    ownerA  // ← Jean
  );

  // Test 5: Je crée un client avec le numéro de Jean
  await test(
    'Test 5: Je crée un client avec le numéro de Jean',
    'POST',
    '/clients',
    {
      client_number: ownerA,
      name: 'Fournisseur'
    },
    ownerB  // ← Moi
  );

  // Test 6: Créer une emprunt (je dois à Jean)
  await test(
    'Test 6: Je crée un emprunt à Jean',
    'POST',
    '/debts/loans',
    {
      client_number: ownerA,
      amount: 3000,
      notes: 'Emprunt test'
    },
    ownerB  // ← Moi
  );

  // Test 7: Je liste mes emprunts
  await test(
    'Test 7: Je liste mes emprunts (vérifier nom de Jean)',
    'GET',
    '/debts/owner/loans',
    null,
    ownerB  // ← Moi
  );

  console.log('\n✨ Tests complétés!\n');
  console.log('📊 Résultats Attendus:\n');
  console.log('Test 1: Jean crée "Mon Client" (mon numéro)');
  console.log('        → Devrait créer un client, status 201');
  console.log('');
  console.log('Test 2: Jean crée une dette avec mon numéro');
  console.log('        → client_id: client créé en Test 1');
  console.log('');
  console.log('Test 3: Je vois la dette reçue');
  console.log('        → creditor_name: "Boutique Jean" ou "Jean Dupont" ✨');
  console.log('        → type: "loan" (emprunt, inversé)');
  console.log('');
  console.log('Test 4: Jean liste ses clients');
  console.log('        → Doit voir "Mon Client" ou "Ma Boutique" (lookup! ✨)');
  console.log('');
  console.log('Test 5: Je crée un client avec le numéro de Jean');
  console.log('        → Devrait créer "Boutique Jean" (lookup! ✨)');
  console.log('        → Pas "Fournisseur"');
  console.log('');
  console.log('Test 6: Je crée un emprunt');
  console.log('        → client_name: "Boutique Jean" (lookup! ✨)');
  console.log('');
  console.log('Test 7: Je liste mes emprunts');
  console.log('        → display_client_name: "Boutique Jean" ✨');
  console.log('');
  console.log('═'.repeat(60));
  console.log('✨ KEY: Vérifier que les noms OFFICIELS sont utilisés!');
  console.log('═'.repeat(60) + '\n');
}

runTests().catch(console.error);
