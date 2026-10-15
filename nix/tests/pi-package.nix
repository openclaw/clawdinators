let
  lock = builtins.fromJSON (builtins.readFile ../../flake.lock);
  locked = lock.nodes.${lock.nodes.nix-openclaw.inputs.nixpkgs}.locked;
  pkgs = import (builtins.fetchTarball {
    url = "https://github.com/NixOS/nixpkgs/archive/${locked.rev}.tar.gz";
    sha256 = locked.narHash;
  }) {};
  pi = pkgs.callPackage ../tools/pi-coding-agent.nix {};
in
pkgs.runCommand "clawdinator-pi-package-test" {} ''
  export HOME="$TMPDIR/home"
  mkdir -p "$HOME"
  ${pi}/bin/pi --version | grep -Fx 0.52.6
  ${pi}/bin/pi --help > "$TMPDIR/help.txt"
  ${pi}/bin/pi --list-models > "$TMPDIR/models.txt"
  test -s "$TMPDIR/help.txt"
  test -s "$TMPDIR/models.txt"
  test ! -e ${pi}/lib/node_modules/@mariozechner/pi-coding-agent/node_modules/vitest
  test ! -e ${pi}/lib/node_modules/@mariozechner/pi-coding-agent/node_modules/shx
  ${pkgs.nodejs}/bin/node ${./pi-ftp.cjs} ${pi}/lib/node_modules/@mariozechner/pi-coding-agent
  touch "$out"
''
