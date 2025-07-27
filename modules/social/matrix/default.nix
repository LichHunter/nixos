{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.dov.social.matrix;
  fqdn = "matrix.susano-tailscale.duckdns.org";
  baseUrl = "https://${fqdn}";
  clientConfig."m.homeserver".base_url = baseUrl;
  serverConfig."m.server" = "${fqdn}:443";
  mkWellKnown = data: ''
    default_type application/json;
    add_header Access-Control-Allow-Origin *;
    return 200 '${builtins.toJSON data}';
  '';
in {
  options.dov.social.matrix = {
    enable = mkEnableOption "docker config";
  };

  config = mkIf cfg.enable {
    sops.secrets.matrix_secret = {
      owner = "matrix-synapse";
      group = "matrix-synapse";
    };

    networking.firewall.allowedTCPPorts = [ 80 443 ];

    services.postgresql.enable = true;

    services.matrix-synapse = {
      enable = true;
      settings = {
        server_name = "susano-tailscale";
        # The public base URL value must match the `base_url` value set in `clientConfig` above.
        # The default value here is based on `server_name`, so if your `server_name` is different
        # from the value of `fqdn` above, you will likely run into some mismatched domain names
        # in client applications.
        public_baseurl = baseUrl;
        listeners = [{
          port = 8008;
          bind_addresses = [ "::1" ];
          type = "http";
          tls = false;
          x_forwarded = true;
          resources = [{
            names = [ "client" "federation" ];
            compress = true;
          }];
        }];
      };

      extraConfigFiles = [ "/run/secrets/matrix_secret" ];
    };
  };
}
