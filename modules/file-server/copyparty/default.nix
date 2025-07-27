{ config, lib, pkgs, inputs, ... }:

with lib;

let cfg = config.dov.file-server.copyparty;
in {
  options.dov.file-server.copyparty = {
    enable = mkEnableOption "copyparty config";
  };

  config = mkIf cfg.enable {
    networking.firewall.allowedTCPPorts = config.services.copyparty.settings.p;

    sops.secrets."copyparty/admin_password" = {
      owner = "copyparty";
      group = "copyparty";
    };
    sops.secrets."copyparty/alex_password" = {
      owner = "copyparty";
      group = "copyparty";
    };

    # add the copyparty overlay to expose the package to the module
    nixpkgs.overlays = [ inputs.copyparty.overlays.default ];
    # (optional) install the package globally
    environment.systemPackages = [ pkgs.copyparty ];
    # configure the copyparty module
    services.copyparty = {
      enable = cfg.enable;
      settings = {
        p = [ 3923 ];
        e2dsa = true; # enable file indexing and filesystem scanning
        e2ts = true; # and enable multimedia indexing
        z = true; # and zeroconf
        qr = true; # and qrcode (you can comma-separate arguments)
      };
      accounts = {
        admin.passwordFile = "/run/secrets/copyparty/admin_password";
        alex.passwordFile = "/run/secrets/copyparty/alex_password";
      };

      # create a volume
      volumes = {
        "/" = {
          # share the contents of "/MEDIA"
          path = "/";
          # see `copyparty --help-accounts` for available options
          access = {
            # everyone gets read-access, but
            r = [ "admin" "alex" ];
            # users "ed" and "k" get read-write
            rw = [ "admin" ];
          };
          # see `copyparty --help-flags` for available options
          flags = {
            # "fk" enables filekeys (necessary for upget permission) (4 chars long)
            fk = 4;
            # scan for new files every 60sec
            scan = 60;
            # volflag "e2d" enables the uploads database
            e2d = true;
            # "d2t" disables multimedia parsers (in case the uploads are malicious)
            d2t = true;
            # skips hashing file contents if path matches *.iso
            nohash = ".iso$";
          };
        };
        "/MEDIA" = {
          # share the contents of "/MEDIA"
          path = "/MEDIA";
          # see `copyparty --help-accounts` for available options
          access = {
            # everyone gets read-access, but
            r = "alex";
            # users "ed" and "k" get read-write
            rw = [ "admin" "alex" ];
          };
          # see `copyparty --help-flags` for available options
          flags = {
            # "fk" enables filekeys (necessary for upget permission) (4 chars long)
            fk = 4;
            # scan for new files every 60sec
            scan = 60;
            # volflag "e2d" enables the uploads database
            e2d = true;
            # "d2t" disables multimedia parsers (in case the uploads are malicious)
            d2t = true;
            # skips hashing file contents if path matches *.iso
            nohash = ".iso$";
          };
        };
      };
    };
  };

}
