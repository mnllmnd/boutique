const express = require('express');
const router = express.Router();
const pool = require('../db');

// List clients
router.get('/', async (req, res) => {
  try {
    const owner = req.headers['x-owner'] || req.headers['X-Owner'] || process.env.BOUTIQUE_OWNER || 'owner';
    const result = await pool.query('SELECT * FROM clients WHERE owner_phone = $1 ORDER BY id DESC', [owner]);
    res.json(result.rows);
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'DB error' });
  }
});

// Create client
router.post('/', async (req, res) => {
  const { client_number, name, avatar_url } = req.body;
  const owner = req.headers['x-owner'] || req.headers['X-Owner'] || process.env.BOUTIQUE_OWNER || 'owner';
  try {
    const result = await pool.query(
      'INSERT INTO clients (client_number, name, avatar_url, owner_phone) VALUES ($1, $2, $3, $4) RETURNING *',
      [client_number, name, avatar_url, owner]
    );
    // log activity
    try {
      await pool.query('INSERT INTO activity_log(owner_phone, action, details) VALUES($1,$2,$3)', [owner, 'create_client', JSON.stringify({ client_id: result.rows[0].id, name: result.rows[0].name })]);
    } catch (e) { console.error('Activity log error:', e); }
    res.status(201).json(result.rows[0]);
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'DB error' });
  }
});

// Get client
router.get('/:id', async (req, res) => {
  try {
    const owner = req.headers['x-owner'] || req.headers['X-Owner'] || process.env.BOUTIQUE_OWNER || 'owner';
    const result = await pool.query('SELECT * FROM clients WHERE id=$1 AND owner_phone = $2', [req.params.id, owner]);
    if (result.rowCount === 0) return res.status(404).json({ error: 'Not found' });
    res.json(result.rows[0]);
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'DB error' });
  }
});

module.exports = router;
