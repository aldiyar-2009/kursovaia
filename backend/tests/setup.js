// Must be the FIRST import of every test file: configures an isolated in-memory DB.
process.env.NODE_ENV = 'test';
process.env.DB_CLIENT = 'sqlite';
process.env.SQLITE_FILENAME = ':memory:';
process.env.JWT_SECRET = 'test-secret';
process.env.BCRYPT_ROUNDS = '4';
