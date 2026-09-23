let
  lock = builtins.fromJSON (builtins.readFile ../../flake.lock);
  locked = lock.nodes.${lock.nodes.nix-openclaw.inputs.nixpkgs}.locked;
  pkgs = import (builtins.fetchTarball {
    url = "https://github.com/NixOS/nixpkgs/archive/${locked.rev}.tar.gz";
    sha256 = locked.narHash;
  }) {};
in
pkgs.callPackage ../tools/pi-coding-agent.nix {}
