
const express = require('express');
const cors = require('cors');
const app = express();
const port = 8080;

app.use(cors());
app.use(express.json());

// Dummy user data (replace with database in production)
let users = [];

// Register route
app.post('/register', (req, res) => {
  const { phone, email } = req.body;
  const newUser = { id: users.length + 1, phone, email, balance: 100 };
  users.push(newUser);
  res.status(201).json({ message: 'User registered successfully', user: newUser });
});

// Login route
app.post('/login', (req, res) => {
  const { phone } = req.body;
  const user = users.find(u => u.phone === phone);
  if (user) {
    res.json({ message: 'Login successful', user });
  } else {
    res.status(401).json({ message: 'Invalid credentials' });
  }
});

// Get user balance
app.get('/balance/:userId', (req, res) => {
  const user = users.find(u => u.id === parseInt(req.params.userId));
  if (user) {
    res.json({ balance: user.balance });
  } else {
    res.status(404).json({ message: 'User not found' });
  }
});

app.listen(port, () => {
  console.log(`Server running on port ${port}`);
});
