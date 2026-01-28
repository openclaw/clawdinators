{ secrets, ... }:
{
  age.secrets."moltinator-github-app.pem".file =
    "/var/lib/clawd/nix-secrets/moltinator-github-app.pem.age";
  age.secrets."moltinator-anthropic-api-key".file =
    "/var/lib/clawd/nix-secrets/moltinator-anthropic-api-key.age";
  age.secrets."moltinator-openai-api-key-peter-2".file =
    "/var/lib/clawd/nix-secrets/moltinator-openai-api-key-peter-2.age";
  age.secrets."moltinator-discord-token".file =
    "/var/lib/clawd/nix-secrets/moltinator-discord-token.age";

  services.openssh.enable = true;
  networking.firewall.allowedTCPPorts = [ 22 18789 ];

  services.clawdinator = {
    enable = true;
    instanceName = "CLAWDINATOR-1";
    memoryDir = "/memory";
    memoryEfs = {
      enable = true;
      fileSystemId = "fs-0e7920726c2965a88";
      region = "eu-central-1";
      mountPoint = "/memory";
    };

    # Raw Moltbot config JSON (schema is upstream). Extend as needed.
    config = {
      gateway = {
        mode = "local";
        bind = "loopback";
        auth.token = "<GATEWAY_TOKEN>";
      };
      agents.defaults.workspace = "/var/lib/clawd/workspace";
      messages.queue.byChannel = {
        discord = "queue";
        telegram = "interrupt";
        whatsapp = "interrupt";
      };
      plugins.slots.memory = "none";
      agents.list = [
        {
          id = "main";
          default = true;
          identity.name = "CLAWDINATOR-1";
        }
      ];
      skills.allowBundled = [ "github" "clawdhub" ];
      channels = {
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
    };

    anthropicApiKeyFile = "/run/agenix/moltinator-anthropic-api-key";
    openaiApiKeyFile = "/run/agenix/moltinator-openai-api-key-peter-2";
    discordTokenFile = "/run/agenix/moltinator-discord-token";

    githubApp = {
      enable = true;
      appId = "123456";
      installationId = "12345678";
      privateKeyFile = "/run/agenix/moltinator-github-app.pem";
      schedule = "hourly";
    };

    selfUpdate.enable = true;
    selfUpdate.flakePath = "/var/lib/clawd/repos/moltinators";
    selfUpdate.flakeHost = "clawdinator-1";
  };
}
