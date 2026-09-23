{ pkgs }:
pkgs.buildNpmPackage {
  pname = "pi-coding-agent";
  version = "0.52.12";

  src = pkgs.fetchurl {
    url = "https://registry.npmjs.org/@mariozechner/pi-coding-agent/-/pi-coding-agent-0.52.12.tgz";
    hash = "sha256-xioju9FJfRsSmL1pWQyRU29i9nGtnYIa2HZ/uR4+hmY=";
  };

  postPatch = ''
    cp ${../vendor/pi-coding-agent/package-lock.json} package-lock.json
  '';

  # Update via `nix build` on hash mismatch
  npmDepsHash = "sha256-lwIK+JjQKbep36j/7mypm99Vv18tWspqn/DZKg5LKCI=";
  dontNpmBuild = true;
}
