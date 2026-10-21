const assert = require('node:assert/strict');
const { execFile } = require('node:child_process');
const { mkdtempSync, writeFileSync, symlinkSync, rmSync, readFileSync } = require('node:fs');
const { tmpdir } = require('node:os');
const { join, resolve } = require('node:path');
const { test } = require('node:test');

const checker = resolve(__dirname, '../bin/check-claude');
const success = { type: 'result', subtype: 'success', is_error: false, result: 'OK' };

function runCheck(t, source, { env = {}, args = [], timeout = 5000 } = {}) {
  const directory = mkdtempSync(join(tmpdir(), 'check-claude-test-'));
  t.after(() => rmSync(directory, { recursive: true, force: true }));
  symlinkSync(process.execPath, join(directory, 'node'));
  if (source !== null) {
    writeFileSync(join(directory, 'claude'), `#!/usr/bin/env node\n${source}\n`, { mode: 0o755 });
  }
  return new Promise((done) => {
    execFile(process.execPath, [checker, ...args], {
      env: { ...process.env, ...env, PATH: directory },
      timeout,
      maxBuffer: 256 * 1024,
    }, (error, stdout, stderr) => {
      done({ status: error ? error.code : 0, signal: error?.signal, stdout, stderr });
    });
  });
}

test('uses the isolated request contract, closed stdin, and caller environment', async (t) => {
  const result = await runCheck(t, `
    const assert = require('node:assert/strict');
    assert.deepEqual(process.argv.slice(2), [
      '--print', '--safe-mode', '--tools', '',
      '--strict-mcp-config', '--mcp-config', '{"mcpServers":{}}',
      '--no-session-persistence', '--effort', 'low', '--max-turns', '1',
      '--output-format', 'json', '--system-prompt', 'Reply with exactly OK.',
      'Reply with exactly OK.',
    ]);
    assert.equal(require('node:fs').readFileSync(0, 'utf8'), '');
    assert.equal(process.env.ANTHROPIC_API_KEY, 'test-api-key');
    assert.equal(process.env.CLAUDE_CODE_OAUTH_TOKEN, 'test-oauth-token');
    assert.equal(process.env.CLAUDE_CONFIG_DIR, '/test/claude-config');
    assert.equal(process.env.ANTHROPIC_MODEL, 'test-model');
    console.log(${JSON.stringify(JSON.stringify({ ...success, result: ' OK\n', extra: true }))});
  `, { env: {
    ANTHROPIC_API_KEY: 'test-api-key',
    CLAUDE_CODE_OAUTH_TOKEN: 'test-oauth-token',
    CLAUDE_CONFIG_DIR: '/test/claude-config',
    ANTHROPIC_MODEL: 'test-model',
  } });
  assert.equal(result.status, 0, result.stderr);
  assert.match(result.stdout, /Claude is ready/);
  assert.equal(result.stderr, '');
  assert.doesNotMatch(result.stdout, /test-api-key|test-oauth-token/);
});

test('fails when claude is missing', async (t) => {
  const result = await runCheck(t, null);
  assert.equal(result.status, 1);
  assert.match(result.stderr, /could not start claude.*ENOENT/);
  assert.equal(result.stdout, '');
});

test('preserves request failure text and stderr on a nonzero exit', async (t) => {
  const result = await runCheck(t, `
    console.log('Authentication failed. Run claude auth login.');
    console.error('Token refresh failed.');
    process.exitCode = 7;
  `);
  assert.equal(result.status, 1);
  assert.match(result.stderr, /status 7/);
  assert.match(result.stderr, /Authentication failed/);
  assert.match(result.stderr, /Token refresh failed/);
});

test('rejects a successful JSON result when claude exits nonzero', async (t) => {
  const result = await runCheck(t, `
    console.log(${JSON.stringify(JSON.stringify(success))});
    process.exitCode = 1;
  `);
  assert.equal(result.status, 1);
  assert.doesNotMatch(result.stdout, /ready/);
});

