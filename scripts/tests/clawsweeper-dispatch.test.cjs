const assert = require("node:assert/strict");
const { execFileSync, spawnSync } = require("node:child_process");
const fs = require("node:fs");
const os = require("node:os");
const path = require("node:path");
const { test } = require("node:test");
const { sourceIdentity } = require("../clawsweeper-source-identity.cjs");

const root = path.resolve(__dirname, "../..");
const workflow = fs.readFileSync(path.join(root, ".github/workflows/clawsweeper-dispatch.yml"), "utf8");
const context = {
  itemKind: "pull_request",
  targetRepo: "openclaw/clawdinators",
  itemNumber: "42",
  sourceAction: "labeled",
};
const fixture = {
  pull_request: {
    title: "Fix a synthetic bug",
    body: "Synthetic description",
    locked: false,
    labels: [
      { name: "bug" }, { name: "PROOF: OVERRIDE" }, { name: "status: reviewing" },
      { name: "Bug" }, { name: "clawsweeper:manual-only" },
    ],
    head: { sha: "A".repeat(40) },
    base: { sha: "b".repeat(40) },
    updated_at: "2026-10-19T00:00:00Z",
    draft: false,
  },
  label: { name: "bug" },
};

test("source identity retains the original dispatch protocol bytes", () => {
  assert.deepEqual(sourceIdentity(fixture, context), {
    queue_claim: {
      source_updated_at: "2026-10-19T00:00:00Z",
      source_content_revision: "9c354356c862e90f9089b9d9e11373db1073fb0f0edb0f070099f9e9c2bd62e0",
      source_head_sha: "a".repeat(40),
      source_base_sha: "b".repeat(40),
      source_is_draft: false,
    },
    ingress_route: "target_dispatcher",
    ingress_fingerprint: "8afc8cc080d65c3ac2240d9cc38c543eea99c07097bc2309454ea38a233b80d4",
  });
});

test("status labels leave content identity unchanged; close guards change it", () => {
  const initial = sourceIdentity(fixture, context).queue_claim.source_content_revision;
  const event = structuredClone(fixture);
  event.pull_request.labels.reverse();
  event.pull_request.labels.push({ name: "rating: reviewed" }, { name: "P2" }, { name: "bug" });
  assert.equal(sourceIdentity(event, context).queue_claim.source_content_revision, initial);
  event.pull_request.labels.push({ name: "clawsweeper:human-review" });
  assert.notEqual(sourceIdentity(event, context).queue_claim.source_content_revision, initial);
});

test("issue claims omit PR identity and accept null bodies", () => {
  const issue = { ...fixture.pull_request, body: null };
  const result = sourceIdentity({ issue }, { ...context, itemKind: "issue" });
  assert.deepEqual(Object.keys(result), ["queue_claim"]);
  assert.deepEqual(Object.keys(result.queue_claim), ["source_updated_at", "source_content_revision"]);
  assert.match(result.queue_claim.source_content_revision, /^[0-9a-f]{64}$/);
});

test("incomplete event data omits unsupported claims", () => {
  assert.deepEqual(sourceIdentity({}, context), { queue_claim: {} });
  assert.deepEqual(sourceIdentity({ pull_request: {
    head: { sha: "invalid" }, base: { sha: "invalid" }, updated_at: "invalid",
  } }, context), { queue_claim: {} });
});

function step(name) {
  const marker = `      - name: ${name}\n`;
  assert.equal(workflow.split(marker).length, 2, `unique step: ${name}`);
  return workflow.split(marker)[1].split("\n      - name:")[0];
}

function shell(name) {
  const block = step(name).split("        run: |\n")[1];
  assert.ok(block, `shell block: ${name}`);
  return block.split("\n").map((line) => line.startsWith("          ") ? line.slice(10) : line).join("\n");
}

