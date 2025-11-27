const express = require('express');
const router = express.Router();
const pool = require('../db');

// The server will act on behalf of the boutique owner when creating debts.
// Set `BOUTIQUE_OWNER` in your environment to the owner identifier (e.g. owner username or id).
const BOUTIQUE_OWNER = process.env.BOUTIQUE_OWNER || 'owner';

// Fonction helper pour récupérer le nom du créancier
// Priorité: shop_name > first_name + last_name > phone
async function getCreditorName(creditorPhone) {
  try {
    const res = await pool.query(
      'SELECT shop_name, first_name, last_name FROM owners WHERE phone = $1',
      [creditorPhone]
    );
    
    if (res.rowCount === 0) return creditorPhone; // Fallback au phone si owner pas trouvé
    
    const owner = res.rows[0];
    
    // ✅ Priorité 1: shop_name
    if (owner.shop_name && owner.shop_name.trim()) {
      return owner.shop_name;
    }
    
    // ✅ Priorité 2: first_name + last_name
    const firstName = owner.first_name?.trim() || '';
    const lastName = owner.last_name?.trim() || '';
    if (firstName || lastName) {
      return `${firstName} ${lastName}`.trim();
    }
    
    // ✅ Fallback: phone
    return creditorPhone;
  } catch (err) {
    console.error('Error getting creditor name:', err);
    return creditorPhone; // Fallback en cas d'erreur
  }
}

// ✅ NOUVELLE FONCTION : Chercher le nom LOCAL du créancier dans MES contacts
async function getLocalCreditorName(creditorPhone, ownerPhone) {
  try {
    if (!creditorPhone || !ownerPhone) return null;
    
    // Normaliser le numéro pour la recherche (toujours)
    const normalizedNumber = creditorPhone.replace(/[^0-9]/g, '');
    
    const res = await pool.query(
      `SELECT name FROM clients 
       WHERE owner_phone = $1 
       AND normalized_phone = $2
       LIMIT 1`,
      [ownerPhone, normalizedNumber]
    );
    
    if (res.rowCount > 0) {
      console.log(`[DEBT DISPLAY] Local creditor name found: ${res.rows[0].name} for ${creditorPhone}`);
      return res.rows[0].name;
    }
    
    return null;
  } catch (err) {
    console.error('Error getting local creditor name:', err);
    return null;
  }
}

// ✅ NOUVELLE FONCTION : Matching automatique - Chercher le nom officiel dans owners
async function getOfficialOwnerName(creditorPhone) {
  try {
    if (!creditorPhone) return null;
    
    // Normaliser le numéro pour la recherche
    const normalizedNumber = creditorPhone.replace(/[^0-9]/g, '');
    
    const res = await pool.query(
      'SELECT shop_name, first_name, last_name FROM owners WHERE phone = $1 OR regexp_replace(phone, \'[^0-9]\', \'\', \'g\') = $2',
      [creditorPhone, normalizedNumber]
    );
    
    if (res.rowCount === 0) return null;
    
    const owner = res.rows[0];
    
    // Priorité 1: shop_name
    if (owner.shop_name && owner.shop_name.trim()) {
      return owner.shop_name;
    }
    
    // Priorité 2: first_name + last_name
    const firstName = owner.first_name?.trim() || '';
    const lastName = owner.last_name?.trim() || '';
    if (firstName || lastName) {
      return `${firstName} ${lastName}`.trim();
    }
    
    // Fallback: retourner null (on utilisera le numéro)
    return null;
  } catch (err) {
    console.error('Error getting official owner name:', err);
    return null;
  }
}

// ✅ NOUVELLE FONCTION : Matching automatique - Trouver ou créer un client par numéro
async function findOrCreateClientByNumber(clientNumber, clientName, ownerPhone, creditorPhone = null) {
  try {
    if (!clientNumber) {
      console.warn('findOrCreateClientByNumber: clientNumber is missing');
      return null;
    }
    
    // Normaliser le numéro (supprimer les espaces, tirets, etc.)
    const normalizedNumber = clientNumber.replace(/[^0-9]/g, '');
    
    // 1. Chercher un client EXISTANT dans mes contacts avec ce numéro
    const existingRes = await pool.query(
      `SELECT id, name FROM clients 
       WHERE owner_phone = $1 
       AND (client_number = $2 OR normalized_phone = $3)
       LIMIT 1`,
      [ownerPhone, clientNumber, normalizedNumber]
    );
    
    if (existingRes.rowCount > 0) {
      // ✅ Client trouvé dans mes contacts! Retourner son ID
      const existing = existingRes.rows[0];
      console.log(`[MATCHING] Client ${clientNumber} trouvé dans mes contacts (ID: ${existing.id}, Nom: ${existing.name})`);
      return {
        id: existing.id,
        name: existing.name,
        is_existing: true,
        source: 'my_contacts'
      };
    }
    
    // 2. Pas dans mes contacts → Chercher dans l'annuaire officiel (owners)
    let officialName = null;
    if (creditorPhone) {
      officialName = await getOfficialOwnerName(creditorPhone);
    }
    
    // 3. Créer un nouveau client avec le nom officiel (si trouvé) ou le nom fourni
    const nameToUse = officialName || clientName || clientNumber;
    
    const newClientRes = await pool.query(
      'INSERT INTO clients (client_number, name, owner_phone) VALUES ($1, $2, $3) RETURNING id, name',
      [clientNumber, nameToUse, ownerPhone]
    );
    
    const newClient = newClientRes.rows[0];
    const sourceInfo = officialName ? ' (nom officiel de ' + creditorPhone + ')' : '';
    console.log(`[MATCHING] Nouveau client créé${sourceInfo} (ID: ${newClient.id}, Numéro: ${clientNumber}, Nom: ${newClient.name})`);
    
    return {
      id: newClient.id,
      name: newClient.name,
      is_existing: false,
      source: officialName ? 'official_registry' : 'manual',
      official_name: officialName
    };
    
  } catch (err) {
    console.error('Error in findOrCreateClientByNumber:', err);
    return null;
  }
}

