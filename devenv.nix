{ pkgs, ... }:
{
  packages = [
    pkgs.hcloud
    pkgs.nixos-generators
    pkgs.zstd
    pkgs.curl
    pkgs.awscli2
  ];
}
