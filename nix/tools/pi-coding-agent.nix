{ pkgs }:
pkgs.buildNpmPackage {
  pname = "pi-coding-agent";
  version = "0.52.6";

  src = pkgs.fetchurl {
    url = "https://registry.npmjs.org/@mariozechner/pi-coding-agent/-/pi-coding-agent-0.52.6.tgz";
    hash = "sha256-CXKWlAxjXSwSJI+DVzgLu1A04w+QQzE6yBXBO/j/za4=";
  };

  postPatch = ''
    cp ${../vendor/pi-coding-agent/package-lock.json} package-lock.json
  '';

  # Update via `nix build` on hash mismatch
  npmDepsHash = "sha256-zD87h87FILBSKCygRLV0jZxLjgU5YnM765FISjFDpas=";
  dontNpmBuild = true;
}