// ✅ NOUVELLE FONCTION : Fusionner automatiquement les contacts par numéro
async function getMergedContactInfo(clientId, ownerPhone) {
  try {
    // Récupérer le contact de la dette
    const debtContactRes = await pool.query(
      'SELECT c.* FROM clients c WHERE c.id = $1',
      [clientId]
    );
    
    if (debtContactRes.rowCount === 0) return null;
    
    const debtContact = debtContactRes.rows[0];
    const clientNumber = debtContact.client_number;
    
    // Chercher si on a un contact local avec le même numéro
    const localContactRes = await pool.query(
      'SELECT id, name FROM clients WHERE client_number = $1 AND owner_phone = $2',
      [clientNumber, ownerPhone]
    );
    
    if (localContactRes.rowCount > 0) {
      // ✅ On a un contact local avec le même numéro → utiliser le nom local
      const localContact = localContactRes.rows[0];
      return {
        display_name: localContact.name,
        local_contact_id: localContact.id,
        debt_contact_name: debtContact.name,
        client_number: clientNumber
      };
    }
    
    // ✅ Pas de contact local → utiliser le nom de la dette
    return {
      display_name: debtContact.name,
      local_contact_id: null,
      debt_contact_name: debtContact.name,
      client_number: clientNumber
    };
    
  } catch (err) {
    console.error('Error in getMergedContactInfo:', err);
    return null;
  }
}

// Fonction helper pour calculer le solde correct
async function calculateDebtBalance(debtId) {
  const debtRes = await pool.query('SELECT amount FROM debts WHERE id=$1', [debtId]);
  if (debtRes.rowCount === 0) return null;
  
  const baseAmount = parseFloat(debtRes.rows[0].amount);
  
  const additionsRes = await pool.query('SELECT COALESCE(SUM(amount),0) as total FROM debt_additions WHERE debt_id=$1', [debtId]);
  const totalAdditions = parseFloat(additionsRes.rows[0].total);
  
  const paymentsRes = await pool.query('SELECT COALESCE(SUM(amount),0) as total FROM payments WHERE debt_id=$1', [debtId]);
  const totalPayments = parseFloat(paymentsRes.rows[0].total);
  
  return {
    base_amount: baseAmount,
    total_additions: totalAdditions,
    total_payments: totalPayments,
    total_debt: baseAmount + totalAdditions,
    remaining: Math.max((baseAmount + totalAdditions) - totalPayments, 0)
  };
}

// List all debts
router.get('/', async (req, res) => {
  try {
    const owner = req.headers['x-owner'] || req.headers['X-Owner'] || process.env.BOUTIQUE_OWNER || 'owner';
    
    // ✅ CORRIGÉ: Récupérer les dettes de DEUX façons:
    // 1. Les dettes où je suis le créancier (creditor) - mes prêts/emprunts que j'ai créés
    // 2. Les dettes où je suis le client (via clients.client_number) - les dettes créées par quelqu'un d'autre pour moi
    const debtsRes = await pool.query(
      `SELECT d.*, c.name as client_name, c.client_number FROM debts d
       LEFT JOIN clients c ON d.client_id = c.id
       WHERE d.creditor = $1 OR (c.client_number = $1 AND d.creditor != $1)
       ORDER BY d.id DESC`,
      [owner]
    );
    
    const debts = [];
    for (const d of debtsRes.rows) {
      const balance = await calculateDebtBalance(d.id);
      const isCreatedByMe = d.creditor === owner;
      
      // ✅ NOUVEAU: Inverser le type si la dette a été créée par quelqu'un d'autre
      let displayType = d.type;
      if (!isCreatedByMe) {
        displayType = d.type === 'debt' ? 'loan' : 'debt';
      }
      
      // ✅ NOUVELLE LOGIQUE: Fusion des contacts par numéro
      let displayCreditorName = d.creditor;  // ✅ Par défaut, afficher le numéro
      let displayClientName = d.client_name;
      let mergedContactInfo = null;
      
      // 🆕 Si la dette vient de quelqu'un d'autre (je dois de l'argent)
      if (!isCreatedByMe) {
        // ✅ SYSTÈME DE SMS: Afficher le nom que J'AI choisi pour le créancier dans MON carnet
        // Priorité 1: Nom local du créancier (si je l'ai enregistré)
        const localName = await getLocalCreditorName(d.creditor, owner);
        if (localName) {
          displayCreditorName = localName;
          console.log(`[DEBT DISPLAY] Using LOCAL creditor name (my choice): ${localName} for ${d.creditor}`);
        } else {
          // Priorité 2: Nom officiel du créancier (son vrai nom)
          const officialName = await getOfficialOwnerName(d.creditor);
          if (officialName) {
            displayCreditorName = officialName;
            console.log(`[DEBT DISPLAY] Using OFFICIAL creditor name: ${officialName} for ${d.creditor}`);
          }
        }
      }
      
      if (d.client_id) {
        mergedContactInfo = await getMergedContactInfo(d.client_id, owner);

        if (mergedContactInfo) {
          // ✅ Priorité au nom du contact local s'il existe
          displayClientName = mergedContactInfo.display_name;
        }
      }
      
      debts.push({ 
        ...d,
        type: displayType,
        original_type: d.type,
        total_paid: balance.total_payments,
        total_additions: balance.total_additions,
        total_debt: balance.total_debt,
        remaining: balance.remaining,
        created_by_me: isCreatedByMe,
        created_by_other: !isCreatedByMe,
        display_creditor_name: displayCreditorName,
        display_client_name: displayClientName,
        creditor_phone: d.creditor,
        merged_contact: mergedContactInfo // ✅ Info de fusion pour debug
      });
    }
    res.json(debts);
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'DB error' });
  }
});

