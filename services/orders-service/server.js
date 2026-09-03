const express = require('express');
const app = express();
app.use(express.json());
const PORT = process.env.PORT || 4003;

// Service discovery via env vars (Service Connect DNS on ECS, K8s Service DNS on EKS)
const USERS_SERVICE_URL = process.env.USERS_SERVICE_URL || 'http://users-service:4001';
const PRODUCTS_SERVICE_URL = process.env.PRODUCTS_SERVICE_URL || 'http://products-service:4002';

// orders-service only stores the *link* (who ordered what) in-memory.
// The actual user/product details are always fetched live from the other
// two services, so any CRUD change made there (edit a name, delete a
// product, etc.) is immediately visible here too.
let orderLinks = [
  { orderId: 5001, userId: 1, productId: 101, qty: 2 },
  { orderId: 5002, userId: 2, productId: 102, qty: 1 },
  { orderId: 5003, userId: 3, productId: 103, qty: 3 }
];
let nextOrderId = 5004;

app.get('/health', (req, res) => res.status(200).json({ status: "ok", service: "orders-service" }));

async function fetchUsersAndProducts() {
  const [usersRes, productsRes] = await Promise.all([
    fetch(`${USERS_SERVICE_URL}/users`),
    fetch(`${PRODUCTS_SERVICE_URL}/products`)
  ]);
  if (!usersRes.ok) throw new Error(`users-service returned ${usersRes.status}`);
  if (!productsRes.ok) throw new Error(`products-service returned ${productsRes.status}`);
  return [await usersRes.json(), await productsRes.json()];
}

function buildOrders(orderLinks, users, products) {
  return orderLinks.map(link => {
    const user = users.find(u => u.id === link.userId);
    const product = products.find(p => p.id === link.productId);
    return {
      orderId: link.orderId,
      userId: link.userId,
      productId: link.productId,
      qty: link.qty,
      total: product ? product.price * link.qty : null,
      user: user || null,
      product: product || null
    };
  });
}

// ---- READ (enriched by calling users-service + products-service) ----
app.get('/orders', async (req, res) => {
  try {
    const [users, products] = await fetchUsersAndProducts();
    const orders = buildOrders(orderLinks, users, products);
    console.log(`[orders-service] GET /orders -> built ${orders.length} orders from users-service + products-service`);
    res.json({ generatedAt: new Date().toISOString(), count: orders.length, orders });
  } catch (err) {
    console.error('[orders-service] failed to reach dependencies:', err.message);
    res.status(502).json({ error: "dependency unreachable", detail: err.message });
  }
});

// ---- CREATE ----
app.post('/orders', async (req, res) => {
  const { userId, productId, qty } = req.body || {};
  if (!userId || !productId || !qty) {
    return res.status(400).json({ error: "userId, productId and qty are required" });
  }
  try {
    const [users, products] = await fetchUsersAndProducts();
    const user = users.find(u => u.id === Number(userId));
    const product = products.find(p => p.id === Number(productId));
    if (!user) return res.status(400).json({ error: `no such userId ${userId}` });
    if (!product) return res.status(400).json({ error: `no such productId ${productId}` });

    const link = { orderId: nextOrderId++, userId: Number(userId), productId: Number(productId), qty: Number(qty) };
    orderLinks.push(link);
    console.log(`[orders-service] POST /orders -> created #${link.orderId}`);
    res.status(201).json(buildOrders([link], users, products)[0]);
  } catch (err) {
    res.status(502).json({ error: "dependency unreachable", detail: err.message });
  }
});

// ---- DELETE ----
app.delete('/orders/:id', (req, res) => {
  const id = parseInt(req.params.id);
  const before = orderLinks.length;
  orderLinks = orderLinks.filter(o => o.orderId !== id);
  if (orderLinks.length === before) return res.status(404).json({ error: "not found" });
  console.log(`[orders-service] DELETE /orders/${id} -> deleted`);
  res.status(204).send();
});

app.listen(PORT, () => console.log(`[orders-service] listening on ${PORT}, USERS_SERVICE_URL=${USERS_SERVICE_URL} PRODUCTS_SERVICE_URL=${PRODUCTS_SERVICE_URL}`));