test("privileged dispatch loads only the trusted event commit without persisted credentials", () => {
  const checkout = step("Read trusted dispatcher helper");
  assert.match(checkout, /if: \$\{\{ github\.event_name != 'issue_comment' \}\}/);
  assert.match(checkout, /ref: \$\{\{ github\.sha \}\}/);
  assert.match(checkout, /persist-credentials: false/);
  assert.match(checkout, /sparse-checkout: scripts\/clawsweeper-source-identity\.cjs/);
  assert.doesNotMatch(workflow, /pull_request\.head|secrets\.|create-github-app-token|node\s+<</);
});

test("checked-in CLI and both workflow intake paths run on synthetic inputs", (t) => {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), "clawsweeper-dispatch-"));
  t.after(() => fs.rmSync(dir, { recursive: true, force: true }));
  const helperDir = path.join(dir, "trusted-dispatcher/scripts");
  fs.mkdirSync(helperDir, { recursive: true });
  fs.copyFileSync(path.join(root, "scripts/clawsweeper-source-identity.cjs"), path.join(helperDir, "clawsweeper-source-identity.cjs"));
  fs.writeFileSync(path.join(dir, "event.json"), JSON.stringify(fixture));
  fs.writeFileSync(path.join(dir, "curl"), `#!/usr/bin/env node
const fs = require("node:fs");
const args = process.argv.slice(2);
if (args.includes("--get")) {
  process.stdout.write(JSON.stringify({value: "synthetic-oidc"}));
} else {
  fs.writeFileSync(process.env.CAPTURE, args[args.indexOf("--data") + 1]);
  fs.writeFileSync(args[args.indexOf("--output") + 1], '{"accepted":true}');
  process.stdout.write(process.env.HTTP_STATUS);
}
`, { mode: 0o755 });
  const env = {
    PATH: `${dir}${path.delimiter}${process.env.PATH}`,
    HOME: dir,
    GITHUB_EVENT_PATH: path.join(dir, "event.json"),
    RUNNER_TEMP: dir,
    ITEM_KIND: context.itemKind,
    ITEM_NUMBER: context.itemNumber,
    TARGET_REPO: context.targetRepo,
    TARGET_BRANCH: "main",
    SOURCE_ACTION: context.sourceAction,
    SOURCE_EVENT: "pull_request_target",
    SUPERSEDES_IN_PROGRESS: "false",
    COMMENT_ID: "123",
    ACTIONS_ID_TOKEN_REQUEST_URL: "https://synthetic.invalid/oidc",
    ACTIONS_ID_TOKEN_REQUEST_TOKEN: "synthetic-request-token",
    TARGET_DISPATCH_URL: "https://synthetic.invalid/intake",
    CAPTURE: path.join(dir, "payload.json"),
  };
  const output = execFileSync(process.execPath, [path.join(helperDir, "clawsweeper-source-identity.cjs")], { env, encoding: "utf8" });
  assert.deepEqual(JSON.parse(output), sourceIdentity(fixture, context));
  for (const name of ["Dispatch exact ClawSweeper review", "Dispatch ClawSweeper comment"]) {
    for (const [httpStatus, exitCode] of [["202", 0], ["403", 0], ["408", 1], ["429", 1], ["503", 1]]) {
      const run = spawnSync("bash", ["-c", shell(name)], {
        cwd: dir, env: { ...env, HTTP_STATUS: httpStatus }, encoding: "utf8", timeout: 10000,
      });
      assert.equal(run.status, exitCode, `${name}: HTTP ${httpStatus}: ${run.stderr}`);
      const payload = JSON.parse(fs.readFileSync(env.CAPTURE, "utf8"));
      assert.equal(payload.target_repo, context.targetRepo);
      assert.equal(payload.item_number, 42);
      if (name === "Dispatch exact ClawSweeper review") {
        assert.deepEqual(payload.queue_claim, sourceIdentity(fixture, context).queue_claim);
        assert.equal(payload.ingress_fingerprint, sourceIdentity(fixture, context).ingress_fingerprint);
      } else {
        assert.equal(payload.comment_id, 123);
        assert.equal(payload.source_event, "issue_comment");
        assert.deepEqual(Object.keys(payload).sort(), ["comment_id", "item_number", "source_action", "source_event", "target_repo"]);
      }
    }
  }
});
