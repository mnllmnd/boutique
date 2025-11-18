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
  const { creditor, debtor, amount, due_date, notes, paid } = req.body;
  try {
    const result = await pool.query(
      'UPDATE debts SET creditor=$1, debtor=$2, amount=$3, due_date=$4, notes=$5, paid=COALESCE($6, paid) WHERE id=$7 RETURNING *',
      [creditor, debtor, amount, due_date, notes, paid, id]
    );
    if (result.rowCount === 0) return res.status(404).json({ error: 'Not found' });
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

module.exports = router;
