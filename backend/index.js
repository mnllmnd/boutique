require('dotenv').config();
const express = require('express');
const app = express();
const cors = require('cors');
const debtsRouter = require('./routes/debts');

const port = process.env.PORT || 3000;

app.use(cors());
app.use(express.json());

app.use('/api/debts', debtsRouter);

app.get('/', (req, res) => res.send('Boutique backend is running'));

app.listen(port, () => console.log(`Server running on port ${port}`));