// Get single debt by id
router.get('/:id', async (req, res) => {
  const { id } = req.params;
  try {
    const owner = req.headers['x-owner'] || req.headers['X-Owner'] || process.env.BOUTIQUE_OWNER || 'owner';
    
    // ✅ CORRIGÉ: L'utilisateur peut voir la dette s'il est:
    // 1. Le créancier (creditor) - celui qui l'a créée
    // 2. Le client (via clients.phone) - celui pour qui elle a été créée
    const result = await pool.query(
      `SELECT d.*, c.name as client_name, c.client_number FROM debts d
       LEFT JOIN clients c ON d.client_id = c.id
       WHERE d.id = $1 AND (d.creditor = $2 OR c.client_number = $2)`, 
      [id, owner]
    );
    
    if (result.rowCount === 0) return res.status(404).json({ error: 'Not found' });
    
    const debt = result.rows[0];
    const balance = await calculateDebtBalance(id);
    const isCreatedByMe = debt.creditor === owner;
    
    // ✅ NOUVEAU: Inverser le type si la dette a été créée par quelqu'un d'autre
    let displayType = debt.type;
    if (!isCreatedByMe) {
      displayType = debt.type === 'debt' ? 'loan' : 'debt';
    }
    
    // ✅ NOUVELLE LOGIQUE: Afficher le bon nom selon qui a créé la dette
    let displayCreditorName = debt.creditor;
    let displayClientName = debt.client_name;
    let mergedContactInfo = null;
    
    // Si créée par moi: afficher le nom du client normalement
    if (isCreatedByMe && debt.client_id) {
      mergedContactInfo = await getMergedContactInfo(debt.client_id, owner);
      if (mergedContactInfo) {
        displayClientName = mergedContactInfo.display_name;
      }
    } else if (!isCreatedByMe) {
      // ✅ SYSTÈME DE SMS: Afficher le nom que J'AI choisi pour le créancier dans MON carnet
      // Priorité 1: Nom local (si je l'ai enregistré dans mes contacts)
      const localName = await getLocalCreditorName(debt.creditor, owner);
      if (localName) {
        displayCreditorName = localName;
        console.log(`[DEBT GET /:id] Using LOCAL creditor name (my choice): ${localName} for ${debt.creditor}`);
      } else {
        // Priorité 2: Nom officiel (le vrai nom du créancier)
        const officialName = await getOfficialOwnerName(debt.creditor);
        if (officialName) {
          displayCreditorName = officialName;
          console.log(`[DEBT GET /:id] Using OFFICIAL creditor name: ${officialName} for ${debt.creditor}`);
        }
      }
    }
    
    res.json({ 
      ...debt,
      type: displayType,
      original_type: debt.type,
      total_paid: balance.total_payments,
      total_additions: balance.total_additions,
      total_debt: balance.total_debt,
      remaining: balance.remaining,
      created_by_me: isCreatedByMe,
      created_by_other: !isCreatedByMe,
      display_creditor_name: displayCreditorName,
      display_client_name: displayClientName,
      creditor_phone: debt.creditor,
      merged_contact: mergedContactInfo
    });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'DB error' });
  }
});

// ✅ NOUVELLE FONCTION : Créer un emprunt (je dois de l'argent à quelqu'un)
router.post('/loans', async (req, res) => {
  const { client_id, client_number, amount, due_date, notes, audio_path } = req.body;
  try {
    const creditorHeader = req.headers['x-owner'] || req.headers['X-Owner'];
    const creditor = creditorHeader || BOUTIQUE_OWNER;
    
    // ✅ NOUVEAU: Matching automatique par numéro de client (identique à POST /)
    let actualClientId = client_id;
    let matchingInfo = null;
    
    if (client_number) {
      const clientNumberForMatch = client_number;
      const normalizedNumber = clientNumberForMatch.replace(/[^0-9]/g, '');
      
      // Chercher par numéro exact OU normalisé
      const matchRes = await pool.query(
        `SELECT id, name, client_number FROM clients 
         WHERE owner_phone = $1 
         AND (client_number = $2 OR normalized_phone = $3)
         LIMIT 1`,
        [creditor, clientNumberForMatch, normalizedNumber]
      );
      
      if (matchRes.rowCount > 0) {
        actualClientId = matchRes.rows[0].id;
        matchingInfo = {
          matched: true,
          existed: true,
          matched_id: actualClientId,
          matched_client_number: matchRes.rows[0].client_number,
          message: `Matched to existing client: ${matchRes.rows[0].name}`
        };
        console.log(`[LOANS MATCHING] ${clientNumberForMatch} matched to existing client ID ${actualClientId} (stored as: ${matchRes.rows[0].client_number})`);
      } else {
        const newClientRes = await pool.query(
          'INSERT INTO clients (client_number, name, owner_phone) VALUES ($1, $2, $3) RETURNING id, name',
          [clientNumberForMatch, clientNumberForMatch, creditor]
        );
        actualClientId = newClientRes.rows[0].id;
        matchingInfo = {
          matched: true,
          existed: false,
          matched_id: actualClientId,
          message: `Created new client for number: ${clientNumberForMatch}`
        };
        console.log(`[LOANS MATCHING] New client created for ${clientNumberForMatch} with ID ${actualClientId}`);
      }
    } else if (client_id) {
      const clientRes = await pool.query(
        'SELECT client_number, normalized_phone, name FROM clients WHERE id = $1',
        [client_id]
      );
      
      if (clientRes.rowCount > 0) {
        const foundNumber = clientRes.rows[0].client_number;
        const normalizedFoundNumber = clientRes.rows[0].normalized_phone;
        
        if (foundNumber || normalizedFoundNumber) {
          // Chercher par numéro exact OU normalisé
          const matchRes = await pool.query(
            `SELECT id, name FROM clients 
             WHERE owner_phone = $1 
             AND id != $2
             AND (client_number = $3 OR normalized_phone = $4)
             LIMIT 1`,
            [creditor, client_id, foundNumber, normalizedFoundNumber]
          );
          
          if (matchRes.rowCount > 0) {
            actualClientId = matchRes.rows[0].id;
            matchingInfo = {
              matched: true,
              duplicate_found: true,
              original_id: client_id,
              matched_id: actualClientId,
              message: `Found duplicate client. Using: ${matchRes.rows[0].name}`
            };
            console.log(`[LOANS MATCHING] Duplicate client found! Using ID ${actualClientId} instead of ${client_id}`);
          }
        }
      }
    }
    
    if (!actualClientId) {
      return res.status(400).json({ error: 'client_id or client_number is required' });
    }
    
    // ✅ NOUVEAU: Récupérer le nom du créancier (shop_name > first_name+last_name > phone)
    const creditorName = await getCreditorName(creditor);
    
    // Pour les emprunts, le client_id représente la personne à qui je dois de l'argent
    const result = await pool.query(
      'INSERT INTO debts (client_id, creditor, creditor_name, amount, due_date, notes, audio_path, type, created_by) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9) RETURNING *',
      [actualClientId, creditor, creditorName, amount, due_date, notes, audio_path, 'loan', creditor]
    );
    
    // log activity
    try {
      await pool.query('INSERT INTO activity_log(owner_phone, action, details) VALUES($1,$2,$3)', 
        [creditor, 'create_loan', JSON.stringify({ debt_id: result.rows[0].id, client_id: actualClientId, amount, matching_info: matchingInfo })]);
    } catch (e) { console.error('Activity log error:', e); }
    
    res.status(201).json({
      type: 'loan',
      ...result.rows[0],
      created_by_me: true,
      matching: matchingInfo
    });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'DB error' });
  }
});

