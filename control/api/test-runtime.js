'use strict';

const assert = require('node:assert/strict');
const { execFileSync } = require('node:child_process');
const fs = require('node:fs');
const https = require('node:https');
const os = require('node:os');
const path = require('node:path');
const { setTimeout: delay } = require('node:timers/promises');

const token = 'synthetic-control-token';
const dispatchLog = '/tmp/control-dispatch.jsonl';
const readyFile = '/tmp/control-dispatch-ready';

function serveDispatch() {
  fs.writeFileSync(dispatchLog, '');
  https.createServer({
    key: fs.readFileSync('/var/task/key.pem'),
    cert: fs.readFileSync('/var/task/cert.pem'),
  }, async (request, response) => {
    const chunks = [];
    for await (const chunk of request) chunks.push(chunk);
    fs.appendFileSync(dispatchLog, `${JSON.stringify({
      method: request.method,
      url: request.url,
      body: JSON.parse(Buffer.concat(chunks).toString()),
    })}\n`);
    response.writeHead(204);
    response.end();
  }).listen(443, '127.0.0.1', () => fs.writeFileSync(readyFile, 'ready'));
}

async function verify() {
  for (let attempt = 0; !fs.existsSync(readyFile); attempt++) {
    assert.ok(attempt < 100, 'dispatch fixture did not start');
    await delay(100);
  }
  const headers = { 'x-clawdinator-token': token };
  const payload = { action: 'deploy', target: 'synthetic-target', control_token: token };
  const request = (body) => ({ headers, body: JSON.stringify(body) });
  const invoke = async (event) => {
    const response = await fetch('http://127.0.0.1:8080/2015-03-31/functions/function/invocations', {
      method: 'POST',
      body: JSON.stringify(event),
      signal: AbortSignal.timeout(30000),
    });
    assert.equal(response.status, 200, 'Lambda invocation failed');
    return response.json();
  };
  const dispatches = () => fs.readFileSync(dispatchLog, 'utf8').trim()
    .split('\n').filter(Boolean).map((line) => JSON.parse(line));

  for (const body of [null, [], 42, 'deploy', { ...payload, action: 42 },
    { ...payload, action: {} }, { ...payload, target: {} },
    { ...payload, caller: [] }, { ...payload, ami_override: {} },
    { ...payload, caller: false }, { ...payload, caller: 0 },
    { ...payload, ami_override: false }, { ...payload, ami_override: 0 }]) {
    const response = await invoke(request(body));
    assert.equal(response.statusCode, 400, `malformed payload: ${JSON.stringify(body)}`);
    assert.equal(JSON.parse(response.body).ok, false);
  }
  assert.equal(dispatches().length, 0);
  console.log('PASS: 13 authenticated malformed Lambda payloads return 400; HTTPS dispatches=0');

  assert.equal((await invoke({ body: JSON.stringify(payload) })).statusCode, 401);
  assert.equal((await invoke(request({ ...payload, control_token: 'wrong' }))).statusCode, 401);
  assert.equal((await invoke(request({ ...payload, caller: payload.target }))).statusCode, 400);
  for (const control_token of [undefined, null, '', 'wrong']) {
    assert.equal((await invoke({ ...payload, control_token })).statusCode, 401);
  }
  for (const event of [
    { ...payload, headers: {} },
    { ...payload, requestContext: {} },
    { ...request(payload), headers: { 'x-clawdinator-token': 'wrong' } },
    request({ ...payload, control_token: undefined }),
  ]) {
    assert.equal((await invoke(event)).statusCode, 401);
  }
  assert.equal(dispatches().length, 0);
  console.log('PASS: direct/HTTP authentication and self-deploy protection; HTTPS dispatches=0');

  for (const optional of [{}, { caller: null }, { ami_override: null },
    { caller: null, ami_override: null }]) {
    const body = { ...payload, action: 'DEPLOY', ...optional };
    const jsonEvent = request(body);
    for (const event of [jsonEvent, {
      ...jsonEvent,
      body: Buffer.from(jsonEvent.body).toString('base64'),
      isBase64Encoded: true,
    }, { ...body, headers }, body]) {
      assert.equal((await invoke(event)).statusCode, 200);
    }
  }
  assert.equal(dispatches().length, 16);
  for (const dispatch of dispatches()) {
    assert.deepEqual(dispatch, {
      method: 'POST',
      url: '/repos/synthetic/control-test/actions/workflows/fixture.yml/dispatches',
      body: { ref: 'main', inputs: { target: payload.target, ami_override: '' } },
    });
  }
  console.log('PASS: payload-only/direct/JSON/base64 Lambda events with omitted or null optional fields return 200; exact HTTPS dispatches=16');
}

function run() {
  const directory = fs.mkdtempSync(path.join(os.tmpdir(), 'control-runtime-'));
  const container = `control-runtime-${process.pid}-${Date.now()}`;
  const exec = (command, args, options = {}) => execFileSync(command, args, {
    stdio: 'inherit', timeout: 300000, ...options,
  });
  let started = false;
  try {
    fs.copyFileSync(process.argv[2] || path.join(__dirname, 'handler.js'), path.join(directory, 'handler.js'));
    fs.copyFileSync(__filename, path.join(directory, 'test-runtime.js'));
    exec('openssl', ['req', '-x509', '-newkey', 'rsa:2048', '-nodes', '-days', '1',
      '-subj', '/CN=api.github.com', '-addext', 'subjectAltName=DNS:api.github.com',
      '-keyout', path.join(directory, 'key.pem'), '-out', path.join(directory, 'cert.pem')],
    { stdio: 'ignore' });
    exec('docker', ['run', '--detach', '--name', container, '--network', 'none',
      '--add-host', 'api.github.com:127.0.0.1',
      '--mount', `type=bind,src=${directory},dst=/var/task,readonly`,
      '--env', `CONTROL_API_TOKEN=${token}`, '--env', 'GITHUB_TOKEN=synthetic-github-token',
      '--env', 'GITHUB_REPO=synthetic/control-test', '--env', 'GITHUB_WORKFLOW=fixture.yml',
      '--env', 'NODE_EXTRA_CA_CERTS=/var/task/cert.pem',
      'public.ecr.aws/lambda/nodejs:20', 'handler.handler']);
    started = true;
    exec('docker', ['exec', '--detach', container, '/var/lang/bin/node', '/var/task/test-runtime.js', 'fixture']);
    exec('docker', ['exec', container, '/var/lang/bin/node', '/var/task/test-runtime.js', 'verify']);
  } finally {
    if (started) exec('docker', ['rm', '--force', container]);
    fs.rmSync(directory, { recursive: true, force: true });
  }
}

if (process.argv[2] === 'fixture') serveDispatch();
else if (process.argv[2] === 'verify') verify().catch((error) => { console.error(error); process.exitCode = 1; });
else run();
