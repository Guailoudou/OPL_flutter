import path from 'path';

export const config = {
  port: parseInt(process.env.PORT || '3000', 10),
  // Keep one source of truth for both tsx development and dist execution.
  dataDir: process.env.OPL_DATA_DIR || path.resolve(__dirname, '..', 'src', 'data'),
};
