'use strict';

const {
  CONTROL_API_TOKEN,
  GITHUB_TOKEN,
  GITHUB_REPO,
  GITHUB_WORKFLOW,
  GITHUB_REF,
} = process.env;

function json(statusCode, payload) {
  return {
    statusCode,
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(payload),
  };
}

function unauthorized() {
  return json(401, { ok: false, error: 'unauthorized' });
}

function badRequest(message) {
  return json(400, { ok: false, error: message });
}

function getAuthToken(headers) {
  return headers['x-clawdinator-token'] || headers['X-Clawdinator-Token'] || null;
}

async function dispatchWorkflow(inputs) {
  const repo = GITHUB_REPO || 'openclaw/clawdinators';
  const workflow = GITHUB_WORKFLOW || 'fleet-deploy.yml';
  const ref = GITHUB_REF || 'main';

  const res = await fetch(`https://api.github.com/repos/${repo}/actions/workflows/${workflow}/dispatches`, {
    method: 'POST',
    headers: {
      Accept: 'application/vnd.github+json',
      Authorization: `Bearer ${GITHUB_TOKEN}`,
      'User-Agent': 'clawdinator-control',
    },
    body: JSON.stringify({ ref, inputs }),
  });

  if (!res.ok) {
    const body = await res.text();
    throw new Error(`workflow dispatch failed: ${res.status} ${body}`);
  }
}
exports.handler = async (event) => {
  if (!CONTROL_API_TOKEN) {
    return json(500, { ok: false, error: 'missing CONTROL_API_TOKEN' });
  }

  const headers = event?.headers || {};
  const token = getAuthToken(headers);
  if (!token || token !== CONTROL_API_TOKEN) {
    return unauthorized();
  }

  let payload;
  if (event && typeof event.body === 'string') {
    const body = event.isBase64Encoded
      ? Buffer.from(event.body, 'base64').toString('utf-8')
      : event.body;
    try {
      payload = JSON.parse(body);
    } catch {
      return badRequest('invalid json');
    }
  } else if (event && typeof event === 'object') {
    payload = event;
  } else {
    return badRequest('missing payload');
  }

  if (!payload || typeof payload !== 'object' || Array.isArray(payload)) {
    return badRequest('payload must be an object');
  }
  if (typeof payload.action !== 'string') {
    return badRequest('action must be a string');
  }

  const action = payload.action.toLowerCase();
  const target = payload.target;
  const caller = payload.caller;
  const amiOverride = payload.ami_override ?? '';
  const controlToken = payload.control_token || null;

  if (CONTROL_API_TOKEN && controlToken !== CONTROL_API_TOKEN) {
    return unauthorized();
  }

  if (action === 'status') {
    return json(400, { ok: false, error: 'status not supported via api' });
  }

  if (action !== 'deploy') {
    return badRequest('unsupported action');
  }

  if (typeof target !== 'string' || !target) {
    return badRequest('target required');
  }
  if (caller != null && typeof caller !== 'string') {
    return badRequest('caller must be a string');
  }
  if (typeof amiOverride !== 'string') {
    return badRequest('ami_override must be a string');
  }

  if (caller && target === caller) {
    return badRequest('refusing self-deploy');
  }

  if (!GITHUB_TOKEN) {
    return json(500, { ok: false, error: 'missing GITHUB_TOKEN' });
  }

  try {
    await dispatchWorkflow({
      target,
      ami_override: amiOverride,
    });
    return json(200, { ok: true, message: `deploy queued for ${target}` });
  } catch (err) {
    return json(500, { ok: false, error: err.message });
  }
};
