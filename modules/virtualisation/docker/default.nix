{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.dov.virtualisation.docker;
  username = "susano";
in {
  options.dov.virtualisation.docker = { enable = mkEnableOption "docker config"; };

  config = mkIf cfg.enable {
    users.extraGroups.docker.members = [ username ];

    virtualisation.docker = {
      enable = true;
      rootless = {
        enable = true;
        setSocketVariable = true;
      };

      # TODO use if disko is btrfs
      storageDriver = "btrfs";
    };
  };

}
