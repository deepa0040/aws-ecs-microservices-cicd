const express = require('express');
const app = express();
app.use(express.json());
const PORT = process.env.PORT || 4002;

let products = [
  { id: 101, name: "Wireless Mouse", price: 799  },
  { id: 102, name: "Mechanical Keyboard", price: 3499 },
  { id: 103, name: "USB-C Hub", price: 1299 }
];
let nextId = 104;

app.get('/health', (req, res) => res.status(200).json({ status: "ok", service: "products-service" }));

// ---- CRUD ----
app.get('/products', (req, res) => {
  console.log(`[products-service] GET /products -> ${products.length} products`);
  res.json(products);
});

app.get('/products/:id', (req, res) => {
  const product = products.find(p => p.id === parseInt(req.params.id));
  if (!product) return res.status(404).json({ error: "not found" });
  res.json(product);
});

app.post('/products', (req, res) => {
  const { name, price } = req.body || {};
  if (!name || price === undefined) return res.status(400).json({ error: "name and price are required" });
  const product = { id: nextId++, name, price: Number(price) };
  products.push(product);
  console.log(`[products-service] POST /products -> created #${product.id}`);
  res.status(201).json(product);
});

app.put('/products/:id', (req, res) => {
  const product = products.find(p => p.id === parseInt(req.params.id));
  if (!product) return res.status(404).json({ error: "not found" });
  const { name, price } = req.body || {};
  if (name) product.name = name;
  if (price !== undefined) product.price = Number(price);
  console.log(`[products-service] PUT /products/${product.id} -> updated`);
  res.json(product);
});

app.delete('/products/:id', (req, res) => {
  const id = parseInt(req.params.id);
  const before = products.length;
  products = products.filter(p => p.id !== id);
  if (products.length === before) return res.status(404).json({ error: "not found" });
  console.log(`[products-service] DELETE /products/${id} -> deleted`);
  res.status(204).send();
});

app.listen(PORT, () => console.log(`[products-service] listening on ${PORT}`));
