# ClawSweeper dispatch

The dispatcher sends issue, pull request, and command-comment locators to the
ClawSweeper Worker using GitHub Actions OIDC. The Worker owns eligibility,
live authorization, acknowledgements, and deduplication. No App private key or
installation token is passed to the target workflow.

For issue and pull request events, `scripts/clawsweeper-source-identity.cjs`
computes the existing queue claims and ingress fingerprint. The privileged
workflow checks out only `github.sha`, the trusted event commit (the base commit
for `pull_request_target`), with credentials disabled and a sparse checkout of
that helper. It never loads code from the pull request head. Comment dispatch
needs only the locator and does not check out source.

Before rollout, verify the compatible Worker is deployed and the repository's
ClawSweeper installation delivers Issues, Pull requests, and Issue comments
webhooks. The independent App route must remain enabled. Non-transient 4xx
responses warn and leave delivery to that route; missing OIDC, network errors,
408, 429, and server failures leave a failed job that can be rerun.

Run the credential-free regression gate with Node and jq installed:

```sh
node --test scripts/tests/clawsweeper-dispatch.test.cjs
```

The tests preserve protocol fingerprints, check the trusted source boundary,
and execute both shell intake paths with synthetic events and a local curl
stub. They do not prove live OIDC issuance or App webhook subscriptions.
