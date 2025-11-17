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

// Run migrations file (safe to run multiple times)
try {
	const mig = fs.readFileSync(path.join(__dirname, 'migrate.sql'), 'utf8');
	pool.query(mig).then(() => console.log('Migrations applied')).catch((err) => console.error('Migration error:', err));
} catch (e) {
	console.error('Could not run migrations:', e);
}

app.get('/', (req, res) => res.send('Boutique backend is running'));

app.listen(port, () => console.log(`Server running on port ${port}`));
