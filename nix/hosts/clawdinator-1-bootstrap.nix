{ config, ... }:
{
  networking.hostName = "clawdinator-1";
  time.timeZone = "UTC";
  system.stateVersion = "26.05";

  boot.loader.systemd-boot.enable = true;
  boot.loader.grub.enable = false;
  boot.loader.efi.canTouchEfiVariables = false;
  boot.loader.efi.efiSysMountPoint = "/boot";

  disko.devices = {
    disk.main = {
      type = "disk";
      device = "/dev/disk/by-path/pci-0000:06:00.0-scsi-0:0:0:0";
      content = {
        type = "gpt";
        partitions = {
          boot = {
            size = "512M";
            type = "EF00";
            content = {
              type = "filesystem";
              format = "vfat";
              mountpoint = "/boot";
            };
          };
          root = {
            size = "100%";
            content = {
              type = "filesystem";
              format = "ext4";
              mountpoint = "/";
            };
          };
        };
      };
    };
  };

  boot.kernelParams = [ "net.ifnames=0" "biosdevname=0" ];
  networking.useDHCP = false;
  networking.useNetworkd = false;
  systemd.network.enable = false;
  networking.interfaces.eth0.useDHCP = true;

  services.openssh.enable = true;
  networking.firewall.enable = false;
  users.users.root.openssh.authorizedKeys.keys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOLItFT3SVm5r7gELrfRRJxh6V2sf/BIx7HKXt6oVWpB"
  ];
}
