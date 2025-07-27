{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.dov.reverse-proxy.traefik;
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
              # Use the DNS-01 challenge with the DuckDNS provider
              dnsChallenge = {
                provider = "duckdns";
                disablePropagationCheck = true;
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
            # --- Router for the Traefik dashboard (optional) ---
            dashboard-router = {
              rule = "Host(`traefik.susano-test.duckdns.org`)"; # Example: A local-only subdomain
              entryPoints = [ "websecure" ];
              service = "api@internal"; # Special service for the dashboard
              tls.certResolver = "duckdns";
            };

            immich-router = {
              rule = "Host(`immich.susano-test.duckdns.org`)"; # 1. The new domain
              entryPoints = [ "websecure" ];                        # 2. Listen on HTTPS
              service = "immich-service";                           # 3. Link to the new Immich service
              tls.certResolver = "duckdns";                         # 4. Use the same SSL resolver
            };
          };

          services = {
            immich-service = {
              loadBalancer.servers = [
                # The backend URL for Immich
                { url = "http://192.168.1.57:2283"; }
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
          };
        };
      };
    };
  };

}
