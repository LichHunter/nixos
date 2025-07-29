{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.dov.reverse-proxy.traefik;
  domain = "susano-nixos.duckdns.org";
  configFile = pkgs.writeText "duckdns-options"
    ''
    DUCKDNS_PROPAGATION_TIMEOUT=120
    '';
in {
  options.dov.reverse-proxy.traefik = { enable = mkEnableOption "traefik config"; };

  config = mkIf cfg.enable {
    networking.firewall.allowedTCPPorts = [ 80 443 53 ];

    sops.secrets.duckdns-token = {
      owner = "traefik";
      group = config.services.traefik.group;
    };

    services.traefik = {
      enable = true;

      # Load the DuckDNS token as an environment variable for Traefik.
      environmentFiles = [ config.sops.secrets.duckdns-token.path configFile ];

      # Static configuration (traefik.yml) - defines entrypoints and certificate resolvers.
      staticConfigOptions = {
        # -- EntryPoints: Where Traefik listens for traffic --
        entryPoints = {
          # Unsecured HTTP on port 80, mainly for redirection
          web = {
            address = ":80";
            # Redirect all traffic from this entrypoint to the 'websecure' (HTTPS) entrypoint
            http.redirections.entryPoint = {
              to = "websecure";
              scheme = "https";
              permanent = true;
            };
          };
          # Secured HTTPS on port 443
          websecure = {
            address = ":443";
          };
        };

        # -- Certificate Resolver: How Traefik gets SSL certs --
        certificatesResolvers = {
          # We'll name our resolver 'duckdns'
          duckdns = {
            acme = {
              email = "susano@local.com";
              storage = "/var/lib/traefik/acme.json"; # Where Traefik stores certs

              dnsChallenge = {
                provider = "duckdns";
                #disablePropagationCheck = true;
              };
            };
          };
        };

        # Optional but recommended: Enable the Traefik Dashboard
        api.dashboard = true;
      };

      # Dynamic configuration - defines the actual routers and services.
      dynamicConfigOptions = {
        http = {
          routers = {
            authelia-router = mkIf config.dov.auth.authelia.enable {
              rule = "Host(`auth.${domain}`)";
              entryPoints = [ "websecure" ];
              service = "authelia-service"; # Points to the Authelia service below
              tls.certResolver = "duckdns";
            };

            dashboard-router = {
              rule = "Host(`traefik.${domain}`)";
              entryPoints = [ "websecure" ];
              service = "api@internal";
              tls = {
                certResolver = "duckdns";
                domains = [
                  {
                    main = "susano-nixos.duckdns.org";
                    sans = [
                      "*.susano-nixos.duckdns.org"
                    ];
                  }
                ];
              };
            };

            copyparty = mkIf config.dov.file-server.copyparty.enable {
              rule = "Host(`copyparty.${domain}`)";
              entryPoints = [ "websecure" ];
              service = "copyparty-service";
              tls.certResolver = "duckdns";
            };

            searxng = mkIf config.dov.searxng.enable {
              rule = "Host(`searxng.${domain}`)";
              entryPoints = [ "websecure" ];
              service = "serxng-service";
              tls.certResolver = "duckdns";
            };
          };

          services = {
            authelia-service = mkIf config.dov.auth.authelia.enable {
              loadBalancer.servers = [
                # Points to the Authelia instance defined in authelia.nix
                { url = "http://127.0.0.1:9091"; }
              ];
            };

            copyparty-service = mkIf config.dov.file-server.copyparty.enable {
              loadBalancer.servers = [
                # The backend URL for Immich
                { url = "http://susano:3923"; }
              ];
            };

            serxng-service = mkIf config.dov.searxng.enable {
              loadBalancer.servers = [
                # The backend URL for Immich
                { url = "http://susano:8888"; }
              ];
            };
          };

          middlewares = {
            # --- Middleware for dashboard authentication (optional) ---
            auth = {
              # Run `nix-shell -p apacheHttpdTools --run "htpasswd -nb your-user your-password"`
              # to generate the user:password hash.
              basicAuth.users = [
                "your-user:$apr1$....some-hash-here...."
              ];
            };

            authelia-mw = mkIf config.dov.auth.authelia.enable {
              forwardAuth = {
                # This address MUST match the Authelia service URL
                address = "http://127.0.0.1:9091/api/verify?rd=https%3A%2F%2Fauth.${domain}%2F";
                trustForwardHeader = true;
                authResponseHeaders = [
                  "Remote-User"
                  "Remote-Groups"
                  "Remote-Name"
                  "Remote-Email"
                ];
              };
            };
          };
        };
      };
    };
  };
}
