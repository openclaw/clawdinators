const crypto = require("node:crypto");
const fs = require("node:fs");

function sourceIdentity(event, { itemKind, targetRepo, itemNumber, sourceAction }) {
  const pullRequest = event.pull_request && typeof event.pull_request === "object"
    ? event.pull_request
    : {};
  const issue = event.issue && typeof event.issue === "object" ? event.issue : {};
  const source = itemKind === "pull_request" ? pullRequest : issue;
  const headSha = String(pullRequest.head?.sha || "").trim().toLowerCase();
  const baseSha = String(pullRequest.base?.sha || "").trim().toLowerCase();
  const updatedAt = String(pullRequest.updated_at || "").trim();
  const queueClaim = {};
  const result = { queue_claim: queueClaim };
  const sourceUpdatedAt = String(source.updated_at || "").trim();
  if (sourceUpdatedAt && Number.isFinite(Date.parse(sourceUpdatedAt))) {
    queueClaim.source_updated_at = sourceUpdatedAt;
  }
  if (
    typeof source.title === "string" &&
    (source.body === null || typeof source.body === "string") &&
    typeof source.locked === "boolean" &&
    Array.isArray(source.labels)
  ) {
    const labels = [
      ...new Set(
        source.labels
          .map((label) => String(label?.name || "").trim().toLowerCase())
          .filter((label) => {
            if (!label) return false;
            if (label === "proof: override") return true;
            if (/^(?:status|rating|proof|merge-risk|impact|issue-rating):/.test(label)) return false;
            if (/^p[0-3]$/.test(label)) return false;
            if ([
              "maturity:stable",
              "feature: ✨ showcase",
              "good first issue",
              "mantis: telegram-visible-proof",
              "proof: telegram-e2e",
              "triage: needs-real-behavior-proof",
              "clawsweeper-recovery-stuck",
              "no-stale",
              "stale",
            ].includes(label)) return false;
            return !label.startsWith("clawsweeper:") || [
              "clawsweeper:autofix",
              "clawsweeper:automerge",
              "clawsweeper:human-review",
              "clawsweeper:manual-only",
              "clawsweeper:bulk-filed",
            ].includes(label);
          }),
      ),
    ].sort();
    queueClaim.source_content_revision = crypto
      .createHash("sha256")
      .update(
        JSON.stringify({
          version: 2,
          title: source.title,
          body: source.body || "",
          locked: source.locked,
          close_guard_labels: labels,
        }),
      )
      .digest("hex");
  }
  if (itemKind === "pull_request") {
    if (/^[0-9a-f]{40}$/.test(headSha)) queueClaim.source_head_sha = headSha;
    if (/^[0-9a-f]{40}$/.test(baseSha)) queueClaim.source_base_sha = baseSha;
    if (typeof pullRequest.draft === "boolean") {
      queueClaim.source_is_draft = pullRequest.draft;
    }
  }
  if (itemKind === "pull_request" && /^[0-9a-f]{40}$/.test(headSha) && updatedAt) {
    result.ingress_route = "target_dispatcher";
    result.ingress_fingerprint = crypto
      .createHash("sha256")
      .update(JSON.stringify({
        version: 1,
        target_repo: String(targetRepo || "").toLowerCase(),
        item_number: Number(itemNumber),
        action: String(sourceAction || ""),
        head_sha: headSha,
        updated_at: updatedAt,
        body: typeof pullRequest.body === "string" ? pullRequest.body : "",
        label: String(event.label?.name || ""),
      }))
      .digest("hex");
  }
  return result;
}

module.exports = { sourceIdentity };

if (require.main === module) {
  const event = JSON.parse(fs.readFileSync(process.env.GITHUB_EVENT_PATH, "utf8"));
  process.stdout.write(JSON.stringify(sourceIdentity(event, {
    itemKind: process.env.ITEM_KIND,
    targetRepo: process.env.TARGET_REPO,
    itemNumber: process.env.ITEM_NUMBER,
    sourceAction: process.env.SOURCE_ACTION,
  })));
}
