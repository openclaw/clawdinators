# Ops Memory

Operational runbook notes and gotchas.

- Keep secrets in agenix; rekey when host SSH keys rotate.
- Use nixos-anywhere for first install, then self-update timer for upgrades.

Update with incidents, fixes, and operational lessons.

## 2026-01-29
- AMI: ami-0b6acad77477abc33 (clawdinators 063b573, nix-openclaw 8ff02aae; extensions packaged).
- Instance: i-0e6125bd57991c5cc (IP 3.75.198.206, DNS ec2-3-75-198-206.eu-central-1.compute.amazonaws.com).
- Discord plugin now loads via packaged extensions; config includes plugins.entries.discord.enabled.
- Note: Discord gateway logged intermittent code 1006 closes; `openclaw doctor` reports Discord ok.

## 2026-02-01
- AMI: ami-003e9e3a97f875f63 (t3.large rebuild; swap + git identity baked).
- Instance: i-077b9075e32a3b8f7 (IP 3.121.98.87, DNS ec2-3-121-98-87.eu-central-1.compute.amazonaws.com).

## 2026-02-02
- AMI: ami-047e0e6354df0f87e (pi coding agent + OpenAI API defaults).
- Instance: i-0d1b0e288dd70273b (IP 3.73.1.102, DNS ec2-3-73-1-102.eu-central-1.compute.amazonaws.com).
