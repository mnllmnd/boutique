const express = require('express');
const router = express.Router();
const pool = require('../db');

// The server will act on behalf of the boutique owner when creating debts.
// Set `BOUTIQUE_OWNER` in your environment to the owner identifier (e.g. owner username or id).
const BOUTIQUE_OWNER = process.env.BOUTIQUE_OWNER || 'owner';

// List all debts
router.get('/', async (req, res) => {
  try {
    const owner = req.headers['x-owner'] || req.headers['X-Owner'] || process.env.BOUTIQUE_OWNER || 'owner';
    const debtsRes = await pool.query('SELECT * FROM debts WHERE creditor=$1 ORDER BY id DESC', [owner]);
    const debts = [];
    for (const d of debtsRes.rows) {
      const sumRes = await pool.query('SELECT COALESCE(SUM(amount),0) as total_paid FROM payments WHERE debt_id=$1', [d.id]);
      const totalPaid = parseFloat(sumRes.rows[0].total_paid || 0);
      debts.push({ ...d, total_paid: totalPaid, remaining: parseFloat(d.amount) - totalPaid });
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
    res.json(result.rows[0]);
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'DB error' });
  }
});

// Create a debt (associate with a client)
// The API does not require the client to provide `creditor`/`debtor`.
router.post('/', async (req, res) => {
  const { client_id, amount, due_date, notes, audio_path } = req.body;
  try {
    // Determine creditor: prefer header 'x-owner' (set by client after login), otherwise use env BOUTIQUE_OWNER
    const creditorHeader = req.headers['x-owner'] || req.headers['X-Owner'];
    const creditor = creditorHeader || BOUTIQUE_OWNER;
    const debtor = '';
    const result = await pool.query(
      'INSERT INTO debts (client_id, creditor, debtor, amount, due_date, notes, audio_path) VALUES ($1, $2, $3, $4, $5, $6, $7) RETURNING *',
      [client_id, creditor, debtor, amount, due_date, notes, audio_path]
    );
    // log activity
    try {
      await pool.query('INSERT INTO activity_log(owner_phone, action, details) VALUES($1,$2,$3)', [creditor, 'create_debt', JSON.stringify({ debt_id: result.rows[0].id, client_id, amount })]);
    } catch (e) { console.error('Activity log error:', e); }
    res.status(201).json(result.rows[0]);
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
    
    res.json(result.rows[0]);
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

    const paidAt = paid_at || new Date();
    const insert = await pool.query('INSERT INTO payments (debt_id, amount, paid_at, notes) VALUES ($1, $2, $3, $4) RETURNING *', [id, amount, paidAt, notes]);

    // log payment activity
    try {
      await pool.query('INSERT INTO activity_log(owner_phone, action, details) VALUES($1,$2,$3)', [owner, 'payment', JSON.stringify({ payment_id: insert.rows[0].id, debt_id: id, amount })]);
    } catch (e) { console.error('Activity log error:', e); }

    // compute total paid
    const sumRes = await pool.query('SELECT COALESCE(SUM(amount),0) as total_paid FROM payments WHERE debt_id=$1', [id]);
    const totalPaid = parseFloat(sumRes.rows[0].total_paid || 0);

    // get original debt amount
    const origRes = await pool.query('SELECT amount FROM debts WHERE id=$1', [id]);
    if (origRes.rowCount === 0) return res.status(404).json({ error: 'Debt not found' });
    const origAmount = parseFloat(origRes.rows[0].amount || 0);

    const paidFlag = totalPaid >= origAmount;
    const paidAtUpdate = paidFlag ? new Date() : null;
    await pool.query('UPDATE debts SET paid = $1, paid_at = COALESCE($2, paid_at) WHERE id=$3', [paidFlag, paidAtUpdate, id]);

    res.status(201).json({ payment: insert.rows[0], total_paid: totalPaid, remaining: (origAmount - totalPaid) });
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
      const sumRes = await pool.query('SELECT COALESCE(SUM(amount),0) as total_paid FROM payments WHERE debt_id=$1', [d.id]);
      const totalPaid = parseFloat(sumRes.rows[0].total_paid || 0);
      debts.push({ ...d, total_paid: totalPaid, remaining: parseFloat(d.amount) - totalPaid });
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
    const owedToRes = await pool.query(
      "SELECT COALESCE(SUM(amount),0) AS owed_to_user FROM debts WHERE creditor=$1 AND (paid IS FALSE OR paid IS NULL)",
      [user]
    );
    const owesRes = await pool.query(
      "SELECT COALESCE(SUM(amount),0) AS owes_user FROM debts WHERE debtor=$1 AND (paid IS FALSE OR paid IS NULL)",
      [user]
    );
    res.json({ owed_to_user: owedToRes.rows[0].owed_to_user, owes_user: owesRes.rows[0].owes_user });
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

    // log addition activity
    try {
      await pool.query('INSERT INTO activity_log(owner_phone, action, details) VALUES($1,$2,$3)', [owner, 'debt_addition', JSON.stringify({ addition_id: insert.rows[0].id, debt_id: id, amount })]);
    } catch (e) { console.error('Activity log error:', e); }

    res.status(201).json({ addition: insert.rows[0], new_debt_amount: newTotalAmount });
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

    // log deletion activity
    try {
      await pool.query('INSERT INTO activity_log(owner_phone, action, details) VALUES($1,$2,$3)', [owner, 'delete_addition', JSON.stringify({ addition_id: additionId, debt_id: id, amount: additionAmount })]);
    } catch (e) { console.error('Activity log error:', e); }

    res.json({ success: true, new_debt_amount: Math.max(newTotalAmount, 0) });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'DB error' });
  }
});

module.exports = router;
