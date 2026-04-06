{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.dov.notification.mako;
  colors = config.lib.stylix.colors;
in {
  options.dov.notification.mako.enable = mkEnableOption "mako option";

  config = mkIf cfg.enable {
    services.mako = {
      enable = true;

      settings = {
        background-color = mkForce "#${colors.base01}";
        border-color = mkForce "#${colors.base00}";
        border-radius = 10;
        text-color = mkForce "#${colors.base0A}";

        default-timeout = 5000;
      };
    };
  };
}
