const express = require('express');
const path = require('path');
const app = express();
app.use(express.json());
const PORT = process.env.PORT || 4000;

const ORDERS_SERVICE_URL = process.env.ORDERS_SERVICE_URL || 'http://orders-service:4003';
const USERS_SERVICE_URL = process.env.USERS_SERVICE_URL || 'http://users-service:4001';
const PRODUCTS_SERVICE_URL = process.env.PRODUCTS_SERVICE_URL || 'http://products-service:4002';

app.use(express.static(path.join(__dirname, 'public')));

app.get('/health', (req, res) => res.status(200).json({ status: "ok", service: "frontend" }));

// Backend-for-frontend: aggregate a simple status + dashboard payload
app.get('/api/dashboard', async (req, res) => {
  const status = {};
  const check = async (name, url) => {
    try {
      const r = await fetch(`${url}/health`, { signal: AbortSignal.timeout(3000) });
      status[name] = r.ok ? 'up' : `error ${r.status}`;
    } catch (e) {
      status[name] = 'down';
    }
  };

  await Promise.all([
    check('users-service', USERS_SERVICE_URL),
    check('products-service', PRODUCTS_SERVICE_URL),
    check('orders-service', ORDERS_SERVICE_URL)
  ]);

  let users = [];
  let products = [];
  let orders = { count: 0, orders: [] };
  try {
    const r = await fetch(`${USERS_SERVICE_URL}/users`, { signal: AbortSignal.timeout(3000) });
    if (r.ok) users = await r.json();
  } catch (e) { /* leave empty */ }
  try {
    const r = await fetch(`${PRODUCTS_SERVICE_URL}/products`, { signal: AbortSignal.timeout(3000) });
    if (r.ok) products = await r.json();
  } catch (e) { /* leave empty */ }
  try {
    const r = await fetch(`${ORDERS_SERVICE_URL}/orders`, { signal: AbortSignal.timeout(3000) });
    if (r.ok) orders = await r.json();
  } catch (e) { /* orders-service down, leave empty */ }

  res.json({ status, users, products, orders });
});

// ---------------------------------------------------------------
// Thin proxy layer so the browser only ever talks to the frontend.
// Every call here forwards to the real microservice, so any CRUD
// action performed from the dashboard is a genuine cross-service
// write, not something faked in the frontend.
// ---------------------------------------------------------------
function proxy(baseUrlGetter, upstreamPath) {
  return async (req, res) => {
    const base = baseUrlGetter();
    const url = `${base}${upstreamPath(req)}`;
    try {
      const r = await fetch(url, {
        method: req.method,
        headers: { 'Content-Type': 'application/json' },
        body: ['POST', 'PUT', 'PATCH'].includes(req.method) ? JSON.stringify(req.body || {}) : undefined,
        signal: AbortSignal.timeout(5000)
      });
      if (r.status === 204) return res.status(204).send();
      const contentType = r.headers.get('content-type') || '';
      const body = contentType.includes('application/json') ? await r.json() : await r.text();
      res.status(r.status).send(body);
    } catch (err) {
      res.status(502).json({ error: 'upstream unreachable', detail: err.message, url });
    }
  };
}

// users-service proxy
app.get('/api/users', proxy(() => USERS_SERVICE_URL, () => '/users'));
app.post('/api/users', proxy(() => USERS_SERVICE_URL, () => '/users'));
app.put('/api/users/:id', proxy(() => USERS_SERVICE_URL, (req) => `/users/${req.params.id}`));
app.delete('/api/users/:id', proxy(() => USERS_SERVICE_URL, (req) => `/users/${req.params.id}`));

// products-service proxy
app.get('/api/products', proxy(() => PRODUCTS_SERVICE_URL, () => '/products'));
app.post('/api/products', proxy(() => PRODUCTS_SERVICE_URL, () => '/products'));
app.put('/api/products/:id', proxy(() => PRODUCTS_SERVICE_URL, (req) => `/products/${req.params.id}`));
app.delete('/api/products/:id', proxy(() => PRODUCTS_SERVICE_URL, (req) => `/products/${req.params.id}`));

// orders-service proxy
app.get('/api/orders', proxy(() => ORDERS_SERVICE_URL, () => '/orders'));
app.post('/api/orders', proxy(() => ORDERS_SERVICE_URL, () => '/orders'));
app.delete('/api/orders/:id', proxy(() => ORDERS_SERVICE_URL, (req) => `/orders/${req.params.id}`));

app.listen(PORT, () => console.log(`[frontend] listening on ${PORT}`));