// ✅ NOUVELLE ROUTE : Lister les emprunts (dettes négatives)
router.get('/owner/loans', async (req, res) => {
  try {
    const owner = req.headers['x-owner'] || req.headers['X-Owner'] || process.env.BOUTIQUE_OWNER || 'owner';
    
    const loansRes = await pool.query(
      `SELECT d.*, c.name as client_name, c.client_number 
       FROM debts d 
       LEFT JOIN clients c ON d.client_id = c.id 
       WHERE d.creditor = $1 AND d.type = 'loan'
       ORDER BY d.id DESC`,
      [owner]
    );
    
    // Calculer les soldes pour chaque emprunt
    const loans = [];
    for (const loan of loansRes.rows) {
      const balance = await calculateDebtBalance(loan.id);
      
      // ✅ APPLIQUER LA FUSION DES CONTACTS
      let displayClientName = loan.client_name;
      const mergedContactInfo = await getMergedContactInfo(loan.client_id, owner);
      if (mergedContactInfo) {
        displayClientName = mergedContactInfo.display_name;
      }
      
      loans.push({
        ...loan,
        display_client_name: displayClientName,
        total_paid: balance.total_payments,
        total_additions: balance.total_additions,
        total_debt: balance.total_debt,
        remaining: balance.remaining
      });
    }
    
    res.json(loans);
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'DB error' });
  }
});

