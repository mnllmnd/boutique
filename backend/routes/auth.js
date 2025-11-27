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

// Quick register - only requires phone number, creates account instantly
// User can complete profile later in settings (name, lastname, PIN optional)
router.post('/register-quick', async (req, res) => {
  const { phone, device_id } = req.body;
  
  if (!phone) {
    return res.status(400).json({ error: 'phone required' });
  }
  
  try {
    // Check if phone already exists
    const existingPhone = await pool.query('SELECT id FROM owners WHERE phone=$1', [phone]);
    if (existingPhone.rowCount > 0) {
      return res.status(409).json({ error: 'Phone number already registered' });
    }
    
    // Generate token for instant access
    const authToken = generateToken();
    const tokenExpiresAt = new Date(Date.now() + TOKEN_EXPIRY_DAYS * 24 * 60 * 60 * 1000);
    
    // Create account with ONLY phone - name, PIN will be optional
    const result = await pool.query(
      'INSERT INTO owners (phone, first_name, last_name, auth_token, token_expires_at, token_created_at, device_id, last_login_at, pin) VALUES ($1, $2, $3, $4, $5, NOW(), $6, NOW(), $7) RETURNING id, phone, shop_name, first_name, last_name, auth_token, boutique_mode_enabled',
      [
        phone,
        '', // Empty first_name
        '', // Empty last_name
        authToken,
        tokenExpiresAt,
        device_id || generateDeviceId(),
        null  // No PIN initially
      ]
    );
    
    console.log('Quick registration successful for phone:', phone);
    res.status(201).json(result.rows[0]);
  } catch (err) {
    console.error(err);
    if (err.code === '23505') return res.status(409).json({ error: 'Phone number already registered' });
    res.status(500).json({ error: 'DB error' });
  }
});

// Login by phone only - for users who have an existing account (with or without PIN)
// If user has no PIN, grant immediate access
// If user has PIN, return a flag indicating PIN is required
router.post('/login-phone', async (req, res) => {
  const { phone, device_id } = req.body;
  
  if (!phone) {
    return res.status(400).json({ error: 'phone required' });
  }
  
  try {
    // Check if owner exists with this phone
    const result = await pool.query(
      'SELECT id, phone, first_name, last_name, shop_name, pin, auth_token, boutique_mode_enabled FROM owners WHERE phone=$1',
      [phone]
    );
    
    if (result.rowCount === 0) {
      return res.status(404).json({ error: 'User not found' });
    }
    
    const owner = result.rows[0];
    
    // If owner has NO PIN set, grant immediate access
    if (owner.pin === null || owner.pin === '') {
      // Generate new token
      const authToken = generateToken();
      const tokenExpiresAt = new Date(Date.now() + TOKEN_EXPIRY_DAYS * 24 * 60 * 60 * 1000);
      
      // Update with new token
      const updateResult = await pool.query(
        'UPDATE owners SET auth_token=$1, token_expires_at=$2, token_created_at=NOW(), device_id=$3, last_login_at=NOW() WHERE id=$4 RETURNING id, phone, shop_name, first_name, last_name, auth_token, boutique_mode_enabled',
        [authToken, tokenExpiresAt, device_id || generateDeviceId(), owner.id]
      );
      
      console.log('Direct login successful for phone (no PIN):', phone);
      return res.json(updateResult.rows[0]);
    }
    
    // If owner HAS a PIN, return flag indicating PIN is required
    // Generate temporary token that's valid only for PIN verification
    const tempToken = generateToken();
    
    // Save temp token temporarily so it can be used in PIN verification
    await pool.query(
      'UPDATE owners SET temp_token=$1 WHERE id=$2',
      [tempToken, owner.id]
    );
    
    console.log('PIN verification required for phone:', phone);
    res.json({
      id: owner.id,
      phone: owner.phone,
      first_name: owner.first_name,
      last_name: owner.last_name,
      shop_name: owner.shop_name,
      temp_token: tempToken,
      pin_required: true,
      boutique_mode_enabled: owner.boutique_mode_enabled,
      message: 'Veuillez entrer votre PIN pour accéder à votre compte'
    });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'DB error' });
  }
});

