const express = require('express');
const router = express.Router();
const pool = require('../db');

// The server will act on behalf of the boutique owner when creating debts.
// Set `BOUTIQUE_OWNER` in your environment to the owner identifier (e.g. owner username or id).
const BOUTIQUE_OWNER = process.env.BOUTIQUE_OWNER || 'owner';

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
    const consolidated = req.query.consolidated || req.query.consolidate || req.query.c;
    // If caller requests consolidated balances per client+type, return aggregated results
    if (consolidated && (consolidated === '1' || consolidated === 'true' || consolidated === 'yes')) {
      try {
        const sql = `
          SELECT d.client_id, d.type,
                 COALESCE(SUM(d.amount::numeric),0) as total_base_amount,
                 COALESCE(SUM(coalesce(a.total_additions,0)),0) as total_additions,
                 COALESCE(SUM(coalesce(p.total_payments,0)),0) as total_payments,
                 (COALESCE(SUM(d.amount::numeric),0) + COALESCE(SUM(coalesce(a.total_additions,0)),0)) as total_debt,
                 ((COALESCE(SUM(d.amount::numeric),0) + COALESCE(SUM(coalesce(a.total_additions,0)),0)) - COALESCE(SUM(coalesce(p.total_payments,0)),0)) as remaining,
                 array_agg(d.id ORDER BY d.id DESC) as debt_ids,
                 MAX(d.id) as last_debt_id
          FROM debts d
          LEFT JOIN (
            SELECT debt_id, SUM(amount::numeric) as total_additions FROM debt_additions GROUP BY debt_id
          ) a ON a.debt_id = d.id
          LEFT JOIN (
            SELECT debt_id, SUM(amount::numeric) as total_payments FROM payments GROUP BY debt_id
          ) p ON p.debt_id = d.id
          WHERE d.creditor = $1
          GROUP BY d.client_id, d.type
          ORDER BY MAX(d.id) DESC
        `;

        const aggRes = await pool.query(sql, [owner]);
        const out = aggRes.rows.map(r => ({
          client_id: r.client_id,
          type: r.type,
          total_base_amount: parseFloat(r.total_base_amount),
          total_additions: parseFloat(r.total_additions),
          total_payments: parseFloat(r.total_payments),
          total_debt: parseFloat(r.total_debt),
          remaining: Math.max(parseFloat(r.remaining), 0),
          debt_ids: r.debt_ids,
          last_debt_id: r.last_debt_id
        }));
        return res.json(out);
      } catch (e) {
        console.error('Error consolidating debts:', e);
        return res.status(500).json({ error: 'DB error during consolidation' });
      }
    }
    // ✅ CORRIGÉ: Récupérer TOUS les débts/emprunts du propriétaire (creditor)
    // - Les PRÊTS ont type='debt' : j'ai prêté de l'argent à client_id
    // - Les EMPRUNTS ont type='loan' : j'ai emprunté de l'argent à client_id
    const debtsRes = await pool.query(
      `SELECT * FROM debts 
       WHERE creditor=$1
       ORDER BY id DESC`,
      [owner]
    );
    
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

