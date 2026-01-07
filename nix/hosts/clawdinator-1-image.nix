{ ... }:
{
  networking.hostName = "clawdinator-1";
  time.timeZone = "UTC";
  system.stateVersion = "26.05";

  boot.loader.systemd-boot.enable = true;
  boot.loader.grub.enable = false;
  boot.loader.efi.canTouchEfiVariables = false;
  boot.loader.efi.efiSysMountPoint = "/boot";

  networking.useDHCP = true;
  services.openssh.enable = true;
  networking.firewall.enable = false;

  users.users.root.openssh.authorizedKeys.keys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOLItFT3SVm5r7gELrfRRJxh6V2sf/BIx7HKXt6oVWpB"
  ];
}
