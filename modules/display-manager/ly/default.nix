{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.dov.display-manager.ly;
in {

  options.dov.display-manager.ly.enable = mkEnableOption "ly config";

  config = mkIf cfg.enable {
    services.displayManager.ly = {
      enable = true;
    };
  };

}
