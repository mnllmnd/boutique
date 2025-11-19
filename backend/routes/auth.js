const express = require('express');
const router = express.Router();
const pool = require('../db');
const bcrypt = require('bcryptjs');
const crypto = require('crypto');

const SALT_ROUNDS = 10;
const TOKEN_EXPIRY_DAYS = 30; // Token expires after 30 days

// Generate unique token
function generateToken() {
  return crypto.randomBytes(32).toString('hex');
}

// Generate device ID fingerprint
function generateDeviceId() {
  // In production, you'd use device-specific info
  // For now, generate a simple ID
  return crypto.randomBytes(16).toString('hex');
}

// Register owner and generate token
router.post('/register', async (req, res) => {
  const { phone, password, shop_name, first_name, last_name, security_question, security_answer, device_id } = req.body;
  if (!phone || !password) return res.status(400).json({ error: 'phone and password required' });
  try {
    // Hash password
    const hashedPassword = await bcrypt.hash(password, SALT_ROUNDS);
    // Hash security answer
    const hashedAnswer = security_answer ? await bcrypt.hash(security_answer.toLowerCase().trim(), SALT_ROUNDS) : null;
    
    // Generate token
    const authToken = generateToken();
    const tokenExpiresAt = new Date(Date.now() + TOKEN_EXPIRY_DAYS * 24 * 60 * 60 * 1000);
    
    const result = await pool.query(
      'INSERT INTO owners (phone, password, shop_name, first_name, last_name, security_question, security_answer_hash, auth_token, token_expires_at, token_created_at, device_id, last_login_at) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, NOW(), $10, NOW()) RETURNING id, phone, shop_name, first_name, last_name, auth_token',
      [phone, hashedPassword, shop_name, first_name, last_name, security_question || null, hashedAnswer, authToken, tokenExpiresAt, device_id || generateDeviceId()]
    );
    res.status(201).json(result.rows[0]);
  } catch (err) {
    console.error(err);
    if (err.code === '23505') return res.status(409).json({ error: 'Owner already exists' });
    res.status(500).json({ error: 'DB error' });
  }
});

// Login owner and generate token
router.post('/login', async (req, res) => {
  const { phone, password, device_id } = req.body;
  if (!phone || !password) return res.status(400).json({ error: 'phone and password required' });
  try {
    const result = await pool.query('SELECT id, phone, password, shop_name, first_name, last_name FROM owners WHERE phone=$1', [phone]);
    if (result.rowCount === 0) return res.status(401).json({ error: 'Invalid credentials' });
    const owner = result.rows[0];
    
    // Compare password with hash
    const passwordMatch = await bcrypt.compare(password, owner.password);
    if (!passwordMatch) return res.status(401).json({ error: 'Invalid credentials' });
    
    // Generate token
    const authToken = generateToken();
    const tokenExpiresAt = new Date(Date.now() + TOKEN_EXPIRY_DAYS * 24 * 60 * 60 * 1000);
    
    // Update with new token
    const updateResult = await pool.query(
      'UPDATE owners SET auth_token=$1, token_expires_at=$2, token_created_at=NOW(), device_id=$3, last_login_at=NOW() WHERE id=$4 RETURNING id, phone, shop_name, first_name, last_name, auth_token',
      [authToken, tokenExpiresAt, device_id || generateDeviceId(), owner.id]
    );
    
    res.json(updateResult.rows[0]);
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'DB error' });
  }
});

