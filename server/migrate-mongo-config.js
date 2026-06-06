// migrate-mongo-config.js
const path = require('path');
require('dotenv').config({ path: path.join(__dirname, '.env') });

const config = {
  mongodb: {
    url: process.env.MONGODB_URI,
    databaseName: 'zeropay',
    options: {
      maxPoolSize: 10,
      serverSelectionTimeoutMS: 5000,
      socketTimeoutMS: 45000,
    },
  },
  migrationsDir: 'migrations',
  changelogCollectionName: 'changelog',
  migrationFileExtension: '.js',
  useFileHash: false,
  moduleSystem: 'commonjs',
};

module.exports = config;
