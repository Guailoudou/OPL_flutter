import { test } from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';

test('writes require a configured key, validate data, and preserve files on rejection', async () => {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'opl-api-'));
  process.env.OPL_DATA_DIR = dir;
  const { createApp } = await import('../src/app');
  const server = createApp().listen(0, '127.0.0.1');
  await new Promise<void>(resolve => server.once('listening', resolve));
  const address = server.address();
  assert.ok(address && typeof address !== 'string');
  const url = `http://127.0.0.1:${address.port}`;
  const body = { notices: [{ title: 'A', content: 'B', time: '2026-10-04' }] };
  const post = (data: unknown, token = '') => fetch(`${url}/api/notices`, {
    method: 'POST', headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${token}` },
    body: JSON.stringify(data),
  });
  try {
    delete process.env.ADMIN_TOKEN;
    assert.equal((await post(body)).status, 503);
    process.env.ADMIN_TOKEN = 'test-only-secret';
    assert.equal((await post(body)).status, 401);
    assert.equal((await post(body, 'test-only-secret')).status, 200);
    assert.equal((await post({ notices: 'invalid' }, 'test-only-secret')).status, 400);
    assert.deepEqual(await (await fetch(`${url}/data/notices.json`)).json(), body);
    assert.equal((await fetch(`${url}/api/missing`)).status, 404);
    assert.equal(fs.existsSync(path.join(dir, 'notices.json.tmp')), false);
    const release = { version: '1.2.3', url: 'https://example.test/core.tar.gz', hash: 'a'.repeat(64) };
    const response = await fetch(`${url}/api/core/linux-arm64`, {
      method: 'POST', headers: { 'Content-Type': 'application/json', Authorization: 'Bearer test-only-secret' },
      body: JSON.stringify({ core: release }),
    });
    assert.equal(response.status, 200);
    const core = await (await fetch(`${url}/api/core/linux-arm64`)).json() as { core: unknown };
    assert.deepEqual(core.core, release);
    assert.equal((await fetch(`${url}/api/core`, {
      method: 'POST', headers: { 'Content-Type': 'application/json', Authorization: 'Bearer test-only-secret' },
      body: JSON.stringify({ easytier: { 'macos-arm64': release } }),
    })).status, 200);
    const all = await (await fetch(`${url}/api/core`)).json() as { core: Record<string, unknown>; easytier: Record<string, unknown> };
    assert.deepEqual(all.core['linux-arm64'], release);
    assert.deepEqual(all.easytier['macos-arm64'], release);
  } finally {
    await new Promise<void>((resolve, reject) => server.close(err => err ? reject(err) : resolve()));
    fs.rmSync(dir, { recursive: true, force: true });
    delete process.env.ADMIN_TOKEN;
    delete process.env.OPL_DATA_DIR;
  }
});
