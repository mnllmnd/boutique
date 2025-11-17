const express = require('express');
const router = express.Router();
const pool = require('../db');

// List all debts
router.get('/', async (req, res) => {
  try {
    const result = await pool.query('SELECT * FROM debts ORDER BY id DESC');
    res.json(result.rows);
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'DB error' });
  }
});

// Get single debt by id
router.get('/:id', async (req, res) => {
  const { id } = req.params;
  try {
    const result = await pool.query('SELECT * FROM debts WHERE id = $1', [id]);
    if (result.rowCount === 0) return res.status(404).json({ error: 'Not found' });
    res.json(result.rows[0]);
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'DB error' });
  }
});

// Create a debt
router.post('/', async (req, res) => {
  const { creditor, debtor, amount, due_date, notes } = req.body;
  try {
    const result = await pool.query(
      'INSERT INTO debts (creditor, debtor, amount, due_date, notes) VALUES ($1, $2, $3, $4, $5) RETURNING *',
      [creditor, debtor, amount, due_date, notes]
    );
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
    const result = await pool.query('DELETE FROM debts WHERE id=$1 RETURNING *', [id]);
    if (result.rowCount === 0) return res.status(404).json({ error: 'Not found' });
    res.json({ success: true });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'DB error' });
  }
});

// Mark a debt as paid
router.post('/:id/pay', async (req, res) => {
  const { id } = req.params;
  try {
    const result = await pool.query('UPDATE debts SET paid = TRUE, paid_at = NOW() WHERE id=$1 RETURNING *', [id]);
    if (result.rowCount === 0) return res.status(404).json({ error: 'Not found' });
    res.json(result.rows[0]);
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
