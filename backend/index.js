require('dotenv').config();
const express = require('express');
const app = express();
const cors = require('cors');
const debtsRouter = require('./routes/debts');
const clientsRouter = require('./routes/clients');
const authRouter = require('./routes/auth');
const teamRouter = require('./routes/team');
const pool = require('./db');
const fs = require('fs');
const path = require('path');

const port = process.env.PORT || 3000;

app.use(cors());
app.use(express.json());

app.use('/api/debts', debtsRouter);
app.use('/api/clients', clientsRouter);
app.use('/api/auth', authRouter);
app.use('/api/team', teamRouter);

// Endpoint for getting all additions by owner_phone (for Hive sync)
app.get('/api/debt-additions', async (req, res) => {
  const ownerPhone = req.query.owner_phone;
  if (!ownerPhone) {
    return res.status(400).json({ error: 'owner_phone required' });
  }
  
  try {
    // Get all debts for this owner
    const debtsRes = await pool.query(
      'SELECT id FROM debts WHERE creditor=$1',
      [ownerPhone]
    );

    if (debtsRes.rowCount === 0) {
      return res.json([]);
    }

    const debtIds = debtsRes.rows.map(d => d.id);
    
    // Get all additions for all these debts
    const additionsRes = await pool.query(
      `SELECT * FROM debt_additions 
       WHERE debt_id = ANY($1)
       ORDER BY added_at DESC`,
      [debtIds]
    );

    res.json(additionsRes.rows);
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'DB error' });
  }
});

// Endpoint for getting all payments by owner_phone (for Hive sync)
app.get('/api/payments', async (req, res) => {
  const ownerPhone = req.query.owner_phone;
  if (!ownerPhone) {
    return res.status(400).json({ error: 'owner_phone required' });
  }
  
  try {
    // Get all debts for this owner
    const debtsRes = await pool.query(
      'SELECT id FROM debts WHERE creditor=$1',
      [ownerPhone]
    );

    if (debtsRes.rowCount === 0) {
      return res.json([]);
    }

    const debtIds = debtsRes.rows.map(d => d.id);
    
    // Get all payments for all these debts
    const paymentsRes = await pool.query(
      `SELECT * FROM payments 
       WHERE debt_id = ANY($1)
       ORDER BY paid_at DESC`,
      [debtIds]
    );

    res.json(paymentsRes.rows);
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'DB error' });
  }
});

// Run migrations file (safe to run multiple times)
try {
	const mig = fs.readFileSync(path.join(__dirname, 'migrate.sql'), 'utf8');
	pool.query(mig).then(() => console.log('Migrations applied')).catch((err) => console.error('Migration error:', err));
} catch (e) {
	console.error('Could not run migrations:', e);
}

app.get('/', (req, res) => res.send('Boutique backend is running'));

app.listen(port, () => console.log(`Server running on port ${port}`));
