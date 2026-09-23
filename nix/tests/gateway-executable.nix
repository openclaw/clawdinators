let
  lock = builtins.fromJSON (builtins.readFile ../../flake.lock);
  locked = lock.nodes.${lock.nodes.nix-openclaw.inputs.nixpkgs}.locked;
  pkgs = import (builtins.fetchTarball {
    url = "https://github.com/NixOS/nixpkgs/archive/${locked.rev}.tar.gz";
    sha256 = locked.narHash;
  }) {};
  inherit (pkgs) lib;

  gateway = program: (pkgs.writeShellScriptBin program ''
    set -eu
    test "$#" -eq 3
    test "$1" = gateway
    test "$2" = --port
    test "$3" = 19234
    test "''${DISCORD_BOT_TOKEN:-}" = "''${EXPECTED_TOKEN:-}"
  '').overrideAttrs (_: {
    name = "gateway-fixture-${program}";
    meta.mainProgram = program;
  });

  command = package: tokenFile:
    (import "${pkgs.path}/nixos/lib/eval-config.nix" {
      inherit pkgs;
      system = pkgs.stdenv.hostPlatform.system;
      modules = [
        ../modules/clawdinator.nix
        {
          options.services.openclaw-gateway = lib.mkOption {
            type = lib.types.attrsOf lib.types.anything;
          };
          config.services.clawdinator = {
            enable = true;
            inherit package;
            gatewayPort = 19234;
            discordTokenFile = tokenFile;
          };
        }
      ];
    }).config.services.openclaw-gateway.execStart;

  token = pkgs.writeText "gateway-test-token" "synthetic-test-token\n";
in
pkgs.runCommand "clawdinator-gateway-executable-test" {} (
  lib.concatMapStringsSep "\n" (program: ''
    ${command (gateway program) null}
    EXPECTED_TOKEN=synthetic-test-token ${command (gateway program) "${token}"}
    echo "PASS: ${program}, direct and token wrapper"
  '') [ "openclaw" "custom-gateway" ]
  + ''
    touch "$out"
  ''
)
