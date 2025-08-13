{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.dov.gitlab;
  owner = config.services.gitlab.user;
  group = config.services.gitlab.group;
  domain = "susano-lab.duckdns.org";
  gitlabDomain = "gitlab.${domain}";
in {
  options.dov.gitlab = { enable = mkEnableOption "gitlab config"; };

  config = mkIf cfg.enable {
    sops.secrets = {
      "gitlab/databasePassword" = { inherit owner group; };
      "gitlab/initialRootPassword" = { inherit owner group; };
      "gitlab/secret" = { inherit owner group; };
      "gitlab/otp" = { inherit owner group; };
      "gitlab/db" = { inherit owner group; };
      "gitlab/jwt" = { inherit owner group; };
      "gitlab/activeRecordPrimaryKey" = { inherit owner group; };
      "gitlab/activeRecordDeterministicKey" = { inherit owner group; };
      "gitlab/activeRecordSalt" = { inherit owner group; };
      "gitlab/oauth/secret" = { inherit owner group; };
    };

    services = {
      gitlab = {
        enable = cfg.enable;
        host = "gitlab.susano-lab.duckdns.org"; # Must be your external domain
        port = 443; # External port users access
        https = true; # Enable since external access is HTTPS

        databasePasswordFile =
          config.sops.secrets."gitlab/databasePassword".path;
        initialRootPasswordFile =
          config.sops.secrets."gitlab/initialRootPassword".path;
        secrets = {
          secretFile = config.sops.secrets."gitlab/secret".path;
          otpFile = config.sops.secrets."gitlab/otp".path;
          dbFile = config.sops.secrets."gitlab/db".path;
          jwsFile = config.sops.secrets."gitlab/jwt".path;
          activeRecordPrimaryKeyFile =
            config.sops.secrets."gitlab/activeRecordPrimaryKey".path;
          activeRecordDeterministicKeyFile =
            config.sops.secrets."gitlab/activeRecordDeterministicKey".path;
          activeRecordSaltFile =
            config.sops.secrets."gitlab/activeRecordSalt".path;
        };
        extraConfig = {
          # CRITICAL: External URL must match what users type in browser
          external_url = "https://gitlab.susano-lab.duckdns.org";
          gitlab_rails = {
            trusted_proxies = [ "127.0.0.1" "::1" "192.168.1.0/24" ];
            internal_api_url = "https://gitlab.susano-lab.duckdns.org";
          };
          nginx.enable = false; # Disable bundled nginx

          # OmniAuth configuration (direct, not under gitlab_rails)
          omniauth = {
            enabled = true;
            allow_single_sign_on = [ "openid_connect" ];
            sync_email_from_provider = "openid_connect";
            sync_profile_from_provider = [ "openid_connect" ];
            sync_profile_attributes = [ "email" ];
            # Enable if want to auto login with sso
            #auto_sign_in_with_provider = "openid_connect";
            block_auto_created_users = true;
            auto_link_user = [ "openid_connect" ];

            providers = [{
              name = "openid_connect";
              label = "My Company OIDC Login";
              args = {
                name = "openid_connect";
                scope = [ "openid" "profile" "email" ];
                response_type = "code";
                issuer = "https://authentik.${domain}/application/o/gitlab/";
                discovery = true;
                client_auth_method = "query";
                uid_field = "preferred_username";
                send_scope_to_token_endpoint = "true";
                pkce = true;
                client_options = {
                  # For production, use secret management with _secret attribute
                  identifier = "QoAaWAv7TSaRFeLahVLs4mugeXpaJ0WWYIUIXhWk";
                  secret._secret =
                    config.sops.secrets."gitlab/oauth/secret".path;
                  redirect_uri =
                    "https://gitlab.${domain}/users/auth/openid_connect/callback";
                };
              };
            }];
          };
        };
      };
    };

    services.nginx = {
      enable = cfg.enable;
      recommendedProxySettings = true;

      virtualHosts = {
        # Default server - accepts any hostname/IP
        localhost = {
          locations."/" = {
            proxyPass = "http://unix:/run/gitlab/gitlab-workhorse.socket";
          };
        };
      };
    };

    networking.firewall = {
      enable = cfg.enable;
      allowedTCPPorts = [ 80 443 ]; # HTTP and HTTPS
    };

    services.openssh.enable = cfg.enable;

    systemd.services.gitlab-backup.environment.BACKUP = "dump";
  };

}
