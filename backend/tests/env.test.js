import './setup.js';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { after, before, describe, test } from 'node:test';
import { buildPgConnection, DEV_JWT_SECRET, resolveJwtSecret } from '../src/config/env.js';

describe('resolveJwtSecret', () => {
  test('explicit JWT_SECRET is always used', () => {
    assert.equal(resolveJwtSecret({ JWT_SECRET: 's3cret', NODE_ENV: 'production', DB_CLIENT: 'pg' }), 's3cret');
    assert.equal(resolveJwtSecret({ JWT_SECRET: 's3cret' }), 's3cret');
  });

  test('production without JWT_SECRET refuses to start', () => {
    assert.throws(() => resolveJwtSecret({ NODE_ENV: 'production' }), /JWT_SECRET/);
    assert.throws(() => resolveJwtSecret({ NODE_ENV: 'production', JWT_SECRET: '' }), /JWT_SECRET/);
    assert.throws(() => resolveJwtSecret({ NODE_ENV: 'production', JWT_SECRET: '   ' }), /JWT_SECRET/);
    assert.throws(
      () => resolveJwtSecret({ DB_CLIENT: 'pg', JWT_SECRET: 'change-me-to-a-long-random-secret' }),
      /JWT_SECRET/,
      'the .env.example placeholder is not a secret',
    );
  });

  test('PostgreSQL without JWT_SECRET refuses to start, even in development', () => {
    assert.throws(() => resolveJwtSecret({ DB_CLIENT: 'pg' }), /JWT_SECRET/);
    assert.throws(() => resolveJwtSecret({ DB_CLIENT: 'pg', NODE_ENV: 'development' }), /JWT_SECRET/);
  });

  test('local sqlite dev/test falls back to the insecure dev secret', () => {
    assert.equal(resolveJwtSecret({}), DEV_JWT_SECRET);
    assert.equal(resolveJwtSecret({ NODE_ENV: 'development', DB_CLIENT: 'sqlite' }), DEV_JWT_SECRET);
    assert.equal(resolveJwtSecret({ NODE_ENV: 'test' }), DEV_JWT_SECRET);
  });
});

const URL = 'postgresql://postgres.ref:pw@aws-0-eu-central-1.pooler.supabase.com:5432/postgres';
let tmpDir;
let caPath;

before(() => {
  tmpDir = fs.mkdtempSync(path.join(os.tmpdir(), 'studyplan-env-'));
  caPath = path.join(tmpDir, 'supabase-ca.crt');
  fs.writeFileSync(caPath, '-----BEGIN CERTIFICATE-----\nTEST\n-----END CERTIFICATE-----\n');
});
after(() => fs.rmSync(tmpDir, { recursive: true, force: true }));

describe('buildPgConnection', () => {
  test('DATABASE_URL + PG_SSL_CA -> ssl.ca is the certificate', () => {
    const conn = buildPgConnection({ DATABASE_URL: URL, PG_SSL_CA: caPath });
    assert.equal(conn.connectionString, URL);
    assert.match(String(conn.ssl.ca), /BEGIN CERTIFICATE/);
    assert.notEqual(conn.ssl.rejectUnauthorized, false);
  });

  test('DATABASE_URL without CA -> rejectUnauthorized: true (SSL on by default)', () => {
    const conn = buildPgConnection({ DATABASE_URL: URL });
    assert.deepEqual(conn.ssl, { rejectUnauthorized: true });
  });

  test('PG_SSL=false -> ssl: false', () => {
    assert.equal(buildPgConnection({ DATABASE_URL: URL, PG_SSL: 'false', PG_SSL_CA: caPath }).ssl, false);
    assert.equal(buildPgConnection({ PG_HOST: 'localhost' }).ssl, false, 'host config without PG_SSL stays plain');
  });

  test('host config with PG_SSL=true verifies the certificate', () => {
    const conn = buildPgConnection({ PG_HOST: 'db.local', PG_PORT: '6543', PG_SSL: 'true' });
    assert.equal(conn.host, 'db.local');
    assert.equal(conn.port, 6543);
    assert.deepEqual(conn.ssl, { rejectUnauthorized: true });
  });

  test('never produces rejectUnauthorized: false', () => {
    const variants = [
      {}, { PG_SSL: 'true' }, { PG_SSL: '1' }, { PG_SSL: 'false' }, { DATABASE_URL: URL },
      { DATABASE_URL: URL, PG_SSL: 'true' }, { DATABASE_URL: URL, PG_SSL_CA: caPath }, { PG_SSL: 'true', PG_SSL_CA: caPath },
    ];
    for (const v of variants) {
      const { ssl } = buildPgConnection(v);
      assert.ok(ssl === false || ssl.rejectUnauthorized !== false, JSON.stringify(v));
    }
  });

  test('sslmode params are stripped from DATABASE_URL so our ssl object wins', () => {
    const conn = buildPgConnection({ DATABASE_URL: `${URL}?sslmode=require`, PG_SSL_CA: caPath });
    assert.equal(conn.connectionString, URL);
    assert.match(String(conn.ssl.ca), /BEGIN CERTIFICATE/);

    const mixed = buildPgConnection({
      DATABASE_URL: `${URL}?application_name=studyplan&sslmode=verify-full&sslrootcert=%2Ftmp%2Fca.crt&sslcert=x&sslkey=y`,
    });
    assert.equal(mixed.connectionString, `${URL}?application_name=studyplan`);
    assert.deepEqual(mixed.ssl, { rejectUnauthorized: true });
  });

  test('DATABASE_URL without query string is passed unchanged', () => {
    assert.equal(buildPgConnection({ DATABASE_URL: URL }).connectionString, URL);
  });

  test('missing CA file fails loudly', () => {
    assert.throws(() => buildPgConnection({ DATABASE_URL: URL, PG_SSL_CA: path.join(tmpDir, 'nope.crt') }), /PG_SSL_CA/);
  });
});
