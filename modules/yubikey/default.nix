{
  config,
  lib,
  pkgs,
  ...
}:

with lib;

let
  cfg = config.dov.yubikey;
in {
  options.dov.yubikey = {
    enable = mkEnableOption "YubiKey integration (PAM U2F + SSH agent)";

    pamControl = mkOption {
      type = types.enum [ "sufficient" "required" ];
      default = "sufficient";
      description = ''
        PAM control flag for U2F authentication.
        - "sufficient": touch YubiKey OR type password (default).
          Can't lock yourself out — if the key is missing or not
          enrolled, the normal password prompt follows.
        - "required": touch YubiKey AND type password (true 2FA).
      '';
    };

    pamServices = mkOption {
      type = types.listOf types.str;
      default = [ "login" "sudo" ];
      description = ''
        PAM services to enable U2F for. Scoped per-service rather
        than globally so that e.g. sshd is not affected.
      '';
    };

    authFile = mkOption {
      type = types.nullOr types.path;
      default = null;
      description = ''
        Central U2F authfile path. When null, uses the default
        per-user location (~/.config/Yubico/u2f_keys). Set to a
        nix-store path for a central, non-user-writable mapping.

        Generate mappings with:
          pamu2fcfg -u &lt;username&gt;
      '';
    };
  };

  config = mkIf cfg.enable (mkMerge [
    {
      # --- Shared infrastructure: smart card daemon + device access ---
      # hardware.gpgSmartcards installs the CCID udev rules that give
      # pcscd permission to open the YubiKey's smart-card USB interface.
      hardware.gpgSmartcards.enable = true;
      services.pcscd.enable = true;
      services.udev.packages = with pkgs; [
        yubikey-personalization
        libfido2
      ];

      environment.systemPackages = with pkgs; [
        yubikey-manager # `ykman` CLI
        pam_u2f # `pamu2fcfg` for key enrollment
        libfido2 # `fido2-token` management
      ];
    }

    # --- PAM U2F: touch YubiKey for login / sudo ---
    {
      security.pam.u2f = {
        enable = true;
        control = cfg.pamControl;
        settings = {
          cue = true; # "Please touch the device."
          interactive = true; # "Insert your U2F device, then press ENTER."
          nouserok = true; # fall through to password if key not enrolled yet
        } // optionalAttrs (cfg.authFile != null) {
          inherit (cfg) authFile;
        };
      };

      # Enable U2F per-service, not globally (avoids enabling for sshd).
      security.pam.services = genAttrs cfg.pamServices (_: {
        u2fAuth = true;
      });
    }

    # --- SSH agent for FIDO2 (-sk) keys ---
    # yubikey-agent is incompatible with YubiKey firmware 5.7.x (PIV
    # management key auth changed). GPG agent's SSH emulation doesn't
    # reliably handle -sk keys. Use the standard OpenSSH agent instead,
    # which is the same software stack that created the key.
    {
      programs.gnupg.agent.enableSSHSupport = mkForce false;
      programs.ssh.startAgent = true;
    }
  ]);
}
