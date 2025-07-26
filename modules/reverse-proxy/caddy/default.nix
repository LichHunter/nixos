{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.dov.reverse-proxy.caddy;
  caddyWithDuckDNS = pkgs.caddy.withPlugins {
    plugins = [
      "github.com/caddy-dns/duckdns@v0.5.0"
    ];
    # Replace with the hash NixOS provides on the first build attempt.
    hash = "sha256-83ETc9K4T13Ws8gVOYwLarhuCA48Drs/i3rVLBMHyrc=";
  };
  email = "susano@local.com";
in {
  options.dov.reverse-proxy.caddy = { enable = mkEnableOption "caddy config"; };

  config = mkIf cfg.enable {
    sops.secrets.duckdns-token = {
      owner = config.services.caddy.user;
      group = config.services.caddy.group;
    };

    services.caddy = {
      enable = cfg.enable;
      package = caddyWithDuckDNS;

      environmentFile = config.sops.secrets.duckdns-token.path;

      # Add a global options block.
      # Let's Encrypt will use this email to send you important notices.
      globalConfig = ''
        email ${email}
      '';

      virtualHosts."test.susano-lab.duckdns.org" = {
        extraConfig = ''
          # Reverse proxy to your Immich instance.
          reverse_proxy http://192.168.1.57:2283 {
            # Send correct headers to the backend service.
            header_up Host {host}
            header_up X-Real-IP {remote_ip}
            header_up X-Forwarded-For {remote_ip}
            header_up X-Forwarded-Proto {scheme}

            # Recommended for large file uploads in Immich.
            transport http {
              read_buffer 1m
            }
          }

          # Configure automatic HTTPS with the DuckDNS provider.
          tls {
            dns duckdns {env.DUCKDNS_TOKEN}

            propagation_timeout -1
          }
        '';
      };
    };
  };
}
