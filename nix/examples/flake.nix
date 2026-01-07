{
  description = "Example CLAWDINATOR host flake";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    nix-clawdbot.url = "github:clawdbot/nix-clawdbot"; # latest upstream
    agenix.url = "github:ryantm/agenix";
    secrets = {
      url = "path:../../../nix/nix-secrets";
      flake = false;
    };
    clawdinators.url = "path:../..";
  };

  outputs = { self, nixpkgs, nix-clawdbot, agenix, secrets, clawdinators }:
    let
      system = "x86_64-linux";
    in {
      nixosConfigurations.clawdinator-1 = nixpkgs.lib.nixosSystem {
        inherit system;
        specialArgs = { inherit secrets; };
        modules = [
          ({ pkgs, ... }: { nixpkgs.overlays = [ clawdinators.overlays.default ]; })
          agenix.nixosModules.default
          clawdinators.nixosModules.clawdinator
          ./clawdinator-host.nix
        ];
      };
    };
}
