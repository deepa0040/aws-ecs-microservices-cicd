// cron-report: a SHORT-LIVED, RUN-TO-COMPLETION job (not a long running server).
// - On ECS this is triggered by an EventBridge Scheduler rule that runs an ECS RunTask.
// - On EKS this is triggered natively by a CronJob resource.
// It fetches /orders from orders-service, prints a small report, then exits(0).

const ORDERS_SERVICE_URL = process.env.ORDERS_SERVICE_URL || 'http://orders-service:4003';

async function main() {
  console.log(`[cron-report] job started at ${new Date().toISOString()}`);
  try {
    const res = await fetch(`${ORDERS_SERVICE_URL}/orders`);
    if (!res.ok) throw new Error(`orders-service returned ${res.status}`);
    const data = await res.json();

    const totalRevenue = data.orders.reduce((sum, o) => sum + (o.total || 0), 0);
    console.log('[cron-report] ---- Periodic Orders Report ----');
    console.log(`[cron-report] orders count : ${data.count}`);
    console.log(`[cron-report] total revenue: ${totalRevenue}`);
    data.orders.forEach(o =>
      console.log(`[cron-report]  - order #${o.orderId}: ${o.user?.name} bought ${o.qty} x ${o.product?.name} = ${o.total}`)
    );
    console.log('[cron-report] ---- end of report ----');
    process.exit(0);
  } catch (err) {
    console.error(`[cron-report] FAILED: ${err.message}`);
    process.exit(1);
  }
}

main();
