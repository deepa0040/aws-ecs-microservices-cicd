// sidecar-logger: runs as a SIDECAR container in the same Task (ECS) / Pod (EKS)
// as orders-service. Because containers in the same task/pod share the network
// namespace, it can reach the main app via "localhost".
// It periodically polls the app's /health endpoint and writes a rolling log,
// simulating a log-shipper / metrics-agent sidecar pattern.

const http = require('http');

const APP_HOST = process.env.APP_HOST || 'localhost';
const APP_PORT = process.env.APP_PORT || '4003';
const INTERVAL_MS = parseInt(process.env.SIDECAR_INTERVAL_MS || '10000', 10);

function pollHealth() {
  const req = http.get({ host: APP_HOST, port: APP_PORT, path: '/health', timeout: 3000 }, (res) => {
    let body = '';
    res.on('data', (chunk) => (body += chunk));
    res.on('end', () => {
      const line = `[sidecar-logger] ${new Date().toISOString()} main-app health check: status=${res.statusCode} body=${body}`;
      console.log(line);
    });
  });
  req.on('error', (err) => {
    console.log(`[sidecar-logger] ${new Date().toISOString()} main-app UNREACHABLE: ${err.message}`);
  });
  req.on('timeout', () => req.destroy());
}

console.log(`[sidecar-logger] starting, polling http://${APP_HOST}:${APP_PORT}/health every ${INTERVAL_MS}ms`);
setInterval(pollHealth, INTERVAL_MS);
pollHealth();