// ✅ MODIFIER la route de création de dette existante pour inclure le type
router.post('/', async (req, res) => {
  const { client_id, client_number, amount, due_date, notes, audio_path, type = 'debt' } = req.body;
  try {
    const creditorHeader = req.headers['x-owner'] || req.headers['X-Owner'];
    const creditor = creditorHeader || BOUTIQUE_OWNER;
    
    // ✅ NOUVEAU: Matching automatique par numéro de client
    let actualClientId = client_id;
    let matchingInfo = null;
    
    if (client_number) {
      // Si on reçoit un client_number, matcher d'abord
      const clientNumberForMatch = client_number;
      const normalizedNumber = clientNumberForMatch.replace(/[^0-9]/g, '');
      
      // Chercher par numéro exact OU normalisé
      const matchRes = await pool.query(
        `SELECT id, name, client_number FROM clients 
         WHERE owner_phone = $1 
         AND (client_number = $2 OR normalized_phone = $3)
         LIMIT 1`,
        [creditor, clientNumberForMatch, normalizedNumber]
      );
      
      if (matchRes.rowCount > 0) {
        actualClientId = matchRes.rows[0].id;
        matchingInfo = {
          matched: true,
          existed: true,
          matched_id: actualClientId,
          matched_client_number: matchRes.rows[0].client_number,
          message: `Matched to existing client: ${matchRes.rows[0].name}`
        };
        console.log(`[DEBTS MATCHING] ${clientNumberForMatch} matched to existing client ID ${actualClientId} (stored as: ${matchRes.rows[0].client_number})`);
      } else {
        // Créer un nouveau client avec ce numéro
        const newClientRes = await pool.query(
          'INSERT INTO clients (client_number, name, owner_phone) VALUES ($1, $2, $3) RETURNING id, name',
          [clientNumberForMatch, clientNumberForMatch, creditor]
        );
        actualClientId = newClientRes.rows[0].id;
        matchingInfo = {
          matched: true,
          existed: false,
          matched_id: actualClientId,
          message: `Created new client for number: ${clientNumberForMatch}`
        };
        console.log(`[DEBTS MATCHING] New client created for ${clientNumberForMatch} with ID ${actualClientId}`);
      }
    } else if (client_id) {
      // Si on a un client_id, chercher son numéro et matcher par lui
      const clientRes = await pool.query(
        'SELECT client_number, name FROM clients WHERE id = $1',
        [client_id]
      );
      
      if (clientRes.rowCount > 0) {
        const foundNumber = clientRes.rows[0].client_number;
        if (foundNumber) {
          // Chercher s'il existe un autre client avec ce même numéro
          const matchRes = await pool.query(
            'SELECT id, name FROM clients WHERE client_number = $1 AND owner_phone = $2 AND id != $3',
            [foundNumber, creditor, client_id]
          );
          
          if (matchRes.rowCount > 0) {
            // ✅ Doublon trouvé! Utiliser le premier (probablement l'existant)
            actualClientId = matchRes.rows[0].id;
            matchingInfo = {
              matched: true,
              duplicate_found: true,
              original_id: client_id,
              matched_id: actualClientId,
              message: `Found duplicate client. Using: ${matchRes.rows[0].name}`
            };
            console.log(`[DEBTS MATCHING] Duplicate client found! Using ID ${actualClientId} instead of ${client_id}`);
          }
        }
      }
    }
    
    if (!actualClientId) {
      return res.status(400).json({ error: 'client_id or client_number is required' });
    }
    
    const existingDebtRes = await pool.query(
      'SELECT id, amount FROM debts WHERE client_id=$1 AND creditor=$2 AND type=$3 AND paid=false LIMIT 1',
      [actualClientId, creditor, type]
    );
    
    if (existingDebtRes.rowCount > 0) {
      const existingDebt = existingDebtRes.rows[0];
      const addedAt = new Date();
      
      const operationType = type === 'loan' ? 'loan_addition' : 'addition';
      
      const insert = await pool.query(
        'INSERT INTO debt_additions (debt_id, amount, added_at, notes, operation_type, debt_type) VALUES ($1, $2, $3, $4, $5, $6) RETURNING *',
        [existingDebt.id, amount, addedAt, notes || 'Montant ajouté', operationType, type]
      );
      
      const balance = await calculateDebtBalance(existingDebt.id);
      await pool.query('UPDATE debts SET amount=$1 WHERE id=$2', [balance.remaining, existingDebt.id]);
      
      // log addition activity
      try {
        await pool.query('INSERT INTO activity_log(owner_phone, action, details) VALUES($1,$2,$3)', [creditor, type === 'loan' ? 'loan_addition' : 'debt_addition', JSON.stringify({ addition_id: insert.rows[0].id, debt_id: existingDebt.id, amount, matching_info: matchingInfo })]);
      } catch (e) { console.error('Activity log error:', e); }
      
      res.status(201).json({ 
        type: 'addition',
        addition: insert.rows[0], 
        new_debt_amount: balance.remaining,
        debt_id: existingDebt.id,
        total_debt: balance.total_debt,
        remaining: balance.remaining,
        matching: matchingInfo
      });
    } else {
      // ✅ Aucune dette existante : créer une nouvelle
      const creditorName = await getCreditorName(creditor);
      
      const result = await pool.query(
        'INSERT INTO debts (client_id, creditor, creditor_name, amount, due_date, notes, audio_path, type, created_by) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9) RETURNING *',
        [actualClientId, creditor, creditorName, amount, due_date, notes, audio_path, type, creditor]
      );
      
      // log activity
      try {
        await pool.query('INSERT INTO activity_log(owner_phone, action, details) VALUES($1,$2,$3)', 
          [creditor, type === 'loan' ? 'create_loan' : 'create_debt', 
           JSON.stringify({ debt_id: result.rows[0].id, client_id: actualClientId, amount, matching_info: matchingInfo })]);
      } catch (e) { console.error('Activity log error:', e); }
      
      res.status(201).json({
        type: type,
        ...result.rows[0],
        total_paid: 0,
        total_additions: 0,
        total_debt: parseFloat(amount),
        remaining: parseFloat(amount),
        created_by_me: true,
        matching: matchingInfo
      });
    }
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'DB error' });
  }
});

// Update a debt
router.put('/:id', async (req, res) => {
  const { id } = req.params;
  const { amount, due_date, notes, paid } = req.body;
  try {
    const owner = req.headers['x-owner'] || req.headers['X-Owner'] || process.env.BOUTIQUE_OWNER || 'owner';
    
    // Verify ownership: only allow updating own debts
    const checkRes = await pool.query('SELECT * FROM debts WHERE id=$1 AND creditor=$2', [id, owner]);
    if (checkRes.rowCount === 0) return res.status(404).json({ error: 'Not found' });
    
    if (amount !== undefined) {
      return res.status(400).json({ error: 'Cannot directly update amount. Use POST /:id/add or POST /:id/pay instead.' });
    }
    
    let updateFields = [];
    let params = [];
    let paramIndex = 1;
    
    if (due_date !== undefined) {
      updateFields.push(`due_date=$${paramIndex++}`);
      params.push(due_date);
    }
    if (notes !== undefined) {
      updateFields.push(`notes=$${paramIndex++}`);
      params.push(notes);
    }
    if (paid !== undefined) {
      updateFields.push(`paid=$${paramIndex++}`);
      params.push(paid);
    }
    
    if (updateFields.length === 0) return res.status(400).json({ error: 'No fields to update' });
    
    params.push(id);
    const query = `UPDATE debts SET ${updateFields.join(', ')} WHERE id=$${paramIndex} RETURNING *`;
    const result = await pool.query(query, params);
    
    const updatedDebt = result.rows[0];
    const balance = await calculateDebtBalance(id);
    
    res.json({ 
      ...updatedDebt,
      total_paid: balance.total_payments,
      total_additions: balance.total_additions,
      total_debt: balance.total_debt,
      remaining: balance.remaining
    });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'DB error' });
  }
});

// Delete a debt
router.delete('/:id', async (req, res) => {
  const { id } = req.params;
  try {
    const owner = req.headers['x-owner'] || req.headers['X-Owner'] || process.env.BOUTIQUE_OWNER || 'owner';
    const result = await pool.query('DELETE FROM debts WHERE id=$1 AND creditor=$2 RETURNING *', [id, owner]);
    if (result.rowCount === 0) return res.status(404).json({ error: 'Not found' });
    try {
      await pool.query('INSERT INTO activity_log(owner_phone, action, details) VALUES($1,$2,$3)', [owner, 'delete_debt', JSON.stringify({ debt_id: id })]);
    } catch (e) { console.error('Activity log error:', e); }
    res.json({ success: true });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'DB error' });
  }
});