// Verify token and auto-login
router.post('/verify-token', async (req, res) => {
  const { auth_token } = req.body;
  if (!auth_token) return res.status(400).json({ error: 'auth_token required' });
  
  try {
    const result = await pool.query(
      'SELECT id, phone, shop_name, first_name, last_name, auth_token, token_expires_at FROM owners WHERE auth_token=$1',
      [auth_token]
    );
    
    if (result.rowCount === 0) return res.status(401).json({ error: 'Invalid or expired token' });
    
    const owner = result.rows[0];
    
    // Check if token is expired
    if (new Date(owner.token_expires_at) < new Date()) {
      // Token expired, invalidate it
      await pool.query('UPDATE owners SET auth_token=NULL, token_expires_at=NULL WHERE id=$1', [owner.id]);
      return res.status(401).json({ error: 'Token expired' });
    }
    
    // Update last_login_at
    await pool.query('UPDATE owners SET last_login_at=NOW() WHERE id=$1', [owner.id]);
    
    // Return user info with token
    res.json({
      id: owner.id,
      phone: owner.phone,
      shop_name: owner.shop_name,
      first_name: owner.first_name,
      last_name: owner.last_name,
      auth_token: owner.auth_token
    });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'DB error' });
  }
});

// Logout and invalidate token
router.post('/logout', async (req, res) => {
  const { auth_token } = req.body;
  if (!auth_token) return res.status(400).json({ error: 'auth_token required' });
  
  try {
    await pool.query(
      'UPDATE owners SET auth_token=NULL, token_expires_at=NULL WHERE auth_token=$1',
      [auth_token]
    );
    res.json({ success: true, message: 'Logged out successfully' });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'DB error' });
  }
});

// Revoke all tokens for a user (change device/security)
router.post('/revoke-tokens', async (req, res) => {
  const { phone, password } = req.body;
  if (!phone || !password) return res.status(400).json({ error: 'phone and password required' });
  
  try {
    // Verify password first
    const result = await pool.query('SELECT id, password FROM owners WHERE phone=$1', [phone]);
    if (result.rowCount === 0) return res.status(401).json({ error: 'Invalid credentials' });
    
    const owner = result.rows[0];
    const passwordMatch = await bcrypt.compare(password, owner.password);
    if (!passwordMatch) return res.status(401).json({ error: 'Invalid credentials' });
    
    // Revoke all tokens
    await pool.query(
      'UPDATE owners SET auth_token=NULL, token_expires_at=NULL WHERE id=$1',
      [owner.id]
    );
    
    res.json({ success: true, message: 'All tokens revoked. Please login again.' });
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

// Get security question by phone (for password recovery)
router.get('/forgot-password/:phone', async (req, res) => {
  const { phone } = req.params;
  try {
    const result = await pool.query('SELECT security_question FROM owners WHERE phone=$1', [phone]);
    if (result.rowCount === 0) return res.status(404).json({ error: 'User not found' });
    
    const owner = result.rows[0];
    if (!owner.security_question) return res.status(400).json({ error: 'No security question set' });
    
    res.json({ security_question: owner.security_question });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'DB error' });
  }
});

// Verify security answer and reset password
router.post('/reset-password', async (req, res) => {
  const { phone, security_answer, new_password } = req.body;
  
  if (!phone || !security_answer || !new_password) {
    return res.status(400).json({ error: 'phone, security_answer, and new_password required' });
  }
  
  try {
    const result = await pool.query('SELECT security_answer_hash FROM owners WHERE phone=$1', [phone]);
    if (result.rowCount === 0) return res.status(404).json({ error: 'User not found' });
    
    const owner = result.rows[0];
    if (!owner.security_answer_hash) return res.status(400).json({ error: 'No security answer set' });
    
    // Compare security answer with hash
    const answerMatch = await bcrypt.compare(security_answer.toLowerCase().trim(), owner.security_answer_hash);
    if (!answerMatch) return res.status(401).json({ error: 'Incorrect answer' });
    
    // Hash new password and update
    const hashedPassword = await bcrypt.hash(new_password, SALT_ROUNDS);
    const updateResult = await pool.query(
      'UPDATE owners SET password=$1, updated_at=NOW() WHERE phone=$2 RETURNING id, phone, shop_name, first_name, last_name',
      [hashedPassword, phone]
    );
    
    res.json({ success: true, message: 'Password reset successfully', user: updateResult.rows[0] });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'DB error' });
  }
});

module.exports = router;