test('reports a signal exit', async (t) => {
  const result = await runCheck(t, "process.kill(process.pid, 'SIGTERM');");
  assert.equal(result.status, 1);
  assert.match(result.stderr, /SIGTERM/);
});

test('rejects malformed JSON and preserves stderr', async (t) => {
  const result = await runCheck(t, "console.log('not JSON'); console.error('Request failed.');");
  assert.equal(result.status, 1);
  assert.match(result.stderr, /valid JSON/);
  assert.match(result.stderr, /not JSON/);
  assert.match(result.stderr, /Request failed/);
});

test('requires every success field and the exact trimmed reply', async (t) => {
  const invalid = [
    null,
    [success],
    { ...success, type: 'system' },
    { ...success, subtype: 'error_during_execution', result: 'Login required.' },
    { ...success, is_error: true },
    { ...success, is_error: undefined },
    { ...success, result: undefined },
    { ...success, result: ['OK'] },
    { ...success, result: 'OK, ready.' },
  ];
  for (const value of invalid) {
    const result = await runCheck(t, `console.log(${JSON.stringify(JSON.stringify(value))});`);
    assert.equal(result.status, 1, JSON.stringify(value));
    assert.match(result.stderr, /successful OK result/);
    assert.equal(result.stdout, '');
    if (value?.result === 'Login required.') assert.match(result.stderr, /Login required/);
  }
});

test('bounds captured output and rejects a truncated result', async (t) => {
  const result = await runCheck(t, `
    process.stdout.write('x'.repeat(200000));
    process.stderr.write('y'.repeat(200000));
  `);
  assert.equal(result.status, 1);
  assert.match(result.stderr, /too much output/);
  assert.match(result.stderr, /stdout truncated/);
  assert.match(result.stderr, /stderr truncated/);
  assert.ok(result.stderr.length < 133000);
});

test('rejects unexpected arguments before starting claude', async (t) => {
  const result = await runCheck(t, "console.error('Unexpected invocation');", { args: ['--timeout', '1'] });
  assert.equal(result.status, 2);
  assert.match(result.stderr, /Usage/);
  assert.doesNotMatch(result.stderr, /Unexpected invocation/);
});

test('enforces the 45-second deadline despite ignored SIGTERM and inherited pipes', { timeout: 60000 }, async (t) => {
  const directory = mkdtempSync(join(tmpdir(), 'check-claude-deadline-'));
  const pidFile = join(directory, 'pids');
  t.after(() => {
    if (require('node:fs').existsSync(pidFile)) {
      for (const pid of readFileSync(pidFile, 'utf8').split('\n').filter(Boolean)) {
        try { process.kill(Number(pid), 'SIGKILL'); } catch (error) {
          if (error.code !== 'ESRCH') throw error;
        }
      }
    }
    rmSync(directory, { recursive: true, force: true });
  });
  const start = performance.now();
  const result = await runCheck(t, `
    process.on('SIGTERM', () => {});
    const child = require('node:child_process').spawn(process.execPath, [
      '-e', "process.on('SIGTERM', () => {}); setInterval(() => {}, 1000);",
    ], { stdio: ['ignore', 'inherit', 'inherit'] });
    require('node:fs').writeFileSync(process.env.TEST_PID_FILE, process.pid + '\\n' + child.pid);
    console.error('Waiting for Claude response.');
    setInterval(() => {}, 1000);
  `, { env: { TEST_PID_FILE: pidFile }, timeout: 55000 });
  const elapsed = performance.now() - start;
  assert.equal(result.status, 1, result.stderr);
  assert.equal(result.signal, null);
  assert.match(result.stderr, /45-second deadline/);
  assert.match(result.stderr, /Waiting for Claude response/);
  assert.ok(elapsed >= 45000 && elapsed < 53000, `finished after ${elapsed}ms`);
  const [direct, descendant] = readFileSync(pidFile, 'utf8').split('\n').map(Number);
  assert.throws(() => process.kill(direct, 0), { code: 'ESRCH' });
  assert.doesNotThrow(() => process.kill(descendant, 0));
});