// Record a payment for a debt (partial allowed). Body: { amount, paid_at (optional), notes }
router.post('/:id/pay', async (req, res) => {
  const { id } = req.params;
  const { amount, paid_at, notes } = req.body;
  try {
    const owner = req.headers['x-owner'] || req.headers['X-Owner'] || process.env.BOUTIQUE_OWNER || 'owner';
    // ensure debt belongs to owner - either creditor OR client (via client_number)
    const debtRes = await pool.query(
      `SELECT d.* FROM debts d
       LEFT JOIN clients c ON d.client_id = c.id
       WHERE d.id = $1 AND (d.creditor = $2 OR c.client_number = $2)`,
      [id, owner]
    );
    if (debtRes.rowCount === 0) return res.status(404).json({ error: 'Debt not found' });

    const balance = await calculateDebtBalance(id);
    const paymentAmount = parseFloat(amount);
    
    if (paymentAmount <= 0) {
      return res.status(400).json({ error: 'Montant invalide' });
    }
    
    if (paymentAmount > balance.remaining) {
      return res.status(400).json({ 
        error: 'Montant dépasse la dette restante',
        remaining: balance.remaining,
        attempted: paymentAmount
      });
    }

    const paidAt = paid_at || new Date();
    const debt = debtRes.rows[0];
    const debtType = debt.type || 'debt';
    
    const operationType = debtType === 'loan' ? 'loan_payment' : 'payment';
    
    const insert = await pool.query(
      'INSERT INTO payments (debt_id, amount, paid_at, notes, operation_type, debt_type) VALUES ($1, $2, $3, $4, $5, $6) RETURNING *',
      [id, paymentAmount, paidAt, notes, operationType, debtType]
    );

    const newBalance = await calculateDebtBalance(id);
    
    const paidFlag = newBalance.remaining <= 0.01;
    const paidAtUpdate = paidFlag ? new Date() : null;
    
    await pool.query('UPDATE debts SET paid = $1, paid_at = COALESCE($2, paid_at) WHERE id=$3', [paidFlag, paidAtUpdate, id]);

    // log payment activity
    try {
      await pool.query('INSERT INTO activity_log(owner_phone, action, details) VALUES($1,$2,$3)', [owner, debtType === 'loan' ? 'loan_payment' : 'payment', JSON.stringify({ payment_id: insert.rows[0].id, debt_id: id, amount: paymentAmount, operation_type: operationType })]);
    } catch (e) { console.error('Activity log error:', e); }

    res.status(201).json({ 
      payment: insert.rows[0], 
      total_paid: newBalance.total_payments,
      total_additions: newBalance.total_additions,
      total_debt: newBalance.total_debt,
      remaining: newBalance.remaining,
      paid: paidFlag
    });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'DB error' });
  }
});

// Get payments for a debt
router.get('/:id/payments', async (req, res) => {
  const { id } = req.params;
  try {
    const owner = req.headers['x-owner'] || req.headers['X-Owner'] || process.env.BOUTIQUE_OWNER || 'owner';
    // ensure debt belongs to owner - either creditor OR client (via client_number)
    const debtRes = await pool.query(
      `SELECT d.* FROM debts d
       LEFT JOIN clients c ON d.client_id = c.id
       WHERE d.id = $1 AND (d.creditor = $2 OR c.client_number = $2)`,
      [id, owner]
    );
    if (debtRes.rowCount === 0) return res.status(404).json({ error: 'Debt not found' });

    const result = await pool.query('SELECT * FROM payments WHERE debt_id=$1 ORDER BY paid_at DESC', [id]);
    res.json(result.rows);
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'DB error' });
  }
});

// Get debts for a client with remaining amount
router.get('/client/:clientId', async (req, res) => {
  const { clientId } = req.params;
  try {
    const owner = req.headers['x-owner'] || req.headers['X-Owner'] || process.env.BOUTIQUE_OWNER || 'owner';
    const debtsRes = await pool.query('SELECT * FROM debts WHERE client_id=$1 AND creditor=$2 ORDER BY id DESC', [clientId, owner]);
    const debts = [];
    for (const d of debtsRes.rows) {
      const balance = await calculateDebtBalance(d.id);
      debts.push({ 
        ...d, 
        total_paid: balance.total_payments,
        total_additions: balance.total_additions,
        total_debt: balance.total_debt,
        remaining: balance.remaining
      });
    }
    res.json(debts);
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'DB error' });
  }
});

// Get balance summary for a user (amount owed to user, and amount user owes)
router.get('/balances/:user', async (req, res) => {
  const { user } = req.params;
  try {
    const debtsRes = await pool.query(
      "SELECT id FROM debts WHERE creditor=$1",
      [user]
    );
    
    let totalOwed = 0;
    for (const debt of debtsRes.rows) {
      const balance = await calculateDebtBalance(debt.id);
      if (balance.remaining > 0) {
        totalOwed += balance.remaining;
      }
    }
    
    res.json({ 
      owed_to_user: totalOwed,
      owes_user: 0 
    });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'DB error' });
  }
});

