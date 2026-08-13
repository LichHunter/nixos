{
  config,
  lib,
  pkgs,
  ...
}:

with lib;

let
  cfg = config.dov.development.qoder;
  qoder = pkgs.callPackage ./package.nix {
    inherit (cfg)
      version
      url
      hash
      extraFlags
      ;
  };
in
{
  options.dov.development.qoder = {
    enable = mkEnableOption "Qoder IDE (unfree, repackaged from the upstream .deb)";

    version = mkOption {
      type = types.str;
      default = "1.19.2";
      description = ''
        Label only — upstream publishes a rolling "latest" URL, so this is
        just what the store path is called. Bump it together with `hash`.
      '';
    };

    url = mkOption {
      type = types.str;
      default = "https://download.qoder.com/release/latest/qoder_amd64.deb";
      description = "Upstream .deb to repackage.";
    };

    hash = mkOption {
      type = types.str;
      default = "";
      example = "sha256-0000000000000000000000000000000000000000000=";
      description = ''
        SRI hash of the .deb. Refresh whenever upstream ships a new build:
          nix store prefetch-file --json <url> | jq -r .hash
      '';
    };

    extraFlags = mkOption {
      type = types.listOf types.str;
      default = [ ];
      example = [ "--disable-gpu-sandbox" ];
      description = "Extra Electron/Chromium flags appended to the wrapper.";
    };

    keyring = mkOption {
      type = types.bool;
      default = true;
      description = ''
        Enable gnome-keyring. Qoder is wrapped with
        --password-store=gnome-libsecret; without a running secret service
        the sign-in token is lost on every restart.
      '';
    };
  };

  config = mkIf cfg.enable (mkMerge [
    {
      assertions = [
        {
          assertion = cfg.hash != "";
          message = ''
            dov.development.qoder.hash is empty. Prefetch the .deb first:
              nix store prefetch-file --json ${cfg.url} | jq -r .hash
          '';
        }
      ];

      environment.systemPackages = [ qoder ];
    }

    (mkIf cfg.keyring {
      services.gnome.gnome-keyring.enable = true;

      # gnome-keyring enables gcr-ssh-agent by default, which asserts against
      # programs.ssh.startAgent from dov.yubikey. We only want the secret
      # service here — SSH keys stay with the OpenSSH agent.
      services.gnome.gcr-ssh-agent.enable = false;
    })
  ]);
}
