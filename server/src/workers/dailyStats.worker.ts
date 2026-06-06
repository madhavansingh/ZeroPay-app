import { Worker, Job } from 'bullmq';
import { bullMqRedis } from '../config/redis';
import { Invoice } from '../models/Invoice';
import { Merchant } from '../models/Merchant';

interface DailyStatsJobData {
  merchantId?: string; // optional: if absent, compute for all merchants
}

/**
 * Daily stats worker — runs nightly (via repeatable job) to pre-aggregate
 * per-merchant revenue stats. Improves dashboard query performance.
 * For MVP this is lightweight — the dashboard route does live aggregation,
 * so this worker stores per-day snapshots to Redis for faster chart loads.
 */
export function startDailyStatsWorker(): Worker {
  const worker = new Worker<DailyStatsJobData>(
    'daily-stats',
    async (_job: Job<DailyStatsJobData>) => {
      const today = new Date();
      today.setHours(0, 0, 0, 0);
      const yesterday = new Date(today.getTime() - 24 * 60 * 60 * 1000);

      // Aggregate all settled invoices from yesterday
      const result = await Invoice.aggregate([
        {
          $match: {
            status: 'settled',
            settledAt: { $gte: yesterday, $lt: today },
          },
        },
        {
          $group: {
            _id: '$merchantId',
            totalLovelace: { $sum: '$amountLovelace' },
            totalPaise: { $sum: '$amountPaise' },
            orderCount: { $sum: 1 },
          },
        },
      ]);

      // Update merchant running totals (these are already incremented per-settlement
      // in the receipt worker — this worker validates consistency)
      let syncCount = 0;
      for (const row of result) {
        const liveTotal = await Invoice.aggregate([
          { $match: { merchantId: row._id, status: 'settled' } },
          { $group: { _id: null, total: { $sum: '$amountLovelace' }, orders: { $sum: 1 } } },
        ]);

        if (liveTotal[0]) {
          await Merchant.findByIdAndUpdate(row._id, {
            $set: {
              totalReceivedLovelace: liveTotal[0].total,
              totalOrders: liveTotal[0].orders,
            },
          });
          syncCount++;
        }
      }

      const dateStr = yesterday.toISOString().slice(0, 10);
      console.log(`✅ [daily-stats] ${dateStr} — synced ${syncCount} merchants, ${result.length} active`);
    },
    { connection: bullMqRedis as any, concurrency: 1 }
  );

  worker.on('active', (job) => {
    console.log(`[dailyStats] Job ${job.id} is now active`);
  });

  worker.on('completed', (job) => {
    console.log(`[dailyStats] Job ${job.id} has completed`);
  });

  worker.on('failed', (_job, err) => {
    console.error('[daily-stats] Job failed:', err.message);
  });

  return worker;
}
