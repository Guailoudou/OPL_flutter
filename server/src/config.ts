import path from 'path';

export const config = {
  port: parseInt(process.env.PORT || '3000', 10),
  dataDir: path.join(__dirname, 'data'),
};
