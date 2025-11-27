const express = require('express');
const router = express.Router();
const pool = require('../db');

// GET: Lister tous les pays avec leurs indicatifs
router.get('/', async (req, res) => {
  try {
    const result = await pool.query(
      'SELECT id, code, country_name, flag_emoji FROM countries ORDER BY country_name ASC'
    );
    res.json(result.rows);
  } catch (err) {
    console.error('Error fetching countries:', err);
    res.status(500).json({ error: 'DB error' });
  }
});

// GET: Récupérer un pays spécifique par code
router.get('/:code', async (req, res) => {
  try {
    const { code } = req.params;
    const result = await pool.query(
      'SELECT id, code, country_name, flag_emoji FROM countries WHERE code = $1',
      [code]
    );
    
    if (result.rowCount === 0) {
      return res.status(404).json({ error: 'Country not found' });
    }
    
    res.json(result.rows[0]);
  } catch (err) {
    console.error('Error fetching country:', err);
    res.status(500).json({ error: 'DB error' });
  }
});

module.exports = router;