// Add amount to an existing debt. Body: { amount, added_at (optional), notes }
router.post('/:id/add', async (req, res) => {
  const { id } = req.params;
  const { amount, added_at, notes } = req.body;
  try {
    const owner = req.headers['x-owner'] || req.headers['X-Owner'] || process.env.BOUTIQUE_OWNER || 'owner';
    
    // ✅ CORRIGÉ: Vérifier que l'utilisateur a le droit de modifier cette dette
    // Soit il l'a créée (creditor), soit elle a été créée pour lui (client)
    const debtRes = await pool.query(
      `SELECT d.creditor, d.amount, d.type, c.client_number FROM debts d
       LEFT JOIN clients c ON d.client_id = c.id
       WHERE d.id=$1`,
      [id]
    );
    
    if (debtRes.rowCount === 0) return res.status(404).json({ error: 'Debt not found' });
    
    const debt = debtRes.rows[0];
    const isCreatedByMe = debt.creditor === owner;
    const isClientOfDebt = debt.client_number && debt.client_number === owner;  // ✅ Vérifier que client_number existe
    
    console.log(`[ADD AMOUNT PERMISSION] debt=${id}, isCreatedByMe=${isCreatedByMe}, isClientOfDebt=${isClientOfDebt}, creditor=${debt.creditor}, client=${debt.client_number}, owner=${owner}`);
    
    // ✅ Vérifier les permissions: créateur OU client
    if (!isCreatedByMe && !isClientOfDebt) {
      console.log(`[PERMISSION] Denied: isCreatedByMe=${isCreatedByMe}, isClientOfDebt=${isClientOfDebt}, creditor=${debt.creditor}, client=${debt.client_number}, owner=${owner}`);
      return res.status(403).json({ error: 'Forbidden - vous ne pouvez pas modifier cette dette' });
    }

    const addedAtTime = added_at || new Date();
    const debtType = debt.type || 'debt';
    
    const operationType = debtType === 'loan' ? 'loan_addition' : 'addition';
    
    console.log(`[ADD AMOUNT] Adding ${amount} to debt ${id}, type=${debtType}, operationType=${operationType}`);
    
    const insert = await pool.query(
      'INSERT INTO debt_additions (debt_id, amount, added_at, notes, operation_type, debt_type) VALUES ($1, $2, $3, $4, $5, $6) RETURNING *',
      [id, amount, addedAtTime, notes, operationType, debtType]
    );
    
    console.log(`[ADD AMOUNT] Addition created: ${insert.rows[0].id}, amount=${insert.rows[0].amount}`);

    const balance = await calculateDebtBalance(id);
    
    // ✅ CORRIGÉ: Ne pas modifier amount, c'est utilisé pour le calcul!
    // On met juste original_amount si c'est la première fois
    await pool.query(
      'UPDATE debts SET original_amount = COALESCE(original_amount, $1) WHERE id=$2',
      [debt.amount, id]
    );

    const paidFlag = balance.remaining <= 0.01;
    await pool.query('UPDATE debts SET paid = $1, paid_at = $2 WHERE id=$3', [paidFlag, paidFlag ? new Date() : null, id]);

    // log addition activity
    try {
      await pool.query('INSERT INTO activity_log(owner_phone, action, details) VALUES($1,$2,$3)', [owner, debtType === 'loan' ? 'loan_addition' : 'debt_addition', JSON.stringify({ addition_id: insert.rows[0].id, debt_id: id, amount, operation_type: operationType })]);
    } catch (e) { console.error('Activity log error:', e); }

    res.status(201).json({ 
      addition: insert.rows[0], 
      new_debt_amount: balance.remaining,
      total_debt: balance.total_debt,
      remaining: balance.remaining
    });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'DB error' });
  }
});

// Get all additions for a debt
router.get('/:id/additions', async (req, res) => {
  const { id } = req.params;
  try {
    const owner = req.headers['x-owner'] || req.headers['X-Owner'] || process.env.BOUTIQUE_OWNER || 'owner';
    // ensure debt belongs to owner - either creditor OR client (via client_number)
    const debtRes = await pool.query(
      `SELECT d.* FROM debts d
       LEFT JOIN clients c ON d.client_id = c.id
       WHERE d.id = $1 AND (d.creditor = $2 OR c.client_number = $2)`,
      [id, owner]
    );
    if (debtRes.rowCount === 0) return res.status(404).json({ error: 'Debt not found' });

    const result = await pool.query('SELECT * FROM debt_additions WHERE debt_id=$1 ORDER BY added_at DESC', [id]);
    res.json(result.rows);
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'DB error' });
  }
});

// Delete an addition
router.delete('/:id/additions/:additionId', async (req, res) => {
  const { id, additionId } = req.params;
  try {
    const owner = req.headers['x-owner'] || req.headers['X-Owner'] || process.env.BOUTIQUE_OWNER || 'owner';
    // ensure debt belongs to owner
    const debtRes = await pool.query('SELECT creditor, amount FROM debts WHERE id=$1', [id]);
    if (debtRes.rowCount === 0) return res.status(404).json({ error: 'Debt not found' });
    if (debtRes.rows[0].creditor !== owner) return res.status(403).json({ error: 'Forbidden' });

    const addRes = await pool.query('SELECT amount FROM debt_additions WHERE id=$1 AND debt_id=$2', [additionId, id]);
    if (addRes.rowCount === 0) return res.status(404).json({ error: 'Addition not found' });
    const additionAmount = parseFloat(addRes.rows[0].amount);

    await pool.query('DELETE FROM debt_additions WHERE id=$1', [additionId]);

    const balance = await calculateDebtBalance(id);
    await pool.query('UPDATE debts SET amount=$1 WHERE id=$2', [balance.remaining, id]);

    const paidFlag = balance.remaining <= 0.01;
    await pool.query('UPDATE debts SET paid = $1, paid_at = $2 WHERE id=$3', [paidFlag, paidFlag ? new Date() : null, id]);

    // log deletion activity
    try {
      await pool.query('INSERT INTO activity_log(owner_phone, action, details) VALUES($1,$2,$3)', [owner, 'delete_addition', JSON.stringify({ addition_id: additionId, debt_id: id, amount: additionAmount })]);
    } catch (e) { console.error('Activity log error:', e); }

    res.json({ 
      success: true, 
      new_debt_amount: balance.remaining,
      total_debt: balance.total_debt,
      remaining: balance.remaining
    });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'DB error' });
  }
});

