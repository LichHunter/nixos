{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.dov.reverse-proxy.nginx;
  email = "susano@local.com";
  # configFile = pkgs.writeText "duckdns_config"
  #   ''
  #   example config file bla bla
  #   '';
in {
  options.dov.reverse-proxy.nginx = { enable = mkEnableOption "nginx config"; };

  config = mkIf cfg.enable {
    sops.secrets.duckdns-token = {
      owner = config.services.nginx.user;
      group = config.services.nginx.group;
    };

    # 1. Enable Nginx

    # 2. Enable Automatic Certificate Management (ACME)
    # NixOS uses acme.sh to handle Let's Encrypt certificates.
    security.acme = {
      acceptTerms = true;
      defaults.email = email;

      # Define the certificates you want to obtain.
      # We use the DNS-01 challenge for wildcard domains.
      certs = {
        # Certificate for *.susano-lab.duckdns.org
        "susano-lab.duckdns.org" = {
          domain = "*.susano-lab.duckdns.org";
          extraDomainNames = [ "susano-lab.duckdns.org" ];
          dnsProvider = "duckdns";
          # The credentialsFile points to the secret file we created.
          credentialsFile = config.sops.secrets.duckdns-token.path;
          group = config.services.nginx.group;
        };

        # Certificate for *.susano-tailscale.duckdns.org
        "susano-tailscale.duckdns.org" = {
          domain = "*.susano-tailscale.duckdns.org";
          extraDomainNames = [ "susano-tailscale.duckdns.org" ];
          dnsProvider = "duckdns";
          credentialsFile = config.sops.secrets.duckdns-token.path;
          group = config.services.nginx.group;
        };
      };
    };

    # 3. Define Nginx Reverse Proxy Configuration
    services.nginx = {
      enable = cfg.enable;

      # Use httpConfig to define 'map' blocks at the correct level.
      httpConfig = ''
        # Map for susano-lab.duckdns.org domains
        map $host $lab_proxy_pass {
          "immich.susano-lab.duckdns.org"     "http://192.168.1.57:2283";
          "jellyfin.susano-lab.duckdns.org"   "http://192.168.1.64:8096";
          "jellyseer.susano-lab.duckdns.org"  "http://192.168.1.68:5055";
          "nginx.susano-lab.duckdns.org"      "http://192.168.1.57:81";
          "portainer.susano-lab.duckdns.org"  "https://192.168.1.57:9443";
          "qbittorrent.susano-lab.duckdns.org" "http://192.168.1.57:8080";
          "radarr.susano-lab.duckdns.org"     "http://192.168.1.57:7878";
          "searxng.susano-lab.duckdns.org"    "http://192.168.1.82:8080";
          "sonarr.susano-lab.duckdns.org"     "http://192.168.1.57:8989";
          "susano-lab.duckdns.org"            "http://192.168.1.53:8006";
          default                             "http://127.0.0.1:8000"; # Optional: a default to avoid errors if no host matches
        }

        # Map for susano-tailscale.duckdns.org domains
        map $host $tailscale_proxy_pass {
          "immich.susano-tailscale.duckdns.org"  "http://192.168.1.57:2283";
          "searxng.susano-tailscale.duckdns.org" "http://192.168.1.82:8080";
          default                                "http://127.0.0.1:8000"; # Optional: a default
        }

        # Map for susano-traefik.duckdns.org domains
        map $host $traefik_proxy_pass {
          "immich.susano-traefik.duckdns.org"  "http://192.168.1.57:2283";
          default                                "http://127.0.0.1:8000"; # Optional: a default
        }
      '';

      virtualHosts = {

        # === Group for susano-lab.duckdns.org subdomains ===
        "susano-lab" = {
          serverName = "susano-lab.duckdns.org";
          serverAliases = [
            "test.susano-lab.duckdns.org"
            "immich.susano-lab.duckdns.org"
            "jellyfin.susano-lab.duckdns.org"
            "jellyseer.susano-lab.duckdns.org"
            "nginx.susano-lab.duckdns.org"
            "portainer.susano-lab.duckdns.org"
            "qbittorrent.susano-lab.duckdns.org"
            "radarr.susano-lab.duckdns.org"
            "searxng.susano-lab.duckdns.org"
            "sonarr.susano-lab.duckdns.org"
          ];
          useACMEHost = "susano-lab.duckdns.org";
          forceSSL = true;

          locations."/".extraConfig = ''
            # The map block is removed from here.
            # We now use the variable defined in httpConfig.
            proxy_pass $lab_proxy_pass;

            # Standard proxy headers for websockets and correct IP forwarding.
            proxy_http_version 1.1;
            proxy_set_header Upgrade $http_upgrade;
            proxy_set_header Connection "upgrade";
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
          '';
        };

        # === Group for susano-tailscale.duckdns.org subdomains ===
        "susano-tailscale" = {
          serverName = "susano-tailscale.duckdns.org";
          serverAliases = [
            "immich.susano-tailscale.duckdns.org"
            "searxng.susano-tailscale.duckdns.org"
          ];
          useACMEHost = "susano-tailscale.duckdns.org";
          forceSSL = true;

          locations."/".extraConfig = ''
            # Use the second variable defined in httpConfig.
            proxy_pass $tailscale_proxy_pass;

            proxy_http_version 1.1;
            proxy_set_header Upgrade $http_upgrade;
            proxy_set_header Connection "upgrade";
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
          '';
        };
      };
    };
  };
}
