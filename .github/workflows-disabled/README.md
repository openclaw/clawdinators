Disabled GitHub Actions live here on purpose.

Moving a file out of `.github/workflows/` fully disables it: no schedule, no manual dispatch button, no runnable workflow at all.

The disabled set includes every AMI build and fleet deployment workflow. The AWS
fleet was retired in August 2026; no workflow may recreate it implicitly.

The unattended nix-openclaw flake bump workflow is retired; updates now use the reviewed local rebuild path.

To reactivate one of these workflows, move it back into `.github/workflows/` in a code change and review whether that would recreate infrastructure or resume unattended mutation.
