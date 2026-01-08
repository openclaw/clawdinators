{ modulesPath, config, ... }:
let
  agenix = builtins.fetchTarball "https://github.com/ryantm/agenix/archive/refs/tags/0.15.0.tar.gz";
in {
  imports = [
    (modulesPath + "/virtualisation/ec2-data.nix")
    (modulesPath + "/virtualisation/amazon-init.nix")
    "${agenix}/modules/age.nix"
    ../modules/clawdinator.nix
    ./clawdinator-1-common.nix
  ];

  networking.hostName = "clawdinator-1";
  time.timeZone = "UTC";
  system.stateVersion = "26.05";

  boot.initrd.availableKernelModules = [ "nvme" ];
  boot.initrd.kernelModules = [ "xen-blkfront" ];
  boot.extraModulePackages = [ config.boot.kernelPackages.ena ];

  boot.loader.systemd-boot.enable = false;
  boot.loader.grub.enable = true;
  boot.loader.grub.device = "/dev/vda";

  networking.useDHCP = true;
  services.openssh.enable = true;
  services.openssh.settings.PermitRootLogin = "prohibit-password";
  environment.etc."agenix/keys/clawdinator.agekey" = {
    source = ../keys/clawdinator.agekey;
    mode = "0400";
  };
  users.users.root.openssh.authorizedKeys.keys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOLItFT3SVm5r7gELrfRRJxh6V2sf/BIx7HKXt6oVWpB"
  ];

  clawdinator.secretsPath = ../age-secrets;
}