// Get single debt by id
router.get('/:id', async (req, res) => {
  const { id } = req.params;
  try {
    const owner = req.headers['x-owner'] || req.headers['X-Owner'] || process.env.BOUTIQUE_OWNER || 'owner';
    const result = await pool.query('SELECT * FROM debts WHERE id = $1 AND creditor = $2', [id, owner]);
    if (result.rowCount === 0) return res.status(404).json({ error: 'Not found' });
    
    const debt = result.rows[0];
    const balance = await calculateDebtBalance(id);
    
    res.json({ 
      ...debt,
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

// ✅ NOUVELLE FONCTION : Créer un emprunt (je dois de l'argent à quelqu'un)
router.post('/loans', async (req, res) => {
  const { client_id, amount, due_date, notes, audio_path } = req.body;
  try {
    const creditorHeader = req.headers['x-owner'] || req.headers['X-Owner'];
    const creditor = creditorHeader || BOUTIQUE_OWNER;
    
    // Pour les emprunts, le client_id représente la personne à qui je dois de l'argent
    const result = await pool.query(
      'INSERT INTO debts (client_id, creditor, amount, due_date, notes, audio_path, type) VALUES ($1, $2, $3, $4, $5, $6, $7) RETURNING *',
      [client_id, creditor, amount, due_date, notes, audio_path, 'loan']
    );
    
    // log activity
    try {
      await pool.query('INSERT INTO activity_log(owner_phone, action, details) VALUES($1,$2,$3)', 
        [creditor, 'create_loan', JSON.stringify({ debt_id: result.rows[0].id, client_id, amount })]);
    } catch (e) { console.error('Activity log error:', e); }
    
    res.status(201).json({
      type: 'loan',
      ...result.rows[0]
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
      loans.push({
        ...loan,
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
  const { client_id, amount, due_date, notes, audio_path, type = 'debt' } = req.body; // ← Ajouter type
  try {
    const creditorHeader = req.headers['x-owner'] || req.headers['X-Owner'];
    const creditor = creditorHeader || BOUTIQUE_OWNER;
    
    const existingDebtRes = await pool.query(
      'SELECT id, amount FROM debts WHERE client_id=$1 AND creditor=$2 AND type=$3 AND paid=false LIMIT 1',
      [client_id, creditor, type] // ← Inclure le type
    );
    
    if (existingDebtRes.rowCount > 0) {
      // ✅ Une dette existe déjà : ajouter comme montant ajouté
      const existingDebt = existingDebtRes.rows[0];
      const addedAt = new Date();
      
      const insert = await pool.query(
        'INSERT INTO debt_additions (debt_id, amount, added_at, notes) VALUES ($1, $2, $3, $4) RETURNING *',
        [existingDebt.id, amount, addedAt, notes || 'Montant ajouté']
      );
      
      // Update the debt's total amount
      const newTotalAmount = parseFloat(existingDebt.amount) + parseFloat(amount);
      await pool.query('UPDATE debts SET amount=$1 WHERE id=$2', [newTotalAmount, existingDebt.id]);
      
      // log addition activity
      try {
        await pool.query('INSERT INTO activity_log(owner_phone, action, details) VALUES($1,$2,$3)', [creditor, type === 'loan' ? 'loan_addition' : 'debt_addition', JSON.stringify({ addition_id: insert.rows[0].id, debt_id: existingDebt.id, amount })]);
      } catch (e) { console.error('Activity log error:', e); }
      
      const balance = await calculateDebtBalance(existingDebt.id);
      
      res.status(201).json({ 
        type: 'addition',
        addition: insert.rows[0], 
        new_debt_amount: newTotalAmount,
        debt_id: existingDebt.id,
        total_debt: balance.total_debt,
        remaining: balance.remaining
      });
    } else {
      // ✅ Aucune dette existante : créer une nouvelle
      const result = await pool.query(
        'INSERT INTO debts (client_id, creditor, amount, due_date, notes, audio_path, type) VALUES ($1, $2, $3, $4, $5, $6, $7) RETURNING *',
        [client_id, creditor, amount, due_date, notes, audio_path, type] // ← Ajouter type
      );
      
      // log activity
      try {
        await pool.query('INSERT INTO activity_log(owner_phone, action, details) VALUES($1,$2,$3)', 
          [creditor, type === 'loan' ? 'create_loan' : 'create_debt', 
           JSON.stringify({ debt_id: result.rows[0].id, client_id, amount })]);
      } catch (e) { console.error('Activity log error:', e); }
      
      res.status(201).json({
        type: type,
        ...result.rows[0],
        total_paid: 0,
        total_additions: 0,
        total_debt: parseFloat(amount),
        remaining: parseFloat(amount)
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
    
    // Build update query dynamically (only update provided fields)
    let updateFields = [];
    let params = [];
    let paramIndex = 1;
    
    if (amount !== undefined) {
      updateFields.push(`amount=$${paramIndex++}`);
      params.push(amount);
    }
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
    // ensure debt belongs to owner
    const debtRes = await pool.query('SELECT creditor FROM debts WHERE id=$1', [id]);
    if (debtRes.rowCount === 0) return res.status(404).json({ error: 'Debt not found' });
    if (debtRes.rows[0].creditor !== owner) return res.status(403).json({ error: 'Forbidden' });

    // ✅ NOUVEAU : Vérifier que le montant ne dépasse pas la dette restante
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
    const insert = await pool.query('INSERT INTO payments (debt_id, amount, paid_at, notes) VALUES ($1, $2, $3, $4) RETURNING *', [id, paymentAmount, paidAt, notes]);

    // ✅ RECALCULER APRÈS INSERTION
    const newBalance = await calculateDebtBalance(id);
    
    const paidFlag = newBalance.remaining <= 0.01; // Tolérance pour arrondis
    const paidAtUpdate = paidFlag ? new Date() : null;
    
    await pool.query('UPDATE debts SET paid = $1, paid_at = COALESCE($2, paid_at) WHERE id=$3', [paidFlag, paidAtUpdate, id]);

    // log payment activity
    try {
      await pool.query('INSERT INTO activity_log(owner_phone, action, details) VALUES($1,$2,$3)', [owner, 'payment', JSON.stringify({ payment_id: insert.rows[0].id, debt_id: id, amount: paymentAmount })]);
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
    // ensure debt belongs to owner
    const debtRes = await pool.query('SELECT creditor FROM debts WHERE id=$1', [id]);
    if (debtRes.rowCount === 0) return res.status(404).json({ error: 'Debt not found' });
    if (debtRes.rows[0].creditor !== owner) return res.status(403).json({ error: 'Forbidden' });

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
    // Calcul correct en prenant en compte les additions et paiements
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
    // ensure debt belongs to owner
    const debtRes = await pool.query('SELECT creditor, amount FROM debts WHERE id=$1', [id]);
    if (debtRes.rowCount === 0) return res.status(404).json({ error: 'Debt not found' });
    if (debtRes.rows[0].creditor !== owner) return res.status(403).json({ error: 'Forbidden' });

    const addedAtTime = added_at || new Date();
    const insert = await pool.query(
      'INSERT INTO debt_additions (debt_id, amount, added_at, notes) VALUES ($1, $2, $3, $4) RETURNING *',
      [id, amount, addedAtTime, notes]
    );

    // Update the debt's total amount
    const newTotalAmount = parseFloat(debtRes.rows[0].amount) + parseFloat(amount);
    await pool.query('UPDATE debts SET amount=$1 WHERE id=$2', [newTotalAmount, id]);

    // Recalculate paid status
    const balance = await calculateDebtBalance(id);
    const paidFlag = balance.remaining <= 0.01;
    await pool.query('UPDATE debts SET paid = $1, paid_at = $2 WHERE id=$3', [paidFlag, paidFlag ? new Date() : null, id]);

    // log addition activity
    try {
      await pool.query('INSERT INTO activity_log(owner_phone, action, details) VALUES($1,$2,$3)', [owner, 'debt_addition', JSON.stringify({ addition_id: insert.rows[0].id, debt_id: id, amount })]);
    } catch (e) { console.error('Activity log error:', e); }

    res.status(201).json({ 
      addition: insert.rows[0], 
      new_debt_amount: newTotalAmount,
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
    // ensure debt belongs to owner
    const debtRes = await pool.query('SELECT creditor FROM debts WHERE id=$1', [id]);
    if (debtRes.rowCount === 0) return res.status(404).json({ error: 'Debt not found' });
    if (debtRes.rows[0].creditor !== owner) return res.status(403).json({ error: 'Forbidden' });

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

    // get the addition to know how much to subtract
    const addRes = await pool.query('SELECT amount FROM debt_additions WHERE id=$1 AND debt_id=$2', [additionId, id]);
    if (addRes.rowCount === 0) return res.status(404).json({ error: 'Addition not found' });
    const additionAmount = parseFloat(addRes.rows[0].amount);

    // delete the addition
    await pool.query('DELETE FROM debt_additions WHERE id=$1', [additionId]);

    // Update the debt's total amount (subtract the addition)
    const newTotalAmount = parseFloat(debtRes.rows[0].amount) - additionAmount;
    await pool.query('UPDATE debts SET amount=$1 WHERE id=$2', [Math.max(newTotalAmount, 0), id]);

    // Recalculate paid status
    const balance = await calculateDebtBalance(id);
    const paidFlag = balance.remaining <= 0.01;
    await pool.query('UPDATE debts SET paid = $1, paid_at = $2 WHERE id=$3', [paidFlag, paidFlag ? new Date() : null, id]);

    // log deletion activity
    try {
      await pool.query('INSERT INTO activity_log(owner_phone, action, details) VALUES($1,$2,$3)', [owner, 'delete_addition', JSON.stringify({ addition_id: additionId, debt_id: id, amount: additionAmount })]);
    } catch (e) { console.error('Activity log error:', e); }

    res.json({ 
      success: true, 
      new_debt_amount: Math.max(newTotalAmount, 0),
      total_debt: balance.total_debt,
      remaining: balance.remaining
    });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'DB error' });
  }
});

module.exports = router;