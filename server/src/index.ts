import { config } from './config';
import { createApp } from './app';

createApp().listen(config.port, () => {
  console.log(`OPL Server listening on port ${config.port}`);
  if (!process.env.ADMIN_TOKEN) console.warn('ADMIN_TOKEN is unset; admin writes are disabled.');
});