// ✅ NOUVEAU : Créer une contestation de dette
router.post('/:id/disputes', async (req, res) => {
  const { id } = req.params;
  const { reason, message } = req.body;
  try {
    const disputedBy = req.headers['x-owner'] || req.headers['X-Owner'] || process.env.BOUTIQUE_OWNER || 'owner';
    
    // Vérifier que la dette existe et que l'utilisateur est autorisé à y accéder
    const debtRes = await pool.query(
      `SELECT d.* FROM debts d
       LEFT JOIN clients c ON d.client_id = c.id
       WHERE d.id = $1 AND (d.creditor = $2 OR c.client_number = $2)`,
      [id, disputedBy]
    );
    if (debtRes.rowCount === 0) return res.status(404).json({ error: 'Debt not found' });
    
    const debt = debtRes.rows[0];
    
    // L'utilisateur qui conteste ne doit pas être le créancier
    if (debt.creditor === disputedBy) {
      return res.status(403).json({ error: 'Cannot dispute own debt' });
    }
    
    // Créer la contestation
    const result = await pool.query(
      `INSERT INTO debt_disputes (debt_id, disputed_by, reason, message, created_at) 
       VALUES ($1, $2, $3, $4, NOW()) 
       RETURNING *`,
      [id, disputedBy, reason, message]
    );
    
    // Mettre à jour le statut de la dette
    await pool.query(
      `UPDATE debts SET dispute_status='disputed' WHERE id=$1`,
      [id]
    );
    
    res.status(201).json({ 
      success: true, 
      dispute: result.rows[0]
    });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'DB error' });
  }
});

// ✅ NOUVEAU : Récupérer les contestations d'une dette
// ✅ CORRIGÉ : Récupérer les contestations d'une dette AVEC le nom du disputant
router.get('/:id/disputes', async (req, res) => {
  const { id } = req.params;
  try {
    const owner = req.headers['x-owner'] || req.headers['X-Owner'] || process.env.BOUTIQUE_OWNER || 'owner';
    
    // Vérifier que la dette existe et appartient à l'utilisateur
    const debtRes = await pool.query(
      `SELECT d.* FROM debts d
       LEFT JOIN clients c ON d.client_id = c.id
       WHERE d.id = $1 AND (d.creditor = $2 OR c.client_number = $2)`,
      [id, owner]
    );
    if (debtRes.rowCount === 0) return res.status(404).json({ error: 'Debt not found' });
    
    // ✅ CORRECTION: PRIORITÉ AU CONTACT LOCAL
    const result = await pool.query(
      `SELECT 
         dd.*,
         -- Priorité 1: Nom dans mes contacts (CE QUE JE VOULAIS!)
         c.name as contact_name,
         -- Priorité 2: Nom officiel du owner
         CASE 
           WHEN o.shop_name IS NOT NULL AND o.shop_name != '' THEN o.shop_name
           WHEN o.first_name IS NOT NULL OR o.last_name IS NOT NULL THEN 
             COALESCE(o.first_name || ' ', '') || COALESCE(o.last_name, '')
           ELSE NULL
         END as official_name,
         -- Nom final à afficher - CONTACT LOCAL EN PREMIER!
         COALESCE(
           c.name,  -- ← "mama" (nom que J'AI choisi)
           CASE 
             WHEN o.shop_name IS NOT NULL AND o.shop_name != '' THEN o.shop_name
             WHEN o.first_name IS NOT NULL OR o.last_name IS NOT NULL THEN 
               COALESCE(o.first_name || ' ', '') || COALESCE(o.last_name, '')
             ELSE NULL
           END,
           dd.disputed_by
         ) as disputed_by_display_name
       FROM debt_disputes dd
       LEFT JOIN owners o ON dd.disputed_by = o.phone
       LEFT JOIN clients c ON (dd.disputed_by = c.client_number AND c.owner_phone = $2)
       WHERE dd.debt_id = $1 
       ORDER BY dd.created_at DESC`,
      [id, owner]
    );
    
    res.json(result.rows);
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'DB error' });
  }
});

// ✅ NOUVEAU : Résoudre une contestation (réponse du créancier)
router.patch('/:id/disputes/:disputeId/resolve', async (req, res) => {
  const { id, disputeId } = req.params;
  const { resolution_note } = req.body;
  try {
    const owner = req.headers['x-owner'] || req.headers['X-Owner'] || process.env.BOUTIQUE_OWNER || 'owner';
    
    // Vérifier que la dette appartient au créancier
    const debtRes = await pool.query('SELECT creditor FROM debts WHERE id=$1', [id]);
    if (debtRes.rowCount === 0) return res.status(404).json({ error: 'Debt not found' });
    
    const debt = debtRes.rows[0];
    if (debt.creditor !== owner) {
      return res.status(403).json({ error: 'Only creditor can resolve disputes' });
    }
    
    // Mettre à jour la contestation
    const result = await pool.query(
      `UPDATE debt_disputes 
       SET resolved_at=NOW(), resolution_note=$1 
       WHERE id=$2 AND debt_id=$3 
       RETURNING *`,
      [resolution_note, disputeId, id]
    );
    
    if (result.rowCount === 0) {
      return res.status(404).json({ error: 'Dispute not found' });
    }
    
    // Vérifier s'il y a d'autres contestations non résolues
    const unresolvedRes = await pool.query(
      `SELECT COUNT(*) as count FROM debt_disputes WHERE debt_id=$1 AND resolved_at IS NULL`,
      [id]
    );
    
    const unresolvedCount = parseInt(unresolvedRes.rows[0].count);
    
    // Si toutes les contestations sont résolues, mettre à jour le statut
    if (unresolvedCount === 0) {
      await pool.query(
        `UPDATE debts SET dispute_status='resolved' WHERE id=$1`,
        [id]
      );
    }
    
    res.json({ 
      success: true, 
      dispute: result.rows[0]
    });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'DB error' });
  }
});

module.exports = router;