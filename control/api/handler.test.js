'use strict';

const assert = require('node:assert/strict');
const { test } = require('node:test');

process.env.CONTROL_API_TOKEN = 'synthetic-control-token';
process.env.GITHUB_TOKEN = 'synthetic-github-token';
const { handler } = require('./handler');

const payload = {
  action: 'deploy',
  target: 'clawdinator-test',
  control_token: process.env.CONTROL_API_TOKEN,
};

function request(body) {
  return {
    headers: { 'x-clawdinator-token': process.env.CONTROL_API_TOKEN },
    body: JSON.stringify(body),
  };
}

test('rejects malformed input without dispatching or throwing', async (t) => {
  const fetch = t.mock.method(globalThis, 'fetch', async () => {
    throw new Error('invalid requests must not dispatch');
  });

  for (const body of [null, [], 42, 'deploy', { ...payload, action: 42 },
    { ...payload, action: {} }, { ...payload, target: {} },
    { ...payload, caller: [] }, { ...payload, ami_override: {} }]) {
    const response = await handler(request(body));
    assert.equal(response.statusCode, 400, JSON.stringify(body));
    assert.equal(JSON.parse(response.body).ok, false);
  }
  for (const event of [null, undefined]) {
    assert.equal((await handler(event)).statusCode, 401);
  }
  assert.equal(fetch.mock.callCount(), 0);
});

test('preserves authentication and self-deploy rejection', async (t) => {
  const fetch = t.mock.method(globalThis, 'fetch', async () => {
    throw new Error('rejected requests must not dispatch');
  });
  assert.equal((await handler({ body: JSON.stringify(payload) })).statusCode, 401);
  assert.equal((await handler(request({ ...payload, control_token: 'wrong' }))).statusCode, 401);
  assert.equal((await handler(request({ ...payload, caller: payload.target }))).statusCode, 400);
  assert.equal(fetch.mock.callCount(), 0);
});

test('dispatches valid direct, JSON and base64 events once', async (t) => {
  const fetch = t.mock.method(globalThis, 'fetch', async () => ({ ok: true }));
  const jsonEvent = request({ ...payload, action: 'DEPLOY' });
  const base64Event = {
    ...jsonEvent,
    body: Buffer.from(jsonEvent.body).toString('base64'),
    isBase64Encoded: true,
  };
  for (const event of [jsonEvent, base64Event, { ...payload, headers: jsonEvent.headers }]) {
    assert.equal((await handler(event)).statusCode, 200);
  }
  assert.equal(fetch.mock.callCount(), 3);
  for (const call of fetch.mock.calls) {
    assert.deepEqual(JSON.parse(call.arguments[1].body).inputs, {
      target: payload.target,
      ami_override: '',
    });
  }
});
