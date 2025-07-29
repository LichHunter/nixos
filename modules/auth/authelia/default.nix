{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.dov.auth.authelia;
  domain = "susano-lab.duckdns.org";
  autheliaUser = config.services.authelia.instances.main.user;
  redis = config.services.redis.servers."";
in {
  options.dov.auth.authelia = { enable = mkEnableOption "authelia config"; };

  config = mkIf cfg.enable {

    # 1. Sops secrets for Authelia
    sops.secrets = {
      "authelia/jwt_secret" = {
        owner = autheliaUser;
        group = autheliaUser;
        mode = "0400";
      };
      "authelia/session_secret" = {
        owner = autheliaUser;
        group = autheliaUser;
        mode = "0400";
      };
      "authelia/storage_encryption_key" = {
        owner = autheliaUser;
        group = autheliaUser;
        mode = "0400";
      };
      "authelia/oidc_jwk" = {
        owner = autheliaUser;
        group = autheliaUser;
        mode = "0400";
      };
    };

    users.users.authelia-main.extraGroups = [ "redis" ];
    services.redis = {
      vmOverCommit = true;
      servers."" = {
        enable = true;
        databases = 16;
        port = 0;
      };
    };

    # --- Authelia Service Configuration ---
    services.authelia.instances.main = {
      enable = true;
      secrets = {
        jwtSecretFile = config.sops.secrets."authelia/jwt_secret".path;
        sessionSecretFile = config.sops.secrets."authelia/session_secret".path;
        storageEncryptionKeyFile =
          config.sops.secrets."authelia/storage_encryption_key".path;
        oidcIssuerPrivateKeyFile = config.sops.secrets."authelia/oidc_jwk".path;
      };

      settings = {
        log = { level = "info"; };
        default_2fa_method = "totp";
        session = {
          cookies = [{
            inherit domain;
            authelia_url = "https://auth.${domain}";
            default_redirection_url = "https://homepage.${domain}";
          }];
          redis = {
            host = redis.unixSocket;
            port = 0;
            database_index = 0;
          };
        };

        authentication_backend = {
          file = {
            path = pkgs.writeText "authelia/users_database.yml" ''
              users:
                admin:
                  displayname: "Administrator"
                  password: "$argon2id$v=19$m=65536,t=3,p=4$B7hBxdT+R4WOS02iZb3HOA$6Epdb0B8JuwkFXbzV16s3gGcgnzviXaRMICNbZbBaFc"
                  email: "admin@${domain}"
                  groups:
                    - admins
                    - dev
            '';
            password.algorithm = "argon2id"; # Modern and secure hashing
          };
        };

        # authentication_backend.ldap = {
        #   url = "ldaps://127.0.0.1:636";
        #   skip_verify = true;
        #   start_tls = false;

        #   base_dn = "dc=susano-nixos,dc=duckdns,dc=org";
        #   user = "cn=authelia,ou=services,dc=susano-nixos,dc=duckdns,dc=org";

        #   # --- User Schema
        #   username_attribute = "uid";
        #   users_filter = "(&({username_attribute}={input})(objectClass=inetOrgPerson))";
        #   mail_attribute = "mail";
        #   display_name_attribute = "displayName";

        #   # --- Group Schema ---
        #   groups_filter = "(&(member={dn})(objectClass=groupOfNames))";
        #   group_name_attribute = "cn";
        # };

        # Access control rules remain the same, but now reference LDAP groups.
        access_control = {
          default_policy = "deny";
          rules = [
            {
              domain = [ "immich.${domain}" ];
              policy = "two_factor";
              # 'admins' and 'dev' are now groups from your LDAP directory.
              subject = [ "group:admins" ];
            }
            {
              domain = [ "searxng.${domain}" ];
              policy = "one_factor";
              subject = [ "group:admins" "group:dev" ];
            }
          ];
        };

        # Other settings remain unchanged...
        notifier.filesystem = {
          filename = "/var/lib/authelia-main/notifications.txt";
        };

        storage.local = { path = "/var/lib/authelia-main/db.sqlite3"; };

        identity_providers.oidc = {
          jwks = [{
            # This is a standard key type for OIDC
            use = "sig";
            algorithm = "RS256";
            key = config.sops.secrets."authelia/oidc_jwk".path;
          }];
          clients = [{
            authorization_policy = "one_factor";
            client_id = "immich";
            client_secret =
              "$pbkdf2-sha512$310000$wPpdmhrPqd.dU.tcLTh9nQ$du11GENjjxaXf5njeqnhpVgr8O9fCISulobjRStCsYJzY6i3aaOyiloRJHKDh.CC.4n1QVqsP.ty9Lo8UH3XvA";
            redirect_uris = [
              "https://immich.${domain}/auth/login"
              "https://immich.${domain}/user-settings"
              "app.immich:///oauth-callback"
            ];
            scopes = [ "openid" "profile" "email" ];
            userinfo_signed_response_alg = "none";
          }];
        };
      };
    };
  };
}