// Register owner with PIN (replaces password-based registration)
router.post('/register-pin', async (req, res) => {
  const { phone, country_code, pin, first_name, last_name, shop_name, device_id } = req.body;
  
  if (!phone || !pin || !country_code) {
    return res.status(400).json({ error: 'phone, country_code and pin required' });
  }
  
  if (pin.length !== 4 || !/^\d+$/.test(pin)) {
    return res.status(400).json({ error: 'PIN must be exactly 4 digits' });
  }
  
  try {
    // ✅ NOUVEAU : Formater le numéro en +PAYS+NUMERO
    const normalizedPhone = phone.replace(/[^0-9]/g, '');
    const fullPhone = `+${country_code}${normalizedPhone}`;
    
    // Check if phone or PIN already exists
    const existingPhone = await pool.query('SELECT id FROM owners WHERE phone=$1', [fullPhone]);
    if (existingPhone.rowCount > 0) {
      return res.status(409).json({ error: 'Phone number already registered' });
    }
    
    // Hash PIN for security
    const hashedPin = await bcrypt.hash(pin, SALT_ROUNDS);
    
    // Generate token
    const authToken = generateToken();
    const tokenExpiresAt = new Date(Date.now() + TOKEN_EXPIRY_DAYS * 24 * 60 * 60 * 1000);
    
    const result = await pool.query(
      'INSERT INTO owners (phone, country_code, pin, shop_name, first_name, last_name, auth_token, token_expires_at, token_created_at, device_id, last_login_at) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, NOW(), $9, NOW()) RETURNING id, phone, shop_name, first_name, last_name, auth_token, boutique_mode_enabled',
      [fullPhone, country_code, hashedPin, shop_name || null, first_name || '', last_name || '', authToken, tokenExpiresAt, device_id || generateDeviceId()]
    );
    
    res.status(201).json(result.rows[0]);
  } catch (err) {
    console.error(err);
    if (err.code === '23505') return res.status(409).json({ error: 'Phone number already registered' });
    res.status(500).json({ error: 'DB error' });
  }
});

// Register owner and generate token (legacy - kept for backward compatibility)
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
      'INSERT INTO owners (phone, password, shop_name, first_name, last_name, security_question, security_answer_hash, auth_token, token_expires_at, token_created_at, device_id, last_login_at) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, NOW(), $10, NOW()) RETURNING id, phone, shop_name, first_name, last_name, auth_token, boutique_mode_enabled',
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
    const result = await pool.query('SELECT id, phone, password, shop_name, first_name, last_name, boutique_mode_enabled FROM owners WHERE phone=$1', [phone]);
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
      'UPDATE owners SET auth_token=$1, token_expires_at=$2, token_created_at=NOW(), device_id=$3, last_login_at=NOW() WHERE id=$4 RETURNING id, phone, shop_name, first_name, last_name, auth_token, boutique_mode_enabled',
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
      'SELECT id, phone, shop_name, first_name, last_name, auth_token, token_expires_at, boutique_mode_enabled FROM owners WHERE auth_token=$1',
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
      auth_token: owner.auth_token,
      boutique_mode_enabled: owner.boutique_mode_enabled
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
  
  // Try to get auth from bearer token if x-owner is not provided
  let authPhone = ownerPhone;
  if (!authPhone) {
    const authHeader = req.headers.authorization;
    if (authHeader && authHeader.startsWith('Bearer ')) {
      const token = authHeader.substring(7);
      try {
        const tokenResult = await pool.query('SELECT phone FROM owners WHERE auth_token=$1', [token]);
        if (tokenResult.rowCount > 0) {
          authPhone = tokenResult.rows[0].phone;
        }
      } catch (err) {
        console.error('Error verifying bearer token:', err);
      }
    }
  }
  
  if (!authPhone) return res.status(401).json({ error: 'Not authenticated' });
  
  try {
    const newPhone = phone || authPhone; // Use provided phone or keep existing
    const result = await pool.query(
      'UPDATE owners SET phone=$1, first_name=$2, last_name=$3, shop_name=$4, updated_at=NOW() WHERE phone=$5 RETURNING id, phone, shop_name, first_name, last_name',
      [newPhone, first_name || '', last_name || '', shop_name || null, authPhone]
    );
    
    if (result.rowCount === 0) return res.status(404).json({ error: 'Owner not found' });
    res.json(result.rows[0]);
  } catch (err) {
    console.error('Error in profile patch:', err);
    if (err.code === '23505') return res.status(409).json({ error: 'Phone number already in use' });
    res.status(500).json({ error: 'DB error', details: err.message });
  }
});

