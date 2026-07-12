{ modulesPath, config, pkgs, ... }: {
  imports = [
    (modulesPath + "/virtualisation/ec2-data.nix")
    (modulesPath + "/virtualisation/amazon-init.nix")
    ../modules/clawdinator.nix
    ./clawdinator-common.nix
  ];

  networking.hostName = "clawdinator-1";
  time.timeZone = "UTC";
  system.stateVersion = "26.05";

  clawdinator.bootstrapPrefix = "bootstrap/clawdinator-1";
  clawdinator.discordTokenSecret = "clawdinator-discord-token-1";

  boot.initrd.availableKernelModules = [ "nvme" ];
  boot.initrd.kernelModules = [ "xen-blkfront" ];
  boot.extraModulePackages = [ config.boot.kernelPackages.ena ];

  boot.loader.systemd-boot.enable = false;
  boot.loader.grub.enable = true;
  boot.loader.grub.device = "/dev/vda";

  networking.useDHCP = true;
  services.openssh.enable = true;
  services.openssh.settings.PermitRootLogin = "prohibit-password";
  users.users.root.openssh.authorizedKeys.keys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOLItFT3SVm5r7gELrfRRJxh6V2sf/BIx7HKXt6oVWpB"
  ];

  fileSystems."/" = {
    device = "/dev/disk/by-label/nixos";
    fsType = "ext4";
  };

  systemd.services.fetch-ec2-metadata = {
    description = "Fetch EC2 metadata";
    wantedBy = [ "multi-user.target" ];
    wants = [ "network-online.target" ];
    after = [ "network-online.target" ];
    path = [ pkgs.curl ];
    serviceConfig = {
      Type = "oneshot";
      StandardOutput = "journal+console";
      ExecStart = "${pkgs.bash}/bin/bash ${../../scripts/fetch-ec2-metadata.sh}";
    };
  };

  systemd.services.amazon-init.after = [ "fetch-ec2-metadata.service" ];
  systemd.services.amazon-init.wants = [ "fetch-ec2-metadata.service" ];
}
