import dotenv from 'dotenv';
dotenv.config();
import app from './app';
import { pool } from './db/pool';

const PORT = process.env.PORT ?? 3000;

async function start() {
  const conn = await pool.getConnection();
  await conn.ping();
  conn.release();
  console.log('Database connected');

  app.listen(PORT, () => {
    console.log(`Server running on http://localhost:${PORT}`);
  });
}

start().catch((err) => {
  console.error('Failed to start:', err);
  process.exit(1);
});
