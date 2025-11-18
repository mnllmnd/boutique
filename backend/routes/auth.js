const express = require('express');
const router = express.Router();
const pool = require('../db');

// Register owner
router.post('/register', async (req, res) => {
  const { phone, password, shop_name, first_name, last_name } = req.body;
  if (!phone || !password) return res.status(400).json({ error: 'phone and password required' });
  try {
    const result = await pool.query(
      'INSERT INTO owners (phone, password, shop_name, first_name, last_name) VALUES ($1, $2, $3, $4, $5) RETURNING id, phone, shop_name, first_name, last_name',
      [phone, password, shop_name, first_name, last_name]
    );
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
    const result = await pool.query('SELECT id, phone, password, shop_name, first_name, last_name FROM owners WHERE phone=$1', [phone]);
    if (result.rowCount === 0) return res.status(401).json({ error: 'Invalid credentials' });
    const owner = result.rows[0];
    if (owner.password !== password) return res.status(401).json({ error: 'Invalid credentials' });
    // For now we return owner info. In a production app return a JWT.
    res.json({ id: owner.id, phone: owner.phone, shop_name: owner.shop_name, first_name: owner.first_name, last_name: owner.last_name });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'DB error' });
  }
});

// Update owner profile
router.patch('/profile', async (req, res) => {
  const { phone, first_name, last_name, shop_name } = req.body;
  const ownerPhone = req.headers['x-owner'] || req.headers['X-Owner'];
  
  if (!ownerPhone) return res.status(401).json({ error: 'Not authenticated' });
  
  try {
    const newPhone = phone || ownerPhone; // Use provided phone or keep existing
    const result = await pool.query(
      'UPDATE owners SET phone=$1, first_name=$2, last_name=$3, shop_name=$4, updated_at=NOW() WHERE phone=$5 RETURNING id, phone, shop_name, first_name, last_name',
      [newPhone, first_name || '', last_name || '', shop_name || '', ownerPhone]
    );
    
    if (result.rowCount === 0) return res.status(404).json({ error: 'Owner not found' });
    res.json(result.rows[0]);
  } catch (err) {
    console.error(err);
    if (err.code === '23505') return res.status(409).json({ error: 'Phone number already in use' });
    res.status(500).json({ error: 'DB error' });
  }
});

module.exports = router;
