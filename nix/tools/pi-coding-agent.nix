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
    # Match the frozen Pi requirements before applying the FTP parser override.
    ${pkgs.jq}/bin/jq --slurpfile lock package-lock.json \
      '.dependencies = $lock[0].packages[""].dependencies | .overrides."basic-ftp" = "6.2.3"' \
      package.json > package.json.tmp
    mv package.json.tmp package.json
  '';

  # Update via `nix build` on hash mismatch
  npmDepsHash = "sha256-JHN1BVrD34nyrs0sRzQIFLE0Qh57NPmFgVMocR2IXFA=";
  dontNpmBuild = true;
}
