# TOOLS

Default tooling lives in `devenv.nix`. Use repo scripts for logic.

Rules:
- No inline Python/Node/etc. in shell or Nix blocks.
- Prefer scripts in `scripts/` and call them.
- Keep changes declarative; avoid manual host edits.
