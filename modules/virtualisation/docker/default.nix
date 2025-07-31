{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.dov.virtualisation.docker;
in {
  options.dov.virtualisation.docker = {
    enable = mkEnableOption "docker config";
    username = mkOption {
      default = "susano";
      type = types.string;
    };
    isBtrfsStorageDriver = mkOption {
      default = true;
      type = types.bool;
    };
  };

  config = mkIf cfg.enable {
    users.extraGroups.docker.members = [ cfg.username ];

    virtualisation.docker = {
      enable = true;
      rootless = {
        enable = true;
        setSocketVariable = true;
      };

      # TODO use if disko is btrfs
      storageDriver = mkIf cfg.isBtrfsStorageDriver "btrfs";
    };
  };

}
