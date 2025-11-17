const express = require('express');
const router = express.Router();
const pool = require('../db');

function getOwnerPhone(req) {
  return req.header('x-owner') || process.env.BOUTIQUE_OWNER || null;
}

// List members of the shop
router.get('/members', async (req, res) => {
  const owner = getOwnerPhone(req);
  if (!owner) return res.status(400).json({ error: 'Missing owner header' });
  try {
    const q = `SELECT u.id, u.phone, u.name, su.role, su.added_at FROM shop_users su JOIN users u ON u.id = su.user_id WHERE su.owner_phone = $1 ORDER BY su.added_at DESC`;
    const { rows } = await pool.query(q, [owner]);
    return res.json(rows);
  } catch (err) {
    console.error(err);
    return res.status(500).json({ error: 'DB error' });
  }
});

// Invite/add a member to the shop
router.post('/invite', async (req, res) => {
  const owner = getOwnerPhone(req);
  if (!owner) return res.status(400).json({ error: 'Missing owner header' });
  const { phone, name, role } = req.body;
  if (!phone) return res.status(400).json({ error: 'phone required' });
  try {
    // create user if not exists
    const exist = await pool.query('SELECT id FROM users WHERE phone = $1', [phone]);
    let userId;
    if (exist.rows.length > 0) {
      userId = exist.rows[0].id;
      // optionally update name
      if (name) await pool.query('UPDATE users SET name = $1 WHERE id = $2', [name, userId]);
    } else {
      const ins = await pool.query('INSERT INTO users(phone, name) VALUES($1,$2) RETURNING id, phone, name', [phone, name || null]);
      userId = ins.rows[0].id;
    }

    // add to shop_users
    await pool.query(`INSERT INTO shop_users(owner_phone, user_id, role) VALUES($1,$2,$3) ON CONFLICT (owner_phone, user_id) DO UPDATE SET role = EXCLUDED.role`, [owner, userId, role || 'clerk']);

    // log activity
    await pool.query('INSERT INTO activity_log(owner_phone, user_id, action, details) VALUES($1,$2,$3,$4)', [owner, userId, 'invite_member', JSON.stringify({ phone, role })]);

    const member = await pool.query('SELECT u.id, u.phone, u.name, su.role, su.added_at FROM shop_users su JOIN users u ON u.id = su.user_id WHERE su.owner_phone = $1 AND u.id = $2', [owner, userId]);
    return res.status(201).json(member.rows[0]);
  } catch (err) {
    console.error(err);
    return res.status(500).json({ error: 'DB error' });
  }
});

// Update member role
router.put('/members/:id', async (req, res) => {
  const owner = getOwnerPhone(req);
  const userId = parseInt(req.params.id);
  const { role } = req.body;
  if (!owner) return res.status(400).json({ error: 'Missing owner header' });
  try {
    await pool.query('UPDATE shop_users SET role = $1 WHERE owner_phone = $2 AND user_id = $3', [role, owner, userId]);
    await pool.query('INSERT INTO activity_log(owner_phone, user_id, action, details) VALUES($1,$2,$3,$4)', [owner, userId, 'update_role', JSON.stringify({ role })]);
    return res.json({ ok: true });
  } catch (err) {
    console.error(err);
    return res.status(500).json({ error: 'DB error' });
  }
});

// Remove member from shop
router.delete('/members/:id', async (req, res) => {
  const owner = getOwnerPhone(req);
  const userId = parseInt(req.params.id);
  if (!owner) return res.status(400).json({ error: 'Missing owner header' });
  try {
    await pool.query('DELETE FROM shop_users WHERE owner_phone = $1 AND user_id = $2', [owner, userId]);
    await pool.query('INSERT INTO activity_log(owner_phone, user_id, action, details) VALUES($1,$2,$3,$4)', [owner, userId, 'remove_member', JSON.stringify({})]);
    return res.json({ ok: true });
  } catch (err) {
    console.error(err);
    return res.status(500).json({ error: 'DB error' });
  }
});

// Get activity log for shop
router.get('/activity', async (req, res) => {
  const owner = getOwnerPhone(req);
  if (!owner) return res.status(400).json({ error: 'Missing owner header' });
  try {
    const q = 'SELECT id, user_id, action, details, created_at FROM activity_log WHERE owner_phone = $1 ORDER BY created_at DESC LIMIT 200';
    const { rows } = await pool.query(q, [owner]);
    return res.json(rows);
  } catch (err) {
    console.error(err);
    return res.status(500).json({ error: 'DB error' });
  }
});

// Append arbitrary activity (optional)
router.post('/activity', async (req, res) => {
  const owner = getOwnerPhone(req);
  const { user_id, action, details } = req.body;
  if (!owner) return res.status(400).json({ error: 'Missing owner header' });
  if (!action) return res.status(400).json({ error: 'action required' });
  try {
    const ins = await pool.query('INSERT INTO activity_log(owner_phone, user_id, action, details) VALUES($1,$2,$3,$4) RETURNING id, created_at', [owner, user_id || null, action, details ? JSON.stringify(details) : null]);
    return res.status(201).json(ins.rows[0]);
  } catch (err) {
    console.error(err);
    return res.status(500).json({ error: 'DB error' });
  }
});

module.exports = router;
