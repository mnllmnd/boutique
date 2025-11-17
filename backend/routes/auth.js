const express = require('express');
const router = express.Router();
const pool = require('../db');

// Register owner
router.post('/register', async (req, res) => {
  const { phone, password, shop_name } = req.body;
  if (!phone || !password) return res.status(400).json({ error: 'phone and password required' });
  try {
    const result = await pool.query('INSERT INTO owners (phone, password, shop_name) VALUES ($1, $2, $3) RETURNING id, phone, shop_name', [phone, password, shop_name]);
    res.status(201).json(result.rows[0]);
  } catch (err) {
    console.error(err);
    if (err.code === '23505') return res.status(409).json({ error: 'Owner already exists' });
    res.status(500).json({ error: 'DB error' });
  }
});

// Login owner
router.post('/login', async (req, res) => {
  const { phone, password } = req.body;
  if (!phone || !password) return res.status(400).json({ error: 'phone and password required' });
  try {
    const result = await pool.query('SELECT id, phone, password, shop_name FROM owners WHERE phone=$1', [phone]);
    if (result.rowCount === 0) return res.status(401).json({ error: 'Invalid credentials' });
    const owner = result.rows[0];
    if (owner.password !== password) return res.status(401).json({ error: 'Invalid credentials' });
    // For now we return owner info. In a production app return a JWT.
    res.json({ id: owner.id, phone: owner.phone, shop_name: owner.shop_name });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'DB error' });
  }
});

module.exports = router;
