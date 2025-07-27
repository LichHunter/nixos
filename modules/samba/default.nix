{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.dov.samba;
  ip = "192.168.1.88";
in {
  options.dov.samba = {
    enable = mkEnableOption "samba share config";
  };

  config = mkIf cfg.enable {
    sops.secrets.smb-secrets = {
    };

    environment.systemPackages = [ pkgs.cifs-utils ];

    fileSystems."/MEDIA" = {
      device = "//${ip}/MEDIA";
      fsType = "cifs";
      options = let
        # this line prevents hanging on network split
        automount_opts = "x-systemd.automount,noauto,x-systemd.idle-timeout=60,x-systemd.device-timeout=5s,x-systemd.mount-timeout=5s";

      in ["${automount_opts},credentials=/run/secrets/smb-secrets"];
    };
  };

}