// Complete profile - user filled signup quickly with just phone, now completes with name/lastname/PIN
// Called from Settings > "Complete Profile"
router.patch('/complete-profile', async (req, res) => {
  const { auth_token, first_name, last_name, pin, shop_name } = req.body;
  
  if (!auth_token) {
    return res.status(401).json({ error: 'auth_token required' });
  }
  
  try {
    // Verify token and get owner
    const ownerResult = await pool.query(
      'SELECT id, phone FROM owners WHERE auth_token=$1',
      [auth_token]
    );
    
    if (ownerResult.rowCount === 0) {
      return res.status(401).json({ error: 'Invalid token' });
    }
    
    const owner = ownerResult.rows[0];
    
    // Prepare update object
    let hashedPin = undefined;
    
    // If PIN provided, hash it
    if (pin && pin.length === 4 && /^\d+$/.test(pin)) {
      hashedPin = await bcrypt.hash(pin, SALT_ROUNDS);
    } else if (pin && pin.length > 0) {
      return res.status(400).json({ error: 'PIN must be exactly 4 digits' });
    }
    
    // Build update query
    let updateQuery;
    let params;
    
    if (hashedPin) {
      updateQuery = 'UPDATE owners SET first_name=$1, last_name=$2, pin=$3, shop_name=$4, updated_at=NOW() WHERE id=$5 RETURNING id, phone, shop_name, first_name, last_name, auth_token, boutique_mode_enabled';
      params = [first_name || '', last_name || '', hashedPin, shop_name || null, owner.id];
    } else {
      updateQuery = 'UPDATE owners SET first_name=$1, last_name=$2, shop_name=$3, updated_at=NOW() WHERE id=$4 RETURNING id, phone, shop_name, first_name, last_name, auth_token, boutique_mode_enabled';
      params = [first_name || '', last_name || '', shop_name || null, owner.id];
    }
    
    const result = await pool.query(updateQuery, params);
    
    if (result.rowCount === 0) {
      console.error('Failed to update owner:', owner.id);
      return res.status(404).json({ error: 'Owner not found' });
    }
    
    console.log('Profile completed for phone:', owner.phone);
    res.json(result.rows[0]);
  } catch (err) {
    console.error('Error in complete-profile:', err);
    res.status(500).json({ error: 'DB error', details: err.message });
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

// Update boutique mode setting
router.post('/update-boutique-mode', async (req, res) => {
  const { auth_token, boutique_mode_enabled } = req.body;
  
  if (!auth_token || boutique_mode_enabled === undefined) {
    return res.status(400).json({ error: 'auth_token and boutique_mode_enabled required' });
  }
  
  try {
    // Verify token first
    const ownerResult = await pool.query('SELECT id FROM owners WHERE auth_token=$1', [auth_token]);
    if (ownerResult.rowCount === 0) return res.status(401).json({ error: 'Invalid token' });
    
    const ownerId = ownerResult.rows[0].id;
    
    // Update boutique mode
    const updateResult = await pool.query(
      'UPDATE owners SET boutique_mode_enabled=$1, updated_at=NOW() WHERE id=$2 RETURNING id, phone, shop_name, first_name, last_name, auth_token, boutique_mode_enabled',
      [boutique_mode_enabled, ownerId]
    );
    
    res.json(updateResult.rows[0]);
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'DB error' });
  }
});

// PIN-based login (simple 4-digit PIN)
router.post('/login-pin', async (req, res) => {
  const { pin } = req.body;
  const authHeader = req.headers.authorization;
  
  console.log('Login attempt - PIN:', pin ? '****' : 'missing', 'Auth header:', authHeader ? 'present' : 'missing');
  
  if (!pin) {
    return res.status(400).json({ error: 'pin required' });
  }
  
  if (!pin || pin.length !== 4 || !/^\d+$/.test(pin)) {
    return res.status(400).json({ error: 'PIN must be exactly 4 digits' });
  }
  
  try {
    let owner = null;
    
    // If Bearer token provided, use it to identify the user
    if (authHeader && authHeader.startsWith('Bearer ')) {
      const token = authHeader.substring(7);
      console.log('Token found, searching for user with this temp token...');
      const result = await pool.query(
        'SELECT id, phone, pin, shop_name, first_name, last_name, boutique_mode_enabled FROM owners WHERE temp_token=$1',
        [token]
      );
      
      console.log('Token search result:', result.rowCount, 'row(s) found');
      
      if (result.rowCount === 0) {
        return res.status(401).json({ error: 'Invalid token' });
      }
      
      owner = result.rows[0];
    } else {
      // No token provided - error
      console.log('No authorization header provided');
      return res.status(401).json({ error: 'Device token required - please sign up first' });
    }
    
    // Verify PIN against this owner's PIN
    const pinMatch = await bcrypt.compare(pin, owner.pin);
    console.log('PIN match result:', pinMatch);
    
    if (!pinMatch) {
      return res.status(401).json({ error: 'Invalid PIN' });
    }
    
    // Generate new token
    const authToken = generateToken();
    const tokenExpiresAt = new Date(Date.now() + TOKEN_EXPIRY_DAYS * 24 * 60 * 60 * 1000);
    
    // Update with new token and clear temp_token
    const updateResult = await pool.query(
      'UPDATE owners SET auth_token=$1, token_expires_at=$2, token_created_at=NOW(), last_login_at=NOW(), temp_token=NULL WHERE id=$3 RETURNING id, phone, shop_name, first_name, last_name, auth_token, boutique_mode_enabled',
      [authToken, tokenExpiresAt, owner.id]
    );
    
    console.log('Login successful for owner:', owner.phone);
    res.json(updateResult.rows[0]);
  } catch (err) {
    console.error('Login error:', err);
    res.status(500).json({ error: 'DB error' });
  }
});

// Set or update PIN for an owner
router.post('/set-pin', async (req, res) => {
  const { auth_token, pin } = req.body;
  
  if (!auth_token || !pin) {
    return res.status(400).json({ error: 'auth_token and pin required' });
  }
  
  if (pin.length !== 4 || !/^\d+$/.test(pin)) {
    return res.status(400).json({ error: 'PIN must be exactly 4 digits' });
  }
  
  try {
    // Verify token first
    const ownerResult = await pool.query('SELECT id FROM owners WHERE auth_token=$1', [auth_token]);
    if (ownerResult.rowCount === 0) return res.status(401).json({ error: 'Invalid token' });
    
    const ownerId = ownerResult.rows[0].id;
    
    // Check if PIN already exists (for another owner)
    const pinCheck = await pool.query(
      'SELECT id FROM owners WHERE pin=$1 AND id != $2',
      [pin, ownerId]
    );
    
    if (pinCheck.rowCount > 0) {
      return res.status(409).json({ error: 'PIN already in use' });
    }
    
    // Hash PIN for security
    const hashedPin = await bcrypt.hash(pin, SALT_ROUNDS);
    
    // Update PIN
    const updateResult = await pool.query(
      'UPDATE owners SET pin=$1, updated_at=NOW() WHERE id=$2 RETURNING id, phone, shop_name, first_name, last_name, pin',
      [hashedPin, ownerId]
    );
    
    res.json({ success: true, message: 'PIN set successfully', user: updateResult.rows[0] });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'DB error' });
  }
});

// Remove PIN from account (requires password)
router.post('/remove-pin', async (req, res) => {
  const { auth_token, password } = req.body;
  
  if (!auth_token || !password) {
    return res.status(400).json({ error: 'auth_token and password required' });
  }
  
  try {
    // Verify token
    const ownerResult = await pool.query(
      'SELECT id, password FROM owners WHERE auth_token=$1',
      [auth_token]
    );
    
    if (ownerResult.rowCount === 0) return res.status(401).json({ error: 'Invalid token' });
    
    const owner = ownerResult.rows[0];
    
    // Verify password
    const passwordMatch = await bcrypt.compare(password, owner.password);
    if (!passwordMatch) return res.status(401).json({ error: 'Invalid password' });
    
    // Remove PIN
    const updateResult = await pool.query(
      'UPDATE owners SET pin=NULL, updated_at=NOW() WHERE id=$1 RETURNING id, phone, shop_name',
      [owner.id]
    );
    
    res.json({ success: true, message: 'PIN removed successfully', user: updateResult.rows[0] });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'DB error' });
  }
});

module.exports = router;
