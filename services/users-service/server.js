const express = require('express');
const app = express();
app.use(express.json());
const PORT = process.env.PORT || 4001;

// In-memory demo data (resets on container restart - fine for a demo)
let users = [
  { id: 1, name: "Asha Verma",  email: "asha@example.com" },
  { id: 2, name: "Rohit Singh", email: "rohit@example.com" },
  { id: 3, name: "Meera Iyer",  email: "meera@example.com" }
];
let nextId = 4;

app.get('/health', (req, res) => res.status(200).json({ status: "ok", service: "users-service" }));

// ---- CRUD ----
app.get('/users', (req, res) => {
  console.log(`[users-service] GET /users -> ${users.length} users`);
  res.json(users);
});

app.get('/users/:id', (req, res) => {
  const user = users.find(u => u.id === parseInt(req.params.id));
  if (!user) return res.status(404).json({ error: "not found" });
  res.json(user);
});

app.post('/users', (req, res) => {
  const { name, email } = req.body || {};
  if (!name || !email) return res.status(400).json({ error: "name and email are required" });
  const user = { id: nextId++, name, email };
  users.push(user);
  console.log(`[users-service] POST /users -> created #${user.id}`);
  res.status(201).json(user);
});

app.put('/users/:id', (req, res) => {
  const user = users.find(u => u.id === parseInt(req.params.id));
  if (!user) return res.status(404).json({ error: "not found" });
  const { name, email } = req.body || {};
  if (name) user.name = name;
  if (email) user.email = email;
  console.log(`[users-service] PUT /users/${user.id} -> updated`);
  res.json(user);
});

app.delete('/users/:id', (req, res) => {
  const id = parseInt(req.params.id);
  const before = users.length;
  users = users.filter(u => u.id !== id);
  if (users.length === before) return res.status(404).json({ error: "not found" });
  console.log(`[users-service] DELETE /users/${id} -> deleted`);
  res.status(204).send();
});

app.listen(PORT, () => console.log(`[users-service] listening on ${PORT}`));
