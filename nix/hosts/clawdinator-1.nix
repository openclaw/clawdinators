{ config, lib, pkgs, secrets, ... }:
{
  imports = [ ../modules/clawdinator.nix ];

  networking.hostName = "clawdinator-1";
  networking.useDHCP = false;
  networking.useNetworkd = true;
  systemd.network.enable = true;
  systemd.network.networks."10-wan" = {
    matchConfig.Type = "ether";
    networkConfig.DHCP = "yes";
  };
  time.timeZone = "UTC";
  system.stateVersion = "26.05";

  boot.loader.systemd-boot.enable = true;
  boot.loader.grub.enable = false;
  boot.loader.efi.canTouchEfiVariables = false;
  boot.loader.efi.efiSysMountPoint = "/boot";

  fileSystems."/" = {
    device = "/dev/disk/by-partlabel/disk-main-root";
    fsType = "ext4";
  };

  fileSystems."/boot" = {
    device = "/dev/disk/by-partlabel/disk-main-boot";
    fsType = "vfat";
  };

  nix.package = pkgs.nixVersions.stable;
  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  services.openssh.enable = true;
  networking.firewall.allowedTCPPorts = [ 22 18789 ];
  users.users.root.openssh.authorizedKeys.keys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOLItFT3SVm5r7gELrfRRJxh6V2sf/BIx7HKXt6oVWpB"
  ];

  age.identityPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];
  age.secrets."clawdinator-github-app.pem" = {
    file = "/var/lib/clawd/nix-secrets/clawdinator-github-app.pem.age";
    owner = "clawdinator";
    group = "clawdinator";
  };
  age.secrets."clawdis-anthropic-api-key" = {
    file = "/var/lib/clawd/nix-secrets/clawdis-anthropic-api-key.age";
    owner = "clawdinator";
    group = "clawdinator";
  };
  age.secrets."clawdinator-discord-token" = {
    file = "/var/lib/clawd/nix-secrets/clawdinator-discord-token.age";
    owner = "clawdinator";
    group = "clawdinator";
  };

  services.clawdinator = {
    enable = true;
    instanceName = "CLAWDINATOR-1";
    memoryDir = "/var/lib/clawd/memory";

    config = {
      gateway.mode = "server";
      agent.workspace = "/var/lib/clawd/workspace";
      agent.maxConcurrent = 4;
      routing.queue = {
        mode = "interrupt";
        bySurface = {
          discord = "queue";
          telegram = "interrupt";
          whatsapp = "interrupt";
          webchat = "queue";
        };
      };
      identity.name = "CLAWDINATOR-1";
      skills.allowBundled = [ "github" "clawdhub" ];
      discord = {
        enabled = true;
        dm.enabled = false;
        guilds = {
          "<GUILD_ID>" = {
            requireMention = true;
            channels = {
              "<CHANNEL_NAME>" = { allow = true; requireMention = true; };
            };
          };
        };
      };
    };

    anthropicApiKeyFile = "/run/agenix/clawdis-anthropic-api-key";
    discordTokenFile = "/run/agenix/clawdinator-discord-token";

    githubApp = {
      enable = true;
      appId = "2607181";
      installationId = "102951645";
      privateKeyFile = "/run/agenix/clawdinator-github-app.pem";
      schedule = "hourly";
    };

    selfUpdate.enable = true;
    selfUpdate.flakePath = "/var/lib/clawd/repo";
    selfUpdate.flakeHost = "clawdinator-1";
  };
}
